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
    #expect(CLIStatus.claude(Data(#"{"loggedIn":true,"authMethod":"claude.ai"}"#.utf8)).connection == .subscription)
    #expect(CLIStatus.claude(Data(#"{"loggedIn":true,"authMethod":"api_key"}"#.utf8)).connection == .api)
}

@Test func claudeFailure() throws {
    #expect(CLIStatus.claude(Data("bad".utf8)).connection == .unavailable)
    #expect(CLIStatus.claude(Data(#"{"loggedIn":false}"#.utf8)).connection == .signedOut)
}

@Test func customRoots() throws {
    let paths = LocalPaths(home: URL(filePath: "/example"), environment: ["CODEX_HOME": "/codex-custom", "CLAUDE_CONFIG_DIR": "/claude-custom"])
    #expect(paths.codex.path == "/codex-custom")
    #expect(paths.claudeConfigs.first?.path == "/claude-custom/.claude.json")
    #expect(paths.logs(for: .codex).count == 2)
}

@Test func relativeRoot() throws {
    let paths = LocalPaths(home: URL(filePath: "/example"), environment: ["CODEX_HOME": "relative"])
    #expect(paths.codex.path == "/example/.codex")
}

@Test func planPillsUseReportedSubscriptionTiers() {
    let status = CLIStatus.claude(Data(#"{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"max","planTier":"max_5x"}"#.utf8))
    var report = ProviderReport(quota: Quota(plan: status.plan), connection: status.connection)
    #expect(report.planLabel == "Max 5x")
    report.quota.plan = "prolite"
    #expect(report.planLabel == "Pro Lite")
    report.connection = .signedOut
    #expect(report.planLabel == nil)
    report.connection = .subscription
    for missing in [nil, "", " ", "unknown"] {
        report.quota.plan = missing
        #expect(report.planLabel == nil)
    }
}

@Test func claudeUsesThePlanNameFromTheSignedInOrganization() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    let auth = Data(#"{"loggedIn":true,"authMethod":"claude.ai","email":"a@example.test","orgId":"one","planTier":"max_5x","subscriptionType":"max"}"#.utf8)
    func check(_ email: String, _ org: String, _ name: String) throws -> String? {
        let profile = ["emailAddress": email, "organizationUuid": org, "planDisplayName": name]
        try JSONSerialization.data(withJSONObject: ["oauthAccount": profile]).write(to: file)
        return CLIStatus.claude(auth, configs: [file]).plan
    }
    #expect(try check("A@example.test", "one", "Ultra") == "Ultra")
    #expect(try check("other@example.test", "one", "Ultra") == "max_5x")
    #expect(try check("a@example.test", "other", "Ultra") == "max_5x")
    #expect(try check("a@example.test", "one", " ") == "max_5x")
}
