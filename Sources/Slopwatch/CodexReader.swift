import Foundation

extension FileIndex {
    mutating func readCodex(_ fields: Fields, at time: Date) {
        let payload = fields.object("payload")
        switch fields["type"] as? String {
        case "session_meta":
            session = payload["id"] as? String ?? session
        case "turn_context":
            model = payload["model"] as? String ?? "Unknown"
        case "token_usage_record":
            readResponse(payload, at: time)
        case "event_msg" where payload["type"] as? String == "token_count":
            readTokenCount(payload, at: time)
        default: break
        }
    }
}

extension FileIndex {
    mutating func readResponse(_ payload: Fields, at time: Date) {
        let tokens = Tokens(codex: payload.object("usage"))
        guard tokens.total > 0, let id = payload["response_id"] as? String else { return }
        let cumulative = payload.object("thread_token_usage").count("total_tokens")
        let key = cumulative > 0 ? session + "/" + String(cumulative) : id
        events[key] = UsageEvent(id: id, time: time, model: payload["model"] as? String ?? model, tokens: tokens)
    }
}

extension FileIndex {
    mutating func readTokenCount(_ payload: Fields, at time: Date) {
        readQuota(payload.object("rate_limits"), at: time)
        let info = payload.object("info")
        let totalFields = info.object("total_token_usage")
        let last = info.object("last_token_usage")
        guard !totalFields.isEmpty || !last.isEmpty else { return }
        let total = Tokens(codex: totalFields)
        let tokens = last.isEmpty ? total.since(previous) : Tokens(codex: last)
        if !totalFields.isEmpty { previous = total }
        let cumulative = totalFields.count("total_tokens")
        let key = session + "/" + (cumulative > 0 ? String(cumulative) : String(time.timeIntervalSince1970))
        guard tokens.total > 0, events[key] == nil else { return }
        events[key] = UsageEvent(id: key, time: time, model: model, tokens: tokens)
    }
}
