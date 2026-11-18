import Darwin
import Foundation

enum MenuInstance {
    static func acquire(in directory: URL = URL.applicationSupportDirectory.appending(path: "local.slopwatch.app")) throws -> FileHandle? {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let file = directory.appending(path: "menu.lock")
        // Keep the file in place. macOS releases the lock when the owner exits, even after a crash.
        let flags = O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW
        while true {
            let descriptor = open(file.path, flags, 0o600)
            if descriptor >= 0 { return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true) }
            let error = errno
            if error == EWOULDBLOCK { return nil }
            if error != EINTR { throw NSError(domain: NSPOSIXErrorDomain, code: Int(error)) }
        }
    }
}
