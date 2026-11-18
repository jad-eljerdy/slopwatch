import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex = "Codex"
    case claude = "Claude"

    var id: Self { self }
}
