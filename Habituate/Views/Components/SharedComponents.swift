import SwiftUI

extension Day {
    var accessibilityName: String {
        date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var monthTitle: String {
        date().formatted(.dateTime.month(.wide).year())
    }
}

/// Shown after a delete; Undo puts the habit back exactly as it was.
struct UndoToast: View {
    @Environment(HabitStore.self) private var store

    var body: some View {
        VStack {
            if let deleted = store.recentlyDeleted {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Deleted “\(deleted.name)”")
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Button("Undo") {
                        withAnimation { store.undoDelete() }
                    }
                    .font(.subheadline.bold())
                    .accessibilityIdentifier("undoDelete")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    AccessibilityNotification.Announcement("Deleted \(deleted.name). Undo is available.").post()
                }
            }
        }
        .animation(.snappy, value: store.recentlyDeleted?.id)
    }
}

/// Explains how to turn notifications back on after the user said no.
struct NotificationsDeniedNote: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications are turned off", systemImage: "bell.slash")
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("notificationsDeniedNote")
            Text("To get reminders, tap Open Settings and turn on Allow Notifications. You can also find this in Settings › Notifications › Habituate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
