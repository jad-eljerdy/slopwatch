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

struct MenuBarReading {
    let provider: Provider
    let limit: Limit?

    init(provider: Provider, report: ProviderReport?, now: Date) {
        self.provider = provider
        guard let report, report.connection == .subscription else {
            limit = nil
            return
        }
        limit = report.quota.windows.filter { $0.used.isFinite && $0.isCurrent(at: now) }
            .max { $0.used < $1.used }
    }

    var percent: String {
        guard let limit else { return "—" }
        return (LimitDisplay.remaining.percent(used: limit.used) / 100)
            .formatted(.percent.precision(.fractionLength(0)))
    }

    var description: String {
        guard let limit else { return "\(provider.rawValue): no current limit reading" }
        return "\(provider.rawValue): \(percent) left (\(limit.title))"
    }

    var validUntil: Date? {
        limit.map { $0.reset ?? $0.observed.addingTimeInterval(300) }
    }
}

@MainActor
func glanceTitle(_ readings: [MenuBarReading]) -> NSAttributedString {
    let title = NSMutableAttributedString()
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    for reading in readings {
        if title.length > 0 { title.append(NSAttributedString(string: "  ")) }
        if let image = ProviderIcon.icons[reading.provider] {
            let icon = NSTextAttachment()
            icon.image = image
            icon.bounds = CGRect(x: 0, y: ((font.capHeight - 20) / 2).rounded(), width: 20, height: 20)
            title.append(NSAttributedString(attachment: icon))
        } else {
            title.append(NSAttributedString(string: reading.provider.rawValue))
        }
        title.append(NSAttributedString(string: " " + reading.percent, attributes: [.font: font]))
    }
    return title
}
