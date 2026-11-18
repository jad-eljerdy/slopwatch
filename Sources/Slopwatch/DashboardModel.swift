import Foundation
import Observation
import Sparkle

@MainActor @Observable
final class DashboardModel {
    let settings = SettingsPreferences()
    var snapshot = Snapshot()
    var interval: Interval
    var provider: Provider?
    var refreshing = false
    let engine = UsageEngine()
    var updater: SPUUpdater?
    private var refreshTask: Task<Void, Never>?

    private var limitTimer: Task<Void, Never>?
    private var lastCheck: ContinuousClock.Instant?
    private var pendingCheck = false

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
        guard refreshTask == nil else {
            pendingCheck = pendingCheck || force
            return
        }
        let checkLimits = force || lastCheck == nil
        if checkLimits {
            limitTimer?.cancel()
            lastCheck = .now
        }
        refreshing = true
        refreshTask = Task {
            snapshot = await engine.refresh(checkLimits: checkLimits)
            refreshing = false
            refreshTask = nil
            if pendingCheck {
                pendingCheck = false
                refresh(force: true)
            } else if checkLimits {
                scheduleLimitCheck()
            }
        }
    }

    func setCheckInterval(_ interval: LimitCheckInterval) {
        settings.checkInterval = interval
        scheduleLimitCheck()
    }

    private func scheduleLimitCheck() {
        limitTimer?.cancel()
        guard let lastCheck else { return }
        let deadline = lastCheck.advanced(by: settings.checkInterval.duration)
        limitTimer = Task { [weak self] in
            do { try await ContinuousClock().sleep(until: deadline) } catch { return }
            self?.refresh(force: true)
        }
    }

    func refreshIfNeeded() {
        if Date().timeIntervalSince(snapshot.updated ?? .distantPast) >= 20 { refresh() }
    }
}
