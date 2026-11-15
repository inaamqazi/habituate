import Foundation

/// Completed versus scheduled days over some period.
struct CompletionRate: Equatable, Sendable {
    var done = 0
    var total = 0

    var fraction: Double? {
        total > 0 ? Double(done) / Double(total) : nil
    }

    var percentText: String {
        fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–"
    }

    static func + (lhs: CompletionRate, rhs: CompletionRate) -> CompletionRate {
        CompletionRate(done: lhs.done + rhs.done, total: lhs.total + rhs.total)
    }
}

/// A read-only view of one habit's schedule and ticks. All streak and percentage maths lives here.
struct HabitHistory: Sendable {
    let start: Day
    /// Ordered by `start`, oldest first.
    let schedule: [ScheduleChange]
    let completed: Set<Day>

    /// The weekdays that applied on `day`, using the schedule that was active then.
    func weekdays(on day: Day) -> WeekdaySet {
        schedule.last(where: { $0.start <= day })?.days ?? schedule.first?.days ?? .all
    }

    func isScheduled(_ day: Day) -> Bool {
        day >= start && weekdays(on: day).contains(day)
    }

    func isDone(_ day: Day) -> Bool {
        completed.contains(day)
    }

    /// Completed scheduled days in a row, ending today. Unscheduled days are skipped,
    /// and an unticked today does not break the streak until the day is over.
    func currentStreak(today: Day) -> Int {
        var streak = 0
        var day = today
        while day >= start {
            if isScheduled(day) {
                if isDone(day) {
                    streak += 1
                } else if day != today {
                    break
                }
            }
            day = day.adding(-1)
        }
        return streak
    }

    func bestStreak(today: Day) -> Int {
        guard start <= today else { return 0 }
        var best = 0
        var run = 0
        for day in start...today where isScheduled(day) {
            if isDone(day) {
                run += 1
                best = max(best, run)
            } else if day != today {
                run = 0
            }
        }
        return best
    }

    /// Only scheduled days up to and including today count, so the current week isn't penalised for days still to come.
    func completionRate(in days: some Sequence<Day>, today: Day) -> CompletionRate {
        var rate = CompletionRate()
        for day in days where day <= today && isScheduled(day) {
            rate.total += 1
            if isDone(day) { rate.done += 1 }
        }
        return rate
    }

    func weekRate(weekStart: Day, today: Day) -> CompletionRate {
        completionRate(in: weekStart..<weekStart.adding(7), today: today)
    }

    func monthRate(monthStart: Day, today: Day) -> CompletionRate {
        completionRate(in: monthStart..<monthStart.nextMonthStart, today: today)
    }

    /// Applies a schedule edit from `day` onwards without touching the schedule of earlier days.
    static func updatedSchedule(_ schedule: [ScheduleChange], with days: WeekdaySet, from day: Day) -> [ScheduleChange] {
        if schedule.last?.days == days { return schedule }
        var updated = schedule.filter { $0.start < day }
        if updated.last?.days != days {
            updated.append(ScheduleChange(start: day, days: days))
        }
        return updated
    }
}
