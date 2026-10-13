# Generated project + dependency de-duplication — design (2026-10-13)

**Status:** draft written under a time cut; items marked `UNVERIFIED:` name the file to check.
**Inputs:** `2026-10-10-dev-workspace-design.md`, `2026-10-11-core-spm-conversion.md`,
`2026-10-12-azahar-dolphin-package-decision.md`, `2026-10-10-core-audit.md`, memory notes
`core-spm-conversion-oct2026`, `weak-symbol-coalescing-core-frameworks`, `intel-unsupported-oct2026`.
**Binding constraints:** iOS/tvOS 17+, arm64 only, no Catalyst, buildbot libretro dylibs untouched,
no new `Cores/` project without an audit row, never commit Tuist output or the dev `Package.resolved`,
every new script registered in `Scripts/maint/jobs.toml`.

## 1. Current state audit

| Thing | Built by | Consumed by shipping `Provenance.xcodeproj` as |
|---|---|---|
| App targets Provenance / Provenance (AppStore) / Lite / XL / UnderDevelopment, TopShelf, Spotlight, widgets, DriverKit | hand-maintained `Provenance.xcodeproj` (+ `Provenance.xcworkspace`) | — |
| `Provenance-Dev-{UI,Thin,Azahar,N64,Dolphin,Coreless}` | Tuist (`Dev/Project.swift`, `Workspace.swift`, `Tuist/ProjectDescriptionHelpers/{CoreProduct,FocusedApp,DevSettings,LibretroCores}.swift`) | not consumed; gitignored output |
| snes9x, FCEU, Genesis-Plus-GX, Mupen64Plus (+4 plugins), Mednafen, Stella, ProSystem, PicoDrive, TGBDual, mGBA, and deprecated Atari800/Bliss/CrabEMU/Gambatte/VBA-M/4DO | `Cores/<X>/Package.swift` (`-Dynamic` products) | `XCLocalSwiftPackageReference` rows (pbxproj `relativePath = Cores/...`), embedded as `PV*-Dynamic` |
| Azahar | `Cores/Azahar/PVAzahar.xcodeproj` (xcodegen `project.yml` + hand-edited pbxproj) → `BuildPVlibAzahar` aggregate → `Scripts/cores/build_slice.py azahar <slice>` → links `build/xcframework/PVlibAzahar-<slice>.framework/PVlibAzahar` by path | workspace project ref; `PVAzahar.framework` embedded (5 targets). `Cores/Azahar/Package.swift` exists (dev only, optional `binaryTarget`) |
| Dolphin | `Cores/Dolphin/PVDolphin.xcodeproj` → `Make XCFrameworks` aggregate → `build_slice.py dolphin` → `dolphin-ios/BuildiOSXCFramework.py` → `PVlibDolphin.xcframework` (dynamic) | workspace ref; `PVDolphin.framework` + `PVlibDolphin.xcframework` embedded (3 targets). `Cores/Dolphin/Package.swift` dev-only |
| emuThree (3DS legacy), PPSSPP, ep128emu, fmsx | hand-maintained xcodeprojs; emuThree links 14 prebuilt `lib*.xcframework`s; PPSSPP links `lib/libpsp.a` + own ffmpeg `.a`s + `lib/libMoltenVK_1.3.250.1.dylib` | workspace refs; frameworks embedded |
| PVCoreBridgeRetro (thin wrapper) | `PVCoreBridgeRetro/PVCoreBridgeRetro.xcodeproj` with explicit file lists (`Package.swift` unusable: mixed target) | workspace ref; also `.project` row in `CoreProduct.coreBridgeRetro` for the dev apps |
| MoltenVK | `MoltenVK/Package.swift` (4 `binaryTarget`s: dynamic, static, 1.2.8, Catalyst) | local package; `MoltenVK.framework` **and** `MoltenVK-1.2.8.framework` both end up in the app (seen in DerivedData Debug-iphoneos build) |
| libretro cores | buildbot zips → `CoresRetro/RetroArch/scripts/get-modules.sh`, `make_frameworks_retroarch.sh`, `validate_frameworks.sh` | Run Script phases "Script: Get RetroArch Modules" (4), "Generate Frameworks" (3), "Validate Frameworks" (3), `output_*.xcfilelist` per variant |

