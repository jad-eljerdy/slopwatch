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

extension Activity {
    static func rollup(_ events: Dictionary<String, UsageEvent>.Values, now: Date, prices: Pricing) -> [Interval: Self] {
        var result = Dictionary(uniqueKeysWithValues: Interval.allCases.map { ($0, Self()) })
        for e in events {
            let age = now.timeIntervalSince(e.time)
            guard age >= 0, age < Interval.month.seconds else { continue }
            let price = prices.rate(for: e.model)?.dollars(for: e.tokens)
            for interval in Interval.allCases where age < interval.seconds {
                let fraction = 1 - age / interval.seconds
                let bin = min(23, Int(fraction * 24))
                result[interval]?.add(e, bin: bin, price: price)
            }
        }
        return result
    }
}

extension Activity {
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(tokens: lhs.tokens + rhs.tokens, unpriced: lhs.unpriced + rhs.unpriced,
             dollars: lhs.dollars + rhs.dollars, bins: zip(lhs.bins, rhs.bins).map(+))
    }
}
