import SwiftUI

struct ActivityCard: View {
    let model: DashboardModel
    private var amount: Activity { model.snapshot.activity(model.interval, provider: model.provider) }
    private var ready: Bool { model.snapshot.updated != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                metric("Tokens", value: ready ? Display.tokens(amount.tokens) : "—", size: 37)
                    .help(amount.tokens.formatted() + " tokens")
                Spacer(minLength: 8)
                metric("API value", value: ready ? Display.estimate(amount) : "—", size: 24, alignment: .trailing)
                    .help("Estimated standard API token cost in USD. Subscription charges are separate.")
            }
            VStack(spacing: 6) {
                ActivityChart(codex: bins(.codex), claude: bins(.claude)).frame(height: 45)
                HStack {
                    Text(model.interval == .day ? "24 hours ago" : "\(model.interval.rawValue) days ago")
                    Spacer()
                    Text("Now")
                }.font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(16).background(Palette.ink, in: RoundedRectangle(cornerRadius: 15))
    }

    private func bins(_ source: Provider) -> [Int] {
        guard model.provider == nil || model.provider == source else { return Activity().bins }
        return model.snapshot.activity(model.interval, provider: source).bins
    }

    private func metric(_ label: String, value: String, size: CGFloat, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.system(size: size, weight: .medium, design: .rounded))
                .monospacedDigit().foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
        }.accessibilityElement(children: .combine)
    }
}
