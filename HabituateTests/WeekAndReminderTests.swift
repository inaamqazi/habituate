import XCTest
@testable import Habituate

final class WeekViewModelTests: XCTestCase {
    private let sunday = Day(year: 2026, month: 11, day: 15)

    func testNavigationIsBoundedByHistoryAndToday() {
        let week = WeekViewModel()
        let earliest = sunday.adding(-14)
        XCTAssertEqual(week.weekStart(today: sunday), Day(year: 2026, month: 11, day: 9))
        XCTAssertFalse(week.canGoForward)
        XCTAssertTrue(week.canGoBack(today: sunday, earliestStart: earliest))

        week.goBack()
        week.goBack()
        XCTAssertEqual(week.weekStart(today: sunday), Day(year: 2026, month: 10, day: 26))
        XCTAssertFalse(week.canGoBack(today: sunday, earliestStart: earliest))
        XCTAssertTrue(week.canGoForward)

        week.goToCurrentWeek()
        XCTAssertTrue(week.isCurrentWeek)
        week.goForward()
        XCTAssertEqual(week.offset, 0, "Can't go past the current week")
        XCTAssertFalse(week.canGoBack(today: sunday, earliestStart: nil))
    }

    func testCurrentWeekFollowsMidnightIntoANewWeek() {
        let week = WeekViewModel()
        XCTAssertEqual(week.weekStart(today: sunday), Day(year: 2026, month: 11, day: 9))
        XCTAssertEqual(week.weekStart(today: sunday.adding(1)), Day(year: 2026, month: 11, day: 16))
        XCTAssertEqual(week.days(today: sunday.adding(1)).last, Day(year: 2026, month: 11, day: 22))
    }

    func testTitles() {
        let week = WeekViewModel()
        XCTAssertEqual(week.title(today: sunday), "This Week")
        week.goBack()
        XCTAssertEqual(week.title(today: sunday), "Last Week")
        week.goBack()
        XCTAssertFalse(week.title(today: sunday).isEmpty)
        XCTAssertNotEqual(week.title(today: sunday), "Last Week")
    }

    func testWeekSpanningNewYear() {
        let week = WeekViewModel()
        let newYearsDay = Day(year: 2025, month: 1, day: 1)
        let days = week.days(today: newYearsDay)
        XCTAssertEqual(days.first, Day(year: 2024, month: 12, day: 30))
        XCTAssertEqual(days.last, Day(year: 2025, month: 1, day: 5))
        XCTAssertTrue(week.rangeText(today: newYearsDay).contains("2025") || week.rangeText(today: newYearsDay).contains("2024"))
    }
}

@MainActor
final class ReminderPlanTests: XCTestCase {
    private func habit(weekdays: WeekdaySet, minutes: Int = 7 * 60 + 30) -> Habit {
        let habit = Habit(name: "Stretch", emoji: "🧘", weekdays: weekdays, start: Day(year: 2026, month: 11, day: 9))
        habit.reminderMinutes = minutes
        return habit
    }

    func testDailyReminderIsOneTrigger() {
        let plan = ReminderPlan(habit: habit(weekdays: .all))
        XCTAssertEqual(plan.title, "🧘 Stretch")
        XCTAssertEqual(plan.triggers.count, 1)
        XCTAssertEqual(plan.triggers.first?.components.hour, 7)
        XCTAssertEqual(plan.triggers.first?.components.minute, 30)
        XCTAssertNil(plan.triggers.first?.components.weekday)
    }

    func testSpecificDaysMapToCalendarWeekdays() {
        let plan = ReminderPlan(habit: habit(weekdays: WeekdaySet(indices: [0, 2, 6])))
        // Calendar weekdays: 1 = Sunday, 2 = Monday, 4 = Wednesday.
        XCTAssertEqual(plan.triggers.compactMap { $0.components.weekday }, [2, 4, 1])
    }

    func testIdentifiersCoverEveryTrigger() {
        let plan = ReminderPlan(habit: habit(weekdays: .workdays))
        let all = Set(ReminderPlan.identifiers(for: plan.habitID))
        XCTAssertTrue(plan.triggers.allSatisfy { all.contains($0.identifier) })
        XCTAssertEqual(plan.requests().count, 5)
    }
}
