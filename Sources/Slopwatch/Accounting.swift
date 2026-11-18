import Foundation

struct Activity: Sendable {
    var tokens = 0
    var unpriced = 0
    var dollars = 0.0
    var bins = Array(repeating: 0, count: 24)

    mutating func add(_ event: UsageEvent, bin: Int, price: Double?) {
        tokens += event.tokens.total
        bins[bin] += event.tokens.total
        if let price { dollars += price } else { unpriced += event.tokens.total }
    }
}
