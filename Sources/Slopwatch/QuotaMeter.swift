import SwiftUI

struct QuotaMeter: View {
    let window: Limit
    let provider: Provider
    let now: Date

    let display: LimitDisplay
    let showResets: Bool
    private var percent: Double { display.percent(used: window.used) }

    var body: some View {
        HStack(spacing: 8) {
            Text(window.title).font(.system(size: 11, weight: .medium)).frame(minWidth: 46, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.09))
                    Capsule().fill(window.used >= 90 ? Color.orange : provider.tint)
                        .frame(width: geometry.size.width * percent / 100)
                }
            }.frame(height: 5)
            Text((percent / 100).formatted(.percent.precision(.fractionLength(0))) + " " + display.suffix)
                .font(.system(size: 11, weight: .semibold).monospacedDigit()).frame(minWidth: 52, alignment: .trailing)
            if showResets, let reset = window.reset {
                Text(Display.reset(reset, now: now)).font(.system(size: 10)).foregroundStyle(.secondary)
                    .frame(minWidth: 62, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(window.title + " limit")
        .accessibilityValue("\(Int(percent.rounded())) percent \(display.suffix)" + (showResets ? window.reset.map { ", resets " + $0.formatted() } ?? "" : ""))
    }
}
