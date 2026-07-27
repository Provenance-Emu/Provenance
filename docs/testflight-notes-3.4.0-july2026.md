# Provenance 3.4.0 (TestFlight)

First build in 54 days. 90 commits. This one is heavy on RetroAchievements
correctness, save-data safety, and Dolphin, plus a new beta system.

## Please test first

1. RetroAchievements on SNES, NES, GBA, Game Boy Color, PC Engine, PSP.
   Achievement unlocks were silently broken on several of these — see below.
2. Save states and quickload, especially with achievements hardcore mode on.
3. Importing ROMs that share a filename with something already in your library.
4. GameCube / Wii (Dolphin) — large update, including fast-forward and
   controller layouts.
5. Atari Jaguar CD (new, beta).

## RetroAchievements

Multiple cores were reading the wrong memory addresses, so achievements
either never triggered or triggered incorrectly. If achievements looked dead
for you before, retest:

- Corrected memory mapping for SNES, GBA, PSP, PC Engine, and Game Boy Color
  (Gambatte and TGBDual).
- NES (FCEU) was missing its per-frame achievement update entirely — it never
  evaluated achievements. Now wired.
- SNES cartridge SRAM is now exposed, so achievements that read save memory work.
- Thin-wrapper cores now use the proper libretro memory map instead of guessing.
- Login and session failures are now surfaced on screen instead of failing
  silently, so you can tell when you are not actually connected.
- Hardcore mode is now correctly enforced on paths that previously bypassed it:
  quickload, slow motion, enabling an existing cheat, and thin/RetroArch cores.
- Your RetroAchievements password now lives in the Keychain instead of
  UserDefaults.

Known: a quickload during an achievement session previously risked corrupting
state. The core is now force-paused during quickload. Worth hammering.

## Atari Jaguar CD (new, beta)

Jaguar CD is enabled for the first time, marked beta. It uses a custom
Virtual Jaguar build with high-level emulation, so most games boot without
the Jaguar CD BIOS. Supported disc formats: CUE, ISO, CDI. CHD is not
supported. Compressed (zip/7z) images are handled by the importer.

Also fixed since the first Jaguar CD build: the numeric keypad was missing
from the on-screen controls (it is there now, same 12 keys as cartridge
Jaguar), and Jaguar skins now load automatically for Jaguar CD games instead
of falling back to a generic layout.

This is the least-tested item in the build. Known issue: some CD games boot
and others crash — cause not yet identified. If you hit a crash, please note
the game and the disc format (CUE / ISO / CDI, and whether it was zipped),
and grab the crash report from Settings > Privacy and Security > Analytics.

## Sega arcade: NAOMI, NAOMI 2, Atomiswave (new, beta)

The three Sega arcade boards that run on the flycast core are now playable
systems rather than groundwork. They use the Dreamcast control scheme with an
added Coin button, and Dreamcast skins apply to them.

BIOS: put naomi.zip (NAOMI and NAOMI 2) and awbios.zip (Atomiswave) in the
BIOS folder for the system. Known limitation: titles that need their own
per-game BIOS, such as Ferrari F355, will not boot yet — Provenance only
supports one BIOS set per system.

## GameCube and Wii (Dolphin)

- Core re-baselined to a much newer Dolphin (2509).
- Fast-forward now drives Dolphin's own throttle, so it actually speeds up.
- Controller layout variants supported.
- Graphics Hacks options were never being applied — fixed.
- Core option changes now apply live; previously all but two keys were dropped.
- Performance options exposed, with fastmem and arena gated on device support.
- Anisotropic filtering fixed for the new core API.

## Save data, imports, and cloud

- Importing a ROM whose name matches an existing file no longer risks
  overwriting or losing data on a content mismatch.
- Files are no longer silently dropped when a same-named file already exists.
- A transient iCloud fetch error no longer deletes a local save.
- Zero-byte and orphaned save states are now rejected/skipped instead of
  loading as corrupt.
- Resume no longer unpauses before the background auto-save finishes.
- PicoDrive save states use the core's real state size instead of a hardcoded
  value, fixing bad legacy loads.
- Fixed a launch crash from the Realm v2 database migration.

## Security

- Archive extraction now sanitizes entry paths in the Zip, 7z, and Tar
  backends, including tar-inside-compressed-stream (zip-slip).
- RetroAchievements credentials moved to the Keychain.

## iFly integration and Plus

- Browse, launch, and import games from iFly EMU if you have it installed.
- A Provenance Plus subscription now unlocks iFly Pro automatically, with no
  server and no extra purchase. Expiry is honored, so a lapsed subscription
  stops granting it.

## Performance and memory

- Rasterized skin assets (PDF/SVG) are now disk-cached, including fallback and
  thumbstick paths. Skin-heavy layouts load faster after first use.
- Artwork search is queued and pauses with emulation to avoid large memory
  spikes.
- Web server: better performance, fuller WebDAV support, improved site features.

## Stability and leaks

- Emulator view controller is now torn down on error and close paths; it was
  leaking a full emulator per session.
- Fixed a use-after-free in RetroArch teardown ordering.
- Fixed a background auto-save assertion.
- Camera overlay is removed and released when hidden (was retaining the view).
- Audio mute-switch observer is cancelled on deinit (leaked once per launch).
- Audio engine now stops before rebuilding the graph when a core reports its
  sample rate late, fixing glitchy/bassy audio on some cores.
- Metal no longer reads the current drawable on the main thread during filter
  setup.

## Skins, display, input

- Fixed integer scaling and native resolution mixing pixels with points, which
  produced wrong-sized output.
- Scaling-mode changes now route viewport cores correctly.
- 3DO controls no longer come up dead at boot; a controller port device is
  always pushed.
- tvOS Siri Remote micro-gamepad setup fixed.
- Gamepad manager now observes correctly, so controller connect/disconnect
  updates the UI.

## Notes

- Provenance Lite is buildable again and back in CI. It had been broken for
  roughly four months without anyone noticing, because CI was not building it.
- tvOS Simulator builds work again (a core was producing an empty framework,
  which broke linking for every variant). Device builds were never affected.
