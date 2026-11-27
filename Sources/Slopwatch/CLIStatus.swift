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
    struct Account {
        let connection: Connection
        var plan: String?
    }

    static func claude(_ data: Data) -> Account {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? Fields,
              let signedIn = root["loggedIn"] as? Bool else { return Account(connection: .unavailable) }
        guard signedIn else { return Account(connection: .signedOut) }
        let method = (root["authMethod"] as? String ?? "").lowercased()
        let subscription = root["subscriptionType"] as? String
        if method == "claude.ai" || subscription != nil {
            let tier = (root["planTier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let tier, !tier.isEmpty, tier.lowercased() != "unknown" {
                return Account(connection: .subscription, plan: tier)
            }
            return Account(connection: .subscription, plan: subscription)
        }
        return Account(connection: .api)
    }
}

extension CLIStatus {
    static func check(_ provider: Provider, paths: LocalPaths) -> Account {
        guard let url = paths.executable(provider.rawValue.lowercased()) else { return Account(connection: .missing) }
        let task = Process()
        let pipe = Pipe()
        var env = paths.environment
        env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
        env["DISABLE_TELEMETRY"] = "1"
        env["OTEL_SDK_DISABLED"] = "true"
        task.environment = env
        task.executableURL = url
        task.arguments = provider == .codex ? ["login", "status"] : ["auth", "status", "--json"]
        task.currentDirectoryURL = URL(filePath: "/")
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = pipe
        task.standardError = provider == .codex ? pipe : FileHandle.nullDevice
        do { try task.run() } catch { return Account(connection: .unavailable) }
        let deadline = ContinuousClock.now + .seconds(5)
        while task.isRunning && ContinuousClock.now < deadline { Thread.sleep(forTimeInterval: 0.025) }
        if task.isRunning {
            kill(task.processIdentifier, SIGKILL)
            task.waitUntilExit()
            return Account(connection: .unavailable)
        }
        guard let data = try? pipe.fileHandleForReading.readToEnd() else { return Account(connection: .unavailable) }
        switch provider {
        case .codex: return Account(connection: codex(String(decoding: data, as: UTF8.self), status: task.terminationStatus))
        case .claude: return claude(data)
        }
    }
}
