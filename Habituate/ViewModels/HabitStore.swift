import Foundation
import os
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

/// Every change to habits goes through here, so saving, reminders, the widget and Undo stay in step.
@Observable
@MainActor
final class HabitStore {
    static let sampleSeedKey = "hasSeededSampleHabits"

    let container: ModelContainer
    let reminders: ReminderScheduler

    /// The habit deleted most recently, kept for a few seconds so Undo can restore it.
    private(set) var recentlyDeleted: HabitSnapshot?
    /// Bumped on every tick and untick; the root view turns them into haptics.
    private(set) var completionCount = 0
    private(set) var uncompletionCount = 0

    @ObservationIgnored private var undoExpiry: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.habituate.app", category: "HabitStore")

    init(container: ModelContainer, reminders: ReminderScheduler) {
        self.container = container
        self.reminders = reminders
    }

    var context: ModelContext { container.mainContext }

    // MARK: Reading

    func habits() -> [Habit] {
        habits(matching: FetchDescriptor<Habit>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    func habit(withID id: UUID) -> Habit? {
        var descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return habits(matching: descriptor).first
    }

    // MARK: Adding and editing

    @discardableResult
    func addHabit(_ draft: HabitDraft, today: Day) -> Habit {
        let nextOrder = (habits().map(\.sortOrder).max() ?? -1) + 1
        let habit = Habit(
            name: draft.trimmedName,
            emoji: draft.emoji,
            color: draft.color,
            weekdays: draft.scheduledDays,
            start: today,
            sortOrder: nextOrder
        )
        habit.reminderEnabled = draft.reminderEnabled
        habit.reminderMinutes = draft.reminderMinutes
        context.insert(habit)
        save()
        reminders.update(habit)
        return habit
    }

    func updateHabit(_ habit: Habit, with draft: HabitDraft, today: Day) {
        habit.name = draft.trimmedName
        habit.emoji = draft.emoji
        habit.colorName = draft.color.rawValue
        habit.updateSchedule(draft.scheduledDays, from: today)
        habit.reminderEnabled = draft.reminderEnabled
        habit.reminderMinutes = draft.reminderMinutes
        save()
        reminders.update(habit)
    }

    func move(_ ordered: [Habit], from source: IndexSet, to destination: Int) {
        var reordered = ordered
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in reordered.enumerated() where habit.sortOrder != index {
            habit.sortOrder = index
        }
        save()
    }

    // MARK: Ticking

    /// Past and today's scheduled days can be ticked; a tick can always be removed.
    func canToggle(_ habit: Habit, on day: Day, today: Day) -> Bool {
        day <= today && (habit.isDone(on: day) || habit.history.isScheduled(day))
    }

    func toggle(_ habit: Habit, on day: Day, today: Day) {
        guard canToggle(habit, on: day, today: today) else { return }
        let done = !habit.isDone(on: day)
        habit.setDone(done, on: day)
        recordFeedback(done: done)
        save()
    }

    /// The days of a week that "Complete whole week" acts on: scheduled and not in the future.
    func eligibleDays(for habit: Habit, weekStart: Day, today: Day) -> [Day] {
        let history = habit.history
        return (0..<7).map { weekStart.adding($0) }.filter { $0 <= today && history.isScheduled($0) }
    }

    func isWeekComplete(_ habit: Habit, weekStart: Day, today: Day) -> Bool {
        let days = eligibleDays(for: habit, weekStart: weekStart, today: today)
        return !days.isEmpty && days.allSatisfy { habit.isDone(on: $0) }
    }

    func setWeek(_ habit: Habit, weekStart: Day, today: Day, done: Bool) {
        let days = eligibleDays(for: habit, weekStart: weekStart, today: today)
        guard !days.isEmpty else { return }
        days.forEach { habit.setDone(done, on: $0) }
        recordFeedback(done: done)
        save()
    }

    func habitsScheduled(_ habits: [Habit], on day: Day) -> [Habit] {
        habits.filter { $0.history.isScheduled(day) }
    }

    func isDayComplete(_ habits: [Habit], on day: Day) -> Bool {
        let scheduled = habitsScheduled(habits, on: day)
        return !scheduled.isEmpty && scheduled.allSatisfy { $0.isDone(on: day) }
    }

    func setDay(_ habits: [Habit], on day: Day, done: Bool) {
        let scheduled = habitsScheduled(habits, on: day)
        guard !scheduled.isEmpty else { return }
        scheduled.forEach { $0.setDone(done, on: day) }
        recordFeedback(done: done)
        save()
    }

    // MARK: Deleting

    func delete(_ habit: Habit) {
        let snapshot = HabitSnapshot(habit: habit)
        reminders.cancel(habitID: habit.id)
        context.delete(habit)
        save()
        recentlyDeleted = snapshot
        scheduleUndoExpiry()
    }

    func delete(id: UUID) {
        guard let habit = habit(withID: id) else { return }
        delete(habit)
    }

    func undoDelete() {
        guard let snapshot = recentlyDeleted else { return }
        dismissUndo()
        let habit = snapshot.makeHabit()
        context.insert(habit)
        save()
        reminders.update(habit)
    }

    func dismissUndo() {
        undoExpiry?.cancel()
        undoExpiry = nil
        recentlyDeleted = nil
    }

    // MARK: Sample data

    func seedSampleHabitsIfNeeded(today: Day, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Self.sampleSeedKey) else { return }
        defaults.set(true, forKey: Self.sampleSeedKey)
        if habits().isEmpty {
            addSampleHabits(today: today)
        }
    }

    func addSampleHabits(today: Day) {
        SampleData.makeHabits(today: today).forEach { context.insert($0) }
        save()
    }

    func removeSampleHabits() {
        for habit in habits() where habit.isSample {
            reminders.cancel(habitID: habit.id)
            context.delete(habit)
        }
        if recentlyDeleted?.isSample == true {
            dismissUndo()
        }
        save()
    }

    // MARK: Private

    func save() {
        do {
            try context.save()
        } catch {
            logger.error("Saving habits failed: \(error.localizedDescription, privacy: .public)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func habits(matching descriptor: FetchDescriptor<Habit>) -> [Habit] {
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Fetching habits failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func recordFeedback(done: Bool) {
        if done {
            completionCount += 1
        } else {
            uncompletionCount += 1
        }
    }

    private func scheduleUndoExpiry() {
        undoExpiry?.cancel()
        // VoiceOver users need longer to reach the Undo button.
        let seconds: Double = UIAccessibility.isVoiceOverRunning ? 10 : 5
        undoExpiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.recentlyDeleted = nil
        }
    }
}
