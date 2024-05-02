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
	if (_isInitialized && threadEnabled && !isPaused) {
		graphicsContext->ThreadFrame();
	}
}

- (void)refreshScreenSize {
    NSLog(@"Refresh Screen Size");
    UIScreen *screen=[UIScreen mainScreen];
    if (!_isInitialized || !m_view)
        return;
    float adjustedHeight = screen.bounds.size.height / 2;
#if !TARGET_OS_TV
    if ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortrait ||
        [[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortraitUpsideDown) {
        if (m_view.frame.size.width > m_view.frame.size.height) {
            if (self.gsPreference == 0) {
                if (m_view.frame.size.height != adjustedHeight) {
                    [[m_view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
                    [[m_view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:NO];
                    [[m_view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
                    [[m_view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
                    
                    m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, adjustedHeight);
                }
            } else {
                m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
            }
        } else {
            if (self.gsPreference == 0) {
                if (m_view.frame.size.height != adjustedHeight) {
                    m_view.frame =  CGRectMake(0, 0, screen.bounds.size.width, adjustedHeight);
                }
            }
        }
    } else {
#endif
        if (m_view.frame.size.width < m_view.frame.size.height) {
            if (self.gsPreference == 0) {
                [[m_view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
                [[m_view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
                [[m_view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
                [[m_view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
                m_view.frame =  CGRectMake(0, 0, screen.bounds.size.width, screen.bounds.size.height);
            } else {
                m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
            }
        }
#if !TARGET_OS_TV
    }
#endif
    float scale = screen.scale;
    if ([screen respondsToSelector:@selector(nativeScale)]) {
            scale = screen.nativeScale;
    }
#if TARGET_OS_TV
    CGSize size = screen.bounds.size;
#else
    CGSize size = screen.applicationFrame.size;
#endif
    if (size.height > size.width) {
        float h = size.height;
        if (IS_IPAD())
            size.height = int(size.width * size.width / size.height);
        else
            size.height = size.width * 272 / 480;
    }
    if (screen == [UIScreen mainScreen]) {
            g_display.dpi = (IS_IPAD() ? 200.0f : 150.0f) * scale;
    } else {
            float diagonal = sqrt(size.height * size.height + size.width * size.width);
            g_display.dpi = diagonal * scale * 0.1f;
    }
    g_display.dpi_scale_x = 240.0f / g_display.dpi;
    g_display.dpi_scale_y = 240.0f / g_display.dpi;
    g_display.dpi_scale_real_x = g_display.dpi_scale_x;
    g_display.dpi_scale_real_y = g_display.dpi_scale_y;
    g_display.pixel_xres = size.width * scale;
    g_display.pixel_yres = size.height * scale;
    g_display.dp_xres = g_display.pixel_xres * g_display.dpi_scale_x;
    g_display.dp_yres = g_display.pixel_yres * g_display.dpi_scale_y;
    g_display.pixel_in_dps_x = (float)g_display.pixel_xres / (float)g_display.dp_xres;
    g_display.pixel_in_dps_y = (float)g_display.pixel_yres / (float)g_display.dp_yres;
    [m_view setContentScaleFactor:scale];
    // PSP native resize
    PSP_CoreParameter().pixelWidth = g_display.pixel_xres;
    PSP_CoreParameter().pixelHeight = g_display.pixel_yres;
    NativeResized();
    NSLog(@"Updated display resolution: (%d, %d) @%.1fx", g_display.pixel_xres, g_display.pixel_yres, scale);
}

- (void)setupView {
    NSLog(@"setupView: Starting\n");
    if (m_view) {
        NSLog(@"setupView: Restarting\n");
        [self setupVideo];
        [self startVM:m_view];
        return;
    }
    NSLog(@"setupView: Setting Up View\n");
    UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
    auto screenBounds = [[UIScreen mainScreen] bounds];
    UIViewController *rootController;
    if(self.gsPreference == 3) {
        PPSSPPVulkanViewController *cgsh_view_controller=[[PPSSPPVulkanViewController alloc]
                                                      initWithResFactor:self.resFactor
                                                      videoWidth: self.videoWidth
                                                      videoHeight: self.videoHeight
                                                      core: self];
        m_view_controller = (UIViewController *)cgsh_view_controller;
        m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
        m_view=cgsh_view_controller.view;
        m_view.contentMode = UIViewContentModeScaleToFill;
        rootController = cgsh_view_controller;
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
        GLKView *glk_view=(GLKView *)m_view;
        m_gl_context=[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if (!m_gl_context) {
            m_gl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        }
        glk_view.context=m_gl_context;
        glk_view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        glk_view.drawableStencilFormat = GLKViewDrawableStencilFormat8;
        [EAGLContext setCurrentContext:m_gl_context];
        rootController = cgsh_view_controller;
    }
    [self setupVideo];
    if (self.touchViewController) {
        NSLog(@"setupView: Touch View");
        [self.touchViewController.view addSubview:m_view];
        [self.touchViewController addChildViewController:rootController];
        [rootController didMoveToParentViewController:self.touchViewController];
        [self.touchViewController.view sendSubviewToBack:m_view];
        [rootController.view setHidden:false];
        rootController.view.translatesAutoresizingMaskIntoConstraints = false;
        [[rootController.view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
        [[rootController.view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
        [[rootController.view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
        [[rootController.view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
        self.touchViewController.view.userInteractionEnabled=true;
        self.touchViewController.view.autoresizesSubviews=true;
#if !TARGET_OS_TV
        self.touchViewController.view.multipleTouchEnabled=true;
#endif
    } else {
        [gl_view_controller addChildViewController:rootController];
        [rootController didMoveToParentViewController:gl_view_controller];
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
            [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
            [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
            [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
            [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
            [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
        }
    }
     
    // Display connected
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidConnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
            UIScreen *screen = (UIScreen *) notification.object;
            NSLog(@"setupView: New display connected: %@", [screen debugDescription]);
        [self refreshScreenSize];
    }];
    // Display disconnected
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidDisconnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        UIScreen *screen = (UIScreen *) notification.object;
        NSLog(@"setupView: Display disconnected: %@", [screen debugDescription]);
    }];
    self.isViewReady = true;
    NSLog(@"setupView: OK\n");
}

- (void)setupVideo {
    NSLog(@"setupVideo: Starting\n");
    if (self.gsPreference == 0) {
        // GPUCORE_GLES
        g_Config.iGPUBackend = (int)GPUBackend::OPENGL;
        PSP_CoreParameter().gpuCore         = GPUCORE_GLES;
        graphicsContext = new OGLGraphicsContext();
        bindDefaultFBO();
        graphicsContext->ThreadStart();
    } else if (self.gsPreference == 3) {
        // GPUCORE_VULKAN
        g_Config.iGPUBackend = (int)GPUBackend::VULKAN;
        PSP_CoreParameter().gpuCore         = GPUCORE_VULKAN;
        graphicsContext = new VulkanGraphicsContext(m_metal_layer, "@executable_path/Frameworks/libMoltenVK_PPSSPP.dylib");
    }
    graphicsContext->GetDrawContext()->SetErrorCallback([](const char *shortDesc, const char *details, void *userdata) {
        NSLog(@"setupVideo: Notify User Message: %s %s\n", shortDesc, details);
        System_NotifyUserMessage(details, 5.0, 0xFFFFFFFF, "error_callback");
    }, nullptr);
    dp_xscale = (float)g_display.dp_xres / (float)g_display.pixel_xres;
    dp_yscale = (float)g_display.dp_yres / (float)g_display.pixel_yres;
    PSP_CoreParameter().graphicsContext = graphicsContext;
    self.isGFXReady=true;
    NSLog(@"setupVideo: OK\n");
    }

- (void)runVM {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!self.isViewReady || !self.isGFXReady) {
            NSLog(@"runVM: %d %d", self.isViewReady, self.isGFXReady);
            usleep(200 * 1000);
        }
        NSLog(@"runVM: SetupEmulation Starting\n");
        [self setupEmulation];
        NSLog(@"runVM: SetupEmulation OK\n");
        threadEnabled=true;
        NSLog(@"runVM: NativeInitGraphics Starting\n");
        NativeInitGraphics(graphicsContext);
        _isInitialized=true;
        UpdateUIState(UISTATE_INGAME);
        NSLog(@"runVM: NativeInitGraphics OK\n");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            isPaused=false;
            [self refreshScreenSize];
        });
        NSLog(@"runVM: Emulation thread starting\n");
		while (graphicsContext != NULL && threadEnabled) {
            if (isPaused) {
                usleep(700 * 1000);
            } else {
                NativeUpdate();
                NativeRender(graphicsContext);
            }
		}
		NSLog(@"runVM: Emulation thread shutting down\n");
		NativeShutdownGraphics();
		NSLog(@"runVM: Emulation thread stopping\n");
        if (self.gsPreference == 0 && graphicsContext) {
            graphicsContext->StopThread();
            graphicsContext->ThreadEnd();
        }
		threadStopped = true;
	});
}

- (void)stopVM:(bool)deinitViews  {
    NSLog(@"Stop VM");
    PSP_Shutdown();
	if (threadEnabled) {
		threadEnabled = false;
        if (graphicsContext) {
            while (!threadStopped) {
                if (self.gsPreference == 0 && graphicsContext) {
                    graphicsContext->ThreadFrame();
                }
                usleep(100 * 1000);
            }
        }
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    if (graphicsContext) {
		graphicsContext->Shutdown();
		delete graphicsContext;
		graphicsContext = nullptr;
		PSP_CoreParameter().graphicsContext = nullptr;
	}
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
	return NO;
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
