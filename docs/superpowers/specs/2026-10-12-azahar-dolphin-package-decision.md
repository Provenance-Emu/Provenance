# Azahar and Dolphin: ship from packages or keep the xcodeprojs (2026-10-12)

## Facts
- Both packages use a `.binaryTarget` over `build/xcframework/PVlib<Core>.xcframework`, produced by
  `Scripts/cores/build_slice.py <core> <slice> --xcframework`. Xcode loads package manifests when it
  resolves the workspace, before any target (including the BuildPVlibAzahar / Make XCFrameworks
  aggregates) runs, so the xcframework must exist before `xcodebuild` starts, for every scheme.
- Dolphin's binaryTarget is unconditional; Azahar's is added only when the xcframework exists.
- Dolphin has no simulator slice, and a package product dependency cannot be filtered by simulator vs
  device, so local simulator runs of Provenance/AppStore/XL would stop linking.
- Today's xcodeprojs link the per-slice archive by path and build it in an aggregate target, which
  works on a cold checkout; that was the fix for "There is no XCFramework found".

## Options
1. Keep both on their xcodeprojs (recommended for now). Nothing changes for release.sh, build.yml,
   testflight.yml, `make lite` or a fresh clone opened in Xcode.
2. Move both: run `build_slice.py <core> <slice> --xcframework` for ios and tvos (and both simulator
   slices for Azahar) before every xcodebuild entry point: release.sh, build.yml, testflight.yml,
   `make lite`, and document it for local Xcode use; add Dolphin simulator slices or accept no
   simulator runs; add the `nm -m <fw> | grep 'weak external'` audit (CLAUDE.md, Azahar gotchas) to
   the gate because the unexported-symbols lists move into Package.swift; and add a Run Script to
   every Dolphin-linking app target that copies `Cores/Dolphin/dolphin-ios/Data/Sys` into the app
   bundle (the xcodeproj bundles it today; a package cannot reference it; the dev app's
   `DevSettings.dolphinSysScript` is the model). Dolphin's `Config/` is already a package resource.
3. Move Azahar only (simulator slices exist; binaryTarget is optional), keep Dolphin.

## Decision
Option 1, keep both on their xcodeprojs (user, 2026-10-12). Revisit when build_slice.py runs as a
pre-resolution step at every xcodebuild entry point and Dolphin has simulator slices.
