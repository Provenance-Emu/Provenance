# Native PPSSPP core

Shipping and Tuist consume the `PVPPSSPP-Dynamic` SwiftPM product. The Swift module
remains `PVPPSSPP`, matching the `PVPPSSPP.PVPPSSPPCore` principal class in Core.plist.
The Thin app's libretro PPSSPP core is a separate implementation.

SwiftPM builds the native engine and its source dependencies, the local glslang
replacements, the Objective-C++ bridge and the Swift wrapper. `Package.swift`
records explicit source membership and per-library definitions. The tracked
configuration headers under `cmake/` are source inputs; no generated Xcode project
or CMake cache is consulted during the build. Keep source membership and these
configuration inputs aligned when updating the upstream submodule. Local translation
units under `SwiftPM/Native` guard the x86 thunk on ARM and isolate PPSSPP's
incremental MD5 function from RetroAchievements' different context layout.

Core.plist belongs to the Swift resource bundle. `cmake/assets` belongs to the
bridge resource bundle and preserves its font, flash0 and shader directories.
The renderer continues to use the app's shared MoltenVK framework, with its
existing dylib fallback.

Build the shipping workspace normally, or run `make dev-ppsspp` for the focused
iOS device app. To include that target during Tuist generation, set
`TUIST_DEV_PPSSPP=1`. FFmpeg is provided by the checked-in
`SwiftPM/FFmpeg/PPSSPPFFmpeg.xcframework`, with distinct arm64 iOS, tvOS,
iOS Simulator and tvOS Simulator slices. Intel simulators are unsupported.
Private header search priority keeps the app's newer FFmpeg frameworks from
changing PPSSPP's legacy codec API/ABI.

Rebuild the simulator slices and repack the device archives with
`Scripts/cores/build_ppsspp_ffmpeg.sh` (Xcode required, `JOBS=4` by default).
It uses the FFmpeg submodule's matching libavcodec 57 source and feature options,
builds out of tree under `build/ppsspp-ffmpeg`, and leaves upstream source untouched.
The original device archives under `cmake/ffmpeg` remain packaging inputs.
No device archive is relabeled as a simulator library. `PV_PPSSPP_FFMPEG_BUILD`
can select another build directory. The sources and LGPL license are available
under `libretro_ppsspp/ffmpeg`; no codecs with additional licensing options are enabled.

Validate the slice metadata and legacy API linkage with
`python3 -m unittest Scripts.cores.tests.test_ppsspp_ffmpeg`.
