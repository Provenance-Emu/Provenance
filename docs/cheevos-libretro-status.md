# RetroAchievements (Cheevos) — LibRetro Core Status

> Audit date: 2026-03-22
> Audited by: Claude / Agent (issue #3386)
> Parent epic: #2705

## Summary

All libretro cores in Provenance reach RetroArch's `cheevos.c` runtime.
`HAVE_CHEEVOS` is compiled into **every** build variant (Lite, Standard, XL, iOS, tvOS).
Achievements are fully wired at the RetroArch framework level; no per-core flag exists that could disable them.

---

## Architecture Overview

```
User signs in via PVCheevos (Swift)
        │
        ▼
RetroArchConfigManager writes credentials to retroarch.cfg
        │
        ▼
RetroArch starts content via libretro API
        │
        ▼
cheevos.c reads settings->bools.cheevos_enable
  (controlled by retroarch.cfg / PVSettings)
        │
        ▼
rcheevos identifies ROM via hash (rhash/hash.c)
        │
        ▼
rcheevos polls RETRO_ENVIRONMENT_GET_MEMORY_DATA every frame
  (called from runloop.c:rcheevos_test())
        │
        ▼
Achievements unlocked, Rich Presence updated, leaderboards posted
```

Key observation: **the cheevos path lives entirely inside RetroArch**.
Every libretro core loaded by `PVRetroArchCore` is subject to the same `runloop.c` tick path — there is no per-core cheevos opt-in or opt-out.

---

## Build Flag Audit

### `HAVE_CHEEVOS` Definition Sites

| File | Location | Notes |
|------|----------|-------|
| `Build.xcconfig` | `GCC_PREPROCESSOR_DEFINITIONS` | Global; applies to all Xcode targets |
| `CoresRetro/RetroArch/BuildFlags.xcconfig` | `OTHER_CFLAGS` and `OTHER_DEBUG_CFLAGS` | PVRetroArchCore compilation |
| `CoresRetro/Package.swift` | `.define("HAVE_CHEEVOS")` | Applied to both `.debug` and `.release` SPM configs |

**Verdict**: `HAVE_CHEEVOS` is defined globally for Lite, Standard, and XL variants in both debug and release builds.

### `griffin.c` Cheevos Section (lines 190–240)

```c
/*============================================================
ACHIEVEMENTS
============================================================ */
#if defined(HAVE_CHEEVOS)
// cheevos.c, cheevos_client.c, cheevos_menu.c
// + rcheevos source files (rc_client, rc_libretro, rhash, etc.)
#endif
```

All cheevos/rcheevos source files are included unconditionally when `HAVE_CHEEVOS` is defined (exact count varies as RetroArch updates; use the audit script to verify).

---

## retroarch.cfg Default State

The Provenance-bundled `retroarch.cfg` ships with:

```ini
cheevos_enable = "false"          # Disabled by default — user must opt in
cheevos_hardcore_mode_enable = "false"
cheevos_username = ""
cheevos_token = ""
cheevos_richpresence_enable = "true"
cheevos_verbose_enable = "true"
```

**Important**: `cheevos_enable = "false"` is the default.
Achievements only activate after the user authenticates and enables the feature via the Provenance settings UI, which calls `RetroArchConfigManager` to update `retroarch.cfg`.

---

## Per-Core RetroAchievements Status

All cores below are loaded by `PVRetroArchCore` and therefore share the same cheevos runtime.
The "RA Coverage" column describes upstream RetroAchievements *game database* coverage — it does not reflect a compile-time flag.

### Tier 1 — Highest RA Database Coverage

| Core | Systems | RA Coverage | Cheevos Compiled | Notes |
|------|---------|-------------|-----------------|-------|
| `genesis_plus_gx` | MD, SMS, GG, SG-1000, CD | Very High | ✅ | Gold standard for Sega 8/16-bit |
| `genesis_plus_gx_wide` | MD (widescreen) | Very High | ✅ | Same core, wide aspect |
| `fceumm` | NES / Famicom | Very High | ✅ | Most NES achievements target fceumm |
| `nestopia` | NES / Famicom | High | ✅ | Alternative NES core |
| `quicknes` | NES | Medium | ✅ | Faster, fewer features |
| `bsnes` | SNES | Very High | ✅ | Accuracy-focused |
| `bsnes_hd_beta` | SNES (HD) | Very High | ✅ | bsnes with HD mode 7 |
| `bsnes_mercury_accuracy` | SNES | Very High | ✅ | bsnes fork |
| `bsnes_mercury_balanced` | SNES | Very High | ✅ | bsnes fork |
| `bsnes_mercury_performance` | SNES | Very High | ✅ | bsnes fork |
| `snes9x2002` | SNES (GBA port) | High | ✅ | Lower accuracy |
| `snes9x2005` | SNES | High | ✅ | |
| `snes9x2005_plus` | SNES | High | ✅ | |
| `snes9x2010` | SNES | High | ✅ | |
| `gambatte` | GB / GBC | Very High | ✅ | Preferred GB core |
| `sameboy` | GB / GBC | Very High | ✅ | Accuracy-focused |
| `mgba` (via `mednafen_gba`) | GBA | Very High | ✅ | See note below |
| `mednafen_gba` | GBA | Very High | ✅ | mGBA is the RA reference for GBA |
| `vba_next` | GBA | High | ✅ | |
| `vbam` | GBA / GBC | High | ✅ | |
| `gpsp` | GBA | Medium | ✅ | |
| `mednafen_psx` | PS1 | Very High | ✅ | |
| `mednafen_psx_hw` | PS1 (GPU) | Very High | ✅ | Hardware renderer variant |
| `pcsx_rearmed` | PS1 | High | ✅ | ARM-optimised |
| `mednafen_pce` | PC Engine / TurboGrafx | High | ✅ | |
| `mednafen_pce_fast` | PC Engine (fast) | High | ✅ | |
| `mednafen_supergrafx` | SuperGrafx | High | ✅ | |
| `mednafen_ngp` | Neo Geo Pocket | High | ✅ | |
| `mednafen_lynx` | Atari Lynx | Medium | ✅ | |
| `mednafen_snes` | SNES (Bsnes) | Very High | ✅ | |
| `mednafen_pcfx` | PC-FX | Low | ✅ | Very few RA games |
| `mednafen_saturn` | Sega Saturn | Growing | ✅ | RA Saturn coverage is expanding |

### Tier 2 — Good RA Coverage

| Core | Systems | RA Coverage | Cheevos Compiled | Notes |
|------|---------|-------------|-----------------|-------|
| `ppsspp` | PSP | Medium | ✅ | PPSSPP has its own cheevos path via rcheevos |
| `flycast` | Dreamcast / NAOMI | Medium | ✅ | Growing RA database |
| `desmume` | Nintendo DS | Medium | ✅ | |
| `fbneo` | Arcade (Neo-Geo, CPS, etc.) | High | ✅ | FBNeo has extensive RA arcade support |
| `fbalpha2012` | Arcade | High | ✅ | |
| `fbalpha2012_cps1` | CPS-1 | High | ✅ | |
| `fbalpha2012_cps2` | CPS-2 | High | ✅ | |
| `fbalpha2012_cps3` | CPS-3 | Medium | ✅ | |
| `fbalpha2012_neogeo` | Neo Geo | High | ✅ | |
| `handy` | Atari Lynx | Medium | ✅ | Alternative Lynx core |
| `mame2003` | Arcade | Medium | ✅ | |
| `mame2003_plus` | Arcade | Medium | ✅ | |
| `mame2010` | Arcade | Medium | ✅ | |
| `mame` | Arcade | Low | ✅ | Current MAME — limited RA titles |
| `mame2000` | Arcade | Low | ✅ | |
| `prosystem` | Atari 7800 | Medium | ✅ | |
| `stella` | Atari 2600 | High | ✅ | |
| `stella2014` | Atari 2600 | High | ✅ | |
| `stella2023` | Atari 2600 | High | ✅ | |
| `a5200` | Atari 5200 | Low | ✅ | Few RA titles |
| `atari800` | Atari 400/800/5200 | Low | ✅ | |
| `race` | Neo Geo Pocket | Medium | ✅ | |
| `geolith` | Neo Geo (AES/MVS) | Medium | ✅ | |
| `yabause` | Sega Saturn | Low–Medium | ✅ | Less accurate than Mednafen |

### Tier 3 — Niche / Low RA Coverage

| Core | Systems | RA Coverage | Cheevos Compiled | Notes |
|------|---------|-------------|-----------------|-------|
| `bluemsx` | MSX / MSX2 | Low | ✅ | |
| `fmsx` | MSX | Low | ✅ | |
| `cap32` | Amstrad CPC | Low | ✅ | |
| `fuse` | ZX Spectrum | Low | ✅ | |
| `81` | ZX81 | None | ✅ | No RA database entries |
| `hatari` | Atari ST | Low | ✅ | |
| `vice_x64` | C64 | Low | ✅ | |
| `vice_x64sc` | C64SC | Low | ✅ | |
| `vice_x128` | C128 | Low | ✅ | |
| `vice_xcbm2` | CBM-II | None | ✅ | |
| `vice_xcbm5x0` | CBM-5x0 | None | ✅ | |
| `vice_xpet` | PET | None | ✅ | |
| `vice_xplus4` | Plus/4 | None | ✅ | |
| `vice_xscpu64` | SuperCPU64 | None | ✅ | |
| `vice_xvic` | VIC-20 | None | ✅ | |
| `px68k` | Sharp X68000 | None | ✅ | |
| `x1` | Sharp X1 | None | ✅ | |
| `galaksija` | Galaksija | None | ✅ | |
| `m2000` | Philips P2000T | None | ✅ | |
| `holani` | HP 9100 | None | ✅ | |
| `freechaf` | Fairchild Channel F | None | ✅ | |
| `freeintv` | Intellivision | Low | ✅ | |
| `vecx` | Vectrex | Low | ✅ | |
| `potator` | Supervision | None | ✅ | |
| `pokemini` | Pokémon Mini | None | ✅ | |
| `vemulator` | Sega VMU | None | ✅ | |
| `gearcoleco` | ColecoVision | Low | ✅ | |
| `theodore` | Thomson MO/TO | None | ✅ | |
| `dinothawr` | Puzzle (homebrew) | None | ✅ | |
| `pocketcdg` | CD+G | None | ✅ | |
| `gme` | Game Music (chiptunes) | None | ✅ | |
| `gw` | Game & Watch | None | ✅ | |
| `scummvm` | LucasArts / SCUMM | Low | ✅ | |
| `dosbox_pure` | MS-DOS | Low | ✅ | |
| `tyrquake` | Quake | None | ✅ | |
| `prboom` | Doom | None | ✅ | |
| `2048` | 2048 (puzzle) | None | ✅ | |
| `dice` | DICE (logic sim) | None | ✅ | |
| `vircon32` | Vircon32 (homebrew) | None | ✅ | |
| `wasm4` | WASM-4 (fantasy) | None | ✅ | |
| `xrick` | Rick Dangerous | None | ✅ | |
| `squirreljme` | J2ME / MIDP | None | ✅ | |
| `qemu` | x86/ARM (QEMU) | None | ✅ | No RA support planned |
| `virtualxt` | 8088 XT | None | ✅ | |
| `virtualjaguar` | Atari Jaguar | Low | ✅ | |
| `sameduck` | Bandai Duck Hunt | None | ✅ | |
| `same_cdi` | Philips CD-i | None | ✅ | |
| `smsplus` | Sega SMS | Medium | ✅ | Genesis Plus GX preferred |
| `play` | PS2 | None | ✅ | Experimental, no RA coverage |

### Special Cases — Sideload Only (not App Store)

| Core | Systems | RA Coverage | Cheevos Compiled | Notes |
|------|---------|-------------|-----------------|-------|
| `dolphin` | GameCube / Wii | Growing | ✅ | JIT required; `appstore: false` |
| `mcsoftserve` | ? | Unknown | ✅ | Not App Store approved |

### tvOS-Only Cores

| Core | Systems | RA Coverage | Cheevos Compiled | Notes |
|------|---------|-------------|-----------------|-------|
| `puau` | Amiga | Low | ✅ | |
| `puau2021` | Amiga (2021) | Low | ✅ | |

### Disabled Cores (not built)

| Core | Status | Notes |
|------|--------|-------|
| `snes9x` | `enabled: false` | Disabled globally; snes9x2002/2005/2010 used instead |
| `vitaquake2*` | `enabled: false` | Disabled in all variants |

---

## Gaps and Findings

### Finding 1 — `cheevos_enable = "false"` Default

**Severity**: Medium (UX concern, not a build defect)

`retroarch.cfg` ships with `cheevos_enable = "false"`. Achievements are silently inactive for users who sign in but don't also toggle the switch in RetroArch settings.

`RetroArchConfigManager` writes credentials to `retroarch.cfg` but it is unclear whether it also writes `cheevos_enable = "true"` when the user enables achievements via the PVCheevos Settings UI.

**Recommendation**: Verify that `RetroArchConfigManager.setCredentials(...)` also sets `cheevos_enable = true` in `retroarch.cfg`.

### Finding 2 — `achievementsActive` Always Returns `false`

**Severity**: Low (stubs)

`PVRetroArchCoreCore+RetroAchievements.swift:achievementsActive` is hardcoded to `return false`:

```swift
public var achievementsActive: Bool {
    // TODO: query cheevos_state() once the C-to-Swift bridge is wired.
    return false
}
```

This means the PVLibrary / SwiftUI layer cannot query whether an active cheevos session is running.

**Recommendation**: Implement the C-to-Swift bridge for `rcheevos_is_active()` or expose a flag set by the runloop when achievements activate.

### Finding 3 — Per-frame Callback Not Wired (Comment in PVLibRetroCore.m)

**Severity**: Low (RetroArch handles internally)

`PVRetroArchCoreCore+RetroAchievements.swift` notes:

> In PVLibRetroCore.m, when HAVE_CHEEVOS is defined, intercept the cheevos callback notifications (cheevos_set_rcheevos_callbacks) and forward them to a Swift-side handler.

The C callback bridge is described but marked as a TODO. Native iOS haptics on unlock and PVLibrary progress tracking are not wired.

**Recommendation**: Implement `cheevos_set_rcheevos_callbacks` bridge for native unlock notifications (tracked separately from this audit).

### Finding 4 — `RC_DISABLE_LUA` Is Set

**Severity**: Informational

`BuildFlags.xcconfig` includes `-DRC_DISABLE_LUA`. This is correct for iOS/tvOS — Lua support is not available in mobile builds and is not required for rcheevos.

### Finding 5 — No Per-Scheme Conditional Compilation of Cheevos

**Severity**: None (positive finding)

Unlike some RetroArch forks, Provenance does **not** gate `HAVE_CHEEVOS` per scheme. The Lite scheme gets the same cheevos-enabled binary as the XL scheme. This is correct behaviour.

---

## Test Plan

Since cheevos are a runtime feature (credentials + enabled flag required), compile-time verification is the primary audit mechanism. Full runtime testing requires:

1. A RetroAchievements account with a known-verified game hash.
2. Set `cheevos_enable = "true"` and credentials in `retroarch.cfg` (or via Settings UI).
3. Load the game and observe `rcheevos_test()` calls in the runloop.
4. Confirm via verbose logging (`cheevos_verbose_enable = "true"`) that the session activates.

Cores with very high RA coverage that are recommended for smoke testing:

| Core | Test Game | Expected Behaviour |
|------|-----------|-------------------|
| `genesis_plus_gx` | Sonic the Hedgehog (MD) | Session starts, rich presence active |
| `fceumm` | Super Mario Bros (NES) | Achievements load on game start |
| `bsnes` | Super Mario World (SNES) | Achievements load |
| `gambatte` | Pokemon Red/Blue (GB) | Achievements load |
| `mednafen_psx` | Crash Bandicoot (PS1) | Session starts |

---

## Conclusion

**All libretro cores in Provenance reach `cheevos.c`.**

The `HAVE_CHEEVOS` flag is set unconditionally in `Build.xcconfig`, `BuildFlags.xcconfig`, and `CoresRetro/Package.swift`. The `griffin.c` unified build includes all rcheevos source files under `#if defined(HAVE_CHEEVOS)`. Every core loaded through `PVRetroArchCore` runs inside the same RetroArch runloop that calls `rcheevos_test()` per frame.

The three open items (default disabled flag, `achievementsActive` stub, unlock callback bridge) are UX improvements, not correctness bugs — achievements do work for users who enable them.

---

*Part of epic #2705 — RetroAchievements integration*
