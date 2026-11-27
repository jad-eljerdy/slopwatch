import SwiftUI

struct ActivityChart: View {
    let activity: Activity
    let interval: Interval
    let end: Date?
    let modelNames: [String]

    @State private var selected: Int?
    @FocusState private var focused: Bool

    private struct Series: Identifiable {
        let id: String
        let counts: [Int]
        let total: Int
        let color: Color
    }

    private static let colors: [Color] = [
        Color(red: 0.41, green: 0.86, blue: 0.77), Color(red: 1, green: 0.69, blue: 0.48),
        Color(red: 0.62, green: 0.72, blue: 1), Color(red: 0.92, green: 0.74, blue: 0.98),
        Color(red: 0.92, green: 0.84, blue: 0.50), Color(red: 0.55, green: 0.81, blue: 0.98)
    ]

    private func seriesColor(_ index: Int) -> Color {
        if index < Self.colors.count { return Self.colors[index] }
        // Space extra model hues around the color wheel without repeating the palette.
        let hue = (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: 0.49, brightness: 0.95)
    }

    var body: some View {
        let series = modelNames.enumerated().compactMap { index, name -> Series? in
            guard let counts = activity.modelBins[name] else { return nil }
            return Series(id: name, counts: counts, total: counts.reduce(0, +),
                          color: seriesColor(index))
        }
        let totals = activity.bins
        VStack(spacing: 7) {
            plot(series: series, totals: totals)
                .frame(height: 54)
                .focusable().focused($focused)
                .onMoveCommand { direction in
                    switch direction {
                    case .left: select((selected ?? totals.count) - 1)
                    case .right: select((selected ?? -1) + 1)
                    default: break
                    }
                }
                .onExitCommand { selected = nil }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Model token usage over " + interval.durationLabel)
                .accessibilityValue(accessibilityValue(series))
                .accessibilityAdjustableAction { direction in
                    select(direction == .increment ? (selected ?? -1) + 1 : (selected ?? totals.count) - 1)
                }
            HStack {
                Text(interval.durationLabel + " ago")
                Spacer()
                Text("Now")
            }.font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.68))
            if let selected, let end {
                breakdown(series: series, index: selected, end: end)
            }
        }
        .contentShape(Rectangle())
        .onHover { inside in if !inside { selected = nil } }
        .onChange(of: focused) { if !focused { selected = nil } }
    }

    private func select(_ index: Int) {
        selected = min(max(0, index), Activity.binCount - 1)
    }

    private func plot(series: [Series], totals: [Int]) -> some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let step = size.width / CGFloat(totals.count)
                let peak = CGFloat(max(1, totals.max() ?? 1))
                for level in [0.0, 0.5, 1.0] {
                    let y = (size.height - 1) * level
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(Palette.grid), style: StrokeStyle(lineWidth: 0.7, dash: [2, 3]))
                }
                for i in totals.indices {
                    let x = CGFloat(i) * step
                    if selected == i {
                        let lane = CGRect(x: x, y: 0, width: step, height: size.height)
                        context.fill(Path(roundedRect: lane, cornerRadius: 3), with: .color(.white.opacity(0.15)))
                    }
                    guard totals[i] > 0 else { continue }
                    let height = max(2, size.height * CGFloat(totals[i]) / peak)
                    let bar = CGRect(x: x + 1.5, y: size.height - height, width: max(1, step - 3), height: height)
                    context.drawLayer { layer in
                        layer.clip(to: Path(roundedRect: bar, cornerRadius: 2.5))
                        layer.opacity = selected == nil || selected == i ? 1 : 0.55
                        var y = bar.maxY
                        for model in series where model.counts[i] > 0 {
                            let part = height * CGFloat(model.counts[i]) / CGFloat(totals[i])
                            y -= part
                            layer.fill(Path(CGRect(x: bar.minX, y: y, width: bar.width, height: part)), with: .color(model.color))
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if case let .active(point) = phase, proxy.size.width > 0 {
                    select(Int(point.x / proxy.size.width * CGFloat(totals.count)))
                }
            }
        }
    }

    private func timeLabel(index: Int, end: Date) -> String {
        let duration = interval.seconds / Double(Activity.binCount)
        let start = end.addingTimeInterval(-interval.seconds + Double(index) * duration)
        return (start..<start.addingTimeInterval(duration)).formatted(.interval.month(.abbreviated).day().hour().minute())
    }

    private func breakdown(series: [Series], index: Int, end: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timeLabel(index: index, end: end))
                .font(.system(size: 11, weight: .semibold))
            if series.isEmpty {
                Text("No recorded tokens").font(.caption).foregroundStyle(.white.opacity(0.7))
            } else {
                ViewThatFits(in: .vertical) {
                    rows(series: series, index: index)
                    ScrollView { rows(series: series, index: index) }
                }
                .frame(maxHeight: 150)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .foregroundStyle(.white)
        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 8))
    }

    private func rows(series: [Series], index: Int) -> some View {
        let ranked = series.sorted { a, b in
            if a.counts[index] != b.counts[index] { return a.counts[index] > b.counts[index] }
            return a.total == b.total ? a.id < b.id : a.total > b.total
        }
        return Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            GridRow {
                Text("Model")
                Text("Bar tokens").gridColumnAlignment(.trailing)
                Text(interval.label + " tokens").gridColumnAlignment(.trailing)
            }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
            ForEach(ranked) { model in
                GridRow {
                    HStack(spacing: 6) {
                        Circle().fill(model.color).frame(width: 6, height: 6)
                        Text(verbatim: model.id).lineLimit(2).truncationMode(.middle)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text(Display.tokens(model.counts[index]))
                    Text(Display.tokens(model.total))
                }.font(.system(size: 11, weight: .medium)).monospacedDigit()
            }
        }
    }

    private func accessibilityValue(_ series: [Series]) -> String {
        if let selected, let end {
            let counts = series.map { "\($0.id), \($0.counts[selected]) tokens" }
            return ([timeLabel(index: selected, end: end)] + counts).joined(separator: ". ")
        }
        return series.isEmpty ? "No recorded tokens" : series.map { "\($0.id), \($0.total) tokens" }.joined(separator: ". ")
    }
}
