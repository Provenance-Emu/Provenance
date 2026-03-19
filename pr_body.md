## Summary

- **Adds `MouseGameRegistry`** — thread-safe registry in `PVCoreBridge` that determines whether the currently loaded game should activate mouse support, using a two-tier system: always-on systems (DOS, Macintosh, AtariST…) and conditional systems where only specific titles use a mouse (SNES, Saturn, Dreamcast, PSX).
- **Fixes false-positive mouse UI** — `gameSupportsMouse` in `PVThinLibretroCore` now delegates to the registry, so SNES games like Super Mario World no longer show the mouse cursor overlay. Only known mouse titles (Mario Paint, Mario & Wario, Undead Line, etc.) activate it.
- **Game detection by MD5 and title keyword** — Mario Paint is auto-detected via its MD5 hash (multiple regional dumps covered) or title substring match. New games can be registered at runtime via `registerKnownMouseGameMD5(_:)` or `registerTitlePattern(_:forSystem:)`.
- **Per-game user override** — Players can force mouse on/off for any game via `MouseGameRegistry.shared.setUserOverride(_:forMD5:)`, stored in UserDefaults. Override wins over all automatic detection.
- **`MouseGamesProvider` protocol** — Cores can declare compile-time mouse game support; the registry calls `registerProvider(_:)` to ingest it.
- **25 unit tests** in `MouseGameRegistryTests` covering always-on systems, conditional detection, MD5 matching, title matching, user override, and dynamic registration.

## Test plan

- [x] `MouseGameRegistryTests` — 25 tests covering all detection paths
- [x] `swiftlint lint` passes on changed Swift files
- [ ] Launch SNES core with Mario Paint — mouse overlay should appear automatically
- [ ] Launch SNES core with Super Mario World — mouse overlay should NOT appear
- [ ] Launch DOS core with any game — mouse overlay should appear (always-on system)
- [ ] Override: call `setUserOverride(true, forMD5:)` for an unknown SNES game — overlay appears
- [ ] Override: call `setUserOverride(false, forMD5:)` for Mario Paint — overlay suppressed

## How to extend the game database

```swift
// Add a new mouse-supporting game by MD5
MouseGameRegistry.shared.registerKnownMouseGameMD5("your_md5_here")

// Add by title keyword (case-insensitive substring match)
MouseGameRegistry.shared.registerTitlePattern("game title", forSystem: .SNES)

// Per-game user override (force on/off)
MouseGameRegistry.shared.setUserOverride(true, forMD5: "rom_md5")
MouseGameRegistry.shared.setUserOverride(nil, forMD5: "rom_md5") // clear override
```

Part of #3331

🤖 Generated with [Claude Code](https://claude.com/claude-code)
