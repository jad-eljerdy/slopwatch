import Foundation

struct ResetGrant: Identifiable, Sendable, Codable {
    let id: String
    let title: String
    let quantity: Int
    let expires: Date?
    let heldOnly: Bool
}

struct BankedResets: Sendable, Codable {
    let grants: [ResetGrant]
    // Codex can return a total with only a partial list of individual credits.
    let unlisted: Int
    var presenceOnly = false
    var validUntil: Date?

    func active(at now: Date) -> [ResetGrant] {
        grants.filter { $0.expires.map { $0 > now } ?? true }
            .sorted { ($0.expires ?? .distantFuture, $0.id) < ($1.expires ?? .distantFuture, $1.id) }
    }

    func hasBankedResets(at now: Date) -> Bool {
        guard validUntil.map({ $0 > now }) ?? true else { return false }
        return presenceOnly || unlisted > 0 || !active(at: now).isEmpty
    }

    func summary(at now: Date) -> String? {
        if let validUntil, now >= validUntil { return nil }
        if presenceOnly { return "Banked reset reported" }
        let count = active(at: now).reduce(unlisted) { $0 + $1.quantity }
        return count == 1 ? "1 banked reset" : "\(count) banked resets"
    }

    private static func quantity(_ fields: Fields, _ key: String) -> Int? {
        guard let n = fields.number(key), n >= 0, n <= 1_000_000, n.rounded() == n else { return nil }
        return Int(n)
    }

    static func codex(_ fields: Fields) -> Self? {
        guard let total = quantity(fields, "availableCount") else { return nil }
        var grants: [ResetGrant] = []
        var seen = Set<String>()
        for row in fields["credits"] as? [Fields] ?? [] {
            guard row["status"] as? String == "available", let id = row["id"] as? String,
                  !id.isEmpty, seen.insert(id).inserted, grants.count < total else { continue }
            let title = row["title"] as? String ?? ""
            grants.append(ResetGrant(id: id, title: title.isEmpty ? "Codex reset" : title, quantity: 1,
                expires: row.number("expiresAt").map(Date.init(timeIntervalSince1970:)), heldOnly: false))
        }
        return Self(grants: grants, unlisted: total - grants.count)
    }

    static func claude(_ fields: Fields) -> Self? {
        guard let rows = fields["grants"] as? [Fields] else { return nil }
        var grants: [ResetGrant] = []
        var seen = Set<String>()
        for row in rows {
            guard let id = row["id"] as? String, !id.isEmpty, let count = quantity(row, "resets_left"),
                  seen.insert(id).inserted else { return nil }
            if count == 0 { continue }
            let expires = timestamp(row["ends_at"])
            if row["ends_at"] is String && expires == nil { return nil }
            let title = row["label"] as? String ?? ""
            grants.append(ResetGrant(id: id, title: title.isEmpty ? "Claude reset" : title, quantity: count,
                expires: expires, heldOnly: row["usable_now"] as? Bool != true || row["paused"] as? Bool == true))
        }
        return Self(grants: grants, unlisted: 0)
    }
}

extension LocalPaths {
    func claudeResetHint(now: Date) -> BankedResets? {
        for url in claudeConfigs {
            guard let data = try? Data(contentsOf: url),
                  let root = try? JSONSerialization.jsonObject(with: data) as? Fields,
                  let account = root.object("oauthAccount")["accountUuid"] as? String, !account.isEmpty else { continue }
            let cache = root.object("cachedUsageUtilization")
            let nowMs = now.timeIntervalSince1970 * 1000
            let hint = root.object("unusedLimitResetStatusCache")
            if cache["accountUuid"] as? String == account, let time = cache.number("fetchedAtMs"),
               time <= nowMs, nowMs - time <= 300_000,
               hint["accountUuid"] as? String != account || time >= (hint.number("checkedAt") ?? 0),
               var report = BankedResets.claude(cache.object("utilization").object("cedar_ember")) {
                report.validUntil = Date(timeIntervalSince1970: time / 1000 + 300)
                return report
            }
            guard hint["accountUuid"] as? String == account, let held = hint["holdsUnusedReset"] as? Bool,
                  let checked = hint.number("checkedAt"), let until = hint.number("validUntil"),
                  checked <= now.timeIntervalSince1970 * 1000, until > now.timeIntervalSince1970 * 1000 else { return nil }
            return BankedResets(grants: [], unlisted: 0, presenceOnly: held,
                validUntil: Date(timeIntervalSince1970: until / 1000))
        }
        return nil
    }
}
