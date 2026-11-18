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
