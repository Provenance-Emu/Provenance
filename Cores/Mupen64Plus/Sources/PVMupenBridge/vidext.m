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

EXPORT m64p_error CALL VidExt_SetVideoMode(int Width, int Height, int BitsPerPixel, m64p_video_mode ScreenMode, m64p_video_flags Flags)
{
    NSString *windowMode;
    switch (ScreenMode) {
        case 1:
            windowMode = @"None";
            break;
        case 2:
            windowMode = @"Window";
            break;
        case 3:
            windowMode = @"Fullscreen";
            break;
        default:
            windowMode = @"Unknown";
            break;
    }
    DLOG(@"(%i,%i) %ibpp %@", Width, Height, BitsPerPixel, windowMode);
    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);
    
    current.videoWidth = Width;
    current.videoHeight = Height;
    current.videoBitDepth = BitsPerPixel;
    
    sActive = 1;
    
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
    GET_CURRENT_OR_RETURN(M64ERR_SUCCESS);
    
    [current swapBuffers];
    return M64ERR_SUCCESS;
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
    
    // Find the external GL context if we don't have one yet
    if (!current._externalGLContext) {
        if (![current findExternalGLContext]) {
            ELOG(@"[Mupen] Failed to find external GL context");
            return 0;
        }
    }
    
    // Make sure we have a valid framebuffer
    if (!current._framebufferInitialized) {
        GLint currentFramebuffer = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currentFramebuffer);
        current._defaultFramebuffer = (GLuint)currentFramebuffer;
        
        if (current._defaultFramebuffer == 0) {
            ELOG(@"[Mupen] No valid framebuffer bound in external GL context");
            return 0;
        }
        
        current._framebufferInitialized = YES;
    }
    
    DLOG(@"[Mupen] VidExt_GL_GetDefaultFramebuffer called, returning: %u", current->_defaultFramebuffer);
    
    // Return the default framebuffer ID
    return current._defaultFramebuffer;
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
    current._preferredRefreshRate = RefreshRate;
    
    // Call the regular SetMode function
    return VidExt_SetVideoMode(Width, Height, BitsPerPixel, ScreenMode, Flags);
}

#ifdef VIDEXT_VULKAN

EXPORT m64p_error CALL VidExt_VK_GetSurface(void **surface, void *instance)
{
    DLOG(@"[Mupen] VidExt_VK_GetSurface called");
    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);
    
    if (!instance || !surface) {
        ELOG(@"[Mupen] Invalid parameters for VK_GetSurface");
        return M64ERR_INPUT_INVALID;
    }
    
    // Create a Metal surface for Vulkan
    VkMetalSurfaceCreateInfoEXT createInfo = {};
    createInfo.sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT;
    
    // Get the Metal layer from your view
    CAMetalLayer *metalLayer = (CAMetalLayer *)current->_metalLayer;
    if (!metalLayer) {
        ELOG(@"[Mupen] No Metal layer available");
        return M64ERR_SYSTEM_FAIL;
    }
    
    createInfo.pLayer = metalLayer;
    
    // Create the Vulkan surface using MoltenVK
    VkSurfaceKHR vulkanSurface = VK_NULL_HANDLE;
    VkResult result = vkCreateMetalSurfaceEXT((VkInstance)instance, &createInfo, NULL, &vulkanSurface);
    
    if (result != VK_SUCCESS) {
        ELOG(@"[Mupen] Failed to create Vulkan surface: %d", result);
        return M64ERR_SYSTEM_FAIL;
    }
    
    *surface = (void*)vulkanSurface;
    DLOG(@"[Mupen] Vulkan surface created successfully");
    return M64ERR_SUCCESS;
}

EXPORT m64p_error CALL VidExt_VK_GetInstanceExtensions(const char **extensions[], uint32_t *count)
{
    DLOG(@"[Mupen] VidExt_VK_GetInstanceExtensions called");
    GET_CURRENT_OR_RETURN(M64ERR_INVALID_STATE);
    
    if (!extensions || !count) {
        ELOG(@"[Mupen] Invalid parameters for VK_GetInstanceExtensions");
        return M64ERR_INPUT_INVALID;
    }
    
    // MoltenVK requires these extensions
    static const char *requiredExtensions[] = {
        "VK_KHR_surface",
        "VK_EXT_metal_surface"
    };
    
    // Free any previously allocated extension names
    if (current._vulkanExtensionNames) {
        free(current._vulkanExtensionNames);
        current._vulkanExtensionNames = NULL;
    }
    
    // Allocate memory for the extension names
    current._vulkanExtensionNames = malloc(sizeof(const char*) * 2);
    if (!current._vulkanExtensionNames) {
        ELOG(@"[Mupen] Failed to allocate memory for Vulkan extension names");
        return M64ERR_SYSTEM_FAIL;
    }
    
    // Copy the extension names
    memcpy(current._vulkanExtensionNames, requiredExtensions, sizeof(requiredExtensions));
    
    *extensions = current._vulkanExtensionNames;
    *count = 2;
    
    DLOG(@"[Mupen] Returning Vulkan extensions: VK_KHR_surface, VK_EXT_metal_surface");
    return M64ERR_SUCCESS;
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

@end
