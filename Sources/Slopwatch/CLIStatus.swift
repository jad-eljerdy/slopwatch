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

extension CLIStatus {
    static func check(_ provider: Provider, paths: LocalPaths) -> Connection {
        guard let url = paths.executable(provider.rawValue.lowercased()) else { return .missing }
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
        do { try task.run() } catch { return .unavailable }
        let deadline = ContinuousClock.now + .seconds(5)
        while task.isRunning && ContinuousClock.now < deadline { Thread.sleep(forTimeInterval: 0.025) }
        if task.isRunning {
            kill(task.processIdentifier, SIGKILL)
            task.waitUntilExit()
            return .unavailable
        }
        guard let data = try? pipe.fileHandleForReading.readToEnd() else { return .unavailable }
        switch provider {
        case .codex: return codex(String(decoding: data, as: UTF8.self), status: task.terminationStatus)
        case .claude: return claude(data)
        }
    }
}
