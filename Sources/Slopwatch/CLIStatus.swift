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

extension CLIStatus {
    static func claude(_ data: Data) -> Connection {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? Fields,
              let signedIn = root["loggedIn"] as? Bool else { return .unavailable }
        guard signedIn else { return .signedOut }
        let method = (root["authMethod"] as? String ?? "").lowercased()
        if method == "claude.ai" || root["subscriptionType"] as? String != nil { return .subscription }
        return .api
    }
}
