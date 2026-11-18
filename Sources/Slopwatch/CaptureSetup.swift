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
