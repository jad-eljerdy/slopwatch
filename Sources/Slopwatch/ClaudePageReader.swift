import AppKit
import ApplicationServices
import Observation

@MainActor @Observable
final class ClaudePageReader {
    private let defaults: UserDefaults
    private let frontBrowserPID: @MainActor () -> pid_t?
    private var task: Task<Void, Never>?
    private(set) var enabled: Bool
    private(set) var balance: ClaudePageBalance?
    private(set) var message: String?

    init(defaults: UserDefaults = .standard, frontBrowserPID: @escaping @MainActor () -> pid_t? = {
        guard let app = NSWorkspace.shared.frontmostApplication, let id = app.bundleIdentifier,
              ClaudeUsageWindow.browsers.contains(id) else { return nil }
        return app.processIdentifier
    }) {
        self.frontBrowserPID = frontBrowserPID
        self.defaults = defaults
        enabled = defaults.bool(forKey: "readClaudeUsagePage")
        if let data = defaults.data(forKey: "claudePageBalance"),
           let previous = try? JSONDecoder().decode(ClaudePageBalance.self, from: data), previous.isFresh(at: Date()) {
            balance = previous
        }
    }

    func start() {
        guard enabled, task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scan()
                do { try await Task.sleep(for: .seconds(6), tolerance: .seconds(1)) } catch { return }
            }
        }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        defaults.set(value, forKey: "readClaudeUsagePage")
        task?.cancel()
        task = nil
        message = nil
        if value {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            start()
        } else if balance?.source == .browser {
            clear()
        }
    }

    func importSelection(_ text: String, now: Date = Date()) {
        guard let count = ClaudeResetPage.count(in: text) else {
            message = "Copy the Limit resets heading and its available count together."
            return
        }
        record(count, source: .selection, now: now)
    }

    func clear() {
        balance = nil
        message = nil
        defaults.removeObject(forKey: "claudePageBalance")
    }

    private func scan() async {
        let permissionHint = "Allow Slopwatch in System Settings → Privacy & Security → Accessibility, or paste the count."
        guard AXIsProcessTrusted() else {
            message = permissionHint
            return
        }
        if message == permissionHint { message = nil }
        guard let pid = frontBrowserPID() else { return }
        let result = await Task.detached(priority: .utility) { ClaudeUsageWindow.read(pid: pid) }.value
        guard enabled, !Task.isCancelled, pid == frontBrowserPID() else { return }
        switch result {
        case .otherPage: break
        case .usagePage(let count):
            if let count { record(count, source: .browser, now: Date()) }
            else {
                if balance?.source == .browser { clear() }
                message = "The usage page has no readable reset total. You can paste the Limit resets section."
            }
        }
    }

    private func record(_ count: Int, source: ClaudePageBalance.Source, now: Date) {
        message = nil
        if let balance, balance.count == count, balance.source == source,
           (0..<30).contains(now.timeIntervalSince(balance.seen)) { return }
        let reading = ClaudePageBalance(count: count, seen: now, source: source)
        balance = reading
        if let data = try? JSONEncoder().encode(reading) { defaults.set(data, forKey: "claudePageBalance") }
    }
}