Resource handling today:
- `PVCoreLoader/Sources/PVCoreLoader/Resources/RetroArchCore.plist` is a **symlink** to `CoresRetro/RetroArch/Core.plist` (SwiftPM `.process` of a symlink; works, fragile in worktrees).
- Native cores carry `Core.plist` as a package `.process` resource; data files (`carthw.cfg`, `GLideN64.ini`, Mednafen `notes/`, Dolphin `Resources/Config`) as `.copy`.
- Dolphin `Data/Sys` lives in the submodule and is copied by a Run Script (`DevSettings.dolphinSysScript`; xcodeproj bundles it in shipping).
- Slang shaders: `Scripts/shaders/embed_slang_shaders.sh` → `fetch_slang_shaders.py --out $TARGET_BUILD_DIR/.../SlangShaders` ("Script: Embed Slang Shaders", 6 targets; `FocusedApp.slangShaders`).
- Hand-edited fallbacks in "generated" projects: `PVAzahar.xcodeproj` has Defaults/DefaultsMacros package refs not in `project.yml` (`18e4cf6946`); the `PVDolphin.xcodeproj` aggregate script is edited in the pbxproj directly.
- Stale cruft: the shipping pbxproj carries ~400 `ProjectRef` entries to `Cube.xcodeproj`, `MoltenVK*.xcodeproj`, `ExternalDependencies.xcodeproj` (68–70 each) plus refs to `Cores/emuThree/lib/libav*.xcframework`, `MoltenVK/glslang.xcframework`, `Dependencies/SDL2.xcframework`, `Dependencies/FFMpeg` ffmpeg-kit. UNVERIFIED: which targets actually link these (`Provenance.xcodeproj/project.pbxproj`, search `glslang.xcframework in Frameworks`).
- Checks that exist: `Scripts/audits/check_pbxproj_sources.py` (unreferenced sources per xcodeproj), `Scripts/dev/check_dev_manifest.sh` (compiles helpers against `ProjectDescription.framework`, validates cores.yml names/paths/duplicate packages), `Scripts/maint/jobs.toml` jobs `dev-manifest`, `pbxproj-sources`, `spm-validate`.

## 2. Dependency and symbol-collision inventory

