# Dev Workspace — Tuist-generated focused targets, core harness, cached core slices, pruning

**Date:** 2026-10-10 · **Status:** approved design (session A of the dev-velocity roadmap,
`2026-10-09-dev-velocity-roadmap.md` Workstream A) · **Audit input:** `2026-10-10-core-audit.md`

## 1. Why

A CI leg archives the full app in 72–100 minutes with no DerivedData cache; locally a one-line
UI change rebuilds against 37 embedded cores. Azahar (30–40 min/slice) and Dolphin
(30–60 min/slice) rebuild whenever their caches miss: Azahar's stamp is the submodule SHA only
and its single CI cache key is shared by the iOS and tvOS legs; Dolphin has no stamp at all and
repacks its xcframework on every build. Of 50 `Cores/` directories, 24 are dead shells that
are still compiled and embedded, and the two native DS cores have been `PVDisabled` since they
were created. iCube iterates in minutes because the app is Tuist-generated with small targets
and the core builds outside the app, per slice, cached.

## 2. Decisions (settled with the maintainer)

1. **Dev workspace first.** Tuist generates a second workspace, `Provenance-Dev.xcworkspace`.
   `Provenance.xcodeproj` keeps shipping untouched this session; a follow-up moves CI, fastlane
   and release.sh onto the generated project once the focused apps have proven the model.
2. **Generated files are not committed.** `Provenance-Dev.xcworkspace`, `Dev/Provenance.xcodeproj`
   and `Dev/Derived` are gitignored; `make dev` generates before opening.
