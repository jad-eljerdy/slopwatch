import Foundation
import Testing
@testable import Slopwatch

@MainActor @Test func settingsSurviveRelaunch() throws {
    let suite = "SlopwatchTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = SettingsPreferences(defaults: defaults)
    #expect(settings.resetRemindersEnabled)
    #expect(settings.reminderLead == .day)
    #expect(settings.checkInterval == .five)
    #expect(settings.display == .remaining)
    #expect(settings.menuBarDisplay == .both)
    #expect(settings.claudeWindow == .fiveHour)
    #expect(settings.codexWindow == .lowest)
    #expect(!settings.hideUnused)
    #expect(settings.showResets)
    #expect(settings.shows(.missing))
    settings.resetRemindersEnabled = false
    settings.reminderLead = .six
    settings.checkInterval = .thirty
    settings.display = .used
    settings.menuBarDisplay = .claude
    settings.claudeWindow = .stacked
    settings.codexWindow = .weekly
    settings.hideUnused = true
    settings.showResets = false
    let reopened = SettingsPreferences(defaults: defaults)
    #expect(!reopened.resetRemindersEnabled)
    #expect(reopened.reminderLead == .six)
    #expect(reopened.checkInterval == .thirty)
    #expect(reopened.display == .used)
    #expect(reopened.menuBarDisplay == .claude)
    #expect(reopened.claudeWindow == .stacked)
    #expect(reopened.codexWindow == .weekly)
    #expect(!reopened.showResets)
    #expect(reopened.shows(.subscription) && reopened.shows(.checking))
    for connection in [Connection.missing, .api, .signedOut, .unavailable] {
        #expect(!reopened.shows(connection))
    }
}

@Test func checkIntervalsAndLimitDirection() {
    #expect(LimitCheckInterval.allCases.map(\.duration) == [60, 180, 300, 600, 1800, 3600].map { .seconds($0) })
    #expect(LimitDisplay.remaining.percent(used: 2) == 98)
    #expect(LimitDisplay.remaining.percent(used: 0) == 100)
    #expect(LimitDisplay.remaining.percent(used: 100) == 0)
    #expect(LimitDisplay.used.percent(used: 2) == 2)
}

@Test func activityScanKeepsLastQuotaUntilNextCheck() async throws {
    let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let bin = home.appending(path: ".local/bin")
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    for cli in ["codex", "claude"] {
        let executable = bin.appending(path: cli)
        try Data("#!/bin/sh\nexit 1\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }
    let paths = LocalPaths(home: home, environment: [:])
    try FileManager.default.createDirectory(at: paths.claude, withIntermediateDirectories: true)
    func record(_ used: Int) throws {
        let data = #"{"observed":100,"rate_limits":{"five_hour":{"used_percentage":\#(used)}}}"#
        try Data(data.utf8).write(to: paths.statusCapture)
    }
    let engine = UsageEngine(paths: paths, cache: nil)
    try record(2)
    let initial = await engine.refresh()
    #expect(initial.reports[.claude]?.quota.windows.first?.used == 2)
    try record(55)
    let background = await engine.refresh(checkLimits: false)
    #expect(background.reports[.claude]?.quota.windows.first?.used == 2)
    let checked = await engine.refresh()
    #expect(checked.reports[.claude]?.quota.windows.first?.used == 55)
}
