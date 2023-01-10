//
//  PVPPSSPP+Video.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPPSSPPCore+Video.h"
#import "PVPPSSPPCore.h"
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>
#import "OGLGraphicsContext.h"
#import "VulkanGraphicsContext.h"

/* PSP Includes */
#import <dlfcn.h>
#import <pthread.h>
#import <signal.h>
#import <string>
#import <stdio.h>
#import <stdlib.h>
#import <sys/syscall.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach/machine.h>

#import <AudioToolbox/AudioToolbox.h>

#include "Common/MemoryUtil.h"
#include "Common/Profiler/Profiler.h"
#include "Common/CPUDetect.h"
#include "Common/Log.h"
#include "Common/LogManager.h"
#include "Common/TimeUtil.h"
#include "Common/File/FileUtil.h"
#include "Common/Serialize/Serializer.h"
#include "Common/ConsoleListener.h"
#include "Common/Input/InputState.h"
#include "Common/Input/KeyCodes.h"
#include "Common/Thread/ThreadUtil.h"
#include "Common/Thread/ThreadManager.h"
#include "Common/File/VFS/VFS.h"
#include "Common/File/VFS/AssetReader.h"
#include "Common/Data/Text/I18n.h"
#include "Common/StringUtils.h"
#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/System/System.h"
#include "Common/GraphicsContext.h"
#include "Common/Net/Resolve.h"
#include "Common/UI/Screen.h"
#include "Common/GPU/thin3d.h"
#include "Common/GPU/thin3d_create.h"
#include "Common/GPU/OpenGL/GLRenderManager.h"
#include "Common/GPU/OpenGL/GLFeatures.h"
#include "Common/System/NativeApp.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Log.h"
#include "Common/TimeUtil.h"
#include "Common/GraphicsContext.h"

#include "GPU/GPUState.h"
#include "GPU/GPUInterface.h"

#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/HLE/sceUtility.h"
#include "Core/HW/MemoryStick.h"
#include "Core/Host.h"
#include "Core/MemMap.h"
#include "Core/System.h"
#include "Core/CoreTiming.h"
#include "Core/HW/Display.h"
#include "Core/CwCheat.h"
#include "Core/ELF/ParamSFO.h"
#include "Core/SaveState.h"

#define IS_IPAD() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

#define RenderWidth 480
#define RenderHeight 272

static GraphicsContext *graphicsContext;
static float dp_xscale = 1.0f;
static float dp_yscale = 1.0f;
static UIView *m_view;
static bool threadEnabled = true;
static bool threadStopped = false;

@implementation PVPPSSPPCore (Video)

# pragma mark - Methods
- (void)videoInterrupt {
}

- (void)swapBuffers {
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
}

- (void)executeFrame {
	if (_isInitialized && threadEnabled) {
		graphicsContext->ThreadFrame();
	}
}

- (void)refreshScreenSize {
	 if (!_isInitialized || !m_view)
		return;
	 float scale = [UIScreen mainScreen].scale;
	 UIScreen *screen=[UIScreen mainScreen];
	 if ([screen respondsToSelector:@selector(nativeScale)]) {
		 scale = screen.nativeScale;
	 }
	 CGSize size = m_view.frame.size;
	 if (size.height > size.width) {
		 float h = size.height;
         if (IS_IPAD())
             size.height = int(size.width * size.width / size.height);
         else
             size.height = size.width * 272 / 480;
	 }
	 if (screen == [UIScreen mainScreen]) {
		 g_dpi = (IS_IPAD() ? 200.0f : 150.0f) * scale;
     } else {
		 float diagonal = sqrt(size.height * size.height + size.width * size.width);
		 g_dpi = diagonal * scale * 0.1f;
	 }
	 g_dpi_scale_x = 240.0f / g_dpi;
	 g_dpi_scale_y = 240.0f / g_dpi;
	 g_dpi_scale_real_x = g_dpi_scale_x;
	 g_dpi_scale_real_y = g_dpi_scale_y;
	 pixel_xres = size.width * scale;
	 pixel_yres = size.height * scale;
	 dp_xres = pixel_xres * g_dpi_scale_x;
	 dp_yres = pixel_yres * g_dpi_scale_y;
	 pixel_in_dps_x = (float)pixel_xres / (float)dp_xres;
	 pixel_in_dps_y = (float)pixel_yres / (float)dp_yres;
	 [m_view setContentScaleFactor:scale];
	 // PSP native resize
	 PSP_CoreParameter().pixelWidth = pixel_xres;
	 PSP_CoreParameter().pixelHeight = pixel_yres;
	 NativeResized();
	 ELOG(@"Updated display resolution: (%d, %d) @%.1fx", pixel_xres, pixel_yres, scale);
}

