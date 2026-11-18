import Foundation
import Testing
@testable import Slopwatch

@Test func codexAuth() throws {
    #expect(CLIStatus.codex("Logged in using ChatGPT", status: 0) == .subscription)
    #expect(CLIStatus.codex("Logged in using an API key", status: 0) == .api)
}

@Test func codexFailure() throws {
    #expect(CLIStatus.codex("Not logged in", status: 1) == .signedOut)
    #expect(CLIStatus.codex("Failed to run", status: 1) == .unavailable)
}

@Test func claudeAuth() throws {
    #expect(CLIStatus.claude(Data(#"{"loggedIn":true,"authMethod":"claude.ai"}"#.utf8)) == .subscription)
    #expect(CLIStatus.claude(Data(#"{"loggedIn":true,"authMethod":"api_key"}"#.utf8)) == .api)
}

@Test func claudeFailure() throws {
    #expect(CLIStatus.claude(Data("bad".utf8)) == .unavailable)
    #expect(CLIStatus.claude(Data(#"{"loggedIn":false}"#.utf8)) == .signedOut)
}

@Test func customRoots() throws {
    let paths = LocalPaths(home: URL(filePath: "/example"), environment: ["CODEX_HOME": "/codex-custom", "CLAUDE_CONFIG_DIR": "/claude-custom"])
    #expect(paths.codex.path == "/codex-custom")
    #expect(paths.claudeConfigs.first?.path == "/claude-custom/.claude.json")
    #expect(paths.logs(for: .codex).count == 2)
}
