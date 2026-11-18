import SwiftUI

struct SourceDetails: View {
    let provider: Provider
    let model: DashboardModel
    let back: () -> Void
    private var report: ProviderReport { model.snapshot.reports[provider] ?? ProviderReport() }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: back) { Label("Overview", systemImage: "chevron.left") }.buttonStyle(.plain)
            Text(provider.rawValue).font(.system(size: 24, weight: .semibold))
            LabeledContent("CLI status", value: report.connection.rawValue)
            if let plan = report.quota.plan { LabeledContent("Last reported plan", value: plan) }
            if report.quota.observed != .distantPast {
                LabeledContent("Limit reading", value: report.quota.observed.formatted(date: .abbreviated, time: .shortened))
            }
            if !report.quota.windows.isEmpty {
                ForEach(Array(report.quota.windows.enumerated()), id: \.offset) { _, window in
                    let percent = (window.used / 100).formatted(.percent.precision(.fractionLength(0...1)))
                    LabeledContent(window.title, value: percent + " used at last reading")
                }
            }
            Divider()
            Text(provider == .codex ? "Codex records limits in local session logs. Use Codex to get a new reading."
                 : "Claude Code saves limits when you open /usage. Its status line can also share limits after a model response.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if provider == .claude { ClaudeCaptureButton(model: model) }
            Divider()
            Caption(text: "Local activity")
            ForEach(Interval.allCases) { range in
                let a = report.periods[range] ?? Activity()
                LabeledContent(range.label, value: Display.tokens(a.tokens) + " tokens · " + Display.estimate(a))
            }
        }.font(.system(size: 12)).padding(20).frame(width: 380)
    }
}
