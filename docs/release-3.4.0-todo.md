# Provenance 3.4.0 release follow-up tasks

The working list for the 3.4.0 release. Update it in the same commit as the work it tracks.

## First

- [x] **Core picker first pass.** Add the RetroArch logo to libretro cores, show a short reason for the recommended core, and keep save counts and explicit preferences. Start with GB/GBC, GBA, SNES, DS, and 3DS. Recommend Azahar for new 3DS launches where it ships and keep emuThreeDS available for its existing save states. [#3341](https://github.com/Provenance-Emu/Provenance/issues/3341) · [PR #3814](https://github.com/Provenance-Emu/Provenance/pull/3814)

## After the picker

- [ ] **Console mouse smoke test.** Check Mario Paint on native and libretro Snes9x, a known mouse game on Flycast, and a joypad-only game. Verify touch mouse, physical mouse where supported, and the per-game override. Close the remaining mouse epics if the shipped cores pass. This is the smaller follow-up and supplies evidence for the picker badges. [#3329](https://github.com/Provenance-Emu/Provenance/issues/3329) · [#3330](https://github.com/Provenance-Emu/Provenance/issues/3330)
  - Native Snes9x used its CRC list without reading the saved per-game override. The fix was made on `codex/snes-mouse-override` and is on `develop` as `031d5b0846` (merge `82c189375b`). All 35 focused registry tests passed on the rebased commit, including the native override regression. The Objective-C selector compiled against the iOS and tvOS simulator SDKs. The patched Provenance-Dev-UI simulator build succeeded and installed on two iPhone 17 Pro QA simulators. CoreSimulator stalled on app launch after reboot. On a fresh device, FrontBoard initially reported the registered app as unknown, and subsequent launches of Provenance and built-in Safari both hung. Mario Paint never reached gameplay. Verify touch motion in Auto and absence of automatic mouse input after setting Always Off and relaunching. Bundled libretro Snes9x, Flycast, and physical mouse input still need device QA.
  - The source-built Snes9x libretro smoke test booted Mario Paint and Super Mario World. Injected mouse motion changed Mario Paint's rendered frame on SNES controller port 1 only. Both joypad-only runs made zero mouse reads. The libretro wrapper now defaults Mario Paint to port 1 and respects saved port choices (`e0deca6072` on `develop`). All 37 focused registry tests passed. App-level pointer routing still needs a run with the bundled core.
  - Simulator run on 2026-11-13 (Provenance-Dev-UI at `develop`, iPhone simulator on iOS 26.5, native Snes9x). The app launched this time; a later reinstall left the simulator refusing to launch it until a reboot.
    - Auto: Mario Paint booted, the virtual mouse installed by itself, and a touch drag moved the game's hand across the title screen.
    - Always Off: set from Game Info, which saved `MouseGameRegistry.mouseEnabled.<md5> = false`. After a relaunch no virtual mouse installed and the same drag left the hand where it was.
    - Joypad only: Super Mario World installed no virtual mouse.
    - With no input, Mario Paint leaves its title for a self-running demo after about 40 seconds. Do the drag checks before that.
    - Fixed on the way: the simulator drew every 16-bit core at half width with wrong colors (its Metal has no packed 16-bit texture formats, so frames are now expanded to RGBA8 there; devices were never affected). The app's arrow cursor was drawn over the hand the game draws on SNES; it is now hidden. The per-game pointer pickers in Game Info had no labels.
    - Still needs a device: bundled libretro Snes9x, Flycast, and a physical mouse.
- [ ] **LAN netplay smoke test.** Use two peers with the same build, native mGBA, and a known link-capable game. Check discovery, manual join, input from both players, disconnect, and rejoin. Then repeat on one thin libretro core that registers netpacket, such as gpSP. Simulators can exercise the app flow. Use devices to confirm Wi-Fi discovery and permissions. [#2483](https://github.com/Provenance-Emu/Provenance/issues/2483)
  - Simulator run on 2026-11-13: two iPhone simulators on one Mac, Provenance-Dev-UI at `develop`, native mGBA, Super Mario Advance 2. Buttons were pressed through the debug API (`POST /api/debug/input`, which now takes GBA buttons).
    - Passed: hosting from the library and from the in-game menu; Bonjour discovery in the library page and the in-game browser; joining a discovered room; joining by typed address; both games running in step, also across a reset on both; button input on each side; the host's "partner disconnected" notice when the joiner quit; hosting again and rejoining.
    - Fixed on the way, all of which blocked the flow:
      - The pause menu hung at 100% CPU as soon as it opened. Its hardware-switch subscription re-ran the menu rebuild on every redraw. It now skips positions it has already drawn.
      - "Host This Game" launched the game and then did nothing. The first read of the cached "emulation is on" flag returned false, so the pause menu request was dropped with "Core isn't on".
      - The host's waiting room stayed at 1/2 after a join, and the advertised room kept `players=1`. Hosting states that differed only in player count compared as equal, so mGBA (and PPSSPP) never published the change.
      - The port was shown as "55,435".
    - Game data crosses the link (checked later the same day). In Super Mario Advance 2 both consoles choose Multiplayer on the title screen, the host presses Start, picks Classic and presses Start again. Both screens then show the same two-player Mario Bros. game, and moving Mario from the host and Luigi from the joiner shows on both. Seven of seven scripted runs from fresh launches reached that game. The first attempt had gone through Single Player, which never uses the link.
      - One more fix came out of it: linking after the game had booted left the host reading "child" on the cable, so Multiplayer did nothing unless both games were reset after connecting. The driver now sets the parent and child lines when the link connects or drops.
      - The debug API can now host and join without the lobby (`POST /api/debug/netplay`), which is how those runs were scripted.
    - Rough edges from that run, fixed the same day and checked on the two simulators:
      - "Start Game" in the waiting room now closes the netplay screens and the pause menu, and the game resumes.
      - Joining from the in-game browser or by typed address now returns to the game with a "Joined" notice.
      - While a session is up, the in-game Network Play screen shows it ("Hosting a room, 2 of 2 players", or who you are connected to) with Close Room or Leave Room, in place of Host and Browse.
      - A joined player reads "Connected" in the waiting room.
      - On a phone the library hub's search field has its own row, and the multiplayer details form scrolls its notes field and Save above the keyboard.
    - Left as designed: a ROM that is not in the multiplayer catalog must have its details confirmed on every device before Join is enabled.
    - Still needs devices: Wi-Fi discovery between two devices, the local network permission prompt, and a thin libretro netpacket core such as gpSP (the buildbot dylibs cannot load in a simulator).

## Backlog

- [ ] **Core capability coverage.** Verify link cable, mouse, camera, microphone, and netplay support for specific shipped cores before adding badges. Extend the curated recommendations to more systems. [#3341](https://github.com/Provenance-Emu/Provenance/issues/3341)
- [ ] **Internet netplay.** Update the WAN ticket for the current thin wrapper. After LAN passes, scope the first WAN milestone to one supported core and a private invite that connects across two networks without port forwarding. This needs transport design and device testing. [#3087](https://github.com/Provenance-Emu/Provenance/issues/3087)
- [ ] **Swift lock cleanup.** Review Swift-only critical sections in `MouseGameRegistry` and `EntityStores` first. Use scoped locking and evaluate state-owning locks where appropriate. Preserve the timing and shutdown semantics of the bridge locks. [#1681](https://github.com/Provenance-Emu/Provenance/issues/1681)
- [ ] **Disc import.** Add compressed CHD serial reads, define the CRC matching rules for discs without useful serials, and scope the remaining serial-first performance work around the importer's MD5 identity requirement. [#872](https://github.com/Provenance-Emu/Provenance/issues/872) · [#2786](https://github.com/Provenance-Emu/Provenance/issues/2786) · [#2787](https://github.com/Provenance-Emu/Provenance/issues/2787) · [#2788](https://github.com/Provenance-Emu/Provenance/issues/2788)
- [ ] **Diagnostic export smoke test.** On iOS, export and reopen a log bundle from Files. On tvOS, export and download it through WebDAV. File any concrete polish gaps against the affected flow. [#3612](https://github.com/Provenance-Emu/Provenance/issues/3612)
- [ ] **Maintenance reports.** Tighten the controller-audit freshness check so save-state changes that leave the report identical do not trigger a warning. Improve the health monitor's orphan check to account for linked PRs. The workflows manage both report issues. [#3741](https://github.com/Provenance-Emu/Provenance/issues/3741) · [#3666](https://github.com/Provenance-Emu/Provenance/issues/3666)
- [ ] **Input re-recording spike.** Record and replay frame inputs on one Pokémon Mini core. Confirm repeatable checkpoints before planning save-state branching or a timeline editor. [#3680](https://github.com/Provenance-Emu/Provenance/issues/3680)

## Closed in this triage

- [#2810](https://github.com/Provenance-Emu/Provenance/issues/2810) — scoped emulator lock changes
- [#2880](https://github.com/Provenance-Emu/Provenance/issues/2880) and [#888](https://github.com/Provenance-Emu/Provenance/issues/888) — cartridge hash normalization and the original N64 report
- [#3612](https://github.com/Provenance-Emu/Provenance/issues/3612) — log export and import
- [#3335](https://github.com/Provenance-Emu/Provenance/issues/3335), [#3339](https://github.com/Provenance-Emu/Provenance/issues/3339), and [#3331](https://github.com/Provenance-Emu/Provenance/issues/3331) — Flycast mouse selection, per-game override, and mouse detection UI
