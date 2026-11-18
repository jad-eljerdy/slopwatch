import Foundation

struct ProviderReport: Sendable {
    var periods: [Interval: Activity] = [:]
    var quota = Quota()
    var connection = Connection.checking
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
