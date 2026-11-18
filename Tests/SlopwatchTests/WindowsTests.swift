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