- (void)setupView {
	if (m_view) {
		ELOG(@"Restarting\n");
		[self startVM:m_view];
		return;
	}
	UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
	auto screenBounds = [[UIScreen mainScreen] bounds];
	if(self.gsPreference == 3)
	{
		PPSSPPVulkanViewController *cgsh_view_controller=[[PPSSPPVulkanViewController alloc]
													  initWithResFactor:self.resFactor
													  videoWidth: self.videoWidth
													  videoHeight: self.videoHeight
													  core: self];
		m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
		m_view=cgsh_view_controller.view;
		m_view.contentMode = UIViewContentModeScaleToFill;
		[gl_view_controller addChildViewController:cgsh_view_controller];
		[cgsh_view_controller didMoveToParentViewController:gl_view_controller];
	} else if(self.gsPreference == 0) {
		PPSSPPOGLViewController *cgsh_view_controller=[[PPSSPPOGLViewController alloc]
													   initWithResFactor:self.resFactor
													   videoWidth: self.videoWidth
													   videoHeight: self.videoHeight
													   core: self];
		m_gl_layer=(CAEAGLLayer *)cgsh_view_controller.view.layer;
		m_view_controller = (UIViewController *)cgsh_view_controller;
		m_view=cgsh_view_controller.view;
		m_view.contentMode = UIViewContentModeScaleToFill;
		[gl_view_controller addChildViewController:cgsh_view_controller];
		[cgsh_view_controller didMoveToParentViewController:gl_view_controller];
		GLKView *glk_view=(GLKView *)m_view;
		m_gl_context=[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
		if (!m_gl_context) {
			m_gl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		}
		glk_view.context=m_gl_context;
		glk_view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
		glk_view.drawableStencilFormat = GLKViewDrawableStencilFormat8;
		[EAGLContext setCurrentContext:m_gl_context];
	}
	if ([gl_view_controller respondsToSelector:@selector(mtlview)]) {
		self.renderDelegate.mtlview.autoresizesSubviews=true;
		self.renderDelegate.mtlview.clipsToBounds=true;
		[self.renderDelegate.mtlview addSubview:m_view];
    } else {
		gl_view_controller.view.autoresizesSubviews=true;
		gl_view_controller.view.clipsToBounds=true;
		[gl_view_controller.view addSubview:m_view];
    }
    if (IS_IPAD()) {
        auto bounds=[[UIScreen mainScreen] bounds];
        [m_view.widthAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.widthAnchor].active=true;
        [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
        [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
        [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
        [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
        [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
    } else {
        auto bounds=[[UIScreen mainScreen] bounds];
        [m_view.widthAnchor constraintGreaterThanOrEqualToConstant:bounds.size.width].active=true;
        [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;;
        [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
        [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
        [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
        [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
    }
    // Display connected
	[[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidConnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
			UIScreen *screen = (UIScreen *) notification.object;
			NSLog(@"New display connected: %@", [screen debugDescription]);
		[self refreshScreenSize];
	}];
	// Display disconnected
	[[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidDisconnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
		UIScreen *screen = (UIScreen *) notification.object;
		NSLog(@"Display disconnected: %@", [screen debugDescription]);
	}];
}

- (void)setupVideo {
	if (self.gsPreference == 0) {
		// GPUCORE_GLES or GPUCORE_VULKAN
		PSP_CoreParameter().gpuCore         = GPUCORE_GLES;
		graphicsContext = new OGLGraphicsContext();
        bindDefaultFBO();
	}
	graphicsContext->GetDrawContext()->SetErrorCallback([](const char *shortDesc, const char *details, void *userdata) {
	   ELOG(@"Error %s\n", details);
		   host->NotifyUserMessage(details, 5.0, 0xFFFFFFFF, "error_callback");
	   }, nullptr);
	graphicsContext->ThreadStart();
	dp_xscale = (float)dp_xres / (float)pixel_xres;
	dp_yscale = (float)dp_yres / (float)pixel_yres;
	PSP_CoreParameter().graphicsContext = graphicsContext;
}

- (void)runVM {
	threadEnabled=true;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		NativeInitGraphics(graphicsContext);
		_isInitialized=true;
        UpdateUIState(UISTATE_INGAME);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            isPaused=false;
        });
        ELOG(@"Emulation thread starting\n");
		while (threadEnabled) {
			NativeUpdate();
			NativeRender(graphicsContext);
		}
		ELOG(@"Emulation thread shutting down\n");
		NativeShutdownGraphics();
		ELOG(@"Emulation thread stopping\n");
		graphicsContext->StopThread();
		threadStopped = true;
	});
}

- (void)stopVM:(bool)deinitViews  {
	if (threadEnabled) {
		threadEnabled = false;
		if (graphicsContext) {
			while (graphicsContext->ThreadFrame()) {
				sleep_ms(100);
				continue;
			}
			while (!threadStopped) {
				sleep_ms(100);
			}
			graphicsContext->ThreadEnd();
		}
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	PSP_Shutdown();
	VFSShutdown();
	if (graphicsContext) {
		graphicsContext->Shutdown();
		delete graphicsContext;
		graphicsContext = nullptr;
		PSP_CoreParameter().graphicsContext = nullptr;
	}
    host->ShutdownGraphics();
    System_SendMessage("finish", "");
    net::Shutdown();
    LogManager::Shutdown();
	if (deinitViews) {
		[m_view removeFromSuperview];
		[m_view_controller dismissViewControllerAnimated:NO completion:nil];
		m_gl_context = nullptr;
		m_gl_layer = nullptr;
		m_metal_layer = nullptr;
		m_view = nullptr;
		m_view_controller = nullptr;
		m_view=nil;
	}
}

# pragma mark - Properties

- (CGSize)bufferSize {
	return CGSizeMake(0,0);
}

- (CGRect)screenRect {
	return CGRectMake(0, 0, self.videoWidth * self.resFactor , self.videoHeight * self.resFactor);
}

- (CGSize)aspectSize {
	return CGSizeMake(self.videoWidth, self.videoHeight);
}

- (BOOL)rendersToOpenGL {
	return YES;
}

- (BOOL)isDoubleBuffered {
	return YES;
}

- (const void *)videoBuffer {
	return NULL;
}

- (GLenum)pixelFormat {
	return GL_RGBA;
}

- (GLenum)pixelType {
	return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
	return GL_RGBA;
}

@end

void bindDefaultFBO()
{
	if (m_view) {
		[(GLKView*)m_view bindDrawable];
	}
}
