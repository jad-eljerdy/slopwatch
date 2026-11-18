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
