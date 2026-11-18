import Foundation
import CryptoKit

enum HistoryReader {
    static func read(_ file: HistoryFile, previous: FileIndex?) throws -> FileIndex {
        let append = !file.compressed && previous?.inode == file.inode && (previous?.size ?? 0) < file.size
        var index = append ? previous ?? FileIndex() : FileIndex()
        if index.session.isEmpty { index.session = file.url.deletingPathExtension().lastPathComponent }
        let handle = try FileHandle(forReadingFrom: file.url)
        defer { try? handle.close() }
        if !file.compressed {
            if append && !checkpointMatches(handle, index: index) {
                index = FileIndex()
                index.session = file.url.deletingPathExtension().lastPathComponent
            }
            try handle.seek(toOffset: index.offset)
        }
        try drain(handle, file: file, index: &index)
        if !file.compressed {
            index.checkpoint = try fingerprint(handle, offset: index.offset)
        }
        index.size = file.size
        index.modified = file.modified
        index.inode = file.inode
        return index
    }
}

extension HistoryReader {
    private static func drain(_ handle: FileHandle, file: HistoryFile, index: inout FileIndex) throws {
        var lines = LineStream()
        let decoder = file.compressed ? try ZstdDecoder() : nil
        func consume(_ bytes: Data) {
            lines.feed(bytes) { data in
                autoreleasepool { RecordReader.consume(data, provider: file.provider, into: &index) }
            }
        }
        while let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            if let decoder { try decoder.decode(chunk, consume: consume) } else { consume(chunk) }
        }
        try decoder?.finish()
        index.offset += lines.complete
        index.skipped += lines.skipped
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
