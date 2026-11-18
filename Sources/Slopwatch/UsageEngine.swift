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

extension UsageEngine {
    private func summarize(_ sources: [HistoryFile], now: Date) -> Snapshot {
        var result = Snapshot(updated: now)
        var skipped = 0
        for provider in Provider.allCases {
            var unique: [String: UsageEvent] = [:]
            var quota = provider == .claude ? paths.claudeQuota() : Quota()
            for source in sources where source.provider == provider {
                guard let file = files[source.url.path] else { continue }
                skipped += file.skipped
                if file.quota.observed > quota.observed { quota = file.quota }
                for e in file.events.values {
                    if let old = unique[e.id], old.tokens.total > e.tokens.total ||
                        (old.tokens.total == e.tokens.total && old.time <= e.time) { continue }
                    unique[e.id] = e
                }
            }
            result.reports[provider] = ProviderReport(periods: Activity.rollup(unique.values, now: now, prices: .standard), quota: quota)
        }
        if skipped > 0 { result.issues.append("\(skipped) damaged or oversized records were skipped.") }
        return result
    }
}

extension UsageEngine {
    private func updateAuth(now: Date, force: Bool) {
        guard force || now.timeIntervalSince(authChecked) >= 300 else { return }
        for provider in Provider.allCases { auth[provider] = CLIStatus.check(provider, paths: paths) }
        authChecked = now
    }
}
