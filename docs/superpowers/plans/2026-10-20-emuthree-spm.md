# emuThree SwiftPM migration

The shipping project and Tuist consume the same `PVEmuThree-Dynamic` product. Keep
`PVEmuThree.PVEmuThreeCore` as the principal class and put Core.plist in Bundle.module.

The C++ engine, Objective-C++ bridge and Crypto++ compile as separate source targets.
Keep C++ header modules disabled for the engine (OpenSSL requires textual C++ headers),
and enabled for the bridge that imports Swift Objective-C interfaces. Crypto++ has scoped
flat header paths, so its zlib.h cannot shadow Apple SDK headers elsewhere. The Swift core
and render controllers depend on it; the bridge resolves the render controllers via the
Objective-C runtime to avoid a generated Swift header dependency cycle. Preserve the
original engine source membership and synchronized-folder exclusions, except five
duplicate implementations. Select the local Dynarmic, savestate and Mii selector replacements,
and retain upstream audio interpolation (entry 20 preceded the redundant local copy at entry 133
in the original archive). SwiftPM links every target object, so the duplicates cannot remain.

Retain the existing third-party archives and shared FFmpeg/OpenAL/SDL/MoltenVK binaries;
upstream sources are read without edits. Isolate C++ symbols at final link rather than
at intermediate object combination.

Validation: compare source membership with the previous project, run core resource/module
checks and shipping/Tuist audit, generate Tuist, then build Lite arm64 iOS and inspect its
embedded framework and Core.plist. Keep UI work out of the migration commit.

Engine C++ pre-includes its actual network/network.h because the SDK framework search
shadows the lowercase path on a case-insensitive volume. Local bridge code includes the
narrow network.h path, while Apple Network/Network.h keeps SDK precedence. Upstream
sources remain unchanged.

Validated on 2026-10-20:

- `Provenance-Lite (AppStore)` built successfully for generic iOS, arm64, with
  Xcode 27.1 and code signing disabled. All 382 engine and 202 Crypto++ sources
  compiled; the 17-file bridge and Swift wrapper compiled and linked successfully.
- The embedded `PVEmuThree-Dynamic.framework` contains the principal class, bridge
  and both render controllers, exports no C++ symbols, and is loaded by the app's
  debug dylib. Its resource bundle contains a byte-identical Core.plist.
- Package layout/resource tests, the shipping/dev audit (21 package rows), Tuist
  manifest checks (7 apps, 17 core rows), project plist lint and SwiftLint passed.
  Focused Tuist generation and package resolution also passed during migration.
- Updated the existing plist loader to initialize `ReadOptions` with `[]`; the
  current Swift SDK rejects its previous integer initialization.

This validates an iOS device build. Simulator, tvOS and gameplay were not exercised.
Azahar and emuThree migrations and this compiler fix are committed separately from
the concurrent UI and library changes.
