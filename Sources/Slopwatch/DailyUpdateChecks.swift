import Foundation
import Network
import Sparkle

struct DailyUpdateSchedule: Codable {
    private(set) var lastSuccess: Date?
    private var lastFailure: Date?
    private var retryDelay: TimeInterval = 0

    func isDue(at now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        if let lastSuccess, calendar.isDate(lastSuccess, inSameDayAs: now) { return false }
        guard let lastFailure, lastFailure <= now, calendar.isDate(lastFailure, inSameDayAs: now) else { return true }
        return now.timeIntervalSince(lastFailure) >= retryDelay
    }

    mutating func succeeded(at now: Date) {
        lastSuccess = now
        lastFailure = nil
        retryDelay = 0
    }

    mutating func failed(at now: Date) {
        lastFailure = now
        retryDelay = min(3600, max(60, retryDelay * 2))
    }

    mutating func networkRestored() {
        // Permit a prompt retry after reconnection, even during a long backoff.
        retryDelay = min(retryDelay, 60)
    }
}

@MainActor
final class DailyUpdateChecks: NSObject, SPUUpdaterDelegate {
    private let monitor = NWPathMonitor()
    private var online: Bool?
    private weak var updater: SPUUpdater?
    private let stateKey = "dailySoftwareUpdateSchedule"
    private var schedule: DailyUpdateSchedule

    override init() {
        let data = UserDefaults.standard.data(forKey: stateKey)
        schedule = data.flatMap { try? JSONDecoder().decode(DailyUpdateSchedule.self, from: $0) } ?? DailyUpdateSchedule()
        super.init()
    }

    func start(with updater: SPUUpdater) {
        self.updater = updater
        monitor.pathUpdateHandler = { [weak self] path in
            MainActor.assumeIsolated { self?.networkChanged(online: path.status == .satisfied) }
        }
        monitor.start(queue: .main)
    }

    func stop() { monitor.cancel() }

    private func networkChanged(online: Bool) {
        if self.online == false && online { schedule.networkRestored() }
        self.online = online
        checkIfDue()
    }

    func checkIfDue() {
        guard online == true, let updater, updater.automaticallyChecksForUpdates,
              !updater.sessionInProgress, schedule.isDue(at: Date()) else { return }
        updater.checkForUpdatesInBackground()
    }

    // Record the result when Sparkle finds it. A manual dialog may stay open overnight.
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        recordSuccess()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        recordSuccess()
    }

    private func recordSuccess() {
        schedule.succeeded(at: Date())
        save()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        guard let error = error as NSError?,
              !(error.domain == SUSparkleErrorDomain && error.code == SUError.noUpdateError.rawValue) else { return }
        schedule.failed(at: Date())
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }
}
