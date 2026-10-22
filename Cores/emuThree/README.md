# Native emuThree core

Shipping and Tuist consume `PVEmuThree-Dynamic`. SwiftPM compiles the legacy engine,
Crypto++, Objective-C++ bridge and Swift wrapper. Core.plist remains in its Swift
resource bundle; the principal class remains `PVEmuThree.PVEmuThreeCore`.

The checked-in `SwiftPM/Vendors/PVEmuThreeVendors.xcframework` supplies distinct
arm64 iOS, tvOS, iOS Simulator and tvOS Simulator slices for the engine's eighteen
vendor libraries plus OpenAL Soft. The existing iOS device archives remain packaging inputs;
the other slices are compiled from pinned historical sources. Device binaries
are never relabeled as simulator binaries. Intel simulators are unsupported.
Shared FFmpeg, SDL2, OpenSSL and MoltenVK retain their package dependencies.
OpenAL Soft is built for each platform, preserving the required callback-buffer extension;
the former empty simulator archives are not used. OpenAL headers stay private in
`SwiftPM/Vendors/Headers` so processing the combined archive cannot overwrite the
app’s separate OpenAL package headers.

Rebuild with `python3 Scripts/cores/build_emuthree_vendors.py` (Xcode, CMake,
Ninja and network access required). It exports pinned sources into
`build/emuthree-vendors`, verifies their public headers against the engine, and
builds outside upstream checkouts. `--source-cache /path/to/citra/externals` can
reuse existing Git objects at the pinned revisions; dirty source files are not
copied. `--jobs 4` controls native compilation concurrency.

`SwiftPM/Vendors/BuildInfo.json` records source pins, source archive checksums,
toolchain version and binary hashes. Dependency license texts accompany the bundle.
The existing mobile Oaknut memory-protection adapter is reused for Dynarmic.

The local `SwiftPM/Native/TimeStretch.cpp` translation unit selects SoundTouch's
signed 16-bit PCM interface, matching the engine's input buffers and the original
vendor archive. This avoids relying on the vendored header's floating-point default.
Upstream source is unchanged.

Validate platform metadata and vendor interfaces with
`python3 -m unittest Scripts.cores.tests.test_emuthree_vendors`.
