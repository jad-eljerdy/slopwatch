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
        switch window {
        case .fiveHour: lines = [line("5-hour")]
        case .weekly: lines = [line("Weekly")]
        case .stacked: lines = [line("5-hour"), line("Weekly")]
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

// Keep the native status button responsible for clicks, keyboard access, and tooltips.
@MainActor
final class MenuBarGlanceView: NSStackView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    convenience init(readings: [MenuBarReading]) {
        self.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        setAccessibilityElement(false)

        for reading in readings {
            let values = NSStackView()
            values.orientation = .vertical
            values.alignment = .trailing
            values.spacing = 0
            let stacked = reading.lines.count > 1
            for line in reading.lines {
                let label = NSTextField(labelWithString: line.percent)
                label.font = .monospacedDigitSystemFont(ofSize: stacked ? 10 : 12, weight: .medium)
                label.setAccessibilityElement(false)
                values.addArrangedSubview(label)
            }
            let symbol: NSView
            if let image = ProviderIcon.icons[reading.provider] {
                let icon = NSImageView(image: image)
                icon.imageScaling = .scaleProportionallyUpOrDown
                NSLayoutConstraint.activate([icon.widthAnchor.constraint(equalToConstant: 20),
                                             icon.heightAnchor.constraint(equalToConstant: 20)])
                symbol = icon
            } else {
                symbol = NSTextField(labelWithString: reading.provider.rawValue)
            }
            let group = NSStackView(views: [symbol, values])
            group.orientation = .horizontal
            group.alignment = .centerY
            group.spacing = 2
            addArrangedSubview(group)
        }
    }
}
