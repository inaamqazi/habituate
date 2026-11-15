import Foundation
import UserNotifications

/// The notifications for one habit, built from plain values so it can be tested without the notification center.
struct ReminderPlan: Equatable {
    let habitID: UUID
    let title: String
    let weekdays: WeekdaySet
    let hour: Int
    let minute: Int

    init(habit: Habit) {
        habitID = habit.id
        title = habit.emoji.isEmpty ? habit.name : "\(habit.emoji) \(habit.name)"
        weekdays = habit.currentWeekdays
        hour = habit.reminderMinutes / 60
        minute = habit.reminderMinutes % 60
    }

    /// Every identifier a habit's reminders can use: "-0" for daily, "-1"…"-7" for Monday…Sunday.
    static func identifiers(for habitID: UUID) -> [String] {
        (0...7).map { "\(habitID.uuidString)-\($0)" }
    }

    /// One repeating trigger per scheduled weekday, or a single daily one. `DateComponents.weekday` 1 = Sunday.
    var triggers: [(identifier: String, components: DateComponents)] {
        if weekdays == .all {
            return [(identifier: "\(habitID.uuidString)-0", components: DateComponents(hour: hour, minute: minute))]
        }
        return weekdays.indices.map { index in
            (
                identifier: "\(habitID.uuidString)-\(index + 1)",
                components: DateComponents(hour: hour, minute: minute, weekday: (index + 1) % 7 + 1)
            )
        }
    }

    func requests() -> [UNNotificationRequest] {
        triggers.map { trigger in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Don't forget to tick it off today."
            content.sound = .default
            let calendarTrigger = UNCalendarNotificationTrigger(dateMatching: trigger.components, repeats: true)
            return UNNotificationRequest(identifier: trigger.identifier, content: content, trigger: calendarTrigger)
        }
    }
}

@MainActor
final class ReminderScheduler {
    /// Off for tests, so no permission prompt ever appears and nothing is scheduled.
    private let isActive: Bool

    init(isActive: Bool) {
        self.isActive = isActive
    }

    private var center: UNUserNotificationCenter { .current() }

    func authorizationStatus() async -> UNAuthorizationStatus {
        guard isActive else { return .notDetermined }
        return await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        guard isActive else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func update(_ habit: Habit) {
        cancel(habitID: habit.id)
        guard isActive, habit.reminderEnabled else { return }
        let requests = ReminderPlan(habit: habit).requests()
        Task {
            guard await canDeliver() else { return }
            for request in requests {
                do {
                    try await center.add(request)
                } catch {
                    continue
                }
            }
        }
    }

    func cancel(habitID: UUID) {
        guard isActive else { return }
        center.removePendingNotificationRequests(withIdentifiers: ReminderPlan.identifiers(for: habitID))
    }

    func resync(_ habits: [Habit]) {
        guard isActive else { return }
        center.removeAllPendingNotificationRequests()
        habits.forEach(update)
    }

    private func canDeliver() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }
}
