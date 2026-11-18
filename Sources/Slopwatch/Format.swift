import Foundation

enum Display {
    static func tokens(_ count: Int) -> String {
        let scales = [(1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")]
        for (scale, suffix) in scales where count >= scale {
            return (Double(count) / Double(scale)).formatted(.number.precision(.fractionLength(0...2))) + suffix
        }
        return count.formatted()
    }

    static func money(_ amount: Double) -> String {
        if amount > 0 && amount < 0.01 { return "<$0.01" }
        return amount.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }
}
