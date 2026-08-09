# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- AGENTS: Add new entries under [Unreleased] for every meaningful feature or fix.
     When a release ships, rename [Unreleased] to the version number and date,
     then add a fresh [Unreleased] section at the top. -->

## [Unreleased] — 3.4.0 (in development, March 2026)

### Added
- **Log Import** — the retrowave log viewer can now import a previously exported `.txt`/`.log` file or `.zip` bundle and display it in place of live logs, with a banner to return to live logs. (#3645)
- **AspectRatioOverride enum** — New `AspectRatioOverride` enum in `PVPrimitives` defines per-core aspect ratio overrides (Auto, 4:3, 16:9, 1:1, 8:7, Stretch) with display metadata and aspect ratio values. (#3619)
- **ScalingMode Enum** — Introduces `ScalingMode` (Aspect Fit, Aspect Fill, Stretch, Integer Scale, Native Resolution) to replace the legacy `nativeScaleEnabled`/`integerScaleEnabled` boolean pair, giving users a single unified video scaling picker. (#3616)
- **PVLogFileManager** — `PVLogging` module now supports writing rotating, date-stamped session log files to `Library/Logs/Provenance/`. Up to 10 files, 2 MB each, managed automatically. (#3615)
- **RetroArch Log Browser** — New Settings › Debug › RetroArch Logs screen to list, view, share, and delete RetroArch log files stored in `Documents/RetroArch/logs/`. (#3614)
- **Log Export & Share** — Export app logs as a plain-text file or ZIP bundle (including device info and RetroArch logs) via the native iOS share sheet, accessible from the Logs viewer header. (#3613)
- **N64 RetroAchievements (native Mupen64Plus)** — `MupenGameCore` now conforms to `CoreRetroAchievements`, exposing the N64 RDRAM memory region (8 MiB via `AudioInfo.RDRAM`) and lifecycle hooks so the rcheevos client can evaluate achievement conditions for N64 games played via the native Mupen64Plus backend. (#3610)
- **Legacy System Directory Migration** — On first launch after update, the app automatically migrates legacy flat-Documents system directories (`PSP/`, `com.provenance.n64/`, `nand/`, `sdmc/`, `sysdata/`, `Play Data Files/`, `RetroArch/system/`) to their canonical `System/<name>/` locations introduced in v3564. (#3604)
- **ProvenanceOpticalDriveDriverKit Xcode target** — DriverKit extension target (`com.apple.product-type.driver-extension`) for the USB optical drive driver, embedded in ProvenanceCompanion with deterministic UUID prefix `C0C0DE01`. (#3600)
- **RetroSettingsComponents** — new shared retrowave UI components in `PVUIBase`: `RetroSettingsBackground`, `RetroSettingsDivider`, `RetroSettingsSectionHeader`, `RetroSettingsPickerRow`, `RetroSettingsActionButton`, and `Font.retroSettings*` size helpers that automatically scale for tvOS viewing distance. (#3599)
- **Dynamic Island / Live Activities** — In-game Live Activity shows current game title, system, elapsed play time, and RetroAchievements points on the lock screen and in the Dynamic Island (iOS 16.2+, graceful no-op on unsupported devices). (#3597)
- **SaveState Intent** — Siri/Shortcuts intent to save the current game state to a specified slot. (#3596)
- **File Provider UI Extension** — Adds the `ROM File ProviderUI` App Extension skeleton (`ActionViewController`) so the `com.apple.fileprovider-ui` extension point is properly registered alongside the existing `NSFileProviderReplicatedExtension`. Fixes project.pbxproj to reference the correct Info.plist path and ProviderUI entitlements for all build configurations. (#3595)
- **DiscRipperView** — SwiftUI screen to rip a physical disc from a USB optical drive, with drive status badge, disc info card (system type, track count, total size), per-track selection, and recent rips list. (#3592)
- **IOUSBOpticalDriveDriver** — DriverKit user-space driver for USB optical drives (CD-ROM/DVD-ROM); matches ATAPI/BOT devices and exposes sector-read and TOC APIs to the app via IOUserClient IPC. (#3591)
- **SNES9x LightGunResponder** — Super Scope and Konami Justifier light gun support for the native SNES9x core. Aim, trigger, reload, and auxiliary buttons (Cursor, Pause, ToggleTurbo) are all mapped via the `LightGunResponder` protocol, enabling touch/GCMouse pointer input for games like Yoshi's Safari, Super Scope 6, and Lethal Enforcers. (#3589)
- **Virtual Skin Controller (Companion App)** — Use the Provenance Companion app as a wireless gamepad: touch an on-screen controller layout and stream input to any DSU/CemuHook-compatible emulator (Cemu, Yuzu, Dolphin, Ryujinx) on the same network. Unlocked via a one-time StoreKit 2 IAP. (#3587)
- **SharedCheatStore** — Actor-backed persistent store that reads/writes cheat codes to the App Group container (via `PVAppGroupId`), enabling cheat sharing between the main Provenance app, companion app, and extensions. (#3586)
- **Buildbot system file download** — Thin libretro wrapper now auto-downloads missing system files (e.g. `prboom.wad`, `ecwolf.pk3`, MSX BIOSes, FBNeo NeoGeo BIOS) from `https://buildbot.libretro.com/assets/system/` asynchronously at core startup, matching the `PVRetroArchCore` overlay-download pattern. (#3583)
- **CloudKit System/ Directory Sync** — `CloudKitBIOSSyncer` now backs up and restores user-placed firmware files from `System/PSP/`, `System/DC/`, `System/AtariST/`, and `System/Saturn/` via CloudKit. On tvOS, where the `System/` directory lives in Caches and can be purged by the OS, firmware is automatically re-downloaded from CloudKit on next launch. Bundle-seeded assets (e.g. PPSSPP flash0 fonts) are excluded because they are re-seeded from the app bundle on every core launch. (#3582)
- **System directory mappings** — Added `systemDirectoryName` entries for MAME, NeoGeo, NeoGeoCD, CD-i, Macintosh, PC-98, MSX/MSX2, C64, and EP128. The thin libretro wrapper now returns `System/<name>/` for these systems instead of falling back to the BIOS directory. (#3580)
- **SystemFileSyncing protocol** — New `SystemFileSyncing` protocol enables iCloud Drive syncing of files in `System/<name>/` subdirectories, complementing the existing `BIOSSyncing` protocol for BIOS files. (#3577)
- **Save Import Wizard** — multi-step retrowave-themed import wizard for save bundles (`.zip`), battery saves (`.sav`, `.srm`, `.ram`), and `.pvsave` files; accessible from Settings → Library → Import Saves or via any game's context menu → Import Save. (#3575)
- **Export Battery Save** — New context menu action on game cards to export only the SRAM/battery save file(s) for a game; single files are shared directly, multiple files (e.g. `.srm` + `.rtc`) are bundled in a zip. Gated behind the `sramImportExport` feature flag (disabled by default; enable in Settings > Advanced > Feature Flags). (#3573)
- **Save states registered in Realm on import** — `importSaves` now registers imported save states via per-save manifest metadata, so they appear in the UI immediately without a full library re-scan. (#3572)
- **Third-Party Emulator Migration Guide** — New "Import from Another Emulator" screen in Settings → Library detects installed emulators (Delta, RetroArch, Manic EMU, Consoles, PPSSPP, Gamma) and provides step-by-step export/import instructions for each. (#3571)
- **Siri Prediction Donations** — Provenance now donates an `NSUserActivity` with `isEligibleForPrediction = true` on every game launch, teaching Siri Suggestions to surface recently and regularly played games on the Lock Screen and in Spotlight based on time-of-day patterns. (#3570)
- **PVControllerDSU** — New Tier-0 Swift Package implementing the DSU/CemuHook UDP protocol: (#3569)
  typed packet enums with CRC-32/ISO-HDLC stamping, `actor DSUSocket` for async UDP transport,
  and Bonjour service advertisement/discovery via `DSUServiceAdvertiser` / `DSUServiceBrowser`.
  Supports iOS, tvOS, macOS, Mac Catalyst, visionOS, and watchOS.
- **PVUSBManager** — new SPM module for USB/HID peripheral discovery using `IOHIDManager`, `GCController`, and `ExternalAccessory`; includes `KnownDeviceProfiles` VID:PID database for 20+ gaming peripherals. (#3567)
- **`Paths.systemPath`** — New `Documents/System/` directory tree for per-console system files (BIOS, firmware, fonts). Provides `systemPath(forSystemName:)`, `systemPath(forSystem:)`, and `systemPath(forSystemIdentifier:)` helpers. Part of Epic #2725. (#3564)
- **TIC-80 System** — Added full system definition to `systems.plist` with D-pad, A/B/X/Y, L/R shoulders, Start/Select controls and `.tic`/`.zip` extension support. (#3563)
- **Feature Flag `allowedPlatforms`** — New optional `allowedPlatforms` field on `FeatureFlag` gates features to specific OS platforms (ios, tvos, macos, visionos); `nil` means all platforms (backwards-compatible default). (#3562)
- **Game Center Matchmaking** — New `NetplayGameCenterView` uses `GKMatchmakerViewController` (iOS/visionOS) to pair players via Apple Game Center; once matched, the host broadcasts their port and the peer auto-joins via RetroArch netplay. (#3559)
- **Save Import/Export Protocols** — Defines `SaveBundleExporting`, `SaveBundleImporting`, `KnownEmulator` (Delta, RetroArch, Mantic Emu, PPSSPP, Gamma), `SaveFileCategory`, `ExternalSaveFile`, `SaveImportResult`, `SaveExportResult`, and `SaveGameMatch` — the typed foundation for all cross-emulator save migration features. (#3557)
- **`.pvsave` Bundle Format (Schema V2)** — Save exports now use the `.pvsave` extension (a zip archive) with a schema v2 `manifest.json` that includes per-save metadata (date, isAutosave, core identifier, description, screenshot filename) for each save state in the bundle. (#3554)
- **INPlayMediaIntent SiriKit Integration** — "Hey Siri, play Donkey Kong Country on Provenance" now routes directly to the correct game via in-app `INPlayMediaIntentHandling` conformance on `PVAppDelegate`, with Siri disambiguation support for partial title matches. Interactions are donated on every game launch so Siri learns user patterns over time. (#3550)
- **Disc Serial Extractor Plugin Architecture** — Pluggable `DiscSerialExtractorPlugin` protocol in `PVHashing` with a `DiscSerialExtractorRegistry` singleton; built-in plugins for PSX/PS2 (ISO 9660 + SYSTEM.CNF), Sega Saturn/SegaCD/Dreamcast (IP.BIN header), GameCube/Wii (disc ID), BIN+CUE (track resolver), NDS ROM header, M3U multi-disc playlists, Dreamcast GDI format, and CHD v5 uncompressed archives. (#3543)
- **Smart Game Suggestions** — The Transfer Pak ROM picker now highlights GB/GBC games that are specifically recommended for the N64 title being configured (e.g. Pokémon Red/Blue/Yellow for Pokémon Stadium) in a dedicated "Suggested" section. (#3542)
- **`retroAchievements` CoreCapability** — New capability flag (`CoreCapability.retroAchievements`) declared in `PVPrimitives`, allowing cores to advertise RetroAchievements live-tracking support in the smart core selector UI. Displayed with a trophy SF Symbol. (#3541)
- **RetroArch Light Gun** — `PVRetroArchCoreCore` (thick RetroArch wrapper) now conforms to `LightGunResponder`, enabling GCMouse and touch-gesture light gun input for all RetroArch-hosted cores that declare `RETRO_DEVICE_LIGHTGUN` (NES Zapper, SNES Super Scope/Justifier, PSX GunCon, Saturn Stunner, Arcade/FBNeo, MAME, etc.). (#3536)
- **PVRcheevos SPM package** — New shared `PVRcheevos` / `CRcheevos` package that compiles the rcheevos C library (submodule at `PVRcheevos/rcheevos`); all native cores that need rc_client-based achievements can depend on this instead of bundling their own copy. (#3534)
- **RetroArch MIDI toggle in pause menu** — The CORE tab in the pause/retro menu now shows an "Enable MIDI Driver" toggle for RetroArch-path cores running on MIDI-capable systems (DOS, Atari ST, MSX, etc.). The toggle persists across sessions and applies to `retroarch.cfg` on the next session start (#3532)
- **DualSense / DS4 light bar theming** — DualSense and DualShock 4 light bars now change color to match the current system (#3529)
- **ArtworkMatchingService** — fast exact-match artwork lookup at ROM import time with a ≤2 s timeout, giving newly imported games artwork immediately before falling back to `ArtworkSearchQueue` (#3526)
- **Default DeltaSkin bundles for physical button cases** — Adds 23 pre-bundled DeltaSkin configurations for GameSir Pocket Taco, Soolra, Backbone One, and Razer Kishi v2 controllers (NES, SNES, GBA, GBC, Genesis/MD, and N64 variants per brand). Skins use a transparent overlay to maximise the game screen when a physical controller is connected; button coordinates are approximated and marked for real-device calibration (#3525)
- **Physical Case Auto-Skin** — When a recognised controller case (GameSir Pocket Taco, Soolra, Buppin) connects, Provenance automatically loads a compatible DeltaSkin session skin and shows a toast notification. Controlled by the new "Auto-load case skin on detection" toggle in Controller Settings (#3522)
- **Flycast iOS 26 JIT** — Added `com.apple.developer.kernel.allow-jit` entitlement to the jailbreak (JB) build variant, enabling the native JIT path on iOS 26+ for the Dreamcast/NAOMI emulator (#3521)
- **Gambatte rcheevos integration** — Wire GB/GBC native RetroAchievements via the shared PVRcheevos SPM package (CRcheevos); enable HAVE_RCHEEVOS in PVGambatteBridge; implement full rc_client lifecycle with NSURLSession server call and credential-based login. (#3516)
- **Multi-Select Mode** — Tap "Select" in the game library title bar to enter multi-select mode; game tiles show circle badges and a bottom toolbar tracks the selection count (#3514)
- **mGBA RetroAchievements Integration** — Wires mGBA's native rcheevos support (`src/core/achievements.c`) to Provenance's achievement delegate system, exposing GBA EWRAM/IWRAM/SRAM and GB/GBC WRAM/VRAM memory regions, implementing hardcore mode save-state blocking, and enabling `achievementsActive` state tracking (#3513)
- **Per-Game Mouse Input Override** — New "Mouse Input" picker in the Game Info screen lets users override automatic mouse detection for individual games (Auto / Always On / Always Off). Only shown for systems that support mouse input. (#3507)
- **Saturn Light Gun Support** — Mednafen Saturn core now implements `LightGunResponder` for the Sega Virtua Gun and Konami Stunner peripherals. Touch/mouse input is mapped to Mednafen's internal pointer-coordinate space; trigger, start, and off-screen reload buttons are fully wired. Supported games include Virtua Cop 1/2, House of the Dead, Area 51, Crypt Killer, Gunblade NY, and Die Hard Trilogy (#3504)
- **Console Layout Variant Selector** — Choose the controller layout for systems with multiple peripherals: Genesis 3-Button vs 6-Button Pad, Wii Wiimote / Wiimote+Nunchuck / Classic Controller / Classic Controller Pro, Atari 5200 Joystick+Keypad vs Joystick Only, NES Standard vs Zapper. Selection persists per system in Settings → Systems (#3501)
- **Genesis Light Gun Support** — Implements `LightGunResponder` for Genesis Plus GX, enabling touch-screen and GCMouse aiming for Sega Menacer, Konami Justifiers, and Sega Light Phaser peripherals. Gun type is auto-detected from ROM CRC; no manual game list required (#3499)
- **Light Gun Settings UI** — New "Light Gun" section in the Game Info screen for NES, SNES, Genesis, PlayStation, Saturn, MAME, Atari 2600, and any system registered via `LightGunSystemRegistry`. Per-game crosshair style (dot / crosshair / off), aim mode (auto / enabled / disabled), and sensitivity override with global fallback (#3497)
- **AU Audio Effects Chain** — Post-process emulator audio with built-in Apple Audio Units: reverb, delay/echo, distortion, low/high/band-pass filters, parametric EQ, peak limiter, and dynamics processor (#3489)
- **8BitDo SN30 Pro iCade profile** — New `PViCade8BitdoSN30ProController` class and `eightBitdoSN30Pro` iCade setting, selectable in Settings > Controllers > iCade Controller for users pairing in iCade mode (#3488)
- **MAME Unpacked ROM Folder Import** — Folders dropped into the Imports directory are now checked against the libretro database; folders matching a known MAME/CPS1/CPS2/CPS3 ROM set are imported directly into the system library, just like their ZIP equivalents. (#3484)
- **Camera Position in Pause Menu** — `RetroMenuView` and the tile-based pause menu now show a camera corner picker dynamically when recording is available and the camera overlay is enabled, so the corner can be changed without leaving gameplay. (#3483)
- **DOSBox Folder ROM Support** — Game folders containing `.conf`, `.exe`, `.bat`, or `.com` files at the root level are now recognised as DOSBox ROMs. Dropping such a folder into the Imports directory automatically imports it as a single DOS game entry, and DOSBox-Pure receives the folder path directly — no zipping required. `.dosz` support is unchanged (#3482)
- **Mednafen rcheevos Memory Regions (Phase 1)** -- Wire per-system RAM pointers for RetroAchievements integration: PSX (2 MB), NES (2 KB), SNES/snes_faust (128 KB WRAM), PCE/PCE-CD (8 KB), SuperGrafx (32 KB). Saturn excluded pending uint16 byte-order correction. achievements remain inactive until Phase 2 (rc_client session) is wired in issue #3380 (#3481)
- **PatchableCore for mGBA** — Declares `PVmGBACore` conformance to `PatchableCore` with supported formats `[.ips, .ips32, .ups]`, exposing mGBA's built-in patch routines to the protocol layer (#3476)
- **PPF Patcher** — Implements PPF (PlayStation Patch Format) v1.0, v2.0, and v3.0 patch application in PVPatching, with 20 unit tests covering all versions and error paths (#3475)
- **ArtworkMatchingService** — New protocol-driven service (`ArtworkMatchingServiceProtocol` / `ArtworkMatchingService`) that encapsulates the progressive-fallback artwork search logic previously duplicated across `ArtworkSearchQueue` (#3470)
- **Batch Artwork Source Filter** — Settings > Batch Artwork Matcher now shows per-source toggles (OpenVGDB, TheGamesDB, LibretroDB) so users can filter results by source database (#3469)
- **FuzzyGameMatcher** — New Tier-2 utility in PVPrimitives for fuzzy game title matching: Levenshtein edit distance, token-set Jaccard similarity, and ranked candidate scoring. Normalizes ROM tags (region, revision, disc labels) via `normalizedROMTitle()` before comparison, and is intended to support upcoming artwork lookup and manual search features. (#3468)
- Screen recording and live streaming via ReplayKit now work on Apple TV when a physical game controller is connected, and the Retro Menu shows recording and broadcast buttons on tvOS with a "Connect a game controller" hint when unavailable (#3463)
- **MIDI Multi-Select Device Picker** — RetroArch quick settings now includes multi-select pickers for MIDI input sources and output destinations, with live RX/TX activity indicators. Multiple devices can be selected simultaneously; empty selection enables auto-detect (all sources) mode (#3457)
- **ROM Library in Files.app** — Provenance now appears as a location in Files.app on iOS, macOS, and visionOS via `NSFileProviderReplicatedExtension`; browse your library by system folder and access individual ROM files (#3455)
- **Physical Case Controller Detection** — `CaseControllerDetector` identifies connected iPhone cases with built-in buttons by `GCController.vendorName` (smart cases: GameSir Pocket Taco, Soolra) and by companion skin identifiers published on deltastyles.com (passive cases: Buppin, which has no Bluetooth). Posts `PVPhysicalCaseDidConnect`, `PVPhysicalCaseDidDisconnect`, and `PVPhysicalCaseSkinDetected` notifications; shows a toast when a known case is connected (#3446)
- **ROM Library in Files.app** — Provenance now appears as a location in Files.app on iOS, macOS, and visionOS via `NSFileProviderReplicatedExtension`. Browse your library by system folder and access individual ROM files. (#3443)
- **Dolphin Netplay: Input Buffer Size** — Wire `Config::NETPLAY_INPUT_BUFFER_SIZE` so that `NetplaySettings.frameDelay` is applied to Dolphin's emulation engine immediately after a session starts. (#3431)
- **Atari 5200 Companion Controller wiring** — `PVAtari800` now adopts `CompanionControllerCapable`, mapping `Atari5200Layout` numpad, fire, start/pause/reset, and analog joystick events to `PV5200Button` calls via `handleCompanionInput(_:forPlayer:)` (#3428)
- **Hardcore Mode Fast-Forward Guard** — Fast-forward and emulation speed are now blocked when a RetroAchievements hardcore session is active, matching the existing save-state load restriction. An alert is shown when the user tries to enable fast-forward in hardcore mode. A rewind guard helper is also provided for future rewind UI integration (#3426)
- **Per-Game JIT Toggle** — Game Info now shows a JIT preference card for JIT-capable systems (N64, GameCube/Wii, PSP, 3DS, Dreamcast, PS2). Users can choose Automatic / Prefer JIT / Skip JIT per game, stored without Realm migration (#3422)
- **Web Server File-event → Realm Integration** — Deleting or moving a ROM/save-state/BIOS via the web UI or WebDAV now updates Realm: games with a CloudKit record are marked offline (`isDownloaded = false`, `requiresSync = true`); games with no remote copy are hard-deleted with full related-object cleanup (save states, cheats, recent plays, screenshots); standalone save-state and BIOS file deletions mark the respective records unavailable (`isDownloaded = false`) (#3421)
- **Atari 7800 ROM header normalization** — `A7800HeaderDetector` detects and skips the 128-byte `.a78` header so headered ROMs match No-Intro/OpenVGDB MD5 hashes on import (#3419)
- **Clip Capture** — Always-on ReplayKit clip buffer lets users retroactively save the last 30 seconds of gameplay via "Save Clip" in the pause menu, without needing to start recording in advance. Available on iOS 15+ and tvOS 15+; SAVE CLIP action is Provenance Plus-gated. (#3412)
- **MFi+ modifier swap-modes — Saturn, 32X, GameCube, Jaguar** — Extends controller mappings to expose missing inputs on GCGamepad/extended gamepad profiles: (#3411)
- **ROM File Provider** — Implements `NSFileProviderReplicatedExtension` to expose the Provenance game library in Files.app. Games appear organised by system under a "Provenance" location; tapping a ROM reveals its content for Quick Look or drag-and-drop export. (#3410)
- **Per-Game Save Export** — long-press a game → Export Saves creates a zip of battery saves and save states and opens the share sheet (iOS) or saves to Documents/Exports (tvOS); export is enabled whenever the game has save states or battery saves on disk (#3409)
- **Per-game Save Export** — long-press a game and choose "Export Saves" to package all save states and battery saves into a zip and share via the system share sheet; also accessible from the All Save States browser via a per-game export button (#3408)
- **ROM Drag Export** — Long-press a game tile in the library grid and drag it to Files.app, AirDrop, or any compatible target to export the ROM file; unsupported on tvOS. For iCloud-evicted ROMs, drag returns an empty provider and triggers a background re-download so the next attempt succeeds (#3407)
- **Native drag & drop ROM import** — Users can now drag ROM or zip files directly from Files.app (or any other app that supports drag & drop) onto the Provenance game library grid or list on iOS/iPadOS/macCatalyst. Dropped files are handed off to the existing `PVGameLibraryUpdatesController` → `PVGameImporter` pipeline, so the normal import flow (copy to Imports folder, hash, match, add to library) applies. A highlight border appears on the drop target while a compatible file is being dragged over it. Drag & drop is guarded with `#if os(iOS)` and is only active on iOS/iPadOS/macCatalyst. Part of epic #2136 / #2659. (#3406)
- **Mouse Input Settings** — New "Mouse Input" section in Settings → Controller and in the pause menu Options tab, letting users choose their input source (Auto / Touchscreen / Controller Touchpad / Gyro / Physical Mouse), adjust global mouse sensitivity, and tune gyroscope-specific sensitivity and dead zone (#3405)
- **Dreamcast Mouse Support (Flycast)** — Flycast now routes mouse input to the Dreamcast Maple bus for games that use a mouse peripheral (Typing of the Dead, Planet Ring, Floigan Brothers, Industrial Spy, Dream Passport, and more) (#3404)
- **GyroMouseAdapter** — New `PVCoreBridge` class that translates gyroscope rotation-rate into virtual mouse cursor movement for games conforming to `MouseResponder`; supports DualSense/Switch Pro via `GCMotion` and iPhone/iPad IMU via `CMMotionManager` fallback, with configurable dead zone, low-pass smoothing, and sensitivity (#3403)
- **GCMouse → MouseResponder bridge** — Physical Bluetooth and USB mice are now routed directly to emulator cores via a new `GCMouseMouseResponderDriver`; left, right, and middle buttons map to the corresponding `MouseResponder` protocol methods and relative deltas are accumulated into a normalised [0,1] cursor position (#3402)
- **Modern Web Server (Feature-Flagged)** — Introduces `PVWebServerManager`, a Swift actor that can coordinate between the legacy GCDWebServer and the new Hummingbird 2-based `PVModernWebServer`. In this release it defaults to the legacy GCDWebServer unless you explicitly enable the modern backend via the Settings › Advanced › Feature Flags debug override (`modernWebServer = true`). The new server delivers a dark-mode-aware drag-and-drop HTML file manager, async/await start/stop, WebDAV class-1 support, and proper multipart upload with the same `PVWebServer*Notification` constants. Part of Epic #2758. (#3399)
- **NetplayJoinConfirmView** — ROM hash verification screen shown before joining a netplay room; displays green/orange match status, room info, truncated hash comparison, and a mismatch warning with context (#3394)
- **Atari 2600 Trackball — Companion Controller support** — Wire the Companion Controller's TrackballLayout into the Stella core so Centipede, Missile Command, Crystal Castles, and other CX-22/CX-80 trackball titles receive relative mouse-delta input and fire-button events (#3393)
- **Document existing N64 RetroArch netplay support** — Clarify that `mupen64plus_next` and `parallel_n64` RetroArch cores already support network play today via the existing `PVRetroArchCoreBridge+PVNetplayCapable` implementation (HAVE_NETPLAY already enabled), and document how to access "Network Play" from the pause menu when using either RA N64 core. (#3392)
- **`CompanionKeyboardMouseCapable` protocol** — New `PVCoreBridge` protocol for emulator cores that support direct keyboard and mouse input from a companion controller session, distinct from the button/axis `CompanionControllerCapable` protocol (#3391)
- **melonDS Local Wireless Netplay** — Exposes melonDS DS local wireless multiplayer via `PVNetplayCapable`, enabling Nintendo DS games with local wireless support (Mario Kart DS, Pokémon, etc.) to be played between two Provenance instances on the same Wi-Fi network (#3390)
- **Vectrex Companion Controller** — Wires the Vectrex companion layout's analog joystick and four action buttons to the VecX emulator core via the new `CompanionControllerCapable` protocol; buttons 1–4 map to `PVVectrexButton` face buttons, and the analog stick maps to `analogUp/Down/Left/Right` (#3389)
- **ColecoVision Companion Controller wiring** — `PVGearcolecoCore` now conforms to `CompanionControllerCapable`, mapping the 12-key numpad, two side action buttons, and D-pad from the Companion overlay to `PVColecoVisionButton` events in the Gearcoleco core (#3388)
- **mGBA Link Cable Netplay** — Play GBA, GB, and GBC link-cable multiplayer (like Pokémon trading or Mario Kart battles) between two Provenance devices on the same Wi-Fi network (#3387)
- **Cheevos LibRetro Audit** — added `docs/cheevos-libretro-status.md` documenting that `HAVE_CHEEVOS` is enabled for all build variants (Lite, Standard, XL) and all 60+ libretro cores reach `cheevos.c` via RetroArch's unified runloop (#3386)
- **Dolphin Netplay Bridge** — `PVDolphinCore` now conforms to `PVNetplayCapable`, enabling GameCube and Wii network play sessions via Dolphin's built-in netplay subsystem (direct IP and traversal relay via `stun.dolphin-emu.org`) (#3385)
- **CompanionControllerCapable protocol** — `PVCoreBridge` protocol enabling emulator cores to receive companion controller input events (`CompanionInputEvent`). Prerequisite for all per-core companion controller integrations (#2702–#2706) (#3382)
- **Gambatte RetroAchievements integration** — wired GB/GBC WRAM and VRAM memory regions into `CoreRetroAchievements` so the achievement runtime can evaluate conditions; added `rc_client` lifecycle management (init on ROM load, `do_frame` each emulated frame, unload on stop) behind `HAVE_RCHEEVOS` compile flag ready for activation once the `PVRcheevos` package lands (#3379)
- **RetroAchievements stubs — snes9x, VBA-M, Stella, FCEU, DuckStation** — `CoreRetroAchievements` conformance stubs for five more native cores, enabling achievement tracking once the shared rcheevos SPM target lands. (#3372)
- **Light Gun Touch Gestures** — Single-finger tap fires the trigger, drag aims, two-finger tap triggers offscreen reload (PSX Guncon / SNES Super Scope), long press fires the AuxA button, and double tap fires the start button; gestures activate only when the running game supports a light gun peripheral (#3371)
- **PSX GunCon Light Gun Support** — Mednafen PSX core now implements `LightGunResponder` for Namco GunCon games (Time Crisis, Point Blank, Lethal Enforcers, etc.); touch/mouse input is mapped to PSX screen space and wired to Mednafen's GunCon peripheral API including trigger, A/B aux buttons, and off-screen reload (#3367)
- **NES Zapper support (FCEU)** — `PVFCEUEmulatorCoreBridge` now implements `LightGunResponder`; Duck Hunt, Hogan's Alley, Wild Gunman, and VS UniSystem Zapper games are playable via touch on iOS. (#3366)
- **Light Gun Crosshair Overlay** — SwiftUI transparent overlay that renders a configurable crosshair (dot, crosshair, reticle, or off) at the current light-gun cursor position for supported systems (NES Zapper, SNES Super Scope, PSX GunCon, etc.). Style is user-selectable in Settings; the overlay is gated behind the `lightGunCrosshair` feature flag (Settings > Advanced > Feature Flags). (#3365)
- **Light Gun Input Primitives** — adds `LightGunResponder` protocol, `GCMouseLightGunDriver` (bridges `GCMouse` delta events to normalised light-gun aim/fire calls), and `LightGunLifecycleManager` (attach/detach helper for cores that support light guns) (#3363)
- **SNES Mouse support in PVSnes9x native core** — `PVSNES9xEmulatorCore` now implements `MouseResponder`; games detected by the existing CRC32 list (Mario Paint, Mario & Wario, Arkanoid, Dezaemon, and 70+ others) automatically activate the virtual trackpad overlay and forward touch/pointer events as SNES Mouse input on port 1. (#3362)
- **PokéMini Palette Picker** — PokéMini now uses the `PaletteProviding` palette picker (14 named palettes with colour swatches) instead of the blind cycling action. (#3359)
- **Hatari (Atari ST) MIDIResponder** — `PVHatariCore` now conforms to `MIDIResponder`, enabling the MIDI device picker UI for Atari ST games. Note On/Off, Control Change, Program Change, and Pitch Bend messages are encoded to raw MIDI bytes and injected into the libretro `retro_midi_interface` input ring buffer so the Hatari core receives them each frame (#3355)
- **MIDI device persistence** — selected MIDI source/destination survive app restarts via UserDefaults (`midiSourceUniqueID`, `midiDestinationUniqueID` keys) (#3354)
- **MIDI Peripheral Support** — `MIDIResponder` protocol for emulator cores to receive/send MIDI messages (Note On/Off, CC, Program Change, Pitch Bend, Poly/Channel Aftertouch). System Common/Real-time (Clock, Start, Stop, Continue) and SysEx are defined as optional protocol methods but not yet dispatched by `MIDIDeviceManager` — will be implemented in a future PR. Modelled on the existing `KeyboardResponder` and `MouseResponder` patterns. (#3353)
- **DualSense / DualShock touchpad → mouse** — polling `touchpadPrimary` each frame in the thin libretro core forwards swipe gestures as relative mouse movement when the current system supports a mouse (iOS/tvOS 14.5+) (#3352)
- **QuickLookPreview Extension** — Register the Quick Look preview extension as a compiled Xcode build target so ROM files and save states show a rich HTML metadata card (box art, title, system, developer, year, genre, play count, favorite badge) when previewed in Files.app (#3348)
- **Smart Core Selection UI** — New `SmartCoreSelectionView` replaces the plain list when meaningful metadata is available: shows capability chips (mouse support, netplay, real mic, etc.), a "Recommended" badge for the best-fit core, save-state counts, and a "Set as Default" context menu option (#3347)
- **Per-Game Mouse Detection** — `MouseGameRegistry` intelligently gates mouse UI to games that actually use a mouse peripheral. Always-on for DOS/Macintosh/AtariST; game-specific for SNES (Mario Paint, Mario & Wario), Dreamcast, Saturn, and PSX. Prevents false-positive mouse overlays on SNES titles that don't use a mouse (#3344)
- **Netplay In-Game HUD** — `NetplayInGameOverlay` SwiftUI view displays a compact corner pill during active netplay sessions showing player count, colour-coded ping bars, and an expandable panel with per-peer latency, frame delay, rollback status, and a one-tap disconnect button (#3325)
- **Netplay Settings View** — Replaced the placeholder "coming soon" screen with a real settings form covering player nickname, default port, relay server URL, frame delay, max players, and spectator preferences, all persisted via `@AppStorage` (#3323)
- **Netplay Waiting Room** — Hosts see a live lobby after creating a room, showing connected players, connection info (IP + port), spectator count, and Start Game / Cancel buttons (#3321)
- **Network Play entry points** — "Network Play" now appears in the game library long-press context menu and the in-game pause tile menu when the `netplayEnabled` feature flag is on, presenting `NetplayLobbyView` as a sheet so players can host, browse, or spectate sessions (#3320)
- **RetroArch Netplay Integration** — `PVRetroArchCoreBridge` now conforms to `PVNetplayCapable`, enabling `PVNetplayManager` to host, join, and stop RetroArch netplay sessions natively; `PVEmulatorViewController` automatically registers the active core as the netplay bridge on emulation start and deregisters it on stop (#3319)
- **Script test suite** — `CoresRetro/RetroArch/scripts/tests/` with `test_get_modules.sh` and `test_make_frameworks.sh` covering: happy path, all-404 failure, partial failures, corrupt zip detection, pinned-date validation, pinned-date URL fallback, framework executable validation, and 80% threshold logic (#3318)
- **Mednafen Virtual Boy Palette Picker** — all 9 VB display modes (2D red/black, 2D white/black, 2D purple/black, and 6 3D anaglyph presets) are now selectable via the PalettePickerView tile in the pause menu (#3314)
- **`LightGunSystemRegistry`** — thread-safe, append-only singleton that tracks lightgun-capable system identifiers; seeds from a built-in baseline and is extended at runtime by cores via `register(system:)` or the `LightGunSystemsProvider` protocol (#3313)
- **ROM artwork thumbnails in Files app** — ThumbnailExtension now looks up the matching game in the shared Realm database by ROM filename and returns the cached box art as the QuickLook thumbnail. Falls back to a branded "P" placeholder when no artwork is available. (#3312)
- **PVQuickLookSupport** — New shared SPM module providing `ROMGameLookup`, `ArtworkResolver`, `SystemIconProvider`, and `GameMetadataCard` helpers; eliminates duplicated lookup and HTML-card logic between the ThumbnailExtension and QuickLookPreview extensions (#3311)
- **QuickLookPreview data-based preview scaffolding** — Updated PreviewProvider.swift with a complete HTML card implementation (box art, title, system, developer/year, genre, play count) ready for use once the build target is created (#3310). Updated Info.plist to use `QLIsDataBasedPreview = true` and `NSExtensionPrincipalClass`.
- **Lock Screen Widgets** — Quick Launch (circular, rectangular, inline) and Now Playing (inline, rectangular) lock screen widgets via the new `ProvenanceWidgets` extension; tap to launch your last-played game or display the current music track (#3305)
- **WidgetKit Extension (ProvenanceWidgets)** — New Home Screen widget extension with three widget types: Recently Played (Small/Medium/Large), Favorites grid (Small/Medium/Large/Extra-Large), and Library Stats (Small/Medium). All widgets read from the shared Realm database via the App Group container and support deep-link tap-to-launch via `provenance://open?md5=<hash>`. Recently Played and Favorites refresh every 15 minutes; Library Stats refreshes every 30 minutes. The main app should call `WidgetCenter.shared.reloadAllTimelines()` on game launch/end (#3304)
- **PVAppIntents module** — New Swift Package providing `GameEntity`, `SystemEntity`, `SaveStateEntity` AppEntities and five modern `AppIntents` (`LaunchGameIntent`, `ToggleFavoriteIntent`, `ListRecentGamesIntent`, `PlayRandomGameIntent`, `GetLibraryStatsIntent`) with `AppShortcutsProvider` Siri phrases. Provides a type-safe, iOS 17+ entity graph usable by the main app, widget extensions, and Siri. Includes migration stub (`CustomIntentMigratedAppIntent`) to ease transition from the legacy `PVOpenIntent`/SiriKit flow. (#3303)
- **Atari 8-bit Keyboard Support** — Full GCKeyCode → AKEY_* mapping for the Atari XL/XE; physical and virtual keyboards now work in BASIC and software that requires a keyboard (#3299)
- **libretro env callback coverage** — Added explicit cases for `RETRO_ENVIRONMENT_GET_SAVESTATE_CONTEXT`, `RETRO_ENVIRONMENT_GET_JIT_CAPABLE`, `RETRO_ENVIRONMENT_GET_DEVICE_POWER`, and `RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE` in both `PVLibRetroCore.m` and `PVThinLibretroFrontend.mm`; added `RETRO_ENVIRONMENT_GET_MICROPHONE_INTERFACE` in `PVLibRetroCore.m`. Cores no longer log "Unhandled RETRO_ENVIRONMENT" for these commands. (#3298)
- **RetroArch Transfer Pak (Mupen64Plus-NX)** — `PVThinLibretroCore` now conforms to `TransferPakSupport`, enabling the Transfer Pak slot-assignment UI and persistence layer for the thin libretro (RetroArch) emulation path. Setting a GB/GBC ROM on a controller port writes `mupen64plus-pak{N}=transfer` and the ROM path core option before the game loads. (#3295)
- **Core Options for This Game** — Long-press any game in the library to open per-game core options directly, scoped to that ROM's MD5; shows a sub-menu when multiple CoreOptional cores are available. (#3294)
- **Haptics & Rumble Settings** — New "Haptics & Rumble" settings section with dedicated `rumbleEnabled` master toggle, `rumbleDeviceEnabled` (device Taptic Engine), `rumbleControllerEnabled` (controller motors), and `dualSenseAdaptiveTriggersEnabled` (DualSense adaptive triggers) — each independently configurable (#3289)
- **Rumble Profile Settings UI** — New "Rumble Profiles" screen (Settings → Controllers → Rumble Profiles) lets users override the haptic profile for each system (N64, PSX, GBA, GameCube, Switch, Xbox) and for each controller type (DualSense, Xbox Series, Switch Pro, Joy-Con) (#3285)
- **In-Session Profile Swap** — "Controller Profile" tile in the tile-based pause menu lets players switch saved button-mapping profiles without leaving the game (#3278)
- **Hardware switches for Atari 5200** — TV Type (Color/BW) toggle switch visible in-game overlay (#3276)
- **SNES Multitap (Mednafen)** — CRC32-based detection enables 5-player (and 8-player homebrew) multitap for snes_faust and bsnes modules; game list mirrors snes9x (#3275)
- **Per-Port Device Type Picker** — Pause menu CORE tab now shows a collapsible device-type picker for each controller port when the libretro core reports supported types via `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO`. Users can switch ports between Joypad, Mouse, Keyboard, Light Gun, etc. (e.g. Mario Paint SNES mouse on port 2). Selections are persisted per-game/per-core and restored on next launch (#3268)
- **Tile/Grid Pause Menu** — New compact floating tile-based pause menu overlay that sits over the game screen instead of a full cover sheet. Enabled via the `pauseTileMenu` feature flag (Settings > Advanced > Feature Flags). Default is OFF; the classic tab/list menu remains unchanged. Supports dynamic column count, retrowave neon aesthetic, and iOS + tvOS. Extensible data model ready for CoreActions and skin-mapped tile inputs. (#3262)
- **PVLogging new categories** — `.emulator`, `.ui`, `.controller`, `.saveState`, `.library` for finer-grained Console.app filtering. (#3261)
- **Animated Switch Button Support** — `DeltaSkinButton` now carries `selfRetracting` (momentary toggle) and `DeltaSkinButtonStates` gains `selected` + `switchAnimation` (spring-curve config) for Manic skin parity. (#3257)
- **Skin Button Position Editor (MVP)** — Tap the pencil icon in the skin fullscreen preview to enter edit mode. Drag button bounding boxes to reposition them, use the stepper fields to nudge coordinates precisely, then tap Export to share a patched `.deltaskin` file. Available in the Skins Browser via the "Edit Button Positions…" context-menu action on any skin (#3254)
- **CoreAction Tiles** — CoreActions exposed by the active emulator core now appear as orange bolt-icon tiles in the tile-based pause menu; actions that require a reset show a ⚠︎ warning badge (#3249)
- **Neo Geo CD System** — added `com.provenance.neogeocd` SystemIdentifier, system definition (BIOS, extensions: cue/chd/m3u/iso, CD flag), TheGamesDB ID 4956, LibretroDB ID 136, and controller mapping (reuses NeoGeo 4-button layout). (#3245)
- **Licenses UI Rewrite** — LicensesView rewritten as native SwiftUI with a retro-styled card list. Search/filter bar on iOS and macOS Catalyst; tvOS opens URLs in the system browser; iOS/Catalyst show an in-app Safari sheet; native macOS uses the system openURL handler. License grouping is scaffolded (all cores show "TBD" pending `PVCore.license` support in #3236). Core data is loaded asynchronously on first appear via `.task` to avoid blocking SwiftUI init (#3244)
- **License Generation Script** — `Scripts/generate_licenses.py` recursively scans all Core.plist files and generates `Scripts/licenses.json` and `LICENSES.md` with attribution data; use `--check` to validate completeness in CI (#3243)
- **YAML Core Manifest** — Replace 4 manually-maintained urls.txt + xcfilelist files with a single `cores.yml` manifest and a Python generator script (`Scripts/generate_core_lists.py`). (#3241)
- **Core License & Copyright Metadata** — Added `PVLicenseName`, `PVLicenseURL`, and `PVCopyright` fields to the `Core.plist` schema, all Swift models (`CorePlistEntry`, `EmulatorCoreInfoPlist`, `EmulatorCoreInfoProvider`), Realm `PVCore`, and SwiftData `Core_Data` models. (#3236)
- **Hatari TOS BIOS entries** — Added 8 new optional BIOS entries for common `.rom`-suffixed TOS variants: `tos100us.rom`, `tos102us.rom`, `tos104us.rom`, `tos104se.rom`, `tos106us.rom`, `tos205us.rom`, `tos206uk.rom`, `tos206us.rom`. These are now importable via the BIOS import screen. (#3233)
- **Hatari TOS errors as native toasts** — Atari ST TOS boot failures (missing ROM, ZIP not extracted, invalid header, unexpected version) now surface as native `PVToastManager` notifications during emulation instead of silently failing or crashing. Uses the existing `PVOSDNotification` → `PVToastManager` bridge. (#3231)
- **Core Version Audit Script** — `Scripts/update_core_versions.py` scans each native core's source tree for version strings in `version.h`, `configure.ac`, `CMakeLists.txt`, `retro_get_system_info()` implementations, and similar files, then reports or updates `Core.plist` entries automatically. (#3228)
- **ProvenanceCompanion app target** — New iOS 18.0+ companion app shell (`org.provenance-emu.ProvenanceCompanion`) with placeholder TabView UI (Library, Peripherals, Settings tabs), shared App Group entitlement, and CloudKit capability pointing to the same container as the main app. This target is the container for the DriverKit system extension and serves as the App Store distribution vehicle for peripheral management. Includes AppStore and development entitlements, `ProvenanceCompanion.xcscheme`, and a `PBXFileSystemSynchronizedRootGroup`-based source layout. (#3218)
- **LightGunResponder protocol** — New `LightGunResponder` protocol in `PVCoreBridge` lets cores declare light gun support (`gameSupportsLightGun`, `requiresLightGun`) and receive normalised aim coordinates plus button events (trigger, reload, aux-A/B, start, select). (#3206)
- **Preferred Player Slots UI** — New section in Controller Settings lets users configure per-controller slot-assignment mode (Auto / Preferred / Always) with a P1–P8 slot picker; previously-seen disconnected controllers also appear so preferences can be reviewed and reset without reconnecting (#3158)
- **Per-button haptic patterns** — Skin buttons in `info.json` can declare a `haptic` block with `style` (light/medium/heavy/soft/rigid) and `intensity` (0.0–1.0); falls back to the default `UIImpactFeedbackGenerator` when absent. (#3154)
- **`DeltaSkinScreen.nativeResolution`** — optional `nativeResolution` field in skin `info.json` screens, allowing per-screen AR overrides that take precedence over the system registry. (#3153)
- **Skin Theme Variants** — skins can now declare named theme variants; users can select a per-skin theme persisted in UserDefaults. (#3145)
- **Keyboard Overlay Rendering** — Virtual keyboard overlay for skin-defined keyboard layouts; renders QWERTY, Compact, C64, ZX Spectrum, Amstrad CPC, Atari ST layouts with modifier key support via `DeltaSkinKeyboardOverlayView`. (#3142)
- **Animated skin backgrounds** — Orientation representations in `info.json` can now declare a `backgroundAnimation` block with `type` (frames/apng/gif), `frames` (array of filenames), `fps`, and `loops`. The new `DeltaSkinBackgroundAnimation` model is decoded by `OrientationRepresentations`. `DeltaSkinView` renders a `DeltaSkinAnimatedBackgroundView` beneath the game screen when a background animation is configured. Frame-sequence animations are driven by a `TimelineView` and pause when the app is backgrounded; `.apng` and `.gif` types display the first frame (#3139)
- **Per-button haptic patterns** — Skin buttons in `info.json` can now declare a `haptic` block with `style` (light/medium/heavy/soft/rigid) and `intensity` (0.0–1.0). The new `DeltaSkinHaptic` model is decoded from both `ItemRepresentation` and `DeltaSkinButton`. On button press, `DeltaSkinView` uses the per-button haptic when present, falling back to the default `UIImpactFeedbackGenerator`. Respects the user's `buttonVibration` preference (#3138)
- **PDF Size-Aware Rendering** — `UIImage(pdfData:preserveTransparency:)` now accepts an optional `size: CGSize?` parameter. When provided (and non-zero), the PDF is rendered at exactly that logical size using the current screen's retina scale, producing crisp HiDPI output. When omitted, the existing behaviour (native PDF size capped at 4096 physical pixels) is preserved. Call sites in `DeltaSkin.image(for:)` pass `rep.mappingSize` so skin images are rendered at the correct display resolution. (#3137)
- **RumbleSystemProfile** — per-system haptic tuning presets for N64 Rumble Pak, PSX DualShock, GBA cartridge motor, GameCube, Switch HD Rumble, and Xbox dual-motor controllers (#3130)
- **Mupen64Plus Auto Pak Detection** — Controller pak type is now auto-detected from the bundled `mupen64plus.ini` ROM database (`Mempak`/`Rumble` flags) after ROM load, mirroring RetroArch mupen64plus-next behaviour. New default is "Auto (ROM Database)" — legacy users with an explicit pak setting are unaffected (#3129)
- **Virtual keyboard opens expanded on user toggle** — Toggling the virtual keyboard from the skin overlay button or pause menu now opens it fully expanded. Auto-shown keyboards (cores that require keyboard, DeltaSkin `autoShow`) still open collapsed to a minimal drag handle to preserve screen space. Swipe-to-collapse gesture scoped to the drag handle only — no longer intercepts key-press touches (#3117)
- **Smart Pak (Memory + Rumble)** — new virtual combo pak mode (`PLUGIN_RAW`) for PVMupen that handles *both* persistent memory-pak saves and rumble feedback simultaneously. Previously users had to choose one or the other. Enable it by setting Controller Pak to "Smart Pak (Memory + Rumble)" in core settings. Saves are stored as `<romName>_controller<N>.mpk` in the battery-saves directory. (#3110)
- **`CoreJITSupportLevel` enum** — new type (`required` / `automatic` / `recommended(fallbackMode:)` / `notApplicable`) that drives differentiated JIT messaging based on how critical JIT is for each core. (#3103)
- **PPSSPP Ad Hoc Netplay** — Expose PPSSPP's PSP Ad Hoc network multiplayer through `PVPPSSPPCore+Netplay` ObjC bridge and `PVNetplayCapable` Swift conformance, enabling LAN multiplayer for PSP games via a PRO Adhoc Server proxy (#3089)
- **Mednafen Netplay Bridge** — `MednafenGameCoreBridge+Netplay` ObjC category wrapping `MDFNI_NetplayConnect` / `MDFNI_NetplayDisconnect`, plus `PVNetplayCapable` Swift conformance enabling PS1, NES, GBA, PCE, Saturn, and other Mednafen-backed games to participate in netplay sessions via `PVNetplayManager` (#3088)
- **WAN Netplay via RetroArch Lobby** — Room browser now has a Local/Internet tab; the Internet tab fetches live public rooms from `lobby.libretro.com` (RetroArch's relay-backed sessions included). (#3087)
- **PVNetplay** — New SPM package providing the foundation for native netplay: `NetplayRoom`, `NetplaySession`, `NetplaySettings`, `NetplayState`, `PVNetplayCapable` protocol, `PVNetplayManager` actor, and `PVNetplayBonjourDiscovery` (discovers RetroArch LAN rooms via Bonjour without any bridge changes) (#3084)
- **Save State Version Mismatch Detection** — new `SaveStateVersionChecker` utility detects when a save state was created by a different emulator core version and presents an async "Load Anyway / Cancel" dialog before proceeding. `createdWithCoreVersion` propagated through `SaveStateRowViewModel`, `RetroSaveStateItem`, and `PVPrimitives.SaveState`. (#3081)
- **Thin libretro frontend (`PVThinLibretroFrontend`)** — RetroArch-free libretro frontend in `PVCoreBridgeRetro` using only `libretro.h`. Loads cores via `dlopen`/`dlsym`, handles the full libretro environment callback API (including GLES3 hw-render via IOSurface-backed FBO), and provides all 5 core callbacks without any RetroArch internal headers. Foundation for running libretro buildbot dylibs without the full RetroArch binary. (#3080)
- **Forward-looking cheat mappings** — `SYSTEM_SHORT_NAMES` now pre-maps Nintendo e-Reader (→ GBA), Sufami Turbo (→ SNES), Super Game Boy / Super Game Boy 2 (→ GB), PlayStation 3, Quake, Quake II, Mega Duck, and Apple II so cheats are correctly attributed if libretro adds these directories in the future. (#3068)
- **Transfer Pak UI** — New `TransferPakConfigView` allows mounting GB/GBC ROM files into Mupen64Plus N64 controller-port Transfer Pak slots. Access via long-press context menu on any N64 game or via the Transfer Pak tile in the pause menu (only appears when the running core supports Transfer Pak). Feature-flagged off by default; enable in Settings → Advanced → Feature Flags → "mupenTransferPak" (#3027)
- **Save State Core Version Tracking** — Save states now record the core version and identifier used to create them, improving compatibility across devices and CloudKit sync (#2952)
- **BPSPatcherTests** — comprehensive XCTest coverage for all four BPS action types (SourceRead, TargetRead, SourceCopy, TargetCopy), CRC32 verification pass/fail, TargetCopy forward-reference guard, and invalid file/header handling; uses self-contained synthetic Data fixtures. (#2898)
- **Hardware Switch UI** — Physical-looking toggle switches for Atari 2600 (left/right difficulty A/B) and Atari 7800 (left/right difficulty) now appear in both the default SwiftUI skin and the legacy UIKit controller overlay, dynamically shown only for systems that have hardware switches. Includes a new `HardwareSwitchView` / `HardwareSwitchRowView` SwiftUI component with retrowave neon styling and haptic feedback on iOS; switch descriptors are sourced from `SystemIdentifier.hardwareSwitches` (#2893)
- **Interactive Button Repositioning** — Edit mode for on-screen controller skins lets users drag any button to a custom position; offsets are saved per-skin and persist across sessions. A "Reset to Default" button restores original layout. Gated behind the `skinButtonReposition` feature flag (disabled by default; enable in Settings > Advanced > Feature Flags). (#2891)
- **App Store Metadata Localization** — Added `fastlane/metadata/` directories with full App Store metadata (name, subtitle, description, keywords, release notes, privacy URL, support URL) for 13 languages: en-US, ar-SA, de-DE, es-ES, fr-FR, it, ja, ko, nl-NL, pt-BR, ru, zh-Hans, zh-Hant (#2875)
- **RTL layout support** — Arabic and Hebrew locales now display text right-aligned in game library section headers; swipe-to-delete gesture in the game grid is reversed in RTL layouts. (#2874)
- **Core Language Setting** — New "Core Language" setting under Core Options lets users choose the language used by emulator cores; defaults to the device locale so games load in the user's preferred language automatically (#2873)
- **Auto-translation pipeline** — `Scripts/auto_translate.py` detects new/changed English strings and translates them to 11 languages (zh-Hans, ja, ko, es, pt-BR, de, fr, it, nl, ru, ar) using Claude Haiku, merging results in-place into existing `.lproj` files. Only translates delta keys for cost efficiency (<$0.01/run). The companion `.github/workflows/auto-translate.yml` workflow triggers automatically on pushes that change `**/en.lproj/*.strings` files and opens a draft PR for human review. (#2871)
- **Korean (ko) and Arabic (ar) translations** — Add AI-generated translations based on community contributions from issues #2255 and #2256, adding `Strings.strings` and `Localizable.strings` to the respective lproj directories and registering both languages via `CFBundleLocalizations` in Info.plist files. (#2870)
- **Localization Audit Script** — `Scripts/audit_localization.sh` enumerates all `Text("…")` and `NSLocalizedString` calls, cross-references existing `.strings` files, and reports coverage gaps and missing keys per language (#2869)
- **3DS Emulation Strategy Spike** — Research document auditing PVEmuThree/PVAzahar override files, identifying the PVAzahar GPU black screen regression root cause, surveying the iOS 3DS emulation landscape (Lime3DS, Cytrus, Folium), and recommending a forward strategy (#2840)
- **Core Deadzone Coordination** — New `CoreDeadzoneCapable` protocol in `PVCoreBridge` lets emulator cores declare that they manage their own analog-stick deadzone, preventing double-processing when both a per-core and universal deadzone are active. (#2828)
- **ROM Title Normalization on Import** — Automatically strips region, revision, and format tags (e.g. `(USA)`, `[!]`, `(Disc 2)`) from ROM filenames when importing, producing clean library titles like "Bomberman" instead of "Bomberman (USA) [!]". Controlled by a new "Auto-Normalize Titles on Import" toggle in Library Management settings (off by default) (#2820)
- **MFi+ HUD Indicators** — Added `analogMode` and `swapMode` indicator IDs to the `PVIndicatorRegistry` system, with predefined state enums `PVAnalogModeIndicatorState` and `PVSwapModeIndicatorState`. (#2818)
- **Saturn TeamTap (6-player Multitap)** — Mednafen Saturn core now automatically enables the TeamTap adapter for known multiplayer games (via a built-in game-ID database), when 3+ controllers are detected, or when the new "TeamTap (Multitap)" setting is force-enabled by the user (#2815)
- **Genesis Plus GX: EA 4-Way Play multitap support** — Automatically detects known EA Sports 4-Way Play titles (FIFA International Soccer, FIFA Soccer 95/96/97, NBA Live 95/96, Madden NFL 96, Bill Walsh College Football) and configures the EA 4-Way Play adapter (`SYSTEM_WAYPLAY` on both controller ports), enabling up to 4 simultaneous players. Sega TeamPlayer detection remains unchanged and continues to use `SYSTEM_TEAMPLAYER` on port A (#2814)
- **PPSSPP OSD → PVToast** — `System_Toast()` callbacks from PPSSPP now surface as native in-game toasts. (#2805)
- **PVToast** — New in-game toast notification overlay (`PVToastManager`, `PVToastView`, `PVToastHostingController`) with retrowave aesthetics, queue-based stacking, auto-dismiss, persistent toasts, and VoiceOver support. (#2802)
- **Extended JIT Detection** — Introduces `JITSource` enum (`.altStore`, `.stikDebug`, `.trollStore`, `.system`, `.unknown`, `.none`) and `JITSourceDetector` to identify which tool is providing JIT (StikDebug via URL scheme, TrollStore via file-system paths, iOS 26 native JIT via `JITAuthorizer` class, jailbreak daemons, or Simulator). (#2795)
- **JIT Capability Matrix** — each core declares its JIT requirement via a `PVJITRequirement` key in its own `Core.plist` (`required`, `optional`, or `notRequired`). `CoreLoader` automatically populates a thread-safe `PVJITRequirementRegistry` (using `PVCoreBridge.PVJITPlistRequirement`) at startup — no hardcoded identifier list to maintain. (#2793)
- **Save State Browser** — New full-page "Save States" tab in the main navigation shows all save states grouped by game title, with expand/collapse per game, screenshot thumbnails, core version info, and autosave filtering. (#2790)
- **Per-game stacked autosaves** — All autosaves for a game are visually grouped behind a single representative card. The newest save is shown on top; ghost cards and a "+N" badge indicate hidden depth. Time-gap dividers ≥ 2 h are shown as session-break indicators inside the filmstrip. (#2789)
- **Serial-based ROM lookup** — `ROMMetadataProvider` gains `searchROM(bySerial:systemID:)` protocol method with a default no-op implementation for backward compatibility; OpenVGDB implements it via `ROMs.romSerial`, LibretroDB via `games.serial_id`. (#2782)
- **Controller Slot Preferences** — `PVControllerManager` now supports three slot-assignment modes per controller: `.auto` (unchanged first-available-slot behaviour), `.preferred(n)` (use slot *n* if free, else auto-assign), and `.always(n)` (always claim slot *n*, bumping the current occupant). Preferences persist across app launches and are applied on every connect/reconnect. A public `reapplyPreferences()` method re-applies all stored preferences after tvOS focus/wake events. Conflicts (two controllers both set to `.always(n)`) are handled gracefully — last-connected wins, warning logged. API: `slotMode(for:)`, `setSlotMode(_:for:)`, `clearSlotMode(for:)`, `preferredPlayer(for:)`, `setPreferredPlayer(_:for:)`, `reapplyPreferences()`. (#2773)
- **Transfer Pak support for Mupen64Plus-NX** — The Mupen64Plus-NX libretro core now implements `TransferPakSupport`, enabling GB/GBC cartridges to be mounted into N64 controller-port Transfer Pak slots (ports 0–3) for cross-game features (Pokémon Stadium, etc.) (#2741)
- **Transfer Pak Pre-Launch Prompt** — When launching a known N64 Transfer Pak title (Pokémon Stadium, Mario Tennis, etc.) with the `mupenTransferPak` feature flag enabled and no Transfer Pak slots configured, a setup sheet now appears automatically with "Skip & Launch" and "Launch Game" options so users can assign GB/GBC ROMs before the game starts. (#2739)
- **Per-Game Core Options in Game Info Page** — Added a "Core Options" section to the Game Detail / Info page for viewing and editing per-game emulator settings, with a live override count badge and descriptive disabled state for unmatched ROMs or cores without configurable options (#2734)
- **Per-Game Core Options Scope** — When Core Options is opened from the in-emulator pause menu, a "This Game / All Games" scope picker lets users set options that apply only to the current ROM, leaving global core defaults untouched. (#2732)
- **CoreOptionsScope** — New `CoreOptionsScope` enum (`.perCore` / `.perGame(md5:displayName:)`) to express which storage key tier is active in `CoreOptionsViewModel`. (#2730)
- **Face-Cam Overlay** — `PVCameraOverlayView` displays `RPScreenRecorder.cameraPreviewLayer` as a configurable picture-in-picture overlay during ReplayKit recordings (iOS only, Provenance Plus). (#2720)
- **`CameraPosition`** — New `CameraPosition` enum in `PVSettings` with four cases (`topLeft`, `topRight`, `bottomLeft`, `bottomRight`) for selecting the camera preview overlay corner during screen recording. (#2718)
- **Live Streaming via ReplayKit** — adds `PVBroadcastManager` (iOS 12+, tvOS 13+) wrapping `RPBroadcastActivityViewController` on both platforms so users can start or stop a live broadcast to Twitch, YouTube, or any installed broadcast extension directly from the pause menu "GO LIVE" button. Broadcast state is tracked in `PVBroadcastManager.isBroadcasting` (updated via `RPBroadcastControllerDelegate`) and surfaced in the Capture section of the Retro Menu. Gated behind Provenance Plus where FreemiumKit is available. (#2717)
- **OSD Recording Button** — Adds a record button to the in-game HUD (iOS only); tapping starts/stops ReplayKit screen recording with a red pulsing indicator while recording is active (#2716)
- **Game Match Source Tracking** — `PVGame` now tracks how its metadata was sourced (`matchSource`: none/md5/nameLookup/userImported/manual), which fields the user has customized (`userCustomizedFields` bitmask), and when the last metadata lookup occurred (`lastMetadataLookupDate`). (#2710)
- **Companion Controller System Layouts** — Adds system-specific touch overlays for the Companion Controller feature: Atari 5200 (numpad + analog joystick + side buttons), ColecoVision (numpad + action buttons + D-pad), Vectrex (analog joystick + 4 colour buttons), DOS/DOSBox (full QWERTY keyboard + mouse trackpad), and a `TrackballLayout` component for future trackball-capable titles (#2698)
- **Companion Controller UI Framework** — adds `CompanionControllerSession`, `CompanionControllerHostView`, `CompanionLayoutProtocol`, `CompanionInputRouter`, `CompanionControllerButton`, `CompanionControllerAxis`, and `GenericCompanionLayout` as the foundation for using an iPhone/iPad as an extended companion controller for Provenance sessions on Apple TV or another device. (#2697)
- **PVControllerDSU Module** — New standalone Swift Package implementing the DSU (DualShock UDP / CemuHook) protocol: typed packet enums with full encode/decode, CRC32, async UDP socket wrapper via `Network.framework`, and Bonjour/mDNS service advertisement and browsing. (#2693)
- **AirPlay in Pause Menu** — Added AirPlay route picker to both the tile-based pause menu (as an "AirPlay" tile in the GAME section) and the classic RetroMenuView (as a styled row in the Options tab), allowing users to stream audio/video to AirPlay devices without leaving a game session (#2684)
- **External Display Support** — Added `ExternalDisplayMode` setting (System Mirror / Dedicated) so standard Metal cores can show the game-only view on a connected TV or monitor while the controller skin stays on the device screen; cores with custom rendering surfaces automatically fall back to system mirroring. (#2683)
- **PVPatch Realm model** — New `PVPatch` Realm object in `PVRealm` that stores ROM patch file info (format, title, author, version, description, enabled state, source URL) linked optionally to a game. (#2676)
- **Focus Filter Intent** — `ProvenanceFocusFilterIntent` (`SetFocusFilterIntent`) lets users configure Provenance behaviour (suppress notifications) when a Gaming Focus is active via Settings → Focus → App Customization. (#2657)
- **PaletteProviding protocol** — New `PVCoreBridge` protocol (`PaletteProviding`) exposing `availablePalettes: [CorePalette]`, `currentPaletteID`, and `selectPalette(id:)` as a structured, type-safe replacement for string-matched `CoreActions` palette cycling. (#2649)
- **blueMSX Core Bridge** — Full controls bridge for blueMSX including joystick, keyboard (via libretro HID pipeline), and mouse support; adds `PVblueMSXEmuCore` Swift wrapper mirroring fMSX architecture (#2648)
- **TIC-80 keyboard support** — TIC-80 fantasy computer now shows the virtual keyboard automatically on launch, via both the RetroArch and thin-libretro core paths (`requiresKeyboard = true`) (#2645)
- **Vulkan→Metal bridge (PVThinLibretroFrontend)** — Implemented `thin_vulkan_set_command_buffers` (submits VkCommandBuffers to the MoltenVK queue via `vkQueueSubmit`), `thin_vulkan_set_signal_semaphore` (stores signal semaphore for queue submit), `thin_vulkan_wait_sync_index` (drains queue via `vkQueueWaitIdle`), and `thin_vulkan_set_image` (exports MTLTexture from the rendered VkImage via `vkGetMTLTextureMVK` / `vkExportMetalObjectsEXT` and forwards it to the Metal presenter) (#2624)
- **Drag & Drop Import** — ROM files and zip archives can be dragged directly into the game library from the Files app, AirDrop, and other file providers using `NSItemProvider` (#2136)
- **Screenshot Browser in Pause Menu** — New "SCREENSHOTS" button in the CAPTURE section of the pause menu STATES tab opens an inline sheet that lists all captured screenshots for the current game. Each row shows a thumbnail, filename, and share button (`UIActivityViewController`). Swipe-to-delete removes the file from disk and from the Realm database. An "Auto-Save to Photos" toggle at the top maps to the new `saveScreenshotsToPhotoLibrary` setting (default on). Screenshots captured with "SAVE SCREENSHOT" now respect this setting rather than always writing to the Photo Library (#pause-menu)
- **Save State Browser in Pause Menu** — Replaced the old UIKit save-state flow with an inline SwiftUI sheet that stays within the pause menu stack. Dismissing without loading returns to the pause menu (no stale dismissal). Save states display thumbnail, date/time, relative age, and core name; swipe-to-delete supported. Section headers ("SAVE STATES", "CAPTURE") and a live info row (save count · last saved N ago) added to the STATES tab (#pause-menu)
- **Pause Menu quick-load and distinct load actions** — "QUICK LOAD" immediately loads the most recent save state; "BROWSE SAVES" opens the new inline browser. Replaced the duplicate "LOAD STATE"/"SAVE STATES" buttons that previously pointed to the same UIKit screen with properly labeled, distinctly styled actions (#pause-menu)
- **`saveScreenshotsToPhotoLibrary` setting** — New `Defaults.Keys.saveScreenshotsToPhotoLibrary` (default `true`) controls whether `takeScreenshot()` auto-saves to the device Photo Library. Exposed via the "Auto-Save to Photos" toggle in the screenshot browser sheet (#pause-menu)
- **Auto-Apply Metadata on Rename Setting** — new `autoApplyMetadataOnRename` user preference (default: off) that controls whether Provenance automatically fetches metadata when the user renames an unmatched game.
- **RetroArch dylib update checker** — `check-dylib-updates.sh` queries the buildbot for the latest nightly date, reports when a newer snapshot is available, and can auto-bump `cores.yml` with `--update`.
- **Staleness warning** — `get-modules.sh` now emits a build-time warning when `pinned_date` is more than 30 days old, prompting developers to run the update checker.

### Fixed
- **Insert Coin tile unresponsive in MAME/CPS1/CPS2/CPS3** — the pause menu fully paused the core, so the coin press/release both landed while `retro_run()` was never executing and the libretro core never sampled it. The tile now briefly resumes emulation to let the press register, then re-pauses. (#3644)
- **Mouse Input Settings (tvOS)** — added `RetroSettingsBackground` so the view matches the retrowave styling of all other settings subpages. (#3599)
- **PSP flash0/font auto-seeding** — Thin libretro wrapper now seeds PPSSPP font files from the app bundle into `System/PSP/font/` on every core launch, matching `PPSSPPGameCore.mm` behavior and fixing tvOS cache-purge recovery. (#3583)
- **VICE core migration** — VICE Commodore emulator RetroArch machine subdirectories (`C64/`, `C128/`, `VIC20/`, `PET/`, etc.) and config files are now included in the legacy RetroArch system directory migration. (#3577)
- **RetroTheme shadowing** — Removed private `RetroTheme` enum that was shadowing the real `RetroTheme` from `PVUIBase`, causing the retro grid background to be replaced with a plain black color. (#3571)
- **DSUSocket init error wrapping** — `NWListener` initialisation errors are now consistently (#3569)
  thrown as `DSUSocketError.listenerFailed` instead of propagating raw `NWError` values.
- **USBPeripheralManager deduplication** — `connectedDevices.contains()` was using synthesized `Equatable` (which includes the random `id: UUID`), so the same physical device could be added multiple times. Deduplication now matches on `vendorID + productID + transport`. (#3567)
- **VB/GameGear legacy skin rendering** — Button hit areas now correctly align with the visual skin position on iPhones with home indicators; previously they were offset by the safe-area bottom inset (~34 pt) causing touches to miss buttons. (#3566)
- **PPSSPP "cannot find core resources"** — PPSSPP now uses `System/PSP/` as its MemStick and flash0 directory (was incorrectly using `Battery States/<rom>/`). Fixes resource-not-found errors when launching PSP games via `PVThinLibretroCore` on tvOS. (#3564)
- **skinButtonReposition syntax error** — Fixed missing closing parenthesis in FeatureFlag static definition. (#3562)
- **Relay server not pre-populated** — `NetplaySettingsView` now defaults to `ra.me` on a fresh install instead of an empty string; invite link default and `fromStoredDefaults` fallback are aligned to the same hostname. (#3559)
- **QuickLook iCloud files** — strip `.icloud` placeholder suffix from URLs before Realm lookup so cloud-hosted ROMs display metadata without needing to be downloaded first. (#3548)
- **PSX BIN+CUE serial extraction** — `BinCueDiscSerialPlugin` no longer skips `ISODiscSerialPlugin` when the data track is a `.bin` file (the extension check was incorrectly gating the ISO extractor, causing all PSX CUE+BIN images to return `nil`). (#3543)
- **JIT Double Alert** — Removed redundant in-emulator JIT onboarding modal that fired after the pre-launch contextual prompt, causing duplicate JIT alerts per session. (#3539)
- **PVRetroArch Mupen64Plus-Next iOS<26 pak1 migration** — Existing installs on iOS<26 that lacked a `pak1` setting in their `.opt` file would never receive the rumble default because `optionOverwrite=false` skips writing when the file exists. Now checks all three required settings (`pak1`, `rdp-plugin`, `rsp-plugin`) at once; any missing setting triggers a targeted merge+overwrite so all defaults are applied in a single pass. When all settings are already present, `optionValues` and `optionValuesFile` are cleared before setting `optionOverwrite=false`, preventing stale content from reaching the Obj-C write layer. (#3537)
- **RetroArch MIDI enabled by default** — `midi_input` and `midi_output` in the bundled `retroarch.cfg` now default to `"coremidi"` so DOSBox-Pure, Hatari, and other MIDI-capable RetroArch cores produce MIDI output on first launch without manual configuration (#3532)
- **MIDI Device Picker for DOSBox-Pure** — `thin_midi_write` previously ignored the user-selected MIDI device and always sent to the first available destination (`MIDIGetDestination(0)`). The MIDI output is now routed to the device chosen in the MIDI device picker, with proper no-op behaviour when "None" is selected (#3528)
- **JIT capability detection** — `jit_available()` in the RetroArch libretro bridge now correctly detects iOS 26 native JIT (`JITAuthorizer` class) and TrollStore installs, fixing Flycast refusing to load games on supported non-jailbroken devices (#3521)
- **GLideN64 NPOT Texture Rendering** — Force `GL_CLAMP_TO_EDGE` for non-power-of-two textures on iOS/tvOS, fixing rendering artifacts caused by unsupported wrap modes in OpenGL ES (#3517)
- **Plural localization** — Added `Localizable.stringsdict` files for `PVSwiftUI` and `PVUIBase` to provide grammatically correct singular/plural forms for all count-based strings (e.g., "1 save" vs "2 saves", "1 GAME" vs "5 GAMES", "1 file in queue" vs "3 files in queue"). Replaced hardcoded Swift ternary plural hacks (`save\(count == 1 ? "" : "s")`) with `String.localizedStringWithFormat` + stringsdict lookup, enabling proper pluralization for all supported locales. Part of #2869. (#3508)
- **iCadeState button collision** — `buttonI` and `buttonJ` shared the same rawValue (`1 << 13`), causing Mocute trigger inputs to be indistinguishable. Each bit flag is now aligned with its `iCadeReaderView` index (`buttonI` → `1<<12`, `buttonJ` → `1<<13`) (#3488)
- Correct P2 button report operator precedence (`(player+1 << 16)` → `((player+1) << 16)`) in the native snes9x core, fixing P2 controller input for all SNES games. (#3487)
- **RetroArch Hardware Acceleration (Metal driver)** — `GET_PREFERRED_HW_RENDER` now returns `RETRO_HW_CONTEXT_VULKAN` when the Metal video driver is active, and `dynamic_verify_hw_context` accepts the Metal driver for both Vulkan and GLES contexts. Beetle PSX HW and other hardware-accelerated cores can now negotiate hardware context correctly. (#3486)
- **TVMediaMainView scroll performance** — `refreshFromRealmChanges()` now only reloads games for the selected and already-loaded systems (instead of all systems sequentially), reducing Realm queries on each write from O(n) to O(loaded). (#3478)
- **Transfer Pak deadlock** — `confirmAndDismissPreLaunchTransferPak()` (renamed from `dismissPreLaunchTransferPakSheet`) resumes the launch continuation deferred to the next run-loop turn, preventing a root-view race while the sheet dismissal is in-flight; `onDismiss` remains as a safe no-op fallback for swipe-to-dismiss, guarding against the known SwiftUI bug where `onDismiss` is skipped when the binding is cleared programmatically. (#3464)
- **RetroArch MIDI config** — normalized `midi_input` and `midi_output` default values from `"OFF"` to `"Off"` to match the casing expected by the CoreMIDI driver endpoint selector (#3457)
- **ROM File Provider quality fixes** — Cascade-deletes save states, cheats, recent plays, and screenshots when a ROM is deleted via Files.app; guards against filename collisions on import by generating a unique destination name; correctly updates placeholder/missing records on duplicate import; normalizes MD5 hashes to uppercase to match codebase convention; rejects `.contents` writes (content replacement is unsafe while the item identifier is MD5-based); removed `.allowsWriting` capability accordingly; fixed `createItem` to use strong self capture so the completion handler is always invoked; wires progress cancellation handler to cancel the underlying import task; full filename sanitization (path-traversal stripping, colon/slash replacement, control-char removal, whitespace normalisation) applied consistently to both import and rename paths so on-disk names match display names; returns `.filenameCollision` error when a rename conflicts with an existing file; hashes source ROM before copying to avoid unnecessary IO for duplicates; adds explicit `Task.checkCancellation()` checks so cancellations terminate promptly; uses no-copy buffer for streaming MD5 to avoid per-chunk allocations (#3455)
- **ROM File Provider — Copilot review fixes** — Addressed all Copilot review issues: replaced `NSCocoaErrorDomain/NSFeatureUnsupportedError` with `NSFileProviderError(.unsupported)` in mutation methods; added filename sanitization to strip `/` and `:` from system names and game titles; removed `.allowsEvicting` capability since there is no rehydration path; added `allowsContentEnumerating` to folder items; tightened platform guard to `#if canImport(FileProvider) && (os(iOS) || os(macOS) || os(visionOS))`; improved domain registration error handling; clarified visionOS support scope in comments. (#3443)
- **Dolphin Netplay: `dolphinTraversalCode` stub** — Replaced the empty stub (always returned `nil`) with a live query via `NetPlayServer::GetInterfaceListToSend()` guarded by the traversal-client availability check. (#3431)
- **Web server delete/move stubs** — `webUploader:didDeleteItemAtPath:`, `webUploader:didMoveItemFromPath:toPath:`, `davServer:didDeleteItemAtPath:`, and `davServer:didMoveItemFromPath:toPath:` in `PVWebServer.m` were `NSLog`-only no-ops; they now post typed notifications consumed by `PVWebFileEventObserver` (#3421)
- **PokeMini test target** — added explicit `PVPokeMiniOptions` dependency to `PVPokeMiniTests` so palette tests compile correctly with `import PVPokeMiniOptions` (#3420)
- **Clip temp file cleanup** — Temporary clip file is now removed after a successful Photos save on iOS, preventing accumulation of MP4 files in the system temp directory. (#3412)
- **PVLibRetroCore MIDI stub** — `RETRO_ENVIRONMENT_GET_MIDI_INTERFACE` now returns the CoreMIDI-backed interface instead of `false`, activating MIDI for all legacy-path libretro cores (DOSBox-Pure, Hatari, NP2Kai, ep128emu) (#3354)
- **SNES Mouse (PVRetroArch)** — virtual trackpad overlay now appears for SNES games; `supportBySystemIdentifier` entry upgraded from keyboard-only to keyboard+mouse (#3352)
- **Flycast 30FPS Support** — Dreamcast games that render at 30fps are now automatically detected and synced correctly (#3345)
- **Flycast (Dreamcast) Mouse Input** — Flycast no longer boots with mouse active for standard games; port 0 is explicitly set to RETRO_DEVICE_JOYPAD for non-mouse titles, and RETRO_DEVICE_MOUSE for confirmed mouse-compatible games (Typing of the Dead, Planet Ring, Floigan Brothers), ensuring touch/pointer events reach the Dreamcast Maple bus mouse peripheral correctly (#3335)
- **SNES Mouse Support (RetroArch cores)** — SNES is now declared as a mouse-capable system, enabling the UI to forward touch/pointer events to bsnes and snes9x-next as `RETRO_DEVICE_MOUSE` input. The port-2 mouse default for Mario Paint (and other SNES mouse titles) is now applied correctly after `retro_load_game`, not before, preventing the core from silently reverting the port type back to joypad on load (#3334)
- **RetroArch core download pipeline** — `get-modules.sh` now exits non-zero when fewer than 80% of cores download successfully, rejects HTML 404 pages disguised as zips via magic-byte validation, and clears the download cache and fails the build phase when 0 dylibs remain after extraction (#3318)
- **PVJIT tvOS build** — Made SideKit dependency in the PVJIT target conditional on iOS (matching JITManager), preventing link errors on tvOS where SideKit is unavailable (#3317)
- **ThumbnailProvider double-handler bug** — Extension previously called the completion handler twice, causing undefined behaviour; now calls it exactly once in all code paths. (#3312)
- **UTI File Association Priority** — Expanded `CFBundleDocumentTypes` and `QLSupportedContentTypes` in iOS/tvOS plists to explicitly list a broad set of system-specific `com.provenance.rom.*` UTIs with `LSHandlerRank: Owner`; previously only the base `com.provenance.rom` was listed, which meant competing emulator apps (e.g. Manic EMU) could win the file association race for specific extensions like `.z64`, `.j64`, `.rom`, `.bin`, `.iso`; also fixed `SpotlightImportExtension` which was referencing non-existent `com.provenance-emu.*` UTI identifiers instead of the correct `com.provenance.*` ones (#3311)
- **HW-render cores (GLES3) now display frames via thin libretro wrapper** — `rendersToOpenGL` now returns `YES` for hardware-render cores; the FBO color texture is bound to the shared `IOSurface` from the Metal view's render delegate; and `RETRO_HW_FRAME_BUFFER_VALID` frames now trigger `didRenderFrameOnAlternateThread` so the Metal blit fires each frame. Fixes blank display for mupen64plus paraLLEl-RDP, flycast, Beetle PSX HW (GLES), and similar cores (#3301)
- **Hatari `--acsi ""` crash** — added explicit `[HardDisk]`, `[ACSI]`, `[SCSI]`, and `[IDE]` sections to the bundled `hatari.cfg` with all hard disk emulation disabled, preventing the hatari libretro core from passing an empty `--acsi ""` argument when no HD image is configured (#3284)
- **Spotlight thumbnail regression** — `UIImage(contentsOfFile:)` was called with the path-component of an HTTPS URL when artwork wasn't cached locally; now guarded with `isFileURL` so inline `thumbnailData` is only set from real local files while `thumbnailURL` still allows Spotlight to fetch the remote image (#3280)
- **Licenses screen showing "TBD"** — in-app Licenses screen now displays actual SPDX license identifiers, copyright holders, and license text links for all cores, grouped by license family (GPL, LGPL, MIT, BSD, Other) (#3270)
- **PVLogging double OSLog emission** — `DLOG`/`ILOG`/etc. previously emitted two OSLog entries; now only one per call. (#3261)
- **PPSSPP Core.plist** — corrected PPSSPP root-level Core.plist identifiers and supported system entries. (#3245)
- **Hatari TOS .rom extension** — TOS ROM files distributed with the `.rom` extension (e.g. `tos102us.rom`, `tos206uk.rom`) are now recognised by the BIOS importer and TOS search logic. Previously only `.img` files were accepted, silently blocking common ROM dump filenames. (#3233)
- **Hatari TOS version bytes** — when detecting the old-Provenance byte-swap pattern (address field stored as native LE integer), also fix the version bytes (2-3) which suffer the same endianness corruption. This resolves Hatari logging "TOS version 201, address $fc00" and rejecting an otherwise importable TOS 1.02 ROM. (#3231)
- **Core.plist versions corrected from source** — Five plists now reflect versions extracted directly from their submodule source: Genesis Plus GX (`v1.7.4`), Mupen64Plus-Next (`2.4`), PicoDrive (`2.03`), PokeMini (`v0.60`), TGBDual (`v0.8.3`). Normalised version strings reduce spurious save-state version-mismatch warnings. (#3228)
- **Doom Fire/Strafe button swap** — `PVDoomButtonFire` now correctly routes to JOYPAD_X (buttonY/north = Fire) and `PVDoomButtonStrafe` to JOYPAD_A (buttonB/east = Strafe On) in PrBoom Gamepad Classic layout. (#3224)
- **Atari ST BIOS Boot** — Extract Hatari/TOS BIOS logic into `PVRetroArchCore+BIOS+AtariST.m`; fix bug where a stale/invalid `tos.img` in the BIOS directory blocked a valid alternate (e.g., `tos102.img`) from being used; add full TOS inventory logging across BIOS, system, and system/hatari directories to aid diagnosis of stuck pre-patched BIOS files. (#3223)
- **SettingsTabView URL opening** — Replaced `UIApplication.shared.open(url)` with SwiftUI's `@Environment(\.openURL)` for idiomatic, testable URL handling. (#3218)
- **HomeView sort sync** — `homeViewModel.sortAscending` now stays in sync with `viewModel.sortGamesAscending` via `onChange` while the view is visible, not only on appear. (#3196)
- **Audio looping on pause** — ring buffers are now drained via a non-reallocating `clear()` call after the audio consumer stops, preventing stale samples from replaying when the pause menu opens and eliminating a potential use-after-free from the previous `reset()` path. (#3195)
- **Shoulder Button Order & Label Consistency** — Corrected L2/R2 to appear on outer edges in both static and dynamic fallback controller skins. Dynamic skins now recognize both "L1"/"L" and "R1"/"R" control titles, ensuring buttons display and dispatch the correct input IDs for all systems (e.g., PSX, PSP). Caches repeated `hasControl` layout lookups to avoid redundant O(n) scans during SwiftUI re-renders. (#3192)
- **Hatari TOS BIOS validation** — improve alternate TOS filename handling and post-sync TOS repair/validation to avoid crashes and ensure valid BIOS images after sync. (#3165)
- **Skin picker not showing downloaded skins** — fixed a race condition where downloaded skins would not appear in the device skin picker after being installed (#3164)
- **Realm thread-safety crashes in pause menu** — cheats and save states views no longer crash when accessed via a `@ThreadSafe` game reference; cheats now re-query Realm on reload so newly added codes are visible without dismissing the view. (#3162)
- **GameGear / legacy handheld skin screen fill** — detect and normalise legacy pixel-coordinate skin layouts; enforce correct aspect ratios for Game Gear (160×144), Atari Lynx (160×102), and WonderSwan so skins fill the screen correctly instead of leaving black bars. (#3154)
- **Hatari/Atari ST boot crash** — `hatari_boot_hd` option was set to `"false"` (an invalid value); changed to `"disabled"` which is the value the hatari libretro core actually accepts. The old in-place repair was incorrectly replacing valid `"disabled"` values with invalid `"false"`, making things worse; it now only corrects genuinely broken variants (`"false"`, `"true"`) — the valid `"enabled"` value is preserved (#3144)
- **Screen Filter JSON Decoding** — `DeltaSkinScreen` now correctly decodes `filters` from skin `info.json` and constructs `CIFilter` instances; CRT, scanline, sepia, and blur filters specified in skins now apply at runtime. Also adds `filterInfos` for round-trip encoding fidelity and wires decoded filters into the Metal rendering pipeline via `PVEmulatorViewController`. (#3135)
- **GameGear/Legacy Handheld Skin Screen Fill** — detect and normalise legacy pixel-coordinate skin layouts; add aspect-ratio enforcement for systems like Game Gear (160×144), Atari Lynx (160×102), and WonderSwan. (#3134)
- **Azahar / emuThreeDS JIT classification** — both cores are reclassified from `.requiredOrCrash` to `.automaticWithFallback`. They auto-detect JIT availability at runtime and fall back to interpreter mode, so launch is always safe. The cores are no longer gated behind a JIT requirement and the `enableJIT` option now defaults to `true` so users get full-speed emulation when JIT is available. (#3131)
- **PVRetroArch Mupen64Plus-Next rumble regression** — A prior commit (`efe5e0d`) added `optionOverwrite=true` for iOS 26+ to force CXD4 RSP (replacing the JIT-crashing ParallelRSP), but this wiped the entire `.opt` file on every launch — clearing all user-configured options including pak types back to the `"memory"` default and silencing rumble-pak games (GoldenEye, Star Fox 64). Rumble worked on iOS 26 before that commit; this was a regression, not an inherent iOS 26 limitation. The fix now does a targeted in-place patch: only the `mupen64plus-rsp-plugin` line is updated; all other settings (audio, video, gameplay, and pak types) are preserved. Fresh installs default `pak1` to `"rumble"` so rumble-pak games work out of the box (#3129).
- **Hatari ACSI boot error** — `hatari_boot_hd` is now written to `Hatari/Hatari.opt` (the per-core options file RetroArch reads for `GET_VARIABLE`) with the valid value `"false"` instead of `"disabled"` in the appendconfig. Prevents the `--acsi ""` error that caused Hatari to fail on every launch (#3127)
- Fixes unresponsive on-screen controller buttons so touches pass correctly through overlays to the underlying game controls (#3117)
- **Hatari/AtariST TOS validation (`$fc00` error)** — Hatari libretro uses `system/hatari/` as its working directory; `hatari.cfg` and `tos.img` are now written there (in addition to `system/`) so Hatari reads the correct config and ROM. Also copies the fresh TOS ROM to the working dir on every boot, overwriting any stale/corrupted copy from previous runs. (#3112)
- **Mupen64Plus rumble** — removed stray `register(nil)` call that cleared the controller registration on every rumble event, causing haptics to silently fail. (#3110)
- **JIT Indicator Tap Presentation** — replaced full-screen cover sheet with a compact `UIAlertController` dialog showing a brief status message when the user taps the JIT HUD pill. (#3103)
- **Skin Catalog Duplicate Systems** — `availableSystems()` now lowercases all codes before deduplication, preventing mixed-case duplicates (e.g. `"masterSystem"` vs `"mastersystem"`) that caused broken filter-chip selection. (#3100)
- **RetroArch Netplay enabled** — Added `-DHAVE_NETPLAY` compiler flag to `BuildFlags.xcconfig`, enabling RetroArch's full rollback netplay engine for all 60+ RetroArch-backed cores (NES, SNES, GBA, GB, N64, DS, Genesis, PS1, Dreamcast, Saturn, and more). Netplay accessible via RetroArch in-game menu → Settings → Network → Netplay; relay support via RA.ME built-in. Part of #2483 (#3083)
- **Version mismatch alert hang** — `SaveStateVersionChecker.confirmLoad(on:)` now guards a `hasResumed` flag to prevent double-resume, adds `withTaskCancellationHandler` to resume `false` if the Swift task is cancelled while the alert is visible, and hooks `UIAdaptivePresentationControllerDelegate` to resume on interactive sheet dismissal. A pre-flight guard also resumes immediately (with `false`) if the view controller cannot present (not in window or already presenting). (#3081)
- **Dynamic libretro core scanner (`PVDynamicLibretroCoreScanner`)** — New `PVCoreLoader` class that scans the app's `Frameworks/` directory at runtime for `*.libretro.framework` and bare `.dylib` cores not already registered via static plists. Discovered cores are synthesised as `EmulatorCoreInfoPlist` sub-cores of a `PVThinLibretro` virtual parent, allowing buildbot dylibs to appear in the core-picker automatically. Includes `CoreLoader.mergeDiscoveredLibretroCores(into:)` integration point. Guarded by the `dynamicLibretroScanner` feature flag (off by default; enable via `UserDefaults.standard.set(true, forKey: "dynamicLibretroScanner")`). Part of #2639 (#3080)
- **GeckoCodes system gating** — GeckoCodes lookup is now only triggered for valid 6-character alphanumeric disc IDs (GC/Wii format) and when the system identifier is known to be GameCube or Wii, preventing unnecessary network requests for ROMs on unrelated platforms (#3073)
- **LibraryNavigator routing system** — New `LibraryNavigator` (`PVUIBase`) provides a typed, DRY routing hub for library-level UI actions. Replaces scattered `AppState.pendingSearchQuery` observations with a `LibraryAction` enum (`.search`, `.console`, `.game`) observed uniformly by `ConsolesWrapperView`, `RetroMainView`, `RetroGameLibraryView`, and `HomeView`. Supports `provenance://screen/search?q=<query>` deep links via `AppRoute.search` and `LibraryRouteProvider` (auto-registered at startup). Part of #3056 (#3064)
- **Doom Input Conformance & Fallback Routing** — `PVRetroArchCoreCore` now conforms to `PVDoomSystemResponderClient`, mapping `PVDoomButton` events through the DOS bridge; this ensures `PVCoreFactory` correctly routes Doom sessions to `PVDoomControllerViewController` instead of silently falling back. Added `PVDOSSystemResponderClient` fallback paths in `PVCoreFactory` and `DeltaSkinInputHandler` for any core that does not yet implement the Doom-specific protocol. Shoulder/trigger buttons in `PVDoomControllerViewController` are now assigned by OSD label (L/R/L2/R2) rather than iteration order, preventing strafe and weapon-cycle buttons from being silently swapped when the control layout lists R2 before R (#3062)
- **Delta/Manic Skin File Association** — Registered `.deltaskin` (`com.provenance.deltaskin`) and `.manicskin` (`com.provenance.manicskin`) UTI declarations and document type handlers across all build schemes so Provenance now appears in the iOS "Open with…" sheet when tapping these skin files in Safari or Files (#3058)
- **Virtual Input Quick-Toggle Buttons** — Keyboard and mouse-cursor toggle buttons now appear directly in the game overlay (both UIKit legacy and SwiftUI default skin) for cores that support virtual keyboard or mouse input (e.g. DOSBox, Doom). Buttons are shown only when the active core reports support, sit in the top-leading HUD corner, and visually indicate active/inactive state (#3057)
- **Siri "Search in App" now populates search field** — `handleSiriSearchActivity` sets `pendingSearchQuery` correctly; `LibraryNavigator` now bridges `AppState.pendingSearchQuery` into a `.search` `LibraryAction` observed by `HomeView`, avoiding the `@Published` `willSet` race, and `ConsolesWrapperView` navigates to the Home tab on both cold- and hot-launch so the search results are immediately visible (#3056)
- **Wolf3D Dedicated Input Responder** — Created `PVWolf3DButton` enum and `PVWolf3DSystemResponderClient` protocol with correct ECWolf libretro button constants (`run` maps to JOYPAD_X/north, `strafeOn` maps to JOYPAD_Y/west). Added `PVWolf3DControllerViewController` with Wolf3D-specific button labels (Shoot, Open, Run, Map, Menu). Fixes incorrect button mapping inherited from the generic DOS responder (#3054)
- **Doom/PrBoom Dedicated Input Responder** — Added `PVDoomButton` enum and `PVDoomSystemResponderClient` protocol (mirroring the Wolf3D pattern) so Doom has its own fully independent input path. `PVDoomControllerViewController` now uses `PVDoomButton` exclusively. Removed Doom-specific branching from the generic DOS responder. `PVDoomButton.map` (SELECT/automap) intentionally does not fire `buttonHome` so the automap press never accidentally opens the RetroArch menu (#3053)
- **Virtual Mouse Touch Overlay** — `TouchTrackpadView.hitTest` no longer captures touches outside the game display area; fixes inability to tap skin overlay buttons, the pause menu, or any UI element when virtual mouse is active (DOSBox, PrBoom, etc.). Added `explicitGameViewRect` property updated by `applyFrameToGPUView` so the correct viewport rect is always used, even before the first skin-repositioning callback (#3052)
- **Auto-Save Crash on ReplayKit Recording Start** — Fixed a crash where tapping "Record Game" triggered an `appWillResignActive` event that attempted an auto-save during ReplayKit's setup window. Added an `isPreparingRecording` flag to `PVRecordingManager` (set during `startRecording()`) so `appWillResignActive` can skip the auto-save. Also added a `realm.isInvalidated` pre-flight guard in `RomDatabase.registerSaveState` to prevent an uncatchable ObjC NSException from `beginAsyncWriteTransaction` (#3051)
- **MetricKit Hang Reporting** — Passive `MXMetricManagerSubscriber` added to `PVAppDelegate`; hang, crash, and CPU-exception diagnostic call stacks are now logged via PVLogging on the next app launch after an event, enabling real-world hang analysis without user action (#3046)
- **Doom Face Button 1 (Shoot) Fix** — Corrected the PrBoom/RetroArch button mapping so face button 1 fires/shoots (JOYPAD_B via `buttonA` south) instead of silently triggering the unmapped strafe action; face button 2 correctly triggers Use/Interact (JOYPAD_A via `buttonB` east). On-screen button labels updated: "1"→"Shoot", "2"→"Use", "Start"→"Map" (select/automap), "Reset"→"Pause" (#3043)
- **Cheat Sheet Crash on Open** — Fixed crash when opening the cheat sheet from the RetroMenuView pause menu. `recoverCheatCodes()` was calling `@ThreadSafe` on an unmanaged Realm object returned by `asRealm()`; `ThreadSafeReference` requires a managed object and would fire a fatal error immediately. Replaced with a synchronous `realm.write` on the main actor. Also added a nil guard for `game` in `showCheatsMenu()` to prevent force-unwrap crashes (#3042)
- **Settings Help Button Opens Internal Wiki** — The always-visible HELP button in the Settings header now opens the in-app `WikiHelpView` sheet instead of launching an external URL in Safari (#3028)
- **Springboard Quick Actions** — Long-pressing the Provenance app icon now correctly shows recently-played games and favorites again; fixed by ensuring `UIApplication.shared.shortcutItems` is always updated on the main thread via `MainScheduler.instance` (#3026)
- **ReplayKit Record-Game Crash** — Fixed an immediate crash when tapping "Record Game" in the pause menu. The `withCheckedThrowingContinuation` closure passed to `RPScreenRecorder.startRecording/stopRecording` is `@Sendable`/non-isolated in Swift's concurrency model; on iOS 17+ the runtime may schedule it off the main actor, violating ReplayKit's main-thread requirement and crashing. Both calls are now explicitly dispatched via `DispatchQueue.main.async` inside the continuation body, ensuring the handler always fires on the main queue (#3025)
- **Siri/Spotlight Save State Thumbnails** — Save states launched from Siri or Spotlight now display their screenshot thumbnail (falling back to game artwork) instead of appearing without artwork in search results (#3023)
- **JIT Status Indicator Popover** — Tapping the JIT status indicator in the emulator HUD now shows a compact `.popover` instead of an inline expanding banner that overlapped game content (#3020)
- **Overlay Quick-Action Buttons** — Fast-forward, quick-save, and quick-load buttons in the legacy UIKit controller overlay are now always tappable, correctly alpha-matched, and no longer obscured by game-control views. Root causes: indicator overlay had no hit-test passthrough so it swallowed all touches in empty areas; `quickActionsContainer` was never brought to front after `setupTouchControls()` stacked game controls on top of it; and controller-opacity was incorrectly applied to quick-action buttons. Also fixed an operator-precedence bug in `adjustDPadPosition` that pushed the D-Pad off-screen on every layout pass. (#3018)
- **GameMoreInfoView Glass Borders** — Suppressed unwanted liquid glass borders on the DONE, Play, and web-reference toolbar buttons in `GameMoreInfoView` on iOS/tvOS 26+. Custom stroke borders and glow shadows are now conditionally skipped via `legacyStrokeBorder`/`legacyGlowShadow` helpers so the system provides its own glass treatment without visual doubling (#3017)
- **Empty Library Flash on Launch** — `HomeView` no longer flashes the "Your library is empty" / cloud sync upsell state before async Realm queries complete; the empty state is now gated on `bootupStateManager.isBootupCompleted` (#3016)
- **Boot step "Initializing game importer" disproportionately slow** — Multiple optimizations to the game importer initialization path: (#3015)
  1. `initCorePlists()` now has an idempotency guard so the redundant second call from `initSystems()` returns instantly when the background pre-fire has already completed.
  2. Per-system directory creation (`createDefaultDirectories`) moved to a background `Task.detached` — filesystem I/O for 60+ system ROM folders no longer blocks the boot sequence.
  3. `updateSystemToPathMap()` simplified from an async-reduce with actor hops to a synchronous loop, eliminating unnecessary context switches.
  4. Removed unused `updateromExtensionToSystemsMap()` function that was dead code inside `initSystems()`.
  5. `CoreLoader.getCorePlists()` runs in a detached task with full-result disk caching so subsequent launches skip the filesystem scan entirely.
- **CloudKit/GameImporter Pause During Gameplay** — Fixed regressions where `CloudKitRomsSyncer`, `GameImporter`, and `DirectoryWatcher` continued running I/O work during active gameplay. Introduced `PausableService` protocol with `ServiceLifecycleReason` enum and `BackgroundServiceRegistry` for centralized service lifecycle management. All background services (`CloudSyncManager`, `GameImporter`, `CloudKitDownloadQueue`, `DirectoryWatcherService`) now conform to `PausableService` and self-register, so callers use a single `BackgroundServiceRegistry.shared.pauseAll(reason: .emulation)` instead of reaching out to each singleton. Reason-based tracking prevents one caller's resume from undoing another caller's pause. `setupSaveStateObserver` skips enqueueing uploads while emulation is active; `performMetadataBootstrap` exits early when paused; syncer-owned `workQueue`s are suspended alongside manager queues. (#3014)
- **Wiki Viewer — GitBook tag and HTML rendering** — GitBook liquid tab tags (`{% tabs %}`, `{% tab title="..." %}`, `{% endtab %}`, `{% endtabs %}`) now render as Markdown section headers and separators instead of raw strings. HTML `<table>`, `<strong>`, `<em>`, `<details>/<summary>`, and `<br>` blocks are converted to their Markdown equivalents before rendering. External links in wiki content open in an in-app Safari sheet; internal `.md` links navigate to the corresponding local wiki page (#3013)
- **Skin Catalog Selection Update** — Downloading and selecting a skin from the catalog now reactively updates the active skin shown in the pause menu Skins tab (#3012)
- **Browse Skins Done Button** — Moved the "Done" dismiss button in the Browse Skins sheet from the trailing (right) toolbar position to the leading (left) position (#3011)
- **Skin Catalog System Pre-filter** — Opening the skin downloader from the pause menu now pre-selects the active game's system so only relevant skins are shown; the filter bar is revealed automatically (#3010)
- **DOS-style FPS Touch Controls** — Doom, Wolf3D, Quake, and Quake II now reuse the DOS controller overlay path so their UIKit touch controls honor run/strafe/weapon mappings, and Quake-family default layouts now expose shoulder + Run buttons like Doom (#3001)
- **PVVecX Hardware Rendering Blank Screen** — Fixed enumeration option accessors in `VecxOptions` returning integer indices instead of the expected label strings. `vecx_use_hw` now returns "Hardware"/"Software" (not "0"/"1"), enabling the C libretro core to activate its GL rendering path; `vecx_res_hw` now returns the resolution string (e.g. "824x1024") so WIDTH/HEIGHT are parsed correctly; scale/shift options now return float strings for correct viewport math (#2984)
- **CrabEMU Input Map (SMS/GG/SG-1000)** — `MasterSystemMap[]` array reordered to match `PVMasterSystemButton`/`PVSG1000Button` enum raw values (`b=0, c=1, start=2, up=3, down=4, left=5, right=6`); previously the d-pad Up press sent `SMS_RIGHT` (index mismatch), making all directional and face-button inputs incorrect for Master System, Game Gear, and SG-1000 games (#2983)
- **Import Queue Glass Borders** — Removed unwanted iOS/tvOS 26 liquid glass interference on custom-themed import queue rows and buttons. The gradient `strokeBorder` is now drawn as a top-level `.overlay()` rather than nested inside a `.background()`, ensuring retro borders remain visible above any system glass material. The "Select System" button uses a solid tinted background to prevent double-border artifacts (#2981)
- **Siri/Spotlight — Games Not Surfacing** — Fixed four bugs causing only save states (not games) to appear when searching in Siri/Spotlight: (1) `IndexRequestHandler.getGames(withIdentifiers:)` now extracts the MD5 from the full `org.provenance-emu.game.<MD5>` URI before querying Realm (previously comparing the full URI against the md5Hash field, never matching); (2) `PVGame.spotlightContentSet` migrated from the deprecated `itemContentType:` initializer to `contentType: .data` and now sets `displayName` in addition to `title`; (3) `SpotlightHelper.reindexAllSaveStates()` now sets `title` on save-state attribute sets (was only setting `displayName`, which Spotlight ignores for matching); (4) All main-app `Info.plist` files now declare `org.provenance-emu.game-search` and `com.provenance-emu.provenance.openMD5` in `NSUserActivityTypes` so OS-level `NSUserActivity` donations from gameplay are eligible for Siri search (#2980)
- **Siri "Search in App" Handoff** — Tapping "Search in App" from a Siri or Spotlight search result now opens the app and pre-populates the search field with the query; fixed by handling `CSQueryContinuationActionType` in both the SwiftUI lifecycle and UIKit delegate, routing the `CSSearchQueryString` through `AppState.pendingSearchQuery` to `HomeView` (#2979). Follow-up: `HomeView.onAppear` now also consumes any already-set `pendingSearchQuery` so cold-launch Siri handoffs (where the query is set before the view subscribes) correctly populate the search field (#3021)
- **Siri/Spotlight Save State Thumbnail** — Save state Spotlight entries now include the screenshot thumbnail image in search results (#2978)
- **PVGME Boot Crash** — Removed erroneously copy-pasted `PVDOSSystemResponderClient` conformance from `PVGMECore`; force-casting the bridge to a DOS responder it doesn't implement caused an immediate crash on boot (#2977)
- **No-ROMs Empty State Flicker** — `NoConsolesView` and the per-console `cloudSyncUpsell` are now guarded by `bootupStateManager.isBootupCompleted`, preventing a jarring flash of the "No Games Found" empty state while the library is still loading on launch (#2976)
- **Controller Skin Browser & Documentation in Settings** — Settings → Controller tab now includes a "Skin Browser" row (opens the community skin catalog) and a "Skin Documentation" row (opens the built-in wiki page for skins) (#2975)
- **Doom Controls** — Added missing critical input mappings for Doom (PrBoom via RetroArch): Strafe Left (L), Strafe Right (R), Weapon Prev (L2), Weapon Next (R2), and Run. Also added these buttons to the Doom on-screen control layout so they appear in the default skin. Fire and Use were already mapped; strafe, run, and weapon cycling now work correctly on touch and hardware controllers (#2974)
- **DS/3DS Skin Support Disabled** — `supportsSkins` set to `false` in melonDS and Desmume2015 cores to prevent broken display when users select skins with no dual-screen layout (#2973)
- **Controller Skin "Default" Revert** — Selecting "Default" in the skin picker now correctly clears the skin for all orientations (portrait + landscape) instead of only the currently-visible tab; fixes cases where the third-party skin remained active after reverting. The Default option is now always visible even when no third-party skins are installed. (#2972)
- **Clear Artwork Cache SF Symbol** — Replace `photo.badge.minus` (iOS 18+) with `photo.badge.xmark` (iOS 16+) so the icon renders on iOS 17 devices (#2971)
- **Settings Systems Navigation** — "Systems" in Settings now pushes as a navigation link (with back button) instead of presenting as a dismissable sheet (#2970)
- **Pause Menu Button Styling** — `menuButton()` and `menuToggleRow()` in `RetroMenuView` now use per-button semantic retrowave accent colors (green/orange/blue/purple/pink/cyan/yellow) with neon icon glow, matching the `AudioVisualizerButton` reference style. "CHEAT CODES" is always rendered at position 4 (dimmed when not supported) so the QUIT button stays at a fixed position, improving muscle-memory navigation (#2969)
- **Pause Menu Tab Bar Lock-up** — Category tab scroll bar in the pause menu intermittently stopped responding to taps; fixed by replacing `@State` + manual `DispatchQueue.asyncAfter` reset with `@GestureState`, ensuring the drag flag is always cleared even when a gesture is cancelled mid-render (#2968)
- **Controller Skin Toolbar Animation** — Toolbar items in `SystemSkinBrowserView` and `SkinCatalogBrowserView` no longer animate their coordinates during view transitions on iOS/tvOS 26 (liquid glass); fixed by consolidating toolbar blocks and suppressing layout animations via `.transaction { $0.animation = nil }` (#2967)
- **Cheat Search Crash on First Add** — Removed unsafe `@ThreadSafe` game fallback inside `realm.write`; game is now looked up strictly from the current Realm instance to prevent cross-Realm relationship crash. Added guard for empty MD5 hash to surface the error cleanly instead of crashing (#2966)
- **Boot Hang on "Loading game library"** — `initializeLibrary()` in `AppState` now wraps
  `GameImporter.initSystems()` (45 s) and `RomDatabase.reloadCache()` (30 s) in individual
  timeouts so a stalled task transitions to an error state instead of hanging forever.
  `BootstrapOrchestrator` gains a configurable per-task timeout (default 30 s) using the same
  pattern, preventing any stalled side-service task from blocking the wave scheduler (#2965)
- **HUD Touch Blocking** — Quick-action buttons (Fast Forward, Quick Save, Quick Load) now use a pass-through container view; touches in the dead-zone around the buttons are forwarded to the game instead of being consumed by the overlay (#2964)
- **PVDisabled/PVAppStoreDisabled Core Filtering** — Fixed inverted core registration logic that caused `PVDisabled` cores to be silently skipped when "Enable Unsupported Cores" was ON (and incorrectly registered when OFF). Also fixed `PVAppStoreDisabled` filtering across all UI layers so these cores are now hard-hidden in App Store builds regardless of the "unsupported cores" setting, matching the documented intent (#2962)
- **PatchCache Linux compatibility** — wrapped `CryptoKit` import in `#if canImport(CryptoKit)` with a CRC32-based fallback so `PVPatching` builds and tests run on Linux CI. (#2898)
- **Library/Gameplay Hangs (Deadlock)** — Fixed three lock-safety regressions introduced by the `NSLock` → `OSAllocatedUnfairLock` refactor (#2887) that caused random UI and gameplay freezes (#2982):
  1. `RealmSaveStateDriver.convertRealmResultsSync` was calling `PVFile.size` (file I/O + `realm.write`) inside `cacheLock.withLock`, causing priority inversion on the unfair spin-lock.
  2. `RealmSaveStateDriver.updateSaveStates` cancelled `currentConversionTask` outside `taskLock`, creating a TSan data race with concurrent callers.
  3. `PVGPUViewController.timeSinceLastDraw` / `calculatedFramesPerSecond` called `super.*` (GLKit) inside `frameTimestampsLock.withLock`, risking lock-order inversion with GLKit internals.
- **FPS label alignment** — annotated as intentionally `.right` (not mirrored) since it is anchored to the right screen edge via explicit right-edge constraints (so it does not flip in RTL). (#2874)
- **Duplicate Localization Key** — Removed duplicate `"Unknown"` key that appeared twice in all `Strings.strings` files (en, es, it, ja, nl, pt-BR, ru). (#2872)
- **Atari ST Virtual Keyboard Layout** — Added a dedicated `atariST` keyboard overlay variant with 7 rows covering F1–F10, Help, Undo, Esc, Delete, Insert, Clr/Home, Ctrl, Alt, all cursor keys, and a numeric keypad — matching the physical Atari ST layout. `DeltaSkinDefaults` now assigns this variant to `.atarist` game types instead of the generic compact layout (#2822)
- **PVCoreLoader Deadlock Risk** — Replaced `NSLock` with `OSAllocatedUnfairLock` in
  `CoreLoader` and `LibretroMetadataReader`; all bare `.lock()`/`.unlock()` pairs replaced
  with `.withLock { }` closures, eliminating the early-return deadlock path in `getCorePlists` (#2809)
- **`PVJITRequirementRegistry.reset()`** — added public `reset()` method; `CoreLoader.registerJITRequirements` was calling it but only `_resetForTesting()` existed, which would have caused a compile error. (#2793)
- **Recent Saves autosave flooding** — The "Recent Saves" section in the Game Library now shows at most one autosave per game (the most recent) by default, preventing timed/session autosaves from flooding the strip and hiding saves from other games. Manual saves are always shown. (#2789)
- **Crash-Save Safety** — `uncaughtExceptionHandler` now calls `stopEmulation()` synchronously
  (removes the `Task.detached { @MainActor }` that would never execute during crash recovery);
  save-state screenshot writes use `.atomic` option to prevent partial/corrupt files (#2766)
- **N64 Transfer Pak** — `TransferPakSupport` protocol enabling Pokémon Stadium and other
  Transfer Pak games (#2751)
- **Auto-Pause on Headphone Disconnect** — Game pauses automatically when AirPods or Bluetooth
  headphones disconnect (#2750)
- **Settings Menu Delegate** — Added fallback notifications when menuDelegate is nil (#2749)
- **GLideN64 Texture Path** — Corrected hi-res texture pack path for Mupen64Plus (#2708)
- **FCEU Famicom Mic** — Famicom controller microphone support via AVAudioEngine (#2702)
- **NSP misclassification** — Removed `.nsp` from patch format/extension lists; `.nsp` Nintendo Switch packages are game files and must not be routed to the patch importer. (#2676)
- **Manual Backup & Restore** — Manually back up and restore the full game library (#2662)
- **Configurable PSX Region** — Default region option for PSX/Mednafen core (#2661)
- **m3u Import** — Associated disc files now moved to system dir when importing m3u (#2660)
- **fMSX Button Mapping** — MSX joystick buttons now correctly map to `RETRO_DEVICE_ID_JOYPAD_*` constants; `reset` maps to `L`, `leftDiff`/`rightDiff` map to `L2`/`R2` matching the established libretro MSX mapping (#2648)
- **Cheat DB MD5 Detection** — Detects MD5 data presence (not just column existence) to
  correctly disable MD5-based lookup when DB was built without `--dat-dir` (#2641)
- **D-pad Diagonal Tokens** — Resolved D-pad diagonal tokens from directional mapping (#2640)
- **Dolphin Options** — DSP HLE/Thread, GPU Sync, Fast Disc Speed exposed as user settings;
  improved JIT detection (#2630)
- **Quick OSD Controls** — Quick Save, Quick Load, and Fast Forward buttons in the on-screen
  controller overlay (#2626)
- **App Group Container Check** — Simplified check for readable app group container (#2623)
- **Cheat System Name Mismatches** — Added `libretroCheatSystemName` mappings for MSX,
  MAME, ZX Spectrum, Atari 8-bit, and others; title tag stripping for region codes (#2617)
- **Screen Recording** — Screenshot pipeline milestones 1 & 3; Provenance Plus gated (#2613)
- **DS Dual-Screen Skins** — Phases 1-3: `supportsSkins` flag, DefaultDeltaSkin dual-screen
  layout, touch input routing for native DS cores (#2612)
- **Skin Browser Device Filter** — Fixed device filter returning 0 results (#2603)
- **Cheat Code Persistence** — Fixed `codeType` field separator, SwiftData model alignment,
  and file path for saved cheats (#2597)
- **Skin Catalog Refresh** — Updated skin catalog seed from upstream repository (#2561)
- **DosBox Graphics** — Graphics glitch resolved in native DosBox core (#2559)
- **MelonDS Color Issues** — Fixed display color calibration in MelonDS core (#2557)
- **SwiftData Models** — New `Game_Data` and related models for Realm → SwiftData migration
  Phase 1 (#2522)
- **Pause Menu CORE tab dimmed for RetroArch cores** — The CORE category header was incorrectly dimmed when only `CoreOptional` (core options) was available. The opacity condition was widened to cover all `hasCoreFeatures` cases, so RA cores always show the tab at full opacity (#pause-menu)
- **Save-state Realm thread-safety crash (`lastOpened`)** — `PVEmulatorViewController.loadSaveState(_:)` now resolves a live `PVSaveState` from the same Realm instance before writing `lastOpened`, avoiding cross-context/frozen-object writes seen in `3.3.0` crash reports.
- **Disabled-core registration/filtering correctness** — Core registration now handles `PVDisabled` consistently with the "Unsupported Cores" setting, fixing the `3.3.0` inverted condition so experimental cores are only exposed when explicitly enabled.
- **Desmume2015 remains experimental-only** — `PVDesmume2015` stays behind the Unsupported Cores gate (`PVDisabled = true`), preserving current policy while reducing unintended exposure from prior disabled-core filtering issues.
- **Libretro Cheat DB format detection** — `generate_cheatdb.py` now populates a `format` column in the `cheats` table using code-string pattern heuristics (GameShark, Game Genie, Action Replay v2, Raw AR/GS v3, etc.). `LibretroCheatEntry` exposes the new `format` field; `LibretroCheatDatabase` reads it with backward-compatibility for old bundles (no `format` column → `nil`). `CheatDatabaseEntry.deviceFormat` is now populated for libretro-sourced cheats, and the iOS/tvOS cheat search UI displays the format badge instead of the generic device name (#3067, Part of #2505)
- **GeckoCodes Cheat Lookup (GameCube/Wii)** — New `GeckoCodesLookup` actor fetches Gecko cheat codes from the RiiConnect24/GeckoCodes database using the ROM disc serial (e.g. `RMCE01`). Integrated into `searchAllCheats` automatically when a serial is available. 24h disk+memory cache. (#3069, Part of #2505)
- **GameHacking.org Cheat Lookup** — New `GameHackingOrgLookup` actor scrapes GameHacking.org via a multi-strategy HTML parser (table rows, definition lists, inline patterns). Runs concurrently with the libretro online lookup; results are merged and deduplicated. System slug mapping added via `SystemIdentifier.gameHackingOrgSlug`. Middleware proxy tracked in #3072. (#3069, Part of #2505)
- **Skin Install Deep Link** — `provenance://install-skin?url=<encoded-url>` downloads and installs a `.deltaskin`/`.manicskin` directly from the web. Powers the "Install in Provenance" button on the provenance-emu.com skin catalog (Part of #3097)
- **Save State Conversion Spike** — Research spike documents that libretro cores expose no version metadata (opaque blobs), making generic state conversion infeasible. Mednafen-based cores already handle version migration internally. Recommendations and future roadmap documented in `docs/save-state-conversion-spike.md` (#3078, Part of #2951)
- **Save State Version Mismatch Detection & UX** — All save-state launch paths (SceneCoordinator, GameLaunchingViewController, PVEmulatorViewController) now check whether the save state was created with the same core version before loading. A "Load Anyway / Cancel" alert is shown when a mismatch is detected. `SaveStateVersionChecker` provides the shared helper. `createdWithCoreVersion` is now propagated through `SaveStateRowViewModel`, `RetroSaveStateItem`, and `PVPrimitives.SaveState` (#3074, #3075, #3076, Part of #2951)
- **Thin libretro frontend (`PVThinLibretroFrontend`)** — New RetroArch-free libretro frontend in `PVCoreBridgeRetro` that depends only on `libretro.h`. Loads cores via `dlopen`/`dlsym`, handles the full libretro environment callback API (including GLES3 hw-render via IOSurface-backed FBO), and provides all 5 core callbacks without any RetroArch internal headers. Foundation for running libretro buildbot dylibs without the full RetroArch binary. Part of #2624 / #2639
- **Missing libretro env callbacks** — Added `RETRO_ENVIRONMENT_GET_VFS_INTERFACE` (45), `RETRO_ENVIRONMENT_GET_LED_INTERFACE` (46), `RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER` (40), and `RETRO_ENVIRONMENT_GET_MIDI_INTERFACE` (48) to `PVLibRetroCore.m`; all return `false` (not supported) with descriptive log messages so cores fall back gracefully instead of hitting the unsupported default. Part of #2624
- **Skin Browser: hide "unofficial" system label** — Filter chips and skin-card badges in the catalog browser no longer show the legacy `unofficial` placeholder; corrected entries for Game Gear, Master System, SG-1000, PC Engine, and MAME now display with proper system names after a catalog refresh (Part of #3097)
- **Skin Catalog: VirtualBoy system code** — `SystemIdentifier.VirtualBoy.skinCatalogSystemCode` updated from `"vb"` to `"virtualboy"` to match the remote catalog, so browsing skins from a Virtual Boy game now correctly pre-filters the catalog (Part of #3097)
- **Hatari/Atari ST: correct colors and display layout** — Removed a TOS ROM byte-patching hack (SPIKE #2823) that wrote the wrong byte order (`[0x00, 0x00, 0xFC, 0x00]` instead of big-endian `[0x00, 0xFC, 0x00, 0x00]`) for the TOS load address, corrupting the ROM and causing the pink/magenta startup palette and split/mirrored screen layout. TOS is now copied unmodified. Also corrected `hatari.cfg` resolution settings (`nMaxWidth=832`, `nMaxHeight=576`, `bAllowOverscan=FALSE`) (#2822, #2823)
- **Hatari/Atari ST: virtual mouse now moves the cursor** — `TouchTrackpadView` sends normalized 0–1 coordinates; casting these to `int16_t` for DOSBox-style `window_pos_x/y` always yielded 0. Hatari libretro uses `RETRO_DEVICE_MOUSE` (relative delta), not `RETRO_DEVICE_POINTER` (absolute window position). Added `st_ra_update_mouse_rel()` that computes per-event deltas between consecutive normalized positions, scales by 300, and writes to `mouse_rel_x/y` in the Cocoa input driver. AtariST and non-AtariST mouse paths now branch correctly in `PVRetroArchCore+Controls+DOS.m` (#2822, #2825)
- **Reset Game after failed save state load** — When loading a save state fails (e.g. PicoDrive 32X after a core update), a "Reset Game / Continue" dialog is now offered. Choosing "Reset Game" calls `core.resetEmulation()` to attempt to restore a playable state (best effort; may not fully recover all cores) instead of leaving the core in an inconsistent state (#3077, Part of #2951)
- **Keyboard Input for 11 Cores** — Physical keyboard (Bluetooth/USB) now forwarded via
  `apple_input_keyboard_event` in Dreamcast (Flycast), PSX, SNES, CDi, 3DO, Saturn, N64,
  ColecoVision, Atari 8-bit, EP128, and MAME RetroArch cores. Atari 8-bit and EP128 set
  `requiresKeyboard = YES` as keyboard-primary systems (#2841–#2851, Part of #2425)
- **TGBDual Force Monochromatic Mode** — New "Force Monochromatic Mode" console option renders GBC games in greyscale (DMG style) for both player screens via RGB565 luma conversion (#2863, Part of #60)
- **Cheat Code Library** — Online search across 1.2M cheat codes from the libretro database
  covering 44 systems (N64, SNES, PSX, GBA, and more). Enabled via features.json flag.
  Stale cache detection ensures DB is always fresh on first use (#2618, #2619, #2641, #2642)
- **RetroAchievements** — Foundation layer: `PVCheevosProtocol` + per-core conformance stubs
  wired into emulator lifecycle (#2722, #2747, #2748)
- **Virtual Keyboard & Mouse** — Full QWERTY on-screen overlay with haptics, platform-specific
  layouts (C64, ZX Spectrum, Amstrad CPC), Siri Remote passthrough on tvOS, and mouse cursor
  overlay for pointer-based computer cores (#2587–#2595, #2620–#2622)
- **Haptics System (Tier 1+2)** — `PVRumbleProtocol` in PVPrimitives (platform-agnostic, no GameController/UIKit import); `PVHapticsLocality` enum; refactored `HapticsManager` in PVCoreBridge with full `rumble(lowFrequency:highFrequency:duration:player:)` API; completed `EmulatorCoreRumbleDataSource.rumble(player:)` implementation; N64 RumblePak (Mupen64Plus) wired to CHHapticEngine via player-aware `rumbleForPlayer:` dispatch (#2742, #2743)
- **Per-Game Core Options** — MD5 wired through `valueForOption` reads; scoped reset helpers
  (`resetOptionsForGame`, `resetAllOptions`) (#2728, #2753, #2757)
- **Controller Guide** — In-app controller guide for iOS, tvOS, and on-screen controls
  (#2527–#2534)
- **Netplay Architecture** — Research document and design for native Swift/SwiftUI netplay
  system (#2544, #2558)
- **Virtual Mouse Overlay Touch Stealing** — `TouchTrackpadView.hitTest` now only captures touches within the GPU/game-screen viewport; touches on controller-skin buttons, the virtual keyboard, or any other overlay outside the game display area pass through correctly. Replaces the broken sibling-iteration approach (#2963, Part of #2575)
- **Virtual Keyboard Renders Behind Skin Buttons** — `viewDidLayoutSubviews` now calls `bringVirtualInputOverlaysToFront()` after re-stacking the skin container, keeping the keyboard, trackpad, and cursor overlay above skin buttons on every layout pass (#2963, Part of #2575)
- **Virtual Keyboard Boots Expanded** — Keyboard overlay now defaults to `isCollapsed = true`; a tappable drag-handle toggles expand/collapse. Swipe-down collapses instead of dismissing; the X button remains the only way to fully close the overlay (#2963, Part of #2575)
- **RetroArch Mouse Overlay Shown for Non-Mouse Cores** — `gameSupportsMouse` / `requiresMouse` in `PVRetroArchCoreCore` now gate on `systemIdentifier` before delegating to the ObjC bridge, preventing the virtual-mouse overlay from appearing for CPS1, MAME, and other non-mouse RetroArch systems (#2963, Part of #2575)
- **RetroArch Virtual Input Capability Detection** — `PVRetroArchCoreCore` now resolves keyboard/mouse support from the loaded `systemIdentifier`, with conservative `coreIdentifier` fallback when RetroArch is still in its generic session bucket. This prevents false-positive mouse overlays on CPS1/MAME-style cores without regressing keyboard/mouse support for RetroArch computer and keyboard-capable systems (#2963, Part of #2575)
- **Cheats & MultiDisc Pause Leak** — `onDone` closures in Cheats (tvOS + iOS) and error/cancel handlers in the disc-swap menu no longer call `setPauseEmulation(false)` or `isShowingMenu = false` directly, preventing the emulator from unpausing while the pause menu is still visible (Part of #2909)
- **Virtual Mouse Cursor Z-Order** — Mouse cursor overlay now stays above the emulator surface and all other layers by calling `bringSubviewToFront` after insertion (#2925, Part of #2575)
- **Virtual Keyboard Z-Order** — Keyboard overlay now renders above skin controller buttons; `bringSubviewToFront` called on show and after every skin change (#2926, Part of #2575)
- **TouchTrackpadView Touch Stealing** — `TouchTrackpadView` now yields to interactive sibling views (e.g. controller skin buttons) via `hitTest` override, preventing it from blocking on-screen button presses (#2924, Part of #2575)
- **RetroArch gameSupportsMouse Force-Cast** — Replaced `as!` with safe `as?` casting in `PVRetroArchCoreCore` DOS extension; non-DOS cores now correctly return `false` for `gameSupportsMouse`/`gameSupportsKeyboard` instead of crashing (#2927, Part of #2575)
- **UTType.bios Identifier** — `UTType.bios` and `UTI.bios` now use the dedicated `com.provenance.bios` identifier (previously shared `com.provenance.rom`); added `com.provenance.bios` exported type declaration to all 7 app Info.plist files (#2864 follow-up)
- **Script Permissions** — UTI generator scripts (`gen_uti.swift`, `generate_uti_declarations.py`) marked executable
- **Controller Profile Scope Resolution** — `SceneCoordinator.loadControllerProfiles` now passes `coreIdentifier` to `loadActiveProfile`, enabling game+core and system+core profile scopes to match correctly at game launch (#2879 follow-up)
- **RarExtractor Path Traversal** — Sanitize entry filenames in RAR archives to prevent `../` path traversal outside the destination directory (Part of #2663)
- **CRC Lookup Error Logging** — `PVLookup.searchROM(byCRC:)` now logs database errors via `ELOG` instead of silently swallowing them with `try?` (Part of #2663)
- **XZExtractor Memory Warning** — Log a warning when extracting XZ archives larger than 200 MB, since the entire file is loaded into memory (Part of #2663)
- **Cheats Not Showing** — Feature flag `cheatsOnlineLookup` now enabled; stale cached DB
  re-extracted when bundle zip is newer (#2619, #2618)

### Changed
- **ScalingMode renderer enabled by default** — The `scalingModeRenderer` feature flag is now enabled by default; the new `ScalingMode`-driven renderer paths (Stretch, Aspect Fill, Integer Scale, Native Resolution) are active for all users. Legacy boolean shims remain for backwards compatibility. (#3619)
- **Metal & GL Renderers** — Both `PVMetalViewController` and `PVGLViewController` now contain the new `ScalingMode`-based layout paths, activated only when the `scalingModeRenderer` feature flag is on. (#3616)
- **PVUSBManager Package.swift** — added `defaultLocalization: "en"` and `.process("Resources")` to support bundled localized strings. (#3600)
- **Audio Engine Settings (tvOS)** — replaced plain `List` with a `ZStack` + `RetroSettingsBackground`; section headers now use the retrowave pink gradient style consistent with other settings pages. (#3599)
- **PVOpenIntent deprecation** — Legacy `INIntent`-based Siri shortcut classes (`PVOpenIntent`, `PVOpenIntentHandling`, `PVOpenIntentResponse`, `PVIntentHandler`) are now marked `@available(*, deprecated)`. New Siri shortcuts use `LaunchGameIntent` from `PVAppIntents`. The legacy stubs are retained for migration continuity via `CustomIntentMigratedAppIntent`. (#3568)
- **ProvenanceCompanion entitlements** — added `com.apple.developer.system-extension.install` and `com.apple.developer.in-app-payments` to both development and App Store entitlement files. (#3567)
- **tvOS cache-purge recovery documented** — Added inline documentation explaining that bundle-derived assets (PPSSPP fonts) are automatically re-seeded on every core launch, and flagged a TODO for extending the CloudKit BIOS syncer to cover `System/` subdirectories for user-placed firmware files. (#3564)
- **RetroArch Settings UI** — The RetroArch Settings row in the app settings is now hidden when the RetroArch framework is not installed (e.g. on tvOS-Lite builds). (#3562)
- **Vulkan double-buffering** — Replace `vkQueueWaitIdle` (full-queue stall) with per-frame `VkFence` synchronisation in the thin libretro Vulkan bridge. `get_sync_index_mask` now returns 3 (double-buffer), narrowing GPU/CPU synchronisation scope and signalling double-buffer capability to cores. (#3558)
- **SaveExporter manifest** — Updated to write schema v2 manifests (rich metadata); import still accepts v1 bundles for backward compatibility. (#3557)
- **Backward-compatible import** — `SaveExporter.importSaves(from:for:)` still accepts legacy schema v1 `.zip` bundles; for those it falls back to a filesystem scan to recover saves. (#3554)
- **`gen_uti.swift`** — adds `rvz` to base ROM extensions, adds `pvsav` to save state UTI, includes all per-system UTIs in `CFBundleDocumentTypes`; all Info.plist files regenerated. (#3548)
- **Transfer Pak UI — Retrowave Theming** — Both `TransferPakConfigView` and `N64ControllerPakView` now use the Retrowave design system: dark grid background, neon-glow title, colour-coded port badges, and neon-border cards replace the plain `List` style. (#3542)
- **Mednafen Core.plist** — Added `PVCapabilities` array (highAccuracy, cdAudio, subChannelAudio, multitapSupport, lightgunSupport, cheats, retroAchievements) to surface Mednafen's capabilities in the core selector. (#3541)
- **JIT Log Clarity** — Added a WLOG on iOS 26 when `JITAuthorizer` is present but `allow-jit` entitlement is absent, directing developers to add the entitlement for reliable iOS 26 JIT. (#3539)
- **PVFeatureFlags: thread-safe synchronous reads** — Removed `@MainActor` isolation from `PVFeatureFlags`. All `isEnabled` and subscript reads are now synchronous and callable from any thread or actor without `await`. Internal state is protected by `OSAllocatedUnfairLock` (iOS/tvOS 16+) with bundled state, eliminating bare lock/unlock pairs and early-return deadlock risk. Falls back to `NSLock` on Linux. A pre-computed `[String: Bool]` cache is rebuilt atomically on config changes. `PVFeatureFlagsManager` subscribes to a `stateDidChange` Combine publisher. Callers in `PVGameLibrary` and `PVAppDelegate` updated to use `PVFeatureFlags.shared.isEnabled(_:)` directly, removing unnecessary `@MainActor` hops. (#3535)
- **Lock Safety (Option A)** — Replaced bare `lock()`/`unlock()` calls on `NSLock`/`NSCondition` in Swift call-sites with `withLock { }` (and `defer` for conditional-lock render blocks), eliminating the class of bugs where an early `return` or `guard` exit could leave a lock permanently acquired. The `NSLock`/`NSCondition` types are preserved on the `@objc` protocol boundary so ObjC core bridges remain unaffected (#3531)
- **ArtworkMatchingService** — Extracted shared artwork search fallback logic into a new actor used by both the import pipeline and the manual batch artwork matching UI, reducing duplicate code and keeping fallback behaviour consistent across the app (#3524)
- **JIT entitlement removed from App Store builds** — `com.apple.developer.kernel.allow-jit` is not permitted in App Store submissions; removed from `Provenance.entitlements`, `Provenance-AppStore.entitlements`, and `Provenance-Mini.entitlements`. App Store users continue to use debugger-attach, TrollStore, StikDebug, AltJIT, or JitStreamer paths. The JB entitlement variant retains the entitlement for sideloaded/jailbroken installs. (#3521)
- **Mupen64Plus iOS Patch Documentation** — Added `PATCHES.md` documenting all iOS/tvOS-specific modifications to the vendored Mupen64Plus source, including vidext, audio resampling, event loop stubs, and GLideN64 workarounds. Serves as a porting guide for future upstream updates (#3517)
- **Localization (l10n)** — Replaced all hardcoded `Text("literal")` calls in `SettingsSwiftUI.swift`, `CloudSyncSettingsView.swift`, `TVMediaMainView.swift`, and `RetroMenuView.swift` with `Text("key", bundle: .module)` (or `Text(String(localized:))` for PVUIBase) and corresponding entries in `Localizable.strings`. Dynamic interpolated strings use `Text(verbatim:)` to avoid accidental translation. Adds ~120 new localization keys organized under `settings.*`, `cloud_sync.*`, `tv_media.*`, and `retro_menu.*` namespaces. Part of #2869. (#3508)
- **iCade Arcade Cabinet guide** — Pairing instructions updated to clarify that 8BitDo controllers should use the matching 8BitDo profile rather than "Standard Controller" (#3488)
- **PVCoreBridgeRetro Package.swift** — Added `MoltenVK-1.2.8` xcframework as an explicit SPM dependency so MoltenVK is bundled with the app and available to libretro cores that use Vulkan hardware rendering. (#3486)
- **SwiftUI scroll performance** — Reduced scroll stutter: all `ConsoleGamesView` cell identities now consistently use `trueArtworkURL?.absoluteString ?? ""` instead of string-interpolating an optional (which produced `Optional(...)` strings and caused spurious view recreation), `TVMediaSystemsView` task identity uses the full system-identifiers list instead of count alone (fixes missed updates on same-count replacements), `TVMediaLibraryModel` ordered refresh prioritises the visible system, all loading task blocks use `defer { isLoading = false }` to guarantee loading state resets on task cancellation, and `CustomPageIndicator` centres indicators without a `ScrollView` when all fit in the viewport. (#3480)
- **Batch Artwork progress reporting** — The processing view now shows the title of the game currently being searched alongside the percentage bar (#3469)
- **`MIDIDeviceManager` multi-select API** — `selectedSourceID`/`selectedDestinationID` are now computed convenience accessors backed by `selectedSourceIDs: Set<MIDIUniqueID>` and `selectedDestinationIDs: Set<MIDIUniqueID>`. Existing single-select behaviour is preserved; `send()` now broadcasts to all selected destinations simultaneously (#3457)
- **DuckStation submodule** — Switched submodule URL from upstream `stenzek/duckstation` to the Provenance-Emu fork and updated to commit `125c3ec70fd1b4fdcf61d52500e5afad72be17e5` on `master` (as of 2026-03-20). (#3447)
- **RetroArch dylib cache: platform-aware fast-path** — `get-modules.sh` now records the active platform (`ios`/`tvos`) to `modules/active_platform.txt` after each successful extraction. On subsequent builds, if the platform, pin, and timestamp are all unchanged and ≥80% of expected dylibs are already present, extraction is skipped entirely — eliminating the unnecessary purge+re-extract cycle that occurred on every same-platform build. When switching platforms, stale dylibs (including platform-neutral ones) are removed and re-extracted with overwrite, so switching back to a previously-built platform only re-extracts from locally cached zips rather than re-downloading (#3423)
- **NetplayRoomBrowserView** — player joins now route through `NetplayJoinConfirmView` for hash confirmation before connecting; spectate taps bypass the confirm screen as ROM version is irrelevant for spectators (#3394)
- **`CompanionInputRouter`** — Keyboard and mouse events now use dedicated `sendKeyDown`/`sendKeyUp`/`sendMouseMove`/`sendMouseButton` methods and publish via a typed `AnyPublisher<CompanionKeyboardMouseEvent, Never>` stream; button/axis types imported from PVCoreBridge (#3391)
- **`CompanionButton`, `CompanionAxisID`, `CompanionInputEvent`** — Moved from `PVUI` to `PVCoreBridge` so emulator cores can use companion input types without importing the UI layer; `CompanionInputRouter` now imports these types from `PVCoreBridge` (#3389)
- **CoreCapabilities data source** — `CoreCapabilities.json` is now an enrichment/fallback layer rather than the sole source of core capability metadata; `CoreRecommendationEngine` derives base capabilities at runtime from each core's `Core.plist` and merges editorial data (summary, qualityRank, notes, and judgment-based caps like `highAccuracy`) from the JSON on top; new cores are automatically picked up without requiring a JSON edit (#3347)
- **`get-modules.sh` shebang** — Changed from `#!/bin/sh` to `#!/bin/bash` to match bash-specific arithmetic syntax already used in the script (`(( ))` expansions); added bash self-re-exec guard so Xcode build phases that call via `/bin/sh` still get the correct interpreter (#3318)
- **LightGun system detection** — replaced the static `lightGunSystems` set with a dynamic `LightGunSystemRegistry` in `PVCoreBridge`; cores that declare `RETRO_DEVICE_LIGHTGUN` in their controller-info callbacks now self-register, so new lightgun-capable systems are detected automatically without manual list maintenance (#3313)
- **GET_JIT_CAPABLE uses runtime JIT state** — libretro `RETRO_ENVIRONMENT_GET_JIT_CAPABLE` now queries `DOLJitManager.acquired` instead of hardcoding `true`, so cores receive an accurate JIT availability signal based on whether Provenance actually acquired JIT at startup (via TrollStore, debugger, AltStore, or iOS 26+ native entitlement). (#3298)
- **Haptics settings consolidated** — The scattered haptic feedback toggle and controller rumble slider are unified under a single "Haptics & Rumble" section for clarity (#3289)
- **ArtworkLoader: shared local file URL resolver** — Extracted artwork-file URL resolution (prefer `originalArtworkFile.pathOfCachedImage`, fall back to `PVMediaCache` keyed by `trueArtworkURL`) into `ArtworkLoader.resolveLocalArtworkFileURL(forGameId:)` with a process-wide memo cache; `clearLocalURLCache()` / `clearLocalURLCache(forGameId:)` are provided for invalidation after re-import (#3280)
- **Atari 2600 hardware switches** — Added Color/BW TV Type switch to complete the full console front panel (Left Diff, Right Diff, TV Type) (#3276)
- **Saturn TeamTap game database** — Combined game lists from two independent sources into a single comprehensive 100+ entry database covering Bomberman, Virtua Fighter, Street Fighter, Daytona USA, and more (#3275)
- **Controller Settings Layout** — Redesigned the controller settings screen to promote button remapping to the top, collapse the keyboard controls guide into a dedicated sub-page instead of an inline MarkdownView, and reorganise sections so connected controller actions appear before informational content. (#3263)
- **PVLogging OSLog subsystem** — replaced `Bundle.main.bundleIdentifier` with static `"com.provenance-emu.provenance"`, correct in unit tests and extension targets. (#3261)
- **Square compact tiles** — Tiles now use a strict 1:1 aspect ratio with a tighter # grid layout; more tiles fit on screen per row without sacrificing readability (#3249)
- **Dynamic libretro core capability detection** — Mouse device-type and L2/R2 trigger detection now query the core's own `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO` and `RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS` runtime data instead of hardcoded system/core identifier string matching. String-match lists are retained as fallback for cores that skip these callbacks, and are centralized into single `dispatch_once` arrays. (#3228)
- **Hatari BIOS search** — TOS candidate validation now checks file validity (size, ZIP detection, load address) before accepting, so importing a fresh TOS image will always take precedence over an old invalid one regardless of filename. (#3223)
- **DeltaSkinNativeResolution** — replaced hardcoded Swift enum with a JSON-backed registry (`system-native-resolutions.json`) so new system resolutions can be added without Swift source changes. (#3153)
- **`debug` field optional** — `info.json` no longer requires a `debug` key; missing value defaults to `false` so legacy skins import without error. (#3145)
- **`enableJIT` behavior** — Azahar and emuThreeDS now attempt to use JIT when available and automatically fall back to interpreter on devices without a JIT entitlement, so launches are safe regardless of JIT support. (#3131)
- `PVLibRetroRumbleHelper.rumble()` now uses `duration: 10.0` (continuous until `stopRumble()`) instead of hardcoded 0.15s/0.08s (#3130)
- **Skins Menu** — Reorganized the SKINS tab in the in-game menu with clear sections (Skin Selection, Button Controls, Tools), a pre-selection scope picker ("Session / This Game / System") that replaces the post-pick alert, always-visible portrait and landscape skin selectors, and immediate skin application on pick — eliminating the separate "Apply Skin and Filter" button. (#3121)
- **JIT Core Detection** — extracted the hardcoded JIT core keyword list into a new `JITCoreCapability` enum in `PVUIBase`, making it the single source of truth for JIT-relevant core identification. (#3103)
- **Skin Catalog System Names** — Moved the human-readable catalog system-code→display-name mapping out of SwiftUI views and into `SystemIdentifier+SkinCatalog.swift` (the canonical home for all system-format conversions). System badges and filter chips now show proper names like "Game Gear" and "Master System" instead of raw codes like "GAMEGEAR" / "MASTERSYSTEM". (#3100)
- **Shared `LibretroSystemInfo` layout struct** — `LibretroSystemInfo` (previously private in `LibretroMetadataReader.swift`) is now `internal` with default field values, so `PVDynamicLibretroCoreScanner` reuses it instead of maintaining a duplicate `RawLibretroSystemInfo`. Eliminates layout drift risk between the two readers. (#3080)
- **Cheat DB system mapping audit** — Completed full audit of `SYSTEM_SHORT_NAMES` in `generate_cheatdb.py`; all current libretro-database `cht/` directories are now mapped or explicitly excluded. (#3068)
- **Virtual Input State Management** — Replaced `NSNotificationCenter` toggle/show/hide notifications (`pvToggleVirtualKeyboard`, `pvShowVirtualMouse`, etc.) with a type-safe `VirtualInputState` `ObservableObject` injected via SwiftUI's environment. SwiftUI overlay buttons and UIKit OSD buttons now observe `@Published` properties directly; toggle actions are wired via closures, eliminating runtime selector mismatch risks and ensuring all observers stay in sync regardless of which code path changes overlay visibility (#3061)
- **Mednafen: Remove non-functional "Fullscreen" and "Use OpenGL" core options** — Both settings had no effect on iOS (no windowing system; Mednafen driver calls were commented out). `rendersToOpenGL` now correctly returns `NO` for the software renderer (#3024)
- **Save-State Persistence Abstraction** — Extracted Realm write for save states into
  `SaveStatePersistenceServiceProtocol` / `RomDatabase` conformance; `createNewSaveState`
  now calls the abstracted service rather than Realm directly, preparing for SwiftData
  backend swap in #2510 without touching PVUI call sites (#2888)
- **Game library section headers** — `textAlignment` changed from hardcoded `.left` to an explicit `effectiveUserInterfaceLayoutDirection` check so headers right-align in RTL locales (Arabic, Hebrew). (#2874)
- **RetroArch `user_language`** — `retroarch.cfg` is now stamped with the resolved `user_language` integer at every core launch (instead of the English default hardcoded in the bundled config), so locale changes take effect without resetting the config (#2873)
- **FCEU/NES bridge** — `DEADZONE` threshold now reads the universal deadzone setting; whichever is larger (core default 10 % or user setting) wins, preventing compound dead regions. (#2828)
- **`String.normalizedROMTitle()`** — New public utility method in `PVPrimitives` that combines disc-name stripping, parenthetical/bracketed-tag removal, and version-suffix trimming into a single canonical normalizer, replacing the previously scattered per-file cleaning logic (#2820)
- **MatchType** — Added `case bySerial(String)` so the import pipeline can record when a ROM was matched by disc serial. (#2782)
- **Mupen-NXOptions** — Transfer Pak (value 4) and Raw Data (value 5) are now selectable controller pak options in the N64 core settings (#2741)
- **Recording Settings UI** — Camera section expanded to show overlay position, size, and shape pickers when face-cam is enabled; live streaming section updated to mention upcoming direct RTMP support. (#2720)
- **Library Management UX** — Reworked library management settings labels and architecture (#2706)
- **Cheats UI** — Moved Cheat Codes to main tab in pause menu for faster access (#2608)
- **VirtualInputState lifted to tvOS** — `virtualInputState` and core capability helpers (`coreSupportsVirtualKeyboard`, `coreSupportsVirtualMouse`) moved to a new cross-platform extension (`PVEmulatorViewController+VirtualInputState.swift`) with no `#if !os(tvOS)` guard. `EmulatorWrapperView` now receives a non-nil `virtualInputState` on tvOS. Siri Remote keyboard/mouse handlers update `isKeyboardVisible` / `isMouseVisible` on activation, and `onToggleKeyboard` / `onToggleMouse` closures are wired to new `toggleSiriRemoteKeyboard()` / `toggleSiriRemoteMouse()` methods so future tvOS UI can flip input modes through the same typed interface as iOS (#3066, Part of #2575)
- **Lock modernization in PVLibrary** — Replaced all `NSLock` instances with `OSAllocatedUnfairLock`
  (iOS/tvOS 16+), eliminating bare `.lock()` / `.unlock()` pairs in favour of deadlock-safe
  `withLock { }` closures across `GameImporter`, `DirectoryWatcher`, `CloudKitRemoteApplyGuard`,
  `CloudSyncManager`, `CloudKitSubscriptionManager`, `iCloudDriveSync`,
  `CloudKitSwiftDataSyncManager`, `PVSwiftDataSchema`, and `PVSaveState` (Part of #1681, #2807)
- **Lock Patterns** — Converted bare `NSLock.lock()/unlock()` to `withLock` throughout
  audio engines and emulator VC (#2688, #2750)
- **Lock Patterns (PVUI GPU/Metal/SaveState)** — Replaced all `NSLock` bare pairs and
  `objc_sync_enter/exit` in `PVGPUViewController`, `PVMetalViewController`, `PVGLViewController`,
  and `RealmSaveStateDriver` with `OSAllocatedUnfairLock` + `withLock {}`. Eliminates deadlock
  risk from bare lock/unlock; removes ObjC runtime sync overhead on render threads (#2808, Part of #1681)
- **WhatsNew** — Moved release notes from hardcoded Swift to `whats-new.json` metadata file;
  agents can add new releases by editing JSON only

### CI / Infrastructure
- **Reproducible dylib builds** — `cores.yml` now has a `pinned_date` field that locks all RetroArch buildbot dylib downloads to a specific nightly snapshot, preventing silent upstream regressions and core-version churn across CI/developer machines (#3226)
- **Mupen64Plus XcodeGen support** — Added `project.yml` for the Mupen64Plus core package to enable Xcode project regeneration via `xcodegen generate` alongside the existing SPM `Package.swift` build path, supporting both build paths side-by-side (#2856)
- **Selective IPA Builds** — PR builds only for external contributors or opt-in via
  `build-ipa` label / `/build` comment; develop push always builds alpha release
- **AI Review Cycle Fix** — Fixed silent review gap: GITHUB_TOKEN pushes don't fire
  `pull_request` events; claude-code.yml now explicitly dispatches ai-review.yml after
  fix and rebase cycles
- **GitHub Issue Relationships** — Agent instructions updated to wire sub-issues and
  blocked-by relationships via API when creating epics and sub-tasks

### Skins
- **Data-driven native resolution registry** — Replaced hardcoded Swift enum with a JSON-backed registry so new system resolutions can be added without source changes (#3153)
- **Multi-theme skin variants** — Skins can declare named theme variants; users can select a per-skin theme persisted in UserDefaults (#3145)
- **Skin catalog display name cleanup** — System badges and filter chips now show proper names like "Game Gear" instead of raw codes (#3100)
- **Per-button haptic patterns** — Skin buttons in `info.json` can declare a `haptic` block with `style` (light/medium/heavy/soft/rigid) and `intensity` (0.0-1.0); falls back to the default feedback generator when absent (#3138, #3154)
- **Animated skin backgrounds** — Orientation representations can declare a `backgroundAnimation` block (type: frames/apng/gif, frames, fps, loops); rendered beneath the game screen and pauses when backgrounded (#3139, #3154)
- **Keyboard overlay rendering** — Skins that declare a `keyboardOverlay` config display a toggleable virtual keyboard during gameplay; supports QWERTY, compact, C64, ZX Spectrum, Amstrad CPC, and Atari ST layouts (#3142, #3154)
- **PDF size-aware skin rendering** — PDFs now rasterise at the correct logical size x screen scale for crisp HiDPI output instead of an uncapped 4096 px default (#3137, #3148)
- **Animated button sprites** — Skin buttons can declare a `states` block (Manic EMU format) with normal, pressed, and optional animated image references (#3137, #3148)

### JIT Improvements
- **Azahar / emuThreeDS automatic fallback** — Both cores reclassified to `.automaticWithFallback`; they auto-detect JIT and fall back to interpreter mode so launch is always safe (#3131)
- **Extended JIT Detection** — Detects StikDebug, TrollStore, iOS 26 native JIT, jailbreak daemons, and Simulator as JIT sources (#3113)
- **JIT Capability Matrix** — Each core declares its JIT requirement via `Core.plist`; `CoreLoader` populates a thread-safe registry at startup with no hardcoded identifier list (#3104)
- **JIT status indicator** — In-game HUD pill shows active JIT source (e.g. "JIT - AltStore"); tap for compact status alert with differentiated messaging per core (#3103, #3156)
- **JIT onboarding** — "How to Enable JIT" guide accessible from the status indicator when JIT is inactive (#3103, #3159)

### Controller Input
- **Smart Pak (Memory + Rumble)** — Virtual combo pak mode for Mupen64Plus that handles both persistent memory-pak saves and rumble simultaneously (#3110)
- **Core deadzone coordination** — New `CoreDeadzoneCapable` protocol with universal deadzone setting (0-50%), per-core coordination modes, and compatibility catalog (#2828)
- **Controller player-slot preferences** — Three assignment modes per controller: auto, preferred, and always; preferences persist and reapply on reconnect (#2773, #3111)

### OSD and Notifications
- **Audio mute warning** — Toast notification when device audio is muted or volume is zero (#3168)
- **RetroArch msg_queue bridge** — RetroArch `msg_queue` OSD messages forwarded to PVToast for all 60+ RetroArch-based cores (#3157)
- **PVToast in-game overlay** — Queue-based toast notification system with retrowave aesthetics, auto-dismiss, persistent toasts, and VoiceOver support (#2802, #3112)
- **Core OSD bridging** — PPSSPP, Dolphin, Azahar, Mednafen, DuckStation, Mupen64Plus, melonDS, and VisualBoyAdvance-M OSD messages now surface as native PVToast notifications (#2805, #3151)

### Spotlight and Siri
- **Siri Suggestions** — `NSUserActivity.isEligibleForPrediction` enables proactive game suggestions in Siri (#2980)
- **Per-game Spotlight indexing** — Games are indexed immediately on import and re-indexed when metadata or artwork updates, using proper registered Provenance UTIs (#2980, #3160)

### Save States
- **Save state browser** — Full-page "Save States" tab grouped by game with expand/collapse, screenshot thumbnails, core version info, and sorting (#2790)
- **Per-game stacked autosaves** — Autosaves are visually grouped behind a single card with "+N" badge and filmstrip timeline on long-press (#2789)
- **Save state version tracking** — Save states record the core version and identifier used to create them; version mismatch detection prompts before loading (#2952, #3081)
- **Recent Saves deduplication** — Shows at most one autosave per game by default; "Show All Auto-Saves" toggle in Settings for power users (#2789, #3107)

### Other Features
- **Save & Quit crash** — Prevented `setPauseEmulation` during core teardown (#3200)
- **Skin catalog install status** — Downloaded skins now show as installed in catalog browser (#3188)
- **Cheats crash** — Fixed Realm thread-safety crashes in pause menu cheats and save states views (#3162)
- **RetroArch msg_queue OSD bridge** — All RetroArch-based cores now surface OSD messages as native PVToast notifications (#3157)
- **Pause menu SKINS tab redesign** — Reorganized with scope picker, always-visible skin selectors, and immediate application on pick (#3121)
- **Mupen64Plus rumble** — Removed stray `register(nil)` call; added Taptic Engine fallback for touchscreen players (#3110)
- **Save state core version propagation** — Mock driver and full propagation chain for `createdWithCoreVersion` (#3102)
  ## UX Improvements
- **Skin download visibility** — Skin catalog install deep link and unofficial label fixes (#3098)
- **Netplay build flag** — `HAVE_NETPLAY` enabled in RetroArch build for 60+ cores (#3091)
- **Save state load failure** — "Reset Game" option offered when save state load fails (#3082)
- **Thin libretro frontend** — RetroArch-free libretro frontend using only `libretro.h`; foundation for running libretro buildbot dylibs without the full RetroArch binary (#3080)
- **tvOS launch crash** — Added missing `BGTaskSchedulerPermittedIdentifiers` to tvOS Info.plist (#2489)
- **Cheat code validator** — Per-format validation with hints for GameShark, Action Replay, and other formats (#2488)
- **DuckStation cheat support** — GameShark cheat codes now work in DuckStation (#2485)
- **mGBA cheat support** — Cheat codes wired up for the mGBA core (#2484)
- **CPDI bootstrap system** — Refactored app startup into structured bootstrap with Firebase Crashlytics config fix (#2463)
- **DosBox keyboard and mouse mapping** — Keyboard and mouse input support for DosBox core (#2457)
- **PVFeatureFlags remote fetching** — Remote feature flag fetching with retry, caching, and fallback (#2454)
- **Configurable CRT shader parameters** — User-adjustable CRT shader settings (#2451)
  ## Bug Fixes
- **Inline core picker with save counts** — Thin wrapper swap in PVCoreFactory with inline core picker showing save state counts per core
- **Cheat code auto-lookup** — Bundled cheat database with online lookup from GameHacking.org and GeckoCodes for GC/Wii (#2455, #3073)
- **BPS/UPS patcher tests** — Comprehensive unit test coverage for ROM patching (#2898, #3106)
- **Save state crashes** — Fixed FBNeo, MAME, and other RetroArch core save state crashes (#1d33338)
- **Cheats crash on toggle** — Fixed crash when toggling cheats from the pause menu (#0afafa4)
- **Skin button transparency** — GameGear and legacy handheld skin screen fill now uses correct aspect ratios instead of leaving black bars (#3134, #3149)
- **Screen filter JSON decoding** — CRT, scanline, sepia, and blur filters from skin `info.json` now apply at runtime instead of always being nil (#3135, #3150)
- **Boot performance** — Core plist scan results cached to disk; core scanner made non-blocking; skin scan deferred to first use; Mach-O fast-path probe for libretro metadata (#3015, #3109, da9fef2, d5a0e61, 265ef4e, d00841d)
- **Hatari TOS validation** — Multiple fixes for TOS boot: correct directory paths, byte-swap repair, ACSI boot option, per-core options file (#3112, #3127, #3144, #3152)
- **Mupen64Plus bootup hang** — Fixed pause, rumble pak default, and bootup hang (#9bd8ee3)
- **On-screen controller touch routing** — Fixed PassThroughView absorbing all touches and overlay blocking game button input (#3117, #3124, #3126, 7bf3f39)
- **Pause menu button layout stability** — CORE tab and save-state buttons now rendered at fixed positions; unsupported items dimmed instead of removed (#2969, #3101)
- **VecX hardware rendering** — Fixed blank square in hardware rendering mode by returning correct HW render dimensions for `screenRect` (#2984, #3123, #3116)
- **Spotlight content types** — Removed invalid `contentType` strings that caused Spotlight to reject game entries (#2980, #3105)
- **Save state double prompt** — Prevented double version-mismatch prompt on launch (#949ab0c)
- **HUD overlay positioning** — Moved HUD controls to top strip so they never overlap skin buttons (#859579, 7f6ce09)
- **PrBoom button mapping** — Corrected Doom button mapping and shoulder button order (#fe0e0d6)
- **CrabEMU resolution** — Fixed bad resolution when nil at boot (#6f2f3f4)
- **Save state Realm crash** — Fixed freeze() inside uncommitted write transaction; moved serialization after commit (#3181, #3193)
- **Audio loop on pause** — Flush ring buffer when pausing to prevent stale audio looping (#3183, #3195)
- **HomeView flickering** — Replaced 5 `@ObservedResults` with background ViewModel to stop cascading re-renders (#3184, #3196)
- **Atari800 joystick crash** — Fixed infinite recursion in `didRelease:` and `didMoveJoystick:` (#3182, #3194)
- **Shoulder button order** — L2/R2 now on outer edge matching real controller layout (#3180, #3192)
- **JIT indicator** — Moved to bottom edge with auto-hide; only shows for cores that need JIT (#3186, #3198)
- **Skin activation** — "Set as Active Skin" now activates directly instead of navigating to browser (#3189, #3200)
- **Shader parameters in pause menu** — CRT shader parameters adjustable from the filter picker (#3185, #3197)
- **Save state browser** — Added Realm refresh so newly created states appear immediately
- **CI submodule fixes** — Fixed ZipArchive, desmume2015, NP2kai submodule checkout failures
- **Companion Controller framework** — iOS companion device overlay infrastructure (#2697, #3190)
  ## Core Updates
- **Atari ST comprehensive improvements** — Video, mouse input, ST keyboard layout, TOS version handling, and boot reliability across multiple PRs (#3094, #3112, #3127, #3144, #3152)
- **Cheat system short name audit** — Complete audit of cheat DB system mappings with forward-looking mappings for future systems (#3068, #3108)
- **Inline core picker with save counts** — Core selection now shows save state counts per core for informed switching
- **Contentless core setup guides** — Setup guidance for cores that need BIOS or other files before use
- **Beta builds install guide** — Sideload feed and installation guidance for beta testers (#b94e2248)
- **RetroMenuView button styling** — Improved visual hierarchy in the retro-style pause menu (#2969, #3121)
- **Sub-task progress display** — Boot sequence now shows sub-task progress with fix for Realm timeout scope (#546d3ee)
- **Screenshot browser** — New screenshot browser in pause menu with save-state UX improvements (#5d6ac25)
  ## CI / Infrastructure
- **Copilot + Claude review loop** — Agent context and auto-fix triggers for PR reviews (#b94e2248)
- **CI optimization** — Concurrency groups, alpha releases, agent PR smoke builds (#7ca84d3, #95801f8)
- **SPM validation script** — Agent validation CI for standalone module builds (#dcedb27)

## [3.0.6] - 2025-03-16

Special thanks to all contributors and testers who helped make this release possible.

### Added
- Core Options Menu for RetroArch cores
- Enhanced search functionality with auto-hiding search bars
- Improved disc selection menu for multi-disc games
- Support for custom textures in 3DS games
- RAR archive support in file enumeration

### Improved
- Major 3DS performance optimizations:
  - NEON-optimized shader interpreter
  - Enhanced Vulkan rendering pipeline
  - Audio processing improvements with NEON optimizations
  - Camera, gyro, and microphone support
  - Async presentation for smoother gameplay
- Updated Mednafen to version 1.32.1
- Improved RetroArch cores with better Vulkan support
- Enhanced continues section with optimized paging
- Threaded rendering and realtime improvements
- Fixed CPU deadlock issues

### Fixed
- Fixed search functionality in Home and Console views
- Fixed tvOS build issues
- Resolved logging issues
- Fixed immediate import on conflict resolution
- Various crash fixes and stability improvements

## [3.0.5] - 2025-03-11

Special thanks to @mrjschulte, @yippeeeyay, and @pabloarista for their contributions to this release.

### Added
- Core Options Menu for RetroArch cores
- Custom textures support for 3DS games
- Onscreen controls toggle button
- RetroArch support for FFMPEG, CoreMIDI, CoreLocation, and AVFoundation camera drivers
- Support for additional systems: CPS1, CPS2, CPS3, Doom, Quake, Quake2
- Additional RetroArch cores: melondsds, desmume, mesen, mesen-s
- ROM deletion confirmation dialog
- Contributors list in settings

### Improved
- Metal performance optimizations
- Realm threading and performance
- Artwork loading and caching system
- Save state management and performance
- SwiftUI components with reduced redraws
- Native scale enabled by default
- Continues section with optimized paging
- Threaded rendering for better performance
- Marquee text animation and performance
- Protocol-oriented refactoring of EmulatorVC

### Fixed
- Fixed tvOS build issues
- Fixed crash in core close operations
- Fixed save state loading and renaming
- Fixed threading crashes in PVFile MD5 cache
- Fixed Metal shader issues (megaTron, ulTron)
- Fixed rotation misalignment in Metal view controller
- Fixed Atari core MFi controllers without L3/R3 buttons
- Fixed multi-disc/track file deletion
- Fixed artwork search and database lookups for various systems

## [3.0.4] - 2025-02-08

Special thanks to all contributors and testers who helped make this release possible.

### Added
- Core Options Menu for RetroArch cores
- Audio switch monitoring
- Protocol-oriented refactoring of EmulatorVC
- Additional UTI types for ROMs

### Improved
- Game cells alignment by title
- Improved threading for database operations
- Refactored emulator state into observed actor
- Parallelized bootup of PVSystems for faster startup

### Fixed
- Fixed crash in core close operations
- Fixed Metal shader issues (megaTron, ulTron)
- Fixed rotation misalignment in Metal view controller
- Fixed nil texture crash in PVMetalVC
- Fixed tvOS WebServer UX flow
- Fixed artwork search for various systems

## [3.0.3] - 2025-01-23

### Added
- Added Crashalytics for better crash reporting
- Added support for ZIP format BIOS files
- Added system name display on custom selection screen

### Improved
- Improved Metal rendering for various cores
- Improved EmuThree settings and options
- Updated core loading system to use plists
- Improved BIOS directory handling and caching

### Fixed
- Fixed Intellivision button layout
- Fixed Vectrex rendering options
- Fixed Metal color rendering for Jaguar and other systems
- Fixed missing Molten framework for Catalyst builds
- Removed broken Opera core from build
- Fixed various core configuration issues

## [3.0.2] - 2025-01-16

### Added
- Added Sentry crash reporting SDK
- Added BIOS scanner with support for subdirectories
- Added Discord and Twitter links in App Store version

### Improved
- Improved EmuThree core options with better restart handling
- Improved settings UI navigation style
- Enhanced BIOS scanning and UI for force scanning

### Fixed
- Fixed bootup locking from cache async calls
- Fixed potential TopShelf crash
- Fixed potential nil crash on boot
- Fixed SystemPlist entry for NeoGeo.zip
- Fixed Saturn controls using RetroArch controls
- Updated Jaguar core for buttons 1-8
- Fixed PVFile crash on duplicate write

## [3.0.1] - 2025-01-07

### Added
- Added WhatsNewKit for displaying new features
- Added PVJit module to fix missing module issues

### Improved
- Improved EmuThree core options and settings
- Improved theme system with better UI updates
- Enhanced navigation bar theming
- Improved RetroArch configuration paths on tvOS

### Fixed
- Fixed crash in save state menu
- Fixed theme changes not updating navigation bar
- Fixed Realm bootup crash on iOS 16
- Fixed tvOS build issues
- Fixed potential crash in PVFile size caching
- Fixed Vectrex compilation without GLES
- Fixed RetroArch config paths on tvOS
- Fixed controller issues with Atari 5200 and Nintendo 64

## [2.2.0] - 2022-12-02

Super special thanks to @Carter1190 @dnicolson @ianclawson @mrjschulte @stuartcarnie for providing pull requests.
Special thanks for all the Patreon and Discord members that provided testing feedback and support.

### Added

- Light/Dark theme
- tvOS artwork options
- Saturn Core options
- Option for onscreen joystick with keyboard on/off, or never.
- add build.yml for github actions
- stella: joystick deadzone

### Fixed

- tvOS various layout, styling improvements
- fixes #1915 joystick layout busted
- BoxArt fix nil crash
- add sfc extension
- Catalyst, fix crash on game load
- catalyst: remove broken bliss
- fixes #1973 incorrect paths in xcworkspace
- fixes #1991 Fixes mupen plugin paths
- fixes #1997 update ios launch storyboard
- fixes #2010 remove unused codesign settings
- disable broken contributors.yml
- fix various tvos targets with wrong target platfrm
- fixes #1814 Use documents for image cache
- Fixes #1814, lib deletion and icloud fixes
- fixes #1986 adds ways to press start in SS
- fixes #1986 Saturn start MFi, I think.
- fixes #2019 Mednafen SNES A/B swap
- fixes #2026 joyPad move works, clear BG
- fixes #2027 importer double run and deleting
- fix archive step
- fix artwork download
- stella: don't crash on 2nd load
- stella: updated and cheats,save support
- closes #1765 map dualsense home to pause on saturn
- closes #1765 map dualsense home to pause on saturn
- closes #1888 fix n64 scaling
- closes #1903 tvos build broken
- conflicts manager add delete option
### Updated

- Min target iOS 13 all around
- More localised strings and xib's
- SwiftUI additions and fixes
### PRs

- Merge branch 'feature/dos-box' into develop
- Merge branch 'remove-unneeded-styling' into develop
- Merge branch 'remove-unneeded-table-generics' into develop
- Merge pull request #1919 from Provenance-Emu/feature/dos-box
- Merge pull request #1995 from dnicolson/style-fixes
- Merge pull request #2006 from Provenance-Emu/pullrequests/dnicolson/general-cleanup
- Merge pull request #2015 from dnicolson/fix-constraint-warnings
- Merge pull request #2016 from dnicolson/use-tvalertcontroller
- Merge pull request #2017 from dnicolson/remove-unneeded-styling
- Merge pull request #2018 from dnicolson/use-system-background-for-settings
- Merge pull request #2025 from Provenance-Emu/largeGameArt-Support
- Merge pull request #2028 from dnicolson/add-light-theme
- Merge pull request #2029 from Provenance-Emu/tvOS-GameInfo-Tweaks
- Merge pull request #2030 from Provenance-Emu/feature/JoystickFixes
- Merge pull request #2033 from dnicolson/fix-library-bottom-separators
- Merge pull request #2036 from Provenance-Emu/feature/gh_build_action
- Merge pull request #2038 from Provenance-Emu/mrjschulte_section_header_fix_tvOS

### GitLog

- Add theme switcher
- Add ThemeOptions enum
- Adjust cell height as needed
- AppDelegate refactor code, improve URL open
- AppDelegate start of save open
- azure 14.1
- azure pipeline macos-12
- azure turn off xcode pretty
- azure update to newer xcode/macos
- cdx4 fix submodule
- cicd remove UIBrackgroundModes processing
- citra: combine platforms
- core 4do updates to fix tvos
- cores framework don't embed
- cores table view, hide unsupported cores unless on
- Cores, add .core.name to ones that didn't
- cxd4 fix submodule bs
- delete dup schemes, new shaders, blissemu framewk
- delete old tvos schemes and rename others
- desmume2015 readd and fix debug
- duckstation: fix some build stuff
- entitlements remove ones that break xc cloud
- Extend navigation bar
- Extensions placeholders for new ones
- fastlane update
- Fix 4do build and almost works, bad gfx freedo
- Fix and update Marketing Version 2.1.2
- Fix button height constraint warning
- fix catalyst builds
- Fix cell background color
- Fix cell font sizes
- Fix controller selection table cell focus
- Fix entitlement paths for 2 extions
- Fix extensions in build
- Fix iCade controller cell background
- Fix iCloud, Spotlight entitlement, re-import path
- fix ios/tvos build
- Fix library options cell background color
- Fix logs crash
- fix macos/catalyst build and export
- Fix navigation bar tint color
- Fix PVFile iCloud paths incorrect
- Fix slider cell text alignment
- fix some warnings and self capture
- Fix stack spacing constraint warning
- fix submodules
- Fix SwiftUI crash on iOS 16
- fix tvos availability
- Fix tvOS build
- flycast builds
- flycast, fbneo, dolphin fix some build stuff
- Frameworks combined into single multi-platform!
- fuse fix some build stuff
- game view cell, hide delete text on start
- GameLibVC fix potential crash
- gba remove driverkit
- gcdweb fix QOS
- genesis: reflector2static libs, submodule 4 upstrm
- gh action fix xcodebuild command
- gh action macos-12
- git insists on touching these submodules
- github action build test
- GitHub actions disable broken ones
- gitignore .xcarchive
- Hide unsupported cores from conflicts unless on
- iCloud containers fix thread issue/warning
- icloud sync catch exception
- Improve how theme is set
- Info.plist add ITSAppUsesNonExemptEncryption
- Info.plist fix xcode cloud issues
- Install the CodeSee workflow. Learn more at https://docs.codesee.io
- intellivision respond protocol fixes
- ios fix gliden compile
- iOS settings menu replace (i) with >
- jaguar: core update video fixes
- Launch screen add brazil locale
- libretro build flags update
- Make web server alerts consistent
- mednafen fix targeted device families
- mednafen refactor controls to catagory
- mednafen: refactor compiler flags to xcconfig
- mednafen: remove broken options,controller reorder
- melon DLOG for nslog
- melonds build flags update
- MetalVC minor catalyst chagnes
- mu fixed embedded framework
- mupen audio on/off callbacks
- mupen speed option
- mupen: fix crash on load
- mupen: hi res off by default, fix catalyst
- n64 controller fix warning
- obscure cores various build fixes
- On screen controller adjustments
- option lcd filter
- Patreon features
- pcsx reamred builds
- pcsx submodule
- pcsx, fix submodule again
- PCSXRearmed added to build
- play: builds with gfx and audio callbacks
- play: fix build
- play: fix release build
- Prevent bottom separators from disappearing
- project remove nil file
- ps2: add bios info
- PVGenesis -Os
- PVLIBRARY fix copy/embed
- PVLogVC fix tvOS color error
- Reduce width of log buttons
- Remove Bliss, its breaking CI
- remove broken cores from build
- Remove cancel action from alert
- Remove cell background color
- remove duckstation from build
- Remove forced dark interface style
- Remove iOS 11 conditional
- Remove iOS 13 conditionals
- remove old vibrate for xccloud
- Remove PVRadioOptionRow and PVRadioOptionCell
- Remove red cell background
- Remove redundant style
- Remove SettingsTableView class
- Remove styles in favor of defaults
- Remove SystemSettingsCell
- Remove SystemSettingsHeaderCell
- Remove unimplimented extensions from app target
- Remove unneeded code
- Remove unneeded guard clause
- Remove unneeded ifdef
- Remove unneeded QuickTableView generics (#2031)
- Remove unneeded section header styles
- Remove unneeded styling
- Remove unused code
- Remove unused file
- remove unused macos xib
- Remove unused styling
- Remove unused variable
- Remove VecXGL submodule
- rename o2em and jaguar cores to PV..
- Replace remaining com.provenance-emu with org
- Replace sync network with async for artwork
- Replace UIWebView with WKWebView
- retro: add bliss, 4do, some organization
- retro: add game music and vicx
- retro: all the cores
- retro: fix build missing #endif
- retro: fix framework dyload
- retro: fix tvos bitcode
- retro: gme builds and links
- retro: gme fix tvos build
- retro: gme loads
- retro: gme plays
- retro: ios biulds
- retro: metal video doesn't crash but still odd
- retro: potator loads, fix static rom buffer copy
- retro: remove VecXGL for libretro version
- retro: software fb callback and pixl fmt fixes
- retro: split core into categories, add cores
- retro: the final cores! for now
- retro: tvOS builds
- retro: update core submodules
- retro: video callback pitchshift work
- rice: use newer branch, fixes catalyst
- Set library header background
- Set navigation bar style only for game library
- Set overrideUserInterfaceStyle
- Set settings button font only on tvOS
- Settings webDav always tvOS and sim
- Settings, disable swiftUI in iOS 13
- shaders add support for lcd/crt screen option
- Simplify code
- Single frameworks, catalyst, macos
- snes n64 fix a/b and deadzone
- snesticle builds
- snesticle: remove from app, needs work
- snesticle: tvos, add to ios build
- spotlight scheme update depends
- stella module fix
- stella snapshot
- stella xcconfig
- stella: delete duplicate files
- stella: use a submodule and static libs
- submodules: Single framework, macos
- swap experimentalCores option with unsupported
- swiftpm updates
- swiftpm update depends
- SwiftUI flow — make landing screen the console carousel if any consoles available, reduce side menu open width
- systems.plist update ext and bios for new cores
- tic80 add submodule
- tic80 submodule
- tvos add missing enums
- tvOS don't copy glsl to docs
- tvOS fix duplicate symbols in mupen/gliden
- tvOS Fix jaguar compile
- tvOS fix missing target warnings, introspect err
- tvOS hide metadata edit behind #if TVOS_HAS_EDIT
- tweak previous commit
- update bliss
- Update bliss submodule, 2 targets
- Update deployment targets
- Update MednafenGameCore.mm
- Update PVGameLibrarySectionHeaderView.swift
- Update PVGameLibraryViewController.swift
- Update PVGameLibraryViewController.swift
- Update PVGameLibraryViewController.swift
- Update PVGameLibraryViewController+CollectionView.swift
- Update PVGameLibraryViewController+CollectionView.swift
- Update PVGameMoreInfoViewController.swift
- Update PVMetalViewController.m
- Update PVSettingsModel.swift
- Update PVSettingsModel.swift
- Update realm schema version
- Update rebase.yml
- Update save game alert
- update some core repos
- Update stella to upstream
- Update styles on theme change
- Update various cores and ios target includes
- Use different yellow that works with both themes
- Use ellipsis
- Use system alert system background color
- Use system background color for game library
- Use system background for game info
- Use system background for settings
- Use system color for "Game library empty"
- Use system colors for file logs
- Use system colors for live log
- Use system colors for save states
- Use system gear image
- Use system sort libray options background colors
- Use theme for section header style
- Use TVAlertController everywhere
- uupdate cores ios version and target platforms
- WebServer fix hardcoded 8080
- webserver fix queue QOS warning
- webserver nslog to logger
- whitespace
- xcodebuild action remove cache clear
- yabause: update c flags
- Add .all-contributorsrc config file
- add a working project for dosbox
- Add dosbox-pure
- Add fceux netplay server
- add framework targets for cores and expermnt cores
- add libretro framework
- add libretro target to framework
- beetle: it runs but no video
- bridging-header remove superfulous import availaiblity
- bump version to 2.1.1
- Cancel as localized string
- clean up window rootViewController assignment for SwiftUI path
- desmume use prov upstream
- desume builds with libretro
- dosbox add libretro library
- dosbox builds
- dosbox technically it builds
- dosbox: av tweaks
- dosbox: link correclty
- dosbox: some overwrides
- ds: add controls callbacks
- ds: melon and extensions tweaks
- duckstation: rebase
- Emu VC defer gesture .bottom to b,l,r
- Enable MTL fast math support
- ep128: fix c++ issue
- fbneo minor shit
- fceux add upstream submodule
- fceux update core to 2.6.2
- filters: add simple crt demo
- filters: metal filter menu
- First version of movable buttons
- Fix broken wiki link, minor UX improvements
- fix build
- fix compile
- fix gles shaders and add other framework core targetrs
- fix some tvos build issues
- fixes #1849 tgbdual crash on ios fixed
- fuck git sometimes
- fucking around with app clips and associated domai
- fxeux swift to 2.2.3
- gameimporter hacky override 4 updated gamefaq url
- gameimporter throw less by pre-checking
- gitignore dsstore
- gitignore newrelic file
- glescore: did i loop wrong?
- hacks: placeholder 4 volumebutton and carplay hax
- include assets
- iOS 13 target in xcconfig
- jag: add CD library support and loading
- jaguar: update core for memory fix
- libretro refactor and add files
- make a libretro and it builds
- mednafen: fix a build issue with switch statement
- Merge branch 'feature/dos-box' into develop
- Merge branch 'release/2.1.0' into develop
- Merge pull request #1761 from ianclawson/ian/swiftui-menu-path
- Merge pull request #1764 from Provenance-Emu/feature/MoveableButtons
- Merge pull request #1810 from Provenance-Emu/feature/fceuxUpdate
- Merge pull request #1900 from Provenance-Emu/feature/1888_N64_19x9
- Merge pull request #1901 from Provenance-Emu/feature/snes9xControllerFix
- Merge pull request #1909 from rrroyal/develop
- Merge pull request #1926 from Provenance-Emu/feature/JoystickLayoutFix
- Merge pull request #1933 from Provenance-Emu/feature/filtermanager
- movebuttons: fix some buttons from resetting
- mupen add more core options
- mupen fix type-o in option
- mupenx: core compile updates
- NOTICKET core options enum default fixed
- NOTICKET Options tableview popover rect fixed
- options onscreen joypad as beta setting
- package resolve update
- pblibretro base code
- prov: yabause hacks
- pvdosbox use retro core as base
- pvgenesis m68kcpu.c compiler flags
- pvretrocore start point
- refs #1765 fix non-dualshock start in  Saturn
- refs #1797 refactor fceux into static libs
- refs #1915 fixes psx start button layout
- remove appclip from build
- reto: video init code
- retro add more files
- retro:  start to add mupenNX
- retro: a bunch of fixes, build flag updates, controllers, gles core
- retro: add a beetle core cause y not
- retro: add hatari build
- retro: Add melonDS start of core
- retro: add minivmac core
- retro: add Mupen64Plus-NX
- retro: add potator cause y not
- retro: add potator core
- retro: add proper projects for test forks
- retro: add submodules and blank projects for more
- retro: add vmac and fix other stuff
- retro: add Yabause core
- retro: beetle builds?!
- retro: beetlepsx builds
- retro: better code to find cores
- retro: better wrapper
- retro: callbacks set
- retro: CORES OPEN MSX!
- retro: desmeme2015 prov patches
- retro: desmume, dosbox, neo, msx, genesis udates
- retro: double buffer and real screen dimensions
- retro: fbneo builds
- retro: fbneo builds shockingly
- retro: fix embedding framework
- retro: fix loading gles cores
- retro: fix paths, desumeme runs now
- retro: fix release builds
- retro: fix tvos build with melon,msx
- retro: i more linking stuff, fbneo start
- retro: kind of loads
- retro: more cores
- retro: more fb neo
- retro: more linking, libretro.h into build
- retro: mupen-nx has proper build, though errors
- retro: pbbeetle additions
- retro: pcsx rearmed some progress
- retro: remove broken beetle from build
- retro: reset targets, builds but empty
- retro: schemes for ep128, msx
- retro: stuff almost runs
- retro: submodules update
- retro: supervision works with new callbacks
- retro: tvos builds, refactor cores into frameworks
- retro: various fixes, tvos builds
- retro: vecrex
- retro: video work
- retro: yabause update
- shader manager
- shaders metal are wrong
- swiftlint corrections
- SwiftUI menu design revamp - bulk add all changes from fubar'ed branch
- systems.plist add DOS
- systems.plist fill in all openvgdb system ids
- systems.plist psx add compresed formats
- test adding dos to build
- Themes.swift cleanup some re-used code
- tvOS add debug setting to use themes
- tvOS fix swift ui build
- Update Atari8bit bios sizes
- Update blit_ps.metal
- Update PVSearchViewController.swift
- Update PVSNESEmulatorCore.mm
- xcconfig: GLES_SILENCE_DEPRECATION=1
- yabause: fix release build

## [2.1.1] - 2022-06-15

### Added

- Controls: PSX on-screen joystick can be disabled in settings. No longer shows when controller is connected
- Swift UI beta for tvOS
- tvOS theme support
- Metal shader 200% speedup 👉 @mrjschulte
- early dosbox testing code (no running yet)

### Fixed

- tgbdual crash on ios fixed

### Updated

- fceux update core to 2.6.2

## [2.1.0] - 2022-02-14

Special thanks to contributors on this release;
👉 @mrjschulte
👉 @ToddLa
👉 @ac90b671
👉 @nenge123
👉 @david.nicolson
👉 @davidmuzi
👉 @amoorecodes

### Added

- Controllers:
  - On Screen Joystick Controls for N64 and PSX
  - APIs for keyboard, mouse, rumble, on-screen joystick. (coming in future release)
  - Apple TV: Support new Siri remote (MicroGamepad and DirectionalGamepad)
- Code Signing is now managed with an XCConfig file. See `CodeSigning.xcconfig.example` for instructions. (Only applies to developers/xcode source installs)
- Enumeration type menu options UI
- FPS debug label now includes total CPU and Memory usage.
- GameBoy Advanced cheat code support
- Jaguar options exposed
- Long press a ROM for quick access to Core Options
- Mednafen
  - many more sub-core options added
  - SNESFaust 1 frame render ahead option (on by default. VERY SNAPPY!)
- Metal Shaders (CRT, LCD, etc.)
- N64:
  - mupen/gliden/rice options exposed
  - Dual Shock 4 touchpad as pause
  - option for Dual Joysticks on DualShock4 as dual controllers (allows Goldeneye dual controller joystick layout from 1 physical dualshock)
- Native Metal renderer option [WIP/Buggy]
- per-game option overrides
- radio selection options
- Sega Saturn Mutli-CD support
- Swift UI/UIKit optional code paths at app start (SwiftUI currernly empty, for easier development in future)
- VirtualBoy side by side mode (for 3D tv's with Side by Side mode. Google Cardboard coming later)
- XCode will present a warning message if it detects a device build but CodeSigning.xcconfig isn't setup.
- Localizations (Only Partially translated WIP)
  - NSLocalizedString for most strings in main app source
  - Chinese Simplified by  @nenge123
  - Spanish
  - Russian by  @amoorecodes
  - Dutch by @mrjschulte
  - Portuguese (Brazil) by  Stéfano Santos

### Improved

- Mupen:
  - wrapper code organized, refactored
  - faster controller polling, various other code speedup tweaks.
  - mupen llvm optimization flags improved (was incorrectly -O2, now -Os)
- On-Screen Controls
  - N64 layout improved
  - PSX layout improved
- Branch prediction compiler hints for tight loops, possibly faster.
- Catalyst: All cores build now for Intel and M1.
- check if file exists before attempt to delete, reduces superfluous throws trapping in the debugger
- Converted more app code from ObjC to Swift
- Dark Mode UI always on, fixes some color issues
- Fix some excessive thread blocks
- Hide/Show systems chevron location tweaks
- If multiple cores support a system, cores are listed in recommended order.
- Improved logo/header bar for iOS & tvOS
- Jaguar button layout tweaks
- Mark various ObjC classes `objc_direct_members`. Should improve Swift to ObjC calls bypassing dynamic dispatch for function pointers (in theory)
- Replace all spinlocks with atomic operations for better thread performance
- replaced some sloppy force unwraps with proper nil checks and logging
- Shaders are copied to Documents at load and read from thereafter. This allows locally editing / developing shaders without rebuilding.

### Fixed

- Conflicts better detected
- tvOS top buttons sometimes couldn't be selected
- Faster compile times (improved header imports, compiler flags)
- Fixed some improper retain cycles in ObjC blocks
- Fixed rare audio engine nil reference race condition crash
- Cheat entry UI fixes

### Updated

- N64:
  - Swap left and right triggers to L:Start R:Z Button from other way around prior
  - mupen cxd4 plugin to latest upstream version
  - mupen rsp-hle plugin to latest upstream version
- Updated Swift Packages (RxRealm, Realm, Cocoalumberjack)
- Improved tvOS UI (top buttons, search, icons, more consistent styling)

### Removed

- Removed SteamController support (no one used it and the code caused too many compilations, plus steam controllers are kind of trash, sorry.)

## [2.0.4] - 2021-12-24

### Fixed

- #1651 Fixed N64 / Mupen blank video @mrjschulte
- #1652 Update TVL in crt_fragment.glsl to reduce moirée effects at UHD @mrjschulte
- #1654 Remove absolute path to file from .xcodeproj @davidmuzi
- mupen replace consts with define, whole module for archive builds @JoeMatt

## [2.0.3] - 2021-12-22

### Added

- Odyssey2 core
- Mac Catalyst early support (M1 and Intel) (not for public use yet)
- SNES FAST and PCE FAST core options for Mednafen
- watch os demo target
- Odyssey add and use od2 extension
- Add odyssey to build
- Tentative support for VecX and CrabEMU
- macOS testing catalyst
- Add nitotv methods for tvOS
- Override openURL for tvOS
- Add Patron link to readme
- Add Desmume2015 core
- DuckStation initial commit
- Cores add plist feature to ignore
- Add PPSSPP Source
- Play! PS2 initial commit
- Add Dolphin project
- Add GameCube support classes and metadata (WIP)
- Add flycast core (WIP)
- Add a Chinese loading example
- Add localized strings file and example

### Fixed

- #1621 GBC palette options crashed gambatte
- #1414 smarter exceptions in PVSystem
- #1645 PCE Audio setting tweaks to match real hardware
- #1637 Cheats label name cut off fixed
- #1649 two PCE module audio related setting tweaks that enable Provenance's PCE Audio output to match much closer to the measured MDFourier output of a real system, as tested with @artemio from the MDFourier project.
- Fixed rare crash in OERingBuffer
- Cores that don't support saves no loner display save actions in menu
- OpenVGDB Update (fixes artwork and metadata not loading)
- Fixed strong self refs in some classes, closures
- Fixed MD5 mismatch log message
- Add back a crash logger #1605 add crash logger and fix minor build settings
- switch jaguar to upstream branch
- core option as bool for objc
- RxDataSources switch to SPM package
- Fix some implicit self block refs
- closes Conflicts not reported #1601 conflicts reporting correctly
- fixes Gambatte core immediately crashes #1621 GBC palette options crashed gambatte
- refs After Resolving an "Import Conflict", subsequent imports no longer work #1414 smarter expecptions in PVSystem
- refs WebDav Server Always-On broken #822 add small main queue delay 4webdav start
- tvOS add multi micro gamepad to infoplist
- tvOS fix target order setting error
- Fix minor iCloud warning
- Fix random warnings
- Fix force unwraps in appdeleagte
- Fix finicky tvOS schemes
- Fix whole/single compilation for rel/arch targets
- Mednafen, proper ELOG in swift
- Mednafen remove dead file ref
- RxSwift fix some threading issues
Remove flycast from build
i dunno xcode beta stuff
package.resolved altkit update
Localization, start basic support
Remove base localization
- Fix GL_SILENCE_DEPRECATION=1
- Fix PS2 stealing PS1 bios
- Fix gamecube stealing n64 roms
- add nintendo DS enums
- Replace QuickTableViewController SPM with source
- PicoDrive fix naming
- altkit not in catalyst
- Remove reicast from build
- Fix catalyst and other build tweaks

### Updated

- Jaguar core upstream & custom performance hacks
- Mupen/GlideN64/Rice... updated to latest upstream
- All SPM packages to upstream

### Removed

- Delete Romefile
- dolphini remove used parent project


## [2.0.2] - 2021-09-14

More Bug fixes mostly.

### Added

- XCode will detect missing git submodules and auto-clone recursive before building the rest of the project

### Fixed

- #1586 Running same care twice in a row would crash
- #1593 Cheat codes menu crash fixes and other cheat code quality improvements

### Updated

- #1564 SteamController native SPM package port
- Jaguar core updated with libretro upstream + my performance hacks. PR made https://github.com/libretro/virtualjaguar-libretro/pull/53#issuecomment-919242560
- Fix many static analyzer warnigns about possible nil pointer/un-malloc'd memory usage, now we check and log nils or early exit where applicable
- SQLite.swift updated
- RxRealm updated from 5.0.2 to 5.0.3
- realm-cocoa updated from 10.14.0 to 10.15.0

## [2.0.1] - 2021-09-09

Bug fixes mostly.
Special thanks to contributors on this release;
👉 @mrjschulte
👉 @dnicolson
👉 @cheif

### Updated

- #1545 Update Mednafen to 1.27.1 ([Changelog](https://mednafen.github.io/documentation/ChangeLog.txt))
- #1587 Clarify Refresh Game Library Ui Dialog text
- TGBDual updated to latest upstream 1e0c4f931d8c5e859e6d3255d67247d7a2987434

### Fixed

- #1555 VirtualBoy crash on open
- #1559 Mednafen build error on tvOS
- #1583 NSLogger build issues on tvOS
- #1584 TvOS Release does NOT build due to 'searchController' is unavailable in tvOS
- #1585 Module 'AltKit' not found
- #1550 Provenance for Apple TV adds "private" part to "partialPath" in PVFile
- #1551 #1575 Fix missing roms on rescan
- #1556 Fix VirtualBoy Crash
- #1568 On screen buttons do not work with mednafen core

## [2.0.0] - 2021-08-02

Special thanks and shout-outs to @braindx, @error404-na, @zydeco, @mrjschulte, @yoshisuga, the Mupen team and all of the additional contributors.

**N64 Release!** with Mupen64Plus + GlideN64 — a non-jailbreak emulation _first._ A lot in this update: Swift codebase conversion, Atari Jaguar support, Saturn, Dreamcast…full _multi-disc support_ for all of you RPG fans out there, dark theme default, 60 FPS optimizations, core updates, new touch controls, iOS 12, iPhone X, WebDAV support and _much more…_

⚠️ **Breaking** ⚠️

2.0 does not support upgrading from 1.4 libraries. It MAY work with some versions of 1.5beta's but not all betas are the same. Your mileage may vary. For this reason we're updating the version to 2.0, to indicate the lack of upgrade path.

ℹ️ *You can install 2.0 along side 1.x by using a different bundle id*
### Added

#### New Cores

- **N64 Core**: Mupen64Plus
  - GlideN64 Preview (_only_ non-jailbreak app to do this)
  - High-Resolution Texture Support
    - Gliden64 & Rice
  - 4 players
  - Rumble support
- **Sega Saturn Core**: Mednafen
- **Atari Jaguar Core**: Virtual Jaguar custom _Alpha_ ** Note: requires additional steps for BIOS, very unstable **
- **Sege Dreamcast Core**: Reicast custom _Alpha_ ** Note: Unplayable, sync issues. For dev testing only **
- [Additional] **Nintendo GameBoy Core**: [TGBDual](https://github.com/libretro/tgbdual-libretro) _Beta_

#### New Features

- **[Multi-disc Support](https://github.com/jasarien/Provenance/wiki/Importing-ROMs#multi-disc-games)** (disc-swapping)
- iOS 11-15 Support
  <sup>Including Smart Invert Support so cover art and emulator view won't invert</sup><br>
- iPhone X Support
  <sup>Full-screen Support, Home Indicator: Hides with controller, Dims while playing</sup><br>
- MFi+ (Instant Button Swap Modes) to access to missing buttons on MFi Controllers ([MFi Controls](https://bit.ly/2LDZNzI))
- iCloud Syncing for Save States and Battery Saves _Beta_
- New Dark Theme Default
- tvOS Ui sync up w iOS.
- Timed Auto Saves (default: every 10 minutes)
- Game Info View & Game Info Preview View (on 3D Touch)
  - Extended editable ROM meta data ([Customizing ROMs](https://github.com/Provenance-Emu/Provenance/wiki/Customizing-ROMs))
    <sup>cover art, title, description, genre, release date, publisher, play history…</sup><br>
  - Single ROM Browsing (swipe left/right)
  - Links to Game Manuals
- Share Button
  - Export ROM, Saves, Screenshot and custom artwork
- WebDAV Support (access from the Finder or other WebDAV clients)
- Optional Touch/Overlay Controls Additions:
  - Start/Select Always On-screen (for MFi usage with iOS)
  - All-Right Shoulders (moves L1, L2, and Z to right side)
- Save/Load Save States View with Screenshots
- Add ROM to Home Screen (like web apps from Safari)
- Native resolution support
  - _Optional_: Renders OpenGL at native retina sizes
  - Some cores support internal up-scaling (Mupen)
- System details in settings
  - Lists supported cores, library info
  - List required BIOS's if they're installed and easy copy MD5 to the clipboard by tapping for easier Google searches
- Improved volume HUD
- Enhanced build information
  - In settings, see info about the installed build (version and build #, built source, date and more)
- In-app logs
  - In settings, view the logging output to help track down bugs. Export and e-mail.
- GameBoy multi-player via: [TGB Dual](https://github.com/libretro/tgbdual-libretro)

### Changed

#### Core Updates

- SNES9x 1.60.0 ([Changelog](https://github.com/snes9xgit/snes9x/releases))
- Mednafen 1.27.0 ([Changelog](https://mednafen.github.io/documentation/ChangeLog.txt))
- tgbdual-libretro 0.8.3 [GitHub](tgbdual-libretro)
- Genesis Plus GX 1.7.5 ([History](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/HISTORY.txt))
- PicoDrive 1.9.3

#### App Improvements

- **60 FPS Rendering & Performance Optimizations**
- Controller Improvements:
  - Consistent Cross-System MFi Button Mappings ([MFi Controls](https://bit.ly/2LDZNzI)]
  - New iCade Support Additions
  - Steam Controller Bluetooh LE Mode support
  - Rumble support (N64, PokeMini)
  - New Direct 8Bitdo M30 mapping support for all of the Sega and PC Engine/TG16 consoles.
- Touch/Overlay Controls:
  - New minimal, and less obstructive controller theme default
    <sup>(preview 1.5 edition as a teaser for UI 2.0's [Overlay Overhaul](#718) project)</sup><br>
  - Improved button styles
  - Improved layout and ergonomics (start, select, shoulders within reach)
  - Extended controls to include L2, R2
  - Visual Feedback
  - Button Color Tinting (Optional)
- Game Importer Improvements:
  - Conflict Resolution
  - Better ROM Matching
  - Imports
    <sup>combined 'roms' and 'cover art' directories into one universal drop directory</sup><br>
- Game Library Improvements
  - Side Scrolling Collection Views:
    - Recent Saves with Screenshots
    - Recently Played
    - Favorites
  - Library Sorting
  - Cover Badges (New/Unplayed, Favorite, Disc Count, Missing ROM)
  - Swipe to Delete
- 3D Touch

#### New Controllers

- Steam Controller
- 2018.Q4+ MFi Controllers (supporting R3/L3) (Controllers)
- 8Bitdo M30

#### Behind the Scenes:

- Conversion to Swift codebase
- Dynamic Core Loading
- Extended ROM metadata
- Extended System metadata
- Full Codable support for games, saves, library etc, models

#### Bugfixes

- Fixed Atari 5200 screen clipping
- Fixed iPhone X margins
- PC Engine CD Support restored
- _and more…_

#### Etc…

- New Icon!

## [1.4.0] - 2018-03-13

Huge thanks to @JoeMatt, @leolobato, @braindx and everyone else who contributed.

### Added

- PlayStation core
- Pokémon mini core
- Virtual Boy core
- Atari 7800 & Lynx core
- Neo Geo Pocket / Neo Geo Pocket Color core
- PC Engine / TurboGrafx-16 (CD) core
- SuperGrafx core
- PC-FX core
- WonderSwan core
- CRT Shader

### Updated

- Importer improvements (MD5 matching and performance improvements)

## [1.3.2] - 2017-02-12
## [1.3.1] - 2016-12-17
## [1.3.0] - 2016-11-28
## [1.2.6] - 2015-11-17
## [1.2.5] - 2015-11-11
## [1.2.4] - 2015-11-06
