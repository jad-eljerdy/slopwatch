import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex = "Codex"
    case claude = "Claude"

    var id: Self { self }
}

enum Interval: Int, CaseIterable, Identifiable, Sendable {
    case day = 1, week = 7, month = 30
    var id: Self { self }
    var seconds: Double { Double(rawValue) * 86_400 }
    var label: String { self == .day ? "24h" : String(rawValue) + "d" }
}
