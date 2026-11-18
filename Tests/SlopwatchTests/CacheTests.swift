import Foundation
import Testing
@testable import Slopwatch

@Test func corruptCache() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    try Data("bad".utf8).write(to: file)
    #expect(HistoryCache(url: file).load().isEmpty)
}

@Test func privateCache() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let cache = HistoryCache(url: dir.appending(path: "usage.plist"))
    var file = FileIndex()
    file.offset = 123
    try cache.save(["sample":file])
    #expect(cache.load()["sample"]?.offset == 123)
    let attrs = try FileManager.default.attributesOfItem(atPath: cache.url.path)
    #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}
