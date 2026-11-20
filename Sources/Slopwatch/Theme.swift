import SwiftUI

extension Provider {
    var tint: Color {
        switch self {
        case .codex: Color(red: 0.29, green: 0.73, blue: 0.65)
        case .claude: Color(red: 0.94, green: 0.63, blue: 0.43)
        }
    }
}

struct ProviderIcon: View {
    let provider: Provider
    let size: CGFloat

    static let icons: [Provider: NSImage] = {
        var images: [Provider: NSImage] = [:]
        for provider in Provider.allCases {
            let name = provider == .codex ? "ChatGPT" : "Claude"
            let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "ProviderIcons")
                ?? Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "ProviderIcons")
            if let url { images[provider] = NSImage(contentsOf: url) }
        }
        return images
    }()

    var body: some View {
        if let image = Self.icons[provider] {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
                .frame(width: size, height: size).accessibilityHidden(true)
        }
    }
}

enum Palette {
    static let ink = Color(red: 0.085, green: 0.106, blue: 0.12)
    static let grid = Color.white.opacity(0.13)
}

struct Caption: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold))
            .tracking(1.1).foregroundStyle(.secondary)
    }
}
