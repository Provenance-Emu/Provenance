# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2022-01-26

Special thanks to contributors on this release;
👉 @mrjschulte
👉 @ToddLa
👉 @ac90b671
👉 @nenge123
👉 @david.nicolson
👉 @davidmuzi
👉 @amoorecodes 

### Added

- Code Signing is now managed with an XCConfig file. See `CodeSigning.xcconfig.example` for instructions. (Only applies to developers/xcode source installs)
- Native Metal renderer option [WIP/Buggy]
- Metal Shaders (CRT, LCD, etc.)
- Sega Saturn Mutli-CD support
- N64: Dual Shock 4 touchpad as pause
- N64: option for Dual Joysticks on DualShock4 as dual controllers (allows Goldeneye dual controller joystock layout from 1 physical dualshock)
- enumeration options
- radio selection options
- per-game option overrides
- Jaguar options exposed
- N64 mupen/gliden/rice options exposed
- Swift UI/UIKit optional code paths at app start (SwiftUI currernly empty, for easier development in future)
- Mednafen: SNESFaust 1 frame render ahead option (on by default. VERY SNAPPY!)
- Mednafen : many more sub-core options added
- Localizations (Only Partially translated WIP)
  - Chinese Simplifed by  @nenge123
  - Spanish
  - Russian by  @amoorecodes
  - Dutch by @mrjschulte
- Support new Apple TV Siri remote (MicroGamepad and DirectionalGamepad)
- NSLocalizedString for most strings in main app source
- Long press a ROM for quick access to Core Options
- FPS debug label now includes total CPU and Memory usage.
- GameBoy Advanced cheat code support
- APIs for keyboard, mouse, rumble, on-screen joystick. (coming in future release)
- VirtualBoy side by side mode (for 3D tv's with Side by Side mode. Google Cardboard coming later)
- XCode will present a warning message if it detects a device build but CodeSigning.xcconfig isn't setup.

### Improved

- If multiple cores support a system, cores are listed in recommended order.
- Improved logo/header bar for iOS & tvOS
- Branch prediction compiler hints for tight loops, possibly faster.
- Fix some excessive thread blocks
- Replace all spinlocks with atomic operations for better thread performance
- mupen faster controller polling, various other code speedup tweaks.
- mupen llvm optimization flags improved (was incorrectly -O2, now -Os)
- replaced some sloppy force unwraps with proper nil checks and logging
- Shaders are copied to Documents at load and read from thereafter. This allows locally editing / developing shaders without rebuilding.
- Catalyst: All cores build now for Intel and M1.
- Dark Mode UI always on, fixes some color issues
- Mupen wrapper code organized, refactored
- Jaguar button layout tweaks
- Converted more app code from ObjC to Swift
- check if file exists before attempt to delete, reduces superfulous throws trapping in the debugger
- Mark various ObjC classes `objc_direct_members`. Should improve Swift to ObjC calls bypassing dynamic dispatch for function pointers (in theory)

### Fixed

- Conflicts better detected
- tvOS top buttons sometimes couldn't be selected
- Faster compile times (improved header imports, compiler flags)
- Fixed some improper retain cycles in ObjC blocks
- Fixed rare audio engine nil reference race condition crash
- Cheat entry UI fixes

### Updated

- N64: Swap left and right triggers to L:Start R:Z Button from other way around prior
- Updated Swift Packages (RxRealm, Realm, Cocoalumberjack)
- Improved tvOS UI (top buttons, search, icons, more consistant styling)
- mupen cxd4 plugin to latest upstream version
- mupen rsp-hle pluring to latest upstream version
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
- #1414 smarter expecptions in PVSystem
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
- Fix gamecub stealing n64 roms
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
