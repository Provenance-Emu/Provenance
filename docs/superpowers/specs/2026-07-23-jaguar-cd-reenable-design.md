# Re-enable Atari Jaguar CD (beta)

**Date:** 2026-07-23
**Status:** Approved design → implementation

## Goal

Re-enable the Atari Jaguar CD system (currently disabled) as a **beta** system
(visible, not disabled), served by the custom `virtualjaguar` libretro dylib
whose HLE runs most Jaguar CD games with **no CD BIOS**. Runs under the default
**thin** libretro wrapper on both iOS and tvOS.

## Background / ground truth

- `AtariJaguarCD` (`com.provenance.jaguarcd`, openVGDB DB id 8) is already a
  fully-wired separate `SystemIdentifier`: `isBeta = true`, controls, controller
  VC, DeltaSkins, UTIs (`com.provenance.rom.jaguarcd`), box-art, DB ids. Nothing
  in that surface needs changing.
- It is held back by exactly two things:
  1. `PVSupported = <false/>` in the systems plist (two identical copies).
  2. `com.provenance.jaguarcd` commented out of the thick RetroArch
     `Core.plist` (`CoresRetro/RetroArch/PVRetroArch/Core.plist:1222`), with a
     stale TODO about the *old* dylib crashing on CD content (tvOS).
- Custom dylib (`CoresRetro/RetroArch/modules/virtualjaguar_libretro_{ios,tvos}.dylib`,
  present in-tree for both platforms) advertises
  `validExtensions = j64|jag|rom|abs|cof|bin|prg|cue|cdi|iso` and a boot-mode
  core option `HLE (no BIOS, recommended) / BIOS (experimental) / Auto`.
- Thin routing: `PVDynamicLibretroCoreScanner` assigns systems to a thin core by
  intersecting the dylib's `validExtensions` with the *enabled* systems'
  `PVSupportedExtensions`. So enabling the system with CD extensions is what
  makes `virtualjaguar` pick up `jaguarcd` under the thin wrapper.

## Changes (data-only)

1. **Un-disable the system** — `PVSupported` `false → true` in BOTH copies:
   - `PVLibrary/Sources/PVLibrary/Resources/systems.plist` (~L5904)
   - `PVCoreLoader/Sources/PVCoreLoader/Resources/systems.plist` (~L5718)

2. **CD extensions → match the dylib.** Set Jaguar CD `PVSupportedExtensions`
   from the current `iso, cue, m3u` to **`cue, iso, cdi`**:
   - add `cdi` (dylib supports it),
   - drop `m3u` (dylib does not advertise it; Jaguar CD titles are single-disc —
     YAGNI, revisit if a multi-disc title appears),
   - do NOT add `bin` (it is the cue's data track and a cart extension; routing
     on it would collide with many systems),
   - do NOT add `chd` (unsupported by the dylib, explicitly excluded).

3. **Add `PVUsesCDs = true`** to the Jaguar CD entry in both plists (currently
   absent — a recorded gap). Verified benign: it adds `cue/iso/cdi` to
   `supportedCDFileExtensions` (correct import routing) and shows a "CD"
   capability tag; it does not force disc-swap UI on single-disc games.

4. **Uncomment `com.provenance.jaguarcd`** in the thick RetroArch
   `Core.plist:1222` and replace the stale crash-TODO with a note that the HLE
   dylib now handles CD content. This covers legacy-wrapper users and documents
   the core→system link. (The thin default is driven by extension-matching, not
   this plist, but keeping both consistent avoids surprises when a user toggles
   `Defaults[.useLegacyRetroArchWrapper]`.)

## Out of scope / no work needed

- **BIOS** — leave the two existing Jaguar CD BIOS entries `Optional = true`.
  HLE is the dylib default; no BIOS required. The dylib also accepts alternate
  BIOS filenames if present, but we do not need to enumerate them for HLE.
- **Compressed `zip` / `7z`** — handled by the importer's archive-extraction
  layer, which extracts and re-detects by inner extension. No per-system work.
- **Native `PVJaguarGameCore`** — untouched; stays cart-only. This keeps Jaguar
  CD unambiguously routed to the RA/thin `virtualjaguar`, while cart Jaguar can
  still use either the native core or the RA core.

## Disambiguation note

`cue`/`iso` are shared with ~12–13 other CD systems and `cdi` with Dreamcast.
This is the same ambiguity every existing CD system already has: known Jaguar CD
games disambiguate via the game DB (MD5 → system 8); unknown discs fall to the
existing user system-selection path. Adding a 14th CD system does not change
that model.

## Verification

- Build succeeds (thin wrapper, both platforms).
- On-device smoke test: import a `.cue` and a `.cdi` Jaguar CD title; confirm the
  app offers `virtualjaguar`, the title boots via HLE (no BIOS present), and
  save states work — on **both iOS and tvOS** (tvOS was the original crash
  platform).
- Confirm cart Jaguar (`.j64`) is unaffected.

## Risk

Low; data-only. The single real risk (thin-wrapper boot on tvOS) is the exact
thing the custom HLE dylib was built to fix and which the author has validated;
the on-device smoke test is the gate.
