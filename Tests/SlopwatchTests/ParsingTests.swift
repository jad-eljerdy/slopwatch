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
