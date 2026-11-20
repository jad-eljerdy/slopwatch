import Foundation

struct ClaudePageBalance: Codable, Equatable, Sendable {
    enum Source: String, Codable { case browser = "Browser", selection = "Copied text" }

    let count: Int
    let seen: Date
    let source: Source

    func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince(seen)
        return (0..<900).contains(age) && (0...999).contains(count)
    }

    var label: String { count == 1 ? "1 banked reset" : "\(count) banked resets" }
}

enum ClaudeResetPage {
    static func matches(_ url: URL) -> Bool {
        url.scheme == "https" && url.host()?.lowercased() == "claude.ai" &&
            url.user() == nil && url.password() == nil && (url.port == nil || url.port == 443) &&
            ["/settings/usage", "/settings/usage/"].contains(url.path(percentEncoded: true))
    }

    // Read the explicit subtotal beside the section heading. Individual reset buttons do not
    // represent inventory: one button can represent several grants or only the usable subset.
    static func count(in text: String) -> Int? {
        guard text.utf8.count <= 64 * 1024 else { return nil }
        let lines = text.split(whereSeparator: \.isNewline).map {
            $0.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
        }.filter { !$0.isEmpty }
        var counts = Set<Int>()
        for index in lines.indices {
            let line = lines[index]
            guard let heading = ["limit resets", "resets"].first(where: { line == $0 || line.hasPrefix($0 + " ") })
            else { continue }
            let tail = String(line.dropFirst(heading.count)).trimmingCharacters(in: .whitespaces)
            let candidates = tail.isEmpty ? Array(lines.dropFirst(index + 1).prefix(2)) : [tail]
            guard let first = candidates.first else { continue }
            if let value = subtotal(first) {
                counts.insert(value)
            } else if candidates.count == 2, let value = subtotal(first + " " + candidates[1]) {
                // A browser can expose the number and its label in separate text nodes.
                counts.insert(value)
            }
        }
        return counts.count == 1 ? counts.first : nil
    }

    private static func subtotal(_ line: String) -> Int? {
        if ["no resets available", "no resets available.", "no limit resets available"].contains(line) { return 0 }
        let words = line.split(separator: " ")
        guard let first = words.first, (1...3).contains(first.count),
              first.allSatisfy({ $0.isASCII && $0.isNumber }), let count = Int(first),
              ["available", "reset available", "resets available"].contains(words.dropFirst().joined(separator: " "))
        else { return nil }
        return count
    }
}
