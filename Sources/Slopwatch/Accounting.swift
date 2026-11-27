import Foundation

struct Activity: Sendable {
    var tokens = 0
    var unpriced = 0
    var dollars = 0.0
    static let binCount = 24
    var modelBins: [String: [Int]] = [:]

    var bins: [Int] {
        modelBins.values.reduce(into: Array(repeating: 0, count: Self.binCount)) { totals, model in
            for i in totals.indices { totals[i] += model[i] }
        }
    }

    mutating func add(_ event: UsageEvent, bin: Int, price: Double?) {
        tokens += event.tokens.total
        let name = event.model.isEmpty ? "Unknown" : event.model
        modelBins[name, default: Array(repeating: 0, count: Self.binCount)][bin] += event.tokens.total
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
                let bin = min(Self.binCount - 1, Int(fraction * Double(Self.binCount)))
                result[interval]?.add(e, bin: bin, price: price)
            }
        }
        return result
    }
}

extension Activity {
    static func + (lhs: Self, rhs: Self) -> Self {
        Self(tokens: lhs.tokens + rhs.tokens, unpriced: lhs.unpriced + rhs.unpriced,
             dollars: lhs.dollars + rhs.dollars,
             modelBins: lhs.modelBins.merging(rhs.modelBins) { zip($0, $1).map(+) })
    }
}
