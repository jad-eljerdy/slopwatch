import Foundation

enum ClaudeQuota {
    static func cached(_ root: Fields) -> Quota? {
        let cache = root.object("cachedUsageUtilization")
        if let account = root.object("oauthAccount")["accountUuid"] as? String,
           let source = cache["accountUuid"] as? String, account != source { return nil }
        guard let millis = cache.number("fetchedAtMs") else { return nil }
        let observed = Date(timeIntervalSince1970: millis / 1000)
        return parse(cache.object("utilization"), observed: observed)
    }
}

extension ClaudeQuota {
    static func parse(_ fields: Fields, observed: Date) -> Quota? {
        let names = [("five_hour", "5-hour"), ("seven_day", "Weekly"),
                     ("seven_day_opus", "Weekly · Opus"), ("seven_day_sonnet", "Weekly · Sonnet")]
        var windows = names.compactMap { key, title -> Limit? in
            let w = fields.object(key)
            guard let used = w.number("utilization") ?? w.number("used_percentage"),
                  (0...100).contains(used) else { return nil }
            let reset = timestamp(w["resets_at"]) ?? w.number("resets_at").map(Date.init(timeIntervalSince1970:))
            return Limit(title: title, used: used, reset: reset, observed: observed)
        }
        if let fable = fableLimit(fields, observed: observed) { windows.append(fable) }
        let resets = BankedResets.claude(fields.object("cedar_ember"), now: observed)
        guard !windows.isEmpty || resets != nil else { return nil }
        return Quota(observed: observed, windows: windows, bankedResets: resets)
    }

    private static func fableLimit(_ fields: Fields, observed: Date) -> Limit? {
        func limit(_ row: Fields, percent: String) -> Limit? {
            guard let used = row.number(percent), (0...100).contains(used) else { return nil }
            let reset = timestamp(row["resets_at"]) ?? row.number("resets_at").map(Date.init(timeIntervalSince1970:))
            return Limit(title: "Weekly · Fable", used: used, reset: reset, observed: observed)
        }

        for row in fields["limits"] as? [Fields] ?? [] where row["kind"] as? String == "weekly_scoped" {
            let model = row.object("scope").object("model")
            if (model["display_name"] as? String)?.lowercased() == "fable",
               let reading = limit(row, percent: "percent") { return reading }
        }
        for row in fields["model_scoped"] as? [Fields] ?? [] {
            if (row["display_name"] as? String)?.lowercased() == "fable",
               let reading = limit(row, percent: "utilization") { return reading }
        }
        let window = fields.object("seven_day_fable")
        return limit(window, percent: "utilization") ?? limit(window, percent: "used_percentage")
    }
}

extension LocalPaths {
    var statusCapture: URL { claude.appending(path: "slopwatch-limits.json") }

    func claudeQuota() -> Quota {
        var snapshots = claudeConfigs.compactMap { url -> Quota? in
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? Fields else { return nil }
            return ClaudeQuota.cached(root)
        }
        if let data = try? Data(contentsOf: statusCapture),
           let root = try? JSONSerialization.jsonObject(with: data) as? Fields,
           let epoch = root.number("observed") {
            if let snapshot = ClaudeQuota.parse(root.object("rate_limits"), observed: Date(timeIntervalSince1970: epoch)) {
                snapshots.append(snapshot)
            }
        }
        return snapshots.max { $0.observed < $1.observed } ?? Quota()
    }
}
