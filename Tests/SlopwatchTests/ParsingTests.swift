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
