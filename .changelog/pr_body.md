## Summary

- **`ControllerLayoutVariant` model** in `PVCoreBridge` — defines named layout variants (id, displayName, sfSymbol) with built-in constants for Genesis, Wii, Atari 5200, and NES
- **`ConsoleVariantConfigurable` protocol** — opt-in protocol for emulator cores to receive variant-change callbacks when the user switches layouts
- **Per-system persistence** in `PVSettings` — `Defaults.Keys.controllerLayoutVariantsBySystem` stores the selection keyed by `SystemIdentifier.rawValue`; helper methods on `Defaults` for read/write
- **`ControllerLayoutVariantPicker` SwiftUI view** — retrowave-styled inline picker shown in Settings → Systems for any system that has multiple layouts
- **Unit tests** — `ControllerLayoutVariantTests` covers unique IDs, system mapping, default variant, and Hashable/Equatable conformance

### Built-in Variants

| System | Variants |
|--------|---------|
| Sega Genesis | 3-Button Pad *(default)*, 6-Button Pad |
| Wii | Wiimote *(default)*, Wiimote + Nunchuck, Classic Controller, Classic Controller Pro |
| Atari 5200 | Joystick + Keypad *(default)*, Joystick Only |
| NES | Standard *(default)*, Zapper |

### Architecture

The feature follows the existing `HardwareSwitchProvider` / `PortDeviceConfigurable` patterns — variant definitions live in `PVCoreBridge`, storage in `PVSettings`, and UI in `PVUI`. Cores opt in to variant switching by implementing `ConsoleVariantConfigurable`. The Settings UI only shows the picker for systems that have `availableControllerLayoutVariants`.

## Test plan

- [ ] Build `Provenance-Lite` scheme on iOS Simulator — no new compiler errors
- [ ] Open Settings → Systems — verify Genesis, Wii, Atari 5200, NES each show a "CONTROLLER LAYOUT" section
- [ ] Select a variant (e.g. Genesis 6-Button Pad) — verify checkmark appears and selection persists after app restart
- [ ] Systems without variants (SNES, GBA, PSX…) — verify picker is not shown
- [ ] tvOS: focus nav through picker rows works with Siri Remote
- [ ] Run `swift test` in `PVCoreBridge` — `ControllerLayoutVariantTests` all pass (requires macOS with Xcode)

Part of #2892
Part of #2889

🤖 Generated with [Claude Code](https://claude.com/claude-code)
