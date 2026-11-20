import AppKit
import SwiftUI
import UserNotifications
import Sparkle

@MainActor
final class MenuController: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let model = DashboardModel()
    private let reminderPresentation = ReminderPresentation()
    private var item: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let popover = NSPopover()
    private var anchorX: CGFloat = 0
    private weak var anchorScreen: NSScreen?
    private weak var observedWindow: NSWindow?
    private let updateChecks = DailyUpdateChecks()
    private var polling: Task<Void, Never>?
    private var glanceView: MenuBarGlanceView?
    private var glanceExpiry: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().delegate = reminderPresentation }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.item = item
        item.autosaveName = "Slopwatch"
        observeMenuBar()
        item.button?.setAccessibilityLabel("Slopwatch")
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            let driver = UpdateUserDriver(hostBundle: .main, delegate: nil)
            let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: updateChecks)
            do {
                try updater.start()
                model.updater = updater
                updateChecks.start(with: updater)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        model.notifications.refresh(requestPermission: true)
        model.claudePage.start()
        model.refresh()
        startPolling()
    }

    private func observeMenuBar() {
        withObservationTracking {
            updateMenuBar()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeMenuBar() }
        }
    }

    private func updateMenuBar() {
        guard let item, let button = item.button else { return }
        glanceExpiry?.cancel()
        glanceView?.removeFromSuperview()
        glanceView = nil
        let providers = model.settings.menuBarDisplay.providers
        if providers.isEmpty {
            item.length = NSStatusItem.squareLength
            button.title = ""
            button.image = menuBarImage()
            button.toolTip = "Slopwatch · Subscription usage"
            button.setAccessibilityValue(nil)
            return
        }

        let now = Date()
        let readings = providers.map { provider in
            MenuBarReading(provider: provider, report: model.snapshot.reports[provider],
                           window: provider == .claude ? model.settings.claudeWindow : model.settings.codexWindow, now: now)
        }
        button.image = nil
        button.title = ""
        let view = MenuBarGlanceView(readings: readings)
        view.translatesAutoresizingMaskIntoConstraints = false
        item.length = ceil(view.fittingSize.width) + 10
        button.addSubview(view)
        NSLayoutConstraint.activate([view.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                                     view.centerYAnchor.constraint(equalTo: button.centerYAnchor)])
        glanceView = view
        let descriptions = readings.map(\.description)
        button.toolTip = descriptions.joined(separator: "\n")
        button.setAccessibilityValue(descriptions.joined(separator: ". "))

        if let expiry = readings.compactMap(\.validUntil).min() {
            glanceExpiry = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow))) } catch { return }
                self?.updateMenuBar()
            }
        }
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
        let root = PanelContent(model: model, openSettings: openSettings, maxHeight: max(1, available.height - 40))
        let host = NSHostingController(rootView: root)
        popover.contentViewController = host
        popover.contentSize = host.sizeThatFits(in: CGSize(width: 380, height: max(1, available.height - 40)))
        model.refreshIfNeeded()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        host.view.window?.makeKey()
        positionPopover()
    }

    private func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil { settingsWindow = SettingsWindow.make(model: model) }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
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
                self?.updateChecks.checkIfDue()
                self?.model.refreshIfNeeded()
            }
        }
    }

    @objc private func didWake() {
        updateMenuBar()
        updateChecks.checkIfDue()
        model.refresh(force: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateChecks.stop()
        polling?.cancel()
        glanceExpiry?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

private struct PanelContent: View {
    let model: DashboardModel
    let openSettings: () -> Void
    let maxHeight: CGFloat
    @State private var contentHeight: CGFloat?

    var body: some View {
        ScrollView {
            Dashboard(model: model, openSettings: openSettings)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 380, height: min(contentHeight.map { ceil($0) } ?? maxHeight, maxHeight))
    }
}
