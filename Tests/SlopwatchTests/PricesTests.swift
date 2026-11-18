import Foundation
import Testing
@testable import Slopwatch

@Test func catalogLoaded() throws {
    #expect(Pricing.standard.models.count >= 40)
    #expect(Pricing.standard.rate(for: "gpt-6.2-astra")?.input == 8)
}

@Test func invalidPriceRows() throws {
    let table = Pricing(table: "bad\t-1\t1\t1\t1\t1\tflat\nshort\t1")
    #expect(table.models.isEmpty)
}

@Test func claudeDatedAlias() throws {
    #expect(Pricing.standard.rate(for: "claude-opus-4-5-20251101")?.output == 25)
}

@Test func openAIDatedAlias() throws {
    #expect(Pricing.standard.rate(for: "gpt-5.4-2026-03-05")?.input == 2.5)
}

@Test func unknownPrice() throws {
    #expect(Pricing.standard.rate(for: "gpt-6-astra-next") == nil)
    #expect(Pricing.standard.rate(for: "codex-auto-review") == nil)
}

@Test func weightedCosts() throws {
    let rate = try #require(Pricing.standard.rate(for: "claude-opus-5-5"))
    let t = Tokens(input: 1_000_000, read: 1_000_000, shortWrite: 1_000_000, longWrite: 1_000_000, output: 1_000_000)
    #expect(abs(rate.dollars(for: t) - 37.2) < 0.000001)
}

@Test func longContext() throws {
    let rate = try #require(Pricing.standard.rate(for: "gpt-6.2-astra"))
    #expect(rate.dollars(for: Tokens(input: 272_000)) == 272_000 * 8.0 / 1e6)
    #expect(rate.dollars(for: Tokens(input: 272_001, output: 10)) == (272_001 * 16.0 + 600) / 1e6)
}

@Test func haikuTier() throws {
    let rate = try #require(Pricing.standard.rate(for: "claude-haiku-5-5"))
    #expect(abs(rate.dollars(for: Tokens(input: 200_000)) - 0.1) < 0.000001)
}
