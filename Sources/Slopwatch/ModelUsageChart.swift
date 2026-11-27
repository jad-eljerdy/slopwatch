import SwiftUI

struct ModelUsageChart: View {
    let activity: Activity
    let interval: Interval
    let provider: Provider

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
        let series = activity.modelBins.keys.sorted().enumerated().compactMap { index, name -> Series? in
            guard let counts = activity.modelBins[name] else { return nil }
            return Series(id: name, counts: counts, total: counts.reduce(0, +),
                          color: seriesColor(index))
        }
        let totals = activity.bins
        VStack(spacing: 7) {
            HStack {
                Text(provider.rawValue + " usage").font(.headline)
                Spacer()
                Text(interval.label).font(.caption.weight(.semibold))
            }.foregroundStyle(.white)
            HStack {
                Text("Local tokens by model").foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(Display.tokens(activity.tokens)).fontWeight(.semibold)
            }.font(.caption).foregroundStyle(.white)
            plot(series: series, totals: totals)
                .frame(height: 54)
                .accessibilityHidden(true)
            HStack {
                Text(interval.durationLabel + " ago")
                Spacer()
                Text("Now")
            }.frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.68))
            breakdown(series: series)
        }
        .padding(12)
        .frame(width: 296)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("usage-tooltip-" + provider.rawValue)
    }

    private func plot(series: [Series], totals: [Int]) -> some View {
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
                guard totals[i] > 0 else { continue }
                let height = max(2, size.height * CGFloat(totals[i]) / peak)
                let bar = CGRect(x: x + 1.5, y: size.height - height, width: max(1, step - 3), height: height)
                context.drawLayer { layer in
                    layer.clip(to: Path(roundedRect: bar, cornerRadius: 2.5))
                    var y = bar.maxY
                    for model in series where model.counts[i] > 0 {
                        let part = height * CGFloat(model.counts[i]) / CGFloat(totals[i])
                        y -= part
                        layer.fill(Path(CGRect(x: bar.minX, y: y, width: bar.width, height: part)), with: .color(model.color))
                    }
                }
            }
        }
    }

    private func breakdown(series: [Series]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if series.isEmpty {
                Text("No recorded tokens").font(.caption).foregroundStyle(.white.opacity(0.7))
            } else {
                ViewThatFits(in: .vertical) {
                    rows(series: series)
                    ScrollView { rows(series: series) }
                }
                .frame(maxHeight: 150)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
    }

    private func rows(series: [Series]) -> some View {
        let ranked = series.sorted { a, b in
            return a.total == b.total ? a.id < b.id : a.total > b.total
        }
        return Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            GridRow {
                Text("Model")
                Text("Share").gridColumnAlignment(.trailing)
                Text(interval.label + " tokens").gridColumnAlignment(.trailing)
            }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
            ForEach(ranked) { model in
                GridRow {
                    HStack(spacing: 6) {
                        Circle().fill(model.color).frame(width: 6, height: 6)
                        Text(verbatim: model.id).lineLimit(2).truncationMode(.middle)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text((Double(model.total) / Double(max(1, activity.tokens))).formatted(.percent.precision(.fractionLength(0...1))))
                    Text(Display.tokens(model.total))
                }.font(.system(size: 11, weight: .medium)).monospacedDigit()
            }
        }
    }
}
