# PPSSPP SwiftPM migration

Shipping and Tuist consume PVPPSSPP-Dynamic, preserving the PVPPSSPP Swift module,
principal class and all four shipping consumers, including Lite. The focused native
app opts in through TUIST_DEV_PPSSPP; Thin retains its separate libretro core.

SwiftPM compiles the native engine, third-party source targets, local glslang
replacements, ObjC++ bridge and Swift wrapper. Source membership follows the former
wrapper and generated native project, with duplicate archive entries removed.
The package carries Core.plist and the existing assets; the bridge looks up its
resource bundle and resolves Swift render controllers by their qualified names.
The existing platform-specific FFmpeg device archives remain external dependencies.
Simulator linking requires matching simulator archives; device archives must not
be relabeled as simulator binaries.

Validate the package language split/source membership, principal class and resources,
shipping/Tuist graph agreement, Tuist generation, native package compilation and the
shipping Lite arm64 iOS build. Keep unrelated UI/library changes and submodule
revisions outside the migration commits.

Validation so far:

- All 819 source entries exist and are unique: 799 native sources, 12 bridge/glue
  sources and eight Swift sources. Four duplicated native archive entries compile
  once; the upstream iOS audio file is replaced by the existing local implementation.
- All arm64 objects in the six iOS and six tvOS FFmpeg archives declare the intended
  device platform (LC_VERSION_MIN_IPHONEOS / LC_VERSION_MIN_TVOS).
- The existing shared MoltenVK framework lookup and dylib fallback remain in the
  renderer. No legacy MoltenVK copy target is required by the source package.
- Package layout/resource/module tests and shipping/dev graph audit passed.
- Tuist opt-in manifest evaluation includes Provenance-Dev-PPSSPP.
