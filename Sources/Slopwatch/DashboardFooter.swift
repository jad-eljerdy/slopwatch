import SwiftUI

struct DashboardFooter: View {
    let model: DashboardModel
    @State private var showIssues = false

    var body: some View {
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
                Button("Quit Slopwatch") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("Slopwatch options")
        }.font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