Sources: `grep` over `Cores/*/Package.swift`, `PV*/Package.swift`, core pbxprojs, `Cores/*/externals`, `Dependencies/`, `MoltenVK/`; `nm -m` over the frameworks of the local DerivedData `Debug-iphoneos/Provenance.app` (stale: predates #3742, so PVFCEU/PVGenesis/snes9x still appear as xcodeproj frameworks — rerun on a fresh archive).

| Library | Carried by | How | Collision risk |
|---|---|---|---|
| zlib | 28 `linkedLibrary("z")` across core packages; Mupen `CZlib` `.systemLibrary` (no pkgConfig, by design); Dolphin `Externals/zlib-ng` (static in PVlibDolphin); PPSSPP `libretro_ppsspp/ext/zlib`; emuThree `cmake/zstd/zlibWrapper`; ZipArchive `minizip`; SWCompression `Sources/Zlib` (Swift) | SDK `libz.tbd` for most; 2–3 static copies (Dolphin zlib-ng, PPSSPP) | LOW: C symbols, zlib-ng is namespaced; only hazard is Homebrew pkg-config leaking `-L/opt/homebrew` (never use `pkgConfig:` for SDK libs) |
| ffmpeg | `Dependencies/FFMpeg/ffmpeg-kit-full-gpl-6.0-*` (ffmpegkit + 7 `libav*.framework` embedded in the app); emuThree `lib/libav*.xcframework` (5); PPSSPP `cmake/ffmpeg/{ios,appletvos}/lib/lib*PPSSPP.a` (renamed static); Dolphin `Externals/FFmpeg-bin` | up to **4 copies**: 1 dynamic app-level, 3 static inside cores | MEDIUM: C symbols, no weak coalescing, but ffmpeg-kit dynamic frameworks + static copies in the same process = duplicate globals when both initialise; also ~40 MB of IPA. UNVERIFIED: who uses ffmpegkit at app level (`grep -n ffmpegkit Provenance.xcodeproj/project.pbxproj`, PVLibrary/PVUI imports) |
| libpng | Mupen `Sources/libpng` (source target, `PNG_ARM_NEON_OPT=0`); Dolphin `Externals/libspng` + `Cores/Dolphin/cmake/Externals/libpng`; PPSSPP `libpng17PPSSPP.a` | static per core | LOW (C, distinct versions renamed in PPSSPP) |
| SDL / SDL2 | `Dependencies/SDL2.xcframework` embedded by emuThree target; Azahar `externals/sdl2` (`ENABLE_SDL2=OFF`, not built); Dolphin `Externals/SDL` (UNVERIFIED whether the iOS cmake build enables it: `Cores/Dolphin/dolphin-ios/CMakeLists.txt` `ENABLE_SDL`); Mupen `Sources/Compatibility/SDL` (stubs, not real SDL) | 1 dynamic (emuThree), maybe 1 static (Dolphin) | LOW once emuThree is retired |
| glslang | Dolphin `Externals/glslang` (static in PVlibDolphin, hidden via second-pass `-unexported_symbols_list`); Azahar `externals/glslang` (static in PVlibAzahar, `__Z*` hidden); PPSSPP `cmake/ext/glslang` → `libMachineIndependentPPSSPP.a` etc. into `PVPPSSPP.framework`; emuThree `libglslang/libMachineIndependent/libSPIRV/libOSDependent/libHLSL/libGenericCodeGen.xcframework`; `MoltenVK/glslang.xcframework` referenced by `Provenance.xcodeproj`; snes9x `external/glslang` (UNVERIFIED not compiled: `Cores/snes9x/Package.swift` sources) | **5 copies**, 4 different versions | **HIGH — the known crash class.** dyld coalesces exported weak C++ (template instantiations) across images; PVlibDolphin's `addSwizzle` crashed Azahar (Oct 8). Local nm: PVlibDolphin-ios still exports 726 weak (Dolphin-unique namespaces), PVAzahar 70, PVEmuThree 101, PVPPSSPP 468 (Spline/Rasterizer/basisu) |
| SPIRV-Cross / SPIRV-Tools | Dolphin `Externals/spirv_cross`; PPSSPP `ext/SPIRV-Cross` (`libspirv-cross-*PPSSPP.a`); `MoltenVK/SPIRVCross.xcframework`, `SPIRVTools.xcframework`; Azahar `sirit` + `spirv-tools`; MoltenVK dylib itself embeds SPIRV-Cross | 4–5 copies | HIGH, same mechanism as glslang (`__ZN4spv`, `__ZN5SPIRV`, `__ZN12spirv_cross`) |
| fmt | Dolphin `Externals/fmt` (v12); Azahar `externals/fmt`; emuThree `libfmt.xcframework`; snes9x-src `external/fmt` (UNVERIFIED compiled) | 3–4 static copies | HIGH: header-only templates = weak externals in every image that doesn't hide them (Dolphin's fmt instantiations were part of the Oct 8 crash) |
| MoltenVK | app: `MoltenVK/MoltenVK/dynamic/MoltenVK.xcframework` (1.2.11) **and** `MoltenVK-1.2.8.xcframework` both embedded; static `MoltenVK/MoltenVK/static` linked into PVlibAzahar (link-only, runtime dlopen of app copy); Dolphin `Externals/MoltenVK*` + `Cores/Dolphin/lib/libMoltenVK_Dolphin.dylib`; PPSSPP `lib/libMoltenVK_1.3.250.1.dylib` (copied to `libMoltenVK_PPSSPP.dylib` by a script phase); emuThree `cmake/MoltenVK/MoltenVK.xcframework` | **≥5 copies, 4 versions** | MEDIUM: separate install names so dyld keeps them apart, but every copy is ~15 MB and each core pins a different Vulkan feature set; thin wrapper + Azahar already share the app copy |
| boost | Azahar `externals/boost` (serialization, iostreams static) | 1 | LOW (hidden by `__Z*` list) |
| libarchive | none. Archive handling is SWCompression (Swift), PLzmaSDK (266 weak `plzma::`), Unrar, LzhArchive, ZipArchive (`Dependencies/ZipArchive`, minizip); legacy `PVLibrary/Sources/Deprecated/LzmaSDKObjC` | — | LOW |
| zstd / lz4 / lzma | Dolphin `Externals/{zstd,lz4,liblzma}` (`USE_SYSTEM_ZSTD=OFF`); Azahar `externals/zstd`; PPSSPP `ext/zstd`; emuThree `cmake/zstd`; SWCompression `LZ4/LZMA/XZ` (Swift) | 4 static C copies | LOW (C) |
| nlohmann::json | PVStella-Dynamic (14 weak `nlohmann`), RealmSwift (16 weak `nlohmann`) | header-only in both | MEDIUM: exactly the weak-coalescing pattern, two versions, both loaded at launch. Hide in Stella (`-fvisibility=hidden` + `-fvisibility-inlines-hidden` in `Cores/Stella/Package.swift` cxxSettings) |
| libretro-common | `PVCoreBridgeRetro/Sources/retro/libretro-common`; Azahar, PPSSPP, snes9x, fmsx submodule copies | 1 compiled (thin wrapper) + submodule copies | LOW |
| mbedtls, enet, soundtouch, minizip-ng, curl, libiconv, bzip2 | Dolphin Externals (static); Azahar enet/soundtouch/cryptopp/libressl/httplib | static, C mostly | LOW |
| Mednafen bsnes (`bSNES_v`), snes9x `TileImpl`, FCEU, PPSSPP, Dolphin own namespaces | 390 / 114 / 323 / 468 / 726 weak externals | own code | LOW unless two copies of the same emulator load (snes9x native + `snes9x.libretro`: UNVERIFIED that the dylib hides its C++; nm `snes9x.libretro.framework`) |

