import Foundation
import Observation
import Sparkle

@MainActor @Observable
final class DashboardModel {
    var snapshot = Snapshot()
    var interval: Interval
    var provider: Provider?
    var refreshing = false
    let engine = UsageEngine()
    var updater: SPUUpdater?
    private var refreshTask: Task<Void, Never>?

    init() {
        interval = Interval(rawValue: UserDefaults.standard.integer(forKey: "interval")) ?? .day
    }

    func select(_ interval: Interval) {
        self.interval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: "interval")
    }
}

extension DashboardModel {
    func refresh(force: Bool = false) {
        guard refreshTask == nil else { return }
        refreshing = true
        refreshTask = Task {
            snapshot = await engine.refresh(forceAuth: force)
            refreshing = false
            refreshTask = nil
        }
    }

    func refreshIfNeeded() {
        if Date().timeIntervalSince(snapshot.updated ?? .distantPast) >= 20 { refresh() }
    }
}
