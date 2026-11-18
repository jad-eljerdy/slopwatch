import AppKit
import SwiftUI

@MainActor
final class MenuController: NSObject, NSApplicationDelegate {
    let model = DashboardModel()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var polling: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.item = item
        item.autosaveName = "Slopwatch"
        item.button?.image = menuBarImage()
        item.button?.toolTip = "Slopwatch · Subscription usage"
        item.button?.setAccessibilityLabel("Slopwatch")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: Dashboard(model: model))
        model.refresh()
        startPolling()
    }

    @objc private func toggle() {
        guard let button = item?.button else { return }
        if popover.isShown { popover.performClose(nil); return }
        model.refreshIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

extension MenuController {
    private func startPolling() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
        polling = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60), tolerance: .seconds(5)) } catch { return }
                self?.model.refreshIfNeeded()
            }
        }
    }

    @objc private func didWake() { model.refresh(force: true) }

    func applicationWillTerminate(_ notification: Notification) {
        polling?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
