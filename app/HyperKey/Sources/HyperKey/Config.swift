import Foundation

/// The kind of action a binding performs.
enum ActionType: String, Codable, CaseIterable, Identifiable {
    case keystroke    // synthesize a key + modifiers
    case media        // system media/brightness/volume key
    case launchApp    // launch or activate an application
    case pickWindow   // launch/activate with a window picker (Xcode)
    case openURL      // open a website or raycast:// deeplink
    case window       // native window management
    case shell        // run a shell command (escape hatch)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keystroke: return "Keystroke"
        case .media: return "Media Key"
        case .launchApp: return "Launch App"
        case .pickWindow: return "Launch App + Window Picker"
        case .openURL: return "Open URL"
        case .window: return "Window Management"
        case .shell: return "Shell Command"
        }
    }
}

/// System media keys that require the special NX_KEYTYPE event path.
enum MediaKey: String, Codable, CaseIterable, Identifiable {
    case volumeUp, volumeDown
    case brightnessUp, brightnessDown
    case playPause, next, previous
    case missionControl
    var id: String { rawValue }
}

/// Native window-management actions.
enum WindowAction: String, Codable, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf, maximize
    case nextDisplay, previousDisplay
    var id: String { rawValue }
}

/// A single action. Stored as a flat struct (rather than an enum with
/// associated values) so it round-trips cleanly through JSON and is trivial
/// to bind to GUI fields.
struct ActionSpec: Codable, Equatable, Hashable {
    var type: ActionType
    var key: String? = nil           // keystroke key name
    var modifiers: [String] = []     // keystroke modifiers
    var media: MediaKey? = nil
    var app: String? = nil           // launchApp / pickWindow
    var url: String? = nil           // openURL
    var window: WindowAction? = nil  // window action
    var command: String? = nil       // shell

    // Convenience constructors mirroring the legacy DSL helpers.
    static func keystroke(_ key: String, _ modifiers: [String] = []) -> ActionSpec {
        ActionSpec(type: .keystroke, key: key, modifiers: modifiers)
    }
    static func media(_ m: MediaKey) -> ActionSpec { ActionSpec(type: .media, media: m) }
    static func app(_ name: String) -> ActionSpec { ActionSpec(type: .launchApp, app: name) }
    static func picker(_ name: String) -> ActionSpec { ActionSpec(type: .pickWindow, app: name) }
    static func url(_ u: String) -> ActionSpec { ActionSpec(type: .openURL, url: u) }
    static func win(_ w: WindowAction) -> ActionSpec { ActionSpec(type: .window, window: w) }
    static func shell(_ c: String) -> ActionSpec { ActionSpec(type: .shell, command: c) }

    var summary: String {
        switch type {
        case .keystroke:
            let mods = modifiers.isEmpty ? "" : modifiers.map { $0.replacingOccurrences(of: "_", with: " ") }.joined(separator: "+") + " + "
            return "\(mods)\(key ?? "?")"
        case .media: return media?.rawValue ?? "?"
        case .launchApp: return "Open \(app ?? "?")"
        case .pickWindow: return "Open \(app ?? "?") (picker)"
        case .openURL: return url ?? "?"
        case .window: return window?.rawValue ?? "?"
        case .shell: return command ?? "?"
        }
    }
}

/// One key within a sublayer (or a direct Hyper binding).
struct KeyBinding: Codable, Equatable, Identifiable, Hashable {
    var id: UUID = UUID()
    var key: String          // trigger key name, e.g. "g", "semicolon", "spacebar"
    var description: String = ""
    var action: ActionSpec

    private enum CodingKeys: String, CodingKey { case key, description, action }
}

/// A sublayer activated by Hyper + `trigger`.
struct Sublayer: Codable, Equatable, Identifiable, Hashable {
    var id: UUID = UUID()
    var trigger: String      // e.g. "o", "w", "s"
    var name: String         // human label, e.g. "Open Apps"
    var bindings: [KeyBinding]

    private enum CodingKeys: String, CodingKey { case trigger, name, bindings }
}

/// A per-application key override (e.g. Minecraft: Backspace -> Space).
struct AppOverride: Codable, Equatable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// Matched against the frontmost app's bundle identifier OR executable path
    /// (regex). Either may match.
    var bundleIdContains: String
    var fromKey: String
    var toKey: String

    private enum CodingKeys: String, CodingKey { case name, bundleIdContains, fromKey, toKey }
}

