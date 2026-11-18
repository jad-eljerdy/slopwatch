import Foundation

struct HistoryCache {
    let url: URL

    static var local: Self {
        let directory = URL.cachesDirectory.appending(path: "local.slopwatch.app", directoryHint: .isDirectory)
        return Self(url: directory.appending(path: "usage-v1.plist"))
    }

    func load() -> [String: FileIndex] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? PropertyListDecoder().decode([String: FileIndex].self, from: data)) ?? [:]
    }

    func save(_ files: [String: FileIndex]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(files).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
