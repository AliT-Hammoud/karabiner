import Foundation
import CoreGraphics

/// Tag written into `.eventSourceUserData` on every event we synthesize, so the
/// event tap can recognize and pass through our own events without re-handling
/// them (which would otherwise loop forever).
let kHyperKeySignature: Int64 = 0x4859_504B  // "HYPK"

/// Maps human-readable key names (as used in the config) to virtual key codes
/// (`CGKeyCode`) for a US ANSI keyboard layout, and back.
///
/// Names mirror the Karabiner `key_code` vocabulary where practical so the
/// translation from the legacy `rules.ts` is one-to-one.
enum KeyCodes {
    /// name -> CGKeyCode
    static let byName: [String: CGKeyCode] = [
        // Letters
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
        "o": 0x1F, "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26,
        "k": 0x28, "n": 0x2D, "m": 0x2E,
        // Number row
        "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16,
        "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        // Punctuation
        "equal_sign": 0x18, "minus": 0x1B, "open_bracket": 0x21,
        "close_bracket": 0x1E, "backslash": 0x2A, "semicolon": 0x29,
        "quote": 0x27, "grave_accent_and_tilde": 0x32, "comma": 0x2B,
        "period": 0x2F, "slash": 0x2C,
        // Whitespace / control
        "spacebar": 0x31, "return_or_enter": 0x24, "tab": 0x30,
        "delete_or_backspace": 0x33, "escape": 0x35, "caps_lock": 0x39,
        // Arrows
        "left_arrow": 0x7B, "right_arrow": 0x7C, "down_arrow": 0x7D,
        "up_arrow": 0x7E,
        // Navigation
        "page_up": 0x74, "page_down": 0x79, "home": 0x73, "end": 0x77,
        // Function keys (F18 is our Hyper trigger after the Caps Lock HID remap)
        "f13": 0x69, "f14": 0x6B, "f15": 0x71, "f16": 0x6A, "f17": 0x40,
        "f18": 0x4F, "f19": 0x50, "f20": 0x5A,
    ]

    static let byCode: [CGKeyCode: String] = {
        var out: [CGKeyCode: String] = [:]
        for (name, code) in byName { out[code] = name }
        return out
    }()

    static func code(for name: String) -> CGKeyCode? { byName[name.lowercased()] }
    static func name(for code: CGKeyCode) -> String? { byCode[code] }

    /// The virtual key code that Caps Lock is remapped to (F18).
    static let hyperTrigger: CGKeyCode = 0x4F
}

/// Modifier names used in the config, mapped to `CGEventFlags`.
enum Modifiers {
    static func flags(for names: [String]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for name in names {
            switch name.lowercased() {
            case "command", "left_command", "right_command", "cmd":
                flags.insert(.maskCommand)
            case "shift", "left_shift", "right_shift":
                flags.insert(.maskShift)
            case "control", "left_control", "right_control", "ctrl":
                flags.insert(.maskControl)
            case "option", "left_option", "right_option", "alt":
                flags.insert(.maskAlternate)
            default:
                break
            }
        }
        return flags
    }
}
