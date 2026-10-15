# Release smoke tests (rolling)

Device checks that code review and simulator tests cannot cover. Run the
"Next release" block on a real iPhone (notched) and iPad before each
TestFlight; move items to "Verified" with the build number once they pass,
delete them a release later. Add new items at the top of "Next release".

## Dev workspace (not release-gated)

Dev apps never ship to TestFlight, so these do not block a release. They gate
the shipping-project swap: the cores below must work as SwiftPM packages on a
device before `Provenance.xcodeproj` consumes them. Build with `make dev-ui` /
`make dev-n64` and install on a real iPhone (and Apple TV where noted).

### Core packages (PR #3739, `1de61a6cc9`)

- [ ] `Provenance-Dev-UI`, snes9x (`PVSNES9x-Dynamic`): a SNES game boots,
      takes input, has sound; save a state, quit, load it.
- [ ] `Provenance-Dev-UI`, FCEU (`PVFCEU-Dynamic`): same for an NES game.
- [ ] `Provenance-Dev-UI`, Genesis-Plus-GX (`PVCoreGenesisPlus-Dynamic`): same
      for a Genesis game; core options open (settings view pushed from Swift).
- [ ] `Provenance-Dev-N64`, Mupen64Plus: an N64 game boots with GlideN64, then
      with Rice (Core options → video plugin). Each loads its framework by name
      (`<name>-Dynamic`); a plugin that fails to load logs the dlopen error.
- [ ] `Provenance-Dev-N64`: repeat one boot with each RSP plugin (HLE, CXD4).
- [ ] `Provenance-Dev-N64` helper files (`38cebb9af3`): in the built app,
      `find <App>.app/PVMupenGameCore_PVMupen64Plus.bundle -type l` prints
      nothing, and the bundle holds `GLideN64.ini`, `GLideN64.custom.ini`,
      `RiceVideoLinux.ini`, `mupen64plus.ini`, `mupencheat.txt`. After a
      boot, the ROM's `config/` and `data/` folders contain the ini files
      (the log has no "No resource path found for file").
- [ ] `Provenance-Dev-N64`, GlideN64 NEON path (`47fcf88138`): geometry,
      lighting and textures look right in a 3D game (e.g. Mario 64, Zelda);
      no missing polygons or garbled matrices compared with the shipping app.
- [ ] Repeat the snes9x and N64 boots on Apple TV.

## Next release

### Upgrade from 3.3.1 (full app; first App Store update in ~9 months)

Every existing user takes this path, so it gates the release. Audit of
3.3.1 → develop (2026-10-12): schema 28 → 29, thick RetroArch → thin
wrapper, 27 cores retired, new iCloud settings sync, #3742 (four cores now
built from SwiftPM packages). Lite is out of scope (never published).

**Setup on 3.3.1** (App Store build; iPhone, iPad and Apple TV, iCloud sync
on with CloudKit on at least one device):

1. Import ROMs for SNES, NES, Genesis/Sega CD, N64, GBA, 2600, PSX, NDS,
   Dreamcast, 3DS, and a patch (`.ips`/`.bps`) linked to a game.
2. On each of snes9x, FCEU, Genesis-Plus-GX, Mupen64Plus (GlideN64 and
   Rice), mGBA, Stella, VBA-M and PicoDrive: one save state and one in-game
   (battery) save.
3. On iOS, libretro cores (they ran on the full RetroArch runtime in
   3.3.1): a save state and an in-game save on NDS and on Dreamcast or PSX;
   change one core option (e.g. NDS screen layout, PSX renderer).
4. Set a preferred core per game and per system; mark favourites; pick a
   skin; change a few settings (autosave, library zoom); leave others at
   defaults.
5. Note the library size and the settings screen (screenshots).

**Upgrade** to the TestFlight build without deleting the app. Launch time
on the oldest supported device: no watchdog kill (0x8BADF00D) while the
v29 migration and Realm compaction run; test once with a large library
(5k+ games).

**Library and database**

- [ ] Same games, favourites, recents, artwork; no duplicates, no empty
      library, ROMs launch.
- [ ] The linked patch is still linked to its game (not "pending").
- [ ] Per-game and per-system preferred cores kept; a preference pointing
      at a removed core falls back to an available one without a crash.
- [ ] Files that sat in the Documents vs App Group location 3.3.1 used
      still resolve (the automatic folder mover is gone).

**Save states and in-game saves**

- [ ] snes9x, FCEU, Genesis-Plus-GX, Mupen64Plus: 3.3.1 states load and
      in-game saves are present (these cores now build from SwiftPM
      packages, `cd5fa516c9`; first device run of that build). N64 with
      both GlideN64 and Rice; ini files land in the ROM's `config/` and
      `data/` folders.
