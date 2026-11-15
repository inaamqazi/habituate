import Foundation

/// The days of the week a habit is scheduled for. Bit 0 = Monday … bit 6 = Sunday.
struct WeekdaySet: OptionSet, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue & 0b111_1111
    }

    init(indices: [Int]) {
        self.init(rawValue: indices.reduce(0) { $0 | (1 << $1) })
    }

    static let all = WeekdaySet(rawValue: 0b111_1111)
    static let workdays = WeekdaySet(rawValue: 0b001_1111)
    static let weekend = WeekdaySet(rawValue: 0b110_0000)

    static func weekday(_ index: Int) -> WeekdaySet {
        WeekdaySet(rawValue: 1 << index)
    }

    func contains(_ day: Day) -> Bool {
        contains(.weekday(day.weekdayIndex))
    }

    /// Monday-based indices (0 = Monday) of the days in the set.
    var indices: [Int] {
        (0..<7).filter { contains(.weekday($0)) }
    }

    var summary: String {
        switch self {
        case .all: return "Every day"
        case .workdays: return "Weekdays"
        case .weekend: return "Weekends"
        default: return indices.map(WeekdayNames.short).joined(separator: ", ")
        }
    }
}

/// One entry in a habit's schedule history: `days` applies from `start` until the next change.
struct ScheduleChange: Equatable, Sendable {
    let start: Day
    let days: WeekdaySet
}

/// Localised weekday names, indexed from Monday (0) to Sunday (6).
enum WeekdayNames {
    static func short(_ index: Int) -> String { symbol(calendar.shortStandaloneWeekdaySymbols, index) }
    static func veryShort(_ index: Int) -> String { symbol(calendar.veryShortStandaloneWeekdaySymbols, index) }
    static func full(_ index: Int) -> String { symbol(calendar.standaloneWeekdaySymbols, index) }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .autoupdatingCurrent
        return calendar
    }

    // Calendar symbol arrays start on Sunday.
    private static func symbol(_ symbols: [String], _ index: Int) -> String {
        let sundayBased = (index + 1) % 7
        return symbols.indices.contains(sundayBased) ? symbols[sundayBased] : ""
    }
}