/// The full configuration. Direct bindings fire on Hyper + key; sublayers add
/// a second key. App overrides apply independently of Hyper.
struct Config: Codable, Equatable {
    var directBindings: [KeyBinding]
    var sublayers: [Sublayer]
    var appOverrides: [AppOverride]

    static var `default`: Config {
        Config(
            directBindings: defaultDirect,
            sublayers: [layerB, layerO, layerW, layerS, layerV, layerC, layerR],
            appOverrides: [
                AppOverride(name: "Minecraft", bundleIdContains: "minecraft",
                            fromKey: "delete_or_backspace", toKey: "spacebar"),
            ]
        )
    }

    private static let defaultDirect: [KeyBinding] = [
        KeyBinding(key: "spacebar", description: "Create Notion todo",
                   action: .url("raycast://extensions/stellate/mxstbr-commands/create-notion-todo")),
    ]

    private static let layerB = Sublayer(trigger: "b", name: "Browse", bindings: [
        KeyBinding(key: "f", description: "Facebook", action: .url("https://facebook.com")),
        KeyBinding(key: "g", description: "GitHub", action: .url("https://github.com")),
        KeyBinding(key: "n", description: "Hacker News", action: .url("https://news.ycombinator.com")),
        KeyBinding(key: "t", description: "Twitter", action: .url("https://twitter.com")),
        KeyBinding(key: "y", description: "YouTube", action: .url("https://youtube.com")),
    ])

    private static let layerO = Sublayer(trigger: "o", name: "Open Apps", bindings: [
        KeyBinding(key: "a", description: "Android Studio", action: .app("Android Studio")),
        KeyBinding(key: "b", description: "Obsidian", action: .app("Obsidian")),
        KeyBinding(key: "c", description: "Cursor", action: .app("Cursor")),
        KeyBinding(key: "f", description: "Finder", action: .app("Finder")),
        KeyBinding(key: "g", description: "Google Chrome", action: .app("Google Chrome")),
        KeyBinding(key: "i", description: "iTerm", action: .app("iTerm")),
        KeyBinding(key: "k", description: "TickTick", action: .app("TickTick")),
        KeyBinding(key: "l", description: "WalletApp", action: .app("WalletApp")),
        KeyBinding(key: "m", description: "Microsoft Outlook", action: .app("Microsoft Outlook")),
        KeyBinding(key: "n", description: "Notion", action: .app("Notion")),
        KeyBinding(key: "s", description: "Simulator", action: .app("Simulator")),
        KeyBinding(key: "t", description: "Microsoft Teams", action: .app("Microsoft Teams")),
        KeyBinding(key: "v", description: "Visual Studio Code", action: .app("Visual Studio Code")),
        KeyBinding(key: "w", description: "WhatsApp", action: .app("WhatsApp")),
        KeyBinding(key: "x", description: "Xcode (picker)", action: .picker("Xcode")),
    ])

    private static let layerW = Sublayer(trigger: "w", name: "Window", bindings: [
        KeyBinding(key: "semicolon", description: "Hide window", action: .keystroke("h", ["right_command"])),
        KeyBinding(key: "y", description: "Previous display", action: .win(.previousDisplay)),
        KeyBinding(key: "o", description: "Next display", action: .win(.nextDisplay)),
        KeyBinding(key: "k", description: "Top half", action: .win(.topHalf)),
        KeyBinding(key: "j", description: "Bottom half", action: .win(.bottomHalf)),
        KeyBinding(key: "h", description: "Left half", action: .win(.leftHalf)),
        KeyBinding(key: "l", description: "Right half", action: .win(.rightHalf)),
        KeyBinding(key: "f", description: "Maximize", action: .win(.maximize)),
        KeyBinding(key: "u", description: "Previous tab", action: .keystroke("tab", ["right_control", "right_shift"])),
        KeyBinding(key: "i", description: "Next tab", action: .keystroke("tab", ["right_control"])),
        KeyBinding(key: "n", description: "Next window", action: .keystroke("grave_accent_and_tilde", ["right_command"])),
        KeyBinding(key: "b", description: "Back", action: .keystroke("open_bracket", ["right_command"])),
        KeyBinding(key: "m", description: "Forward", action: .keystroke("close_bracket", ["right_command"])),
    ])

