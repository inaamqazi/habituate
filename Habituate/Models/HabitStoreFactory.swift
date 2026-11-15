import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.habituate.app"
}

enum HabitStoreFactory {
    /// The store lives in the App Group so the widget can read it. `nil` when the App Group
    /// capability is missing (for example on a free Apple developer account).
    static var sharedStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appending(path: "Habituate.store")
    }

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([Habit.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let storeURL = url ?? sharedStoreURL {
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
