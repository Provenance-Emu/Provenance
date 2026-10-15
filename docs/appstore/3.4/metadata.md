# Provenance 3.4: App Store metadata (draft)

Status: **draft for owner review**, 2026-10-15. Sources: `CHANGELOG.md` [Unreleased],
`git log` since 2026-09-20 (launch batch Oct 14-15) and the current
`fastlane/metadata/{en-US,appleTV/en-US}` files. Nothing here has been pushed to
App Store Connect, and `fastlane/metadata` is unchanged. Copy the approved text into
those files for `deliver`.

Character counts were checked with `tools/check_metadata.py` (the App Store
limits are listed beside each field).

Rules this draft follows:

- Keywords contain no console brand names (Nintendo, Sega, PlayStation, SNES and so on)
  and no competitor app names. Apple rejects trademarked keywords under guideline 2.3.7.
  System names stay in the description, where the shipping listing already has them.
- Nothing behind a feature flag that is off by default (Nearby Libraries / Share This
  Library) is advertised.
- Provenance Plus features are labelled as Plus.

---

## iPhone and iPad

### Name (30)
```
Provenance Emu
```

### Subtitle (30)
```
Your Retro Game Collection
```

### Promotional text (170)
```
New in 3.4: Dreamcast and Jaguar CD, a settings sidebar, edit your controller layout from the pause menu, CRT and LCD filters per game, NFC game tags and more.
```

### Keywords (100)
```
emulator,retro,arcade,classic,console,controller,cheats,achievements,crt,shaders,skins,homebrew,8bit
```

### Description (4000)
```
Provenance plays the games you own from more than 60 classic consoles, handhelds and arcade systems, in one native app for iPhone, iPad and Apple TV.

YOUR LIBRARY, BEAUTIFULLY ORGANIZED
• Import ROMs from Files, AirDrop, the share sheet, a Wi-Fi web uploader or a folder you choose
• Cover art and game details are matched automatically, and you can add your own artwork
• Browse by system, search everything, pin favorites and jump back into recent games
• Keep the library in the app, or point Provenance at a folder in Files or iCloud Drive

PLAY YOUR WAY
• On-screen controls built for every system, with an editor right in the pause menu: move, resize and remap buttons without leaving the game
• Full controller support: MFi, Xbox, PlayStation, Switch Online pads, Backbone and other controller cases, keyboards and mice
• Remap any controller per system or per game
• Import DeltaSkin controller skins

MAKE IT LOOK RIGHT
• A library of CRT, LCD and handheld filters, picked per game, per system or for everything, with live previews over your paused game
• Aspect fit, integer scaling, stretch and native resolution

SAVE, SHARE, CONTINUE
• Save states with thumbnails, quick save and quick load
• A cheat library of over 1.2 million codes for 44 systems
• RetroAchievements: earn achievements while you play
• Gameplay Clips: keep the last moments of play and save them as a video
• iCloud sync of your library, save states and BIOS files across iPhone, iPad and Apple TV (Provenance Plus)
• NFC game tags: write a game to a tag, then tap it with your iPhone to start playing

SUPPORTED SYSTEMS INCLUDE
• Nintendo: NES, SNES, Nintendo 64, Game Boy, Game Boy Color, Game Boy Advance, Nintendo DS
• Sega: Master System, Genesis / Mega Drive, Game Gear, Sega CD, 32X, Saturn, Dreamcast
• Sony: PlayStation, PSP
• Atari: 2600, 5200, 7800, Lynx, Jaguar, Jaguar CD
• NEC PC Engine / TurboGrafx-16 and CD, Neo Geo, Neo Geo Pocket, WonderSwan, arcade, DOS and more

Provenance does not include any games. Play games you own or homebrew and freely distributed software. Some systems need BIOS files that you provide.

Provenance is open source and built by its community.
```

### What's New in 3.4 (4000)
```
Provenance 3.4 is our biggest update yet.

NEW SYSTEMS
• Sega Dreamcast, with no JIT needed
• Atari Jaguar CD, with a built-in BIOS replacement so most games boot without a BIOS file

NEW
• Settings sidebar: every settings page one tap away, on iPhone and iPad
• Edit Layout and Remap Controller in the pause menu: move buttons and change mappings without leaving your game
• A new on-screen controller for every system, with layouts matched to each console's pad
• Filters: a library of CRT, LCD and handheld looks, set per game or per system, with live previews
• Gameplay Clips: save the last moments of play as a video
• NFC game tags: tap a tag with your iPhone to launch a game, even when Provenance is closed
• Choose where your library lives, including a folder in Files or iCloud Drive
• ROM patches: apply IPS and BPS patches and keep each version of a game
• A cheat library of over 1.2 million codes for 44 systems
• Nintendo Switch Online controllers for SNES, N64 and Mega Drive now work
• Zipped games load directly

IMPROVED
• More cores run on the faster libretro engine, with your saves carried over
• Import is quicker and handles multi-disc and multi-file games
• Many fixes for stability, audio, save states and iCloud sync
```