Headline: the only libraries that can crash the process are the C++ template-heavy ones — glslang, SPIRV-Cross/Tools, fmt, nlohmann, VMA — and only when **two dynamic images export them weak**. C libraries (zlib, png, ffmpeg, zstd) cost size and audit time, not crashes.

## 3. Options and recommendations

### (a) One copy of a C/C++ library across SwiftPM core packages
| Option | Pros | Cons |
|---|---|---|
| `.systemLibrary` (SDK libs only: z, bz2, iconv, xml2, c++) | zero build, zero collision | only for what the SDK ships; never with `pkgConfig:` (Homebrew leak) |
| Shared source package `PVVendor/<lib>` (static target, `-fvisibility=hidden`) | one version, SwiftPM links it statically into each `-Dynamic` product; no symbol export | still N static copies in N images (fine when hidden); every consumer's C flags must match (`PNG_ARM_NEON_OPT`, `ZSTD_*`) |
| Shared **dynamic** `PVVendor-<lib>.framework` | truly one copy | every core's bridge must link it by name; dyld load order; for C++ libs this *is* the coalescing hazard unless the dynamic lib is the *only* exporter |
| Prebuilt `binaryTarget` xcframework from a `build_slice.py`-style script | fast rebuilds, cacheable per content key, same path for cmake and SwiftPM consumers | must exist before package resolution (the PVlibAzahar/PVlibDolphin problem); needs `--xcframework` packing at every xcodebuild entry point |

**Recommendation:** SDK libs via `.systemLibrary`/`linkedLibrary` (status quo). For libpng/zstd/lz4/fmt used by *SwiftPM* cores: one `PVVendor` package with static, hidden-visibility targets, consumed by Mupen (libpng), Stella (nlohmann), snes9x (fmt if compiled). For the cmake cores, do **not** try to share: hide instead (see c) and pin the external to the same upstream tag where cheap. Prebuilt binaryTargets only for whole emulator libraries (Azahar/Dolphin), not for leaf libs.

