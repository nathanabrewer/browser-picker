# Browser Picker

A tiny macOS menu-bar utility that asks **which browser** (and which profile) should open a link — every time you click one.

Set Browser Picker as your default browser, and instead of links blindly opening in whatever's "default," a small popup lets you choose: Chrome (any profile), Firefox (any profile), Safari, Arc, Brave, Edge, Vivaldi, Opera, and more — all auto-detected.

## Features

- **Per-click browser choice** — a clean popup on every link, dismissable with `Esc`.
- **Profile-aware** — detects Chrome/Chromium profiles (via `Local State`) and Firefox profiles (via `profiles.ini`), and launches into the exact one.
- **"Goto" default** — star a browser/profile to pre-select it.
- **Auto-open mode** — optionally skip the popup and open your starred default instantly; hold <kbd>⌥ Option</kbd> at click time to force the picker back.
- **Drag-to-reorder** the browser list.
- **Lightweight** — an `LSUIElement` agent with no dock icon; it only lives while handling a link.

## Install

1. Download the latest `.dmg` from [Releases](../../releases).
2. Drag **Browser Picker** to `/Applications`.
3. Open it once, then set it as your default browser:
   **System Settings → Desktop & Dock → Default web browser → Browser Picker.**

Builds are signed with a Developer ID and notarized by Apple, so they open without Gatekeeper warnings.

## Build from source

Requires macOS 13+ and the Xcode command-line tools.

```sh
./build.sh
cp -R "build/Browser Picker.app" /Applications/
```

`build.sh` compiles the Swift sources, generates the app icon, and codesigns the bundle. Adjust the signing identity / team ID at the top of the script to match your own Developer ID.

## How it works

Browser Picker registers as a handler for `http`/`https` URLs. macOS hands it the URL via a `GetURL` Apple Event; it detects installed browsers with `NSWorkspace.urlsForApplications(toOpen:)`, shows the picker, and launches the chosen browser — using `open -na … --profile-directory=…` for Chromium and `-P` for Firefox to target a specific profile.

## Project layout

| File | Purpose |
|------|---------|
| `Sources/main.swift` | App delegate, URL-event handling, window management |
| `Sources/PickerView.swift` | SwiftUI picker + settings UI |
| `Sources/BrowserDetector.swift` | Browser/profile detection and launching |
| `Sources/Settings.swift` | Persisted settings model |
| `build.sh` | Compile, icon-gen, codesign |
| `generate_icon.py` | App icon generation |

## License

MIT — see [LICENSE](LICENSE).
