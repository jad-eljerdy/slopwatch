import Foundation

struct FileIndex: Codable, Sendable {
    var inode: UInt64 = 0
    var size: UInt64 = 0
    var modified = Date.distantPast
    var offset: UInt64 = 0
    var session = ""
    var model = "Unknown"
    var events: [String: UsageEvent] = [:]
    var quota = Quota()
    var previous: Tokens?
    var skipped = 0
}
