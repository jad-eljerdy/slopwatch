import AppKit
import SwiftUI

@MainActor
final class MenuController: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let model = DashboardModel()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var anchorX: CGFloat = 0
    private weak var anchorScreen: NSScreen?
    private weak var observedWindow: NSWindow?
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
        popover.animates = false
        popover.delegate = self
        model.refresh()
        startPolling()
    }

    @objc private func toggle() {
        guard let button = item?.button else { return }
        if popover.isShown { popover.performClose(nil); return }
        guard let statusWindow = button.window else { return }
        let anchor = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let center = CGPoint(x: anchor.midX, y: anchor.midY)
        let display = NSScreen.screens.first { $0.frame.contains(center) }
        let pointer = NSEvent.mouseLocation
        guard let screen = display ?? NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? statusWindow.screen else { return }
        anchorX = display == nil ? pointer.x : center.x
        anchorScreen = screen
        let available = usableArea(on: screen)
        let content = Dashboard(model: model)
        let root = ViewThatFits(in: .vertical) {
            content.fixedSize(horizontal: false, vertical: true)
            ScrollView { content }
        }
        .frame(width: 380)
        .frame(maxHeight: max(1, available.height - 40))
        .fixedSize(horizontal: false, vertical: true)
        let host = NSHostingController(rootView: root)
        popover.contentViewController = host
        popover.contentSize = host.sizeThatFits(in: CGSize(width: 380, height: max(1, available.height - 40)))
        model.refreshIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        host.view.window?.makeKey()
        positionPopover()
    }

    private func usableArea(on screen: NSScreen) -> CGRect {
        PopoverPlacement.availableFrame(display: screen.frame, visible: screen.visibleFrame,
            menuHeight: max(NSStatusBar.system.thickness, screen.safeAreaInsets.top))
    }

    func popoverDidShow(_ notification: Notification) {
        guard let window = popover.contentViewController?.view.window else { return }
        observedWindow = window
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(positionPopover), name: name, object: window)
        }
        positionPopover()
    }

    @objc private func positionPopover() {
        guard popover.isShown, let screen = anchorScreen, let window = popover.contentViewController?.view.window else { return }
        let frame = window.frame
        let origin = PopoverPlacement.origin(for: frame.size, centeredAt: anchorX, in: usableArea(on: screen))
        if abs(origin.y - frame.minY) > 0.5 || abs(origin.x - frame.minX) > 0.5 {
            window.setFrameOrigin(origin)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: observedWindow)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: observedWindow)
        }
        observedWindow = nil
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
