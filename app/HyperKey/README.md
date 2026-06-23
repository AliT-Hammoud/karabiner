# HyperKey

A native macOS menu-bar app that replaces Karabiner-Elements for this repo's
Hyper-key config. It implements the Hyper key, all sublayers, **native window
management**, and **native app launching** — no Karabiner, no yabai/skhd. Raycast
is still used (via `raycast://` URLs) for clipboard/AI/emoji/etc.

## How it works

- **Caps Lock → Hyper:** on start, the app remaps Caps Lock to **F18** using the
  built-in `hidutil` HID user-key mapping (no kernel driver), then treats F18 as
  the Hyper key inside a **CGEventTap**. Tap Caps Lock alone → Escape.
- **Sublayers:** Hyper + a trigger (`b o w s v c r`) enters a sublayer; the next
  key runs its action. A single sublayer is active at a time (same model as the
  old Karabiner variables). Hyper + `space` is a direct binding.
- **Actions:** synthesized keystrokes, media keys, native app launch
  (`NSWorkspace`), URL open, native window management (Accessibility API), an
  Xcode window picker (ports `scripts/pick_window.applescript`), and a shell
  escape hatch.
- **Config:** stored at `~/Library/Application Support/HyperKey/config.json`,
  seeded from `rules.ts`. Edit it in the app's **Settings** window (GUI editor);
  changes apply live.

## Build & run

```bash
cd app/HyperKey
./build.sh              # produces build/HyperKey.app (ad-hoc signed)
open build/HyperKey.app
```

You can also open `Package.swift` in Xcode and run it there.

## First-time setup

1. Launch the app — a keyboard icon appears in the menu bar (no Dock icon).
2. Open **Settings…** → grant the two permissions:
   - **Accessibility** (key events + window management)
   - **Input Monitoring** (observe the keyboard)
   The app polls and auto-starts once both are granted.
3. **Disable / quit Karabiner-Elements** so keys aren't double-handled.
4. Optionally enable **Launch at login** in Settings.

## Signing for distribution (optional)

Your iOS Apple Developer Program membership also covers macOS. To sign with your
team instead of ad-hoc:

```bash
HYPERKEY_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
# then notarize with: xcrun notarytool submit …
```

## Caveats

- macOS may disable the event tap under load / secure-input fields; the app
  re-enables it automatically. Password fields still block synthesized keys.
- Brightness/volume/media use the system `NX_KEYTYPE` event path; brightness can
  be hardware-dependent.
- Quitting the app removes the Caps Lock → F18 remap.

## Source map

| File | Responsibility |
|------|----------------|
| `KeyboardEngine.swift` | CGEventTap + Caps→F18 remap |
| `HyperStateMachine.swift` | Hyper / sublayer state machine |
| `ActionRunner.swift` | keystroke / media / launch / URL / shell |
| `WindowManager.swift` | native window management (AX) |
| `AppLauncher.swift` | app launch/activate + Xcode picker |
| `Config.swift` | config model, store, default seed |
| `AppModel.swift` | app state, permissions, launch-at-login |
| `MenuBarApp.swift` / `SettingsView.swift` | menu bar + GUI editor |
| `KeyCodes.swift` | key-name ↔ keycode tables |
