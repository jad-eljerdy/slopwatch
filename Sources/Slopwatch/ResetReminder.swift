import Foundation

enum ReminderLead: Int, CaseIterable {
    case one = 1, six = 6, twelve = 12, day = 24, twoDays = 48

    var seconds: TimeInterval { TimeInterval(rawValue * 3600) }
}

struct ResetReminder: Codable, Equatable, Identifiable {
    static let prefix = "banked-reset."
    let provider: Provider
    let expiry: Date
    let quantity: Int

    var id: String { Self.prefix + provider.rawValue + "." + String(expiry.timeIntervalSince1970) }
    func due(_ lead: ReminderLead) -> Date { expiry.addingTimeInterval(-lead.seconds) }

    static func collect(from snapshot: Snapshot, previous: [Self], at now: Date) -> [Self] {
        var reminders: [Self] = []
        for provider in Provider.allCases {
            let report = snapshot.reports[provider]
            switch report?.connection {
            case .signedOut, .missing, .api: continue
            default: break
            }
            guard let report, report.connection == .subscription,
                  let inventory = report.quota.bankedResets, inventory.summary(at: now) != nil,
                  !inventory.presenceOnly else {
                // An unavailable reading can recover on the next CLI check.
                reminders += previous.filter { $0.provider == provider && $0.expiry > now }
                continue
            }
            var counts: [Date: Int] = [:]
            for grant in inventory.active(at: now) {
                if let expiry = grant.expires { counts[expiry, default: 0] += grant.quantity }
            }
            reminders += counts.map { Self(provider: provider, expiry: $0.key, quantity: $0.value) }
        }
        return reminders.sorted { ($0.expiry, $0.id) < ($1.expiry, $1.id) }
    }
}

struct ScheduledReminder: Codable {
    let reminder: ResetReminder
    let due: Date

    func needsReplacement(with next: ResetReminder, lead: ReminderLead, pending: Bool, now: Date) -> Bool {
        // A one-shot request disappears after delivery, even if the user dismisses it.
        if !pending && due <= now { return false }
        return !pending || reminder != next || due != next.due(lead)
    }
}
