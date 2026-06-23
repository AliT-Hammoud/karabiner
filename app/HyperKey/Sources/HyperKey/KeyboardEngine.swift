import AppKit
import CoreGraphics
import Combine

/// Owns the CGEventTap and the Caps Lock -> F18 HID remap. Feeds key events to
/// the `HyperStateMachine` and swallows or passes them through accordingly.
final class KeyboardEngine: ObservableObject {
    @Published private(set) var isRunning = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateMachine: HyperStateMachine

    // Caps Lock (0x700000039) -> F18 (0x70000006D) HID usage codes.
    private let capsLockUsage: UInt64 = 0x700000039
    private let f18Usage: UInt64 = 0x70000006D

    init(config: Config) {
        self.stateMachine = HyperStateMachine(config: config)
    }

    func updateConfig(_ config: Config) {
        stateMachine.config = config
    }

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else { return }
        installCapsLockRemap()

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let engine = Unmanaged<KeyboardEngine>.fromOpaque(refcon!).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            NSLog("HyperKey: failed to create event tap (missing permissions?)")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        removeCapsLockRemap()
        isRunning = false
    }

    // MARK: - Tap callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable the tap if the system disabled it under load / secure input.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Pass through events we synthesized ourselves.
        if event.getIntegerValueField(.eventSourceUserData) == kHyperKeySignature {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let now = ProcessInfo.processInfo.systemUptime

        let swallow: Bool
        switch type {
        case .keyDown: swallow = stateMachine.handleKeyDown(keyCode: keyCode, timestamp: now)
        case .keyUp: swallow = stateMachine.handleKeyUp(keyCode: keyCode, timestamp: now)
        default: swallow = false
        }
        return swallow ? nil : Unmanaged.passUnretained(event)
    }

    // MARK: - Caps Lock -> F18 remap (via hidutil)

    private func installCapsLockRemap() {
        let mapping = """
        {"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":\(capsLockUsage),"HIDKeyboardModifierMappingDst":\(f18Usage)}]}
        """
        runHidutil(set: mapping)
    }

    private func removeCapsLockRemap() {
        runHidutil(set: #"{"UserKeyMapping":[]}"#)
    }

    private func runHidutil(set json: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", json]
        try? process.run()
        process.waitUntilExit()
    }
}
