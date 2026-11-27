import SwiftUI

struct ActivityCard: View {
    let model: DashboardModel
    private var ready: Bool { model.snapshot.updated != nil }

    var body: some View {
        let amount = model.snapshot.activity(model.interval, provider: model.provider)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                metric("Tokens", value: ready ? Display.tokens(amount.tokens) : "—", size: 37)
                    .help(amount.tokens.formatted() + " tokens")
                Spacer(minLength: 8)
                metric("API value", value: ready ? Display.estimate(amount) : "—", size: 24, alignment: .trailing)
                    .help("Estimated standard API token cost in USD. Subscription charges are separate.")
            }
            ActivityChart(activity: amount, interval: model.interval, end: model.snapshot.updated,
                          modelNames: modelNames)
        }
        .padding(16).background(Palette.ink, in: RoundedRectangle(cornerRadius: 15))
    }

    // Keep model colors consistent across the provider and time range controls.
    private var modelNames: [String] {
        Set(model.snapshot.reports.values.flatMap { report in
            report.periods[.month]?.modelBins.keys.map { $0 } ?? []
        }).sorted()
    }

    private func metric(_ label: String, value: String, size: CGFloat, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.system(size: size, weight: .medium, design: .rounded))
                .monospacedDigit().foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }.accessibilityElement(children: .combine)
    }
}
