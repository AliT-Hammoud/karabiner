import AppKit
import ApplicationServices

/// Launches / activates applications natively (replacing `open -a`) and provides
/// a window picker for apps with multiple windows (replacing
/// `scripts/pick_window.applescript`).
enum AppLauncher {
    /// Launch the app if not running, otherwise bring it to the front.
    static func launch(_ appName: String) {
        if let running = runningApp(named: appName) {
            running.activate(options: [.activateAllWindows])
            return
        }
        guard let url = appURL(for: appName) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    /// Launch/activate, and if multiple windows are open, show a picker.
    /// Mirrors `pick_window.applescript`: for Xcode keep only windows whose
    /// title contains an em dash ("Project — File"), else fall back to all
    /// named windows.
    static func launchWithPicker(_ appName: String) {
        guard let running = runningApp(named: appName) else {
            launch(appName)
            return
        }

        let appElement = AXUIElementCreateApplication(running.processIdentifier)
        var windowsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        let windows = (windowsRef as? [AXUIElement]) ?? []

        // (title, element) pairs for named windows.
        let named: [(String, AXUIElement)] = windows.compactMap { w in
            guard let t = windowTitle(w), !t.isEmpty else { return nil }
            return (t, w)
        }

        // Primary filter: "Project — File" style titles (em dash).
        var candidates = named.filter { $0.0.contains("—") }
        if candidates.isEmpty { candidates = named }

        if candidates.count > 1 {
            running.activate(options: [.activateAllWindows])
            showPicker(appName: appName, candidates: candidates)
        } else if let only = candidates.first {
            running.activate(options: [.activateAllWindows])
            raise(only.1)
        } else {
            running.activate(options: [.activateAllWindows])
        }
    }

    // MARK: - Picker UI

    private static func showPicker(appName: String, candidates: [(String, AXUIElement)]) {
        let alert = NSAlert()
        alert.messageText = "Pick \(appName) window:"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 25))
        popup.addItems(withTitles: candidates.map { $0.0 })
        alert.accessoryView = popup
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let element = candidates[popup.indexOfSelectedItem].1
            raise(element)
        }
    }

    // MARK: - AX helpers

    private static func windowTitle(_ window: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &ref) == .success
        else { return nil }
        return ref as? String
    }

    private static func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
    }

    // MARK: - App lookup

    private static func runningApp(named appName: String) -> NSRunningApplication? {
        let target = appName.lowercased()
        return NSWorkspace.shared.runningApplications.first { app in
            (app.localizedName?.lowercased() == target)
                || (app.bundleURL?.deletingPathExtension().lastPathComponent.lowercased() == target)
        }
    }

    private static func appURL(for appName: String) -> URL? {
        // Try by display name in the standard Applications locations, then by
        // letting LaunchServices resolve it.
        let name = appName.hasSuffix(".app") ? appName : appName + ".app"
        let candidates = [
            "/Applications/\(name)",
            "/System/Applications/\(name)",
            "\(NSHomeDirectory())/Applications/\(name)",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName)
    }
}
