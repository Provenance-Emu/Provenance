# TODO.MD
_My personal TODO notes_

## Show stoppers

- [X] Games pausing not working
- [ ] New save state mangager
    - [X] doesn't load from homeview
    - [X] Hide share or impliment
    - [X] Save state images
    - [ ] swipe sucks
    - [X] top to play, with confirmation
    - [X] Fix main game artwork async, or missing artwork view
    - [X] Number of save states count updates on delete
    - [X] Save state images
    - [X] Transparent background on the wrapper view controller,
    - [X] Glitchy search bar hiding
- [X] test,fix,finish PVImageFile pathOfCachedImage

- [X] Shared documents :        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId)

## Major bugs

- [ ] Opening roms from md5/siri search doesn't work (Claude had good sample code)
- [X] Test iOS 17.0 and then 16.X
- [X] Remove or fix new shaders
- [ ] Artwork ratios are wrong
- [X] BIOS screens show mismatch when there isn't
- [ ] Fix or remove Flycast retroarch for Dreamcast
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

- [ ] Spotlight no worky, crashes
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

- [ ] Add more artwork lookups
- [ ] Gamepad navigation in swiftUI
    - Partially implimented
- [ ] iCloud sync
- [ ] Save state share in savestate manager swift ui view

### Kind of want

- [ ] New save states management page
    - [ ] (New design)[https://discord.com/channels/@me/1034683216059179069/1307885448030326877]

### Cores to translate

- [ ] PVFreeIntV
- [ ] PVfMSX

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

- [ ] Update screenshots without copyright material
- [X] Remove apple referecnces from app description
- [X] Custom build without certain cores
    - Anything apple

- [X] Screenshots
- [X] Remove "beta" text

## Provenance Plus

## High Priority

- [X] Privacy policy / EULA in settings!
- [X] Add in-app purchase and screen
- [ ] Add app rating with SiruisRating
- [ ] Add alternative icons
    - [ ] AppIcon-8bit1
    - [ ] AppIcon-8bit2
    - [ ] AppIcon-8bit3
    - [ ] AppIcon-8bit4
    - [ ] AppIcon-8bit5
    - [ ] AppIcon-Blue-Negative
    - [ ] AppIcon-Blue
    - [ ] AppIcon-Cyan
    - [ ] AppIcon-Gem
    - [ ] AppIcon-Gold
    - [ ] AppIcon-Paint1
    - [ ] AppIcon-Paint2
    - [ ] AppIcon-Purple
    - [ ] AppIcon-Seafoam
    - [ ] AppIcon-Yellow

### Low Priority
- [ ] Finish themes
- [ ] Add Shiragame
- [X] Hide some features behind is plus in app store builds
    - [X] Advanced settings
    - [X] Extra themes
