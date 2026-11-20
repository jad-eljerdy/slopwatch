import AppKit
import SwiftUI

@MainActor
enum SettingsWindow {
    static func make(model: DashboardModel) -> NSWindow {
        let tabs = NSTabViewController()
        tabs.title = "Slopwatch Settings"
        tabs.canPropagateSelectedChildViewControllerTitle = false
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab("General", symbol: "gearshape", view: GeneralSettings(model: model)))
        tabs.addTabViewItem(tab("Notifications", symbol: "bell", view: NotificationSettings(model: model)))
        tabs.addTabViewItem(tab("About", symbol: "info.circle", view: AboutSettings()))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.title = "Slopwatch Settings"
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("SlopwatchSettings")
        window.setContentSize(NSSize(width: 482, height: 430))
        return window
    }

    private static func tab(_ title: String, symbol: String, view: some View) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: NSHostingController(rootView: view))
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

private struct GeneralSettings: View {
    let model: DashboardModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Subscription checks") {
                Picker("Check limits every", selection: Binding(
                    get: { settings.checkInterval }, set: model.setCheckInterval
                )) {
                    ForEach(LimitCheckInterval.allCases, id: \.self) { interval in
                        Text(interval == .one ? "1 minute" : "\(interval.rawValue) minutes").tag(interval)
                    }
                }
            }
            Section("Menu bar") {
                Picker("Show in menu bar", selection: $settings.menuBarDisplay) {
                    ForEach(MenuBarDisplay.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                }
                ForEach(settings.menuBarDisplay.providers) { provider in
                    Picker(provider.rawValue + " limit", selection: provider == .claude ? $settings.claudeWindow : $settings.codexWindow) {
                        ForEach(MenuBarWindow.allCases, id: \.self) { window in Text(window.rawValue).tag(window) }
                    }
                }
            }
            Section("Menu bar panel") {
                Picker("Limit bars show", selection: $settings.display) {
                    ForEach(LimitDisplay.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
                }
                Toggle("Show limit reset times", isOn: $settings.showResets)
                Toggle(isOn: $settings.hideUnused) {
                    Text("Hide unused subscriptions")
                    Text("Only show connected providers in the limits list.")
                }
            }
            if let updater = model.updater {
                Section("Software updates") {
                    AutomaticUpdatesToggle(updater: updater, title: "Update Slopwatch automatically")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    private let info = Bundle.main.infoDictionary ?? [:]
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 76, height: 76).accessibilityHidden(true)
            Text("Slopwatch").font(.system(size: 29, weight: .bold, design: .rounded))
            Text("Version \(info["CFBundleShortVersionString"] as? String ?? "Development") · Build \(info["CFBundleVersion"] as? String ?? "—")")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            Text("Codex and Claude subscription usage in your menu bar.\nUsage history stays on your Mac.")
                .multilineTextAlignment(.center).lineSpacing(3).padding(.vertical, 6)
            Divider().frame(width: 230)
            Text("Created by Jad El Jerdy").font(.headline).padding(.top, 3)
            HStack(spacing: 18) {
                Link("jad.sh", destination: URL(string: "https://jad.sh")!)
                Link("Slopwatch on GitHub", destination: URL(string: "https://github.com/jad-eljerdy/slopwatch")!)
            }.font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
