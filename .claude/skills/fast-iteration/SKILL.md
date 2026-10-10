---
name: fast-iteration
description: Use when iterating on Provenance UI or a single emulator core and the full app build is too slow — adding or building a Tuist focused app (Provenance-Dev-UI/-Thin/-Azahar), building one Azahar/Dolphin core slice, running a ROM through the dev harness, or adding a libretro dylib to a focused app. Trigger phrases: "dev workspace", "focused app", "make dev", "tuist", "build_slice", "core slice", "dev harness", "screenshot a core".
version: 1.0.0
---

# Fast iteration (Tuist dev workspace)

Background and rules: CLAUDE.md "Dev workspace (Tuist)". Generate with
`mise exec -- tuist generate --no-open` (`make dev` opens it). Never pass
`CODE_SIGNING_ALLOWED=NO` to a dev build (Dev.xcconfig ad-hoc signs simulators; unsigned
MoltenVK kills the app in dyld).

## 1. Add a focused target

1. Every core must already be a row in `Tuist/ProjectDescriptionHelpers/CoreProduct.swift`
   (and have a KEEP row in `docs/superpowers/specs/2026-10-10-core-audit.md`). Row kinds:
   `.package(path:product:)` for SwiftPM dynamic products, `.project(path:target:product:)` for
   `Cores/<X>/*.xcodeproj` targets, `.prebuilt(path:)` for an on-disk (xc)framework.
2. Append one literal to `FocusedApp.all` in `Tuist/ProjectDescriptionHelpers/FocusedApp.swift`:
   ```swift
   static let genesis = FocusedApp(slug: "genesis", title: "Genesis", cores: [.genesis], flags: [DevSettings.harnessFlag])
   static let all: [FocusedApp] = [.ui, .azahar, .thin, .genesis]
   ```
3. `Scripts/dev/check_dev_manifest.sh`, then `make dev-generate`, then build:
   `make _dev-build DEV_SCHEME=Provenance-Dev-Genesis` (add a `dev-genesis` Make target if
   it's going to stay). Check iOS and tvOS Simulator.

## 2. Build one core slice

```bash
python3 Scripts/cores/build_slice.py azahar ios-sim            # hit: symlink; miss: build + cache
python3 Scripts/cores/build_slice.py dolphin tvos --print-key   # the CI cache key
python3 Scripts/cores/build_slice.py azahar ios --force         # rebuild this key
python3 Scripts/cores/build_slice.py azahar ios --xcframework   # also repack PVlibAzahar.xcframework
```
Cache: `$PV_CORE_CACHE` or `~/Library/Caches/Provenance/cores/<core>/<slice>/<key12>/`. The key
includes the submodule working-tree state, so dirty edits in the submodule bust the cache. If
`--xcframework` fails on hard links, set `PV_CORE_CACHE` to a folder on the repo's volume. Cold
slices take 30–40 min (Azahar) / 30–60 min (Dolphin): run them in the background and poll.

## 3. Run the harness against a ROM

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
python3 Scripts/dev/make_harness_rom.py /tmp/loop.a26      # synthetic 2600 ROM (.gba also supported)
make dev-harness ROM=/tmp/loop.a26 TARGET=ui FRAMES=120 CORE=com.provenance.core.stella SIM_DEVICE=booted
open build/harness/Provenance-Dev-UI/screenshot.png
```
Outputs: `screenshot.png`, `frames.json`, `log.txt`, or `error.txt` on failure, in
`build/harness/<Scheme>/`. Launch arguments: `-PVHarnessROM`, `-PVHarnessCore`, `-PVHarnessFrames`,
`-PVHarnessOut`, `-PVHarnessExit`. `TARGET` is `ui` or `azahar`; `TARGET=thin` is refused with
exit 2 because libretro buildbot dylibs are iOS-platform binaries and can't `dlopen` in a
simulator (Thin plays on a device only).

## 4. Add a libretro dylib to a target

1. The name must be an `enabled: true` entry in `CoresRetro/RetroArch/scripts/cores.yml`
   (and present in the generated `urls.txt` / `urls-tv.txt`).
2. Add it to the app's `libretro:` list in `FocusedApp.swift`, e.g.
   `libretro: ["mednafen_psx_hw", "mupen64plus_next", "snes9x", "ppsspp", "genesis_plus_gx"]`.
3. `Scripts/dev/check_dev_manifest.sh` (fails on unknown/disabled names), `make dev-generate`,
   `make dev-thin`. The pre script fetches through `get-modules.sh --urls`, which never prunes
   the shared `modules/`. The dylib only plays on a device.
