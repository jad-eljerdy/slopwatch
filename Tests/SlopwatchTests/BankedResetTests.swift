import Foundation
import Testing
@testable import Slopwatch

@Test func codexBankedCreditsExcludeRedeemedAndExpiredGrants() throws {
    let now = Date(timeIntervalSince1970: 1000)
    let credits: [Fields] = [
        ["id": "a", "status": "available", "expiresAt": 1100],
        ["id": "a", "status": "available", "expiresAt": 1100],
        ["id": "b", "status": "available", "expiresAt": 1000],
        ["id": "c", "status": "redeemed"],
    ]
    let reset = try #require(BankedResets.codex(["availableCount": 3, "credits": credits]))
    #expect(reset.active(at: now).map(\.id) == ["a"])
    #expect(reset.unlisted == 1)
    #expect(reset.summary(at: now) == "2 banked resets")
    #expect(BankedResets.codex(["availableCount": 0])?.hasBankedResets(at: now) == false)
    #expect(BankedResets.codex(["hasCredits": true]) == nil)
}

@Test func claudeGrantCountsAndUnknownBalances() throws {
    let now = Date(timeIntervalSince1970: 100)
    let grants: [Fields] = [
        ["id": "weekly", "label": "Weekly reset", "resets_left": 2, "ends_at": "2027-01-01T00:00:00Z", "usable_now": false],
        ["id": "spent", "resets_left": 0],
    ]
    let reading = try #require(ClaudeQuota.parse(["cedar_ember": ["grants": grants]], observed: now))
    #expect(reading.bankedResets?.summary(at: now) == "2 banked resets")
    #expect(reading.bankedResets?.active(at: now).first?.heldOnly == true)
    #expect(BankedResets.claude([:]) == nil)
    #expect(BankedResets.claude(["grants": []])?.summary(at: now) == "0 banked resets")
    #expect(BankedResets.claude(["grants": [["id": "bad", "resets_left": true]]]) == nil)
}

@Test func onlyCurrentAccountCanSupplyClaudeResetHint() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let paths = LocalPaths(home: home, environment: [:])
    func write(_ account: String, held: Bool = true) throws {
        let fields: Fields = ["oauthAccount": ["accountUuid": account],
            "unusedLimitResetStatusCache": ["checkedAt": 1000, "validUntil": 5000, "accountUuid": "A", "holdsUnusedReset": held]]
        try JSONSerialization.data(withJSONObject: fields).write(to: paths.claudeConfigs[0])
    }
    try write("A")
    let now = Date(timeIntervalSince1970: 2)
    let hint = try #require(paths.claudeResetHint(now: now))
    #expect(hint.summary(at: now) == "Banked reset reported")
    #expect(hint.summary(at: Date(timeIntervalSince1970: 5)) == nil)
    try write("A", held: false)
    #expect(paths.claudeResetHint(now: now) == nil)
    try write("B")
    #expect(paths.claudeResetHint(now: now) == nil)
}

@Test func codexResetProbeOnlyInitializesAndReads() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let bin = home.appending(path: ".local/bin")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let cli = bin.appending(path: "codex")
    let script = """
    #!/bin/sh
    set -eu
    IFS= read -r msg
    case "$msg" in *'"method":"initialize"'*) ;; *) exit 2 ;; esac
    echo '{"id":1,"result":{}}'
    IFS= read -r msg
    [ "$msg" = '{"method":"initialized"}' ]
    IFS= read -r msg
    [ "$msg" = '{"id":2,"method":"account/rateLimits/read"}' ]
    echo '{"id":2,"result":{"rateLimitResetCredits":{"availableCount":2,"credits":null}}}'
    """
    try script.write(to: cli, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cli.path)
    let reset = try #require(CodexResetRequest.fetch(paths: LocalPaths(home: home, environment: [:])))
    #expect(reset.unlisted == 2)
}
