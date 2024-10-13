# TODO.MD
_My personal TODO notes_

## Show stoppers

- [ ] Conflicts folder is weird
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

- [ ] Jaguar not working in Metal mode (dimensions off slightly?)
- [ ] Stella Metal is right but GLES is blank
- [ ] Stella no buttons work
- [ ] CrabEMU no buttons work
- [ ] Intellivision (PVBliss) audio crashes on button press
- [ ] Mednafen GB crashing
- [ ] Odyssey2 needs a way to enter game number 1,2 (3,4)?
- [ ] Zip files cause conflicts, not always handled correctly
- [ ] Vectrex needs PVVecXCore:LibRetroCore (or rollback to older code?)
- [ ] ZX Spectrum needs PVLibRetroCore (or rollback to older code?)
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

- [ ] Add Show recent saves on console itself
- [ ] 3D0 crashes on load
- [ ] 7Zip support not working
- [ ] See if psx mednafen has more options
- [X] Nes fix button layout
- [ ] Short names are abreviations not shortname
- [ ] Sega Master System short name showing as SMS
- [ ] Mupen CoreOptions code is trash 
- [ ] Test/fix CrabEMU save states
- [ ] Opening roms from md5/siri search doesn't work
- [ ] Swift UI should open on home and be scrollable to systems
- [ ] Swift UI sort consoles by bits/brand/name/year order ascend/descend
- [ ] Legacy UI removed collapsing systems
- [ ] Swift UI long press on roms menu missing actions {artwork, sharing...}
- [ ] Dolphin won't build due to stdint.h in extern C

## Cores to translate

- [ ] PVFreeIntV
- [ ] PVfMSX
