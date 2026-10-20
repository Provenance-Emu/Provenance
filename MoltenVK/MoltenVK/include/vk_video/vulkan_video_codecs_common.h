#ifndef VULKAN_VIDEO_CODECS_COMMON_H_
#define VULKAN_VIDEO_CODECS_COMMON_H_ 1

/*
** Copyright 2015-2024 The Khronos Group Inc.
**
** SPDX-License-Identifier: Apache-2.0
*/

/*
** This header is generated from the Khronos Vulkan XML API Registry.
**
*/





// vulkan_video_codecs_common is a preprocessor guard. Do not pass it to API calls.
#define vulkan_video_codecs_common 1
#if !defined(VK_NO_STDINT_H)
    // Codec headers can include this file inside extern "C"; Clang's standard
    // library modules must be imported with C++ linkage even in that context.
    #ifdef __cplusplus
    extern "C++" {
    #endif
    #include <stdint.h>
    #ifdef __cplusplus
    }
    #endif
#endif

#define VK_MAKE_VIDEO_STD_VERSION(major, minor, patch) \
    ((((uint32_t)(major)) << 22) | (((uint32_t)(minor)) << 12) | ((uint32_t)(patch)))



#endif
