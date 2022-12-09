# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- stella: don’t crash on 2nd load
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
- cores framework don’t embed
- cores table view, hide unsupported cores unless on
- Cores, add .core.name to ones that didn’t
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
- retro: metal video doesn’t crash but still odd
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
- tvOS don’t copy glsl to docs
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
- Use system color for “Game library empty”
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
- retro: various fixes, tvos builds
- retro: vecrex
- retro: video work
- retro: yabause update
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
