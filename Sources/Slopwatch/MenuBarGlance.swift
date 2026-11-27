import AppKit

enum MenuBarDisplay: String, CaseIterable {
    case both = "Codex and Claude"
    case codex = "Codex"
    case claude = "Claude"
    case icon = "Slopwatch icon only"

    var providers: [Provider] {
        switch self {
        case .both: [.codex, .claude]
        case .codex: [.codex]
        case .claude: [.claude]
        case .icon: []
        }
    }
}

enum MenuBarWindow: String, CaseIterable {
    case fiveHour = "5-hour"
    case weekly = "Weekly"
    case stacked = "5-hour above weekly"
    case lowest = "Lowest remaining"
}

struct MenuBarLine {
    let name: String
    let limit: Limit?

    var percent: String {
        guard let limit else { return "—" }
        return (LimitDisplay.remaining.percent(used: limit.used) / 100)
            .formatted(.percent.precision(.fractionLength(0)))
    }
}

struct MenuBarReading {
    let provider: Provider
    let lines: [MenuBarLine]

    init(provider: Provider, report: ProviderReport?, window: MenuBarWindow, now: Date) {
        self.provider = provider
        let current = report?.connection == .subscription
            ? report?.quota.windows.filter { $0.used.isFinite && $0.isCurrent(at: now) } ?? [] : []
        func line(_ name: String) -> MenuBarLine {
            MenuBarLine(name: name, limit: current.first { $0.title == name })
        }
        let fiveHour = line("5-hour")
        let upper = provider == .claude && report?.planLabel == "Ultra" && fiveHour.limit == nil
            ? line("Fable") : fiveHour
        switch window {
        case .fiveHour: lines = [upper]
        case .weekly: lines = [line("Weekly")]
        case .stacked: lines = [upper, line("Weekly")]
        case .lowest:
            let limit = current.max { $0.used < $1.used }
            lines = [MenuBarLine(name: limit?.title ?? "Limit", limit: limit)]
        }
    }

    var description: String {
        let details = lines.map { line in
            line.name + " " + (line.limit == nil ? "unavailable" : line.percent + " left")
        }
        return provider.rawValue + ": " + details.joined(separator: ", ")
    }

    var validUntil: Date? {
        lines.compactMap(\.limit).map { $0.reset ?? $0.observed.addingTimeInterval(300) }.min()
    }
}

// Only visible content determines whether the status button needs a new image.
struct MenuBarGlyph: Equatable {
    let provider: Provider
    let values: [String]

    init(_ reading: MenuBarReading) {
        provider = reading.provider
        values = reading.lines.map(\.percent)
    }
}

@MainActor
func glanceImage(_ glyphs: [MenuBarGlyph]) -> NSImage {
    let height: CGFloat = 22
    var x: CGFloat = 0
    var icons: [(NSImage, CGRect)] = []
    var labels: [(NSAttributedString, CGPoint)] = []

    for glyph in glyphs {
        if x > 0 { x += 8 }
        if let icon = ProviderIcon.icons[glyph.provider] {
            icons.append((icon, CGRect(x: x, y: 1, width: 20, height: 20)))
            x += 22
        } else {
            let name = NSAttributedString(string: glyph.provider.rawValue, attributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor
            ])
            labels.append((name, CGPoint(x: x, y: floor((height - name.size().height) / 2))))
            x += ceil(name.size().width) + 2
        }
        let stacked = glyph.values.count > 1
        let font = NSFont.monospacedDigitSystemFont(ofSize: stacked ? 10 : 12, weight: .medium)
        let rows = glyph.values.map {
            NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        let width = ceil(rows.map { $0.size().width }.max() ?? 0)
        let rowHeight = height / CGFloat(rows.count)
        for (index, row) in rows.enumerated() {
            let size = row.size()
            let y = height - (CGFloat(index) + 0.5) * rowHeight - size.height / 2
            labels.append((row, CGPoint(x: x + width - size.width, y: floor(y))))
        }
        x += width
    }

    // AppKit snapshots status items for the menu bar. Supply one native image
    // so taking that snapshot never lays out or invalidates a child view.
    return NSImage(size: NSSize(width: x, height: height), flipped: false) { [icons, labels] _ in
        for (icon, rect) in icons { icon.draw(in: rect) }
        for (label, point) in labels { label.draw(at: point) }
        return true
    }
}
