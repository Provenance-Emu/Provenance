# Dolphin SwiftPM migration

Shipping and Tuist consume PVDolphin-Dynamic. Preserve existing shipping target
membership: Dolphin is present in Provenance, Provenance (AppStore) and XL;
Lite continues to validate the shared package graph.

The package owns the 12-file native bridge, eight Swift sources, Core.plist and
Config/Sys resources. Resources/Sys links to the existing submodule data without
copying or editing upstream source. Remove the handmade project and its configs.
The CMake native engine remains a prepared XCFramework binary target, produced by
build_slice.py before package resolution. Make, CI and release entry points prepare
both Azahar and Dolphin; Tuist's focused Dolphin target uses the same package.

Validate native preparation, source membership, package resources/language layout,
shipping/Tuist graph agreement, focused Tuist generation, Dolphin compilation and
the Lite arm64 iOS build. Inspect the embedded native framework and resource bundle.
Keep unrelated UI/library changes and the pre-existing Dolphin gitlink change out
of migration commits.

Validation on 2026-10-20:

- Native iOS preparation succeeded and cached the rebuilt engine before XCFramework
  packaging. The existing device and simulator slices remain in the XCFramework.
- The PVDolphin-Dynamic scheme built successfully for generic iOS arm64 with Xcode
  27.1 from the package workspace. All 12 bridge and eight Swift sources compiled.
  Linker arguments now use -Xlinker so Swift's linker driver accepts them.
- The framework exports the principal class, bridge and both render controllers.
  Its load commands reference PVlibDolphin-ios, whose copied binary UUID matches
  the prepared native artifact.
- Core.plist matches the source. All nine Config and 2,656 Sys files match their
  sources (Finder metadata excluded). Sys is copied as a real bundle directory.
- Shipping/dev graph audit, package layout/resource tests, source-membership audit,
  project plist lint, SwiftLint and release-script syntax checks passed.
- The shipping Provenance-Lite (AppStore) scheme built successfully for generic
  iOS arm64 with Xcode 27.1 after the final package changes. Lite retains its
  existing core membership and validates the shared shipping package graph.
- Canonical Tuist generation and opt-in manifest evaluation passed. The standalone
  package build validates the same product used by the focused Dolphin app.

The temporary focused iOS app requires a provisioning profile, so its app signing
and gameplay were not validated. Xcode 26 also crashed while loading that isolated
workspace; library compilation was completed with Xcode 27.1. Simulator and tvOS
compilation were not exercised. Keep the pre-existing submodule revision, upstream
UI edits and generated native build artifacts outside this migration's commits.