### (b) cmake-built cores (Azahar, Dolphin, PPSSPP, emuThree) without forking
| Mechanism | Verdict |
|---|---|
| cmake `-D` overrides + `CMAKE_PREFIX_PATH`/toolchain file (`USE_SYSTEM_MOLTENVK=ON -DMOLTENVK_LIBRARY=…`, `USE_SYSTEM_ZSTD`, `ENABLE_SDL2=OFF`) | **first choice**: already how `build_azahar_core.py` and `BuildiOSXCFramework.py` work; zero fork cost; put the flag set in `build_slice.py`'s key inputs (it already hashes `CMAKE_OPTIONS`) |
| Patch files applied at build time (`git apply --check` then `git apply`, idempotent via a `.patches-applied-<sha>` stamp in the build dir, never in the submodule) | **second choice** for things upstream won't take (tvOS compile fixes). Store under `Cores/<X>/patches/NNN-*.patch`, apply in `build_slice.py` to a build-dir copy (`git worktree add --detach`), so the submodule stays clean and the content key covers the patch text |
| SwiftPM build-tool plugin running cmake | rejected: plugins are sandboxed (no network, restricted paths), cannot produce a binaryTarget, and run per-resolve; wrong tool for a 30-minute cmake job |
| Tuist-generated Run Script phase calling `build_slice.py` | fine for the aggregate step (what `BuildPVlibAzahar` is today), but it cannot satisfy a `binaryTarget` at resolution time; so the slice must be built **before** `tuist generate`/`xcodebuild` (Makefile `make dev-azahar` pattern, CI pre-step keyed on `--print-key`) |
| Fork (`Provenance-Emu/azahar` branch `provenance`, `PATCHES.md`) | only when a patch touches CMakeLists in a way `-D` can't express and upstream rejects it; keep the current "fork = upstream + rebased patch stack, auto-synced" rule |

**Recommendation:** `-D` overrides first, build-time patch stack second, fork last. Dolphin's `-DDOLPHIN_UNEXPORTED_SYMBOLS_LIST` is a fork-side hook already; keep it.

### (c) Hiding symbols (the fallback that actually prevents crashes)
- `-fvisibility=hidden -fvisibility-inlines-hidden` on every core's C++ (Azahar bridge has it; add to Stella, snes9x, Mednafen, FCEU, PPSSPP, Mupen GlideN64 packages/xcconfigs).
- `-Wl,-unexported_symbols_list,<file>` with `__Z*` for every image that only exposes an ObjC/Swift surface (Azahar, emuThree today; add PPSSPP, Mednafen, Stella, snes9x). Dolphin can't (bridge imports `MMU::HostRead<>`), so its generated third-party list stays.
- `-Wl,-hidden-lX` for static libs linked by path (PPSSPP's `lib*PPSSPP.a`, Azahar's merged archive).
- Gate: a CI script `Scripts/audits/check_weak_exports.py` that runs `nm -m` on every embedded framework of a built app, intersects weak-external sets pairwise (`comm -12`), and fails on any overlap outside an allowlist. Register it in `jobs.toml`.

### (d) Resources in generated projects
- Tuist: `resources:` globs + `.folderReference` (used today); copy-files via `TargetScript` for submodule data (Dolphin Sys). SwiftPM: `.process` for plists, `.copy` for data dirs; a package cannot reference files outside its root, so submodule data stays a Run Script.
- Replace the `RetroArchCore.plist` symlink with a `.copy` of a real file generated by `Scripts/maint` (`core-lists` job) — symlinks break `tuist generate` in worktrees and `git add -A` has committed them as self-links before.
- Slang shaders stay a post script (`DevSettings.embedSlangShadersScript`); it already works in both worlds.

### (e) Keeping shipping xcodeproj and Dev workspace from drifting
Until the shipping project is generated: one table (`CoreProduct`) is the source of truth; add a check in `check_dev_manifest.sh` (or a new `Scripts/audits/check_shipping_vs_dev.py`) that parses `Provenance.xcodeproj/project.pbxproj` `XCLocalSwiftPackageReference` + Embed phases and asserts every `.package` row in `CoreProduct.all` appears there with the same product name, and every embedded `PV*-Dynamic` has a row. Fails PRs that add a core on one side only.

## 4. Phased plan

