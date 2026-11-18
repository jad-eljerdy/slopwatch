import AppKit

@main
struct SlopwatchApp {
    @MainActor static func main() async {
        if CommandLine.arguments.contains("--summary") {
            let snapshot = await UsageEngine().refresh(forceAuth: true)
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
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = MenuController()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