- [ ] mGBA, VBA-M, PicoDrive, Genesis Sega CD: states and in-game saves
      load (core versions bumped; VBA-M upgrades states by exact length).
- [ ] iOS libretro states from 3.3.1 load: the thin wrapper now decodes
      RetroArch's rzip and RASTATE files (`142f51545b`); the log names the
      format. Whether a state loads still depends on the core's version.
      Achievement data stored in the state is dropped.
- [ ] iOS libretro in-game saves from `Documents/RetroArch/saves/` appear
      in the game: copied to `Battery States/<rom>/` on first launch
      (`af5a109f1c`; never overwrites). A game already played on a thin
      build may have a blank `.srm` that blocks the copy; the original
      stays in `RetroArch/saves/`.
- [ ] DS battery saves that 3.3.1 kept in Save States land in Battery
      States and load in melonDS/DeSmuME.
- Expected, not bugs: Stella 7 → 8 refuses 3.3.1 2600 states (in-game
  saves unaffected); FCEU 2.6.6 no longer loads mapper 101/151 ROMs;
  retired cores' states stay listed but can't load ("core is gone")
  except Jaguar, which migrates; libretro core options reset to defaults
  (stored under new keys).

**Settings and iCloud**

- [ ] Two devices with different sync on/off and CloudKit/iCloud Drive
      choices: upgrade one, launch, then upgrade the other. Each keeps its
      own choice (fixed `8c8785d28c`).
- [ ] CloudKit: first launch uploads battery saves, screenshots, cheats and
      skins once (new); no duplicate `File` records in the CloudKit
      dashboard; record counts stable on second launch.
- [ ] tvOS with default settings: sync content type now defaults to
      metadata-only. Confirm whether tvOS battery saves still reach iCloud
      and ROMs added on iOS appear; decide if that default is intended.
- [ ] Defaults that changed for users who never touched them: timed
      autosaves now off, title normalization now on, library zoom reset,
      tvOS web server (`webDavAlwaysOn` removed). Confirm each is intended.
- [ ] Plus/subscriber: upgrade offline, cold-launch twice; Plus stays
      unlocked and iCloud sync is not turned off.

**Cores and platforms**

- [ ] 3DS game with no preferred core: note which core launches (emuThree
      or Azahar) and whether its save is found.
- [ ] Jaguar boots (virtualjaguar is a local dylib: check
      `virtualjaguar.libretro.framework` is in the IPA).
- [ ] 3DO with `panafz10-patched.bin` in BIOS (renamed entry, same MD5).
- [ ] TopShelf is empty until the app is opened once after the update
      (expected), then shows recents.

**App Store packaging**

- [ ] Archive validates: provisioning profiles include the new entitlements
      (extended virtual addressing, keychain group
      `com.joemattiello.shared`) and the new `ROM File ProviderUI` App ID.
- [ ] Files app: the Provenance location still opens and imports.

### Retired native cores (pruning PR, `feature/prune-dead-cores`)

Migrations run on first launch after the update; use a library that existed
before it (or seed the files below by hand, then relaunch).

- [ ] DS, `melondsds`: put a native melonDS battery file at
      `Save States/<rom>/<rom>.sav`, launch the app once, then boot the game
      through `melondsds` (Core options / per-game core): the save is there
      (`Battery States/<rom>/<rom>.srm` exists). Repeat with the default
      `melonds` replacement.
- [ ] DS, `desmume`: put a DeSmuME2015 `Save States/<rom>/<rom>.dsv` in place,
      launch the app once, boot the game in `desmume`: the save loads.
      UNVERIFIED conversion (the audit asks for this check): the migration
      moves the `.dsv` as is and does not strip its 122-byte footer. If the
      save is missing or garbled, record it as a defect.
- [ ] Pokemon Mini `.eep` carries over in `pokemini`.
- [ ] Deprecated natives still work (Atari800, Bliss, CrabEMU, Gambatte, VBA-M):
      a game with a native save state on each still loads it. The picker lists
      them as "<name> (Deprecated)" after the libretro cores, libretro cores
      carry the RetroArch mark; Settings → Cores shows a DEPRECATED badge; an
      existing default-core preference on them is kept.
- [ ] One game per other retired system boots through its replacement:
      Odyssey2 (`o2em`), PS1
      (`mednafen_psx_hw`, then `pcsx_rearmed`), Saturn (`yabause`), N64
      (`mupen64plus_next`), Jaguar (`virtualjaguar`, native v13 states load),
      3DO (`opera`), ZX Spectrum (`fuse`), Palm (`mu`), Mac (`minivmac`),
      Supervision (`potator`), music files (`gme`).
