import Foundation
import Testing
@testable import Slopwatch

@Test func corruptCache() throws {
    let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: file) }
    try Data("bad".utf8).write(to: file)
    #expect(HistoryCache(url: file).load().isEmpty)
}
