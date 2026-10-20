# Remaining native cores: SwiftPM migration assessment

**Status:** Proposed implementation sequence; assessment only  
**Date:** 2026-10-19  
**Scope:** Azahar, emuThree, Dolphin and native PPSSPP. Preserve their identities and behavior while removing the remaining shipping core Xcode projects.

## Context and proposed decision

Use SwiftPM for the Swift APIs, Objective-C++ bridges, resources and app dependency graph. Keep upstream CMake/native builds behind reproducible XCFramework artifacts. This removes handmade core projects without immediately reimplementing each upstream build system in Package.swift.

This is a package integration migration, not a promise that an unprepared checkout can compile all emulator engines with plain `swift build`. For that clean-checkout experience, publish immutable XCFramework archives with checksums as binary dependencies. The alternative is an explicit repository preparation step before opening/resolving the workspace. Choose one artifact policy across these cores; do not rely on an app build phase to create binary targets after package resolution.

The current `Scripts/cores/build_slice.py` already provides a content-keyed native build/cache for Azahar and Dolphin. Extend that foundation rather than introduce four unrelated builders. Prepare artifacts before both shipping Xcode and Tuist resolve packages. Keep upstream submodule edits outside this change.

## Current state

| Core | Existing SwiftPM coverage | Native build today | Main remaining work |
| --- | --- | --- | --- |
| Azahar | Swift target, ObjC++ bridge target, static engine binary target; Tuist consumes PVAzahar-Dynamic | Cached CMake slice builder plus shipping Xcode aggregate | Stable artifact availability, direct dependencies, package test target, shipping integration |
| Dolphin | Swift target, ObjC++ bridge target, dynamic engine binary target; Tuist consumes PVDolphin-Dynamic | Cached upstream CMake builder plus shipping Xcode aggregate | Package-owned Sys resources, simulator behavior, dynamic embedding, shipping integration |
| emuThree | No root Package.swift; Core.plist accessor already has a package branch | 279-source native Xcode target, upstream project reference, loose native archives | Reproducible engine artifact, bridge/Swift split, dependency/platform audit |
| PPSSPP | No root Package.swift | Generated CMake Xcode dependency graph plus a 37-source local shader target and native bridge | Reproduce native build and shader overrides, bridge/Swift split, assets and graphics dependencies |

Counts are source-phase entries from the current parent projects, not estimates of upstream engine size.

## Azahar: closest to shipping package replacement

Evidence: `Cores/Azahar/Package.swift`, `project.yml`, `PVAzahar.xcodeproj`, `build_azahar_core.py`, `unexported_symbols.txt` and `PVAzaharCore/`.

- The package describes six Swift sources and eleven bridge/glue sources, matching the shipping wrapper's 17 source entries. The engine is a static archive wrapped in an XCFramework.
- The bridge already avoids importing its own Swift module. Swift injects its render-view class, user path, mute-switch policy and lifecycle callbacks. Preserve this pattern.
- The manifest conditionally adds the binary target based on files on disk. Its own comments document stale manifest-cache behavior. Make the graph deterministic once the artifact preparation/distribution policy is settled; a missing engine should not silently produce a different target graph.
- The current local XCFramework contains arm64 iOS, iOS Simulator, tvOS and tvOS Simulator slices. There is no x86_64 slice. Ensure all required slices are current for the same source/toolchain inputs; presence alone is not proof of freshness or runtime support.
- Keep `-idirafter` header ordering: upstream network/network.h collides with Apple's Network headers on case-insensitive volumes. Preserve C++ symbol hiding to avoid shader/compiler symbol coalescing with other cores.
- `PVAzaharCore.swift` directly uses Defaults, but the package only reaches it through PVSettings. Declare Defaults directly rather than repeat the indirect-link dependency problem just fixed in the libretro wrapper.
- Port the existing data-migrator unit tests into an appropriate SwiftPM test target. The shipping Xcode project has a dedicated test target; Package.swift currently has none. A lightweight migrator target/test arrangement can avoid requiring a native engine build for filesystem tests.
- Keep Core.plist's `PVAzahar.PVAzaharCore` principal class and Bundle.module access. Carry the existing plist generation/regeneration contract forward.
- Replace shipping link/embed/project references with the package product, then remove the old aggregate/project and its duplicate generation definition after device and simulator validation.

**Effort:** Low to medium relative to the others. Most source/module work is already done.

## Dolphin: existing package, integration and resource work

Evidence: `Cores/Dolphin/Package.swift`, `PVDolphinCore/Core/PVDolphinCore.mm`, `BuildFlags.xcconfig`, `PVDolphin.xcodeproj`, `Tuist/ProjectDescriptionHelpers/DevSettings.swift` and the local engine artifact metadata.

