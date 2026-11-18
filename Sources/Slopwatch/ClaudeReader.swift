import Foundation

extension FileIndex {
    mutating func readClaude(_ fields: Fields, at time: Date) {
        guard fields["type"] as? String == "assistant" else { return }
        let message = fields.object("message")
        guard let model = message["model"] as? String, model != "<synthetic>",
              let id = message["id"] as? String ?? fields["uuid"] as? String else { return }
        let tokens = Tokens(claude: message.object("usage"))
        guard tokens.total > 0 else { return }
        let key = (fields["requestId"] as? String ?? "") + "/" + id
        guard events[key].map({ tokens.total >= $0.tokens.total }) ?? true else { return }
        events[key] = UsageEvent(id: key, time: events[key]?.time ?? time, model: model, tokens: tokens)
    }
}
