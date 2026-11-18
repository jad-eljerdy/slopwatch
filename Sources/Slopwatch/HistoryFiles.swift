import Foundation

struct HistoryFile {
    let url: URL
    let provider: Provider
    let modified: Date
    let size: UInt64
    let inode: UInt64
    var compressed: Bool { url.pathExtension == "zst" }
}

extension LocalPaths {
    func history(since cutoff: Date) -> (files: [HistoryFile], failures: Int) {
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        var files: [HistoryFile] = []
        var failures = 0
        for provider in Provider.allCases {
            for root in logs(for: provider) where fm.fileExists(atPath: root.path) {
                let entries = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles], errorHandler: { _, _ in failures += 1; return true })
                guard let entries else { failures += 1; continue }
                for case let url as URL in entries {
                    let name = url.lastPathComponent
                    guard name.hasSuffix(".jsonl") || (provider == .codex && name.hasSuffix(".jsonl.zst")) else { continue }
                    do {
                        let values = try url.resourceValues(forKeys: keys)
                        guard values.isRegularFile == true, values.isSymbolicLink != true,
                              let modified = values.contentModificationDate, modified >= cutoff else { continue }
                        let attr = try fm.attributesOfItem(atPath: url.path)
                        files.append(HistoryFile(url: url, provider: provider, modified: modified,
                            size: UInt64(values.fileSize ?? 0), inode: (attr[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0))
                    } catch { failures += 1 }
                }
            }
        }
        return (files, failures)
    }
}
