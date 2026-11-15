import XCTest
@testable import Habituate

final class HabitHistoryTests: XCTestCase {
    /// Monday 9 November 2026.
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let mwf = WeekdaySet(indices: [0, 2, 4])

    private func history(start: Day, weekdays: WeekdaySet = .all, done: [Day], schedule: [ScheduleChange]? = nil) -> HabitHistory {
        HabitHistory(start: start, schedule: schedule ?? [ScheduleChange(start: start, days: weekdays)], completed: Set(done))
    }

    private func days(_ offsets: ClosedRange<Int>, from base: Day) -> [Day] {
        offsets.map { base.adding($0) }
    }

    // MARK: Current streak

    func testStreakCountsConsecutiveDaysIncludingToday() {
        let today = monday.adding(4)
        let sut = history(start: monday.adding(-10), done: days(0...4, from: monday))
        XCTAssertEqual(sut.currentStreak(today: today), 5)
    }

    func testUntickedTodayDoesNotBreakStreak() {
        let today = monday.adding(4)
        let sut = history(start: monday.adding(-10), done: days(0...3, from: monday))
        XCTAssertEqual(sut.currentStreak(today: today), 4)
    }

    func testMissedScheduledDayBreaksStreak() {
        let today = monday.adding(3)
        let sut = history(start: monday.adding(-10), done: [monday, monday.adding(2), monday.adding(3)])
        XCTAssertEqual(sut.currentStreak(today: today), 2)
    }

    func testMissedYesterdayAndUntickedTodayIsZero() {
        let today = monday.adding(3)
        let sut = history(start: monday.adding(-10), done: [monday, monday.adding(1)])
        XCTAssertEqual(sut.currentStreak(today: today), 0)
    }

    func testUnscheduledDaysDoNotBreakStreak() {
        // Mon, Wed, Fri, then Mon of the next week; checked on the following Tuesday (not scheduled).
        let done = [monday, monday.adding(2), monday.adding(4), monday.adding(7)]
        let sut = history(start: monday, weekdays: mwf, done: done)
        XCTAssertEqual(sut.currentStreak(today: monday.adding(8)), 4)
        // Wednesday of week two still pending: streak holds.
        XCTAssertEqual(sut.currentStreak(today: monday.adding(9)), 4)
        // Thursday: Wednesday was missed, so the streak is over.
        XCTAssertEqual(sut.currentStreak(today: monday.adding(10)), 0)
    }

    func testStreakStopsAtStartDay() {
        let start = monday.adding(2)
        let sut = history(start: start, done: days(-5...4, from: monday))
        XCTAssertEqual(sut.currentStreak(today: monday.adding(4)), 3)
    }

    func testEmptyHistory() {
        let sut = history(start: monday, done: [])
        XCTAssertEqual(sut.currentStreak(today: monday), 0)
        XCTAssertEqual(sut.bestStreak(today: monday), 0)
        XCTAssertNil(sut.weekRate(weekStart: monday, today: monday.adding(-1)).fraction)
    }

    func testStreakAcrossLeapDay() {
        let today = Day(year: 2024, month: 3, day: 1)
        let done = days(-3...0, from: today) // 27, 28, 29 Feb and 1 Mar
        let sut = history(start: Day(year: 2024, month: 1, day: 1), done: done)
        XCTAssertEqual(sut.currentStreak(today: today), 4)
    }

    func testStreakAcrossYearBoundary() {
        let today = Day(year: 2026, month: 1, day: 2)
        let sut = history(start: Day(year: 2025, month: 12, day: 1), done: days(-3...0, from: today))
        XCTAssertEqual(sut.currentStreak(today: today), 4)
    }

    // MARK: Best streak

    func testBestStreakFindsLongestRun() {
        let start = monday.adding(-14)
        let done = days(0...2, from: start) + days(4...8, from: start) + days(12...13, from: start)
        let sut = history(start: start, done: done)
        XCTAssertEqual(sut.bestStreak(today: start.adding(13)), 5)
        XCTAssertEqual(sut.currentStreak(today: start.adding(13)), 2)
    }

    func testBestStreakSkipsUnscheduledDays() {
        let done = [monday, monday.adding(2), monday.adding(4), monday.adding(7), monday.adding(9)]
        let sut = history(start: monday, weekdays: mwf, done: done)
        XCTAssertEqual(sut.bestStreak(today: monday.adding(10)), 5)
    }

    func testBestStreakIsZeroBeforeStart() {
        let sut = history(start: monday, done: [])
        XCTAssertEqual(sut.bestStreak(today: monday.adding(-1)), 0)
    }

    // MARK: Weekly percentage

    func testCurrentWeekCountsOnlyDaysSoFar() {
        let sut = history(start: monday.adding(-7), done: [monday, monday.adding(2)])
        let rate = sut.weekRate(weekStart: monday, today: monday.adding(2))
        XCTAssertEqual(rate, CompletionRate(done: 2, total: 3))
    }

