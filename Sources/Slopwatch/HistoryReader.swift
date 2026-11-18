import Foundation

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
            try handle.seek(toOffset: index.offset)
            try drain(handle, provider: file.provider, index: &index)
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
        while let chunk = try handle.read(upToCount: 256 * 1024), !chunk.isEmpty {
            lines.feed(chunk) { data in
                autoreleasepool { RecordReader.consume(data, provider: provider, into: &index) }
            }
        }
        index.offset += lines.complete
        index.skipped += lines.skipped
    }
}
