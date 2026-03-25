# Default DeltaSkin Bundles for Third-Party Physical Button Cases

This directory contains DeltaSkin bundles for known third-party physical button cases and controllers.
These skins are bundled with Provenance and loaded automatically via `DeltaSkinManager`.

## Purpose

When a compatible physical controller case is detected, Provenance can auto-load the appropriate skin
to optimise the game screen layout. Since physical buttons handle all input, these skins:

1. Maximise the game screen area (no on-screen button overlay needed)
2. Define approximate button positions for visual overlays and input mapping reference
3. Support both standard and edge-to-edge iPhone display types (iPhone 14/15/16)

## Coordinate System

All button and screen coordinates are in the skin's **mapping coordinate space** (not 0–1 normalised).
The `mappingSize` defines the coordinate grid:
- **Standard portrait**: `750 × 1334` (logical pixels, equivalent to iPhone 6/7/8 resolution)
- **Edge-to-edge portrait**: `393 × 852` (logical points for iPhone 14/15/16)

Button `frame` values represent approximate physical positions estimated from product photographs
and typical MFi controller ergonomics. **All coordinates require real-device calibration.**

## Included Skins

### GameSir Pocket Taco (`PocketTaco-*.deltaskin`)

The GameSir Pocket Taco is a clip-on physical MFi Bluetooth controller for iPhone.
The phone sits in the top portion of the controller; physical buttons are on the grip body below.

- **Form factor**: Grip controller with phone clipped into top
- **Connectivity**: Bluetooth MFi
- **Systems covered**: NES, SNES, GBA, Genesis (Mega Drive)
- **Calibration status**: ⚠️ NEEDS CALIBRATION — coordinates estimated from product photos

Button layout reference (portrait, 750×1334 mapping):
- Shoulder L/R: top edge, y ≈ 0–80
- D-pad: lower-left area, x ≈ 40–260, y ≈ 970–1190
- Action buttons: lower-right area, x ≈ 460–735, y ≈ 960–1235
- Start/Select: center-bottom, y ≈ 1210

### Soolra Controller (`Soolra-*.deltaskin`)

The Soolra is a full MFi layout physical controller for iPhone with buttons on both sides.

- **Form factor**: Grip controller with integrated iPhone mount
- **Connectivity**: Bluetooth MFi
- **Systems covered**: NES, SNES, GBA
- **Calibration status**: ⚠️ NEEDS CALIBRATION — coordinates estimated from product photos

## Adding New Cases

To add a skin for a new physical case:

1. Create a new directory: `<CaseName>-<System>.deltaskin/`
2. Copy an existing `info.json` as a template
3. Update the `name`, `identifier`, `gameTypeIdentifier`
4. Adjust button frame coordinates to match the physical case
5. Include a `transparent.png` (1×1 pixel placeholder — replace with actual skin artwork if available)
6. Add `.copy("Resources/DefaultSkins")` entry remains in `Package.swift` (already present)

## Calibration

To calibrate button positions on a real device:

1. Enable `"debug": true` in `info.json` to show button overlay rectangles
2. Connect the physical case
3. Load a game and observe button position overlays
4. Adjust `frame` values in `info.json` until overlays align with physical buttons
5. Set `"debug": false` when complete
6. Submit calibrated coordinates in a PR referencing issue #3252

## File Format

Each `.deltaskin` bundle contains:
- `info.json` — skin metadata and button/screen mappings
- `transparent.png` — 1×1 transparent PNG placeholder (no visual overlay)

For skins with actual artwork, replace `transparent.png` with a proper background image
(PDF recommended for resolution independence, PNG accepted).

## References

- DeltaSkin format: `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Models/DeltaSkin.swift`
- Issue: https://github.com/Provenance-Emu/Provenance/issues/3252
- Related: Physical case detection (#3249), DeltaSkin editor (#3253)
