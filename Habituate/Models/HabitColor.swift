import SwiftUI

enum HabitColor: String, CaseIterable, Identifiable, Sendable {
    case red, orange, green, teal, blue, indigo, purple, pink, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }

    var displayName: String { rawValue.capitalized }
}
