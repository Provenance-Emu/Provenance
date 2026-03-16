# Provenance 3.4.0 Release Notes

## New Features

### Skins
- **Per-button haptic patterns** — Skin buttons in `info.json` can declare a `haptic` block with `style` (light/medium/heavy/soft/rigid) and `intensity` (0.0-1.0); falls back to the default feedback generator when absent (#3138, #3154)
- **Animated skin backgrounds** — Orientation representations can declare a `backgroundAnimation` block (type: frames/apng/gif, frames, fps, loops); rendered beneath the game screen and pauses when backgrounded (#3139, #3154)
- **Keyboard overlay rendering** — Skins that declare a `keyboardOverlay` config display a toggleable virtual keyboard during gameplay; supports QWERTY, compact, C64, ZX Spectrum, Amstrad CPC, and Atari ST layouts (#3142, #3154)
- **PDF size-aware skin rendering** — PDFs now rasterise at the correct logical size x screen scale for crisp HiDPI output instead of an uncapped 4096 px default (#3137, #3148)
- **Animated button sprites** — Skin buttons can declare a `states` block (Manic EMU format) with normal, pressed, and optional animated image references (#3137, #3148)
- **Multi-theme skin variants** — Skins can declare named theme variants; users can select a per-skin theme persisted in UserDefaults (#3145)
- **Skin validator** — ZIP-based pre-import validation with a results sheet showing severity-categorised findings and fix suggestions (#3145)
- **Data-driven native resolution registry** — Replaced hardcoded Swift enum with a JSON-backed registry so new system resolutions can be added without source changes (#3153)
- **Per-screen native resolution overrides** — Optional `nativeResolution` field in skin `info.json` screens allows per-screen aspect ratio overrides (#3153)
- **Skin catalog display name cleanup** — System badges and filter chips now show proper names like "Game Gear" instead of raw codes (#3100)

### JIT Improvements
- **JIT Capability Matrix** — Each core declares its JIT requirement via `Core.plist`; `CoreLoader` populates a thread-safe registry at startup with no hardcoded identifier list (#3104)
- **Extended JIT Detection** — Detects StikDebug, TrollStore, iOS 26 native JIT, jailbreak daemons, and Simulator as JIT sources (#3113)
- **JIT status indicator** — In-game HUD pill shows active JIT source (e.g. "JIT - AltStore"); tap for compact status alert with differentiated messaging per core (#3103, #3156)
- **JIT onboarding** — "How to Enable JIT" guide accessible from the status indicator when JIT is inactive (#3103, #3159)
- **Azahar / emuThreeDS automatic fallback** — Both cores reclassified to `.automaticWithFallback`; they auto-detect JIT and fall back to interpreter mode so launch is always safe (#3131)

### Controller Input
- **Controller player-slot preferences** — Three assignment modes per controller: auto, preferred, and always; preferences persist and reapply on reconnect (#2773, #3111)
- **Core deadzone coordination** — New `CoreDeadzoneCapable` protocol with universal deadzone setting (0-50%), per-core coordination modes, and compatibility catalog (#2828)
- **Smart Pak (Memory + Rumble)** — Virtual combo pak mode for Mupen64Plus that handles both persistent memory-pak saves and rumble simultaneously (#3110)

### OSD and Notifications
- **PVToast in-game overlay** — Queue-based toast notification system with retrowave aesthetics, auto-dismiss, persistent toasts, and VoiceOver support (#2802, #3112)
- **Core OSD bridging** — PPSSPP, Dolphin, Azahar, Mednafen, DuckStation, Mupen64Plus, melonDS, and VisualBoyAdvance-M OSD messages now surface as native PVToast notifications (#2805, #3151)
- **RetroArch msg_queue bridge** — RetroArch `msg_queue` OSD messages forwarded to PVToast for all 60+ RetroArch-based cores (#3157)
- **Audio mute warning** — Toast notification when device audio is muted or volume is zero (#3168)

### Spotlight and Siri
- **Per-game Spotlight indexing** — Games are indexed immediately on import and re-indexed when metadata or artwork updates, using proper registered Provenance UTIs (#2980, #3160)
- **Siri Suggestions** — `NSUserActivity.isEligibleForPrediction` enables proactive game suggestions in Siri (#2980)

### Save States
- **Save state browser** — Full-page "Save States" tab grouped by game with expand/collapse, screenshot thumbnails, core version info, and sorting (#2790)
- **Save state version tracking** — Save states record the core version and identifier used to create them; version mismatch detection prompts before loading (#2952, #3081)
- **Per-game stacked autosaves** — Autosaves are visually grouped behind a single card with "+N" badge and filmstrip timeline on long-press (#2789)
- **Recent Saves deduplication** — Shows at most one autosave per game by default; "Show All Auto-Saves" toggle in Settings for power users (#2789, #3107)

### Other Features
- **Inline core picker with save counts** — Thin wrapper swap in PVCoreFactory with inline core picker showing save state counts per core
- **Cheat code auto-lookup** — Bundled cheat database with online lookup from GameHacking.org and GeckoCodes for GC/Wii (#2455, #3073)
- **Cheat code validator** — Per-format validation with hints for GameShark, Action Replay, and other formats (#2488)
- **DuckStation cheat support** — GameShark cheat codes now work in DuckStation (#2485)
- **mGBA cheat support** — Cheat codes wired up for the mGBA core (#2484)
- **Thin libretro frontend** — RetroArch-free libretro frontend using only `libretro.h`; foundation for running libretro buildbot dylibs without the full RetroArch binary (#3080)
- **Netplay build flag** — `HAVE_NETPLAY` enabled in RetroArch build for 60+ cores (#3091)
- **BPS/UPS patcher tests** — Comprehensive unit test coverage for ROM patching (#2898, #3106)
- **Configurable CRT shader parameters** — User-adjustable CRT shader settings (#2451)

## Bug Fixes

- **Save state crashes** — Fixed FBNeo, MAME, and other RetroArch core save state crashes (#1d33338)
- **Cheats crash** — Fixed Realm thread-safety crashes in pause menu cheats and save states views (#3162)
- **Cheats crash on toggle** — Fixed crash when toggling cheats from the pause menu (#0afafa4)
- **Skin button transparency** — GameGear and legacy handheld skin screen fill now uses correct aspect ratios instead of leaving black bars (#3134, #3149)
- **Screen filter JSON decoding** — CRT, scanline, sepia, and blur filters from skin `info.json` now apply at runtime instead of always being nil (#3135, #3150)
- **Skin download visibility** — Skin catalog install deep link and unofficial label fixes (#3098)
- **Boot performance** — Core plist scan results cached to disk; core scanner made non-blocking; skin scan deferred to first use; Mach-O fast-path probe for libretro metadata (#3015, #3109, da9fef2, d5a0e61, 265ef4e, d00841d)
- **Hatari TOS validation** — Multiple fixes for TOS boot: correct directory paths, byte-swap repair, ACSI boot option, per-core options file (#3112, #3127, #3144, #3152)
- **Mupen64Plus rumble** — Removed stray `register(nil)` call; added Taptic Engine fallback for touchscreen players (#3110)
- **Mupen64Plus bootup hang** — Fixed pause, rumble pak default, and bootup hang (#9bd8ee3)
- **On-screen controller touch routing** — Fixed PassThroughView absorbing all touches and overlay blocking game button input (#3117, #3124, #3126, 7bf3f39)
- **Pause menu button layout stability** — CORE tab and save-state buttons now rendered at fixed positions; unsupported items dimmed instead of removed (#2969, #3101)
- **VecX hardware rendering** — Fixed blank square in hardware rendering mode by returning correct HW render dimensions for `screenRect` (#2984, #3123, #3116)
- **Spotlight content types** — Removed invalid `contentType` strings that caused Spotlight to reject game entries (#2980, #3105)
- **Save state double prompt** — Prevented double version-mismatch prompt on launch (#949ab0c)
- **Save state load failure** — "Reset Game" option offered when save state load fails (#3082)
- **HUD overlay positioning** — Moved HUD controls to top strip so they never overlap skin buttons (#859579, 7f6ce09)
- **PrBoom button mapping** — Corrected Doom button mapping and shoulder button order (#fe0e0d6)
- **tvOS launch crash** — Added missing `BGTaskSchedulerPermittedIdentifiers` to tvOS Info.plist (#2489)
- **CrabEMU resolution** — Fixed bad resolution when nil at boot (#6f2f3f4)
- **Save state Realm crash** — Fixed freeze() inside uncommitted write transaction; moved serialization after commit (#3181, #3193)
- **Audio loop on pause** — Flush ring buffer when pausing to prevent stale audio looping (#3183, #3195)
- **HomeView flickering** — Replaced 5 `@ObservedResults` with background ViewModel to stop cascading re-renders (#3184, #3196)
- **Atari800 joystick crash** — Fixed infinite recursion in `didRelease:` and `didMoveJoystick:` (#3182, #3194)
- **Shoulder button order** — L2/R2 now on outer edge matching real controller layout (#3180, #3192)
- **JIT indicator** — Moved to bottom edge with auto-hide; only shows for cores that need JIT (#3186, #3198)
- **Skin catalog install status** — Downloaded skins now show as installed in catalog browser (#3188)
- **Skin activation** — "Set as Active Skin" now activates directly instead of navigating to browser (#3189, #3200)
- **Shader parameters in pause menu** — CRT shader parameters adjustable from the filter picker (#3185, #3197)
- **Save & Quit crash** — Prevented `setPauseEmulation` during core teardown (#3200)
- **Save state browser** — Added Realm refresh so newly created states appear immediately
- **CI submodule fixes** — Fixed ZipArchive, desmume2015, NP2kai submodule checkout failures
- **Companion Controller framework** — iOS companion device overlay infrastructure (#2697, #3190)

## Core Updates

- **RetroArch msg_queue OSD bridge** — All RetroArch-based cores now surface OSD messages as native PVToast notifications (#3157)
- **Atari ST comprehensive improvements** — Video, mouse input, ST keyboard layout, TOS version handling, and boot reliability across multiple PRs (#3094, #3112, #3127, #3144, #3152)
- **DosBox keyboard and mouse mapping** — Keyboard and mouse input support for DosBox core (#2457)
- **Cheat system short name audit** — Complete audit of cheat DB system mappings with forward-looking mappings for future systems (#3068, #3108)
- **Save state core version propagation** — Mock driver and full propagation chain for `createdWithCoreVersion` (#3102)

## UX Improvements

- **Inline core picker with save counts** — Core selection now shows save state counts per core for informed switching
- **Contentless core setup guides** — Setup guidance for cores that need BIOS or other files before use
- **Beta builds install guide** — Sideload feed and installation guidance for beta testers (#b94e2248)
- **Pause menu SKINS tab redesign** — Reorganized with scope picker, always-visible skin selectors, and immediate application on pick (#3121)
- **RetroMenuView button styling** — Improved visual hierarchy in the retro-style pause menu (#2969, #3121)
- **Sub-task progress display** — Boot sequence now shows sub-task progress with fix for Realm timeout scope (#546d3ee)
- **Screenshot browser** — New screenshot browser in pause menu with save-state UX improvements (#5d6ac25)

## CI / Infrastructure

- **Copilot + Claude review loop** — Agent context and auto-fix triggers for PR reviews (#b94e2248)
- **CI optimization** — Concurrency groups, alpha releases, agent PR smoke builds (#7ca84d3, #95801f8)
- **SPM validation script** — Agent validation CI for standalone module builds (#dcedb27)
- **CPDI bootstrap system** — Refactored app startup into structured bootstrap with Firebase Crashlytics config fix (#2463)
- **PVFeatureFlags remote fetching** — Remote feature flag fetching with retry, caching, and fallback (#2454)
