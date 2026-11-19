import Darwin
import Foundation

enum CLIResponseLine {
    static func read(_ handle: FileHandle, buffer: inout Data, until deadline: ContinuousClock.Instant) -> Data? {
        var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
        var bytes = [UInt8](repeating: 0, count: 8192)
        while ContinuousClock.now < deadline {
            if let end = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<end])
                buffer.removeSubrange(...end)
                return line
            }
            guard buffer.count <= 1_048_576 else { return nil }
            let ready = poll(&descriptor, 1, 100)
            if ready < 0 && errno != EINTR { return nil }
            guard ready > 0 else { continue }
            let count = bytes.withUnsafeMutableBytes { Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count) }
            guard count > 0 else { return nil }
            buffer.append(contentsOf: bytes.prefix(count))
        }
        return nil
    }
}
