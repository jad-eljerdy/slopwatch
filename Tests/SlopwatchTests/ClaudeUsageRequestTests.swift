import Foundation
import Testing
@testable import Slopwatch

private let reply = #"{"type":"control_response","response":{"subtype":"success","request_id":"slopwatch-quota","response":{"subscription_type":"max","rate_limits_available":true,"rate_limits":{"five_hour":{"utilization":3,"resets_at":"2026-11-18T17:19:59Z"},"seven_day":{"utilization":12,"resets_at":"2026-11-23T17:19:59Z"}}}}}"#

@Test func readsOnlyTheRequestedClaudeSubscription() throws {
    let now = Date()
    let quota = try #require(ClaudeUsageRequest.reading(from: Data(reply.utf8), observed: now))
    #expect(quota.windows.map(\.used) == [3, 12])
    #expect(quota.windows.allSatisfy { $0.reset != nil && $0.observed == now })
    #expect(quota.plan == "max")
    let unrelated = reply.replacingOccurrences(of: "slopwatch-quota", with: "other")
    #expect(ClaudeUsageRequest.reading(from: Data(unrelated.utf8), observed: now) == nil)
    let failure = reply.replacingOccurrences(of: "success", with: "error")
    #expect(ClaudeUsageRequest.reading(from: Data(failure.utf8), observed: now) == nil)
}

@Test func claudeNullQuotaDoesNotBecomeZeroUsage() {
    let missing = #"{"type":"control_response","response":{"request_id":"slopwatch-quota","subtype":"success","response":{"rate_limits_available":true,"rate_limits":null}}}"#
    #expect(ClaudeUsageRequest.reading(from: Data(missing.utf8), observed: Date()) == nil)
}

@Test func readsCLIUsageWithoutSendingAModelPrompt() throws {
    let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let bin = home.appending(path: ".local/bin")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let cli = bin.appending(path: "claude")
    let script = """
    #!/bin/sh
    set -eu
    [ "$DISABLE_TELEMETRY" = 1 ]
    IFS= read -r request
    case "$request" in *'"subtype":"get_usage"'*) ;; *) exit 1 ;; esac
    if read -r unexpected; then exit 2; fi
    echo '{"type":"system","subtype":"init"}'
    printf '%s\\n' '\(reply)'
    """
    try script.write(to: cli, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cli.path)
    let quota = try #require(ClaudeUsageRequest.fetch(paths: LocalPaths(home: home, environment: [:])))
    #expect(quota.windows.map(\.title) == ["5-hour", "Weekly"])
}

@Test func fableMeterUsesTheReportedModelLimit() throws {
    let now = Date(timeIntervalSince1970: 1000)
    let fable: Fields = ["kind": "weekly_scoped", "percent": 0, "resets_at": 2000,
                         "scope": ["model": ["display_name": "Fable"]], "is_active": false]
    let legacy: Fields = ["display_name": "Fable", "utilization": 42.5, "resets_at": 2000]
    let usage: Fields = ["seven_day": ["utilization": 77], "limits": [fable], "model_scoped": [legacy]]
    let reading = try #require(ClaudeQuota.parse(usage, observed: now))
    #expect(reading.windows.map(\.title) == ["Weekly", "Weekly · Fable"])
    #expect(reading.windows.map(\.used) == [77, 0])
    #expect(reading.windows.last?.isCurrent(at: Date(timeIntervalSince1970: 2000)) == false)
    #expect(ClaudeQuota.parse(["model_scoped": [legacy]], observed: now)?.windows.first?.used == 42.5)
    let otherLimits: Fields = ["limits": [["kind": "weekly_all", "percent": 55]],
                               "model_scoped": [["display_name": "Opus", "utilization": 30]]]
    #expect(ClaudeQuota.parse(otherLimits, observed: now) == nil)
    for invalid: Any in [NSNull(), true, -1, 101] {
        var invalidRow = fable
        invalidRow["percent"] = invalid
        #expect(ClaudeQuota.parse(["limits": [invalidRow]], observed: now) == nil)
    }
}
