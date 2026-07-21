# @mxstbr's Karabiner Elements configuration

If you like TypeScript and want your Karabiner configuration maintainable & type-safe, you probably want to use the custom configuration DSL / generator I created in `rules.ts` and `utils.ts`!

> “This repo is incredible - thanks so much for putting it together! I always avoided Karabiner mostly because of its complicated configuration. **Your project makes it so much easier to work with and so much more powerful. I'm geeking out on how much faster I'm going to be now.**”
>
> — @jhanstra ([source](https://github.com/mxstbr/karabiner/pull/4))

Watch the video about this repo:

[<img width="772" alt="CleanShot 2024-04-17 at 17 47 16@2x" src="https://github.com/mxstbr/karabiner/assets/7525670/c8565c48-10ad-4479-b690-ddc35d1ca8ce">](https://www.youtube.com/watch?v=j4b_uQX3Vu0)

Watch my interview with Raycast for a deeper dive into how I connect this with Raycast as my personal productivity system:

[![](https://github.com/mxstbr/karabiner/assets/7525670/f974cee3-ac92-4f80-8bf7-9efdf81f78b5)](https://www.youtube.com/watch?v=m5MDv9qwhU8)

You probably don't want to use my exact configuration, as it's optimized for my personal style & usage. Best way to go about using this if you want to? Probably delete all the sublayers in `rules.ts` and add your own based on your own needs!

## Installation

1. Install & start [Karabiner Elements](https://karabiner-elements.pqrs.org/)
1. Clone this repository
2. open the repo for the `karabiner`
3. builds the `karabiner.json` from the `rules.ts`.
4. run `yarn build:deploy` to build `karabiner.json` from `rules.ts` and copy it directly into `~/.config/karabiner/` (or run `yarn deploy` to only copy an already-built `karabiner.json`)
5. [Restart karabiner_console_user_server](https://karabiner-elements.pqrs.org/docs/manual/misc/configuration-file-path/) with `` launchctl kickstart -k gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server ``

## Keybindings

Caps Lock is the **Hyper** key (⌃⌥⇧⌘). Tapped on its own it sends `Escape`; held down it activates a sublayer, so every binding below is `Hyper + <sublayer> + <key>`.

`Hyper + Space` creates a Notion todo via Raycast.

### `b` — Browse

| Key | Opens |
| --- | --- |
| `f` | facebook.com |
| `g` | github.com |
| `n` | news.ycombinator.com |
| `t` | twitter.com |
| `y` | youtube.com |

### `o` — Open applications

| Key | App | Key | App |
| --- | --- | --- | --- |
| `a` | Android Studio | `n` | Notion |
| `b` | O**b**sidian | `p` | Postman |
| `c` | Claude | `s` | Simulator |
| `f` | Finder | `t` | Microsoft Teams |
| `g` | Google Chrome | `v` | Visual Studio Code |
| `i` | iTerm2 | `w` | WhatsApp |
| `k` | TickTick | `x` | Xcode (window picker) |
| `l` | WalletApp | `m` | Microsoft Outlook |

`x` runs `scripts/pick_window.applescript` so you can choose between multiple open Xcode windows instead of just focusing the app.

### `w` — Window

| Key | Action |
| --- | --- |
| `h` / `l` | Left / right half |
| `k` / `j` | Top / bottom half |
| `f` | Maximize |
| `y` / `o` | Previous / next display |
| `u` / `i` | Previous / next tab |
| `n` | Next window of the same app |
| `b` / `m` | Back / forward |
| `;` | Hide window |

Window positioning goes through Raycast's window management commands.

**Tab switching (`u` / `i`)** sends `⌃⇧Tab` / `⌃Tab` in most apps. iTerm2 maps those to *most-recently-used* tab order, so when iTerm2 is frontmost the same keys send `⌘⇧[` / `⌘⇧]` instead — iTerm2's positional Previous/Next Tab. This is implemented as two manipulators on the same key, the iTerm2-conditional one first; see the `frontmost_application_if` condition in `rules.ts`.

### `s` — System

| Key | Action |
| --- | --- |
| `a` | Mission Control (**a**ll windows) |
| `u` / `j` | Volume up / down |
| `i` / `k` | Brightness up / down |
| `l` | **L**ock screen |
| `p` | Play / pause |
| `;` | Next track |
| `e` | Toggle Elgato key light |
| `d` | Toggle **d**o not disturb |
| `t` | Toggle system **t**heme |
| `c` | Open **c**amera |
| `v` | **V**oice dictation (`⌥Space`) |

### `v` — moVe

On the left hand so `hjkl` stay vim-like.

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` | Arrow keys |
| `u` / `i` | Page down / page up |
| `m` | Magic**m**ove (homerow.app) |
| `s` | **S**croll mode (homerow.app) |
| `d` | `⇧⌘D` |

### `c` — musi**C**

| Key | Action |
| --- | --- |
| `p` | Play / pause |
| `n` / `b` | Next / previous track |

### `r` — Raycast

| Key | Command |
| --- | --- |
| `c` | Color picker |
| `n` | Dismiss notifications |
| `l` | Create shortlink |
| `e` | Search emoji & symbols |
| `p` | Confetti |
| `a` | Raycast AI chat |
| `s` | Silent mention |
| `h` | Clipboard history |
| `1` / `2` | Connect favorite Bluetooth device 1 / 2 |

### Non-Hyper rules

- **OnMicro K68 keyboard:** it's a PC layout, so the key next to the spacebar reports as Option. Command and Option are swapped back on that device only; the built-in Apple keyboard is untouched.
- **Minecraft:** Backspace sends Space while Minecraft is focused.

## Development

```
yarn install
```

to install the dependencies. (one-time only)

```
yarn run build
```

builds the `karabiner.json` from the `rules.ts`.

```
yarn run watch
```

watches the TypeScript files and rebuilds whenever they change.

## License

Copyright (c) 2022 Maximilian Stoiber, licensed under the [MIT license](./LICENSE.md).
