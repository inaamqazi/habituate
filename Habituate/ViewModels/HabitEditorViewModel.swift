import Foundation
import UserNotifications

@Observable
@MainActor
final class HabitEditorViewModel {
    static let suggestedEmoji = ["💧", "📚", "🏃", "🏋️", "🧘", "🥗", "😴", "✍️", "🎸", "🧹", "💊", "🌱", "🚶", "🦷", "📵", "💰"]

    let habit: Habit?
    var draft: HabitDraft
    private(set) var notificationsDenied = false
    private let original: HabitDraft

    init(habit: Habit?) {
        self.habit = habit
        let draft = habit.map { HabitDraft(habit: $0) } ?? HabitDraft()
        self.draft = draft
        original = draft
    }

    var isNew: Bool { habit == nil }
    var hasChanges: Bool { draft != original }

    var reminderTime: Date {
        get {
            Calendar.current.date(
                bySettingHour: draft.reminderMinutes / 60,
                minute: draft.reminderMinutes % 60,
                second: 0,
                of: Date()
            ) ?? Date()
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            draft.reminderMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }

    /// Typing replaces the icon with the last character entered, so the field always holds one emoji.
    func setCustomEmoji(_ text: String) {
        draft.emoji = text.last.map { String($0) } ?? ""
    }

    func limitNameLength() {
        if draft.name.count > HabitDraft.maxNameLength {
            draft.name = String(draft.name.prefix(HabitDraft.maxNameLength))
        }
    }

    func refreshNotificationStatus(using reminders: ReminderScheduler) async {
        guard draft.reminderEnabled else { return }
        notificationsDenied = await reminders.authorizationStatus() == .denied
    }

    func setReminder(_ enabled: Bool, using reminders: ReminderScheduler) async {
        guard enabled else {
            draft.reminderEnabled = false
            return
        }
        draft.reminderEnabled = true
        var status = await reminders.authorizationStatus()
        if status == .notDetermined {
            status = await reminders.requestAuthorization() ? .authorized : .denied
        }
        notificationsDenied = status == .denied
        if notificationsDenied {
            draft.reminderEnabled = false
        }
    }

    func save(using store: HabitStore, today: Day) {
        if let habit {
            store.updateHabit(habit, with: draft, today: today)
        } else {
            store.addHabit(draft, today: today)
        }
    }
}