- [ ] Settings → Cores: none of the 27 pruned native cores is listed (unsupported cores off).
      Libretro cores no longer carry a "(RetroArch)" suffix; native cores still list first.
- [ ] A save state made with a retired core is still listed, labelled with the retired core.
      Opening it shows the "no longer included in Provenance" alert, not "install the core".
- [ ] Lite (AppStore) build, which bundles no libretro dylibs: the pruned systems
      are unavailable (accepted loss); the app does not crash on a library that has them.

### Emulation-lock deadlocks (pause + quit off the main thread)
- [ ] Quit to the library from a native core (e.g. Genesis Plus GX), a thin
      core (e.g. snes9x libretro) and a thin blocking core: returns promptly,
      no freeze, no `stopEmulationAfterLoopExits ... joining on the main
      thread` warning in the log.
- [ ] Regression only: quit 3DS (Azahar) and Dolphin. They run their own
      emulation thread and still join it on main; this fix does not cover them.
- [ ] Quit while a thin core is still booting (tap Quit on the loading
      screen): no crash, and the next launch boots.
- [ ] Pause/resume repeatedly, then save and load a state right after pausing:
      the state loads correctly.
- [ ] Atari 2600 light-gun game (an XG-1 cart) and trackball via the companion
      controller: aim, fire and movement still register.
- [ ] HW-render thin cores, teardown off main (`fix/thin-quit-teardown-deadlock`):
      flycast on Vulkan, flycast on GL (`reicast_` renderer option), and one GL
      core such as mupen64plus_next. For each, after ~1 min of play with timed
      autosaves on:
      - quit from the pause menu;
      - Save & Quit;
      - swipe the app away from the app switcher while in gameplay.

      Pass: no freeze, no 0x8BADF00D ("Failed to terminate gracefully") in
      Analytics Data, and the game relaunches. Every quit logs
      `calling context_destroy before retro_deinit` from the
      `PVThinLibretro-Teardown` thread, then `core teardown took X s (clean)`.
      Note X for each core: anything near 3 s is close to the bound. A teardown that hangs logs `core
      teardown did not finish within …` instead of killing the app; after that,
      relaunching the same core shows "still shutting down" until it finishes,
      or until the app restarts. Save & Quit's state loads on the next launch,
      and SRAM (a DC VMU or N64 save) survives all three paths.

### Programmatic touch overlay (Phase 1, `PVTouchOverlay`, toggle on by default)
- [ ] Fresh install, no user skins: overlay appears on all 13 bound systems
      (NES, GB, GBC, SNES, GBA, Genesis, 32X, Sega CD, N64, PS1, GameCube,
      Wii, DS). A tester with installed skins must pick Built-in first.
- [ ] Every button, d-pad diagonals and sticks press the right inputs per
      system (watch Genesis 6-button X/Y/Z, N64 C cluster, GC analog L/R + Z,
      Wii Nunchuk C/Z, PS1 L3/R3 via stick tap).
- [ ] Floating menu button stays visible and tappable above the overlay on
      every system, both orientations (no Phase 1 template has a menu control).
- [ ] Rotation keeps the overlay (no drop to the classic pad, Dolphin
      included); picture follows the overlay's screen frames.
- [ ] Stage Manager / split-view resize on iPad relays out without overlap.
- [ ] Scaling-mode change in the pause menu re-applies to the picture.
- [ ] DS: stylus taps land on the bottom screen (Metal split) and in
      landscape (single picture); Start/Select/X/Y/L/R work.
- [ ] Thin-wrapper late geometry: PSP/PS1 resolution switches do not shift
      the layout; Dolphin GC/Wii render view sits inside the picture frame.
- [ ] Physical controller connected: Genesis 6-button games keep X/Y/Z; a
      saved Port Devices choice survives relaunch.
- [ ] Boot variant push: untouched PS1 game shows DualShock in Port Devices
      once running; Genesis stays on "Joypad Auto" unless a variant is picked.
- [ ] Pause menu → Controller Layout: Genesis 3/6, PS1 Digital/DualShock,
      Wii Remote/Nunchuk, GameCube; "This game" vs "All <system> games";
      persists across relaunch. NES shows no tile.
- [ ] Editor: long-press empty space and Pause → Edit Layout both open it;
      game pauses while editing; toolbar clear of Dynamic Island/notch; move,
      pinch/handle resize, detach a button, undo/redo, Done asks This game /
      All games; relaunch shows the saved layout; Reset Pad; rotating
      mid-edit saves and closes the editor.
