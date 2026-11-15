import Foundation

/// A calendar day with no time or time zone attached, stored as the number of days since 1 January 1970.
/// Completions are saved as days, so travelling or changing the device time zone never moves a tick.
struct Day: Hashable, Comparable, Strideable, Sendable {
    let number: Int

    init(number: Int) {
        self.number = number
    }

    init(year: Int, month: Int, day: Int) {
        number = Day.daysFromCivil(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `timeZone`. Always Gregorian, whatever calendar the user has chosen.
    init(_ date: Date, timeZone: TimeZone = .autoupdatingCurrent) {
        let parts = Day.gregorian(in: timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    static func today(now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) -> Day {
        Day(now, timeZone: timeZone)
    }

    var year: Int { civil.year }
    var month: Int { civil.month }
    var dayOfMonth: Int { civil.day }

    /// 0 = Monday … 6 = Sunday. 1 January 1970 was a Thursday.
    var weekdayIndex: Int { ((number + 3) % 7 + 7) % 7 }

    var weekStart: Day { adding(-weekdayIndex) }
    var monthStart: Day { Day(year: year, month: month, day: 1) }

    var nextMonthStart: Day {
        let parts = civil
        return parts.month == 12
            ? Day(year: parts.year + 1, month: 1, day: 1)
            : Day(year: parts.year, month: parts.month + 1, day: 1)
    }

    var previousMonthStart: Day { monthStart.adding(-1).monthStart }
    var daysInMonth: Int { monthStart.distance(to: nextMonthStart) }

    func adding(_ days: Int) -> Day {
        Day(number: number + days)
    }

    /// Midnight at the start of this day in `timeZone`.
    func date(in timeZone: TimeZone = .autoupdatingCurrent) -> Date {
        let parts = civil
        let components = DateComponents(year: parts.year, month: parts.month, day: parts.day)
        return Day.gregorian(in: timeZone).date(from: components)
            ?? Date(timeIntervalSince1970: TimeInterval(number) * 86_400)
    }

    static func == (lhs: Day, rhs: Day) -> Bool { lhs.number == rhs.number }
    static func < (lhs: Day, rhs: Day) -> Bool { lhs.number < rhs.number }
    func distance(to other: Day) -> Int { other.number - number }
    func advanced(by days: Int) -> Day { adding(days) }

    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private var civil: (year: Int, month: Int, day: Int) { Day.civilFromDays(number) }

    // Howard Hinnant's exact proleptic Gregorian conversions, leap years included.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = (shiftedYear >= 0 ? shiftedYear : shiftedYear - 399) / 400
        let yearOfEra = shiftedYear - era * 400
        let shiftedMonth = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    private static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let shifted = days + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return (year, month, day)
    }
}
