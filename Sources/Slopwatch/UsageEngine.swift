import Foundation

actor UsageEngine {
    let paths: LocalPaths
    let cache: HistoryCache?
    private var files: [String: FileIndex] = [:]
    private var loaded = false
    private var auth: [Provider: Connection] = [:]
    private var authChecked = Date.distantPast

    init(paths: LocalPaths = LocalPaths(), cache: HistoryCache? = .local) {
        self.paths = paths
        self.cache = cache
    }
}

extension UsageEngine {
    func refresh(now: Date = Date(), forceAuth: Bool = false) -> Snapshot {
        if !loaded { files = cache?.load() ?? [:]; loaded = true }
        let discovery = paths.history(since: now.addingTimeInterval(-Interval.month.seconds))
        var keep = Set<String>()
        var failures = discovery.failures
        var changed = false
        var archiveMissing = false
        for file in discovery.files {
            let key = file.url.path
            keep.insert(key)
            let previous = files[key]
            if previous?.modified == file.modified, previous?.size == file.size, previous?.inode == file.inode { continue }
            do {
                files[key] = try HistoryReader.read(file, previous: previous, paths: paths)
                changed = true
            } catch {
                failures += 1
                if file.compressed && paths.executable("zstd") == nil { archiveMissing = true }
            }
        }
        if files.keys.contains(where: { !keep.contains($0) }) {
            files = files.filter { keep.contains($0.key) }
            changed = true
        }
        var snapshot = summarize(discovery.files, now: now)
        if failures > 0 { snapshot.issues.append("\(failures) log files or folders could not be read.") }
        if archiveMissing { snapshot.issues.append("Install zstd to include compressed Codex history.") }
        if changed {
            do { try cache?.save(files) } catch { snapshot.issues.append("The local index could not be saved.") }
        }
        updateAuth(now: now, force: forceAuth)
        for provider in Provider.allCases { snapshot.reports[provider]?.connection = auth[provider] ?? .unavailable }
        return snapshot
    }
}
