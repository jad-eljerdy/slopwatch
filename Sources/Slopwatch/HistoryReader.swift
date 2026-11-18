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
