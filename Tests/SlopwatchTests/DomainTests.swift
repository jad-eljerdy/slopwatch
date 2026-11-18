import Foundation
import Testing
@testable import Slopwatch

@Test func cacheInclusiveCodexTotal() {
    let t = Tokens(codex: ["input_tokens": 100, "cached_input_tokens": 40, "output_tokens": 20])
    #expect(t.input == 60)
    #expect(t.total == 120)
}

@Test func reasoningOutput() throws {
    let t = Tokens(codex: ["output_tokens": 20, "reasoning_output_tokens": 18])
    #expect(t.total == 20)
}

@Test func codexWrites() throws {
    let t = Tokens(codex: ["input_tokens": 50, "cached_input_tokens": 10, "cache_write_input_tokens": 25])
    #expect(t == Tokens(input: 15, read: 10, shortWrite: 25))
}

@Test func overreportedHits() throws {
    let t = Tokens(codex: ["input_tokens": 2, "cached_input_tokens": 8])
    #expect(t.read == 2)
    #expect(t.input == 0)
}

@Test func claudeLongWrite() throws {
    let t = Tokens(claude: ["cache_creation_input_tokens": 50, "cache_creation": ["ephemeral_1h_input_tokens": 40]])
    #expect(t.shortWrite == 10)
    #expect(t.longWrite == 40)
}

@Test func claudeLegacyWrites() throws {
    let t = Tokens(claude: ["cache_creation_input_tokens": 8, "cache_read_input_tokens": 16, "input_tokens": 1, "output_tokens": 3])
    #expect(t.total == 28)
    #expect(t.shortWrite == 8)
}

@Test func invalidCounters() throws {
    let fields: Fields = ["flag": true, "negative": -1, "huge": 1e20, "text": "10"]
    for key in fields.keys { #expect(fields.count(key) == 0) }
}

@Test func resetCounters() throws {
    let t = Tokens(input: 10)
    #expect(t.since(Tokens(input: 100)) == t)
}

@Test func incrementCounters() throws {
    let t = Tokens(input: 15, output: 8)
    #expect(t.since(Tokens(input: 10, output: 2)) == Tokens(input: 5, output: 6))
}

@Test func windowDurations() throws {
    #expect(windowTitle(minutes: 300) == "5-hour")
    #expect(windowTitle(minutes: 10_080) == "Weekly")
    #expect(windowTitle(minutes: 120) == "2-hour")
    #expect(windowTitle(minutes: 90) == "90-minute")
    #expect(windowTitle(minutes: nil) == "Session")
}

@Test func quotaExpiry() throws {
    let start = Date(timeIntervalSince1970: 1000)
    let limit = Limit(title: "Weekly", used: 90, reset: start.addingTimeInterval(10), observed: start)
    #expect(limit.isCurrent(at: start))
    #expect(!limit.isCurrent(at: start.addingTimeInterval(10)))
}

@Test func quotaWithoutReset() throws {
    let now = Date()
    let limit = Limit(title: "Session", used: 5, reset: nil, observed: now)
    #expect(limit.isCurrent(at: now))
    #expect(!limit.isCurrent(at: now.addingTimeInterval(301)))
    #expect(!limit.isCurrent(at: now.addingTimeInterval(-1)))
}

@Test func timestampPrecision() throws {
    let whole = try #require(timestamp("2026-11-18T10:00:00Z"))
    let fractional = try #require(timestamp("2026-11-18T12:00:00.125+02:00"))
    #expect(abs(fractional.timeIntervalSince(whole) - 0.125) < 0.0001)
    #expect(timestamp("yesterday") == nil)
}
