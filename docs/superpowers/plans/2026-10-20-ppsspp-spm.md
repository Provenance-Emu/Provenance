# PPSSPP SwiftPM migration

Shipping and Tuist consume PVPPSSPP-Dynamic, preserving the PVPPSSPP Swift module,
PVPPSSPP.PVPPSSPPCore principal class and all four shipping consumers, including
Lite. TUIST_DEV_PPSSPP enables the focused native app; make dev-ppsspp builds it on
an iOS device. Thin retains its separate libretro implementation.

SwiftPM compiles 799 native implementation sources, twelve ObjC++/platform bridge
sources and eight Swift sources. Explicit source membership and per-library
settings replace the wrapper and generated native Xcode projects. Tracked native
configuration headers remain source inputs; no CMake cache or generated Xcode
project participates in the build. The original FFmpeg device archives are repacked
with real arm64 simulator builds from the matching legacy source in a four-slice
PPSSPPFFmpeg.xcframework. No Mach-O platform tags are rewritten.
Private quote-header search priority keeps the app's newer shared FFmpeg framework
headers from replacing the legacy API that these archives implement.

Local translation units preserve upstream source. The x86 thunk matches ABI.cpp's
architecture guard, avoiding an unused x86 object that the old archive left
unloaded on ARM. Both PPSSPP incremental-MD5 call sites use a private symbol because
RetroAchievements exports a different function with an incompatible context layout
under the same original name. Shader compiler definitions remain private too.
Explicit implementation module maps avoid overlapping generated umbrellas.

Core.plist belongs to the Swift resource bundle. The bridge owns cmake/assets and
looks up SWIFTPM_MODULE_BUNDLE; flash0 points at its real asset directory. Swift
render controllers are resolved by their qualified runtime names, avoiding a
reverse dependency from the bridge. The renderer's existing shared MoltenVK lookup
and dylib fallback remain unchanged.

A fresh shipping resolution exposed stale exact Defaults 9.0.2 references requiring
SwiftSyntax 600, conflicting with HexColors' SwiftSyntax 603 requirement. Both
references and only the Defaults lockfile pin now select 9.0.9, matching the
validated standalone/Tuist graph. Existing unrelated OpenAPI/zstd lockfile edits
remain outside the migration commits.

Validation on 2026-10-20/21:

- The native PVPPSSPP-Dynamic package built successfully for generic iOS arm64
  with Xcode 27.1. Every declared source exists; source entries are unique and
  Swift/Clang targets remain separate.
- The framework contains the principal class, ObjC bridge and both render classes.
  Core.plist and all 158 shipped asset files match their sources, excluding the
  VCS/Finder metadata that Xcode intentionally omits. Native shader definitions
  and the private MD5 helper are hidden from exports. The standalone library uses
  system runtimes; shipping also uses Xcode's embedded package-product frameworks.
  Every shipping rpath resolves inside the app, with no shared newer FFmpeg dependency.
- Canonical Tuist generation succeeded. The generated native PPSSPP app links and
  embeds PVPPSSPP-Dynamic. Shipping/dev graph audit, manifest checks and root
  project plist lint passed.
- All sixteen package/graph regression tests passed. These include simultaneous
  Clang imports and an executable digest test linking both MD5 implementations,
  verifying PPSSPP one-shot/incremental and cheevos against a known digest vector.
  A shared-framework fixture also verifies private legacy FFmpeg header selection.
- SwiftLint found no serious violations in changed Swift files; the new package
  manifest has no lint warnings.
- Shipping Provenance-Lite (AppStore) built successfully for generic iOS arm64
  with Xcode 27.1 after the final header-isolation fix. The app embeds the exact
  PPSSPP framework and both resource bundles produced by the package.

Simulator follow-up validation on 2026-10-21:

- Shipping Provenance-Lite (AppStore) built successfully for both generic iOS
  Simulator and generic tvOS Simulator, arm64, using Xcode 27.1. Both commands
  completed with exit 0 and BUILD SUCCEEDED.
- PPSSPP's drawable proxy now guards the Metal timing/feedback APIs omitted from
  simulator SDKs. CoreAudioKit and CoreMotion are restricted to the platforms
  that provide them; SDK link checks cover PPSSPP, emuThree, Dolphin and Azahar.
- Lite's iOS dependency graph also exposed emuThree's device-only vendor archives
  and empty OpenAL simulator archives. A separately scoped vendor rebuild supplies
  real platform slices, including OpenAL Soft's required callback-buffer API.
  Source pins and public-header checks preserve the legacy interfaces. A local
  time-stretch translation unit selects signed 16-bit PCM, matching the engine's
  buffers and the original SoundTouch archive, without modifying upstream source.
- All 23 regression tests passed. These include actual legacy FFmpeg simulator
  links, every simulator object's Mach-O platform, Metal proxy typechecking on
  four SDKs, framework links for four packages on four SDKs, vendor symbols and
  OpenAL callback API links using the package's declared dependencies.
- Both Lite apps contain the exact PPSSPP package framework, correct simulator
  platform metadata, principal-class symbols, source-equivalent Core.plist and
  all 158 byte-identical PSP runtime assets. Selected FFmpeg archives match their
  tracked simulator slices. The iOS app's emuThree framework, Core.plist and vendor
  input were checked too. Existing shipping/Tuist emuThree filters remain iOS-only;
  its tvOS vendor slices do not change the app's core availability.
- Shipping/dev graph audit passes for all 22 package rows. Changed manifests pass
  SwiftLint with no serious violations; existing style warnings remain.

The simulator build commands used:

```sh
xcodebuild build -workspace Provenance.xcworkspace \
  -scheme 'Provenance-Lite (AppStore)' \
  -destination 'generic/platform=iOS Simulator' -jobs 4 \
  ARCHS=arm64 EXCLUDED_ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO \
  -skipPackagePluginValidation -skipMacroValidation \
  -skipPackageUpdates -disableAutomaticPackageResolution
```

The tvOS command uses `-destination 'generic/platform=tvOS Simulator'` with the same
settings. These validate compilation and linking; signed launch and gameplay were
not exercised. Unrelated UI/library changes, root lockfile edits and submodule
revisions remain outside this work's commits.