| # | Goal | Files | Acceptance | Rollback |
|---|---|---|---|---|
| 1 | **Weak-export gate + cheap hiding.** Add `Scripts/audits/check_weak_exports.py` (nm/comm over `*.app/Frameworks`, allowlist file); add `-fvisibility=hidden -fvisibility-inlines-hidden` to Stella, snes9x, Mednafen, FCEU, Mupen packages; `__Z*` unexported list for PPSSPP (`Cores/PPSSPP/BuildFlags.xcconfig`) | `Scripts/audits/check_weak_exports.py`, `Scripts/audits/weak_exports_allowlist.txt`, `Scripts/maint/jobs.toml`, `Cores/{Stella,snes9x,Mednafen,FCEU,Mupen64Plus}/Package.swift`, `Cores/PPSSPP/BuildFlags.xcconfig`, `.github/workflows/build.yml` (post-build step on the iOS leg) | gate runs green on `build.yml` iOS; nlohmann overlap between Stella and RealmSwift gone. **Status 2026-10-13:** gate script, allowlist, jobs.toml entry, advisory build.yml step and the Stella flags landed; snes9x/Mednafen/FCEU/Mupen flags and the PPSSPP list are still open (no confirmed overlap yet; apply once a fresh-archive audit names them) | revert the flag commits; the gate is advisory (`continue-on-error`) for the first week |
| 2 | **Shipping ↔ dev drift check.** **Done 2026-10-13:** `check_shipping_vs_dev.py` compares `CoreProduct` `.package` rows with the pbxproj's local package refs + product names both ways, with documented exception tables (Azahar/Dolphin shipping-side, deprecated + 4DO dev-side); unit-tested; runs in `xcode-project-sources.yml` (not agent-validation) | `Scripts/audits/check_shipping_vs_dev.py`, `Scripts/tests/test_check_shipping_vs_dev.py`, `jobs.toml`, `xcode-project-sources.yml` | script passes on develop; fails when a `CoreProduct` row is removed | delete script |
| 3 | **Resource de-symlink + MoltenVK dedup.** Replace `RetroArchCore.plist` symlink with a generated copy; drop `MoltenVK-1.2.8` product and the stale `Cube/MoltenVK*/ExternalDependencies` ProjectRefs from the shipping pbxproj; PPSSPP uses the app `MoltenVK.framework` (same as Azahar/thin) | `PVCoreLoader/Sources/PVCoreLoader/Resources/RetroArchCore.plist`, `Scripts/maint/jobs.toml` (`core-lists` writes it), `MoltenVK/Package.swift`, `Provenance.xcodeproj/project.pbxproj`, `Cores/PPSSPP/PVPPSSPP.xcodeproj` | `build.yml` both legs; one `MoltenVK.framework` in the IPA; PSP native boots on device (owner) | revert pbxproj hunk; keep 1.2.8 product |
| 4 | **Retire emuThree + ffmpeg copies.** Remove emuThree target/embeds (audit: RETIRE-after-save-check, Azahar migrator exists), `Cores/emuThree/lib/*.xcframework`, `Dependencies/SDL2.xcframework`; decide app-level ffmpeg-kit (UNVERIFIED consumer) | `Provenance.xcworkspace/contents.xcworkspacedata`, pbxproj, `Cores/emuThree/`, `.gitmodules`, `RetiredCoreMigration` entry | both CI legs; IPA shrinks; 3DS still launches via Azahar | git revert |
| 5 | **Azahar + Dolphin on packages in shipping** (reverses the 2026-10-12 decision once prerequisites hold): `build_slice.py <core> <slice> --xcframework` as a pre-resolution step in `release.sh`, `build.yml`, `testflight.yml`, `make lite`; Dolphin simulator slices or device-only; Sys copy script on every Dolphin-linking target | `Scripts/cores/build_slice.py`, `release.sh`, `.github/workflows/{build,testflight}.yml`, `Makefile`, pbxproj (swap project refs for `XCLocalSwiftPackageReference` rows) | both legs green on a cold cache; `check_weak_exports` green | keep `.project` rows; the xcodeprojs are not deleted until phase 7 |
| 6 | **Shipping project generated by Tuist.** `FocusedApp`-style `ShippingApp` rows for Provenance/AppStore/Lite/XL (+ extensions TopShelf, Spotlight, widgets), libretro xcfilelists → `LibretroCores` lists, entitlements, `Build.xcconfig` inheritance; CI, fastlane and `release.sh` switch to `Provenance-Dev.xcworkspace`-style generated `Provenance.xcworkspace`; `Provenance-CI` and `create_ci_target.rb` retired | `Tuist/ProjectDescriptionHelpers/ShippingApp.swift`, `Dev/Project.swift` → `Project.swift`, `.gitignore`, `fastlane/`, `release.sh`, all workflows | TestFlight upload from the generated project; IPA diff vs previous build (framework list identical) | branch-only until a TestFlight build passes the smoke list in `docs/RELEASE_SMOKE_TESTS.md` |
| 7 | **Delete per-core xcodeprojs** (`Cores/*/PV*.xcodeproj`, `project.yml`s, `swiftgen.yml`s), PVCoreBridgeRetro split into a SwiftPM-buildable layout (ObjC and Swift targets), `check_pbxproj_sources.py` narrowed to what remains. Audit-row rule stays: adding a core = a `CoreProduct` row + an audit row in `2026-10-10-core-audit.md` | `Cores/*/`, `PVCoreBridgeRetro/Package.swift`, `Scripts/audits/pbxproj_sources_allowlist.txt`, CLAUDE.md core taxonomy | `tuist generate` + both legs; `check_dev_manifest.sh` | restore from git |
| 8 | **PVVendor package** (libpng, nlohmann, fmt, zstd as hidden static targets) consumed by Mupen/Stella/snes9x; cmake cores pinned to matching upstream tags via `-D` where offered | `PVVendor/Package.swift`, `Cores/{Mupen64Plus,Stella,snes9x}/Package.swift` | weak-export gate; IPA size delta | per-core revert |

