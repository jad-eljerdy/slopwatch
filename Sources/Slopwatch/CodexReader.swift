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
