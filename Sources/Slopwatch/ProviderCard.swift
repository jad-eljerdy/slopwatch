import SwiftUI

struct ProviderCard: View {
    let provider: Provider
    let report: ProviderReport
    let now: Date
    let loading: Bool
    let settings: SettingsPreferences
    let details: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                ProviderIcon(provider: provider, size: 28)
                Text(provider.rawValue).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(report.connection.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Button(action: details) { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(provider.rawValue + " source details")
            }
            let windows = report.quota.windows.filter { $0.isCurrent(at: now) }
            if !windows.isEmpty && report.connection == .subscription {
                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                    QuotaMeter(window: window, provider: provider, now: now, display: settings.display, showResets: settings.showResets)
                }
            } else {
                Text(statusText).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if report.connection == .subscription, let inventory = report.quota.bankedResets,
               inventory.hasBankedResets(at: now), let summary = inventory.summary(at: now) {
                Button(action: details) {
                    HStack(spacing: 5) {
                        Image(systemName: "ticket")
                        Text(summary).fontWeight(.semibold)
                        Spacer()
                        if let expiry = inventory.active(at: now).first?.expires {
                            Text("Expires " + expiry.formatted(.dateTime.month().day())).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                    .font(.caption).padding(7)
                    .background(provider.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, 5)
    }
}

extension ProviderCard {
    private var statusText: String {
        if loading { return "Reading local usage…" }
        switch report.connection {
        case .missing: return "Install the CLI to connect this subscription."
        case .signedOut: return "Sign in with the \(provider.rawValue) CLI to see limits."
        case .api: return "The CLI uses API credentials."
        case .unavailable: return "The CLI did not return its sign-in status."
        default: break
        }
        if report.quota.observed != .distantPast {
            return "Reading expired · " + report.quota.observed.formatted(date: .abbreviated, time: .shortened)
        }
        return provider == .codex ? "Waiting for a Codex limit reading." : "Claude Code returned no limits. Select Refresh usage to retry."
    }
}
