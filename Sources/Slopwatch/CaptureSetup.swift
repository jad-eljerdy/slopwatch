import Foundation

struct CaptureSetup {
    let settings: URL
    let script: URL

    static func local(paths: LocalPaths = LocalPaths()) -> Self? {
        guard let script = Bundle.main.url(forResource: "claude-statusline", withExtension: "sh") else { return nil }
        return Self(settings: paths.claude.appending(path: "settings.json"), script: script)
    }

    var command: String {
        "/bin/sh '" + script.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func read() throws -> (Data?, Fields) {
        guard FileManager.default.fileExists(atPath: settings.path) else { return (nil, [:]) }
        let raw = try Data(contentsOf: settings)
        guard let object = try JSONSerialization.jsonObject(with: raw, options: [.json5Allowed]) as? Fields else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (raw, object)
    }
}

extension CaptureSetup {
    func change(enable: Bool) throws -> String {
        let (original, fields) = try read()
        var updated = fields
        let current = fields.object("statusLine")["command"] as? String
        if enable {
            if current == command { return "Local Claude limit capture is enabled." }
            guard fields["statusLine"] == nil else {
                return "Claude already has a custom status line. Its /usage cache remains available."
            }
            updated["statusLine"] = ["type": "command", "command": command]
        } else {
            guard current == command else { return "Slopwatch does not control this status line." }
            updated.removeValue(forKey: "statusLine")
        }
        let data = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        guard (try? Data(contentsOf: settings)) == original else { throw CocoaError(.fileWriteFileExists) }
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (data + Data([10])).write(to: settings, options: .atomic)
        return enable ? "Enabled. Claude supplies limits after its next model response." : "Disabled local limit capture."
    }
}
