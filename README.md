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

### Verify the download came from this source

Every release `.dmg` is built by [GitHub Actions](.github/workflows/release.yml)
from a tagged commit and carries a signed [build-provenance
attestation](https://docs.github.com/actions/security-guides/using-artifact-attestations).
You can confirm the binary you downloaded was produced by this repo's public
workflow from a specific commit — not built or swapped out on someone's laptop:

```sh
gh attestation verify Browser-Picker-1.1.dmg --repo nathanabrewer/browser-picker
```

Combined with `codesign -dvv` (Developer ID) and `spctl -a -vv` (Apple
notarization), that gives you a verifiable chain from the source you can read to
the file you run.

## Build from source

Requires macOS 13+ and the Xcode command-line tools.

```sh
./build.sh
cp -R "build/Browser Picker.app" /Applications/
```

`build.sh` compiles the Swift sources, generates the app icon, and codesigns the bundle. Adjust the signing identity / team ID at the top of the script to match your own Developer ID.

## How it works

Browser Picker registers as a handler for `http`/`https` URLs. macOS hands it the URL via a `GetURL` Apple Event; it detects installed browsers with `NSWorkspace.urlsForApplications(toOpen:)`, shows the picker, and launches the chosen browser — using `open -na … --profile-directory=…` for Chromium and `-P` for Firefox to target a specific profile.

## Why not the Mac App Store?

Browser Picker's core features — detecting each browser's profiles and launching
into a specific one — require reading other browsers' profile data (Chrome's
`Local State`, Firefox's `profiles.ini`) and launching them with custom
arguments. Both are forbidden under the App Store's mandatory sandbox, which
jails an app to its own container. A sandboxed build couldn't see your profiles
or launch them; it would be a strictly worse tool.

So it ships the way utilities like [Velja](https://sindresorhus.com/velja),
Rectangle, and Hammerspoon do: as a **notarized direct download**, outside the
store. That unsandboxed access asks for your trust — which is exactly why it's
**open source**: the code that reads your browser data and routes your links is
right here for you to read. Nothing leaves your machine; there is no network
code, no telemetry, no accounts.

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
