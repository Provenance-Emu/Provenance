# Native core audit — what is really used (2026-10-10)

Static audit of every `Cores/<X>` directory against the app embed phases, the core plists and
`CoresRetro/RetroArch/scripts/cores.yml`. Source of truth for the pruning batch of the
dev-velocity session (`2026-10-10-dev-workspace-design.md`). Nothing here was run on a device.

Variants: L = Provenance-Lite, LA = Provenance-Lite (AppStore), S = Provenance, XL = Provenance-XL,
AS = Provenance (AppStore), UD = Provenance-UnderDevelopment. "Dylib" = same emulator in `cores.yml`
served by the thin wrapper.

## Decisions

| Verdict | Count | Cores |
|---|---|---|
| KEEP | 8 | Azahar, FCEU, Genesis-Plus-GX, Mednafen, Mupen64Plus, ProSystem, snes9x, Stella |
| KEEP (native-only reason) | 4 | Dolphin (AppStore-legal build, netplay, cheats, cheevos), mGBA (lockstep link cable, cheats), PicoDrive (sole 32X/Sega CD provider, cheevos maps), TGBDual (dual-GB link) |
| RETIRE | 24 | BeetlePSX, Debug, DosBox, DuckStation, FreeIntv, GameMusicEmu, Gearcoleco, JollyGoodEmulation, Mini_vMac, Mu, Mupen64Plus-NX, Play, Potator, Reicast, Sudachi, VecX, VirtualJaguar, Yabause, fuse, opera, pcsx_rearmed, sm64ex, snesticle, supergrafx |
| RETIRE after save check | 8 | Bliss, CrabEMU, Desmume2015, O2EM, PokeMini, VisualBoyAdvance-M, emuThree, melonDS |
| KEEP (deprecated) | 2 | Atari800, Gambatte: the only core for their systems for years, so users have states on them; shipped, labelled "(Deprecated)", libretro replacement preferred (`PVCore.deprecatedCores`) |
| UNSURE | 4 | PPSSPP (native vs thin default?), fmsx (#3709 trackpad mouse ported to `fmsx`/`bluemsx` dylibs?), 4DO (is `opera` acceptable for 3DO; native has cheevos), ep128emu (only EP128 core, XL-only, no dylib) |

Also dead: embedded frameworks with no producing project — `PVLibRetro`, `PVFreeDO`, `PVSnesticle`,
`PVMiniVMac`, `PVYabause`, `PVPCSXRearmed` (UD only) and the XL-only cmake `PVDosBoxRetro`,
`PVMelonDSRetro`, `PVMiniVMacRetro`. Disabled shells still compiled and embedded: fMSX (L LA S XL),
VecX (LA S XL AS), DosBox (AS UD), Desmume2015 (LA AS UD), melonDS (S XL AS UD).

Qualifiers:
- A soft-retirement mechanism exists: `PVCore.retiredCoreReplacements` + `RetiredCoreMigration`
  (1e1abfdadb) retired native Jaguar for `virtualjaguar.libretro.framework`; the PV target is still
  embedded. CLAUDE.md still lists Jaguar and "Flycast" as active native cores (stale; no `Cores/Flycast`).
- Natives with no same-emulator dylib: PicoDrive, TGBDual, CrabEMU, 4DO, Bliss, ep128emu, FCEUX,
  Azahar, emuThree, DuckStation, snesticle. These cannot be retired on "dylib covers it" alone.
- Lite (AppStore) has no libretro module phase, so a RETIRE row embedded in LA removes that system
  from Lite. `build.yml` no longer builds Lite (AppStore).

## Per-core table

| Core dir (PV target) | Wraps | Embedded in | Flags | Dylib | Native unique value | Last touch | Rec |
|---|---|---|---|---|---|---|---|
| 4DO (PVFreeDO-Dynamic) | OpenEmu 4DO fork | LA S XL AS | — | none (`opera` differs) | RetroAchievements (Aug 2026) | 2026-08-12 | UNSURE |
| Atari800 (PVAtari800-Dynamic) | atari800 fork | LA S XL AS | — | `atari800` | cheevos, mouse | 2026-10-02 | KEEP (deprecated): native save states don't load in `atari800`/`a5200` |
| Azahar (PVAzahar) | Azahar fork | L LA S XL AS | — | none | JIT, dual screen, skins, cheats | 2026-10-09 | KEEP |
| BeetlePSX (PVBeetlePSX) | beetle-psx, PVLibRetroCoreBridge | LA XL AS | — | `mednafen_psx(_hw)` | none | 2026-04-01 | RETIRE |
| Bliss (PVBliss-Dynamic) | OpenEmu Bliss | LA S XL AS | — | none (`freeintv` differs) | none | 2026-05-09 | RETIRE-AFTER-SAVE-CHECK |
| CrabEMU (PVCrabEmu-Dynamic) | CrabEmu | LA S XL AS | — | none (SMS via GPGX) | none | 2026-03-17 | RETIRE-AFTER-SAVE-CHECK |
| Debug | stub | none | — | — | none | 2024-05-02 | RETIRE |
| Desmume2015 (PVDesmume2015) | desmume2015, PVLibRetroCoreBridge | LA AS UD | PVDisabled since 2021 | `desmume` (modern) | dual screen/stylus (thin has it) | 2026-10-07 | RETIRE-AFTER-SAVE-CHECK |
| Dolphin (PVDolphin) | iCube dolphin-ios | S XL AS | JIT optional | `dolphin` (appstore:false) | netplay, cheats, cheevos, AppStore-legal | 2026-10-08 | KEEP |
| DosBox (PVDosBox) | dosbox-pure, PVLibRetroCoreBridge | AS UD (+XL Retro) | PVDisabled | `dosbox_pure` | none | 2026-09-29 | RETIRE |
| DuckStation (PVDuckStation) | DuckStation fork | none | — | Beetle/pcsx dylibs | placeholder | 2026-08-05 | RETIRE |
| FCEU (PVFCEU) | FCEUX fork | LA S XL AS | — | none (fceumm/nestopia/mesen differ) | lightgun, Game Genie, netplay, cheevos | 2026-10-08 | KEEP |
| FreeIntv (PVFreeIntv) | FreeIntv, PVLibRetroCoreBridge | S XL | — | `freeintv` | none | 2026-04-01 | RETIRE |
| Gambatte (PVGambatte-Dynamic) | Gambatte | XL | — | `gambatte`, `sameboy` | cheats, full GB rcheevos map | 2026-10-02 | KEEP (deprecated): native save states don't load in `gambatte`; `.rtc` not carried by the thin wrapper |
| GameMusicEmu (PVGME) | libretro-gme | LA S XL AS | — | `gme` | none | 2026-04-01 | RETIRE |
| Gearcoleco (PVGearcoleco) | Gearcoleco | S XL | — | `gearcoleco` | none | 2026-07-22 | RETIRE |
| Genesis-Plus-GX (PVGenesis) | GPGX fork | LA S XL AS | — | `genesis_plus_gx(_wide)` | lightgun, cheats, cheevos maps | 2026-10-02 | KEEP |
| JollyGoodEmulation | submodule | none | — | — | unwired | 2026-03-06 | RETIRE |
| Mednafen (PVCoreMednafen) | mednafen fork | LA AS (S XL static) | — | many `mednafen_*` | port devices, netplay, cheats, cheevos, multitap | 2026-10-05 | KEEP |
| Mini_vMac (PVMiniVMac) | libretro-minivmac | UD (+XL Retro) | — | `minivmac` | none | 2026-04-01 | RETIRE |
| Mu (PVMu) | Mu | S XL | — | `mu` | none | 2026-04-01 | RETIRE |
| Mupen64Plus-NX | mupen64plus-nx | XL | JIT | `mupen64plus_next` | none | 2026-07-22 | RETIRE |
| Mupen64Plus (PVMupen + 5 fws) | mupen64plus + plugins | LA S XL AS | JIT | `mupen64plus_next` | netplay, cheats, cheevos, plugin choice | 2026-10-05 | KEEP |
| O2EM (PVO2EM) | OpenEmu O2EM | LA XL AS | — | `o2em`, `m2000` | none | 2026-08-26 | RETIRE-AFTER-SAVE-CHECK |
| PPSSPP (PVPPSSPP) | PPSSPP native | LA S XL AS | — | `ppsspp` | netplay, cheats, cheevos, own renderer | 2026-10-05 | UNSURE |
| PicoDrive (PVPicoDrive-Dynamic) | picodrive | LA S XL AS | — | none | 32X/Sega CD, cheats, cheevos | 2026-10-02 | KEEP |
| Play (PVPlay) | Play- | none | JIT required | `play` | none | 2026-09-26 | RETIRE |
| PokeMini (PVPokeMini-Dynamic) | PokeMini | LA S XL AS | — | `pokemini` | cheevos only | 2026-10-02 | RETIRE-AFTER-SAVE-CHECK |
| Potator (PVPotator) | potator | LA S XL | — | `potator` | none | 2026-04-01 | RETIRE |
| ProSystem (PVProSystem-Dynamic) | ProSystem | LA S XL AS | — | `prosystem` | lightgun, cheevos | 2026-10-02 | KEEP |
| Reicast (PVReicast) | reicast | none | — | `flycast` | none | 2026-07-22 | RETIRE |
| Stella (PVStella-Dynamic) | stella fork | LA S XL AS | — | `stella*` | lightgun, cheats, cheevos | 2026-10-07 | KEEP |
| Sudachi | cmake dir | none | — | — | unwired | 2024-08-14 | RETIRE |
| TGBDual (PVTGBDual-Dynamic) | tgbdual | LA S XL AS | — | none | dual-GB link, cheevos | 2026-10-02 | KEEP |
| VecX (PVVecX) | libretro-vecx | LA S XL AS | PVDisabled | `vecx` | none | 2026-09-29 | RETIRE |
| VirtualJaguar (PVVirtualJaguar-Dynamic) | Core-VirtualJaguar | LA S XL AS | soft-retired | `virtualjaguar` (local) | none left | 2026-10-04 | RETIRE |
| VisualBoyAdvance-M (PVVisualBoyAdvance-Dynamic) | vbam | LA S XL AS UD | — | `vbam`, `mgba`… | cheats, GBA save RAM for cheevos | 2026-10-02 | RETIRE-AFTER-SAVE-CHECK |
| Yabause (PVYabause) | yabause | UD | — | `yabause` | none | 2026-04-27 | RETIRE |
| emuThree (PVEmuThree) | emuThreeDS | L LA S XL AS | JIT | none | superseded by Azahar; migrator exists | 2026-10-08 | RETIRE-AFTER-SAVE-CHECK |
| ep128emu (PVEP128Emu) | ep128emu-core | XL | — | none | only EP128 core | 2026-07-22 | UNSURE |
| fmsx (PVfMSX) | fmsx fork | L LA S XL | PVDisabled | `fmsx`, local `bluemsx` | trackpad mouse #3709 | 2026-09-29 | UNSURE |
| fuse (PVFuse) | fuse-libretro | XL | — | `fuse` | none | 2026-07-22 | RETIRE |
| mGBA (PVCoremGBA-Dynamic) | mgba fork | S XL | — | `mgba` | lockstep link cable, cheats | 2026-10-05 | KEEP |
| melonDS (PVMelonDS) | legacy melonDS libretro.cpp | S XL AS UD | PVDisabled since 2022 | `melonds` (same code), `melondsds` | LocalMP netplay, AR cheats | 2026-10-07 | RETIRE-AFTER-SAVE-CHECK |
| opera (PVOpera) | opera-libretro | XL | — | `opera` | none | 2026-07-22 | RETIRE |
| pcsx_rearmed (PVPCSXRearmed) | pcsx_rearmed | UD | — | `pcsx_rearmed` | none | 2026-07-22 | RETIRE |
| sm64ex | game port | none | — | — | unwired | 2022-01-22 | RETIRE |
| snes9x (PVSNES + snes9x fw) | snes9x fork | LA S XL AS | — | `snes9x*` | lightgun, mouse, cheevos (SA-1) | 2026-10-02 | KEEP |
| snesticle (PVSnesticle) | SNESticle | UD | — | none | stub | 2026-03-29 | RETIRE |
| supergrafx (PVSupergrafx) | beetle-supergrafx, 0 LOC | XL | — | `mednafen_supergrafx` | none | 2026-03-21 | RETIRE |

## Native DS cores — save compatibility

- Both register `com.provenance.ds`, both `PVDisabled` since creation, never selectable in App Store
  builds ("Unsupported Cores" hidden on iOS App Store). Only sideload users with the toggle could run them.
- Neither has save states (`supportsSaveStates` NO). Only battery files matter.
- The legacy host answered `GET_SAVE_DIRECTORY` with the **Save States** dir; thin answers with the
  **Battery Saves** dir. Native DS battery files therefore sit in Save States and were likely never
  synced as battery saves.
- Formats: native melonDS writes raw `<rom>.sav` (same code as the `melonds` dylib); `melondsds`
  exposes SAVE_RAM and thin persists raw `<rom>.srm`. DeSmuME2015 writes `<rom>.dsv` = raw data +
  122-byte footer (82-byte text, 24 bytes u32 fields, 16-byte cookie `|-DESMUME SAVE-|`); with no
  `.dsv` it imports a raw `.sav`. The buildbot `desmume` dylib's `.dsv` handling is unverified.
- Migration: move `<rom>.sav`/`<rom>.dsv` from Save States to Battery Saves; for `melondsds` also copy
  `.sav` → `.srm` (thin `memcpy(min(size))`, size mismatch is silent); `.dsv` → raw `.sav` = strip the
  last 122 bytes.
- **Verdict:** safe to retire both; add the one-time move to `RetiredCoreMigration`; confirm one
  migrated save in `melondsds` and `desmume` on a device.
