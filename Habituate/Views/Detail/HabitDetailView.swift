import SwiftData
import SwiftUI

/// Looks the habit up by id, so the screen closes itself cleanly if the habit no longer exists.
struct HabitDetailView: View {
    @Query private var matches: [Habit]
    @Environment(\.dismiss) private var dismiss

    init(habitID: UUID) {
        _matches = Query(filter: #Predicate<Habit> { $0.id == habitID })
    }

    var body: some View {
        if let habit = matches.first {
            HabitDetailContent(habit: habit)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }
}

private struct HabitDetailContent: View {
    let habit: Habit

    @Environment(HabitStore.self) private var store
    @Environment(\.today) private var today
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editorMode: HabitEditorMode?
    @State private var pendingDeletion: DeletionRequest?
    @State private var month = Day.today().monthStart

    var body: some View {
        let history = habit.history
        ScrollView {
            VStack(spacing: 20) {
                header
                stats(history)
                MonthCalendarView(habit: habit, history: history, month: $month)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editorMode = .edit(habit) }
                    .accessibilityIdentifier("editHabit")
            }
        }
        // Deleting from here: close the editor, leave this screen, then delete.
        .sheet(item: $editorMode, onDismiss: { if pendingDeletion != nil { dismiss() } }) { mode in
            HabitEditorView(mode: mode) { pendingDeletion = $0 }
        }
        .onDisappear {
            guard let request = pendingDeletion else { return }
            pendingDeletion = nil
            withAnimation { store.delete(id: request.id) }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HabitIcon(emoji: habit.emoji, name: habit.name, color: habit.habitColor, size: 72)
            Text(habit.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(habit.currentWeekdays.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if habit.reminderEnabled {
                Label("Reminder at \(reminderTimeText)", systemImage: "bell.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stats(_ history: HabitHistory) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
        let tint = habit.habitColor.color
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(title: "Current streak", value: daysText(history.currentStreak(today: today)), systemImage: "flame.fill", tint: .orange)
            StatTile(title: "Best streak", value: daysText(history.bestStreak(today: today)), systemImage: "trophy.fill", tint: .yellow)
            StatTile(title: "This week", value: history.weekRate(weekStart: today.weekStart, today: today).percentText, systemImage: "chart.bar.fill", tint: tint)
            StatTile(title: "Total check-ins", value: "\(history.completed.count)", systemImage: "checkmark.circle.fill", tint: .green)
        }
    }

    private var reminderTimeText: String {
        let date = Calendar.current.date(bySettingHour: habit.reminderMinutes / 60, minute: habit.reminderMinutes % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func daysText(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }
}
