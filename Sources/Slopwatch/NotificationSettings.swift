import SwiftUI
import UserNotifications

struct NotificationSettings: View {
    let model: DashboardModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Notify me before a banked reset expires", isOn: $settings.resetRemindersEnabled)
                    .onChange(of: settings.resetRemindersEnabled) {
                        model.notifications.refresh(requestPermission: settings.resetRemindersEnabled)
                    }
                Picker("Remind me", selection: $settings.reminderLead) {
                    ForEach(ReminderLead.allCases, id: \.self) { lead in
                        Text(lead == .one ? "1 hour before expiry" : "\(lead.rawValue) hours before expiry").tag(lead)
                    }
                }
                .disabled(!settings.resetRemindersEnabled)
                .onChange(of: settings.reminderLead) { model.notifications.refresh() }
            } header: {
                Text("Banked resets")
            } footer: {
                Text("Slopwatch can send a reminder when Codex or Claude reports an expiry date. If a reset is already within the reminder period, you receive one alert when Slopwatch detects it.")
            }
            Section("macOS notifications") {
                switch model.notifications.authorization {
                case .authorized, .provisional:
                    LabeledContent("Permission", value: "Allowed")
                case .denied:
                    LabeledContent("Permission", value: "Blocked")
                    Link("Open Notification Settings", destination: URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                case .notDetermined:
                    Button("Allow notifications…") { model.notifications.refresh(requestPermission: true) }
                        .disabled(!settings.resetRemindersEnabled)
                default:
                    Text("Checking permission…")
                }
                if let error = model.notifications.errorMessage { Text(error).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.notifications.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.notifications.refresh()
        }
    }
}