- [ ] Resting a thumb just outside a control for 0.5 s must NOT open the
      editor during play.
- [ ] Advanced → Programmatic Touch Overlay OFF: classic pad / generated
      default skin return; Dolphin returns to explicit skin selection.
- [ ] Overlay Style Flat / Glossy / Outline render and stay legible at low
      opacity; global opacity and scale sliders apply.
- [ ] 120 Hz ProMotion: two thumbs held + stick motion stays smooth
      (watch log volume from `analogStickMoved`).
- [ ] Packaged skin that supports one orientation only: rotate both ways,
      overlay fills the unsupported orientation and the skin returns.

### Fixes shipped alongside (same develop push)
- [ ] On-screen keyboard (DOS/Atari ST/C64/MSX): bottom key rows register;
      taps above the sheet reach the skin; a skin with `keyboardOverlay`
      toggles the app keyboard; 44pt keys fit in landscape on a notched phone.
- [ ] DS dual-screen skin (thin melonDS and DeSmuME): both screens upright
      and in the right order (vertical flip was corrected); stylus registers
      with a non-zero screen gap; skin swap button exchanges screens and the
      stylus follows.
- [ ] Atari 2600 Color/B&W and difficulty switches: pause-menu tiles change
      the game (e.g. Combat tank colours); skin switches select the right
      position; Manic `tvType` single-token skins alternate correctly.

### Shader library and filter browser (2026-10-12)
- [ ] First build fetches the slang library (Scripts/shaders/fetch_slang_shaders.py);
      the app bundle has `SlangShaders/` (~870 presets) and Settings → Display
      Filters lists "Search 874 filters" in the browser.
- [ ] Pause menu → Screen Filter opens the browser; This Game / This System /
      Everywhere each stick, and the paused game redraws with the choice.
- [ ] Heavy multi-pass presets (crt-royale, guest-advanced) run at full speed on
      an older device; a preset still compiling shows the plain picture briefly.
- [ ] Shader Settings tile edits parameters live; Reset and Reset All work;
      search appears for presets with many settings.
- [ ] Thumbnails use the paused game frame (software cores) or the sample scene.
- [ ] Favorites and parameter edits sync between two devices on the same iCloud
      account (key-value store), and removing a favorite on one sticks.
- [ ] Skin with its own CIFilter: "Skin's Filter" appears; picking a shader
      replaces it, Off/Skin's Filter brings it back.
- [ ] VHS/CRT stay inside the picture during the first seconds of launch with a
      skin, after rotation and after switching skins.
- [ ] Non-linear stretch (Settings → Scaling Mode) in landscape: picture fills
      the width, centre keeps its shape; Gentle/Balanced/Full differ.
- [ ] tvOS: browser and editor are usable with the Siri Remote (focus, steppers).
- [ ] Dolphin (Metal backend) and native PPSSPP: a library preset (e.g. crt-geom)
      and a Provenance filter both render; picking one in the pause menu takes
      effect on the next frame; switching to Off restores the plain picture.
- [ ] DS / 3DS dual-screen skins and Azahar: no Screen Filter / Shader Settings
      tiles (shaders do not apply to dual-screen layouts).
- [ ] Skin CIFilters render (they never did before Oct 13 2026): a skin whose game
      screen has filters (e.g. UITesting GBA-Test on iPad portrait: blur + colour
      controls) shows them, upright (a vignette or centred blur sits where the skin
      puts it); Skin's Filter / Off / a shader in the pause menu switch them live,
      also while paused. The picture's edges stay opaque (no skin showing through).
- [ ] A skin whose only filtered screen is a full-size backdrop (blurred background
      behind the game, Delta edge-to-edge style): the game stays sharp, no
      "Skin's Filter" option. Backdrops themselves are not drawn.
- [ ] DS skin with per-screen filters: each screen gets its own, with a shader
      selected too (shaders can't draw there, so they don't silence skin filters);
      with the LCD look on, filtered screens stay without the grid.
- [ ] Frame rate with a skin filter on an older device (A12/A13), single screen and DS.
- [ ] Settings → Display Filters → "LCD look on dual-screen handhelds" (default
      off). DS skin on melonDS DS (thin) and DeSmuME: both screens get a pixel grid
      on the DS's own pixels, slight softness and muted colour; screens upright, no
      seam or colour bleed between them; portrait and landscape; swap screens; the
      programmatic touch overlay. Toggle mid-game from the pause menu's settings:
      takes effect on the next frame, also while paused.
