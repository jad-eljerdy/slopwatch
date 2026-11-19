import AppKit

@main
struct SlopwatchApp {
    @MainActor static func main() async {
        if CommandLine.arguments.contains("--summary") {
            let snapshot = await UsageEngine().refresh()
            printSummary(snapshot)
            return
        }
        if CommandLine.arguments.contains("--enable-claude-capture") {
            do {
                guard let setup = CaptureSetup.local() else { throw CocoaError(.fileNoSuchFile) }
                print(try setup.change(enable: true))
            } catch { print(error.localizedDescription); exit(1) }
            return
        }
        let lock: FileHandle
        do {
            guard let acquired = try MenuInstance.acquire() else { return }
            lock = acquired
        } catch {
            NSLog("Slopwatch could not acquire the menu bar lock: %@", error.localizedDescription)
            exit(1)
        }
        // Older releases do not acquire the lock. Leave their existing menu item in place.
        let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "local.slopwatch.app")
        guard !existing.contains(where: { $0.processIdentifier != getpid() && $0.isFinishedLaunching && !$0.isTerminated }) else { return }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = MenuController()
        app.delegate = delegate
        withExtendedLifetime((lock, delegate)) { app.run() }
    }
}

extension SlopwatchApp {
    static func printSummary(_ snapshot: Snapshot) {
        for provider in Provider.allCases {
            guard let report = snapshot.reports[provider] else { continue }
            print(provider.rawValue, report.connection.rawValue)
            for interval in Interval.allCases {
                let a = report.periods[interval] ?? Activity()
                print(" ", interval.label, a.tokens, "tokens", Display.estimate(a), "unpriced", a.unpriced)
            }
            if report.connection == .subscription {
                let now = snapshot.updated ?? Date()
                let resets = report.quota.bankedResets
                print(" ", resets?.summary(at: now) ?? "Banked reset balance unavailable")
                for grant in resets?.active(at: now) ?? [] {
                    print(" ", grant.title, "×", grant.quantity, grant.expires.map { "expires " + $0.formatted() } ?? "")
                }
            }
            for limit in report.quota.windows {
                let current = limit.isCurrent(at: snapshot.updated ?? Date())
                print(" ", limit.title, current ? "\(limit.used)% used" : "expired", "observed", limit.observed.formatted())
            }
        }
        for issue in snapshot.issues { print("Partial data:", issue) }
    }
}
