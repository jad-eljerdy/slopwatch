import Foundation
import Testing
@testable import Slopwatch

@Test func usesSectionTotalEvenWhenOnlyOneResetCanBeUsed() {
    let text = """
    Weekly limits
    70% used
    Limit resets
    2 available
    Fable reset
    Reset for free
    """
    #expect(ClaudeResetPage.count(in: text) == 2)
    #expect(ClaudeResetPage.count(in: "Limit resets\nNo resets available") == 0)
    #expect(ClaudeResetPage.count(in: "Limit resets 1 available") == 1)
    #expect(ClaudeResetPage.count(in: "Resets\n3\navailable") == 3)
    #expect(ClaudeResetPage.count(in: "Limit resets\n2\u{a0}resets available") == 2)
}

@Test func invalidAndUnrelatedPageTextKeepBalanceUnknown() {
    for text in ["2 available", "Resets in 5 hours\n2 available", "Limit resets\nReset for free",
                 "Limit resets\nExtra usage\n2 available", "Limit resets\n-1 available",
                 "Limit resets\nNo resets available\nResets\n3 available",
                 "Limit resets\n2 available\n" + String(repeating: "x", count: 65536)] {
        #expect(ClaudeResetPage.count(in: text) == nil)
    }
}

@Test func readerAcceptsOnlyClaudeUsageURLs() {
    for url in ["https://claude.ai/settings/usage", "https://claude.ai/settings/usage/?from=settings"] {
        #expect(ClaudeResetPage.matches(URL(string: url)!))
    }
    for url in ["http://claude.ai/settings/usage", "https://claude.ai/chat/1", "https://claude.ai.evil.example/settings/usage",
                "https://claude.ai:444/settings/usage", "https://x@claude.ai/settings/usage", "https://claude.ai/settings%2Fusage"] {
        #expect(!ClaudeResetPage.matches(URL(string: url)!))
    }
}

@MainActor @Test func userSelectionPersistsOnlyTheNumberSourceAndTime() throws {
    let suite = "slopwatch.page." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let reader = ClaudePageReader(defaults: defaults)
    let now = Date()
    #expect(!reader.enabled)
    reader.importSelection("Limit resets\n2 available\nPrivate unrelated text", now: now)
    let restored = ClaudePageReader(defaults: defaults)
    #expect(restored.balance == ClaudePageBalance(count: 2, seen: now, source: .selection))
    let data = try #require(defaults.data(forKey: "claudePageBalance"))
    let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(fields.keys) == Set(["count", "seen", "source"]))
    #expect(restored.balance?.isFresh(at: now.addingTimeInterval(900)) == false)
    reader.importSelection("weekly reset in 2 hours")
    #expect(reader.message != nil && reader.balance?.count == 2)
    reader.clear()
    #expect(ClaudePageReader(defaults: defaults).balance == nil)
}
