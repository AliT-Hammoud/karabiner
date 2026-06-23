import AppKit
import CoreGraphics

/// Executes an `ActionSpec`. Runs on the main thread (the event tap is attached
/// to the main run loop).
enum ActionRunner {
    private static let eventSource = CGEventSource(stateID: .hidSystemState)

    static func run(_ action: ActionSpec) {
        switch action.type {
        case .keystroke:
            if let key = action.key { keystroke(key, modifiers: action.modifiers) }
        case .media:
            if let media = action.media { mediaKey(media) }
        case .launchApp:
            if let app = action.app { AppLauncher.launch(app) }
        case .pickWindow:
            if let app = action.app { AppLauncher.launchWithPicker(app) }
        case .openURL:
            if let url = action.url, let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        case .window:
            if let w = action.window { WindowManager.perform(w) }
        case .shell:
            if let cmd = action.command { shell(cmd) }
        }
    }

    // MARK: - Keystroke synthesis

    static func keystroke(_ keyName: String, modifiers: [String]) {
        guard let code = KeyCodes.code(for: keyName) else { return }
        let flags = Modifiers.flags(for: modifiers)
        postKey(code, flags: flags)
    }

    static func postKey(_ code: CGKeyCode, flags: CGEventFlags) {
        guard let down = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: code, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: kHyperKeySignature)
        up.setIntegerValueField(.eventSourceUserData, value: kHyperKeySignature)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Media / system keys

    // NX_KEYTYPE constants from IOKit/hidsystem/ev_keymap.h
    private enum NX {
        static let soundUp: Int32 = 0
        static let soundDown: Int32 = 1
        static let brightnessUp: Int32 = 2
        static let brightnessDown: Int32 = 3
        static let play: Int32 = 16
        static let next: Int32 = 17
        static let previous: Int32 = 18
    }

    static func mediaKey(_ media: MediaKey) {
        switch media {
        case .volumeUp: postNX(NX.soundUp)
        case .volumeDown: postNX(NX.soundDown)
        case .brightnessUp: postNX(NX.brightnessUp)
        case .brightnessDown: postNX(NX.brightnessDown)
        case .playPause: postNX(NX.play)
        case .next: postNX(NX.next)
        case .previous: postNX(NX.previous)
        case .missionControl:
            // Default macOS shortcut: Control + Up Arrow
            if let up = KeyCodes.code(for: "up_arrow") {
                postKey(up, flags: .maskControl)
            }
        }
    }

    /// Posts a system-defined media key via the NSSystemDefined event path.
    private static func postNX(_ key: Int32) {
        func emit(down: Bool) {
            let flagsRaw: UInt = down ? 0xA00 : 0xB00
            let data1 = Int((key << 16) | ((down ? 0xA : 0xB) << 8))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: flagsRaw),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { return }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
        emit(down: true)
        emit(down: false)
    }

    // MARK: - Shell escape hatch

    static func shell(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        try? process.run()
    }
}
