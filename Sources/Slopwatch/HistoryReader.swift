import Foundation
import CryptoKit

enum HistoryReader {
    static func read(_ file: HistoryFile, previous: FileIndex?, paths: LocalPaths) throws -> FileIndex {
        let append = !file.compressed && previous?.inode == file.inode && (previous?.size ?? 0) < file.size
        var index = append ? previous ?? FileIndex() : FileIndex()
        if index.session.isEmpty { index.session = file.url.deletingPathExtension().lastPathComponent }
        if file.compressed {
            try readArchive(file, index: &index, paths: paths)
        } else {
            let handle = try FileHandle(forReadingFrom: file.url)
            defer { try? handle.close() }
            if append && !checkpointMatches(handle, index: index) {
                index = FileIndex()
                index.session = file.url.deletingPathExtension().lastPathComponent
            }
            try handle.seek(toOffset: index.offset)
            try drain(handle, provider: file.provider, index: &index)
            index.checkpoint = try fingerprint(handle, offset: index.offset)
        }
        index.size = file.size
        index.modified = file.modified
        index.inode = file.inode
        return index
    }
}

extension HistoryReader {
    static func drain(_ handle: FileHandle, provider: Provider, index: inout FileIndex) throws {
        var lines = LineStream()
        while try autoreleasepool(invoking: {
            guard let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty else { return false }
            lines.feed(chunk) { data in
                autoreleasepool { RecordReader.consume(data, provider: provider, into: &index) }
            }
            return true
        }) {}
        index.offset += lines.complete
        index.skipped += lines.skipped
    }
}

extension HistoryReader {
    static func readArchive(_ file: HistoryFile, index: inout FileIndex, paths: LocalPaths) throws {
        guard let decoder = paths.executable("zstd") else { throw CocoaError(.executableNotLoadable) }
        let task = Process()
        let pipe = Pipe()
        task.executableURL = decoder
        task.arguments = ["-qdc", "--", file.url.path]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try task.run()
        defer {
            try? pipe.fileHandleForReading.close()
            if task.isRunning { task.waitUntilExit() }
        }
        try drain(pipe.fileHandleForReading, provider: file.provider, index: &index)
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
    }
}

extension HistoryReader {
    private static func fingerprint(_ handle: FileHandle, offset: UInt64) throws -> Data {
        let size = min(offset, 256)
        try handle.seek(toOffset: offset - size)
        let bytes = size > 0 ? try handle.read(upToCount: Int(size)) ?? Data() : Data()
        return Data(SHA256.hash(data: bytes))
    }

    private static func checkpointMatches(_ handle: FileHandle, index: FileIndex) -> Bool {
        guard let expected = index.checkpoint, let actual = try? fingerprint(handle, offset: index.offset) else { return false }
        return actual == expected
    }
}