- [ ] Same toggle on an Azahar 3DS skin: grid only (no softness or colour change),
      aligned with both screens' pixels (400 and 320 wide). Check Azahar fills the
      skin's screen rects exactly; if it letterboxes inside them the grid is off.
      Touch on the bottom screen still works; grid follows rotation and skin changes.
      Azahar's swap-screens option: the grid follows the screen actually in each rect.
      Switch from a 3DS dual-screen skin to a single-screen skin, then to skins off:
      no grid left over the picture.
- [ ] DS LCD look frame rate on an older device (A12/A13): no dropped frames.

### Multi-file games from iFly / iCube share sheet
- [ ] iFly: share a GDI game whose tracks mix `.bin` and `.raw` (e.g. a 3-track
      set). Provenance appears in the share sheet; one game imports under
      Dreamcast with all tracks beside the .gdi in its own folder,
      `ROMs/com.provenance.dreamcast/<gdi name>/`, and it boots on flycast. No
      stray `track02.raw` failure in the import queue; the log has one
      `[IMPORT] <name>.gdi and N file(s) it lists → …/<folder>/` line.
- [ ] Share a second GDI game with the same track names (`track01.bin`, …) after
      the first one finished importing, and again with both shared in one go:
      each lands in its own folder, the first game's tracks are untouched, and
      both boot. Two different games both named `disc.gdi` go to `disc/` and
      `disc-2/`.
- [ ] Two different Dreamcast games whose `.gdi` files are byte-identical (same
      track layout, e.g. both `track01.bin`/`track02.raw`/`track03.bin` at the
      same LBAs): both import and both boot, one after the other and in one go.
      A set is now keyed by its data track (gdi: the last type-4 track; cue: the
      first MODE1/MODE2 file; m3u: derived from disc 1), not the index text.
- [ ] Share the same GDI game a second time: it is still caught as the same game
      (`[IMPORT] … is the same game as …`), both for a game imported with this
      build and for one imported before it.
- [ ] Games imported before this build keep their ids: their save states,
      per-game settings, cheats and CloudKit records are still attached, and
      nothing is re-uploaded or duplicated in the library after updating.
- [ ] RetroAchievements: a cue/bin (PSX) and a GDI (Dreamcast) set game imported
      with this build is still identified (achievements list loads).
- [ ] A redump PSX, Saturn or Sega CD cue/bin set (unmodified `.cue`) imported
      with this build gets its OpenVGDB title, region and box art, the same as
      before the data-track id.
- [ ] CloudKit: a cue or GDI set imported with this build uploads, and downloads
      and boots on a second device.
- [ ] Rescan (Settings › Library › Scan ROM Directories) with a set folder whose
      game was removed from the library: the game comes back; a DOS game folder
      with a `.cue` inside is not imported as a disc set.
- [ ] Delete a game that lives in a set folder: the folder is gone; a flat game
      with a `track01.bin` of its own in the same system folder is untouched.
- [ ] CloudKit: with ROM sync on, import a GDI set on one device and download it
      on another: it lands in `ROMs/com.provenance.dreamcast/<gdi name>/` there
      too and boots.
- [ ] A flat cue/bin or GDI game imported before this build still launches, and
      saves for it are where they were.
- [ ] iFly: share a NAOMI zip + CHD (e.g. `ikaruga.zip` + `gdl-0010.chd`): the
      zip imports under NAOMI, `ROMs/com.provenance.naomi/ikaruga/gdl-0010.chd`
      exists, the CHD is not imported as a Dreamcast game, and the game boots
      (flycast finds the GD-ROM under `{stem}/`). Imports has no leftover
      `.archive-companions` folder.
- [ ] iFly: share an .m3u multi-disc set (each disc a .gdi or .cue with tracks):
      one game imports with every disc and track; disc swap works in game.
- [ ] iCube: share a single-file disc image (.rvz/.iso): imports after ~3 s as before.
- [ ] Share the same file twice from Files ("Open in"): the original stays in
      Files, the second copy imports (as `name-1.ext`), and `Documents/Inbox` is
      empty afterwards.

### Carried over from earlier sessions (see memory notes)
- [ ] Background/resume: no main-thread deadlock on resume (Metal drawable).
- [ ] Dolphin scaling modes (Aspect Fill / Integer / Native) on device.
- [ ] Thin netplay (gpSP, melonDS DS) between two devices over Bonjour.
- [ ] Jaguar CD boot via the HLE virtualjaguar dylib.
- [ ] Flycast render-target crash on iPad (dylib-side fix).

## Verified
_(move items here with the TestFlight build number)_
