import Foundation
import Testing
@testable import Slopwatch

@Test func codexAuth() throws {
    #expect(CLIStatus.codex("Logged in using ChatGPT", status: 0) == .subscription)
    #expect(CLIStatus.codex("Logged in using an API key", status: 0) == .api)
}
