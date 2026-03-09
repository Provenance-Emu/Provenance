# Hatari Core Status — Native vs RetroArch Evaluation

**Date:** 2026-03-09
**Issue:** [#2826](https://github.com/Provenance-Emu/Provenance/issues/2826) (Atari ST epic: #2822)

---

## Overview

Two Hatari implementations exist in the Provenance codebase:

| Implementation | Core Identifier | Principal Class | Status |
|---|---|---|---|
| Native Hatari (PVHatari) | `com.provenance.core.Hatari` | `PVHatari.PVHatariCore` | Stub / incomplete |
| RetroArch Hatari | `hatari.libretro.framework` | `PVRetroArch.PVRetroArchCoreCore` | Active / functional |

---

## 1. Native Hatari Core (`Cores/hatari/`)

### Files
- `PVHatariCore/PVHatariCore.mm` — Main implementation
- `PVHatariCore/PVHatariCore.h` — Header
- `PVHatari/Core.plist` — Core registration
- `cmake/Makefile` — libretro-style build Makefile
- `hatari/` — Git submodule (currently **not checked out / empty**)

### State: Stub / Non-functional

`PVHatariCore.mm` is essentially an empty shell. Every meaningful method is commented out:

- `loadFileAtPath:error:` — commented out
- `startEmulation` — commented out
- `setPauseEmulation:` — commented out
- `stopEmulation` — commented out
- `resetEmulation` — commented out
- Cheat code support — commented out
- Video buffer / pixel format methods — commented out
- Controller input support — not implemented (no `+Controls` category)
- Audio support — not implemented (no `+Audio` category)

Only two methods are actually implemented:
- `frameInterval` — returns the hardcoded value `13.63`
- `audioSampleRate` — returns the hardcoded value `22255`

### Header Analysis

`PVHatariCore.h` declares `PVHatariCore` as a subclass of `PVLibRetroCoreBridge` (a RetroArch bridge base class), not as a standalone native emulator. This means the "native" core was actually intended to wrap the libretro Hatari core through the RetroArch bridge infrastructure — not to link directly against the upstream Hatari emulator library.

All instance variable declarations are commented out.

### Submodule Status

The git submodule at `Cores/hatari/hatari/` (pointing to `https://github.com/Provenance-Emu/hatari.git`) is registered in `.gitmodules` but is **not populated** in the working tree. No upstream Hatari source code is present.

The `cmake/Makefile` is a libretro build Makefile intended to produce `hatari_libretro_ios.dylib` or `hatari_libretro_tvos.dylib` — it is not a direct build of the Hatari emulator for native use.

### Core Registration

`PVHatari/Core.plist` registers the core with:
- `PVCoreIdentifier`: `com.provenance.core.Hatari`
- `PVSupportedSystems`: `com.provenance.atarist`
- `PVProjectVersion`: `0` (indicating unreleased/placeholder status)

---

## 2. RetroArch Hatari Core (`CoresRetro/RetroArch/`)

### Files
- `PVRetroArch/Core.plist` — Core registration (includes Hatari entry)
- `PVRetroArchCore/Core/PVRetroArchCore+RetroArchUI.m` — Bridge with Hatari-specific setup logic
- `scripts/urls.txt`, `scripts/urls-tv.txt`, etc. — Download lists for prebuilt dylibs
- `hatari.cfg` — Bundled Hatari configuration file (included in `PVRetroArch.xcodeproj`)

### State: Active / Functional

The RetroArch Core.plist registers Hatari as:
- `PVCoreIdentifier`: `hatari.libretro.framework`
- `PVPrincipleClass`: `PVRetroArch.PVRetroArchCoreCore`
- `PVProjectName`: `Atari ST/STE/TT/Falcon (RetroArch)`
- `PVSupportedSystems`: `com.provenance.atarist`
- `PVProjectVersion`: `1.8`

The prebuilt dylibs are downloaded by CI scripts:
- iOS: `hatari_libretro_ios.dylib` (from libretro buildbot)
- tvOS: `hatari_libretro_tvos.dylib` (from libretro buildbot)

The `hatari_libretro_ios.dylib` is referenced in `Provenance.xcodeproj/project.pbxproj` and placed at `CoresRetro/RetroArch/modules/hatari_libretro_ios.dylib`.

### Hatari-specific Logic in Bridge

`PVRetroArchCore+RetroArchUI.m` contains substantial Hatari-specific runtime logic:

1. **TOS image setup** — Detects `atarist` system or `hatari` core identifier; copies `tos.img` from the BIOS path to the RetroArch system directory. Includes byte-level verification and patching of TOS version/address fields.
2. **Video settings** — Applies integer scaling and disables smoothing for Hatari.
3. **hatari.cfg injection** — Copies and updates a bundled `hatari.cfg` with the live TOS image path and ROM directory path at runtime.
4. **System directory** — Passes the system directory to RetroArch config so Hatari can locate the TOS image.

---

## 3. Core Loader Mapping (`systems.plist`)

The `PVCoreLoader` system definitions (`PVCoreLoader/Sources/PVCoreLoader/Resources/systems.plist`) define `com.provenance.atarist` with:
- `PVRequiresBIOS`: `true`
- BIOS: `tos.img` (TOS 1.02 US, MD5 `c1c57ce48e8ee4135885cee9e63a68a2`, 192 KB)
- Supported extensions: `st`, `mas`, `zip`, `stx`, `dim`, `ipf`

The systems.plist does **not** hard-code a preferred core; the `PVCoreLoader` selects among registered cores at runtime. Both `com.provenance.core.Hatari` (native stub) and `hatari.libretro.framework` (RetroArch) register for `com.provenance.atarist`.

---

## 4. Which Core is Active at Runtime?

**The RetroArch Hatari core (`hatari.libretro.framework`) is the active, functional path.**

Reasons:
- The native `PVHatariCore` is a stub with all emulation methods commented out; it cannot run games.
- The `PVHatariRetroArch.framework` is linked in `Provenance.xcodeproj` (in the `Provenance-XL` and standard schemes), alongside the prebuilt `hatari_libretro_ios.dylib`.
- The RetroArch bridge has detailed Hatari-specific startup logic that the native stub entirely lacks.
- The `PVHatari.framework` (native) is also referenced in the project, but given its stub state, the RetroArch variant would be preferred by the core loader if both are available.

---

## 5. Recommendation

**Continue with the RetroArch path (`hatari.libretro.framework`) for Atari ST support.**

Rationale:
- The RetroArch core is version 1.8 with active upstream libretro maintenance.
- Hatari-specific BIOS handling, TOS patching, and configuration injection are already implemented in the bridge.
- The native core has no emulation logic whatsoever and its upstream submodule is not checked out.
- Moving to a native implementation would require: checking out the submodule, implementing a full ObjC/C++ bridge layer (controls, audio, video, save states, BIOS loading), and extensive testing — significant engineering effort with no user-facing benefit over the already-working libretro path.

**Work needed to make the RetroArch path fully functional:**
- Verify `tos.img` BIOS distribution/licensing requirements for bundled copy
- Validate TOS byte-order patching logic against actual device behavior (the bridge contains extensive comments about unresolved byte-order issues)
- Test `.stx` (Pasti) and `.ipf` (SPS/CAPSImg) format support (these require additional library support in the libretro build)
- Consider exposing Hatari machine type (ST/STE/TT/Falcon) as a per-game core option in the UI

**Work needed to resurrect the native core (not recommended at this time):**
- Check out `Cores/hatari/hatari` submodule
- Implement `PVHatariCore+Controls.mm`, `PVHatariCore+Audio.mm`, `PVHatariCore+Video.mm`
- Implement `loadFileAtPath:`, `startEmulation`, `stopEmulation`, `resetEmulation`
- Wire up BIOS loading and save state support
- Integrate with the libretro wrapper in `cmake/` or replace with a direct Hatari library link

---

## File References

| File | Role |
|---|---|
| `Cores/hatari/PVHatariCore/PVHatariCore.mm` | Native core stub (non-functional) |
| `Cores/hatari/PVHatariCore/PVHatariCore.h` | Native core header |
| `Cores/hatari/PVHatari/Core.plist` | Native core registration |
| `Cores/hatari/cmake/Makefile` | libretro build script for upstream Hatari |
| `CoresRetro/RetroArch/PVRetroArch/Core.plist` | RetroArch core registration (includes Hatari) |
| `CoresRetro/RetroArch/PVRetroArchCore/Core/PVRetroArchCore+RetroArchUI.m` | Hatari-specific RetroArch bridge logic |
| `CoresRetro/RetroArch/scripts/urls.txt` | iOS libretro core download list (includes Hatari) |
| `CoresRetro/RetroArch/scripts/urls-tv.txt` | tvOS libretro core download list (includes Hatari) |
| `PVCoreLoader/Sources/PVCoreLoader/Resources/systems.plist` | System/BIOS definitions for Atari ST |