- The package describes eight Swift and twelve bridge/glue sources. The shipping project's extra source entry is its simulator debug stub.
- Unlike Azahar, the engine XCFramework contains dynamic frameworks. The observed iOS install name is `@rpath/PVlibDolphin-ios.framework/PVlibDolphin-ios`. Verify that the package product embeds/signs the selected engine framework and its dependencies with the matching install name; do not treat the engine like a static archive.
- The current local artifact has all four arm64 device/simulator slices. Existing comments describing it as device-only are stale for this checkout. Real package simulator compilation and boot are still unverified; the shipping project currently substitutes PVDebug.c on simulator SDKs.
- Config is already a resource of the Clang bridge target and is read through SWIFTPM_MODULE_BUNDLE. Sys is copied by a Tuist app post-script and read from the app bundle fallback. Bring Sys under explicit package resource ownership, preserving its directory tree and validating GameSettings, Wii data and Gecko code-handler lookup. A resource target/staged resource directory can expose the upstream data without modifying it. The submodule being inside the package is not itself a blanket SwiftPM prohibition; target paths and exclusions must be arranged correctly.
- The current package breaks the Swift/ObjC++ cycle using declarations and module-qualified runtime renderer lookups. Verify renderer classes and Swift categories survive linkage; injected renderer interfaces, as Azahar uses, are a cleaner follow-up if the lookup approach proves fragile.
- Preserve netplay and RetroAchievements source/dependency coverage, C++ compatibility header/flags, and shader-symbol isolation.
- Remove the shipping build aggregate only after pre-resolution artifact preparation also refreshes the selected native slice and XCFramework. Preserve the existing protection against embedding a stale cached engine.
- Replace shipping project integration, move/remove the Tuist Sys-copy workaround when package resources are authoritative, and validate iOS/tvOS dynamic dependencies.

**Effort:** Medium. The package exists; resource completeness and dynamic embedding need end-to-end proof.

## PPSSPP: extract a reproducible native build first

Evidence: `Cores/PPSSPP/PVPPSSPP.xcodeproj`, `BuildFlags.xcconfig`, `cmake/PPSSPP.xcodeproj`, `PVPPSSPPCore/Core/`, `cmake/assets` and `libretro_ppsspp/`.

- There is no root package. The native `PVPPSSPP` framework and the separate `ppsspp_libretro` target are different products. Packaging the native core does not require replacing it with the existing thin libretro implementation or assuming their states/features are interchangeable.
- The `psp` target depends on dozens of targets in a generated CMake Xcode project and separately compiles 37 local shader/glslang files, including renamed PPSSPP variants. Those overrides must be captured in a reproducible builder; a plain upstream CMake build is not automatically equivalent.
- Inventory generated headers/configuration and required engine libraries, including FFmpeg, then produce a platform-specific native XCFramework. Extend the shared slice/cache pipeline with source, patches/overlays, toolchain, flags and dependency versions in its key. Avoid absolute SDK paths and reliance on an existing CMakeCache.txt or generated Xcode project.
- Split the eight Swift source files from the ObjC++/C++ bridge and platform glue. The main bridge and both graphics-context headers import PVPPSSPP-Swift.h. Renderer construction, options and any other Swift calls need injected ObjC-facing interfaces or a lower independent helper target. The upper Swift target must not become a bridge dependency.
- Use a narrow public bridge module map; graphics-context headers include extensive engine C++ and the Swift header and should not become the public Clang umbrella.
- Preserve native memory-arena/platform adaptations such as MemArenaDarwin.cpp and the iOS audio/filesystem helpers; decide which live with the engine artifact versus the bridge to avoid duplicate definitions.
- Move Core.plist and the complete assets directory into package resources. CorePlist.swift currently still returns Bundle(for:) even under a package build. The ObjC++ code constructs assets paths from its framework bundle; replace that with an explicit package resource URL and test font/shader/flash0 layout.
- Audit MoltenVK ownership rather than copy its old dylib blindly. The project has an adjustment target copying a pinned legacy MoltenVK dylib, while current renderer code tries the shared MoltenVK framework and a dylib fallback. Preserve working behavior first; verify renderer/ABI compatibility before consolidating versions.
- Preserve netplay and RetroAchievements modules and categories. Keep shader symbols isolated from Azahar/Dolphin.
- Choose and test simulator behavior explicitly: the current project compiles PVDebug.m instead of the native core on both simulator SDKs. Arm64 alone does not make a device archive a simulator library.
- Add a Tuist CoreProduct entry and shipping package references only after the native artifact and source/resource package pass isolated validation.

**Effort:** High. Native build reproducibility and shader/platform overlays are more work than writing Package.swift.

## emuThree: compatibility core with the least reproducible engine inputs

Evidence: `Cores/emuThree/PVEmuThree.xcodeproj`, `BuildFlags.xcconfig`, `LibEmuThreeConfig.xcconfig`, `lib/`, `PVEmuThreeCore/`, and `Cores/Azahar/PVAzaharCore/PVAzaharDataMigrator.swift`.

