import SwiftUI
import Sparkle

struct DashboardFooter: View {
    let model: DashboardModel
    let openSettings: () -> Void
    @State private var showIssues = false

    var body: some View {
        VStack(spacing: 9) {
            usageControls
            if let updater = model.updater {
                AppUpdateRow(updater: updater)
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private var usageControls: some View {
        HStack(spacing: 8) {
            if model.refreshing {
                ProgressView().controlSize(.mini)
                Text("Reading local usage")
            } else {
                Image(systemName: "lock.fill").font(.system(size: 9))
                if let date = model.snapshot.updated { Text("Updated " + date.formatted(date: .omitted, time: .shortened)) }
            }
            if !model.snapshot.issues.isEmpty {
                Button { showIssues.toggle() } label: { Image(systemName: "exclamationmark.triangle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.orange).accessibilityLabel("Incomplete usage data")
                    .popover(isPresented: $showIssues) {
                        Text(model.snapshot.issues.joined(separator: "\n")).padding().frame(maxWidth: 280)
                    }
            }
            Spacer()
            Button { model.refresh(force: true) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).disabled(model.refreshing).help("Refresh usage (⌘R)")
                .keyboardShortcut("r").accessibilityLabel("Refresh usage")
            Menu {
                Button("Settings…", action: openSettings).keyboardShortcut(",")
                Divider()
                if let updater = model.updater {
                    Button("Check for Updates…") { updater.checkForUpdates() }
                    AutomaticUpdatesToggle(updater: updater, title: "Update Automatically")
                    Divider()
                }
                Button("Quit Slopwatch") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("Slopwatch options")
        }
    }
}

private struct AppUpdateRow: View {
    let updater: SPUUpdater
    @State private var canCheck = false

    var body: some View {
        HStack {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            Text(version.map { "Slopwatch v" + $0 } ?? "Slopwatch")
            Spacer()
            Button("Check for Updates…") { updater.checkForUpdates() }
                .controlSize(.small)
                .disabled(!canCheck)
                .help("Check the signed release feed for a newer version")
        }
        .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheck = $0 }
    }
}

struct AutomaticUpdatesToggle: View {
    let updater: SPUUpdater
    let title: String
    @State private var enabled = false

    var body: some View {
        Toggle(title, isOn: Binding(get: { enabled }, set: { value in
            updater.automaticallyChecksForUpdates = value
            updater.automaticallyDownloadsUpdates = value
            enabled = value
        }))
        .onReceive(updater.publisher(for: \.automaticallyChecksForUpdates)
            .combineLatest(updater.publisher(for: \.automaticallyDownloadsUpdates))) { checks, downloads in
            enabled = checks && downloads
        }
    }
}
