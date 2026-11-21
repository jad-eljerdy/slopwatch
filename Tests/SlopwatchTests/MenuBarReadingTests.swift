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
    let reading = MenuBarReading(provider: .claude, report: report, window: .lowest, now: now)
    #expect(reading.lines.first?.limit?.title == "Weekly")
    #expect(reading.lines.first?.percent == (0.13).formatted(.percent))
    #expect(reading.validUntil == expiry)
    #expect(MenuBarReading(provider: .claude, report: report, window: .lowest, now: expiry).lines.first?.percent == "—")
}

@Test func glanceRequiresAConnectedProviderAndFreshReading() {
    let now = Date()
    let limit = Limit(title: "Session", used: 100, reset: nil, observed: now)
    var report = ProviderReport(quota: Quota(windows: [limit]), connection: .signedOut)
    #expect(MenuBarReading(provider: .codex, report: report, window: .lowest, now: now).lines.first?.limit == nil)
    report.connection = .subscription
    let current = MenuBarReading(provider: .codex, report: report, window: .lowest, now: now)
    #expect(current.lines.first?.percent == (0.0).formatted(.percent))
    #expect(current.validUntil == now.addingTimeInterval(300))
    #expect(MenuBarReading(provider: .codex, report: report, window: .lowest, now: now.addingTimeInterval(300)).lines.first?.limit == nil)
    #expect(MenuBarReading(provider: .claude, report: nil, window: .fiveHour, now: now).lines.first?.percent == "—")
}

@Test func explicitWindowsKeepTheirOrderWhenOneIsUnavailable() {
    let now = Date()
    let end = now.addingTimeInterval(200)
    let week = Limit(title: "Weekly", used: 80, reset: now.addingTimeInterval(500), observed: now)
    let short = Limit(title: "5-hour", used: 11, reset: end, observed: now)
    let modelWeek = Limit(title: "Weekly · Opus", used: 99, reset: end, observed: now)
    let report = ProviderReport(quota: Quota(windows: [modelWeek, week, short]), connection: .subscription)
    let single = MenuBarReading(provider: .claude, report: report, window: .fiveHour, now: now)
    #expect(single.lines.map(\.limit?.used) == [11])
    let both = MenuBarReading(provider: .claude, report: report, window: .stacked, now: now)
    #expect(both.lines.map(\.limit?.used) == [11, 80])
    #expect(both.validUntil == end)
    let expired = MenuBarReading(provider: .claude, report: report, window: .stacked, now: end)
    #expect(expired.lines.map(\.limit?.used) == [nil, 80])
    let absent = MenuBarReading(provider: .claude, report: report, window: .fiveHour, now: end)
    #expect(absent.lines.first?.percent == "—")
}

@Test func onlyVisibleChangesInvalidateTheGlanceImage() {
    let now = Date()
    func reading(used: Double, resetIn: TimeInterval) -> MenuBarReading {
        let limit = Limit(title: "5-hour", used: used, reset: now.addingTimeInterval(resetIn), observed: now)
        let report = ProviderReport(quota: Quota(windows: [limit]), connection: .subscription)
        return MenuBarReading(provider: .claude, report: report, window: .stacked, now: now)
    }
    let initial = reading(used: 21.1, resetIn: 300)
    let renewed = reading(used: 21.2, resetIn: 600)
    #expect(initial.validUntil != renewed.validUntil)
    #expect(MenuBarGlyph(initial) == MenuBarGlyph(renewed))
    #expect(MenuBarGlyph(initial) != MenuBarGlyph(reading(used: 22, resetIn: 300)))
}
