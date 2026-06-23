import AppKit
import CoreGraphics

/// Reproduces the Karabiner variable logic: a `hyper` flag plus a single active
/// sublayer at a time. Pure-ish decision layer — returns `true` to swallow the
/// originating event, and runs actions as a side effect via `ActionRunner`.
final class HyperStateMachine {
    var config: Config

    private var hyperActive = false
    private var activeSublayer: Sublayer?
    private var hyperDownTime: CFTimeInterval = 0
    private var consumedDuringHyper = false

    /// Max hold time for Caps Lock to count as a tap (-> Escape).
    private let tapThreshold: CFTimeInterval = 0.25

    init(config: Config) {
        self.config = config
    }

    // MARK: - Event entry points (return true to swallow)

    func handleKeyDown(keyCode: CGKeyCode, timestamp: CFTimeInterval) -> Bool {
        if keyCode == KeyCodes.hyperTrigger {
            hyperActive = true
            hyperDownTime = timestamp
            consumedDuringHyper = false
            activeSublayer = nil
            return true
        }

        let keyName = KeyCodes.name(for: keyCode)

        if hyperActive {
            consumedDuringHyper = true
            guard let keyName = keyName else { return true }

            // Inside a sublayer: dispatch its binding (or ignore).
            if let sub = activeSublayer {
                if let binding = sub.bindings.first(where: { $0.key == keyName }) {
                    ActionRunner.run(binding.action)
                }
                return true
            }

            // Not yet in a sublayer: is this key a sublayer trigger?
            if let sub = config.sublayers.first(where: { $0.trigger == keyName }) {
                activeSublayer = sub
                return true
            }

            // Direct Hyper binding (e.g. spacebar -> Notion todo)?
            if let binding = config.directBindings.first(where: { $0.key == keyName }) {
                ActionRunner.run(binding.action)
                return true
            }

            // Unbound while Hyper is held: swallow to avoid stray modified input.
            return true
        }

        // Not in Hyper mode: apply per-app overrides (e.g. Minecraft Backspace).
        if let keyName = keyName, let toKey = overrideKey(for: keyName) {
            ActionRunner.keystroke(toKey, modifiers: [])
            return true
        }
        return false
    }

    func handleKeyUp(keyCode: CGKeyCode, timestamp: CFTimeInterval) -> Bool {
        if keyCode == KeyCodes.hyperTrigger {
            let wasTap = hyperActive
                && !consumedDuringHyper
                && (timestamp - hyperDownTime) < tapThreshold
            hyperActive = false
            activeSublayer = nil
            if wasTap {
                ActionRunner.keystroke("escape", modifiers: [])
            }
            return true
        }

        if hyperActive { return true }

        // Swallow the key-up that pairs with a remapped override key-down.
        if let keyName = KeyCodes.name(for: keyCode), overrideKey(for: keyName) != nil {
            return true
        }
        return false
    }

    // MARK: - App overrides

    private func overrideKey(for keyName: String) -> String? {
        guard !config.appOverrides.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let bundle = front.bundleIdentifier?.lowercased() ?? ""
        let path = front.bundleURL?.path.lowercased() ?? ""
        let name = front.localizedName?.lowercased() ?? ""
        for override in config.appOverrides where override.fromKey == keyName {
            let needle = override.bundleIdContains.lowercased()
            if !needle.isEmpty,
               bundle.contains(needle) || path.contains(needle) || name.contains(needle) {
                return override.toKey
            }
        }
        return nil
    }
}
