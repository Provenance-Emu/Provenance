# Core SwiftPM / Tuist conversion (finish)

**Goal:** every shipping native core is consumed as a SwiftPM product, so the Tuist dev workspace
(`docs/superpowers/specs/2026-10-10-dev-workspace-design.md`) can generate small, targeted Xcode
projects (one core, or no core at all) and builds stop paying for hand-maintained
`Cores/<X>/PV<X>.xcodeproj` graphs. Shipping `Provenance.xcodeproj` is untouched in this phase.

## Where we are (2026-10-11)

`Tuist/ProjectDescriptionHelpers/CoreProduct.swift` still links these via `.project(...)`:

| Core | Package.swift today | Why not `.package` yet |
|---|---|---|
| snes9x | `PVSNES9x-Dynamic` exists | never built by any target; xcodeproj product is `PVSNES` + `snes9x.framework` |
| FCEU | `PVFCEU-Dynamic` exists | same |
| Genesis-Plus-GX | `PVCoreGenesisPlus-Dynamic` exists | same; xcodeproj product `PVGenesis` |
| Mupen64Plus | `PVMupenGameCore-Dynamic` exists | xcodeproj also builds 5 plugin frameworks (RspHLE, Bridge, GlideN64, Rice, CXD4) the core dlopens |
| Azahar / Dolphin | none | out-of-tree C++ lib built by `build_slice.py` aggregates |
| PVCoreBridgeRetro | none usable | mixed Swift/ObjC target, SwiftPM can't build it ([[pvcorebridgeretro-xcodeproj-not-spm]]) |

Mednafen, Stella, ProSystem, PicoDrive, TGBDual, mGBA already ship as `-Dynamic` packages in the
focused apps, with `Core.plist` as a `.process` resource that `CoreLoader` discovers.

## Definition of done per core

1. `swift build` is not required (Tier ≥3), but `tuist generate` + `xcodebuild build` of a focused
   app containing the core succeeds for `generic/platform=iOS Simulator` and `tvOS Simulator`.
2. `CoreProduct.<core>.link` is `.package(path:product:)`; no `.project` rows remain for it and
   `Workspace.swift` no longer references its xcodeproj (when no other row needs it).
3. The package target declares `resources: [.process("Resources/Core.plist")]` and the plist's
   `PVPrincipleClass` resolves (harness or `CoreLoader` log shows the core registered).
4. `Scripts/dev/check_dev_manifest.sh` passes. `Scripts/audits/check_pbxproj_sources.py` passes.
5. Nothing in `Provenance.xcodeproj` changes. Shipping builds keep using the xcodeproj until a
   later phase swaps them.

## Phases

- **Phase 1 (parallel, one agent each):** snes9x, FCEU, Genesis-Plus-GX. Add each to a focused
  app (`FocusedApp.ui` already has snes9x; add `fceu` and `genesis` rows or a `dev-nes`/`dev-genesis`
  app) and verify per the DoD. Expect to fix stale `Package.swift` paths, missing C flags copied
  from the xcodeproj `.xcconfig`, and header maps.
- **Phase 2:** Mupen64Plus — plugins become separate dynamic products embedded via `embeds`.
- **Phase 3:** Azahar / Dolphin — `.binaryTarget` over the slice cache's `.xcframework`
  (`build_slice.py --xcframework`), aggregate stays as the producer.
- **Phase 4:** `FocusedApp.coreless` (no native cores, no libretro) for UI-only test builds; CI's
  agent smoke build moves to it.
- **Out of scope:** PVCoreBridgeRetro split; shipping project swap; retired/UNSURE cores
  (PPSSPP, emuThree, ep128emu, fmsx) — they follow the audit, not this conversion.
