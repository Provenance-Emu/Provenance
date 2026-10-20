# Azahar shipping and Tuist SwiftPM migration

- [x] Checkpoint the completed libretro migration and native-core assessment separately, preserving unrelated work.
- [x] Make the Azahar package graph deterministic and prepare cached native artifacts/headers before resolution.
- [x] Preserve module identity, resources, header ordering, C++ isolation and migrator tests.
- [x] Switch all five shipping Azahar consumers to the same SwiftPM product as Tuist; remove the handmade core project and generator.
- [x] Complete independent review, targeted checks, actual Tuist generation and the Lite device build.

## Implementation

Shipping Xcode and Tuist consume `PVAzahar-Dynamic`. The engine remains the cached CMake-built `PVlibAzahar.xcframework`; SwiftPM owns the Swift API, ObjC++ bridge, Core.plist and migrator support/test targets. The graph always declares its binary dependency. `make prepare-azahar AZAHAR_SLICE=ios` prepares artifacts before resolution; workspace opening, dev generation, CI, release and harness entry points perform preparation automatically.

`-ObjC` is forwarded through `-Xlinker` for Swift's dynamic-library driver. C++ visibility filtering stays at the final image link: compile-time hidden visibility let Xcode's intermediate `ld -r` step localize definitions before the Swift core and native engine could resolve them.

## Validation

- `Provenance-Lite (AppStore)` from `Provenance.xcworkspace`: **BUILD SUCCEEDED**, exit 0, arm64 iOS device, signing disabled, Xcode 27.1. Log: `/tmp/provenance-lite-azahar-spm-build-coordinated.log`.
- Embedded `PVAzahar-Dynamic.framework` and `PVAzahar_PVAzahar.bundle/Core.plist` verified in `Provenance Lite.app`. The plist matches the source, and the app's debug dylib loads the dynamic framework.
- Export audit: zero exported `__Z*` C++ symbols; ObjC bridge and `PVAzahar.PVAzaharCore` metadata remain available. `/tmp/azahar-framework-exports-check.log` and `/tmp/provenance-azahar-final-artifact-check.json`.
- Native cache tests: 31; migrator filesystem tests: 9; core package/resource checks: 3; shipping/Tuist drift tests: 8; CI manifest tests: 4. All **55 pass**. Migrator tests use actual sources and PVLogging in an isolated macOS validation manifest, without a native engine dependency.
- Actual Tuist generation and package resolution pass under installed Xcode 26.6. Its existing toolchain policy rejects active Xcode 27.1; that policy was preserved. `/tmp/azahar-tuist-generate-supported.log`.
- All five shipping consumers link/embed the package product. Shipping/Tuist and source audits, manifest checks, shell/Ruby/YAML syntax and preparation-order checks pass. SwiftLint reports no serious violations. Hosted CI execution is not claimed.
- Native artifact preparation hit cache key `da5029ec2e92` and packed the four cached arm64 slices. All 4,018 selected headers match the iOS header tree exactly.
- Independent read-only reviews found no concrete issues in the migration, CI wiring or shared UI compile repairs. No app runtime, simulator or tvOS build verification is claimed.

## Shared checkout and checkpoints

Prior work is checkpointed as `1ccbe7e968` (libretro/EP128) and `c176b34f58` (native-core assessment). Azahar's 27-file scope is saved independently from `develop` on `codex/azahar-spm` using a temporary Git index; the active UI checkout and its unrelated work are preserved. No upstream submodule sources or signing configuration were changed.

The concurrent UI lifecycle refactor exposed unrelated compile errors during validation. Shared helper relocations are separate signed UI-branch commits `022562da07` and `770333ae15`. Callback/helper access and root-view type-checking repairs remain with that UI refactor, outside the Azahar branch. The user authorized coordination with its task; it paused edits/builds for the successful run. Hashes of all 794 UI/app Swift files confirm **zero source changes during that build**.
