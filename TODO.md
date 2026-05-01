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
- [ ] RetroArch and Menu buttons showing when using thin wrapper
- [ ] tvOS test removing PVRetroArchCore from build
- [ ] Thin wrapper (tvOS only needed for release)
      - [X] N64 mupen video squashed
      - [X] N64 mupen rumble no worky --
            - [ ] Seems to work on iPhone haptics, need to test controller
      - [ ] PSX hardware renderer crashy
      - [X] Hijacking RA cores when feature flag is off (#64df8f0c72)
      - [X] Per-frame rcheevos tick + unlock callback (#d337ba7f0b)
      - [X] RA frame loop off main thread to prevent UI freezes (#32375eebb0, #9fd1243bd9, #58544c89ff)
- [X] GameMoreInfo crashing
- [X] Sometimes when booting a game from ConsoleGamesView.swift and others, the game boot process starts and stops, and tapping any game again doesn't work (i think has to do with bios required, tries to download and fails even if available or not, but even bios not required games just don't react to taps anymore)
- [X] Skin selection, when downloading a skin from skin downloader, while playing a game from the pause menu, download a new skin, set the new skin as active, skin didn't change (tested on SG-1000, which is a git different since it mapped to a SMS skin since they're compatible, perhaps it's only for skins that are cross compatible). I can go into the skin selector after download and select it though (yes, i confirmed, with snes this flow works fine since skins directly mapped 1:1, but then again, 32x using a related skin also didnt' work)
- [ ] tvOS Pause tile menu focus sucks, like when going to the skins button, it jumps to the top and other buttons too, the focus needs to be greatly simplified
- [X] M3U import crash — force-unwrap of `expectedAssociatedFileNames!` and unsafe `as! [URL]` cast in M3U/CUE import path (#7dcd58bd53)
- [X] Audio crash — guard nil gameCore in startAudio (#7ec47ccdd5)
- [X] Status messages — summarize batch game-import toasts (#a9232cbcbf)
- [X] Pause tiles — Lynx/Jaguar named-parameter selectors (#e0bdc3b412)
- [X] Stella video_callback heap overrun + 32x analog cross-axis bleed (#a1f06094eb)
- [X] tvOS Apr 27 wave 1 — saturn buttons, autosave, core picker label (#620f204d15)
- [X] tvOS Apr 27 wave 2 — yabause inputs, mame coin, RA aspect clamp (#5590c446ef)
- [X] Port-device picker tvOS readability + suppress default focus glow (#e6900705df)
- [X] Supervision pause tile uses .enter/.clear (#4627d402e9)
- [X] Dynamic Start/Select tiles for controllers without those buttons (#18af0b359e)
- [X] Cheevos hash MD5-first with rcheevos auto-detect fallback (#c6bfe4f5f8)
- [X] Toast + dismiss when core fails to load (missing BIOS) (#3c4dd0911b)
- [X] RetroAchievements toast feedback on login/logout + unlock SFX (#fe8640a991)
- [X] Skip MD5 hashing when extension uniquely identifies system (#852d527355)


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
