# PPSSPP FFmpeg archives

`PPSSPPFFmpeg.xcframework` contains the legacy libavcodec 57 ABI used by the
native PPSSPP core. Each slice combines avcodec, avdevice, avformat, avutil,
swresample and swscale into one static archive. Headers remain in
`../../cmake/ffmpeg/ios/universal/include` and are not exported as a module.

The iOS and tvOS device slices are repacked from the existing tracked archives.
The arm64 simulator slices are compiled from `../../libretro_ppsspp/ffmpeg`
(commit `98973e62e0653fcac12f277838ff3d76e786722b`) with its `shared_options.sh`
feature set, Xcode 27.1 and a minimum deployment target of 17.0.
Simulator headers match the checked-in headers byte for byte.

Reproduction: run `Scripts/cores/build_ppsspp_ffmpeg.sh` from the repository.
It compiles outside the source tree and packages real platform slices; no Mach-O
platform rewriting is used. The matching upstream source and LGPL license are
in the FFmpeg submodule. See the core README for validation commands.
