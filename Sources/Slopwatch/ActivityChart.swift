import SwiftUI

struct ActivityChart: View {
    let codex: [Int]
    let claude: [Int]

    var body: some View {
        Canvas { context, size in
            let totals = zip(codex, claude).map(+)
            let peak = CGFloat(max(1, totals.max() ?? 1))
            let step = size.width / CGFloat(max(totals.count, 1))
            for level in [0.0, 0.5, 1.0] {
                let y = (size.height - 1) * level
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(Palette.grid), style: StrokeStyle(lineWidth: 0.7, dash: [2, 3]))
            }
            for i in totals.indices where totals[i] > 0 {
                let height = max(2, size.height * CGFloat(totals[i]) / peak)
                let bar = CGRect(x: CGFloat(i) * step + 1, y: size.height - height,
                                 width: max(1, step - 3), height: height)
                let shape = Path(roundedRect: bar, cornerRadius: 2)
                context.drawLayer { layer in
                    layer.clip(to: shape)
                    layer.fill(shape, with: .color(Provider.codex.tint))
                    let top = height * CGFloat(claude[i]) / CGFloat(totals[i])
                    layer.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: top)),
                               with: .color(Provider.claude.tint))
                }
            }
        }
        .accessibilityLabel("Token activity across 24 equal time intervals")
        .accessibilityValue("Codex \(codex.reduce(0, +)) tokens. Claude \(claude.reduce(0, +)) tokens.")
    }
}
