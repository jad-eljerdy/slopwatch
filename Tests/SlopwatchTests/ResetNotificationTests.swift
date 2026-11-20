import Foundation
import Testing
import UserNotifications
@testable import Slopwatch

private func resetReading(_ provider: Provider, _ dates: [Date?]?, connection: Connection = .subscription) -> Snapshot {
    let inventory = dates.map {
        BankedResets(grants: $0.enumerated().map { index, expiry in
            ResetGrant(id: String(index), title: "Full reset", quantity: 1, expires: expiry, heldOnly: false)
        }, unlisted: 0)
    }
    return Snapshot(reports: [provider: ProviderReport(quota: Quota(bankedResets: inventory), connection: connection)], updated: Date())
}

@MainActor private final class TestReminderCenter: ReminderCenter {
    var status: UNAuthorizationStatus = .notDetermined
    var scheduled: [String: Date] = [:]
    var submissions = 0
    var prompts = 0
    var failNext = false
    func authorization() async -> UNAuthorizationStatus { status }
    func askPermission() async throws { prompts += 1; status = .authorized }
    func pendingIDs() async -> [String] { Array(scheduled.keys) }
    func cancel(_ ids: [String]) { for id in ids { scheduled.removeValue(forKey: id) } }
    func schedule(_ reminder: ResetReminder, due: Date) async throws {
        if failNext { failNext = false; throw CocoaError(.userCancelled) }
        submissions += 1
        if due > Date() { scheduled[reminder.id] = due }
    }
}

@Test func reminderInventoryGroupsDatedResetsByProvider() {
    let now = Date()
    let date = now.addingTimeInterval(3600)
    var snapshot = resetReading(.codex, [nil, now, date, date])
    snapshot.reports[.claude] = resetReading(.claude, [date]).reports[.claude]
    let result = ResetReminder.collect(from: snapshot, previous: [], at: now)
    #expect(result.map(\.quantity).sorted() == [1, 2])
    #expect(Set(result.map(\.id)).count == 2)
}

@MainActor @Test func resetNotificationLifecycle() async throws {
    let suite = "SlopwatchTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = SettingsPreferences(defaults: defaults)
    let center = TestReminderCenter()
    let notifications = ResetNotifications(preferences: preferences, defaults: defaults, center: center)
    let expiry = Date().addingTimeInterval(3 * 86_400)
    let reading = resetReading(.claude, [expiry])
    await notifications.refresh(snapshot: resetReading(.claude, [nil])).value
    #expect(center.prompts == 0)
    await notifications.refresh(snapshot: reading).value
    #expect(center.prompts == 1)
    #expect(center.scheduled.values.first == expiry.addingTimeInterval(-86_400))
    await notifications.refresh(snapshot: resetReading(.claude, nil)).value
    #expect(center.submissions == 1)
    preferences.reminderLead = .six
    await notifications.refresh().value
    #expect(center.scheduled.values.first == expiry.addingTimeInterval(-21_600))
    preferences.resetRemindersEnabled = false
    await notifications.refresh().value
    #expect(center.scheduled.isEmpty)
    preferences.resetRemindersEnabled = true
    center.status = .denied
    await notifications.refresh(snapshot: reading).value
    #expect(center.scheduled.isEmpty)
    center.status = .authorized
    center.failNext = true
    await notifications.refresh().value
    #expect(notifications.errorMessage != nil)
    await notifications.refresh().value
    #expect(center.scheduled.count == 1)
    await notifications.refresh(snapshot: resetReading(.claude, [])).value
    #expect(center.scheduled.isEmpty)
    await notifications.refresh(snapshot: reading).value
    await notifications.refresh(snapshot: resetReading(.claude, nil, connection: .signedOut)).value
    #expect(center.scheduled.isEmpty)
}

@MainActor @Test func lateDetectionAlertsOnlyOnceAcrossRelaunch() async throws {
    let suite = "SlopwatchTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = SettingsPreferences(defaults: defaults)
    let center = TestReminderCenter()
    let reading = resetReading(.codex, [Date().addingTimeInterval(3600)])
    for _ in 0..<2 {
        let notifications = ResetNotifications(preferences: preferences, defaults: defaults, center: center)
        await notifications.refresh(snapshot: reading).value
        await notifications.refresh().value
    }
    #expect(center.submissions == 1)
}

@MainActor @Test func launchRequestsPermissionWithoutAResetInventory() async throws {
    let suite = "SlopwatchTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = SettingsPreferences(defaults: defaults)
    let center = TestReminderCenter()
    let notifications = ResetNotifications(preferences: preferences, defaults: defaults, center: center)
    preferences.resetRemindersEnabled = false
    await notifications.refresh(requestPermission: true).value
    #expect(center.prompts == 0)
    preferences.resetRemindersEnabled = true
    await notifications.refresh(requestPermission: true).value
    await notifications.refresh(requestPermission: true).value
    #expect(center.prompts == 1)
    center.status = .denied
    await notifications.refresh(requestPermission: true).value
    #expect(center.prompts == 1)
    #expect(center.submissions == 0)
}
