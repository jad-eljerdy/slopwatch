import SwiftUI

struct ProviderCard: View {
    let provider: Provider
    let report: ProviderReport
    let interval: Interval
    let activityEnd: Date?
    let now: Date
    let loading: Bool
    let settings: SettingsPreferences
    let pageBalance: ClaudePageBalance?
    let details: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                ProviderIcon(provider: provider, size: 28)
                Text(provider.rawValue).font(.system(size: 14, weight: .semibold))
                if let plan = report.planLabel {
                    Text(plan)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1).truncationMode(.tail)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(provider.tint.opacity(0.18), in: Capsule())
                        .help(plan + " plan").accessibilityLabel(plan + " plan")
                }
                Spacer(minLength: 2)
                Text(report.connection.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                Button(action: details) { Image(systemName: "info.circle") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(provider.rawValue + " source details")
            }
            let windows = report.quota.windows.filter { $0.isCurrent(at: now) }
            if !windows.isEmpty && report.connection == .subscription {
                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                    QuotaMeter(window: window, provider: provider, activity: report.periods[interval] ?? Activity(),
                               interval: interval, activityEnd: activityEnd, now: now, display: settings.display, showResets: settings.showResets)
                }
            } else {
                Text(statusText).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if report.connection == .subscription {
                if let inventory = report.quota.bankedResets, let summary = inventory.summary(at: now) {
                    if inventory.hasBankedResets(at: now) {
                        let expiry = inventory.active(at: now).first?.expires
                        resetButton(summary, note: expiry.map { "Expires " + $0.formatted(.dateTime.month().day()) })
                    }
                } else if let balance = pageBalance, balance.isFresh(at: now), balance.count > 0 {
                    resetButton(balance.label, note: balance.source.rawValue + " · " + balance.seen.formatted(date: .omitted, time: .shortened))
                }
            }
        }.padding(.vertical, 5)
    }
}

extension ProviderCard {
    private func resetButton(_ summary: String, note: String?) -> some View {
        Button(action: details) {
            HStack(spacing: 5) {
                Image(systemName: "ticket")
                Text(summary).fontWeight(.semibold)
                Spacer()
                if let note { Text(note).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").imageScale(.small)
            }.font(.caption).padding(7)
                .background(provider.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
    }

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
