import SwiftData
import XCTest
@testable import Habituate

@MainActor
final class HabitStoreTests: XCTestCase {
    /// Wednesday 11 November 2026.
    private let today = Day(year: 2026, month: 11, day: 11)
    private var monday: Day { today.weekStart }
    private let mwf = WeekdaySet(indices: [0, 2, 4])

    private func makeStore(url: URL? = nil) throws -> HabitStore {
        let container = try HabitStoreFactory.makeContainer(inMemory: url == nil, url: url)
        return HabitStore(container: container, reminders: ReminderScheduler(isActive: false))
    }

    private func draft(_ name: String, weekdays: WeekdaySet = .all) -> HabitDraft {
        var draft = HabitDraft()
        draft.name = name
        draft.everyDay = weekdays == .all
        draft.weekdays = weekdays
        return draft
    }

    private func makeDefaults() throws -> UserDefaults {
        let name = "HabitStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testAddHabitTrimsNameStartsTodayAndGoesLast() throws {
        let store = try makeStore()
        store.addHabit(draft("First"), today: today)
        let second = store.addHabit(draft("  Second  "), today: today)
        XCTAssertEqual(second.name, "Second")
        XCTAssertEqual(second.start, today)
        XCTAssertEqual(store.habits().map(\.name), ["First", "Second"])
    }

    func testToggleTicksAndUnticks() throws {
        let store = try makeStore()
        let habit = store.addHabit(draft("Read"), today: today)
        store.toggle(habit, on: today, today: today)
        XCTAssertTrue(habit.isDone(on: today))
        XCTAssertEqual(store.completionCount, 1)
        store.toggle(habit, on: today, today: today)
        XCTAssertFalse(habit.isDone(on: today))
        XCTAssertEqual(store.uncompletionCount, 1)
    }

    func testToggleIgnoresFutureUnscheduledAndPreStartDays() throws {
        let store = try makeStore()
        let habit = store.addHabit(draft("Gym", weekdays: mwf), today: today)
        store.toggle(habit, on: today.adding(2), today: today) // Friday, future
        store.toggle(habit, on: today.adding(1), today: today) // Thursday, not scheduled and future
        store.toggle(habit, on: monday, today: today) // before the habit started
        XCTAssertTrue(habit.completedDayNumbers.isEmpty)
    }

    func testCompleteWholeWeekMarksOnlyEligibleDays() throws {
        let store = try makeStore()
        let habit = store.addHabit(draft("Gym", weekdays: mwf), today: monday.adding(-7))
        store.setWeek(habit, weekStart: monday, today: today, done: true)
        XCTAssertEqual(habit.completedDayNumbers.sorted(), [monday.number, today.number])
        XCTAssertTrue(store.isWeekComplete(habit, weekStart: monday, today: today))

        store.setWeek(habit, weekStart: monday, today: today, done: false)
        XCTAssertTrue(habit.completedDayNumbers.isEmpty)
        XCTAssertFalse(store.isWeekComplete(habit, weekStart: monday, today: today))
    }

    func testCompleteTodaySkipsHabitsNotScheduledToday() throws {
        let store = try makeStore()
        let daily = store.addHabit(draft("Water"), today: monday)
        let weekends = store.addHabit(draft("Hike", weekdays: .weekend), today: monday)
        let habits = store.habits()

        store.setDay(habits, on: today, done: true)
        XCTAssertTrue(daily.isDone(on: today))
        XCTAssertFalse(weekends.isDone(on: today))
        XCTAssertTrue(store.isDayComplete(habits, on: today))

        store.setDay(habits, on: today, done: false)
        XCTAssertFalse(store.isDayComplete(habits, on: today))
    }

