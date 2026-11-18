import Foundation
import Testing
@testable import Slopwatch

@Test func cacheInclusiveCodexTotal() {
    let t = Tokens(codex: ["input_tokens": 100, "cached_input_tokens": 40, "output_tokens": 20])
    #expect(t.input == 60)
    #expect(t.total == 120)
}
