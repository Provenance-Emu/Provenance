# Release smoke tests (rolling)

Device checks that code review and simulator tests cannot cover. Run the
"Next release" block on a real iPhone (notched) and iPad before each
TestFlight; move items to "Verified" with the build number once they pass,
delete them a release later. Add new items at the top of "Next release".

## Next release

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
