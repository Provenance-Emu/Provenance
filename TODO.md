# TODO.MD
_My personal TODO notes_

## Show stoppers

- [ ] ugly retroarch ui in app, a bit unresponsive
- [ ] Retroarch core options not showing up

## Major bugs

- [ ] Mednafen FDS sometimes crashes on load (it worked then it didn't)
- [ ] Mednafen loads Famicom Disks but gets stuck on bios
- [ ] Opening roms from md5/siri search doesn't work (Claude had good sample code)
- [ ] Artwork ratios are wrong
- [ ] Share on old UI crashes app (realm threading issue)
- [X] Checking Import UI is hanging (removed for now)
    - [ ] fix public func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) async
- [ ] Fix layout, layout button and touch controls of Desmume2015 or remove
    - Partially done WIP
- [ ] Native scale on mupen shows in wrong area on ipad
- [ ] Flycast crashes with error `NSInvalidArgumentException', reason: '-[MetalView naturalDrawableSizeMVK]: unrecognized selector sent`
    - [X] Try downgrading MoltenVK.xcframework to fix dolphin, flycast others
- [ ] (Lite) Intellivision (PVBliss) audio crashes on button press
- [ ] (Lite) Intellivision video is glitched
- [ ] (Lite) Odyssey2 needs a way to enter game number 1,2 (3,4)?
- [ ] (Lite) SuperVision video dimensions wrong
- [ ] (Lite) Turbo GFX 16 no video for some roms
- [ ] (Lite) Sega CD is borked

## Minor bugs

- [ ] Atari 2600 not using our controller for retroarch
- [ ] Spotlight no worky, crashes
- [ ] archive extraction HUD doens't show % progress updates
- [ ] Screensots for retroarch cores is the wrong space (3ds too)
- [ ] BIOS importer should work when multiple systems match the same bios
- [ ] Dark mode toggle doens't refresh all views if theme set to auto
- [ ] Box art is clipped in swift ui -- need better aspect ratios
- [ ] Game Info in swift ui crashes on next game scroll
- [ ] Mupen CoreOptions code is trash 
- [ ] N64 onscreen controls are kind of high
- [ ] Add a way to delete a bios
- [ ] Add core option for mGBA low pass filter
- [ ] See if psx mednafen has more options
- [ ] Should add loading screen for starting emulator
- [ ] Spotlignt/extensions can't build with spm modules (this is working now? was an xcode bug?)
- [ ] SwiftUI game long press menu missing item
    - [ ] View save states
    - [ ] Share
    - [ ] Hide
    - [ ] Choose disc
- [ ] Microphone input for cores that support it
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
- [ ] App Group containers in Catalyst "public class var appGroupContainer"
- [ ] look at the displaylink thing in retroarch

## Features to Add

###  Really want

- [ ] GameImportQueue
    - [ ] Pause/play on game start/stop
    - [ ] clicking an item should import it
    - [ ] indicator, pause/start in queue UI
    - [ ] Inidicator, pause/start in main UI
- [ ] Add an option to use AppGroups
- [ ] Gamepad navigation in swiftUI
    - Partially implimented
- [ ] iCloud sync
- [ ] Save state share in savestate manager swift ui view
- [X] Add more artwork lookups

### Kind of want

- [X] New save states management page
    - [X] (New design)[https://discord.com/channels/@me/1034683216059179069/1307885448030326877]

### Cores to translate / fix

- [ ] Gearcoloco
    - Video bad
- [ ] PVEP128
- [ ] PVVecX
- [ ] Flycast / Reicast
- [ ] PVFreeIntV
- [ ] PVfMSX
- [ ] Duckstation
- [ ] PCSXRearmed
- [ ] Mupen retroarch no video

### Retroarch cores to add

- holani
    >>> Holani is a cycle-stepped Atari Lynx video game system emulator that can be used as a libretro core. Holani's primary goal is to get closer to the Lynx hardware and provide a better emulation experience.
    https://docs.libretro.com/library/holani/#background
- puae & puea 2021
    Amiga
    https://docs.libretro.com/library/puae/
- bsnes-hd-beta
- neocd
    https://docs.libretro.com/library/neocd/
- melondsds

--------------------------------------

## AppStore Review

- [\] Update screenshots without copyright material

## Provenance Plus

## High Priority

- [ ] Add app rating with SiruisRating

### Low Priority
- [ ] Finish themes
- [ ] Add Shiragame
