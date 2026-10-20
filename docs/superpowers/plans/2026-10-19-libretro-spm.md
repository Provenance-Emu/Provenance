# Libretro SPM migration implementation plan

**Goal:** Replace the remaining libretro handmade projects with Swift packages in the shipping and Tuist workspaces.

**Approved scope:** Convert PVCoreBridgeRetro; remove the disabled fMSX shell in favor of the existing buildbot/thin route; preserve EP128/Spectrum support with a source package. The four standalone core projects are outside this pass. EP128 usage is limited; favor a clean build system over additional bespoke infrastructure.

**Architecture:** Keep PVCoreBridgeRetro as the Swift module and dynamic product. Separate its Objective-C frontend and legacy bridge into PVLibRetroBridge, its independent Swift callbacks into PVLibRetroSupport, and the small legacy C runtime into libretro. Preserve Objective-C runtime names. EP128 keeps its PVEP128Emu Swift module and statically incorporates its unchanged upstream sources into the dynamic package product.

**Constraints:** iOS/tvOS 17 minimum; preserve upstream submodules and CodeSigning.xcconfig; preserve unrelated working changes. No full command-line app builds without explicit authorization.

## Tasks

- [x] Split the wrapper package, expose explicit public headers, wire callbacks without a dependency cycle, and register the existing tests in SPM. Check package descriptions and source coverage against the old project.
- [x] Package EP128's existing bridge and upstream source list, retaining its catalog identifier and resources. Check the manifest and compile the portable upstream sources where possible.
- [x] Switch the shipping app and Tuist to package products, remove obsolete project references and fMSX shell, and update validation documentation.
- [x] Validate package structure, Xcode project parsing, Tuist manifest checks, Swift syntax/lint, and existing repository checks. Request an independent libretro-wrapper review and address substantive findings.

## Review focus

- Swift/Clang dependency graph must be acyclic; generated Swift headers must come from the helper module.
- Runtime class lookup and dynamic symbol exports must survive package linkage.
- Public headers must not expose unavailable platform SDKs or private implementation headers.
- Hatari and EP128 resources must resolve through the correct package bundle.
- fMSX removal must preserve the enabled libretro entries and Enterprise/Spectrum must retain an available implementation.

## Validation limits

Package graph and static validation do not prove device runtime behavior. iOS/tvOS Xcode build and core boot/input/state smoke tests remain necessary before release.

## Recorded validation

- Both package descriptions load; library targets have separate Swift/Clang source sets.
- EP128 host syntax checks pass for 54 C++ sources and one C source.
- An isolated Xcode-backed SwiftPM build validates the Swift helper → ObjC frontend → Swift API layering and flat C dependency headers.
- Core package module/resource checks, CI core-manifest tests, Tuist manifest checks, and workspace source audit pass.
- Swift syntax parsing passes; SwiftLint reports existing warnings and no serious violations.
- Independent libretro review identified the dynamic framework filename and Hatari resource bundle lookup; both are corrected. A Swift resource test covers Hatari's bundled config.
- Xcode app validation initially failed before compilation with “Failed to receive dependency graph response”; a fresh workspace instance progressed to package/plugin preparation but did not reach source compilation. The temporary validation workspace was closed. Subsequent successful CLI app validation is recorded below; device boot/input/save-state validation remains outstanding.

## Lite build follow-up

- Enabled Clang/C++ modules for both new Objective-C++ bridges.
- Moved the archive resolver into `PVLibRetroSupport`, beneath the ObjC frontend, and updated its tests' module import.
- Added the legacy thread-lock header explicitly. Disabled the unavailable RetroArch netplay driver consistently in the bridge/runtime; thin-core netplay uses PVNetplay.
- Device SDK checks pass for the support Swift module, all 11 bridge implementation files, all 11 compatibility-runtime sources, and the main Swift module with its resource accessor.
- An Objective-C++ SwiftPM interop probe reproduces the missing-module failure without the flags and builds successfully with them.
- Full Lite device validation completed successfully with zero errors.

- Lite device compilation reached the dynamic wrapper link and exposed missing direct Defaults/PVPrimitives products plus unused full-RetroArch runtime references.
- Added the direct Swift products and reduced the C target to its four used components (threading, dylib loading, keyboard maps, dummy core). Disabled the absent built-in FFmpeg core.
- Replaying the wrapper's actual device link with these inputs succeeds. The full Lite rebuild with the corresponding manifest changes also succeeds.

## Final Lite validation

- `Provenance.xcworkspace`, scheme `Provenance-Lite (AppStore)`, generic iOS device, arm64, Debug, signing disabled: **BUILD SUCCEEDED**, zero errors.
- Build log: `/tmp/provenance-lite-spm-device-fixed-build.log`.
- The built `PVCoreBridgeRetro.framework` exports the thin core/frontend, legacy bridge, archive resolver, JIT callback and VFS callback symbols.
- Package structure/resource tests: 3 passed. SwiftLint reports existing warnings and zero serious violations. `git diff --check` passes.
- Simulator validation was interrupted during native compilation; no simulator build or emulator runtime result is claimed. The other four core migrations remain deferred.
