import SwiftUI

struct ResetDetails: View {
    let provider: Provider
    let inventory: BankedResets?
    let now: Date

    private var usagePage: URL {
        switch provider {
        case .codex: URL(string: "https://chatgpt.com/codex/settings/usage")!
        case .claude: URL(string: "https://claude.ai/settings/usage")!
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Caption(text: "Banked resets")
            if let inventory, let summary = inventory.summary(at: now) {
                Text(summary).fontWeight(.medium)
                ForEach(inventory.active(at: now)) { grant in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(grant.quantity > 1 ? "\(grant.title) × \(grant.quantity)" : grant.title)
                        if let expiry = grant.expires {
                            Text("Expires " + expiry.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if grant.heldOnly { Text("Held · unavailable now").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if inventory.unlisted > 0 {
                    Text("Individual details are unavailable for \(inventory.unlisted) of these resets.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("The CLI did not report a reset balance.").foregroundStyle(.secondary)
            }
            Link("Review resets on \(provider.rawValue) ↗", destination: usagePage)
                .help("Open the provider’s usage page to review and confirm a reset.")
        }
    }
}
