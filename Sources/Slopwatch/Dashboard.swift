import SwiftUI

struct Dashboard: View {
    let model: DashboardModel
    let openSettings: () -> Void
    @State private var detail: Provider?
    @State private var hoveredInfo: Provider?
    @State private var hoveredChart: Provider?
    @State private var tooltip: Provider?

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
                Text(model.settings.display.rawValue + (model.settings.showResets ? " · Resets" : "")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                ForEach(visibleProviders) { provider in
                    if provider != visibleProviders.first { Divider() }
                    ProviderCard(provider: provider, report: model.snapshot.reports[provider] ?? ProviderReport(),
                        now: Date(), loading: model.snapshot.updated == nil, settings: model.settings,
                        pageBalance: provider == .claude ? model.claudePage.balance : nil,
                        infoHover: { inside in
                            if inside { hoveredInfo = provider }
                            else if hoveredInfo == provider { hoveredInfo = nil }
                        }) { clearTooltip(); detail = provider }
                }
                if visibleProviders.isEmpty {
                    Text("No connected subscriptions.")
                        .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Divider()
            DashboardFooter(model: model, openSettings: openSettings)
        }.padding(16)
        .overlayPreferenceValue(ProviderInfoBounds.self) { anchors in
            if let tooltip, let anchor = anchors[tooltip] {
                GeometryReader { geometry in
                    let button = geometry[anchor]
                    Color.clear.allowsHitTesting(false)
                        .overlay(alignment: .topLeading) {
                            ModelUsageChart(activity: model.snapshot.activity(model.interval, provider: tooltip),
                                            interval: model.interval, provider: tooltip)
                                .fixedSize(horizontal: false, vertical: true)
                                .onHover { inside in
                                    if inside { hoveredChart = tooltip }
                                    else if hoveredChart == tooltip { hoveredChart = nil }
                                }
                                .alignmentGuide(.leading) { size in -max(4, button.minX - size.width - 4) }
                                .alignmentGuide(.top) { size in -max(4, button.maxY - size.height) }
                        }
                }
            }
        }
        .task(id: hoveredInfo ?? hoveredChart) {
            let target = hoveredInfo ?? hoveredChart
            guard target != tooltip else { return }
            do { try await Task.sleep(for: .milliseconds(target == nil ? 400 : 220)) } catch { return }
            tooltip = target
        }
        .onChange(of: model.provider) { clearTooltip() }
        .onDisappear { clearTooltip() }
    }

    private func clearTooltip() {
        hoveredInfo = nil
        hoveredChart = nil
        tooltip = nil
    }

    private var visibleProviders: [Provider] {
        Provider.allCases.filter { provider in
            (model.provider == nil || model.provider == provider) &&
                model.settings.shows(model.snapshot.reports[provider]?.connection ?? .checking)
        }
    }

    private var activity: Activity { model.snapshot.activity(model.interval, provider: model.provider) }
}

struct ProviderInfoBounds: PreferenceKey {
    static var defaultValue: [Provider: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [Provider: Anchor<CGRect>], nextValue: () -> [Provider: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}
