# MoltenVK

Version: 1.4.2 (official KhronosGroup release, MoltenVK-all.tar)
Source: https://github.com/KhronosGroup/MoltenVK/releases/tag/v1.4.2

`dynamic/MoltenVK.xcframework`, `static/MoltenVK.xcframework` and `include/` come
from the release unmodified, except:

- visionOS (`xros-*`) slices are dropped; no Provenance app ships for visionOS.
- `include/vulkan/vk_platform.h` and `include/vk_video/vulkan_video_codecs_common.h`
  have no `extern "C"` block, and the codecs header imports `<stdint.h>` with C++
  linkage. Clang modules reject standard-library module imports nested in
  `extern "C"`. Reapply both edits when updating the headers.

The 1.2.11rc1 build this replaced came from the Provenance-Emu fork with
`-mcpu=apple-a10` and SPIRV-Cross `use_framebuffer_fetch_subpasses` (a Play!
patch). Play! has since been removed; stock 1.4.2 reads input attachments as
textures.

Not covered by this copy: Dolphin, PPSSPP and emuThree ship their own MoltenVK
dylibs (`Cores/*/lib/libMoltenVK_*.dylib`), and `MoltenVK-1.2.8/` is a separate
older build kept for Dolphin's loader fallback.
