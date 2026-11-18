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
