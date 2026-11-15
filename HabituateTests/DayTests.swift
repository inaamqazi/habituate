import XCTest
@testable import Habituate

final class DayTests: XCTestCase {
    func testKnownWeekdays() {
        XCTAssertEqual(Day(year: 1970, month: 1, day: 1).weekdayIndex, 3) // Thursday
        XCTAssertEqual(Day(year: 2000, month: 1, day: 1).weekdayIndex, 5) // Saturday
        XCTAssertEqual(Day(year: 2024, month: 2, day: 29).weekdayIndex, 3) // Thursday
        XCTAssertEqual(Day(year: 2026, month: 11, day: 15).weekdayIndex, 6) // Sunday
        XCTAssertEqual(Day(year: 2026, month: 11, day: 16).weekdayIndex, 0) // Monday
        XCTAssertEqual(Day(year: 1969, month: 12, day: 31).weekdayIndex, 2) // Wednesday, before the epoch
    }

    func testComponentsRoundTripIncludingLeapDays() {
        let samples = [(2024, 2, 29), (2023, 2, 28), (2000, 2, 29), (1900, 2, 28), (2100, 3, 1), (2026, 12, 31), (1969, 7, 20)]
        for (year, month, day) in samples {
            let value = Day(year: year, month: month, day: day)
            XCTAssertEqual(value.year, year)
            XCTAssertEqual(value.month, month)
            XCTAssertEqual(value.dayOfMonth, day)
        }
    }

    func testAddingAcrossMonthYearAndLeapBoundaries() {
        XCTAssertEqual(Day(year: 2024, month: 2, day: 28).adding(1), Day(year: 2024, month: 2, day: 29))
        XCTAssertEqual(Day(year: 2024, month: 2, day: 29).adding(1), Day(year: 2024, month: 3, day: 1))
        XCTAssertEqual(Day(year: 2023, month: 2, day: 28).adding(1), Day(year: 2023, month: 3, day: 1))
        XCTAssertEqual(Day(year: 2024, month: 3, day: 1).adding(-1), Day(year: 2024, month: 2, day: 29))
        XCTAssertEqual(Day(year: 2025, month: 12, day: 31).adding(1), Day(year: 2026, month: 1, day: 1))
        XCTAssertEqual(Day(year: 2024, month: 1, day: 1).adding(366), Day(year: 2025, month: 1, day: 1))
    }

    func testWeekStartIsMondayAcrossYearBoundary() {
        XCTAssertEqual(Day(year: 2025, month: 1, day: 1).weekStart, Day(year: 2024, month: 12, day: 30))
        XCTAssertEqual(Day(year: 2026, month: 11, day: 15).weekStart, Day(year: 2026, month: 11, day: 9))
        XCTAssertEqual(Day(year: 2026, month: 11, day: 16).weekStart, Day(year: 2026, month: 11, day: 16))
        XCTAssertEqual(Day(year: 2024, month: 3, day: 3).weekStart, Day(year: 2024, month: 2, day: 26))
    }

    func testMonthLengthsAndNavigation() {
        XCTAssertEqual(Day(year: 2024, month: 2, day: 10).daysInMonth, 29)
        XCTAssertEqual(Day(year: 2023, month: 2, day: 10).daysInMonth, 28)
        XCTAssertEqual(Day(year: 1900, month: 2, day: 1).daysInMonth, 28)
        XCTAssertEqual(Day(year: 2000, month: 2, day: 1).daysInMonth, 29)
        XCTAssertEqual(Day(year: 2026, month: 4, day: 30).daysInMonth, 30)
        XCTAssertEqual(Day(year: 2026, month: 12, day: 25).nextMonthStart, Day(year: 2027, month: 1, day: 1))
        XCTAssertEqual(Day(year: 2026, month: 1, day: 25).previousMonthStart, Day(year: 2025, month: 12, day: 1))
        XCTAssertEqual(Day(year: 2024, month: 3, day: 31).monthStart, Day(year: 2024, month: 3, day: 1))
    }

    func testSameInstantIsADifferentDayInDifferentTimeZones() throws {
        // 2024-03-01 03:30 UTC.
        let instant = Date(timeIntervalSince1970: 1_709_263_800)
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        XCTAssertEqual(Day(instant, timeZone: newYork), Day(year: 2024, month: 2, day: 29))
        XCTAssertEqual(Day(instant, timeZone: tokyo), Day(year: 2024, month: 3, day: 1))
        XCTAssertEqual(Day(instant, timeZone: .gmt), Day(year: 2024, month: 3, day: 1))
    }

    func testStoredDaySurvivesTimeZoneChange() throws {
        // A tick saved as a Day keeps its calendar date whatever zone the phone moves to.
        let saved = Day(year: 2026, month: 11, day: 10)
        for identifier in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "Asia/Karachi", "Europe/London"] {
            let zone = try XCTUnwrap(TimeZone(identifier: identifier))
            XCTAssertEqual(Day(saved.date(in: zone), timeZone: zone), saved, identifier)
        }
    }

    func testDateRoundTripOnDaylightSavingDays() throws {
        let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        for day in [Day(year: 2024, month: 3, day: 10), Day(year: 2024, month: 11, day: 3)] {
            XCTAssertEqual(Day(day.date(in: newYork), timeZone: newYork), day)
        }
    }

    func testMidnightRolloverChangesToday() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Asia/Karachi"))
        let lastSecond = try XCTUnwrap(Day.gregorian(in: zone).date(from: DateComponents(year: 2024, month: 12, day: 31, hour: 23, minute: 59, second: 59)))
        XCTAssertEqual(Day.today(now: lastSecond, timeZone: zone), Day(year: 2024, month: 12, day: 31))
        XCTAssertEqual(Day.today(now: lastSecond.addingTimeInterval(1), timeZone: zone), Day(year: 2025, month: 1, day: 1))
    }

    func testRangesIterateEveryDay() {
        let start = Day(year: 2024, month: 2, day: 27)
        let days = Array(start...Day(year: 2024, month: 3, day: 2))
        XCTAssertEqual(days.count, 5)
        XCTAssertEqual(days.map(\.dayOfMonth), [27, 28, 29, 1, 2])
    }

    func testWeekdaySet() {
        let mwf = WeekdaySet(indices: [0, 2, 4])
        XCTAssertEqual(mwf.indices, [0, 2, 4])
        XCTAssertTrue(mwf.contains(Day(year: 2026, month: 11, day: 16))) // Monday
        XCTAssertFalse(mwf.contains(Day(year: 2026, month: 11, day: 17))) // Tuesday
        XCTAssertEqual(WeekdaySet.all.summary, "Every day")
        XCTAssertEqual(WeekdaySet.workdays.summary, "Weekdays")
        XCTAssertEqual(WeekdaySet.weekend.summary, "Weekends")
        XCTAssertTrue(WeekdaySet().isEmpty)
        XCTAssertEqual(WeekdaySet(rawValue: 0xFFFF), .all)
    }
}
