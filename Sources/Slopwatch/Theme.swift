import SwiftUI

extension Provider {
    var tint: Color {
        switch self {
        case .codex: Color(red: 0.29, green: 0.73, blue: 0.65)
        case .claude: Color(red: 0.94, green: 0.63, blue: 0.43)
        }
    }

    var symbol: String { self == .codex ? "chevron.left.forwardslash.chevron.right" : "sun.max.fill" }
}

enum Palette {
    static let ink = Color(red: 0.085, green: 0.106, blue: 0.12)
    static let grid = Color.white.opacity(0.13)
}
