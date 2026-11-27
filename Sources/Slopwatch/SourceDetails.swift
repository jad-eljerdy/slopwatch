import SwiftUI

struct SourceDetails: View {
    let provider: Provider
    let model: DashboardModel
    let back: () -> Void
    @State private var showSource = false
    private var report: ProviderReport { model.snapshot.reports[provider] ?? ProviderReport() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: back) { Label("Overview", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(report.connection == .subscription ? .green : .secondary).frame(width: 6, height: 6)
                    Text(report.connection.rawValue)
                }
                .accessibilityElement(children: .combine)
            }.font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ProviderIcon(provider: provider, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue).font(.system(size: 25, weight: .bold, design: .rounded))
                    if let plan = report.planLabel {
                        Text(plan).font(.callout).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            if !report.quota.windows.isEmpty {
                LimitDetails(provider: provider, quota: report.quota, settings: model.settings,
                             connected: report.connection == .subscription)
            }
            if report.connection == .subscription {
                ResetDetails(provider: provider, inventory: report.quota.bankedResets, now: Date(),
                    pageReader: provider == .claude ? model.claudePage : nil)
            }
            ActivityDetails(report: report)
            Divider()
            DisclosureGroup("Data source", isExpanded: $showSource) {
                VStack(alignment: .leading, spacing: 8) {
                    if report.quota.observed != .distantPast {
                        LabeledContent("Last reading", value: report.quota.observed.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text(provider == .codex ? "Codex writes limit readings to its local session logs."
                         : "Slopwatch reads subscription limits from your signed-in Claude Code CLI.")
                    if provider == .claude { ClaudeCaptureButton(model: model) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 5)
            }.font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

}

private struct LimitDetails: View {
    let provider: Provider
    let quota: Quota
    let settings: SettingsPreferences
    let connected: Bool
    private let now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(quota.windows.enumerated()), id: \.offset) { index, window in
                let current = connected && window.isCurrent(at: now)
                let percent = settings.display.percent(used: window.used)
                if index > 0 { Divider().overlay(.white.opacity(0.18)) }
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(window.title + " limit").font(.headline)
                        Spacer()
                        Text((percent / 100).formatted(.percent.precision(.fractionLength(0...1))))
                            .font(.system(size: 25, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text(settings.display.suffix).font(.callout)
                    }
                    GeometryReader { proxy in
                        Capsule().fill(.white.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule().fill(current ? provider.tint : Color.gray)
                                    .frame(width: proxy.size.width * percent / 100)
                            }
                    }.frame(height: 5).accessibilityHidden(true)
                    if !current { Text("At last reading").font(.caption).foregroundStyle(.white.opacity(0.82)) }
                    else if settings.showResets, let reset = window.reset {
                        Text("Resets " + reset.formatted(date: .abbreviated, time: .shortened))
                            .font(.callout).foregroundStyle(.white.opacity(0.82))
                    }
                }.accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .foregroundStyle(.white)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct ActivityDetails: View {
    let report: ProviderReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local activity").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Period")
                    Text("Tokens").gridColumnAlignment(.trailing)
                    Text("API value").gridColumnAlignment(.trailing)
                }.font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Divider()
                ForEach(Interval.allCases) { range in
                    let activity = report.periods[range] ?? Activity()
                    GridRow {
                        Text(range.durationLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Display.tokens(activity.tokens))
                        Text(Display.estimate(activity)).fontWeight(.medium)
                    }
                    .font(.system(size: 13)).monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(range.label), \(Display.tokens(activity.tokens)) tokens, API value \(Display.estimate(activity))")
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
