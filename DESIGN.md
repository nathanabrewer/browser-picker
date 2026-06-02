# Browser Picker — Design Notes

## App icon

**Concept: "one link, many destinations."** A clean browser window sits above a
branching set of paths that diverge to three dots — a fork-in-the-road motif for
choosing which browser/profile a clicked link should open in.

**Form factor (Big Sur+ HIG):**
- Rounded-rect "squircle" background, corner radius ≈ 22.5% of the icon, with the
  standard transparent margin (~8.5% inset) so it sits correctly on the macOS grid.
- Vertical blue gradient (bright azure → deeper blue) with a subtle top highlight
  for a glossy, dimensional feel.
- A single bold white glyph: a rounded browser window (with three small
  traffic-light dots and a title-bar separator) feeding into three curved white
  paths that each terminate in a filled dot.

**Why this glyph:** the previous icon was a generic globe + "?" that read as a
help/unknown affordance and looked muddy at small sizes. The window-and-branches
mark is distinctive, communicates *choosing a browser* directly, and stays legible
down to 16px (the window reads as a window; the branches as routing).

**Implementation (`generate_icon.py`):**
- Pure AppKit / Core Graphics via PyObjC (already used by the project; no new deps).
- Renders all ten required iconset variants (16–512 @1x/@2x) and packs them with
  `iconutil`. Emits the `.icns` to `argv[1]`, unchanged contract with `build.sh`.
- Drawing runs in a subprocess; if PyObjC is unavailable on a build host it falls
  back to a minimal solid-blue PNG so the build never fails.
- Note: this PyObjC build exposes the PNG file-type as the raw enum value `4`
  (`NSBitmapImageFileTypePNG`) rather than the `FileType.PNG` symbol.

Test: `python3 generate_icon.py /tmp/test.icns` runs clean and produces a valid
multi-resolution `.icns`.

## UI polish (behavior unchanged)

### Picker (`PickerView.swift`)
- **Header:** left-aligned "Open With" title; the URL now sits in a tidy pill with
  a `link` glyph, single-line middle-truncated for a calmer, more scannable layout.
- **Search field:** rounded with a clear (✕) button that appears when text is
  entered; consistent corner radii via `clipShape`.
- **Empty state:** a friendly "No browsers match …" placeholder when a filter
  excludes everything, instead of a blank list.
- **Rows:** added a hover chevron affordance, slightly stronger hover tint, and a
  short ease-out animation on hover for a more responsive feel.
- **Footer:** Cancel and the gear are now visually paired chips with helpful
  tooltips (Cancel notes the Esc shortcut).

### About window (`main.swift`)
- Replaced the SF-Symbol globe with an **in-app rendition of the app icon**
  (gradient squircle + browser window + branch glyph) for brand consistency.
- Tightened vertical rhythm with deliberate spacing; primary "Make Default
  Browser" action is full-width and `.large`, with a one-line hint about where it
  leads. Settings is a matching full-width secondary button.
- Clearer typographic hierarchy and "Version 1.1" footer.

All changes keep existing SwiftUI idioms (system fonts, `VisualEffectBackground`,
accent-color usage) and do not alter app behavior, window sizing, or the build.
