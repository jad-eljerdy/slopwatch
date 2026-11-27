import SwiftUI

struct QuotaMeter: View {
    let window: Limit
    let provider: Provider
    let activity: Activity
    let interval: Interval
    let activityEnd: Date?
    let now: Date

    @State private var showing = false
    @State private var closeTask: Task<Void, Never>?

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
        .contentShape(Rectangle())
        .onHover(perform: hover)
        .onTapGesture { showing = true }
        .focusable()
        .onKeyPress(.return) { showing = true; return .handled }
        .accessibilityAction { showing = true }
        .popover(isPresented: $showing, arrowEdge: .trailing) {
            ModelUsageChart(activity: activity.forLimit(window.title), interval: interval, end: activityEnd,
                            provider: provider, limit: window)
                .onHover(perform: hover)
        }
        .onDisappear { closeTask?.cancel(); showing = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(window.title + " limit")
        .accessibilityValue("\(Int(percent.rounded())) percent \(display.suffix)" + (showResets ? window.reset.map { ", resets " + $0.formatted() } ?? "" : ""))
    }

    private func hover(_ inside: Bool) {
        closeTask?.cancel()
        if inside {
            showing = true
        } else {
            // Allow the pointer to cross the popover arrow before closing it.
            closeTask = Task {
                do { try await Task.sleep(for: .milliseconds(190)) } catch { return }
                showing = false
            }
        }
    }
}
