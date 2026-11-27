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

@Test func modelCountsFollowTheRangeAndProviderFilter() throws {
    let now = Date()
    func event(_ id: String, _ hoursAgo: Double, _ model: String, _ tokens: Int) -> UsageEvent {
        UsageEvent(id: id, time: now.addingTimeInterval(-hoursAgo * 3600), model: model, tokens: Tokens(read: tokens))
    }
    func report(_ events: [UsageEvent]) -> ProviderReport {
        let unique = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        return ProviderReport(periods: Activity.rollup(unique.values, now: now, prices: .standard))
    }
    let snapshot = Snapshot(reports: [
        .claude: report([event("a", 0, "fable", 5), event("b", 12, "opus", 10), event("c", 24, "fable", 20)]),
        .codex: report([event("d", 0, "gpt", 7), event("e", 168, "gpt", 25)])
    ])
    for (range, fable, opus, gpt) in [(Interval.halfDay, 5, 0, 7), (.day, 5, 10, 7),
                                        (.week, 25, 10, 7), (.month, 25, 10, 32)] {
        let combined = snapshot.activity(range, provider: nil)
        #expect(combined.modelBins["fable"]?.reduce(0, +) == fable)
        #expect((combined.modelBins["opus"]?.reduce(0, +) ?? 0) == opus)
        #expect(combined.modelBins["gpt"]?.reduce(0, +) == gpt)
        #expect(combined.bins.reduce(0, +) == fable + opus + gpt)
        #expect(snapshot.activity(range, provider: .claude).modelBins["gpt"] == nil)
        #expect(snapshot.activity(range, provider: .codex).modelBins["fable"] == nil)
    }
    let day = snapshot.activity(.day, provider: nil)
    #expect(day.bins[12] == 10)
    #expect(day.bins[23] == 12)
    #expect(day.modelBins["opus"]?[23] == 0)
    #expect((day + day).modelBins["fable"]?[23] == 10)
}
