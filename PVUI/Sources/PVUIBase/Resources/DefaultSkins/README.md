# Default DeltaSkin Bundles for Third-Party Physical Button Cases

This directory contains DeltaSkin bundles for known third-party physical button cases and controllers.
These skins are bundled with Provenance and loaded automatically via `DeltaSkinManager`.

## Purpose

When a compatible physical controller case is detected, Provenance can auto-load the appropriate skin
to optimise the game screen layout. Since physical buttons handle all input, these skins:

1. Maximise the game screen area (no on-screen button overlay needed)
2. Render a visual controller overlay using SVG artwork so players can see approximate button positions
3. Support both standard and edge-to-edge iPhone display types, plus iPad

## Coordinate System

All button and screen coordinates are in the skin's **mapping coordinate space** (not 0–1 normalised).

### Portrait grip controllers (PocketTaco, Soolra)
- **Standard portrait**: `750 × 1334` (logical pixels, equivalent to iPhone 6/7/8)
- **Edge-to-edge portrait**: `393 × 852` (logical points for iPhone 14/15/16)
- **iPad standard portrait**: `768 × 1024`
- **iPad edge-to-edge portrait**: `820 × 1180`

### Landscape clamshell controllers (Backbone, Razer Kishi)
- **Standard landscape**: `1334 × 750`
- **Edge-to-edge landscape**: `852 × 393`
- **iPad standard landscape**: `1366 × 1024`
- **iPad edge-to-edge landscape**: `1180 × 820`

Button `frame` values represent approximate physical positions estimated from product photographs
and typical MFi controller ergonomics. **All coordinates require real-device calibration.**

## Included Skins

### GameSir Pocket Taco (`PocketTaco-*.deltaskin`)

The GameSir Pocket Taco is a clip-on physical MFi Bluetooth controller for iPhone.
The phone sits in the top portion of the controller; physical buttons are on the grip body below.

- **Form factor**: Grip controller with phone clipped into top
- **Connectivity**: Bluetooth MFi
- **Systems covered**: NES, SNES, GBA, GBC, Genesis, N64
- **Calibration status**: NEEDS CALIBRATION — coordinates estimated from product photos

### Soolra Controller (`Soolra-*.deltaskin`)

The Soolra is a full MFi layout physical controller for iPhone with buttons on both sides.

- **Form factor**: Grip controller with integrated iPhone mount
- **Connectivity**: Bluetooth MFi
- **Systems covered**: NES, SNES, GBA, GBC, Genesis
- **Calibration status**: NEEDS CALIBRATION — coordinates estimated from product photos

### Backbone One (`Backbone-*.deltaskin`)

The Backbone One is a landscape clamshell MFi controller. The phone clips into the middle.

- **Form factor**: Landscape clamshell, phone in centre
- **Connectivity**: Lightning / USB-C
- **Systems covered**: NES, SNES, GBA, GBC, Genesis, N64
- **Calibration status**: NEEDS CALIBRATION — coordinates estimated from product photos

### Razer Kishi v2 (`RazerKishi-*.deltaskin`)

The Razer Kishi v2 is a landscape clamshell MFi controller similar to the Backbone.

- **Form factor**: Landscape clamshell, phone in centre
- **Connectivity**: USB-C
- **Systems covered**: NES, SNES, GBA, GBC, Genesis
- **Calibration status**: NEEDS CALIBRATION — coordinates estimated from product photos

## File Format

Each `.deltaskin` bundle contains:
- `info.json` — skin metadata, button/screen mappings, and asset reference
- `controller.svg` — SVG controller artwork (transparent background, semi-opaque button shapes)
- `transparent.png` — 1×1 transparent PNG placeholder (fallback for older loading paths)

The `controller.svg` uses a transparent background so the game screen shows through.
Each button area is drawn with a semi-transparent fill (opacity 0.85) and a coloured stroke
indicating the button type (A=red, B=yellow, X=blue, Y=green, C=purple, D-pad=dark, L/R=dark).

## Generating / Regenerating Skins

The Python script `Scripts/generate_default_skins.py` regenerates all bundles:

```bash
python3 Scripts/generate_default_skins.py
```

The script overwrites `info.json` and `controller.svg` in every bundle but preserves existing
`transparent.png` files to avoid rewriting unchanged binary data.

## Adding New Cases

To add a skin for a new physical case:

1. Create a new directory: `<CaseName>-<System>.deltaskin/`
2. Copy an existing `info.json` as a template
3. Update `name`, `identifier`, `gameTypeIdentifier`
4. Adjust button `frame` coordinates to match the physical case
5. Add a `controller.svg` with your artwork (or use the generator script)
6. The existing `.copy("Resources/DefaultSkins")` in `Package.swift` already picks it up

## Calibration

To calibrate button positions on a real device:

1. Enable `"debug": true` in `info.json` to show button overlay rectangles
2. Connect the physical case
3. Load a game and observe button position overlays
4. Adjust `frame` values in `info.json` until overlays align with physical buttons
5. Set `"debug": false` when complete
6. Submit calibrated coordinates in a PR referencing issue #3252

## SVG Artwork Notes

The SVG renderer (`SVGRenderer.swift`) supports a subset of SVG:
- Elements: `<svg>`, `<g>`, `<rect>`, `<circle>`, `<ellipse>`, `<polygon>`, `<text>`
- Transforms: `translate()` only
- Colors: `#rrggbb`, `#rgb`, `rgba()`, `rgb()`, CSS named colors

## References

- DeltaSkin format: `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Models/DeltaSkin.swift`
- SVG renderer: `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Extensions/SVGRenderer.swift`
- Generator script: `Scripts/generate_default_skins.py`
- Issue: https://github.com/Provenance-Emu/Provenance/issues/3252
