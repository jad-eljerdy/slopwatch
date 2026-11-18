import SwiftUI

struct QuotaMeter: View {
    let window: Limit
    let provider: Provider
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            Text(window.title).font(.system(size: 11, weight: .medium)).frame(minWidth: 46, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.09))
                    Capsule().fill(window.used >= 90 ? Color.orange : provider.tint)
                        .frame(width: geometry.size.width * window.used / 100)
                }
            }.frame(height: 5)
            Text(window.used / 100, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 11, weight: .semibold).monospacedDigit()).frame(width: 35, alignment: .trailing)
            if let reset = window.reset {
                Text(Display.reset(reset, now: now)).font(.system(size: 10)).foregroundStyle(.secondary)
                    .frame(minWidth: 62, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(window.title + " limit")
        .accessibilityValue("\(Int(window.used.rounded())) percent used" + (window.reset.map { ", resets " + $0.formatted() } ?? ""))
        .help("Observed " + window.observed.formatted() + (window.reset.map { " · Resets " + $0.formatted() } ?? ""))
    }
}