    private static let layerS = Sublayer(trigger: "s", name: "System", bindings: [
        KeyBinding(key: "a", description: "Mission Control", action: .media(.missionControl)),
        KeyBinding(key: "u", description: "Volume up", action: .media(.volumeUp)),
        KeyBinding(key: "j", description: "Volume down", action: .media(.volumeDown)),
        KeyBinding(key: "i", description: "Brightness up", action: .media(.brightnessUp)),
        KeyBinding(key: "k", description: "Brightness down", action: .media(.brightnessDown)),
        KeyBinding(key: "l", description: "Lock screen", action: .keystroke("q", ["right_control", "right_command"])),
        KeyBinding(key: "p", description: "Play / Pause", action: .media(.playPause)),
        KeyBinding(key: "semicolon", description: "Next track", action: .media(.next)),
        KeyBinding(key: "e", description: "Elgato Key Light", action: .url("raycast://extensions/thomas/elgato-key-light/toggle?launchType=background")),
        KeyBinding(key: "d", description: "Do Not Disturb", action: .url("raycast://extensions/yakitrak/do-not-disturb/toggle?launchType=background")),
        KeyBinding(key: "t", description: "Toggle theme", action: .url("raycast://extensions/raycast/system/toggle-system-appearance")),
        KeyBinding(key: "c", description: "Open camera", action: .url("raycast://extensions/raycast/system/open-camera")),
        KeyBinding(key: "v", description: "Voice", action: .keystroke("spacebar", ["left_option"])),
    ])

    private static let layerV = Sublayer(trigger: "v", name: "Move (Vim)", bindings: [
        KeyBinding(key: "h", description: "Left", action: .keystroke("left_arrow")),
        KeyBinding(key: "j", description: "Down", action: .keystroke("down_arrow")),
        KeyBinding(key: "k", description: "Up", action: .keystroke("up_arrow")),
        KeyBinding(key: "l", description: "Right", action: .keystroke("right_arrow")),
        KeyBinding(key: "m", description: "MagicMove (homerow)", action: .keystroke("f", ["right_control"])),
        KeyBinding(key: "s", description: "Scroll mode (homerow)", action: .keystroke("j", ["right_control"])),
        KeyBinding(key: "d", description: "Shift+Cmd+D", action: .keystroke("d", ["right_shift", "right_command"])),
        KeyBinding(key: "u", description: "Page down", action: .keystroke("page_down")),
        KeyBinding(key: "i", description: "Page up", action: .keystroke("page_up")),
    ])

    private static let layerC = Sublayer(trigger: "c", name: "Music", bindings: [
        KeyBinding(key: "p", description: "Play / Pause", action: .media(.playPause)),
        KeyBinding(key: "n", description: "Next track", action: .media(.next)),
        KeyBinding(key: "b", description: "Previous track", action: .media(.previous)),
    ])

    private static let layerR = Sublayer(trigger: "r", name: "Raycast", bindings: [
        KeyBinding(key: "c", description: "Color picker", action: .url("raycast://extensions/thomas/color-picker/pick-color")),
        KeyBinding(key: "n", description: "Dismiss notifications", action: .url("raycast://script-commands/dismiss-notifications")),
        KeyBinding(key: "l", description: "Create shortlink", action: .url("raycast://extensions/stellate/mxstbr-commands/create-mxs-is-shortlink")),
        KeyBinding(key: "e", description: "Emoji & symbols", action: .url("raycast://extensions/raycast/emoji-symbols/search-emoji-symbols")),
        KeyBinding(key: "p", description: "Confetti", action: .url("raycast://extensions/raycast/raycast/confetti")),
        KeyBinding(key: "a", description: "AI Chat", action: .url("raycast://extensions/raycast/raycast-ai/ai-chat")),
        KeyBinding(key: "s", description: "Silent mention", action: .url("raycast://extensions/peduarte/silent-mention/index")),
        KeyBinding(key: "h", description: "Clipboard history", action: .url("raycast://extensions/raycast/clipboard-history/clipboard-history")),
        KeyBinding(key: "1", description: "Connect device 1", action: .url("raycast://extensions/VladCuciureanu/toothpick/connect-favorite-device-1")),
        KeyBinding(key: "2", description: "Connect device 2", action: .url("raycast://extensions/VladCuciureanu/toothpick/connect-favorite-device-2")),
    ])
}

/// Loads and persists `Config` as JSON in Application Support.
final class ConfigStore {
    static let shared = ConfigStore()

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("HyperKey", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("config.json")
    }

    func load() -> Config {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            let def = Config.default
            save(def)
            return def
        }
        return config
    }

    func save(_ config: Config) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    var path: String { fileURL.path }
}
