# TODO.MD
_My personal TODO notes_

## Show stoppers

- [ ] RetroArch GLES cores are crashing?
- [ ] Delete isn't deleting
    - [X] throw an error on file manager error
- [ ] Checking Import UI is hanging (removed for now)
    - [ ] fix public func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) async
- [X] Refresh library and conflicts on new UI not working
- [X] UI is unresponsive after closing emulator
- [X] wrap advanced settings in freemiumview
- [X] fix launching webserver from swiftui menu
- [X] iCloud sync isn't working, remove or fix
- [X] Swift UI long press on roms menu missing actions {rename, ~~share~~}
- [X] Progress hud on unzips isn't hiding
- [X] Themes setting doesn't work
- [X] Conflicts folder is weird
- [X] SwiftUI not seeing conflicts
- [X] Copy the framework loader from old branch, fix it too!
- [X] emuThreeDS and other metal based cores have wrong layout contraints
- [X] Possible race condition in importer
- [X] Gambatte swift module not done
- [X] PVmGBA swift module is not done
- [X] Fix Repo submodules
- [X] Audio broken
- [X] Loading save states crashes realm
- [X] Creating save states crashes realm
- [X] SwiftUI not importing roms correctly
- [X] compiling with Mupen+Rumble.swift breaks device release builds

## Major bugs

- [ ] Re-add and fix "Launch Web Server" from Swift UI settings
- [ ] Share on old UI crashes app (realm threading issue)
- [ ] iCloud sync removed
- [ ] look at the displaylink thing in retroarch
- [ ] Flycast crashes with error `NSInvalidArgumentException', reason: '-[MetalView naturalDrawableSizeMVK]: unrecognized selector sent`
    - [ ] Try downgrading MoltenVK.xcframework to fix dolphin, flycast others
- [ ] (Lite) Intellivision (PVBliss) audio crashes on button press
- [ ] (Lite) Intellivision video is glitched
- [ ] (Lite) Odyssey2 needs a way to enter game number 1,2 (3,4)?
- [ ] (Lite) SuperVision video dimensions wrong
- [ ] (Lite) Turbo GFX 16 no video for some roms
- [ ] (Lite) Sega CD is borked
- [X] The notch is in retroarch view
- [X] manually copying a bios into bios's works, but database isn't updated with instance reference
- [X] Mupen video crashes with update metal code
- [X] CrabEMU (Genesis) no buttons work
- [X] Mednafen GB crashing
- [X] Vectrex needs PVVecXCore:LibRetroCore (or rollback to older code?)
- [X] ZX Spectrum needs PVLibRetroCore (or rollback to older code?)
- [X] Zip files cause conflicts, not always handled correctly
- [X] Jaguar not working in Metal mode (dimensions off slightly?)
- [X] Stella Metal is right but GLES is blank
- [X] Stella no buttons work
- [X] Game gear dimensions wrong
- [X] Colicovision roms are blank screen
- [X] iPad swiftui opening web server doesn't have a cgrect
- [X] Stella pixel types are wrong - video is distorted
- [X] Loading the app is very slow now (release mode not that bad)
- [X] Mednafen controller input broken
- [X] Test intellivisoin and check proper bios
- [X] Pokemini crashes on load
- [X] PokeMini butons don't work
- [X] Intellivision doesn't load

## Minor bugs

- [ ] BIOS importer should work when multiple systems match the same bios
- [ ] Dark mode toggle doens't refresh all views if theme set to auto
- [ ] Box art is clipped in swift ui -- need better aspect ratios
- [ ] Game Info in swift ui crashes on next game scroll
- [ ] Mupen CoreOptions code is trash 
- [ ] N64 onscreen controls are kind of high
- [ ] Opening roms from md5/siri search doesn't work (Claude had good sample code)
- [ ] See if psx mednafen has more options
- [ ] Should add loading screen for starting emulator
- [ ] Spotlignt/extensions can't build with spm modules (this is working now? was an xcode bug?)
- [ ] SwiftUI game long press menu missing item
    - [ ] View save states
    - [ ] Share
    - [ ] Hide
    - [ ] Choose disc
- [ ] Make an LCD Filter then add it back to settings
- [ ] Swift UI should open on home and be scrollable to systems
- [ ] When switching from SwiftUI to old UI, the game lib is zoomed way too much, need to change how it uses Scaling Factor Defaults[.gameLibraryScale]
- [ ] should store last page view for next open
- [ ] theme switching doesn't update nav bar color
- [ ] Themes are ugly on old UI
    - [ ] Fix default no-artwork background
    - [ ] Fix section header colors
    - [ ] Top bar not themed
    - [ ] Main background not themed
    - [ ] Game text not themed
    - [ ] New import indicator not themed
- [ ] Make GameMoreInfoVC and it's equivlant PageViewController into native swifttUI with editing of properties
- [X] Fix button 9 repeat on Intellivision controls
- [X] Importer should overwrite or delete on duplicate imports
- [X] Swift UI Settings should use the themed alerts via the delegate or something
- [X] purple and rainbow themes not selectable
- [X] Themes page indicator not right
- [X] add tap for bios to clipboard in swiftui on missing
- [X] Swift UI console view, games could use some improvments
    - [X] side padding minimums
    - [X] even spacing
    - [X] game title text sometimes overflows the width
- [X] Add Show recent saves on console itself
- [X] Dolphin won't build due to stdint.h in extern C
- [X] Nes fix button layout
- [X] Test/fix CrabEMU save states
- [X] Legacy UI removed collapsing systems
- [X] 3D0 crashes on load
- [X] 7Zip support not working

## Cores to translate

- [ ] PVFreeIntV
- [ ] PVfMSX

--------------------------------------

## AppStore Review

- [X] Screenshots
- [X] Remove "beta" text

## Provenance Plus

## High Priority

- [X] Privacy policy / EULA in settings!
- [X] Add in-app purchase and screen
- [ ] Add app rating with SiruisRating

### Low Priority
- [ ] Finish themes
- [ ] Add new logo
- [ ] Add Shiragame
- [X] Hide some features behind is plus in app store builds
    - [X] Advanced settings
    - [X] Extra themes
