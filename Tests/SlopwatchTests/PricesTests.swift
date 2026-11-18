import Foundation
import Testing
@testable import Slopwatch

@Test func catalogLoaded() throws {
    #expect(Pricing.standard.models.count >= 40)
    #expect(Pricing.standard.rate(for: "gpt-6.2-astra")?.input == 8)
}
