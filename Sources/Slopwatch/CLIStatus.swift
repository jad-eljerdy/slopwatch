import Foundation
import Darwin

enum CLIStatus {
    static func codex(_ output: String, status: Int32) -> Connection {
        let text = output.lowercased()
        if text.contains("not logged in") || text.contains("not signed in") { return .signedOut }
        guard status == 0 else { return .unavailable }
        if text.contains("api key") { return .api }
        return text.contains("chatgpt") ? .subscription : .unavailable
    }
}
