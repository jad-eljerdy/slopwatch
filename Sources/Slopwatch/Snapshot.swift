import Foundation

struct ProviderReport: Sendable {
    var periods: [Interval: Activity] = [:]
    var quota = Quota()
    var connection = Connection.checking

    var planLabel: String? {
        guard connection == .subscription,
              let name = quota.plan?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, name.lowercased() != "unknown" else { return nil }
        if name.lowercased() == "prolite" { return "Pro Lite" }
        return name.replacingOccurrences(of: "_", with: " ").split(separator: " ")
            .map { $0.first?.isNumber == true ? String($0) : $0.capitalized }
            .joined(separator: " ")
    }
}

struct Snapshot: Sendable {
    var reports: [Provider: ProviderReport] = [:]
    var updated: Date?
    var issues: [String] = []

    func activity(_ interval: Interval, provider: Provider?) -> Activity {
        if let provider { return reports[provider]?.periods[interval] ?? Activity() }
        return reports.values.reduce(Activity()) { $0 + ($1.periods[interval] ?? Activity()) }
    }
}
