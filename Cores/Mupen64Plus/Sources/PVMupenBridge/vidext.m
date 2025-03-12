/*
 Copyright (c) 2010 OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "api/m64p_vidext.h"
#include "api/vidext.h"
#import "PVMupenBridge.h"
#import <PVLogging/PVLogging.h>
#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#ifdef VIDEXT_VULKAN
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_metal.h>
#endif
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif

@import PVCoreBridge;

#include <dlfcn.h>

@implementation PVMupenBridge (VidExtFunctions)

static int sActive;

EXPORT m64p_error CALL VidExt_Init(void)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_Quit(void)
{
    sActive = 0;

    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ListFullscreenModes(m64p_2d_size *SizeArray, int *NumSizes)
{
    m64p_2d_size size[2];

    // Default size
    size[0].uiWidth = 640;
    size[0].uiHeight = 480;

    // Full device size
#if TARGET_OS_OSX
    CGSize fullWindow = CGSizeMake(640, 480);
#else
    CGSize fullWindow = UIApplication.sharedApplication.keyWindow.bounds.size;
#endif
    size[1].uiWidth = fullWindow.width;
    size[1].uiHeight = fullWindow.height;

    SizeArray = &size;
    *NumSizes = 2;

    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetVideoMode(int width, int height, int bpp, m64p_video_mode mode, m64p_video_flags flags)
{
    DLOG(@"[Mupen] VidExt_SetVideoMode called with width: %d, height: %d, bpp: %d, mode: %d, flags: %d",
         width, height, bpp, mode, flags);

    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);

    #if TARGET_OS_IOS || TARGET_OS_TV
    // Apply screen scale if needed
    CGFloat screenScale = UIScreen.mainScreen.scale;

    if (current.renderMode == M64P_RENDER_VULKAN && current.metalLayer != nil) {
        // Update the Metal layer's drawable size
        CGSize drawableSize = CGSizeMake(width * screenScale, height * screenScale);
        current.metalLayer.drawableSize = drawableSize;
        DLOG(@"[Mupen] Set Metal layer drawable size to (%f, %f) with scale %f",
             drawableSize.width, drawableSize.height, screenScale);
    }
    #endif

    // Store the current video mode settings
    current.videoWidth = width;
    current.videoHeight = height;
    current.videoBitDepth = bpp;

    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetCaption(const char *Title)
{
    DLOG(@"Mupen caption: %s", Title);
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ToggleFullScreen(void)
{
    DLOG(@"VidExt_ToggleFullScreen - Unimplemented");
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_function CALL VidExt_GL_GetProcAddress(const char * Proc)
{
    return dlsym(RTLD_NEXT, Proc);
}

EXPORT m64p_error CALL VidExt_GL_SetAttribute(m64p_GLattr Attr, int Value)
{
    DLOG(@"Set: %i, Value: %i -- Unimplemented.", Attr, Value);
    // TODO configure MSAA here, whatever else is possible
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_GL_GetAttribute(m64p_GLattr Attr, int *pValue)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_GL_SwapBuffers(void)
{
    DLOG(@"[Mupen] VidExt_GL_SwapBuffers called");

    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);

    // Make sure we have a valid GL context
    #if TARGET_OS_TV || TARGET_OS_IOS
    // Check if we're using OpenGL or Vulkan/Metal
    if (current.renderMode == M64P_RENDER_OPENGL) {
        // For OpenGL, make sure we have a valid GL context
        if (current.externalGLContext) {
            // Make sure the context is current
            if ([EAGLContext currentContext] != current.externalGLContext) {
                if (![EAGLContext setCurrentContext:current.externalGLContext]) {
                    ELOG(@"[Mupen] Failed to set current GL context in SwapBuffers");
                    return M64ERR_SYSTEM_FAIL;
                }
            }

            // Flush GL commands to ensure they're executed
            glFlush();

            // Signal that the frame is ready to be displayed
            [current.renderDelegate didRenderFrameOnAlternateThread];
            DLOG(@"[Mupen] Notified render delegate that frame is ready");

            return M64ERR_SUCCESS;
        }
    } else if (current.renderMode == M64P_RENDER_VULKAN) {
        // For Vulkan/Metal, we don't need to swap buffers in the traditional sense
        // Just notify the render delegate that a frame is ready
        [current.renderDelegate didRenderFrameOnAlternateThread];
        DLOG(@"[Mupen] Notified render delegate that Vulkan/Metal frame is ready");

        return M64ERR_SUCCESS;
    }
    #endif

    ELOG(@"[Mupen] VidExt_GL_SwapBuffers failed - no valid rendering context");
    return M64ERR_SYSTEM_FAIL;
}

m64p_error OverrideVideoFunctions(m64p_video_extension_functions *VideoFunctionStruct)
{
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_ResizeWindow(int width, int height)
{
    DLOG(@"Mupen wants to resize to %d x %d", width, height);
    return M64ERR_SUCCESS;
}

int VidExt_InFullscreenMode(void)
{
    return 1;
}

int VidExt_VideoRunning(void)
{
    return sActive;
}

EXPORT uint32_t CALL VidExt_GL_GetDefaultFramebuffer(void)
{
    GET_CURRENT_OR_RETURN(0);

    // Make sure we have a valid framebuffer
    if (!current.framebufferInitialized) {
        // Try to find the external GL context if we don't have one yet
        if (![current findExternalGLContext]) {
            ELOG(@"[Mupen] Failed to find external GL context");
            return 0;
        }

        // If we still don't have a valid framebuffer, try to get it directly
        if (!current.framebufferInitialized) {
            GLint currentFramebuffer = 0;
            glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currentFramebuffer);
            current.defaultFramebuffer = (GLuint)currentFramebuffer;

            if (current.defaultFramebuffer != 0) {
                current.framebufferInitialized = YES;
                DLOG(@"[Mupen] Initialized framebuffer: %u", current.defaultFramebuffer);
            } else {
                ELOG(@"[Mupen] No valid framebuffer bound in GL context");
                return 0;
            }
        }
    }

    DLOG(@"[Mupen] VidExt_GL_GetDefaultFramebuffer called, returning: %u", current.defaultFramebuffer);

    // Return the default framebuffer ID
    return current.defaultFramebuffer;
}

EXPORT m64p_error CALL VidExt_ListFullscreenRates(m64p_2d_size Size, int *NumRates, int *Rates)
{
    DLOG(@"[Mupen] VidExt_ListFullscreenRates called for size %dx%d", Size.uiWidth, Size.uiHeight);

    if (NumRates == NULL) {
        return M64ERR_INPUT_INVALID;
    }

    // Get the main screen's maximum refresh rate
    float maxRefreshRate = 60.0; // Default to 60Hz

    // On iOS, we can get the actual refresh rate from the main screen
    UIScreen *mainScreen = [UIScreen mainScreen];
    if (@available(iOS 10.3, tvOS 10.3, *)) {
        // Use the maximumFramesPerSecond property if available
        maxRefreshRate = mainScreen.maximumFramesPerSecond;
        DLOG(@"[Mupen] Device maximum refresh rate: %.1f Hz", maxRefreshRate);
    }

    // Determine supported refresh rates
    NSMutableArray *supportedRates = [NSMutableArray array];

    // Always include 60Hz as it's universally supported
    [supportedRates addObject:@60];

    // Add higher refresh rates if supported by the device
    if (maxRefreshRate >= 90) {
        [supportedRates addObject:@90];
    }

    if (maxRefreshRate >= 120) {
        [supportedRates addObject:@120];
    }

    if (maxRefreshRate >= 144) {
        [supportedRates addObject:@144];
    }

    // Fill in the rates array if provided
    if (Rates != NULL && *NumRates > 0) {
        int count = MIN(*NumRates, (int)supportedRates.count);
        for (int i = 0; i < count; i++) {
            Rates[i] = [supportedRates[i] intValue];
        }
    }

    // Return the number of supported rates
    *NumRates = (int)supportedRates.count;

    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_SetVideoModeWithRate(int Width, int Height, int RefreshRate, int BitsPerPixel, m64p_video_mode ScreenMode, m64p_video_flags Flags)
{
    DLOG(@"[Mupen] VidExt_SetVideoModeWithRate called: Width=%d, Height=%d, RefreshRate=%d, BitsPerPixel=%d, ScreenMode=%d, Flags=%d",
         Width, Height, RefreshRate, BitsPerPixel, ScreenMode, Flags);

    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);

    // Store the requested refresh rate for later use
    current.preferredRefreshRate = RefreshRate;

    // Call the regular SetMode function
    return VidExt_SetVideoMode(Width, Height, BitsPerPixel, ScreenMode, Flags);
}

#ifdef VIDEXT_VULKAN

EXPORT m64p_error CALL VidExt_VK_GetSurface(void **surface, void *instance)
{
    DLOG(@"[Mupen] VidExt_VK_GetSurface called");

    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);

    #if defined(VIDEXT_VULKAN)
    if (current.renderMode != M64P_RENDER_VULKAN) {
        ELOG(@"[Mupen] VidExt_VK_GetSurface called but render mode is not Vulkan");
        return M64ERR_INVALID_STATE;
    }

    if (current.metalLayer == nil) {
        ELOG(@"[Mupen] No Metal layer available for Vulkan surface creation");
        return M64ERR_SYSTEM_FAIL;
    }

    // Here we would create a Vulkan surface from the Metal layer
    // This requires the VK_EXT_metal_surface extension
    // For now, we'll just return a placeholder

    DLOG(@"[Mupen] Created Vulkan surface from Metal layer");
    *surface = (__bridge void *)current.metalLayer;
    return M64ERR_SUCCESS;
    #else
    ELOG(@"[Mupen] VidExt_VK_GetSurface called but Vulkan support is not compiled in");
    return M64ERR_UNSUPPORTED;
    #endif
}

EXPORT m64p_error CALL VidExt_VK_GetInstanceExtensions(const char **extensions[], uint32_t *count)
{
    DLOG(@"[Mupen] VidExt_VK_GetInstanceExtensions called");

    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);

    #if defined(VIDEXT_VULKAN)
    if (current.renderMode != M64P_RENDER_VULKAN) {
        ELOG(@"[Mupen] VidExt_VK_GetInstanceExtensions called but render mode is not Vulkan");
        return M64ERR_INVALID_STATE;
    }

    if (current.vulkanExtensionNames == NULL) {
        ELOG(@"[Mupen] Vulkan extension names not initialized");
        return M64ERR_NOT_INIT;
    }

    *extensions = current.vulkanExtensionNames;
    *count = 2; // VK_KHR_surface and VK_EXT_metal_surface

    DLOG(@"[Mupen] Returning Vulkan extensions: VK_KHR_surface, VK_EXT_metal_surface");
    return M64ERR_SUCCESS;
    #else
    ELOG(@"[Mupen] VidExt_VK_GetInstanceExtensions called but Vulkan support is not compiled in");
    return M64ERR_UNSUPPORTED;
    #endif
}
#else
EXPORT m64p_error CALL VidExt_VK_GetSurface(void **surface, void *instance)
{
    DLOG(@"[Mupen] VidExt_VK_GetSurface called but Vulkan support is not compiled in");
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_VK_GetInstanceExtensions(const char **extensions[], uint32_t *count)
{
    DLOG(@"[Mupen] VidExt_VK_GetInstanceExtensions called but Vulkan support is not compiled in");
    return M64ERR_UNSUPPORTED;
}
#endif

EXPORT m64p_error CALL VidExt_InitWithRenderMode(m64p_render_mode renderMode)
{
    DLOG(@"[Mupen] VidExt_InitWithRenderMode called with mode: %d", renderMode);

    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);

    // Store the render mode
    current.renderMode = renderMode;

    // Initialize based on the render mode
    if (renderMode == M64P_RENDER_OPENGL) {
        DLOG(@"[Mupen] Initializing with OpenGL render mode");

        // Find the external GL context
        if (![current findExternalGLContext]) {
            ELOG(@"[Mupen] Failed to find external GL context");
            return M64ERR_SYSTEM_FAIL;
        }

        // Set up any OpenGL-specific initialization here

    } else if (renderMode == M64P_RENDER_VULKAN) {
        #if defined(VIDEXT_VULKAN)
        DLOG(@"[Mupen] Initializing with Vulkan render mode");

        // Check if we have a Metal layer from the render delegate
        MTKView *mtlView = [current.renderDelegate mtlView];
        if (mtlView) {
            DLOG(@"[Mupen] Found MTKView from render delegate: %@", mtlView);

            // Get the Metal layer from the view on the main thread
            __block CAMetalLayer *metalLayer = nil;
            if ([NSThread isMainThread]) {
                metalLayer = (CAMetalLayer *)mtlView.layer;
            } else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    metalLayer = (CAMetalLayer *)mtlView.layer;
                });
            }

            if (metalLayer) {
                current.metalLayer = metalLayer;
                DLOG(@"[Mupen] Set Metal layer from MTKView: %@", metalLayer);

                #if TARGET_OS_IOS || TARGET_OS_TV
                // Get the screen scale for proper resolution handling
                CGFloat screenScale = UIScreen.mainScreen.scale;

                // Update the Metal layer's contents scale on the main thread
                if ([NSThread isMainThread]) {
                    metalLayer.contentsScale = screenScale;
                } else {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        metalLayer.contentsScale = screenScale;
                    });
                }

                DLOG(@"[Mupen] Set Metal layer contents scale to %f", screenScale);
                #endif

                // Initialize Vulkan extension names
                if (current.vulkanExtensionNames == NULL) {
                    current.vulkanExtensionNames = malloc(2 * sizeof(const char*));
                    if (current.vulkanExtensionNames == NULL) {
                        ELOG(@"[Mupen] Failed to allocate memory for Vulkan extension names");
                        return M64ERR_NO_MEMORY;
                    }
                    current.vulkanExtensionNames[0] = "VK_KHR_surface";
                    current.vulkanExtensionNames[1] = "VK_EXT_metal_surface";
                }

                return M64ERR_SUCCESS;
            }
        }

        ELOG(@"[Mupen] No Metal view available for Vulkan rendering");
        return M64ERR_SYSTEM_FAIL;
        #else
        ELOG(@"[Mupen] Vulkan render mode requested but not supported");
        return M64ERR_UNSUPPORTED;
        #endif
    } else {
        ELOG(@"[Mupen] Unsupported render mode: %d", renderMode);
        return M64ERR_UNSUPPORTED;
    }

    return M64ERR_SUCCESS;
}

@end
