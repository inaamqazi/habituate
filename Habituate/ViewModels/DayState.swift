import Foundation

/// How one habit looks on one day in the grid and calendar.
enum DayState: Equatable {
    case done
    case open
    case upcoming
    case unscheduled

    init(day: Day, history: HabitHistory, today: Day) {
        if history.isDone(day) {
            self = .done
        } else if !history.isScheduled(day) {
            self = .unscheduled
        } else if day > today {
            self = .upcoming
        } else {
            self = .open
        }
    }

    var isInteractive: Bool { self == .done || self == .open }

    var accessibilityDescription: String {
        switch self {
        case .done: "Done"
        case .open: "Not done"
        case .upcoming: "Upcoming"
        case .unscheduled: "Not scheduled"
        }
    }
}
