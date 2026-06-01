# TODO.md

ACTIVELU WORKING ON BY JOE

- [X] deafult skins / skins hide option when using external controller (like the uikit controller had) (#65ad1604cb)
- [X] Thin wrapper, console toggles (like atari's bw/color toggles) — TV TYPE Color/BW toggle fixed (#3347c96647), full system already wired
- [X] Jaguar thin wrapper with skins make sure number pad works (#13aec6b8cb, prior session)
- [X] Jaguar native PVJaguar update to latest libretro/virtualjaguar-libretro develop branch (done by Joe)
- [X] Thin wrapper, works with Saturn — BIOS sync added (#c6fea87ddd), BOOTS now w/ beetle+yabause. Backup RAM "system memory not ready" FIXED (#55ae973743). Region now user-selectable via Settings > Video > System Region (beetle_saturn_region).
- [~] thin wrapper works with PPSSPP — SHIPPING THIN (Vulkan). No longer force-routed to thick (#2f09fd7802 reverted that). PSP is thin-by-default; ~10 thin-Vulkan fixes landed (#592faadf59 instance exts → #7718853649 Metal VkSurfaceKHR → #7388f57eca defer context_reset → #efc4ddb119 apiVersion bump; GLES-own-thread #6414412e15). Vulkan boot walls cleared in-simulator; NEEDS device test to confirm it boots+renders detached (vm_remap fastmem fails under debugger only). Keep iterating — want PSP on thin Vulkan (or whatever's best for PPSSPP) for release.
- [X] thin wrapper works with m3y's multi disc etc — disc swap tile added (#7096b76e4f, prior session)
- [ ] "Select controller skin" previews missing for skins for sone reason — code looks correct, needs runtime debugging. DEFERRED post-release (cosmetic; picker still functional, just no thumbnail).
- [X] thin wrapper *and in theory all other cores* live change their stretch / scale setting during emulation (#17ccb0b349)
- [~] backgrounding / foregrounding STILL deadlocks — Metal drawable fix (#3abe31a1e7) was insufficient. NEW symptom: emulator video+audio keep running (render thread fine), but MAIN thread locks — rotation never relayouts, SwiftUI/UIKit frozen. Something on main thread blocks on resume. UPDATE (May 31): a large batch of Metal/freeze fixes landed since (#774b93077c pause render loop on willResignActive, #1ff0bbff31 self-heal wedged drawable pool, #d59f7b65d5 remove waitUntilCompleted-on-main, #97aea7b8a2 gate first post-resume frame off sync CA-commit, #bdd24bdc22 nextDrawable timeout + pool reset, #ecab000a47 stop toggling isPaused, #48ebea5bc3 / #1de102cb0d pause core before view-state guard). May already be fixed/much-improved — TOP priority to confirm on device (play → background → return → rotate).
- [X] if a core crashes and we show a toaster message, the toaster floats to the top of the main library UI since we close the emulation scene, so the user can't read the error message (#21776f9389)
- [X] Thin wrapper n64 mupen-next has inverted joystick in skins (and maybe other controllers?) — affects ALL analog cores, fixed (#f164848638)
- [ ] PCE/TurboGrafx-16 RUN button doesn't work in thin wrapper with beetle_pce / beetle_pce_fast cores (works with supergrafx core in PCE mode). NOTE (May 31): upstream source for ALL three cores (beetle-pce, beetle-pce-fast, beetle-supergrafx) maps RUN → `RETRO_DEVICE_ID_JOYPAD_START` (id 3) via identical `map[]` arrays — which is exactly what the thin wrapper already sends (`pceMap: .run → .start`). So our mapping is NOT wrong; supergrafx working with the same mapping points to a stale/divergent beetle_pce buildbot dylib or a pad-mode default. Do NOT blindly remap (would break supergrafx). Resolve with a runtime trace: press RUN and read the existing `ThinFrontend: input_state BITMASK` log (PVThinLibretroFrontend.mm:4406) — if it shows bit 3 set (0x0008) the wrapper is correct and the dylib is at fault.
- [X] N64 GoldenEye rumble in thin wrapper — FIXED: set thin pak1="rumble" to match thick. In the RetroArch buildbot dylib (run by BOTH wrappers) pak1="rumble"/PLUGIN_RAW is the raw-intercept HYBRID mode (marshals both memory-pak saves AND rumble). The submodule source has this path stubbed (RawData=0) — wrong source to read; the dylib has it live.
- [X] Region not set correctly for thin wrapper systems — added global "System Region" setting (Settings > Video; Auto/Japan/N.America/Europe). Thin wrapper force-applies it to beetle_saturn_region (key+values verified vs libretro/beetle-saturn-libretro source). yabasanshiro has NO region option (internal/NTSC-fixed), so it's unaffected. Extensible to other region-aware cores.
- [X] on demand download for games etc shouldn't time-out if the download is making progress — iCloud Drive path now uses inactivity/stall timeout (#8de51631f3). NOTE: CloudKit on-demand path already used correct CKOperation defaults; if timeouts persist confirm which iCloudSyncMode.
- [X] 2 flycast boots in a row crashes — FIXED by Joe. Upstream bug was `#ifdef __APPLE__` in flycast `retro_deinit` skipping `emu.term()` (stale pointers crashed on 2nd boot); fork fixed + dylib rebuilt.
- [X] if the on screen keyboard is active, and minimized, we still can't tap buttons behind it... + draggable — FIXED (#88a8b939da): hitTest now gated to visible sheet frame (touches pass through elsewhere); handle bar drags keyboard vertically.
- [ ] *bonus* thin wrapper touch mouse almost working, tested mario paint, but how do we use the controller? slot 1 becomes the mouse, not sure if tapping to click or right click is working, but i can't get past menu since i can't press controller which i guess the skin should be able to be assigned to player 2 instead (maybe we always need a quick way to change the skins/osd's player index, since some games on old consoles have features you need to press buttons on p2 port even in 1 player games)
- [ ] *bonus* Wold3D loading, almost kind of works. the text in the library says we can auto download the files, but that's only with fat wrapper, we'd need to add that for thin wrapper somehow into the ui or remove that text or give better instructions, also it's ambigous where and what files go, maybe we shoudl add to wiki as well (would need a wiki page if not already) or a pop out larger blurb?


### Recently fixed (May 29–31, on develop, pending device verification)
- [X] Tile pause-menu fast-forward reset on menu close (#ac36b8bfb0) — DeltaSkin reconnect no longer clobbers a deliberate speed change.
- [X] Odyssey2 (o2em) thin wrapper: no input — key0 was mapped to JOYPAD_SELECT which toggles o2em's virtual keyboard and gates the whole pad; now digits dispatch as RETROK_0..9 (+ secondary joypad 0–6), SELECT never mapped (#09d0b7e164).
- [X] Thin-wrapper audio at wrong sample rate (bassy/glitchy) — thin defers retro_load_game to startEmulation, so the audio graph was built at the 44100 fallback before the core's real rate was known; now rebuilds after start if the rate changed (#cb40fef061). Thin-wrapper-wide fix (o2em 42240/35200 Hz was worst case).
- [X] Promote internal PVFeatureFlags to Advanced toggles (tapToRemapUI, companionController, lightGunCrosshair, skinButtonReposition, airPlayMenu) — off-by-default user settings, "PLUS"-gated via FreemiumKit `PremiumThemedToggle`. Gating is REAL (locked branch `.disabled(true)`s the toggle): free on sideload/dev (ProvenanceApp.swift:95-103 overrides `purchasedTier` when `!isAppStore`), Plus-locked on the App Store. Keyed on StoreKit IAP, not Patreon.

<!-- AGENTS: Keep this file current. Check off items when done, add new items as discovered. -->

## tvOS Tester Sprint Checklist (May 8-9 2026)

Bundles 7 commits on `develop` from `477a7a48f2..093ac7c787`. 4 fixes + 3 diagnostic-logging spikes. Tester to run a single Console.app session capturing all three log filters in one pass.

### Fixes — visual / behavioural verification (no logs)

- [ ] **Aspect ratio** (`477a7a48f2`): RA-wrapped cores no longer clamped to 4:3. Check Dolphin GameCube widescreen, BeetlePSX, FBNeo, and any other libretro core that reports a non-4:3 `geometry.aspect_ratio`. Was: pillarboxed to 4:3. Should now: fill correctly.
- [ ] **MAME CHD** (`8e6fb559b0`): Import a MAME CHD (`.chd`) ROM. Was: rejected at import (extension not in allow-list) or rejected at launch by the RA wrapper. Should now: import succeeds, game launches.
- [ ] **MAME 7z** (`8e6fb559b0`): also added `.7z`. Verify a 7z-packed MAME set imports.
- [ ] **PPSSPP renderer** (`524966ff72`): Native PPSSPP core on tvOS 26+ no longer attempts MoltenVK Vulkan and crashes / black-screens. Should auto-pick OpenGL regardless of the saved Vulkan setting. Look for log line `PPSSPP: iOS/tvOS 26+ — overriding Vulkan setting with OpenGL to avoid MoltenVK boot failure`.
- [X] **tvOS set-default-core hint** (`370b8e92b1`): Open the core picker on tvOS for a multi-core system. Each card should show a small `★ Hold to set default` label in the lower-left of the card body. Long-pressing the card still triggers `Set as Default for This System` from the contextMenu.

### Diagnostic-logging spikes — capture Console.app logs

Run all three in one session. Filter on each prefix in turn or use `CHEEVOS-DIAG OR CTRL-DIAG OR PPSSPP-DIAG` if your Console.app supports it.

- [ ] **CHEEVOS-DIAG** (`73241135cd`): Boot SNES9x + F-Zero, race Mute City on Standard difficulty. Boot Stella + Pac-Man (Atari 2600), get to 500 points. Capture full log.
  - Looking for: did `prepareAchievements` even run? Did MD5 / hash match? Did `tickAchievements` fire per frame? Did the unlock callback ever fire?
- [ ] **CTRL-DIAG** (`765a35a2c3`): Boot Mednafen Saturn (any game). Press each shoulder + trigger ONE AT A TIME (left, right, L1, R1, L2, R2). Boot PicoDrive 32X. Repeat the same one-at-a-time test.
  - Looking for: which gamepad button fires which `controllerValueForButtonID:` case. The one-shot log dumps the gamepad class + `use8BitdoM30` flag at first frame. Heartbeat every 600 polls shows the live state of all four shoulders + buttonMenu/buttonOptions presence.
- [ ] **PPSSPP-DIAG** (`093ac7c787`): Boot a PSP game with the **RetroArch core** (NOT native PPSSPP). Capture Console.app session. If the app crashes on boot, also grab `/var/mobile/Library/Logs/CrashReporter/*.ips` for the device.
  - Looking for: how far does the boot sequence get before the crash? Last `PPSSPP-DIAG` line tells us where it died. If we see `synchronizeOptionsWithRetroArch EXIT normal completion` and `loadFileAtPath ENTER` but never `retro_load_game returned`, the crash is inside PPSSPP's libretro core (probably MemoryMap_Setup with vm_remap).

### Known pre-existing CI issue (not from this sprint)
- tvOS CI build fails on `GetModule: FAILED to download parallel_n64_libretro_tvos.dylib.zip` (HTTP 404). Buildbot dylib infra issue. iOS CI passes. Local tvOS builds work — this is a remote-download regression upstream of our changes.

### Deferred (not in this sprint)
- NES turbo / clockwise rotation working only on Nestopia — feature-gap, not bug. Separate epic.
- DS portrait window on tvOS — explicitly deferred per maintainer.
- Per-core widescreen hacks (`flycast_widescreen_hack`, `beetle_psx_widescreen_hack`, `dolphin_aspect_ratio`) — separate epic once the basic aspect_ratio fix is verified.

---

## Release Testing Checklist (May 2026)

### Build & Install
- [ ] Clean build succeeds (Provenance-Lite, iOS)
- [ ] Clean build succeeds (Provenance-Lite, tvOS)
- [ ] No `get-modules.sh` or `make_frameworks_retroarch.sh` errors in build log
- [ ] VirtualJaguar dylib preserved (not overwritten by buildbot) after clean build
- [ ] App installs and launches on iOS device
- [ ] App installs and launches on tvOS device (Apple TV)

### Library & Import
- [ ] Import a ROM via Files app / share sheet
- [ ] Import a multi-disc game (M3U + CUE/BIN) — no crash
- [ ] ROM appears in library with correct artwork
- [ ] Delete a game from library
- [ ] iCloud sync: ROM appears on second device after sync
- [ ] Cloud save download works — tapping save boots the game

### Core Launch & Video
- [ ] NES game launches (Nestopia or FCEUmm via thin wrapper)
- [ ] SNES game launches (Snes9x via thin wrapper)
- [ ] N64 game launches (Mupen64Plus) — video not squashed
- [ ] PSX game launches (Beetle PSX HW) — no crash on hardware renderer
- [ ] DS game launches (MelonDS) — both screens visible, correct aspect
- [ ] Saturn game launches (Mednafen) — draws correctly, not 4:3 clamped
- [ ] Saturn game launches (Yabause) — all buttons work including Start
- [ ] Jaguar game launches (VirtualJaguar via thin wrapper)
- [ ] MAME game launches — verify coin button works separately from select
- [ ] 3DO game launches

### Jaguar Numpad (new — verify today's fix)
- [ ] Numpad 0-6 work in-game (e.g. Battle Sphere)
- [ ] Numpad 7-9 work in-game (e.g. AvP map = numpad 8)
- [ ] Numpad * and # work in-game
- [ ] D-pad and A/B/C face buttons work
- [ ] Pause and Option buttons work
- [ ] Numpad works with `numpad_to_kb = "numbers"` (default)
- [ ] Numpad 0-6 still work if user sets `numpad_to_kb = "disabled"`

### Aspect Ratio / Scaling (B3 regression check)
- [ ] RA-wrapped core (any) fills screen correctly, not stuck in 4:3 box
- [ ] DS portrait mode shows both screens, not clipped
- [ ] Beetle Saturn draws (was no-draw before B3 fix)
- [ ] Native cores (non-RA) still display at correct aspect
- [ ] iPad landscape and iPhone portrait both letterbox correctly

### Controls & Input
- [ ] On-screen touch controls respond on iOS
- [ ] MFi controller works (pair, all buttons respond)
- [ ] MFi controller doesn't double-fire P1+P2 on tvOS
- [ ] Controller share button → pause menu (not RA menu) on tvOS
- [ ] Keyboard input works for cores that support it (DOS, Apple II)
- [ ] Skin selection: download new skin from pause menu, set active, verify it changes
- [ ] "Choose Core..." context menu only shows for multi-core systems

### RetroAchievements
- [ ] Login via Settings → RetroAchievements (toast confirms success)
- [ ] Launch a cheevos-supported game — achievements load
- [ ] Earn an achievement — toast + unlock SFX plays
- [ ] Logout — toast confirms logout
- [ ] Cheevos hash identifies game correctly (MD5 fast path)

### Pause Menu & UI
- [ ] Pause menu opens on iOS (skin pause button or controller)
- [ ] Pause menu opens on tvOS (Menu button)
- [ ] Save state from pause menu
- [ ] Load state from pause menu
- [ ] Screenshot from pause menu
- [ ] "RetroArch Menu" / "RetroArch Settings" tiles NOT visible for thin wrapper cores
- [ ] tvOS pause tile focus: navigating tiles doesn't jump unexpectedly
- [ ] Timed auto-saves OFF by default (check Settings)

### Skins
- [ ] Default skin loads for each supported system
- [ ] Custom skin can be selected per-game
- [ ] Skin buttons all respond (verify a system with many buttons like Jaguar or Saturn)
- [ ] Cross-compatible skins (e.g. SG-1000 → SMS) apply correctly from download

### Stability
- [ ] Play a game for 5+ minutes without crash
- [ ] Background app and return — game resumes
- [ ] Auto-save fires on app background (check Settings → auto-save = ON)
- [ ] No BIOS-required game: shows toast with hint, doesn't hang
- [ ] Memory pressure: launch a large ROM, no OOM crash

### tvOS Specific
- [ ] Siri Remote navigation through library
- [ ] Siri Remote game selection and launch
- [ ] Focus engine works in settings screens
- [ ] Top Shelf extension shows recent games
- [ ] Storage warning displays when space is low

---

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
- [X] `RetroSaveSelectionAlertView.swift` sometimes when downloading a cloud save, it doesn't boot after download, tapping again boots though (#334b463ec8)
- [ ] RetroArch and Menu buttons showing when using thin wrapper — mostly guarded already; never runtime-reproduced. Verify on device, likely no-op.
- [X] tvOS test removing PVRetroArchCore from build — DONE. ProvenanceTV / ProvenanceTV-Lite schemes have 0 PVRetroArch refs; `PVCoreFactory` forces thin whenever the thick class is absent (so tvOS can't load thick even if the setting is on). This also moots the 3 tvOS RetroArch MFi controller bugs below (they were thick-RA-only).
- [ ] Thin wrapper (tvOS only needed for release)
      - [X] N64 mupen video squashed
      - [X] N64 mupen rumble no worky --
            - [ ] Seems to work on iPhone haptics, need to test controller
      - [X] PSX hardware renderer crashy — force OpenGL HW renderer in thin wrapper (develop)
      - [X] Hijacking RA cores when feature flag is off (#64df8f0c72)
      - [X] Per-frame rcheevos tick + unlock callback (#d337ba7f0b)
      - [X] RA frame loop off main thread to prevent UI freezes (#32375eebb0, #9fd1243bd9, #58544c89ff)
- [X] GameMoreInfo crashing
- [X] Sometimes when booting a game from ConsoleGamesView.swift and others, the game boot process starts and stops, and tapping any game again doesn't work (i think has to do with bios required, tries to download and fails even if available or not, but even bios not required games just don't react to taps anymore)
- [X] Skin selection, when downloading a skin from skin downloader, while playing a game from the pause menu, download a new skin, set the new skin as active, skin didn't change (tested on SG-1000, which is a git different since it mapped to a SMS skin since they're compatible, perhaps it's only for skins that are cross compatible). I can go into the skin selector after download and select it though (yes, i confirmed, with snes this flow works fine since skins directly mapped 1:1, but then again, 32x using a related skin also didnt' work)
- [X] tvOS Pause tile menu focus sucks, like when going to the skins button, it jumps to the top and other buttons too, the focus needs to be greatly simplified (#ca23b8b9db)
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
- [X] VirtualJaguar numpad dual-path input + core option defaults (#745e7d2261)
- [X] Build scripts: local core support in cores.yml + sh-compat fix (#b7175f3ab5)


## tvOS

- [ ] New banner image that doesn't use copyrighted art
- [X] TopShelf extension working and right archs
- [X] Context Menu 'Games'
- [X] Settings UI
- [X] Pause menu fixes
- [X] RetroArch MFi controller issues — MOOT on tvOS: thick PVRetroArchCore is no longer in the tvOS build (see Release Blockers), so these thick-RA-only bugs can't occur. Re-open only if reproduced on the thin wrapper.
    - [X] Controller 1 presses both P1 and P2 (thick-RA only)
    - [X] Controller 1 share button shows RetroArch menu (thick-RA only)
    - [X] Controller 1 options (start) presses P2 start only (thick-RA only)
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
