import SwiftUI

/// The habit's emoji on a tinted circle, or its first letter when it has no emoji. Shared with the widget.
struct HabitIcon: View {
    let emoji: String
    let name: String
    let color: HabitColor
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(color.color.opacity(0.18))
            if emoji.isEmpty {
                Text(name.first.map { String($0).uppercased() } ?? "")
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.color)
            } else {
                Text(emoji)
                    .font(.system(size: size * 0.55))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