3. **Tuist 4.200.0**, pinned in `.mise.toml` (the version installed here and in iCube's CI).
4. **Only audited cores are modelled.** The focused targets draw from the 12 KEEP cores in the
   audit; the 24 RETIRE cores, the two native DS cores and the seven other save-check cores
   (Atari800, Bliss, CrabEMU, Gambatte, O2EM, PokeMini, VisualBoyAdvance-M) are pruned from the
   shipping project in this session, each with a `RetiredCoreMigration` entry. emuThree and the
   four UNSURE cores stay until the maintainer rules.
5. **iOS and tvOS from the start.** Every focused target is one multiplatform target, like
   `Provenance (AppStore)`.
6. **The Tuist project is named `Provenance`.** `Build.xcconfig` derives bundle ids, the app
   group and the iCloud container from `$(PROJECT_NAME:lower)`; the project therefore lives in
   `Dev/` so it does not overwrite the shipping `Provenance.xcodeproj`.

## 3. Layout and tooling

```
.mise.toml                      tuist = "4.200.0"
Tuist.swift                     Tuist(compatibleXcodeVersions: .upToNextMajor("26.0"),
                                      generationOptions: .options(enforceExplicitDependencies: false))
Workspace.swift                 Workspace(name: "Provenance-Dev", projects: ["Dev"],
                                          additionalFiles: ["docs/superpowers/specs/*.md"])
Dev/Project.swift               Project(name: "Provenance", ...)  → Dev/Provenance.xcodeproj
Dev/Tuist/ProjectDescriptionHelpers/
    CoreProduct.swift           the core table (§4)
    FocusedApp.swift            the target template (§5)
    LibretroCores.swift         dylib list → filter + scripts (§6)
    DevSettings.swift           shared settings, xcconfig, configurations
Dev/Config/Dev.xcconfig         #include "../../Build-iOS.xcconfig"; dev-only overrides
PVDevHarness/                   SwiftPM package (§7)
Scripts/cores/build_slice.py    (§8)
Makefile                        dev, dev-generate, dev-ui, dev-azahar, dev-thin, dev-harness
```

`Tuist.swift` at the root makes the repo root the Tuist root, so manifest paths are repo-relative
(`"../PVUI"` from `Dev/`). The dead 2021 xcodegen `project.yml` at the root is deleted. The
`Package.swift` reference pattern follows iCube: `Project(packages: [.local(path:)])` plus
`.package(product:)` per target; no `Tuist/Package.swift`, no `tuist install`, each local package
declared exactly once (a duplicate fails generation).

## 4. Core table — `CoreProduct`

One row per audited KEEP core, declaring how the app consumes it. Nothing else about the core
lives in the manifest.

```swift
public enum CoreLink {
    case package(path: Path, product: String)                  // SPM dynamic product
    case project(path: Path, target: String, product: String)  // Cores/<X>/PV<X>.xcodeproj
    case prebuilt(path: Path)                                  // .framework/.xcframework on disk
}
public struct CoreProduct {
    public let id: String            // "azahar", "snes9x", ...
    public let link: CoreLink
    public let embeds: [CoreLink]    // extra frameworks the app must embed (Mupen plugins, PVlibDolphin)
    public let platforms: Set<Platform>   // .iOS, .tvOS — omit tvOS where the shipping target filters it
    public let needsAggregate: String?    // "BuildPVlibAzahar", "Make XCFrameworks"
}
```

Rows (from the shipping embed phases): Azahar (`project`, `Cores/Azahar/PVAzahar.xcodeproj`,
`PVAzahar`, aggregate `BuildPVlibAzahar`), Dolphin (`project`, `PVDolphin` + embeds
`PVlibDolphin.xcframework`, aggregate `Make XCFrameworks`), FCEU, Genesis-Plus-GX, snes9x
(`project` rows, product names as the embed phase lists them: `PVFCEU`, `PVGenesis`, `PVSNES`
and `snes9x`), Mupen64Plus (`project` `PVMupen64Plus` + embeds `PVMupen64PlusRspHLE`,
`PVMupen64PlusBridge`, `PVMupen64PlusVideoGlideN64`, `PVMupen64PlusVideoRice`, `PVRSPCXD4`),
Mednafen (`package` `Cores/Mednafen`, `PVCoreMednafen-Dynamic`), Stella, ProSystem, PicoDrive,
TGBDual, mGBA (`package` `-Dynamic` products), plus the non-core products every app needs:
`PVCoreBridgeRetro` (`project`), `PVCheevos`, MoltenVK (`package`, iOS/tvOS product
`MoltenVK`). The exact product and path strings are copied from the pbxproj dump
(`scratchpad/pbx.json`, section 2b/2c of the app map) when the row is written, never typed from
memory.

## 5. Focused targets — `FocusedApp`

```swift
public struct FocusedApp {
    public let slug: String              // "ui", "azahar", "thin"
    public let cores: [CoreProduct]
    public let libretro: [String]        // cores.yml names, e.g. ["mednafen_psx_hw", "mupen64plus_next"]
    public let flags: [String]           // SWIFT_ACTIVE_COMPILATION_CONDITIONS additions, e.g. ["PV_DEV_HARNESS"]
    public func target() -> Target        // builds the multiplatform app target
    public func scheme() -> Scheme
}
```

`target()` produces `Provenance-Dev-<Slug>`: product `.app`, destinations iPhone, iPad, Apple TV,
Mac (Designed for iPad); deployment `.multiplatform(iOS: "17.0", tvOS: "17.0")`; sources
`Provenance/Main UI/**`; resources, Info.plist (`Provenance/Provenance-Lite (AppStore)-Info.plist`,
`PVAppType` left as is), entitlements selection and package products mirrored from
`Provenance-Lite (AppStore)` minus its cores; base xcconfig `Dev/Config/Dev.xcconfig`;
per-configuration settings `ALPHA_BUNDLE_SUFFIX = .dev.<slug>` (the suffix hook `Build.xcconfig`
already has) and `PRODUCT_NAME = Provenance-Dev-<Slug>`; `SWIFT_ACTIVE_COMPILATION_CONDITIONS =
$(inherited) PV_DEV <flags>`; `ENABLE_USER_SCRIPT_SANDBOXING = NO`. Dependencies come from the
rows: `.package(product:)`, `.project(target:path:)` with `condition: .when([...])` from
`platforms`, `.xcframework`/`.framework(path:)` for prebuilt, and `.project(target: aggregate)`
where `needsAggregate` is set. `defaultSettings: .recommended(excluding:)` pins the tvOS app-icon
keys (iCube lesson). Configurations: Debug and Release only.

Initial table:

| Target | Cores | Libretro dylibs | Flags |
|---|---|---|---|
| `Provenance-Dev-UI` | mGBA, Stella, snes9x | — | PV_DEV_HARNESS |
| `Provenance-Dev-Azahar` | Azahar | — | PV_DEV_HARNESS |
| `Provenance-Dev-Thin` | — (PVCoreBridgeRetro only) | mednafen_psx_hw, mupen64plus_next, snes9x, ppsspp | PV_DEV_HARNESS |

Adding a target is one `FocusedApp(...)` literal appended to the `focusedApps` array.

## 6. Libretro dylibs per target — `LibretroCores`

The dylib list becomes two scripts on the target, both `basedOnDependencyAnalysis: false`:

- **pre** `Get libretro cores (<slug>)`: writes `$DERIVED_FILE_DIR/urls.txt` from the names
  (`https://buildbot.libretro.com/nightly/apple/{ios,tvos}-arm64/latest/<name>_libretro_{ios,tvos}.dylib.zip`
  by `$PLATFORM_NAME`), then runs `CoresRetro/RetroArch/scripts/get-modules.sh --urls
  "$DERIVED_FILE_DIR/urls.txt"`. `get-modules.sh` gains the `--urls <file>` option (today it
  picks `urls*.txt` by platform); its skip/manifest logic keys on the file's hash as it does now.
- **post** `Generate libretro frameworks (<slug>)`: `make_frameworks_retroarch.sh
  "$SRCROOT/../CoresRetro/RetroArch" "$DERIVED_FILE_DIR/urls.txt"` (the filter argument it already
  takes), then `validate_frameworks.sh`.

A target with an empty list gets neither script. `cores.yml` is not consulted at generate time;
the manifest names are validated by a unit test against `cores.yml` (§12).

## 7. Core harness — `PVDevHarness`

A SwiftPM package (`PVDevHarness`, depends on PVLibrary, PVUI, PVLogging) compiled into focused
apps under `PV_DEV_HARNESS`. `ProvenanceApp.swift` calls `DevHarness.start(appState:)` inside
`#if PV_DEV_HARNESS` after launch. Launch arguments:

```
-PVHarnessROM <absolute path or app-container-relative path>
-PVHarnessCore <core identifier, optional>
-PVHarnessFrames <n, default 300>
-PVHarnessOut <directory, default Documents/Harness/<timestamp>>
-PVHarnessExit <1|0, default 1>
```

Behaviour: import the ROM through `GameImporter` if it is not in the library, pick the core
(explicit, else the system default), launch the emulator view controller through the normal
launch path, count rendered frames via the core's frame counter (fallback: `n / 60` seconds),
write `screenshot.png` (window snapshot), `frames.json` (fps, frame count, core, elapsed),
copy the current PVLogging file as `log.txt`, then `exit(0)`; on any failure write
`error.txt` and `exit(1)`. `make dev-harness ROM=<path> TARGET=ui` runs it on the booted
simulator through `simctl launch --console`. Session B's debug API reuses `DevHarness` for its
"launch game, wait, screenshot" endpoint.

## 8. Core slices built outside the app — `Scripts/cores/build_slice.py`

```
build_slice.py <azahar|dolphin> <ios|ios-sim|tvos|tvos-sim> [--print-key] [--force] [--cache-dir DIR]
```

- **Key** = sha256 of: the core submodule tree (`git -C <sub> rev-parse HEAD` plus
  `git submodule status --recursive` for nested externals), the wrapped build script and
  toolchain file contents, the flag set (Azahar `CMAKE_OPTIONS`; Dolphin `DOL_FULL_LTO`,
  `DOL_PGO`, the profdata hash when used), `xcodebuild -version` and the SDK version for the
  slice, and the MoltenVK static slice hash for Azahar. `--print-key` prints it for CI.
- **Cache dir** default `$PV_CORE_CACHE` else `~/Library/Caches/Provenance/cores`; layout
  `<core>/<slice>/<key12>/<Product>-<slice>.framework` plus `stamp.json` (inputs, time, Xcode).
- **Behaviour:** cache hit → ensure the legacy output path points at it (symlink
  `Cores/Azahar/build/xcframework/PVlibAzahar-<slice>.framework` and
  `Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin-<slice>.framework`, so `PVAzahar`'s
  `PVAZAHAR_ARCHIVE` path and PVDolphin's framework reference are unchanged); miss → run the
  wrapped script for that one slice, move the product into the cache, write the stamp, link.
  Neither path repacks the multi-slice `.xcframework`; a separate `--xcframework` flag does that
  for distribution builds.
- **Aggregates:** `BuildPVlibAzahar` (Cores/Azahar/project.yml and the hand-edited pbxproj, both)
  and `Make XCFrameworks` (PVDolphin.xcodeproj) call `build_slice.py <core> <slice from
  $PLATFORM_NAME>` instead of the per-core scripts; Dolphin keeps its rsync into
  `$BUILT_PRODUCTS_DIR`. The wrapped scripts are not modified.
- **Registry:** `Scripts/maint/jobs.toml` gets `build_slice.py` as a job and lists
  `Cores/Azahar/build_azahar_core.py` and `Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py`
  under `[ignore]` with a comment.

## 9. CI

In `build.yml` and `testflight.yml`: replace the "Cache azahar build" step with one
`actions/cache` step per leg on `~/Library/Caches/Provenance/cores`, key
`cores-${{ runner.os }}-${{ matrix.platform }}-${{ azahar key }}-${{ dolphin key }}` (keys from
`build_slice.py --print-key` in a prior step), restore-keys `cores-${{ runner.os }}-${{ matrix.platform }}-`.
Keep `!Cores/Azahar/build` excluded from the submodules cache and add
`!Cores/Dolphin/dolphin-ios/build-*`. A new `dev-workspace.yml` (PR + develop) installs Tuist via
mise, runs `tuist generate --no-open`, and builds `Provenance-Dev-UI` for `generic/platform=iOS
Simulator` and `generic/platform=tvOS Simulator` with `CODE_SIGNING_ALLOWED=NO`; this becomes
the agent smoke build, replacing `Provenance-CI` in `agent-validation.yml` in the follow-up.

## 10. Pruning (shipping project)

Removed in this session, as one PR so `build.yml` validates both legs before merge:

- The 24 RETIRE cores from the audit, plus Desmume2015, melonDS, Atari800, Bliss, CrabEMU,
  Gambatte, O2EM, PokeMini and VisualBoyAdvance-M (33 cores): their embed/link/file
  references in every `Provenance.xcodeproj` target, their projects in
  `Provenance.xcworkspace`, `Cores/<X>` directories and `.gitmodules` entries, Core.plist /
  PVCoreLoader entries, and the orphan embedded frameworks with no producer (`PVLibRetro`,
  `PVFreeDO`, `PVSnesticle`, `PVMiniVMac`, `PVYabause`, `PVPCSXRearmed`, `PVDosBoxRetro`,
  `PVMelonDSRetro`, `PVMiniVMacRetro`). `PVFreeDO`'s producer is 4DO (UNSURE), so only the
  dangling reference goes, not the core.
- `RetiredCoreMigration` gains one entry per retired core that users could run (every core that
  was embedded and not `PVDisabled`, plus the DS pair): replacement thin core identifier
  (`atari800`, `freeintv`, `genesis_plus_gx`/`gearcoleco` for CrabEMU's SMS/Coleco, `gambatte`,
  `o2em`, `pokemini`, `vbam`; `melonds`+`melondsds`; `desmume`) and a battery-save rule derived
  from the native bridge's save path and extension versus the thin frontend's `<rom>.srm` in
  Battery Saves (DS: move `<rom>.sav`/`<rom>.dsv` from Save States to Battery Saves, also copy
  `.sav` → `.srm` for `melondsds`). Save states are not migrated (formats differ); the migration
  logs what it moved. It runs once per game on first launch after update, as the Jaguar entry does.
  Each replacement must be `enabled: true` for the platform in `cores.yml`; if one is not, that
  core is left in place and the PR says so.
- `Scripts/audits/check_pbxproj_sources.py` allowlist, `Scripts/maint/jobs.toml`, CLAUDE.md's core
  taxonomy (drop Jaguar and "Flycast" from active native; list the audit doc), and
  `docs/RELEASE_SMOKE_TESTS.md` (DS via `melondsds`, one migrated save).

Not pruned here, pending the maintainer: emuThree (Azahar must pass a device skin test first)
and the four UNSURE cores. Native extras lost with the seven save-check cores (Gambatte/VBA-M
cheats, Atari800/Gambatte/PokeMini/VBA-M rcheevos maps, Atari800 mouse) are accepted; the thin
wrapper's generic libretro cheat and memory-map paths cover them where the dylib exposes them.

## 11. Docs and skill

CLAUDE.md gets a "Dev workspace" section (generate, targets, harness, slice cache, pruning
rule: no new `Cores/` project without an audit row). A `fast-iteration` skill
(`.claude/skills/fast-iteration/SKILL.md`) gives the four recipes: add a focused target, build
one core slice, run the harness against a ROM, add a libretro dylib to a target. The roadmap doc
marks Workstream A done and lists the follow-up (swap CI/fastlane/release to the generated
project, retire `Provenance-CI` and `create_ci_target.rb`).

## 12. Verification

- `tuist generate --no-open` succeeds from a clean checkout after `make dev-generate`
  (which runs `build_slice.py` for the active slice of any `needsAggregate` core first, since
  Tuist resolves prebuilt paths eagerly).
- `xcodebuild -workspace Provenance-Dev.xcworkspace -scheme Provenance-Dev-UI build` for
  `generic/platform=iOS Simulator` and `generic/platform=tvOS Simulator`, `CODE_SIGNING_ALLOWED=NO`;
  same for `-Thin`; `-Azahar` for iOS Simulator (arm64) with a warm slice cache.
- Harness: `Provenance-Dev-UI` on a booted iPhone simulator with a homebrew GBA ROM from
  `UITesting/` (or a 1-byte placeholder if none ships; then the test asserts `error.txt`), exits
  0 and writes the four files.
- `python3 -m unittest Scripts/cores/tests/test_build_slice.py`: key changes when any input
  changes and is stable otherwise; cache-hit path only links; `--print-key` matches.
- Manifest tests (`Dev/Tests/ManifestTests.swift`, run via `swift test` in
  `Dev/Tuist/ProjectDescriptionHelpers` as a package, or a Python check if that is impractical):
  every `FocusedApp.libretro` name exists in `cores.yml` with `enabled: true`; every
  `CoreProduct` path exists; no local package is declared twice.
- Pruning PR: `build.yml` green on both legs; `xcodebuild -list` shows no removed target;
  the app launches a DS game through `melondsds` with a migrated save (device, maintainer).

## 13. Delivery (one session, six batches, each a commit series on develop except batch 5)

1. **Tooling and the first target.** `.mise.toml`, `Tuist.swift`, `Workspace.swift`,
   `Dev/Project.swift`, helpers with `CoreProduct`/`FocusedApp`/`DevSettings`, rows for mGBA,
   Stella, snes9x, PVCoreBridgeRetro, PVCheevos, MoltenVK; `Provenance-Dev-UI`; gitignore; delete
   root `project.yml`; `make dev`, `make dev-generate`, `make dev-ui`. Builds on both simulators.
2. **Remaining rows and targets.** Rows for the other KEEP cores; `Provenance-Dev-Azahar`
   (aggregate dependency) and `Provenance-Dev-Thin` with `LibretroCores`; `get-modules.sh --urls`;
   manifest tests.
3. **Harness.** `PVDevHarness`, `ProvenanceApp.swift` hook, `make dev-harness`, simulator run.
4. **Slice cache.** `build_slice.py` + tests, both aggregates, `jobs.toml`, `build.yml` and
   `testflight.yml` cache steps, `dev-workspace.yml`.
5. **Pruning PR.** §10. Merged when both CI legs pass.
6. **Docs.** §11, roadmap update, handoff memory.

## 14. Out of scope

- Replacing `Provenance.xcodeproj` for shipping builds; fastlane, release.sh, `Provenance-CI`.
- Tuist binary caching (`tuist cache`), `Tuist/Package.swift` / `.external` packages.
- Regenerating the `Cores/*` xcodeprojs (Azahar/Mupen xcodegen ymls stay as they are).
- Retiring the save-check and UNSURE cores, and emuThree.
- The debug/automation API (Workstream B) beyond the harness entry point it will reuse.
