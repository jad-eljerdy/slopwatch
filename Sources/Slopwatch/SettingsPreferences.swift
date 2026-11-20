import Foundation
import Observation

enum LimitCheckInterval: Int, CaseIterable {
    case one = 1, three = 3, five = 5, ten = 10, thirty = 30, sixty = 60

    var duration: Duration { .seconds(rawValue * 60) }
}

enum LimitDisplay: String, CaseIterable {
    case remaining = "Remaining"
    case used = "Used"

    var suffix: String { self == .remaining ? "left" : "used" }

    func percent(used: Double) -> Double {
        let value = min(100, max(0, used))
        return self == .remaining ? 100 - value : value
    }
}

@MainActor @Observable
final class SettingsPreferences {
    private let defaults: UserDefaults
    var resetRemindersEnabled: Bool {
        didSet { defaults.set(resetRemindersEnabled, forKey: "resetRemindersEnabled") }
    }
    var reminderLead: ReminderLead {
        didSet { defaults.set(reminderLead.rawValue, forKey: "resetReminderHours") }
    }
    var checkInterval: LimitCheckInterval {
        didSet { defaults.set(checkInterval.rawValue, forKey: "limitCheckMinutes") }
    }
    var claudeWindow: MenuBarWindow {
        didSet { defaults.set(claudeWindow.rawValue, forKey: "menuBarClaudeWindow") }
    }
    var codexWindow: MenuBarWindow {
        didSet { defaults.set(codexWindow.rawValue, forKey: "menuBarCodexWindow") }
    }
    var menuBarDisplay: MenuBarDisplay {
        didSet { defaults.set(menuBarDisplay.rawValue, forKey: "menuBarDisplay") }
    }
    var display: LimitDisplay {
        didSet { defaults.set(display.rawValue, forKey: "limitDisplay") }
    }
    var hideUnused: Bool {
        didSet { defaults.set(hideUnused, forKey: "hideUnusedSubscriptions") }
    }
    var showResets: Bool {
        didSet { defaults.set(showResets, forKey: "showResetTimes") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resetRemindersEnabled = defaults.object(forKey: "resetRemindersEnabled") as? Bool ?? true
        reminderLead = ReminderLead(rawValue: defaults.integer(forKey: "resetReminderHours")) ?? .day
        checkInterval = LimitCheckInterval(rawValue: defaults.integer(forKey: "limitCheckMinutes")) ?? .five
        claudeWindow = defaults.string(forKey: "menuBarClaudeWindow").flatMap(MenuBarWindow.init(rawValue:)) ?? .fiveHour
        codexWindow = defaults.string(forKey: "menuBarCodexWindow").flatMap(MenuBarWindow.init(rawValue:)) ?? .lowest
        menuBarDisplay = defaults.string(forKey: "menuBarDisplay").flatMap(MenuBarDisplay.init(rawValue:)) ?? .both
        display = LimitDisplay(rawValue: defaults.string(forKey: "limitDisplay") ?? "") ?? .remaining
        hideUnused = defaults.bool(forKey: "hideUnusedSubscriptions")
        showResets = defaults.object(forKey: "showResetTimes") as? Bool ?? true
    }

    func shows(_ connection: Connection) -> Bool {
        !hideUnused || connection == .subscription || connection == .checking
    }
}
