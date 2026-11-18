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

struct Tokens: Codable, Equatable, Sendable {
    var input = 0
    var read = 0
    var shortWrite = 0
    var longWrite = 0
    var output = 0

    var prompt: Int { input + read + shortWrite + longWrite }
    var total: Int { prompt + output }
}

struct UsageEvent: Codable, Sendable {
    let id: String
    let time: Date
    let model: String
    let tokens: Tokens
}

struct Limit: Codable, Identifiable, Sendable {
    let title: String
    let used: Double
    let reset: Date?
    let observed: Date

    var id: String { title }
    func isCurrent(at now: Date) -> Bool {
        observed <= now && (reset.map { $0 > now } ?? (now.timeIntervalSince(observed) < 300))
    }
}

enum Connection: String, Sendable {
    case checking = "Checking CLI"
    case subscription = "Connected"
    case api = "API access"
    case signedOut = "Signed out"
    case missing = "CLI missing"
    case unavailable = "Status unavailable"
}

struct Quota: Codable, Sendable {
    var observed = Date.distantPast
    var windows: [Limit] = []
    var plan: String?
}
