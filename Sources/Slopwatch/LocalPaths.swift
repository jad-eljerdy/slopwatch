import Foundation

struct LocalPaths: Sendable {
    var home = FileManager.default.homeDirectoryForCurrentUser
    var environment = ProcessInfo.processInfo.environment

    var codex: URL { directory("CODEX_HOME", fallback: ".codex") }
    var claude: URL { directory("CLAUDE_CONFIG_DIR", fallback: ".claude") }
    var claudeConfigs: [URL] {
        if environment["CLAUDE_CONFIG_DIR"] != nil { return [claude.appending(path: ".claude.json")] }
        return [home.appending(path: ".claude.json"), claude.appending(path: ".claude.json")]
    }

    private func directory(_ key: String, fallback: String) -> URL {
        guard let path = environment[key], path.hasPrefix("/") else { return home.appending(path: fallback) }
        return URL(filePath: path)
    }
}

extension LocalPaths {
    func logs(for provider: Provider) -> [URL] {
        switch provider {
        case .codex: [codex.appending(path: "sessions"), codex.appending(path: "archived_sessions")]
        case .claude: [claude.appending(path: "projects")]
        }
    }
}

extension LocalPaths {
    func executable(_ name: String) -> URL? {
        let fixed = [home.appending(path: ".local/bin").path, "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        let path = (environment["PATH"] ?? "").split(separator: ":").map(String.init).filter { $0.hasPrefix("/") }
        return (fixed + path).lazy.map { URL(filePath: $0).appending(path: name) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
