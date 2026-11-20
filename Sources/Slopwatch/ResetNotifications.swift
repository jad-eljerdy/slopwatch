import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class ResetNotifications {
    private(set) var authorization: UNAuthorizationStatus?
    private(set) var errorMessage: String?
    private var snapshot = Snapshot()
    private var worker: Task<Void, Never>?
    private var dirty = false
    private var askPermission = false
    private let preferences: SettingsPreferences
    private let defaults: UserDefaults
    private let center: any ReminderCenter
    private let recordKey = "scheduledBankedResetReminders"
    private var records: [String: ScheduledReminder]

    init(preferences: SettingsPreferences, defaults: UserDefaults = .standard, center: any ReminderCenter = MacReminderCenter()) {
        self.center = center
        self.preferences = preferences
        self.defaults = defaults
        records = defaults.data(forKey: recordKey).flatMap {
            try? JSONDecoder().decode([String: ScheduledReminder].self, from: $0)
        } ?? [:]
    }

    @discardableResult
    func refresh(snapshot: Snapshot? = nil, requestPermission: Bool = false) -> Task<Void, Never> {
        if let snapshot { self.snapshot = snapshot }
        askPermission = askPermission || requestPermission
        dirty = true
        if let worker { return worker }
        let task = Task {
            while dirty {
                dirty = false
                let ask = askPermission
                askPermission = false
                await reconcile(ask: ask)
            }
            worker = nil
        }
        worker = task
        return task
    }

    private func reconcile(ask: Bool) async {
        let now = Date()
        let reminders = ResetReminder.collect(from: snapshot, previous: records.values.map(\.reminder), at: now)
        var status = await center.authorization()
        authorization = status
        errorMessage = nil
        if status == .notDetermined && preferences.resetRemindersEnabled && (ask || !reminders.isEmpty) {
            do { try await center.askPermission() }
            catch { errorMessage = "macOS could not enable notifications. Try again in System Settings." }
            status = await center.authorization()
        }
        authorization = status
        guard !dirty else { return }
        let allowed = preferences.resetRemindersEnabled && (status == .authorized || status == .provisional)
        if allowed && snapshot.updated == nil { return }
        let pending = Set(await center.pendingIDs().filter { $0.hasPrefix(ResetReminder.prefix) })
        guard !dirty else { return }
        let current = allowed ? reminders : []
        let ids = Set(current.map(\.id))
        let removed = pending.subtracting(ids)
        if !removed.isEmpty { center.cancel(Array(removed)) }
        let knownIDs = Set(reminders.map(\.id))
        records = records.filter { id, record in
            ids.contains(id) || (knownIDs.contains(id) && record.due <= now && !pending.contains(id))
        }
        let lead = preferences.reminderLead
        for reminder in current {
            let now = Date()
            guard !dirty else { break }
            guard reminder.expiry > now else { continue }
            if let last = records[reminder.id],
               !last.needsReplacement(with: reminder, lead: lead, pending: pending.contains(reminder.id), now: now) { continue }
            let due = reminder.due(lead)
            do {
                try await center.schedule(reminder, due: due)
                records[reminder.id] = ScheduledReminder(reminder: reminder, due: due)
            } catch {
                errorMessage = "macOS could not schedule a reminder. Slopwatch will retry on the next limit check."
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(records), defaults.data(forKey: recordKey) != data {
            defaults.set(data, forKey: recordKey)
        }
    }
}

@MainActor
protocol ReminderCenter {
    func authorization() async -> UNAuthorizationStatus
    func askPermission() async throws
    func pendingIDs() async -> [String]
    func cancel(_ ids: [String])
    func schedule(_ reminder: ResetReminder, due: Date) async throws
}

struct MacReminderCenter: ReminderCenter {
    private var center: UNUserNotificationCenter { .current() }

    func authorization() async -> UNAuthorizationStatus {
        guard Bundle.main.bundleIdentifier != nil else { return .denied }
        return await center.notificationSettings().authorizationStatus
    }
    func askPermission() async throws { _ = try await center.requestAuthorization(options: [.alert]) }
    func pendingIDs() async -> [String] {
        guard Bundle.main.bundleIdentifier != nil else { return [] }
        return await center.pendingNotificationRequests().map(\.identifier)
    }
    func cancel(_ ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }

    func schedule(_ reminder: ResetReminder, due: Date) async throws {
        let now = Date()
        let content = UNMutableNotificationContent()
        content.title = reminder.provider.rawValue + (reminder.quantity == 1 ? " reset expires soon" : " resets expire soon")
        let count = reminder.quantity == 1 ? "1 banked reset expires" : "\(reminder.quantity) banked resets expire"
        content.body = count + " on " + reminder.expiry.formatted(date: .abbreviated, time: .shortened) + "."
        let trigger = due > now ? UNTimeIntervalNotificationTrigger(timeInterval: due.timeIntervalSince(now), repeats: false) : nil
        try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }
}

final class ReminderPresentation: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}
