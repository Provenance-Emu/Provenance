//
//  PVLibRetroGLESCore.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PVCoreBridgeRetro/libretro.h>
#import <PVCoreBridgeRetro/PVLibRetroCore.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

//#pragma clang diagnostic push
//#pragma clang diagnostic error "-Wall"

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

// Vulkan support via MoltenVK
#ifdef __cplusplus
extern "C" {
#endif

// Forward declare Vulkan types to avoid requiring vulkan.h
typedef struct VkInstance_T* VkInstance;
typedef struct VkDevice_T* VkDevice;
typedef struct VkQueue_T* VkQueue;
typedef struct VkPhysicalDevice_T* VkPhysicalDevice;
typedef uint32_t VkResult;
typedef void* PFN_vkVoidFunction;

#ifdef __cplusplus
}
#endif

__attribute__((weak_import))
@interface PVLibRetroGLESCoreBridge : PVLibRetroCoreBridge

// Hardware rendering support
- (BOOL)setHardwareRenderCallback:(NSValue *)callbackValue;
- (void)setupHardwareContext:(enum retro_hw_context_type)contextType;
- (void)destroyHardwareContext;

// Hardware rendering callbacks
- (void)contextReset;
- (void)contextDestroy;
- (uintptr_t)getCurrentFramebuffer;
- (void*)getProcAddress:(const char*)symbol;

// Touch and mouse input support
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
- (void)handleTouchEvent:(UIEvent *)event;
#else
- (void)handleMouseEvent:(NSEvent *)event;
#endif
- (int16_t)getPointerState:(unsigned)port device:(unsigned)device index:(unsigned)index id:(unsigned)id;

@end

#pragma clang diagnostic pop