- No root package exists. The wrapper has six Swift and seven Objective-C++ source entries. Its `emuthree` native target compiles 279 entries, including vendored Crypto++ and emulator files, and links many loose libraries.
- Twenty-two archives are tracked under lib/ and five under cmake/. A sampled libdynarmicEmuThree.a is arm64 with an iOS 11 minimum and SDK 16.4 metadata. This is evidence of an old device artifact, not a complete platform/ABI audit of every archive. Establish provenance and reproducible build recipes before describing these as interchangeable iOS/tvOS/simulator dependencies.
- Package the native engine and its actual dependencies as a validated XCFramework, or deliberately introduce maintainable source targets for the portions the repository can rebuild. Do not merely copy the current -L search paths into SwiftPM.
- Account for Boost, Dynarmic, Crypto++, glslang/SPIRV, Teakra, SoundTouch, zstd, FFmpeg, OpenAL, SDL2 and OpenSSL according to actual link usage. Remove unused dependencies only after checking symbols/behavior.
- Break the bridge's PVEmuThree-Swift.h dependency: it calls Swift parseOptions and directly constructs the Swift Vulkan/OpenGL view controllers. Use injected interfaces or an independent helper target; add a narrow public Clang module surface and explicit direct Swift dependencies.
- Core.plist's module identity and package resource accessor already exist. Preserve `PVEmuThree.PVEmuThreeCore`, option keys, user-data paths and save-state behavior.
- The current project uses simulator exclusions/debug stubs. Preserve a defined compatibility behavior until real simulator engine builds are available.
- Preserve symbol hiding, and audit fast-math/CPU tuning against actual supported device baselines instead of mechanically applying every inherited flag to every platform.
- Prior retirement notes are not authorization to remove this core. Azahar's migrator explicitly skips emuThree save states and only runs when the emuThree class is absent. Retaining the class identity matters to both state compatibility and migration behavior. Converting the build should not change that lifecycle.
- Add a Tuist entry and replace shipping references after validating the compatibility behavior and platform artifacts.

**Effort:** High, with greater uncertainty than PPSSPP because of the loose historical binary inputs. Can be kept deliberately narrow as a compatibility package.

## Options and trade-offs

| Approach | Benefit | Cost / limitation |
| --- | --- | --- |
| SwiftPM wrappers/resources plus prebuilt XCFramework engines | Reuses upstream native builds, removes handmade core projects, keeps bridge source editable | Requires artifact production/distribution and a clear freshness policy |
| Reimplement every engine and third-party build as SwiftPM source targets | Single source-oriented package build entry point | Must reproduce CMake generation, platform assembly, external dependencies and local overrides; substantially larger work |
| Leave each old native project behind an app build phase | Smallest immediate edit | Does not meet the goal; retains duplicate graphs and artifact-ordering hazards |

Recommend the first approach for this round. A later source-only conversion can be evaluated separately for individual libraries.

## Implementation order and completion criteria

1. **Azahar:** establish the shared artifact-before-resolution contract; promote its existing package to shipping and retain its tests.
2. **Dolphin:** reuse that contract, add package-owned Sys resources and verify dynamic embedding and simulator policy.
3. **PPSSPP:** build a reproducible engine artifact with its local shader/platform overrides, then split/package the wrapper and resources.
4. **emuThree:** reproduce/audit its historical native inputs and package the existing compatibility core without silently retiring it.

For each core, before deleting its old project:

- Resolve from a clean checkout using the chosen artifact mechanism, not just this machine's existing build folders.
- Verify source lists, direct dependencies and generated plist ownership; preserve the principal class/module and category/callback retention.
- Build the package/device integration for iOS and tvOS; exercise the declared simulator path separately. Adopt an explicit arm64 simulator policy or build/maintain the missing x86_64 support.
- Build internal Lite as a compile/integration check. Lite is not a public release or user-data migration gate.
- Smoke-test boot, renderer, controls/touch, audio, save/load, JIT fallback and applicable netplay/achievements; check packaged native dependencies and resource lookup.
- Remove both shipping and Tuist references to the handmade project and obsolete aggregate scripts. Avoid changing core identities or migrating save formats as a side effect.

## Validation performed for this assessment

- Read the four parent projects' target/source/resource/link phases, current manifests and native build/cache integration.
- `swift package describe --type json` succeeds for the existing Azahar and Dolphin packages with the current local artifacts. This does not prove either package compiles or runs.
- Parsed both XCFramework Info.plist files: each currently contains all four arm64 iOS/tvOS device/simulator slices. Confirmed Azahar's iOS engine is an archive and Dolphin's is a dynamic Mach-O with a platform-suffixed install name.
- Sampled native archive architecture/platform metadata and tracked-input counts for emuThree/PPSSPP.
- A temporary mixed Swift/Objective-C package is rejected by the selected Apple Swift 6.4 toolchain with `contains mixed language source files; feature not supported`, using both tools-version 6.0 and 6.4. Do not base this migration on unreleased documentation for mixed-language targets.
- No core implementation, package manifest or project was changed by this assessment. No full app/native build or runtime smoke test was performed in this audit.

## External references

- [Apple: Distributing binary frameworks as Swift packages](https://developer.apple.com/documentation/Xcode/distributing-binary-frameworks-as-swift-packages).
- [SwiftPM: Target-scoped resources](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html).
- [Mixed-language target proposal SE-0403](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0403-swiftpm-mixed-language-targets.md); local toolchain behavior was checked directly rather than inferred from main-branch documentation.
