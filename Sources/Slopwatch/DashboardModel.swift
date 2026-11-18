import Foundation
import Observation

@MainActor @Observable
final class DashboardModel {
    var snapshot = Snapshot()
    var interval: Interval
    var provider: Provider?
    var refreshing = false
    var info: String?
    let engine = UsageEngine()
    private var refreshTask: Task<Void, Never>?

    init() {
        interval = Interval(rawValue: UserDefaults.standard.integer(forKey: "interval")) ?? .day
    }

    func select(_ interval: Interval) {
        self.interval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: "interval")
    }
}
