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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Banked resets").font(.headline)
                if let inventory, !inventory.presenceOnly, inventory.summary(at: now) != nil {
                    let count = inventory.active(at: now).reduce(inventory.unlisted) { $0 + $1.quantity }
                    Text(count, format: .number).font(.caption.bold()).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.primary.opacity(0.08), in: Capsule())
                }
                Spacer()
                Link(destination: usagePage) { Label("Review", systemImage: "arrow.up.right") }
                    .font(.callout.weight(.medium))
                    .accessibilityLabel("Review resets on " + provider.rawValue)
                    .help("Open the provider’s usage page to review a reset.")
            }
            if let inventory, let summary = inventory.summary(at: now) {
                let grants = inventory.active(at: now)
                if grants.isEmpty && inventory.unlisted == 0 {
                    Text(inventory.presenceOnly ? summary : "No banked resets available.").foregroundStyle(.secondary)
                }
                if !grants.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Type")
                            Spacer()
                            Text("Expires")
                        }.font(.caption.weight(.medium)).foregroundStyle(.secondary).padding(.vertical, 5)
                        Divider()
                        ForEach(grants) { grant in
                            if grant.id != grants.first?.id { Divider() }
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(grant.quantity > 1 ? "\(grant.title) × \(grant.quantity)" : grant.title)
                                    .fontWeight(.medium)
                                Spacer(minLength: 6)
                                if let expiry = grant.expires {
                                    Text(expiry.formatted(.dateTime.month(.abbreviated).day()) + " · " +
                                         expiry.formatted(date: .omitted, time: .shortened))
                                        .monospacedDigit().foregroundStyle(.secondary)
                                        .accessibilityLabel("Expires " + expiry.formatted())
                                        .help("Expires " + expiry.formatted())
                                }
                            }.padding(.vertical, 7).accessibilityElement(children: .combine)
                            if grant.heldOnly { Text("Held · unavailable now").font(.caption).padding(.bottom, 6) }
                        }
                    }
                    .padding(.horizontal, 11).padding(.vertical, 2)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.10)) }
                    .help("Dates show when each reset expires")
                }
                if inventory.unlisted > 0 {
                    Text(inventory.unlisted == 1 ? "Details unavailable for 1 reset." : "Details unavailable for \(inventory.unlisted) resets.")
                        .foregroundStyle(.secondary)
                }
            } else if let balance = pageReader?.balance, balance.isFresh(at: now) {
                Text(balance.label).fontWeight(.medium)
                Text("\(balance.source.rawValue) · Seen at \(balance.seen.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("The CLI did not report a reset balance.").foregroundStyle(.secondary)
            }
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
        }.font(.system(size: 13))
    }
}
