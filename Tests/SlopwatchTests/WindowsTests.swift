import Foundation
import Testing
@testable import Slopwatch

@Test func rollingDayBoundary() throws {
    let now = Date(timeIntervalSince1970: 9_000_000)
    let ages = [0.0, 86_399.9, 86_400.0, -1]
    var events: [String: UsageEvent] = [:]
    for (i, age) in ages.enumerated() {
        let id = String(i)
        events[id] = UsageEvent(id: id, time: now.addingTimeInterval(-age), model: "unknown", tokens: Tokens(input: 1))
    }
    let result = Activity.rollup(events.values, now: now, prices: .standard)
    #expect(result[.day]?.tokens == 2)
    #expect(result[.week]?.tokens == 3)
    #expect(result[.month]?.tokens == 3)
}

@Test func rollingMonthBoundary() throws {
    let now = Date()
    var events: [String: UsageEvent] = [:]
    for age in [Interval.week.seconds, Interval.month.seconds - 1, Interval.month.seconds] {
        let id = String(age)
        events[id] = UsageEvent(id: id, time: now.addingTimeInterval(-age), model: "unknown", tokens: Tokens(output: 1))
    }
    let values = Activity.rollup(events.values, now: now, prices: .standard)
    #expect(values[.week]?.tokens == 0)
    #expect(values[.month]?.tokens == 2)
}

@Test func chartSum() throws {
    let now = Date()
    let one = UsageEvent(id: "x", time: now, model: "unknown", tokens: Tokens(read: 123))
    let report = try #require(Activity.rollup(["x": one].values, now: now, prices: .standard)[.day])
    #expect(report.bins.reduce(0, +) == report.tokens)
    #expect(report.bins.last == 123)
    #expect(report.unpriced == 123)
}

@Test func combinedActivity() throws {
    var snapshot = Snapshot()
    snapshot.reports[.codex] = ProviderReport(periods: [.day: Activity(tokens: 32, dollars: 3)])
    snapshot.reports[.claude] = ProviderReport(periods: [.day: Activity(tokens: 70, dollars: 2)])
    #expect(snapshot.activity(.day, provider: nil).tokens == 102)
    #expect(snapshot.activity(.day, provider: nil).dollars == 5)
    #expect(snapshot.activity(.day, provider: .codex).tokens == 32)
}

@Test func rollingHalfDayUsesThirtyMinuteBins() throws {
    let now = Date()
    let ages = [0, 21_600, 43_199, 43_200, -1]
    let events = Dictionary(uniqueKeysWithValues: ages.map { age in
        let id = String(age)
        return (id, UsageEvent(id: id, time: now.addingTimeInterval(-Double(age)), model: "unknown", tokens: Tokens(input: 1)))
    })
    let periods = Activity.rollup(events.values, now: now, prices: .standard)
    let halfDay = try #require(periods[.halfDay])
    #expect(halfDay.tokens == 3)
    #expect(halfDay.bins[0] == 1)
    #expect(halfDay.bins[12] == 1)
    #expect(halfDay.bins[23] == 1)
    #expect(periods[.day]?.tokens == 4)
    #expect(Interval.allCases.map(\.label) == ["12h", "24h", "7d", "30d"])
}