    func testDeleteLeavesNothingBehindAndUndoRestoresEverything() throws {
        let store = try makeStore()
        var editDraft = draft("Meditate", weekdays: mwf)
        editDraft.emoji = "🧘"
        let habit = store.addHabit(editDraft, today: monday.adding(-14))
        store.toggle(habit, on: monday, today: today)
        store.updateHabit(habit, with: draft("Meditate"), today: today)
        let before = HabitSnapshot(habit: habit)

        store.delete(habit)
        XCTAssertTrue(store.habits().isEmpty)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Habit>()), 0)
        XCTAssertEqual(store.recentlyDeleted?.id, before.id)

        store.undoDelete()
        XCTAssertNil(store.recentlyDeleted)
        let restored = try XCTUnwrap(store.habits().first)
        XCTAssertEqual(HabitSnapshot(habit: restored), before)
    }

    func testDeleteByIDIgnoresUnknownHabit() throws {
        let store = try makeStore()
        store.addHabit(draft("Read"), today: today)
        store.delete(id: UUID())
        XCTAssertEqual(store.habits().count, 1)
        XCTAssertNil(store.recentlyDeleted)
    }

    func testEditingScheduleKeepsPastTicks() throws {
        let store = try makeStore()
        let habit = store.addHabit(draft("Run"), today: monday.adding(-7))
        for offset in 0...6 { store.toggle(habit, on: monday.adding(offset - 7), today: today) }
        store.updateHabit(habit, with: draft("Run", weekdays: mwf), today: today)

        let history = habit.history
        XCTAssertEqual(habit.completedDayNumbers.count, 7)
        XCTAssertEqual(history.weekRate(weekStart: monday.adding(-7), today: today), CompletionRate(done: 7, total: 7))
        XCTAssertTrue(history.isScheduled(monday.adding(1)), "Tuesday this week was before the edit")
        XCTAssertFalse(history.isScheduled(today.adding(1)), "Thursday is after the edit")
    }

    func testReorder() throws {
        let store = try makeStore()
        ["A", "B", "C"].forEach { store.addHabit(draft($0), today: today) }
        store.move(store.habits(), from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(store.habits().map(\.name), ["C", "A", "B"])
    }

    func testSampleSeedingRunsOnlyOnceAndClearKeepsUserHabits() throws {
        let store = try makeStore()
        let defaults = try makeDefaults()
        store.seedSampleHabitsIfNeeded(today: today, defaults: defaults)
        XCTAssertEqual(store.habits().count, 6)
        XCTAssertTrue(store.habits().allSatisfy(\.isSample))
        XCTAssertTrue(store.habits().contains { $0.history.currentStreak(today: today) > 0 })

        store.addHabit(draft("Mine"), today: today)
        store.removeSampleHabits()
        XCTAssertEqual(store.habits().map(\.name), ["Mine"])

        store.seedSampleHabitsIfNeeded(today: today, defaults: defaults)
        XCTAssertEqual(store.habits().count, 1, "Samples never come back once seeded")
    }

    func testSamplesAreNotAddedOverExistingHabits() throws {
        let store = try makeStore()
        store.addHabit(draft("Mine"), today: today)
        store.seedSampleHabitsIfNeeded(today: today, defaults: try makeDefaults())
        XCTAssertEqual(store.habits().count, 1)
    }

    func testDataSurvivesReopeningTheStore() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Test.store")

        let id: UUID
        do {
            let store = try makeStore(url: url)
            let habit = store.addHabit(draft("Persisted 🌱", weekdays: mwf), today: monday)
            store.toggle(habit, on: today, today: today)
            id = habit.id
        }

        let reopened = try makeStore(url: url)
        let habit = try XCTUnwrap(reopened.habit(withID: id))
        XCTAssertEqual(habit.name, "Persisted 🌱")
        XCTAssertEqual(habit.currentWeekdays, mwf)
        XCTAssertTrue(habit.isDone(on: today))
    }

    func testManyHabitsLongNamesAndEmoji() throws {
        let store = try makeStore()
        let longName = String(repeating: "Very long habit name with emoji 🏃‍♀️ ", count: 3)
        for index in 0..<25 {
            let habit = store.addHabit(draft(index == 0 ? longName : "Habit \(index) 🎯"), today: monday)
            store.toggle(habit, on: today, today: today)
        }
        let habits = store.habits()
        XCTAssertEqual(habits.count, 25)
        XCTAssertEqual(habits.first?.name, longName.trimmingCharacters(in: .whitespaces))
        XCTAssertEqual(habits.map(\.sortOrder), Array(0..<25))
        XCTAssertTrue(store.isDayComplete(habits, on: today))
        let overall = habits.reduce(CompletionRate()) { $0 + $1.history.weekRate(weekStart: monday, today: today) }
        XCTAssertEqual(overall, CompletionRate(done: 25, total: 75))
    }

    func testDraftValidation() {
        var draft = HabitDraft()
        XCTAssertFalse(draft.isValid)
        draft.name = "   "
        XCTAssertFalse(draft.isValid)
        draft.name = "Walk"
        XCTAssertTrue(draft.isValid)
        draft.everyDay = false
        draft.weekdays = []
        XCTAssertFalse(draft.isValid)
        draft.weekdays = .weekend
        XCTAssertTrue(draft.isValid)
    }

    func testEditorLimitsNameAndKeepsOneEmoji() {
        let model = HabitEditorViewModel(habit: nil)
        model.draft.name = String(repeating: "a", count: 150)
        model.limitNameLength()
        XCTAssertEqual(model.draft.name.count, HabitDraft.maxNameLength)
        model.setCustomEmoji("🙂🏊‍♂️")
        XCTAssertEqual(model.draft.emoji, "🏊‍♂️")
        model.setCustomEmoji("")
        XCTAssertEqual(model.draft.emoji, "")
    }
}
