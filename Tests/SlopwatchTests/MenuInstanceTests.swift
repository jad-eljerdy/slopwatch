import Foundation
import Testing
@testable import Slopwatch

@Test func onlyOneMenuOwnerUntilExit() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = try #require(try MenuInstance.acquire(in: directory))
    #expect(try MenuInstance.acquire(in: directory) == nil)
    try first.close()
    let next = try #require(try MenuInstance.acquire(in: directory))
    try next.close()
}
