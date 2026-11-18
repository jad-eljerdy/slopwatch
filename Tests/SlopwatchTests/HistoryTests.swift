import Foundation
import Testing
@testable import Slopwatch

private struct HistoryFixture {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    var path: URL { root.appending(path: "session.jsonl") }

    init() throws { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    func clean() { try? FileManager.default.removeItem(at: root) }

    func row(_ id: String, tokens: Int) -> String {
        #"{"type":"assistant","timestamp":"2026-11-18T12:00:00Z","message":{"id":"\#(id)","model":"claude-opus-5-5","usage":{"output_tokens":\#(tokens)}}}"# + "\n"
    }

    func scan(_ previous: FileIndex? = nil) throws -> FileIndex {
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        let file = HistoryFile(url: path, provider: .claude, modified: Date(),
            size: (attributes[.size] as? NSNumber)?.uint64Value ?? 0,
            inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0)
        return try HistoryReader.read(file, previous: previous, paths: LocalPaths())
    }
}
