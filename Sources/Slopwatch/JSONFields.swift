import Foundation
import CoreFoundation

typealias Fields = [String: Any]

extension Dictionary where Key == String, Value == Any {
    func object(_ key: String) -> Fields { self[key] as? Fields ?? [:] }

    func number(_ key: String) -> Double? {
        guard let value = self[key] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }

    func count(_ key: String) -> Int {
        guard let n = number(key), n >= 0, n < 1e12 else { return 0 }
        return Int(n)
    }
}

func timestamp(_ value: Any?) -> Date? {
    guard let text = value as? String else { return nil }
    return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
        ?? (try? Date.ISO8601FormatStyle().parse(text))
}
