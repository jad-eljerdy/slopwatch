import Foundation

actor UsageEngine {
    let paths: LocalPaths
    let cache: HistoryCache?
    private var files: [String: FileIndex] = [:]
    private var loaded = false
    private var auth: [Provider: Connection] = [:]
    private var quotas: [Provider: Quota] = [:]
    private var quotaIssue: String?
    private var cacheSaved = Date.distantPast
    private var cacheDirty = false

    init(paths: LocalPaths = LocalPaths(), cache: HistoryCache? = .local) {
        self.paths = paths
        self.cache = cache
    }
}

extension UsageEngine {
    func refresh(now reference: Date? = nil, checkLimits: Bool = true) -> Snapshot {
        let now = reference ?? Date()
        if !loaded { files = cache?.load() ?? [:]; loaded = true }
        let discovery = paths.history(since: now.addingTimeInterval(-Interval.month.seconds))
        var keep = Set<String>()
        var failures = discovery.failures
        var changed = false
        for file in discovery.files {
            let key = file.url.path
            keep.insert(key)
            let previous = files[key]
            if previous?.modified == file.modified, previous?.size == file.size, previous?.inode == file.inode { continue }
            do {
                var index = try HistoryReader.read(file, previous: previous)
                let cutoff = now.addingTimeInterval(-Interval.month.seconds)
                index.events = index.events.filter { $0.value.time > cutoff }
                files[key] = index
                changed = true
            } catch {
                failures += 1
            }
        }
        if files.keys.contains(where: { !keep.contains($0) }) {
            files = files.filter { keep.contains($0.key) }
            changed = true
        }
        if checkLimits { readLimits(discovery.files) }
        var snapshot = summarize(discovery.files, now: reference ?? Date())
        if failures > 0 { snapshot.issues.append("\(failures) log files or folders could not be read.") }
        cacheDirty = cacheDirty || changed
        if cacheDirty && now.timeIntervalSince(cacheSaved) >= 300 {
            do {
                try cache?.save(files)
                cacheDirty = false
                cacheSaved = now
            } catch { snapshot.issues.append("The local index could not be saved.") }
        }
        if let quotaIssue { snapshot.issues.append(quotaIssue) }
        snapshot.updated = reference ?? Date()
        return snapshot
    }
}

extension UsageEngine {
    private func summarize(_ sources: [HistoryFile], now: Date) -> Snapshot {
        var result = Snapshot(updated: now)
        var skipped = 0
        for provider in Provider.allCases {
            var unique: [String: UsageEvent] = [:]
            for source in sources where source.provider == provider {
                guard let file = files[source.url.path] else { continue }
                skipped += file.skipped
                for e in file.events.values {
                    if let old = unique[e.id], old.tokens.total > e.tokens.total ||
                        (old.tokens.total == e.tokens.total && old.time <= e.time) { continue }
                    unique[e.id] = e
                }
            }
            result.reports[provider] = ProviderReport(periods: Activity.rollup(unique.values, now: now, prices: .standard),
                quota: quotas[provider] ?? Quota(), connection: auth[provider] ?? .checking)
        }
        if skipped > 0 { result.issues.append("\(skipped) damaged or oversized records were skipped.") }
        return result
    }
}

extension UsageEngine {
    private func readLimits(_ sources: [HistoryFile]) {
        quotaIssue = nil
        for provider in Provider.allCases {
            auth[provider] = CLIStatus.check(provider, paths: paths)
            var quota = provider == .claude ? paths.claudeQuota() : Quota()
            for source in sources where source.provider == provider {
                if let reading = files[source.url.path]?.quota, reading.observed > quota.observed {
                    quota = reading
                }
            }
            if provider == .codex && auth[provider] == .subscription {
                quota.bankedResets = CodexResetRequest.fetch(paths: paths)
            }
            if provider == .claude && auth[provider] == .subscription {
                quota.bankedResets = nil
                if let reading = ClaudeUsageRequest.fetch(paths: paths) {
                    quota = reading
                } else {
                    quotaIssue = "Claude Code could not refresh its subscription limits."
                }
                if quota.bankedResets == nil { quota.bankedResets = paths.claudeResetHint(now: Date()) }
            }
            quotas[provider] = quota
        }
    }
}
