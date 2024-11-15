# TODO.MD
_My personal TODO notes_

## Show stoppers

- [X] RetroArch GLES cores are crashing?
- [X] moveable button joystick and dpad move at the same time
- [X] Delete isn't deleting
    - [X] throw an error on file manager error
- [X] audio is fucked
- [X] 4X multisampling crashes Mupen on iPad, (iphone?)
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

- [ ] Test iOS 17.0 and then 16.X
- [ ] Gamepad navigation in swiftUI
- [ ] Remove or fix new shaders
- [ ] Artwork ratios are wrong
- [ ] Add more artwork lookups
- [ ] BIOS screens show mismatch when there isn't
- [ ] Fix or remove Flycast retroarch for Dreamcast
- [ ] Fix layout, layout button and touch controls of Desmume2015 or remove
- [ ] Opening roms from md5/siri search doesn't work (Claude had good sample code)
- [ ] Native scale on mupen shows in wrong area on ipad
- [ ] Share on old UI crashes app (realm threading issue)
- [ ] iCloud sync removed
- [X] Checking Import UI is hanging (removed for now)
    - [ ] fix public func addImportedGames(to spotlightIndex: CSSearchableIndex, database: RomDatabase) async
- [ ] look at the displaylink thing in retroarch
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
