import SwiftData
import SwiftUI

@main
@MainActor
struct HabituateApp: App {
    private let store: HabitStore?

    init() {
        let container = try? HabitStoreFactory.makeContainer(inMemory: LaunchOptions.usesInMemoryStore)
        store = container.map {
            HabitStore(container: $0, reminders: ReminderScheduler(isActive: LaunchOptions.remindersEnabled))
        }
    }

    var body: some Scene {
        WindowGroup {
            if let store {
                RootView()
                    .environment(store)
                    .modelContainer(store.container)
            } else {
                StorageErrorView()
            }
        }
    }
}

/// Switches used by the automated tests. Normal launches use none of them.
enum LaunchOptions {
    private static let arguments = ProcessInfo.processInfo.arguments

    static let isUITesting = arguments.contains("-uiTesting")
    static let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    static var usesInMemoryStore: Bool { isUITesting || isUnitTesting }
    static var remindersEnabled: Bool { !usesInMemoryStore }
    static var seedsSampleHabitsForUITests: Bool { isUITesting && arguments.contains("-seedSamples") }
    static var colorScheme: ColorScheme? { arguments.contains("-darkMode") ? .dark : nil }
}
