# Release QA — Provenance 3.4 (tvOS primary target)

## How to use this file
- Test each item, mark `[x]` when passing, `[!]` when broken
- Add bug notes inline: `[!] crashes on launch — <details>`
- I (Claude) read this at session start and fix P0s first

---

## P0 — Must pass before submission

### Boot & Launch
- [ ] App launches without hang on tvOS (cold boot)
- [ ] App launches without hang on iOS (cold boot)
- [ ] Progress screen shows during boot (not blank)
- [ ] Game library populates after boot (no permanent empty state)

### Core emulation (pick 2-3 representative cores per platform)
- [ ] ROM loads and runs (N64 / SNES / PSX — use RetroArch cores)
- [ ] Pause works (tap menu button on tvOS remote)
- [ ] Resume works after pause
- [ ] Save state saves without crash
- [ ] Save state loads correctly
- [ ] Quit back to library works cleanly

### Pause menu
- [ ] Pause menu opens correctly on tvOS
- [ ] Save State tab works
- [ ] Core tab doesn't lock up
- [ ] Can resume from pause menu
- [ ] Screenshot save works

### tvOS-specific
- [ ] Game controller (MFi / Apple TV remote) input works
- [ ] Focus engine navigates library correctly
- [ ] No UI elements that require touch (tvOS has no touchscreen)

---

## P1 — Fix before release if reproducible

### Save States
- [ ] Save state browser shows states grouped by game
- [ ] Version mismatch warning appears at most once per load
- [ ] Version string shows correctly (not "2024.10.29" date format)
- [ ] Autosave on exit works

### Siri / Spotlight (iOS)
- [ ] Games appear in Spotlight search
- [ ] "Search in Provenance" opens app and passes query to search
- [ ] Save states have thumbnails in Spotlight

### Cheats
- [ ] Cheat sheet opens from pause menu (no crash)
- [ ] Adding a cheat doesn't crash
- [ ] Cheats persist across sessions

### Settings / UI
- [ ] Settings > Controller tab shows Skin Browser
- [ ] Systems list uses navigation title (not hidden nav bar)
- [ ] Home search results are scrollable (not cut off)

---

## P2 — Defer to 3.4.1 if not blocking

### New features (agent work — needs real-world validation)
- [ ] Skins: per-button haptic feedback
- [ ] Skins: animated backgrounds
- [ ] Skins: multi-theme variants
- [ ] Skins: keyboard overlay rendering
- [ ] JIT onboarding screen (iOS only)
- [ ] JIT status indicator in HUD
- [ ] Controller player-slot auto-assign on connect
- [ ] Deadzone coordination (per-core + universal)
- [ ] CloudKit cheat sync
- [ ] Thin libretro dynamic core scanner (feature-flagged off by default)

### Cores with recent changes
- [ ] Mupen64Plus: pause, rumble pak, boot hang fixed
- [ ] VecX: hardware rendering (no blank screen)
- [ ] Hatari: TOS boots correctly
- [ ] Doom/PrBoom: fire button = shoot, L/R strafe
- [ ] FBNeo/MAME: save state no longer crashes

---

## Known issues (pre-existing or discovered during QA)

_Add findings here as you test:_

<!-- Example:
- [!] tvOS: pause menu Core tab scrolls but selection lost — [date]
-->

---

## Release checklist (final)
- [ ] Plist fix confirmed in build
- [ ] App Store screenshots updated (manual)
- [ ] Version number bumped
- [ ] Build submitted via Xcode / fastlane
- [ ] TestFlight smoke test on actual Apple TV hardware