Phase 1 is a few hours and prevents the next Oct-8-style crash; phases 2–4 are a session each; 5–7 are the generated-project milestone (2–3 sessions, CI-bound); 8 is optional size work.

## 5. Risks and open questions (defaults in bold)

0. **MoltenVK versions are deliberate, not drift (owner, 2026-10-13).** The copies exist because some cores did not work with certain MoltenVK versions or with certain MoltenVK optimizations enabled. Consolidation therefore means *testing*, not just deleting: pick the latest stable MoltenVK, build each Vulkan consumer (Azahar, thin wrapper + PPSSPP/flycast dylibs, Dolphin, native PPSSPP) against it, and run the per-core device smoke list before removing a pinned copy. Keep a per-core override path (own MoltenVK copy or config-flag set) for any core that regresses, and record the failing version/flag pair next to the override so it can be retried on the next MoltenVK release. **Default: phase 3 starts with a MoltenVK compatibility matrix (core × version × flags) filled from device tests, and removes a copy only after its row is green.**

1. Is ffmpeg-kit at app level still used (video previews? Azahar has `ENABLE_FFMPEG=OFF`)? **Default: assume unused; remove in phase 4 behind a CI build, restore if PVUI/PVLibrary fail to link.**
2. Dolphin without simulator slices blocks local simulator runs of the full app on packages. **Default: Dolphin is device-only in the generated project (`condition: .when([.ios,.tvos])` device SDK filter via `EXCLUDED_SOURCE_FILE_NAMES` is not available to packages); simulator builds of the shipping app ship without Dolphin.**
3. PPSSPP native vs thin (audit UNSURE). **Default: keep native PPSSPP but hide its C++ (phase 1) and move it to the app MoltenVK (phase 3); do not convert it to a package.**
4. Does hiding `__Z*` in Mednafen/Stella/snes9x break anything that dlsym's into them (cheevos memory maps use ObjC entry points)? **Default: no; the gate plus the device smoke list catches it.**
5. Will the owner accept `build_slice.py` as a mandatory pre-step for every xcodebuild entry point (phase 5)? **Default: yes, since CI already caches by `--print-key`.**
6. Tuist 4.200 pinned; `compatibleXcodeVersions: .upToNextMajor("26.0")`. **Default: stay on 4.200 until phase 6 begins, then bump once.**

## UNVERIFIED (next session)
- Which shipping targets link `MoltenVK/glslang.xcframework`, `Dependencies/SDL2.xcframework`, ffmpeg-kit: `Provenance.xcodeproj/project.pbxproj` (grep `in Frameworks */` for those names).
- snes9x compiles `external/glslang` or `external/fmt`? `Cores/snes9x/Package.swift` source lists.
- Dolphin iOS cmake enables SDL? `Cores/Dolphin/dolphin-ios/CMakeLists.txt`, `BuildiOSXCFramework.py` flags.
- `snes9x.libretro` / `mame.libretro` weak exports vs native cores: `nm -m` on a Release archive (local DerivedData app is stale, pre-#3742).
- `Cores/Dolphin/cmake/Externals/*` purpose (second externals tree beside `dolphin-ios/Externals`).
- Phase 6 extension targets (TopShelf, Spotlight, widgets, DriverKit) need their own `ShippingApp` rows; not inventoried here (`Provenance.xcodeproj` `productName` list in §1).
