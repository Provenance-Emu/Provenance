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
