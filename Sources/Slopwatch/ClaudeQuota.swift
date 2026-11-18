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
