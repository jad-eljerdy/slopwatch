import Foundation

struct LineStream {
    let maximum: Int
    private var pending = Data()
    private var oversized = false
    private(set) var consumed: UInt64 = 0
    private(set) var complete: UInt64 = 0
    private(set) var skipped = 0

    init(maximum: Int = 16 * 1024 * 1024) { self.maximum = maximum }

    mutating func feed(_ chunk: Data, consume: (Data) -> Void) {
        var start = chunk.startIndex
        while start < chunk.endIndex {
            let end = chunk[start...].firstIndex(of: 10) ?? chunk.endIndex
            if !oversized {
                if pending.count + end - start > maximum {
                    oversized = true
                    pending.removeAll(keepingCapacity: false)
                } else {
                    pending.append(chunk[start..<end])
                }
            }
            consumed += UInt64(end - start)
            guard end < chunk.endIndex else { break }
            consumed += 1
            complete = consumed
            if oversized { skipped += 1 } else if !pending.isEmpty { consume(pending) }
            pending.removeAll(keepingCapacity: true)
            oversized = false
            start = end + 1
        }
    }
}
