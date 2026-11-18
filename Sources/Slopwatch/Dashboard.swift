import SwiftUI

struct Dashboard: View {
    let model: DashboardModel
    @State private var detail: Provider?

    var body: some View {
        Group {
            if let detail {
                SourceDetails(provider: detail, model: model) { self.detail = nil }
            } else {
                overview
            }
        }
        .frame(width: 380)
        .onAppear { model.refreshIfNeeded() }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                WatchMark().stroke(style: StrokeStyle(lineWidth: 2.1, lineCap: .round)).frame(width: 22, height: 22)
                Text("Slopwatch").font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                RangeControl(model: model)
            }
            VStack(alignment: .leading, spacing: 8) {
                ProviderFilter(model: model)
                ActivityCard(model: model)
                if activity.unpriced > 0 {
                    Text(Display.tokens(activity.unpriced) + " tokens have no published rate in this catalog.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                Caption(text: "Subscription limits")
                Spacer()
                Text("Used · Resets").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                ForEach(Provider.allCases) { provider in
                    if model.provider == nil || model.provider == provider {
                        ProviderCard(provider: provider, report: model.snapshot.reports[provider] ?? ProviderReport(),
                            now: Date(), loading: model.snapshot.updated == nil) { detail = provider }
                        if provider == .codex && model.provider == nil { Divider() }
                    }
                }
            }
            Divider()
            DashboardFooter(model: model)
        }.padding(16)
    }

    private var activity: Activity { model.snapshot.activity(model.interval, provider: model.provider) }
}
