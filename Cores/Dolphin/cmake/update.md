# Update.md

_How to update the generated xcode project after running update.sh_

1. Remove `VulkanLoader.cpp` from `videovulkan` target source files
2. Remove `Mixer.cpp` from `audioCommon` target source files
3. Rename libraries with `Dolphin` Postfix eg; `lzma` => 'lzmaDolphin`
