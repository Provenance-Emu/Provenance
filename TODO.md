# TODO.md

<!-- AGENTS: Keep this file current. Check off items when done, add new items as discovered. -->

## Active Epics (March 2026)

- [ ] **Epic 1: Cheats** — Online lookup working; remaining: MD5 regen with --dat-dir, CloudKit sync (#2505, #2506)
- [ ] **Epic 1b: SwiftData Migration** — Models done (#2522); remaining tasks #2551-#2556
- [ ] **Epic 5: RetroAchievements** — Protocol done; session manager, OSD overlay, notifications, leaderboards remaining
- [ ] **Epic 6: Haptics/Rumble** — PVRumbleProtocol done (#2751); Tiers 2-4 pending
- [ ] **Epic 7: Screen Recording** — Basic RPScreenRecorder done; streaming, clip capture, camera overlay pending
- [ ] **Epic 8: N64 Transfer Pak** — Protocol done; Mupen bridge, slot UI, persistence pending
- [ ] **Epic 9: Per-Game Core Options** — MD5 wiring done; VM, UI, RetroArch .opt routing pending
- [ ] **Epic 10: DriverKit & USB Peripherals** (#3201) — PVUSBManager + DriverKit scaffold + StoreKit IAP done; remaining: Xcode dext target, DS3 HID report translation, GameCube adapter port mapping, Apple DriverKit entitlement approval

## Release Blockers

- [ ] Legacy UIKit Controller PVControllerViewController.swift 
      - [ ] Has top bar of buttons, needs complete rewrite
      - [ ] Touch mouse/keyboard blocks rest of touches
      - [ ] Tapping the "toggle controller buttons visible" button, the other controller buttons ignore the alpha settings and also doesn't hide joysticks (is that a setting though?)
- [ ] `RetroSaveSelectionAlertView.swift` sometimes when downloading a cloud save, it doesn't boot after download, tapping again boots though
- [ ] RetroarArch and Menu buttons showing when using thing wrapper
- [ ] tvOS test removing PVRetroArchCore from build
- [ ] Thin wrappper
      - [ ] N64 mupen video squashed
      - [ ] N64 mupen rumble no worky
      - [ ] PSX hardware renderer crashy
- [ ] GameMoreInfo crashing
- [ ] Sometimes when booting a game from ConsoleGamesView.swift and others, the game boot process starts and stops, and tapping any game again doesn't work (i think has to do with bios required, tries to download and fails even if available or not, but even bios not required games just don't react to taps anymore)
- [ ] Skin selection, when downloading a skin from skin downloader, while playing a game from the pause menu, download a new skin, set the new skin as active, skin didn't change (tested on SG-1000, which is a git different since it mapped to a SMS skin since they're compatible, perhaps it's only for skins that are cross compatible). I can go into the skin selector after download and select it though (yes, i confirmed, with snes this flow works fine since skins directly mapped 1:1, but then again, 32x using a related skin also didnt' work)



## tvOS

- [ ] New banner image that doesn't use copyrighted art
- [X] TopShelf extension working and right archs
- [X] Context Menu 'Games'
- [X] Settings UI
- [X] Pause menu fixes
- [ ] RetroArch MFi controller issues:
    - [ ] Controller 1 presses both P1 and P2
    - [ ] Controller 1 share button shows RetroArch menu (should be pause)
    - [ ] Controller 1 options (start) presses P2 start only
- [ ] Storage/space warning improvements

## Core Updates

- [ ] DS Dual-Screen skins — Phase 4+ (full dynamic layout, size controls)
- [ ] MelonDS — Colors fixed (#2557); still needs core update to latest upstream
- [ ] DesmUME2015 — Core code out of date
- [ ] Mupen64Plus — Core and GLideN64 plugin updates (large ROM hack patch may be mainline)
- [ ] DuckStation — Years out of date; evaluation needed before revival
- [ ] DosBox — Keyboard/mouse added; graphics working (#2559); native vs RetroArch dosbox-pure tradeoffs
- [ ] RETRO_ENVIRONMENT_SET_PROC_ADDRESS_CALLBACK for MelonDS dual-screen layout

## UI / UX

- [ ] Moveable buttons in pause menu (broken/weird)
- [ ] Add multi-select delete/move/favorite support in library
- [ ] Hookup PVMediaCache trimDiskCache with status info and force-trim button
- [ ] Some RetroArch cores (Quake, etc.) not showing controller UI when expected
- [ ] Move unsupported cores to general settings section

## Infrastructure

- [ ] Regenerate libretro_cheats.sqlite with --dat-dir to populate MD5 column (#2616)
- [ ] Move cheat DBs to CloudKit/iCloud to reduce app size
- [ ] Skin catalog: create provenance-skins repo, add DeltaStyles source (#2607)
- [ ] D-pad diagonal tokens audit (#2611)
- [ ] Netplay — Native Swift/SwiftUI implementation (post-research phase)
- [ ] Release automation — full pipeline: git-flow → archive → IPA → GitHub Release → AltStore feed
