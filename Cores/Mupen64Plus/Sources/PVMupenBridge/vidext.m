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

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif

#include <dlfcn.h>

#if __has_include(<OpenGLES/ES3/gl.h>)
#import <OpenGLES/ES3/gl.h>
#endif

@implementation PVMupenBridge (VidExtFunctions)

static int sActive;

EXPORT m64p_error CALL VidExt_Init(void)
{
    return M64ERR_SUCCESS;
}

/// Only the GL path exists here (EAGL context owned by the bridge); Vulkan is not provided.
EXPORT m64p_error CALL VidExt_InitWithRenderMode(m64p_render_mode RenderMode)
{
    return (RenderMode == M64P_RENDER_OPENGL) ? VidExt_Init() : M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_ListFullscreenRates(m64p_2d_size Size, int *NumRates, int *Rates)
{
    return M64ERR_UNSUPPORTED;
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

/// The refresh rate is driven by the frontend's display link, so it is ignored.
EXPORT m64p_error CALL VidExt_SetVideoModeWithRate(int Width, int Height, int RefreshRate, int BitsPerPixel, m64p_video_mode ScreenMode, m64p_video_flags Flags)
{
    return VidExt_SetVideoMode(Width, Height, BitsPerPixel, ScreenMode, Flags);
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

EXPORT m64p_function CALL VidExt_GL_GetProcAddress(const char* Proc)
{
    return (m64p_function)dlsym(RTLD_NEXT, Proc);
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

/// There is no window-system framebuffer 0 on iOS/tvOS: the bridge renders into its own
/// FBO, which is the one bound on the GL thread when a plugin asks for this.
EXPORT uint32_t CALL VidExt_GL_GetDefaultFramebuffer(void)
{
#if __has_include(<OpenGLES/ES3/gl.h>)
    GLint framebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
    return (uint32_t)framebuffer;
#else
    return 0;
#endif
}

EXPORT m64p_error CALL VidExt_VK_GetSurface(void** Surface, void* Instance)
{
    return M64ERR_UNSUPPORTED;
}

EXPORT m64p_error CALL VidExt_VK_GetInstanceExtensions(const char** Extensions[], uint32_t* NumExtensions)
{
    return M64ERR_UNSUPPORTED;
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

@end

