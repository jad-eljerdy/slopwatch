import Foundation
import Testing
@testable import Slopwatch

@Test func glanceSelectsTheLowestCurrentBalance() {
    let now = Date()
    let expiry = now.addingTimeInterval(3600)
    let report = ProviderReport(quota: Quota(windows: [
        Limit(title: "5-hour", used: 20, reset: expiry, observed: now),
        Limit(title: "Weekly", used: 87, reset: expiry, observed: now),
        Limit(title: "Expired", used: 100, reset: now, observed: now)
    ]), connection: .subscription)
    let reading = MenuBarReading(provider: .claude, report: report, now: now)
    #expect(reading.limit?.title == "Weekly")
    #expect(reading.percent == (0.13).formatted(.percent))
    #expect(reading.validUntil == expiry)
    #expect(MenuBarReading(provider: .claude, report: report, now: expiry).percent == "—")
}

@Test func glanceRequiresAConnectedProviderAndFreshReading() {
    let now = Date()
    let limit = Limit(title: "Session", used: 100, reset: nil, observed: now)
    var report = ProviderReport(quota: Quota(windows: [limit]), connection: .signedOut)
    #expect(MenuBarReading(provider: .codex, report: report, now: now).limit == nil)
    report.connection = .subscription
    let current = MenuBarReading(provider: .codex, report: report, now: now)
    #expect(current.percent == (0.0).formatted(.percent))
    #expect(current.validUntil == now.addingTimeInterval(300))
    #expect(MenuBarReading(provider: .codex, report: report, now: now.addingTimeInterval(300)).limit == nil)
    #expect(MenuBarReading(provider: .claude, report: nil, now: now).percent == "—")
}
