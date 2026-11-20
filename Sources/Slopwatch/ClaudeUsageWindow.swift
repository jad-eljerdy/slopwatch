import ApplicationServices
import Foundation

enum ClaudeUsageWindow {
    enum Reading: Sendable { case otherPage, usagePage(Int?) }

    static let browsers: Set<String> = ["com.apple.Safari", "com.google.Chrome", "com.brave.Browser",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "org.mozilla.firefox"]

    static func read(pid: pid_t) -> Reading {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let raw = attribute(app, kAXFocusedWindowAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return .otherPage }
        let window = raw as! AXUIElement
        if let document = attribute(window, kAXDocumentAttribute) as? String,
           let url = URL(string: document), !ClaudeResetPage.matches(url) { return .otherPage }
        // Chromium exposes its renderer tree lazily when an accessibility client reads the app role.
        _ = attribute(app, kAXRoleAttribute)
        let deadline = ContinuousClock.now + .seconds(2)
        var stack = [window]
        var remaining = 350
        while let node = stack.popLast(), remaining > 0, ContinuousClock.now < deadline {
            remaining -= 1
            if attribute(node, kAXRoleAttribute) as? String == "AXWebArea" {
                guard let url = attribute(node, kAXURLAttribute) as? URL, ClaudeResetPage.matches(url)
                else { continue }
                let count = readBalance(node, deadline: deadline)
                // The user can navigate while the accessibility tree is being read.
                guard let current = attribute(node, kAXURLAttribute) as? URL, ClaudeResetPage.matches(current)
                else { return .otherPage }
                return .usagePage(count)
            }
            stack.append(contentsOf: children(node).reversed())
        }
        return .otherPage
    }

    private static func readBalance(_ page: AXUIElement, deadline: ContinuousClock.Instant) -> Int? {
        var stack = Array(children(page).reversed())
        var remaining = 700
        var lines: [String] = []
        while let node = stack.popLast(), remaining > 0, ContinuousClock.now < deadline {
            remaining -= 1
            let role = attribute(node, kAXRoleAttribute) as? String
            switch role {
            case "AXWebArea", "AXTextField", "AXTextArea", "AXButton", "AXLink", "AXMenu", "AXToolbar":
                continue
            case "AXStaticText", "AXHeading":
                let value = attribute(node, kAXValueAttribute) as? String ?? ""
                if let value = value.isEmpty ? attribute(node, kAXTitleAttribute) as? String : value, !value.isEmpty {
                    lines.append(String(value.prefix(256)))
                    continue
                }
            default: break
            }
            stack.append(contentsOf: children(node).reversed())
        }
        return ClaudeResetPage.count(in: lines.joined(separator: "\n"))
    }

    private static func children(_ node: AXUIElement) -> [AXUIElement] {
        attribute(node, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func attribute(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(node, name as CFString, &value) == .success ? value : nil
    }
}
