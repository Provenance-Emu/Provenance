# PPSSPP SwiftPM migration

Shipping and Tuist consume PVPPSSPP-Dynamic, preserving the PVPPSSPP Swift module,
PVPPSSPP.PVPPSSPPCore principal class and all four shipping consumers, including
Lite. TUIST_DEV_PPSSPP enables the focused native app; make dev-ppsspp builds it on
an iOS device. Thin retains its separate libretro implementation.

SwiftPM compiles 799 native implementation sources, twelve ObjC++/platform bridge
sources and eight Swift sources. Explicit source membership and per-library
settings replace the wrapper and generated native Xcode projects. Tracked native
configuration headers remain source inputs; no CMake cache or generated Xcode
project participates in the build. Existing FFmpeg archives remain device-specific
inputs, with all arm64 objects verified against their iOS/tvOS platform metadata.
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

Simulator and tvOS compilation, signed app launch and gameplay remain unverified.
The FFmpeg device archives do not provide simulator support. Unrelated UI/library
changes and submodule revisions remain outside this migration's commits.
