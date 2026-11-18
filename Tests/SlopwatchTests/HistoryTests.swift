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

@Test func resumePartialJSON() throws {
    let f = try HistoryFixture()
    defer { f.clean() }
    let a = f.row("a", tokens: 1)
    let b = f.row("b", tokens: 2)
    try Data((a + b.dropLast()).utf8).write(to: f.path)
    let first = try f.scan()
    #expect(first.offset == a.utf8.count)
    let writer = try FileHandle(forWritingTo: f.path)
    try writer.seekToEnd()
    try writer.write(contentsOf: Data([10]))
    try writer.close()
    let second = try f.scan(first)
    #expect(second.events.count == 2)
    #expect(second.offset == a.utf8.count + b.utf8.count)
}

@Test func replacedGrowingLog() throws {
    let f = try HistoryFixture()
    defer { f.clean() }
    try Data(f.row("old", tokens: 1).utf8).write(to: f.path)
    let first = try f.scan()
    let contents = f.row("new", tokens: 2) + f.row("other", tokens: 3)
    let writer = try FileHandle(forWritingTo: f.path)
    try writer.truncate(atOffset: 0)
    try writer.write(contentsOf: Data(contents.utf8))
    try writer.close()
    let next = try f.scan(first)
    #expect(next.inode == first.inode)
    #expect(next.events.count == 2)
    #expect(next.events.values.map(\.tokens.total).reduce(0, +) == 5)
}

@Test func truncateLog() throws {
    let f = try HistoryFixture()
    defer { f.clean() }
    try Data((f.row("a", tokens: 20) + f.row("b", tokens: 30)).utf8).write(to: f.path)
    let first = try f.scan()
    try Data(f.row("a", tokens: 7).utf8).write(to: f.path)
    let next = try f.scan(first)
    #expect(next.events.count == 1)
    #expect(next.events.values.first?.tokens.total == 7)
}