---

## Apple TV

### Subtitle (30)
```
Retro Games on Apple TV
```

### Promotional text (170)
```
Your classic games on the big screen: Dreamcast and Jaguar CD join 60+ systems, with CRT filters, controller remapping and iCloud sync from your iPhone and iPad.
```

### Keywords (100)
```
emulator,retro,arcade,classic,console,controller,couch,multiplayer,crt,achievements,cheats,tv games
```

### Description (4000)
```
Provenance turns your Apple TV into a retro game console. Play the games you own from more than 60 classic consoles, handhelds and arcade systems on the big screen, in one app built for tvOS.

BUILT FOR THE BIG SCREEN
• A native tvOS interface for the Siri Remote and game controllers
• MFi, Xbox, PlayStation and Switch Online controllers, with remapping per system or per game
• Connect several controllers for multiplayer on the couch
• Browse your library with cover art and details

MAKE IT LOOK RIGHT
• CRT, LCD and handheld filters, picked per game or per system, with live previews
• Aspect fit, integer scaling, stretch and native resolution

KEEP PLAYING
• Save states, quick save and quick load
• Built-in cheat database
• RetroAchievements
• iCloud sync brings your library, save states and BIOS files over from iPhone and iPad (Provenance Plus)

SUPPORTED SYSTEMS INCLUDE
• Nintendo: NES, SNES, Nintendo 64, Game Boy, Game Boy Color, Game Boy Advance
• Sega: Master System, Genesis / Mega Drive, Game Gear, Sega CD, 32X, Saturn, Dreamcast
• Sony: PlayStation
• Atari: 2600, 5200, 7800, Lynx, Jaguar, Jaguar CD
• PC Engine / TurboGrafx-16, Neo Geo, Neo Geo Pocket, WonderSwan, arcade, DOS and more

Provenance does not include any games. Play games you own or homebrew and freely distributed software. Some systems need BIOS files that you provide.
```

### What's New (4000)
```
Provenance comes to Apple TV.

• Play games from more than 60 classic systems on your TV
• Sega Dreamcast, and Atari Jaguar CD with a built-in BIOS replacement
• CRT, LCD and handheld filters, set per game or per system
• Controller remapping per system or per game, including Switch Online pads
• Save states, a built-in cheat database and RetroAchievements
• iCloud sync brings your library, save states and BIOS files over from iPhone and iPad (Provenance Plus)
```

---

## Claims the owner must confirm before submission

| Claim | Why it needs a check |
|---|---|
| "Edit Layout / Remap Controller in the pause menu" | Landed Oct 14 (19eb0620a8, 6c1c9900e1); device-tested only on simulator |
| "Gameplay Clips" | Settings › Advanced; the SAVE CLIP action is Provenance Plus-gated per CHANGELOG (#3412). Mark as Plus if that is still true |
| "RetroAchievements" | Known gap: the thin libretro wrapper has no per-frame rcheevos tick (memory `thin-wrapper-cheevos-gap`). Native cores only? Narrow the wording if so |
| "NFC game tags" | Needs the NFC Tag Reading capability in the shipping profile and a device test |
| "ROM patches" | Shipped in #3734/#3736/#3738; confirm it is not behind a flag |
| "Nintendo DS" and "PSP" in the iOS system list | Confirm both ship in the App Store build (melonDS / PPSSPP dylibs in cores.yml) |
| "Over 1.2 million cheat codes for 44 systems" | Figure taken from the app's own What's New sheet; the shipping listing said "hundreds of games". Confirm it counts the bundled database, not the online GameHacking.org lookup |
| "Nintendo Switch Online controllers for SNES, N64 and Mega Drive now work" (What's New, Apple TV caption 04) | Adapter landed Oct 13-14 without a device test |
| "Choose where your library lives, including a folder in Files or iCloud Drive" | Picked-folder storage: the PVLibrary test suite has not run on it |
| Network Play tile in the pause-menu screenshots (iPhone 03, iPad 04) | Netplay is left out of the copy, but the tile is on screen; keep it, or recapture with netplay hidden |
| Brand names on screen: "Neogeo" bezel preset (iPhone 06), "MFi, Xbox, PlayStation and Switch Online" (Apple TV 04 caption) | Low risk; approve or reword |
| Netplay | Deliberately left out: thin netplay covers only netpacket cores and is untested on devices |
| Nearby Libraries / Share This Library | Left out: behind the `nearbyLibraries` flag, off by default |
| Subtitle change | The shipping subtitle is "Multi-System Retro Emulator"; the draft is a suggestion |
| Keywords | Draft drops the console brand names the current `keywords.txt` uses |
