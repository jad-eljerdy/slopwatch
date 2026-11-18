import Foundation
import Testing
@testable import Slopwatch

@Test func dailyCheckSurvivesRelaunchAndMissedDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let late = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 58)))
    var state = DailyUpdateSchedule()
    #expect(state.isDue(at: late, calendar: calendar))
    state.succeeded(at: late)
    let reopened = try JSONDecoder().decode(DailyUpdateSchedule.self, from: JSONEncoder().encode(state))
    #expect(!reopened.isDue(at: late.addingTimeInterval(60), calendar: calendar))
    #expect(reopened.isDue(at: late.addingTimeInterval(120), calendar: calendar))
    #expect(reopened.isDue(at: late.addingTimeInterval(5 * 86400), calendar: calendar))
    #expect(reopened.isDue(at: late.addingTimeInterval(-86400), calendar: calendar))
}

@Test func failedChecksRetryWithBoundedDelay() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    var now = Date(timeIntervalSince1970: 0)
    var state = DailyUpdateSchedule()
    for delay: Double in [60, 120, 240, 480, 960, 1920, 3600, 3600] {
        state.failed(at: now)
        state = try JSONDecoder().decode(DailyUpdateSchedule.self, from: JSONEncoder().encode(state))
        #expect(!state.isDue(at: now.addingTimeInterval(delay - 1), calendar: calendar))
        now = now.addingTimeInterval(delay)
        #expect(state.isDue(at: now, calendar: calendar))
    }
    state.failed(at: now)
    state.networkRestored()
    #expect(!state.isDue(at: now.addingTimeInterval(59), calendar: calendar))
    #expect(state.isDue(at: now.addingTimeInterval(60), calendar: calendar))
    state.succeeded(at: now.addingTimeInterval(61))
    state.networkRestored()
    #expect(!state.isDue(at: now.addingTimeInterval(62), calendar: calendar))
}

@Test func newLocalDayCanRecoverBeforeRetryDeadline() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    var state = DailyUpdateSchedule()
    state.failed(at: Date(timeIntervalSince1970: 86399))
    #expect(state.isDue(at: Date(timeIntervalSince1970: 86400), calendar: calendar))
}
