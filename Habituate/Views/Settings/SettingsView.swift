import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<Habit> { $0.isSample == true }) private var sampleHabits: [Habit]
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var confirmingSampleRemoval = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Notifications", value: statusText)
                    if notificationStatus == .denied {
                        NotificationsDeniedNote()
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Turn on a reminder for any habit in its edit screen.")
                }

                if !sampleHabits.isEmpty {
                    Section {
                        Button("Remove Sample Habits", role: .destructive) {
                            confirmingSampleRemoval = true
                        }
                        .accessibilityIdentifier("removeSamples")
                    } header: {
                        Text("Sample Data")
                    } footer: {
                        Text("Habituate started with example habits so you can try it out. Removing them keeps any habits you added yourself.")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Remove the sample habits?",
                isPresented: $confirmingSampleRemoval,
                titleVisibility: .visible
            ) {
                Button("Remove \(sampleHabits.count) Sample Habits", role: .destructive) {
                    withAnimation { store.removeSampleHabits() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone. Habits you added yourself are kept.")
            }
            .task { await refreshStatus() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await refreshStatus() }
                }
            }
        }
    }

    private var statusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "On"
        case .denied: "Off"
        default: "Not set up"
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func refreshStatus() async {
        notificationStatus = await store.reminders.authorizationStatus()
    }
}
