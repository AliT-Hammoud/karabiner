import AppKit
import ApplicationServices

/// Native window management via the Accessibility API. Replaces the Raycast
/// window-management commands for halves / maximize / display moves.
enum WindowManager {
    static func perform(_ action: WindowAction) {
        guard let window = focusedWindow() else { return }
        guard let screen = screenForWindow(window) ?? NSScreen.main else { return }

        switch action {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize:
            let frame = targetFrame(for: action, in: screen.visibleFrame)
            setFrame(window, frame, on: screen)
        case .nextDisplay, .previousDisplay:
            moveToAdjacentDisplay(window, from: screen, forward: action == .nextDisplay)
        }
    }

    // MARK: - Frame math (AX uses top-left origin, flipped from Cocoa)

    private static func targetFrame(for action: WindowAction, in visible: NSRect) -> NSRect {
        switch action {
        case .leftHalf:
            return NSRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .rightHalf:
            return NSRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .topHalf:
            // Cocoa origin is bottom-left; "top" half is the upper portion.
            return NSRect(x: visible.minX, y: visible.midY, width: visible.width, height: visible.height / 2)
        case .bottomHalf:
            return NSRect(x: visible.minX, y: visible.minY, width: visible.width, height: visible.height / 2)
        case .maximize:
            return visible
        default:
            return visible
        }
    }

    private static func moveToAdjacentDisplay(_ window: AXUIElement, from current: NSScreen, forward: Bool) {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let idx = screens.firstIndex(of: current) else { return }
        let nextIdx = forward ? (idx + 1) % screens.count
                              : (idx - 1 + screens.count) % screens.count
        let target = screens[nextIdx]
        // Place maximized on the target display.
        setFrame(window, target.visibleFrame, on: target)
    }

    // MARK: - AX helpers

    private static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard result == .success, let window = windowRef else { return nil }
        return (window as! AXUIElement)
    }

    /// Converts a Cocoa (bottom-left origin) rect into AX (top-left origin)
    /// coordinates and applies position + size to the window.
    private static func setFrame(_ window: AXUIElement, _ cocoaFrame: NSRect, on screen: NSScreen) {
        // Global height across all displays for flipping the Y axis.
        let globalHeight = NSScreen.screens.map { $0.frame.maxY }.max() ?? screen.frame.maxY
        var topLeft = CGPoint(x: cocoaFrame.minX, y: globalHeight - cocoaFrame.maxY)
        var size = CGSize(width: cocoaFrame.width, height: cocoaFrame.height)

        if let posValue = AXValueCreate(.cgPoint, &topLeft) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private static func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        var posRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              let posValue = posRef else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)

        // Convert AX top-left point back to Cocoa to find the containing screen.
        let globalHeight = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        let cocoaPoint = CGPoint(x: point.x, y: globalHeight - point.y)
        return NSScreen.screens.first { NSPointInRect(cocoaPoint, $0.frame) }
    }
}
