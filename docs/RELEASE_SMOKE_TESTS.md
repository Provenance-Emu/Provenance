# Release smoke tests (rolling)

Device checks that code review and simulator tests cannot cover. Run the
"Next release" block on a real iPhone (notched) and iPad before each
TestFlight; move items to "Verified" with the build number once they pass,
delete them a release later. Add new items at the top of "Next release".

## Next release

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
- [ ] GBA: a VBA-M `Battery States/<rom>/<rom>.sav2` shows up in `vbam` after first launch.
- [ ] Pokemon Mini `.eep` carries over in `pokemini`. Genesis/SMS/GG game with a
      CrabEMU `.sav` loads it.
- [ ] Deprecated natives still work: a GB game with a native Gambatte save state
      and an Atari 800/5200 game with a native Atari800 state both still load
      those states. The picker lists "Gambatte (Deprecated)" / "Atari 800
      (Deprecated)" after the libretro cores; Settings → Cores shows a
      DEPRECATED badge; an existing default-core preference on them is kept.
- [ ] One game per other retired system boots through its replacement:
      Intellivision (`freeintv`), Odyssey2 (`o2em`),
      ColecoVision (`gearcoleco`), SMS/Game Gear (Genesis Plus GX), PS1
      (`mednafen_psx_hw`, then `pcsx_rearmed`), Saturn (`yabause`), N64
      (`mupen64plus_next`), Jaguar (`virtualjaguar`, native v13 states load),
      3DO (`opera`), ZX Spectrum (`fuse`), Palm (`mu`), Mac (`minivmac`),
      Supervision (`potator`), music files (`gme`).
- [ ] Settings → Cores: none of the 30 pruned native cores is listed (unsupported cores off).
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

### Carried over from earlier sessions (see memory notes)
- [ ] Background/resume: no main-thread deadlock on resume (Metal drawable).
- [ ] Dolphin scaling modes (Aspect Fill / Integer / Native) on device.
- [ ] Thin netplay (gpSP, melonDS DS) between two devices over Bonjour.
- [ ] Jaguar CD boot via the HLE virtualjaguar dylib.
- [ ] Flycast render-target crash on iPad (dylib-side fix).

## Verified
_(move items here with the TestFlight build number)_