    func testPastWeekWithSpecificDays() {
        let sut = history(start: monday.adding(-7), weekdays: mwf, done: [monday, monday.adding(4), monday.adding(5)])
        let rate = sut.weekRate(weekStart: monday, today: monday.adding(20))
        // Saturday's tick is not scheduled, so it doesn't count.
        XCTAssertEqual(rate, CompletionRate(done: 2, total: 3))
        XCTAssertEqual(rate.fraction ?? 0, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testWeekWithNothingScheduledHasNoPercentage() {
        let sut = history(start: monday.adding(5), weekdays: mwf, done: [])
        let rate = sut.weekRate(weekStart: monday, today: monday.adding(6))
        XCTAssertEqual(rate.total, 0)
        XCTAssertNil(rate.fraction)
        XCTAssertEqual(rate.percentText, "–")
    }

    func testOverallRateAddsHabitsTogether() {
        let total = CompletionRate(done: 2, total: 3) + CompletionRate(done: 5, total: 7) + CompletionRate()
        XCTAssertEqual(total, CompletionRate(done: 7, total: 10))
        XCTAssertEqual(total.fraction ?? 0, 0.7, accuracy: 0.0001)
    }

    func testMonthRateInLeapFebruary() {
        let start = Day(year: 2024, month: 2, day: 1)
        let sut = history(start: start, done: days(0...28, from: start))
        XCTAssertEqual(sut.monthRate(monthStart: start, today: Day(year: 2024, month: 3, day: 5)), CompletionRate(done: 29, total: 29))
    }

    // MARK: Schedule changes

    func testScheduleChangeKeepsPastHistory() {
        let lastMonday = monday.adding(-7)
        let schedule = [ScheduleChange(start: lastMonday, days: .all), ScheduleChange(start: monday, days: mwf)]
        let done = days(0...6, from: lastMonday) + [monday, monday.adding(2)]
        let sut = history(start: lastMonday, done: done, schedule: schedule)

        XCTAssertTrue(sut.isScheduled(lastMonday.adding(1)), "Last Tuesday used the old every-day schedule")
        XCTAssertFalse(sut.isScheduled(monday.adding(1)), "This Tuesday uses the new schedule")
        XCTAssertEqual(sut.weekRate(weekStart: lastMonday, today: monday.adding(2)), CompletionRate(done: 7, total: 7))
        XCTAssertEqual(sut.currentStreak(today: monday.adding(2)), 9)
    }

    func testUpdatedScheduleAppendsFromTheGivenDay() {
        let original = [ScheduleChange(start: monday, days: .all)]
        let updated = HabitHistory.updatedSchedule(original, with: mwf, from: monday.adding(3))
        XCTAssertEqual(updated, [ScheduleChange(start: monday, days: .all), ScheduleChange(start: monday.adding(3), days: mwf)])
    }

    func testUpdatedScheduleOnSameDayReplacesInsteadOfStacking() {
        let original = [ScheduleChange(start: monday, days: .all), ScheduleChange(start: monday.adding(3), days: mwf)]
        let updated = HabitHistory.updatedSchedule(original, with: .workdays, from: monday.adding(3))
        XCTAssertEqual(updated, [ScheduleChange(start: monday, days: .all), ScheduleChange(start: monday.adding(3), days: .workdays)])
    }

    func testRevertingScheduleOnSameDayDropsTheChange() {
        let original = [ScheduleChange(start: monday, days: .all), ScheduleChange(start: monday.adding(3), days: mwf)]
        let updated = HabitHistory.updatedSchedule(original, with: .all, from: monday.adding(3))
        XCTAssertEqual(updated, [ScheduleChange(start: monday, days: .all)])
    }

    func testUnchangedScheduleIsLeftAlone() {
        let original = [ScheduleChange(start: monday, days: mwf)]
        XCTAssertEqual(HabitHistory.updatedSchedule(original, with: mwf, from: monday.adding(10)), original)
    }

    func testEditOnCreationDayReplacesFirstSchedule() {
        let original = [ScheduleChange(start: monday, days: .all)]
        XCTAssertEqual(HabitHistory.updatedSchedule(original, with: mwf, from: monday), [ScheduleChange(start: monday, days: mwf)])
    }

    // MARK: Day state

    func testDayStates() {
        let sut = history(start: monday, weekdays: mwf, done: [monday])
        let today = monday.adding(2)
        XCTAssertEqual(DayState(day: monday, history: sut, today: today), .done)
        XCTAssertEqual(DayState(day: monday.adding(1), history: sut, today: today), .unscheduled)
        XCTAssertEqual(DayState(day: monday.adding(2), history: sut, today: today), .open)
        XCTAssertEqual(DayState(day: monday.adding(4), history: sut, today: today), .upcoming)
        XCTAssertEqual(DayState(day: monday.adding(-2), history: sut, today: today), .unscheduled, "Before the habit started")
    }
}
