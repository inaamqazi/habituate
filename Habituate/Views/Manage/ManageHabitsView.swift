import SwiftData
import SwiftUI

/// Reorder, edit and delete habits.
struct ManageHabitsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.sortOrder) private var queriedHabits: [Habit]
    @State private var editorMode: HabitEditorMode?
    @State private var deletion: DeletionRequest?

    /// Leaves out habits deleted a moment ago that the query hasn't dropped yet; reading those would crash.
    private var habits: [Habit] { queriedHabits.filter { !$0.isDeleted && $0.modelContext != nil } }

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    Button { editorMode = .edit(habit) } label: {
                        HStack(spacing: 12) {
                            HabitIcon(emoji: habit.emoji, name: habit.name, color: habit.habitColor, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                    .foregroundStyle(.primary)
                                Text(habit.currentWeekdays.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Edits this habit.")
                    .accessibilityIdentifier("manageRow.\(habit.name)")
                }
                .onMove { store.move(habits, from: $0, to: $1) }
                .onDelete { offsets in
                    if let index = offsets.first, habits.indices.contains(index) {
                        deletion = DeletionRequest(habit: habits[index])
                    }
                }
            }
            .overlay {
                if habits.isEmpty {
                    ContentUnavailableView("No Habits", systemImage: "checklist", description: Text("Habits you add appear here."))
                }
            }
            .overlay(alignment: .bottom) {
                UndoToast().padding(.bottom, 16)
            }
            .navigationTitle("Manage Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .habitEditorSheet($editorMode)
            .confirmHabitDeletion($deletion) { request in
                withAnimation { store.delete(id: request.id) }
            }
        }
    }
}
