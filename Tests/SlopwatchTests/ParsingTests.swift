import Foundation
import Testing
@testable import Slopwatch

@Test func pairedCodexRecords() throws {
    var file = FileIndex()
    file.session = "thread"
    let when = Date()
    let usage: Fields = ["input_tokens": 60, "output_tokens": 40, "total_tokens": 100]
    file.readResponse(["response_id": "r", "thread_token_usage": usage, "usage": usage], at: when)
    file.readTokenCount(["info": ["total_token_usage": usage, "last_token_usage": usage]], at: when)
    #expect(file.events.count == 1)
    #expect(file.events.values.first?.id == "r")
}

@Test func reversedPair() throws {
    var file = FileIndex()
    let usage: Fields = ["input_tokens": 10, "total_tokens": 10]
    file.readTokenCount(["info": ["total_token_usage": usage, "last_token_usage": usage]], at: Date())
    file.readResponse(["response_id": "r", "thread_token_usage": usage, "usage": usage], at: Date())
    #expect(file.events.count == 1)
    #expect(file.events.values.first?.id == "r")
}

@Test func repeatedCodexEvent() throws {
    var f = FileIndex()
    let event: Fields = ["info": ["total_token_usage": ["input_tokens": 40, "total_tokens": 40]]]
    f.readTokenCount(event, at: Date())
    f.readTokenCount(event, at: Date())
    #expect(f.events.values.map(\.tokens.total) == [40])
}

@Test func codexModelSwitch() throws {
    var f = FileIndex()
    f.readCodex(["type": "turn_context", "payload": ["model": "first"]], at: Date())
    f.readResponse(["response_id": "a", "usage": ["input_tokens": 4]], at: Date())
    f.readCodex(["type": "turn_context", "payload": ["model": "second"]], at: Date())
    f.readResponse(["response_id": "b", "usage": ["input_tokens": 5]], at: Date())
    #expect(f.events["a"]?.model == "first")
    #expect(f.events["b"]?.model == "second")
}

@Test func quotaOnlyEvent() throws {
    var f = FileIndex()
    f.readTokenCount(["rate_limits": ["primary": ["used_percent": 0, "window_minutes": 10080]]], at: Date())
    #expect(f.quota.windows.first?.title == "Weekly")
    #expect(f.events.isEmpty)
}

@Test func codexSeparatePools() throws {
    var f = FileIndex()
    f.readQuota(["limit_id": "extra", "primary": ["used_percent": 10]], at: Date())
    #expect(f.quota.windows.isEmpty)
}

@Test func quotaOrdering() throws {
    var f = FileIndex()
    let now = Date()
    f.readQuota(["primary": ["used_percent": 30]], at: now)
    f.readQuota(["primary": ["used_percent": 10]], at: now.addingTimeInterval(-1))
    f.readQuota(["primary": ["used_percent": 200]], at: now.addingTimeInterval(2))
    #expect(f.quota.windows.first?.used == 30)
}

@Test func claudeRevisions() throws {
    var f = FileIndex()
    for n in [1, 12, 2] {
        f.readClaude(["type": "assistant", "message": ["id": "m", "model": "claude-opus-5", "usage": ["output_tokens": n]]], at: Date())
    }
    #expect(f.events.count == 1)
    #expect(f.events.values.first?.tokens.total == 12)
}

@Test func skipSynthetic() throws {
    var f = FileIndex()
    f.readClaude(["type": "assistant", "message": ["id": "m", "model": "<synthetic>", "usage": ["output_tokens": 20]]], at: Date())
    #expect(f.events.isEmpty)
}

@Test func skipUserContent() throws {
    var f = FileIndex()
    let row = Data(#"{"type":"user","timestamp":"2026-01-01T00:00:00Z","message":{"usage":{"output_tokens":10}}}"#.utf8)
    RecordReader.consume(row, provider: .claude, into: &f)
    #expect(f.events.isEmpty)
}

@Test func corruptJSON() throws {
    var f = FileIndex()
    RecordReader.consume(Data(#"{"output_tokens":3"#.utf8), provider: .claude, into: &f)
    #expect(f.skipped == 1)
    #expect(f.events.isEmpty)
}

@Test func accountMismatch() throws {
    let root: Fields = ["oauthAccount": ["accountUuid": "B"],
        "cachedUsageUtilization": ["accountUuid": "A", "fetchedAtMs": 1000, "utilization": ["five_hour": ["utilization": 42]]]]
    #expect(ClaudeQuota.cached(root) == nil)
}

@Test func claudeWeeklyOnly() throws {
    let q = try #require(ClaudeQuota.parse(["seven_day": ["used_percentage": 8.4, "resets_at": 1000]], observed: Date()))
    #expect(q.windows.count == 1)
    #expect(q.windows.first?.title == "Weekly")
    #expect(q.windows.first?.reset == Date(timeIntervalSince1970: 1000))
}

@Test func claudeCacheDates() throws {
    let q = try #require(ClaudeQuota.cached(["cachedUsageUtilization": ["fetchedAtMs": 2000,
        "utilization": ["five_hour": ["utilization": 0, "resets_at": "2026-11-18T13:00:00.000+00:00"]]]]))
    #expect(q.observed == Date(timeIntervalSince1970: 2))
    #expect(q.windows.first?.used == 0)
    #expect(q.windows.first?.reset != nil)
}
