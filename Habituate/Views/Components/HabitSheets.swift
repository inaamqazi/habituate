import SwiftUI

enum HabitEditorMode: Identifiable {
    case new
    case edit(Habit)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let habit): habit.id.uuidString
        }
    }

    var habit: Habit? {
        if case .edit(let habit) = self { return habit }
        return nil
    }
}

/// A pending delete, held by value so no screen keeps reading a habit after it is gone.
struct DeletionRequest: Identifiable, Equatable {
    let id: UUID
    let name: String

    init(habit: Habit) {
        id = habit.id
        name = habit.name
    }
}

/// Presents the editor. A delete chosen inside it runs only after the sheet has closed.
private struct HabitEditorSheetModifier: ViewModifier {
    @Binding var mode: HabitEditorMode?
    @Environment(HabitStore.self) private var store
    @State private var pendingDeletion: DeletionRequest?

    func body(content: Content) -> some View {
        content.sheet(item: $mode, onDismiss: deletePending) { mode in
            HabitEditorView(mode: mode) { pendingDeletion = $0 }
        }
    }

    private func deletePending() {
        guard let request = pendingDeletion else { return }
        pendingDeletion = nil
        withAnimation { store.delete(id: request.id) }
    }
}

private struct DeleteConfirmationModifier: ViewModifier {
    @Binding var request: DeletionRequest?
    let onDelete: (DeletionRequest) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete this habit?",
            isPresented: Binding(get: { request != nil }, set: { if !$0 { request = nil } }),
            titleVisibility: .visible,
            presenting: request
        ) { request in
            Button("Delete", role: .destructive) { onDelete(request) }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text("“\(request.name)” and all of its history will be deleted. You can undo this for a few seconds afterwards.")
        }
    }
}

extension View {
    func habitEditorSheet(_ mode: Binding<HabitEditorMode?>) -> some View {
        modifier(HabitEditorSheetModifier(mode: mode))
    }

    func confirmHabitDeletion(_ request: Binding<DeletionRequest?>, onDelete: @escaping (DeletionRequest) -> Void) -> some View {
        modifier(DeleteConfirmationModifier(request: request, onDelete: onDelete))
    }
}
