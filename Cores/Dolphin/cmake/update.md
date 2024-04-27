# Update.md

_How to update the generated xcode project after running update.sh_

1. Remove `VulkanLoader.cpp` from `videovulkan` target source files
2. Remove `Mixer.cpp` from `audioCommon` target source files
3. Rename libraries with `Dolphin` Postfix eg; `lzma` => 'lzmaDolphin`
4. Change generated xcodeproj main settings to;
   1. Platforms (mac, tvos, ios, visionos plus sims)
   2. Arches => Apple Default
   3. Build active arch only on for `Configuration` => `Debug`
   4. Delete these settings from all the subtarget libs so they inherit from root
