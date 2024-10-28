# TODO.MD
_My personal TODO notes_

## Show stoppers

- [ ] (Lite) Sega CD is borked
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

- [ ] Dark mode toggle doens't refresh all views if theme set to auto
- [ ] iCloud sync removed
- [ ] (Lite) Turbo GFX 16 no video for some roms
- [ ] (Lite) Intellivision (PVBliss) audio crashes on button press
- [ ] (Lite) Intellivision video is glitched
- [ ] (Lite) SuperVision video dimensions wrong
- [ ] (Lite) Odyssey2 needs a way to enter game number 1,2 (3,4)?
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

- [ ] Swift UI Settings should use the themed alerts via the delegate or something
- [ ] theme switching doesn't update nav bar color
- [ ] Box art is clipped in swift ui -- need better aspect ratios
- [ ] Game Info in swift ui crashes on next game scroll
- [X] Fix button 9 repeat on Intellivision controls
- [X] Importer should overwrite or delete on duplicate imports
- [ ] Spotlignt/extensions can't build with spm modules
- [ ] See if psx mednafen has more options
- [ ] Short names are abreviations not shortname
- [ ] Sega Master System short name showing as SMS
- [ ] Mupen CoreOptions code is trash 
- [ ] Opening roms from md5/siri search doesn't work
- [ ] Swift UI should open on home and be scrollable to systems
- [ ] N64 onscreen controls are kind of high
- [ ] Themes are ugly on old UI
    - [ ] Fix default no-artwork background
    - [ ] Fix section header colors
    - [ ] Top bar not themed
    - [ ] Main background not themed
    - [ ] Game text not themed
    - [ ] New import indicator not themed
- [ ] Swift UI doesn't have "Share" menu item
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

## AppStore Review

- [ ] Screenshots
- [ ] Remove "beta" text

## Provenance Plus

- [ ] Add in-app purchase and screen
- [ ] Add new logo
- [ ] Add Shiragame
- [ ] Finish themes
- [ ] Add app rating with SiruisRating
- [ ] Hide some features behind is plus in app store builds
    - [ ] Advanced settings
    - [ ] Extra themes
