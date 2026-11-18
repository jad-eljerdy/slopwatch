import Foundation

enum RecordReader {
    static let claudeMarkers = ["\"output_tokens\""].map { Data($0.utf8) }
    static let codexMarkers = ["\"turn_context\"", "\"session_meta\"", "\"token_count\"", "\"token_usage_record\""].map { Data($0.utf8) }

    static func consume(_ data: Data, provider: Provider, into file: inout FileIndex) {
        let markers = provider == .codex ? codexMarkers : claudeMarkers
        guard markers.contains(where: { data.range(of: $0) != nil }) else { return }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? Fields else { file.skipped += 1; return }
        guard let time = timestamp(root["timestamp"]) else { return }
        switch provider {
        case .claude: file.readClaude(root, at: time)
        case .codex: file.readCodex(root, at: time)
        }
    }
}
