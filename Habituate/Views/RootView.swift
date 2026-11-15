import Combine
import SwiftUI

struct RootView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = Day.today()

    var body: some View {
        NavigationStack {
            WeekView()
        }
        .environment(\.today, today)
        .overlay(alignment: .bottom) {
            UndoToast()
                .padding(.bottom, 64)
        }
        .sensoryFeedback(.success, trigger: store.completionCount)
        .sensoryFeedback(.impact(weight: .light), trigger: store.uncompletionCount)
        .preferredColorScheme(LaunchOptions.colorScheme)
        .task { prepareData() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshToday()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshToday()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange).receive(on: RunLoop.main)) { _ in
            NSTimeZone.resetSystemTimeZone()
            refreshToday()
        }
    }

    /// "Today" is re-read at midnight, on time zone or clock changes, and whenever the app comes back to the foreground.
    private func refreshToday() {
        let now = Day.today()
        if now != today {
            today = now
        }
    }

    private func prepareData() {
        if LaunchOptions.isUITesting {
            if LaunchOptions.seedsSampleHabitsForUITests && store.habits().isEmpty {
                store.addSampleHabits(today: today)
            }
        } else if !LaunchOptions.isUnitTesting {
            store.seedSampleHabitsIfNeeded(today: today)
            store.reminders.resync(store.habits())
        }
    }
}

private struct TodayKey: EnvironmentKey {
    static var defaultValue: Day { Day.today() }
}

extension EnvironmentValues {
    /// The current day, refreshed by `RootView`.
    var today: Day {
        get { self[TodayKey.self] }
        set { self[TodayKey.self] = newValue }
    }
}

struct StorageErrorView: View {
    var body: some View {
        ContentUnavailableView(
            "Can't Open Your Habits",
            systemImage: "exclamationmark.triangle",
            description: Text("Habituate couldn't open its storage. Close the app and open it again. If this keeps happening, free up some space on your iPhone.")
        )
    }
}
