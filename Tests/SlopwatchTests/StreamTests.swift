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

@Test func oversizedRecord() throws {
    var stream = LineStream(maximum: 4)
    var rows: [Data] = []
    for chunk in ["12345", "678\nok\n"] { stream.feed(Data(chunk.utf8)) { rows.append($0) } }
    #expect(stream.skipped == 1)
    #expect(rows == [Data("ok".utf8)])
    #expect(stream.complete == 12)
}

@Test func exactMaximum() throws {
    var stream = LineStream(maximum: 2)
    var rows = [Data]()
    stream.feed(Data("12\n\n".utf8)) { rows.append($0) }
    #expect(rows.count == 1)
    #expect(stream.skipped == 0)
    #expect(stream.complete == 4)
}
