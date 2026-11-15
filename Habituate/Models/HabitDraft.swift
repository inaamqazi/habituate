import Foundation

/// The editable fields of a habit, used by the add/edit screen.
struct HabitDraft: Equatable {
    static let maxNameLength = 100

    var name = ""
    var emoji = ""
    var color: HabitColor = .blue
    var everyDay = true
    var weekdays: WeekdaySet = .all
    var reminderEnabled = false
    var reminderMinutes = 9 * 60

    init() {}

    init(habit: Habit) {
        name = habit.name
        emoji = habit.emoji
        color = habit.habitColor
        weekdays = habit.currentWeekdays
        everyDay = weekdays == .all
        reminderEnabled = habit.reminderEnabled
        reminderMinutes = habit.reminderMinutes
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var scheduledDays: WeekdaySet { everyDay ? .all : weekdays }
    var isScheduleValid: Bool { !scheduledDays.isEmpty }
    var isValid: Bool { !trimmedName.isEmpty && isScheduleValid }
}

/// Everything needed to put a deleted habit back exactly as it was.
struct HabitSnapshot: Equatable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let colorName: String
    let sortOrder: Int
    let startDayNumber: Int
    let scheduleStarts: [Int]
    let scheduleMasks: [Int]
    let completedDayNumbers: [Int]
    let reminderEnabled: Bool
    let reminderMinutes: Int
    let isSample: Bool

    init(habit: Habit) {
        id = habit.id
        name = habit.name
        emoji = habit.emoji
        colorName = habit.colorName
        sortOrder = habit.sortOrder
        startDayNumber = habit.startDayNumber
        scheduleStarts = habit.scheduleStarts
        scheduleMasks = habit.scheduleMasks
        completedDayNumbers = habit.completedDayNumbers
        reminderEnabled = habit.reminderEnabled
        reminderMinutes = habit.reminderMinutes
        isSample = habit.isSample
    }

    func makeHabit() -> Habit {
        let habit = Habit(name: name, start: Day(number: startDayNumber), sortOrder: sortOrder)
        habit.id = id
        habit.emoji = emoji
        habit.colorName = colorName
        habit.scheduleStarts = scheduleStarts
        habit.scheduleMasks = scheduleMasks
        habit.completedDayNumbers = completedDayNumbers
        habit.reminderEnabled = reminderEnabled
        habit.reminderMinutes = reminderMinutes
        habit.isSample = isSample
        return habit
    }
}
