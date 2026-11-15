import SwiftUI

/// Which week the main grid shows.
@Observable
final class WeekViewModel {
    /// Weeks relative to the current one: 0 = this week, -1 = last week. An offset rather than a date,
    /// so the grid moves on to the new week by itself when midnight passes on a Sunday.
    private(set) var offset = 0
    private(set) var transitionEdge: Edge = .trailing

    var isCurrentWeek: Bool { offset == 0 }
    var canGoForward: Bool { offset < 0 }

    func weekStart(today: Day) -> Day {
        today.weekStart.adding(offset * 7)
    }

    func days(today: Day) -> [Day] {
        let start = weekStart(today: today)
        return (0..<7).map { start.adding($0) }
    }

    /// History can be browsed back to the week the oldest habit started.
    func canGoBack(today: Day, earliestStart: Day?) -> Bool {
        guard let earliestStart else { return false }
        return weekStart(today: today) > earliestStart.weekStart
    }

    func goBack() {
        transitionEdge = .leading
        offset -= 1
    }

    func goForward() {
        guard canGoForward else { return }
        transitionEdge = .trailing
        offset += 1
    }

    func goToCurrentWeek() {
        transitionEdge = .trailing
        offset = 0
    }

    func title(today: Day) -> String {
        switch offset {
        case 0: "This Week"
        case -1: "Last Week"
        default: rangeText(today: today)
        }
    }

    func rangeText(today: Day) -> String {
        let start = weekStart(today: today)
        let end = start.adding(6)
        let formatter = DateIntervalFormatter()
        formatter.dateTemplate = start.year == today.year && end.year == today.year ? "MMMd" : "MMMdy"
        return formatter.string(from: start.date(), to: end.date())
    }
}
