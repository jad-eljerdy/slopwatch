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
