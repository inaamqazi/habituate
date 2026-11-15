import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = ""
    var colorName: String = "blue"
    var sortOrder: Int = 0
    var startDayNumber: Int = 0
    /// Schedule history: `scheduleMasks[i]` applies from day `scheduleStarts[i]`.
    /// Two plain arrays so SwiftData stores them natively.
    var scheduleStarts: [Int] = []
    var scheduleMasks: [Int] = []
    var completedDayNumbers: [Int] = []
    var reminderEnabled: Bool = false
    /// Minutes after midnight.
    var reminderMinutes: Int = 540
    var isSample: Bool = false

    init(
        name: String,
        emoji: String = "",
        color: HabitColor = .blue,
        weekdays: WeekdaySet = .all,
        start: Day,
        sortOrder: Int = 0
    ) {
        self.name = name
        self.emoji = emoji
        self.colorName = color.rawValue
        self.sortOrder = sortOrder
        self.startDayNumber = start.number
        self.scheduleStarts = [start.number]
        self.scheduleMasks = [weekdays.rawValue]
    }

    var start: Day { Day(number: startDayNumber) }

    var habitColor: HabitColor { HabitColor(rawValue: colorName) ?? .blue }

    var schedule: [ScheduleChange] {
        zip(scheduleStarts, scheduleMasks).map { ScheduleChange(start: Day(number: $0), days: WeekdaySet(rawValue: $1)) }
    }

    var currentWeekdays: WeekdaySet { schedule.last?.days ?? .all }

    var history: HabitHistory {
        HabitHistory(start: start, schedule: schedule, completed: Set(completedDayNumbers.map { Day(number: $0) }))
    }

    func isDone(on day: Day) -> Bool {
        completedDayNumbers.contains(day.number)
    }

    func setDone(_ done: Bool, on day: Day) {
        let isDone = completedDayNumbers.contains(day.number)
        if done && !isDone {
            completedDayNumbers.append(day.number)
        } else if !done && isDone {
            completedDayNumbers.removeAll { $0 == day.number }
        }
    }

    /// Changes the schedule from `day` onwards; earlier days keep the schedule they had.
    func updateSchedule(_ weekdays: WeekdaySet, from day: Day) {
        let updated = HabitHistory.updatedSchedule(schedule, with: weekdays, from: max(day, start))
        scheduleStarts = updated.map(\.start.number)
        scheduleMasks = updated.map(\.days.rawValue)
    }
}
