import Foundation
import Testing
@testable import Slopwatch

@Test func splitLine() throws {
    var stream = LineStream()
    var rows: [String] = []
    for chunk in ["ab", "c\nd", "\ne"] {
        stream.feed(Data(chunk.utf8)) { rows.append(String(decoding: $0, as: UTF8.self)) }
    }
    #expect(rows == ["abc", "d"])
    #expect(stream.complete == 6)
    #expect(stream.consumed == 7)
}
