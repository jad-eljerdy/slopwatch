import SwiftUI

struct ResetDetails: View {
    let provider: Provider
    let inventory: BankedResets?
    let now: Date
    let pageReader: ClaudePageReader?
    @State private var showPageOptions = false

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
            } else if let balance = pageReader?.balance, balance.isFresh(at: now) {
                Text(balance.label).fontWeight(.medium)
                Text("\(balance.source.rawValue) · Seen at \(balance.seen.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("The CLI did not report a reset balance.").foregroundStyle(.secondary)
            }
            Link("Review resets on \(provider.rawValue) ↗", destination: usagePage)
                .help("Open the provider’s usage page to review and confirm a reset.")
            if let pageReader {
                DisclosureGroup("Read balance from usage page", isExpanded: $showPageOptions) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use the account shown in your browser. Page readings expire after 15 minutes.")
                        Toggle("Read the open usage page automatically", isOn: Binding(get: { pageReader.enabled },
                            set: { pageReader.setEnabled($0) }))
                        Text("For a manual reading, copy the Limit resets heading and its available count.")
                        HStack {
                            PasteButton(payloadType: String.self) { values in
                                if let text = values.first { pageReader.importSelection(text) }
                            }.controlSize(.small)
                            if pageReader.balance != nil { Button("Clear reading") { pageReader.clear() } }
                        }
                        if let message = pageReader.message { Text(message).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 5)
                }
            }
        }
    }
}
