//
//  PVPPSSPP+Video.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "OGLGraphicsContext.h"
#import "VulkanGraphicsContext.h"
#import <PVLogging/PVLoggingObjC.h>

//#import "PVPPSSPPCore.h"
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>

/* PPSSPP Includes */
#ifdef __cplusplus
    #include <vector>
    #include <string>
    #include <cstring>
#endif

#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/System/System.h"
#include "Common/GPU/Vulkan/VulkanContext.h"
#include "Common/GPU/Vulkan/VulkanDebug.h"
#include "Common/GPU/Vulkan/VulkanLoader.h"
#ifdef __cplusplus
    #include "Common/GPU/Vulkan/VulkanRenderManager.h"
#endif
#include "Common/GPU/thin3d.h"
#include "Common/GPU/thin3d_create.h"
#include "Common/Data/Text/Parsers.h"
#include "Common/VR/PPSSPPVR.h"
#include "Common/Log.h"
#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/System.h"
#if !PPSSPP_PLATFORM(WINDOWS) && !PPSSPP_PLATFORM(SWITCH)
    #include <dlfcn.h>
#endif

/* PSP Includes */
//#import <dlfcn.h>
//#import <pthread.h>
//#import <signal.h>
//#import <string>
//#import <stdio.h>
//#import <stdlib.h>
//#import <sys/syscall.h>
//#import <sys/types.h>
//#import <sys/sysctl.h>
//#import <mach/mach.h>
//#import <mach/machine.h>

#import <AudioToolbox/AudioToolbox.h>

//#include "Common/MemoryUtil.h"
//#include "Common/Profiler/Profiler.h"
//#include "Common/CPUDetect.h"
//#include "Common/Log.h"
//#include "Common/LogManager.h"
//#include "Common/TimeUtil.h"
//#include "Common/File/FileUtil.h"
//#include "Common/Serialize/Serializer.h"
//#include "Common/ConsoleListener.h"
//#include "Common/Input/InputState.h"
//#include "Common/Input/KeyCodes.h"
//#include "Common/Thread/ThreadUtil.h"
//#include "Common/Thread/ThreadManager.h"
//#include "Common/File/VFS/VFS.h"
//#include "Common/Data/Text/I18n.h"
//#include "Common/StringUtils.h"
//#include "Common/System/Display.h"
//#include "Common/System/NativeApp.h"
//#include "Common/System/System.h"
//#include "Common/GraphicsContext.h"
//#include "Common/Net/Resolve.h"
//#include "Common/UI/Screen.h"
//#include "Common/GPU/thin3d.h"
//#include "Common/GPU/thin3d_create.h"
//#include "Common/GPU/OpenGL/GLRenderManager.h"
//#include "Common/GPU/OpenGL/GLFeatures.h"
//#include "Common/System/NativeApp.h"
//#include "Common/File/VFS/VFS.h"
//#include "Common/Log.h"
//#include "Common/TimeUtil.h"
//#include "Common/GraphicsContext.h"

//#include "GPU/GPUState.h"
//#include "GPU/GPUInterface.h"

//#include "Core/Config.h"
//#include "Core/ConfigValues.h"
//#include "Core/Core.h"
//#include "Core/CoreParameter.h"
//#include "Core/HLE/sceCtrl.h"
//#include "Core/HLE/sceUtility.h"
//#include "Core/HW/MemoryStick.h"
//#include "Core/MemMap.h"
//#include "Core/System.h"
//#include "Core/CoreTiming.h"
//#include "Core/HW/Display.h"
//#include "Core/CwCheat.h"
//#include "Core/ELF/ParamSFO.h"
//#include "Core/SaveState.h"

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

@interface PVPPSSPPCoreBridge (CustomLayout)
@property (nonatomic, assign) BOOL useCustomRenderViewLayout;
@property (nonatomic, assign) CGRect pendingCustomFrame;
@end

@implementation PVPPSSPPCoreBridge (CustomLayout)

- (void)setUseCustomRenderViewLayout:(BOOL)enabled {
    objc_setAssociatedObject(self, @selector(useCustomRenderViewLayout), @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    /// If enabling custom layout and there's a pending frame, apply it now
    /// Check if view is ready by checking if m_view exists and has a superview
    if (enabled && m_view && m_view.superview && !CGRectIsEmpty(self.pendingCustomFrame)) {
        ILOG(@"PPSSPP: setUseCustomRenderViewLayout enabled, applying pending custom frame: %@", NSStringFromCGRect(self.pendingCustomFrame));
        CGRect frame = self.pendingCustomFrame;
        self.pendingCustomFrame = CGRectZero;
        [self applyRenderViewFrameInTouchView:frame];
    }
}

- (BOOL)useCustomRenderViewLayout {
    NSNumber *val = objc_getAssociatedObject(self, @selector(useCustomRenderViewLayout));
    return val ? val.boolValue : NO;
}

- (void)setPendingCustomFrame:(CGRect)frame {
    NSValue *frameValue = [NSValue valueWithCGRect:frame];
    objc_setAssociatedObject(self, @selector(pendingCustomFrame), frameValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGRect)pendingCustomFrame {
    NSValue *frameValue = objc_getAssociatedObject(self, @selector(pendingCustomFrame));
    return frameValue ? frameValue.CGRectValue : CGRectZero;
}

@end

@implementation PVPPSSPPCoreBridge (Video)

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
    ILOG(@"Refresh Screen Size");
    UIScreen *screen=[UIScreen mainScreen];
    if (!_isInitialized || !m_view)
        return;

    /// Check if custom layout is enabled (DeltaSkin)
    BOOL hasCustomLayout = self.useCustomRenderViewLayout;

    /// Skip frame modifications when custom layout is enabled (DeltaSkin manages the frame)
    if (!hasCustomLayout) {
        float adjustedHeight = screen.bounds.size.height / 2;
#if !TARGET_OS_TV
        if ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortrait ||
            [[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortraitUpsideDown) {
            if (m_view.frame.size.width > m_view.frame.size.height) {
                if (self.gsPreference == 0) {
                    if (m_view.frame.size.height != adjustedHeight) {
                        if (self.touchViewController && self.touchViewController.view) {
                            [[m_view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
                            [[m_view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:NO];
                            [[m_view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
                            [[m_view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
                        }
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
                    if (self.touchViewController && self.touchViewController.view) {
                        [[m_view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
                        [[m_view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
                        [[m_view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
                        [[m_view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
                    }
                    m_view.frame =  CGRectMake(0, 0, screen.bounds.size.width, screen.bounds.size.height);
                } else {
                    m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
                }
            }
#if !TARGET_OS_TV
        }
#endif
    }

    float scale = screen.scale;
    if ([screen respondsToSelector:@selector(nativeScale)]) {
            scale = screen.nativeScale;
    }

    /// Use m_view.frame.size when custom layout is enabled (DeltaSkin viewport), otherwise use screen size
    CGSize size;
    if (hasCustomLayout) {
        size = m_view.frame.size;
        ILOG(@"PPSSPP: Using m_view.frame.size for rendering: %.0fx%.0f", size.width, size.height);
    } else {
#if TARGET_OS_TV
        size = screen.bounds.size;
#else
        size = screen.applicationFrame.size;
#endif
    }
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
    ILOG(@"Updated display resolution: (%d, %d) @%.1fx", g_display.pixel_xres, g_display.pixel_yres, scale);
}

- (void)applyRenderViewFrameInTouchView:(CGRect)frame {
    ILOG(@"PPSSPP: ========================================");
    ILOG(@"PPSSPP: applyRenderViewFrameInTouchView called with frame: %@", NSStringFromCGRect(frame));

    if (!m_view) {
        ILOG(@"PPSSPP: m_view nil, exiting.");
        return;
    }

    /// ALWAYS find a parent view - don't give up
    /// Priority: 1) m_view.superview (most reliable), 2) renderDelegate.mtlView, 3) renderDelegate.view, 4) touchViewController.view
    UIView *parent = nil;

    if (m_view.superview) {
        parent = m_view.superview;
        ILOG(@"PPSSPP: Using m_view.superview as parent: %@", parent);
    } else if (self.renderDelegate) {
        /// For Metal, m_view should be added to renderDelegate.mtlView
        /// Try to get it using the protocol method - this is the most common case for PPSSPP
        @try {
            if ([(id)self.renderDelegate respondsToSelector:@selector(mtlView)]) {
                UIView *mtlView = [(id)self.renderDelegate performSelector:@selector(mtlView)];
                if (mtlView) {
                    parent = mtlView;
                    ILOG(@"PPSSPP: Using renderDelegate.mtlView as parent: %@", parent);
                }
            }
        } @catch (NSException *e) {
            ILOG(@"PPSSPP: Exception accessing mtlView: %@", e);
        }

        /// Fallback: use renderDelegate.view (gpuViewController.view)
        if (!parent) {
            UIViewController *renderVC = (UIViewController *)self.renderDelegate;
            if (renderVC && renderVC.view) {
                parent = renderVC.view;
                ILOG(@"PPSSPP: Using renderDelegate.view as parent: %@", parent);
            }
        }
    } else if (self.touchViewController && self.touchViewController.view) {
        parent = self.touchViewController.view;
        ILOG(@"PPSSPP: Using touchViewController.view as parent: %@", parent);
    }

    /// If we still don't have a parent, try to find it by checking if m_view has a window
    /// If m_view has a window, try to find its parent in the view hierarchy
    if (!parent) {
        ILOG(@"PPSSPP: No parent view found - renderDelegate=%@, touchViewController=%@, m_view.superview=%@",
             self.renderDelegate, self.touchViewController, m_view.superview);

        /// Try to find parent by checking if renderDelegate was set after setupView
        /// This handles the case where renderDelegate is null during setupView but gets set later
        if (self.renderDelegate) {
            UIViewController *renderVC = (UIViewController *)self.renderDelegate;
            @try {
                if ([renderVC respondsToSelector:@selector(mtlView)]) {
                    UIView *mtlView = [(id)renderVC performSelector:@selector(mtlView)];
                    if (mtlView) {
                        parent = mtlView;
                        ILOG(@"PPSSPP: Found renderDelegate.mtlView as parent (late): %@", parent);
                    }
                }
            } @catch (NSException *e) {
                ILOG(@"PPSSPP: Exception accessing mtlView: %@", e);
            }

            if (!parent && renderVC.view) {
                parent = renderVC.view;
                ILOG(@"PPSSPP: Found renderDelegate.view as parent (late): %@", parent);
            }
        }

        /// If still no parent, store frame and apply later
        if (!parent) {
            ILOG(@"PPSSPP: Still no parent, storing frame for later: %@", NSStringFromCGRect(frame));
            self.pendingCustomFrame = frame;

            /// Set up for frame-based layout
            m_view.translatesAutoresizingMaskIntoConstraints = YES;
            m_view.autoresizingMask = UIViewAutoresizingNone;

            /// Pixel-align and apply frame
            CGFloat scale = UIScreen.mainScreen.scale;
            CGRect aligned = (CGRect){
                .origin.x = floor(frame.origin.x * scale) / scale,
                .origin.y = floor(frame.origin.y * scale) / scale,
                .size.width = floor(frame.size.width * scale) / scale,
                .size.height = floor(frame.size.height * scale) / scale
            };

            if (aligned.size.width > 0 && aligned.size.height > 0) {
                m_view.frame = aligned;
                m_view.hidden = NO;
                m_view.alpha = 1.0;
                ILOG(@"PPSSPP: Applied frame directly to m_view: %@", NSStringFromCGRect(aligned));
                [self refreshScreenSize];
            }

            /// Schedule retry
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!CGRectIsEmpty(self.pendingCustomFrame) && m_view.superview) {
                    ILOG(@"PPSSPP: Retrying frame application after view hierarchy settled");
                    CGRect frameToApply = self.pendingCustomFrame;
                    self.pendingCustomFrame = CGRectZero;
                    [self applyRenderViewFrameInTouchView:frameToApply];
                }
            });
            return;
        }
    }

    ILOG(@"PPSSPP: m_view: %@, current frame: %@, superview: %@", m_view, NSStringFromCGRect(m_view.frame), m_view.superview);

    /// Ensure view is in parent - CRITICAL: m_view must be in the view hierarchy for frame to work
    if (m_view.superview != parent) {
        if (m_view.superview) {
            /// Remove from old parent first
            [m_view removeFromSuperview];
        }
        [parent addSubview:m_view];
        ILOG(@"PPSSPP: Added m_view to parent: %@, m_view.superview is now: %@", parent, m_view.superview);

        /// Force layout to ensure superview is set
        [parent setNeedsLayout];
        [parent layoutIfNeeded];
    }

    /// Validate frame
    CGRect parentBounds = parent.bounds;
    if (frame.size.width <= 0 || frame.size.height <= 0 ||
        frame.size.width > parentBounds.size.width * 2 ||
        frame.size.height > parentBounds.size.height * 2 ||
        isnan(frame.origin.x) || isnan(frame.origin.y) ||
        isnan(frame.size.width) || isnan(frame.size.height)) {
        ILOG(@"PPSSPP: Invalid frame received: %@ (parent bounds: %@), skipping", NSStringFromCGRect(frame), NSStringFromCGRect(parentBounds));
        return;
    }

    /// Set up for frame-based layout
    m_view.translatesAutoresizingMaskIntoConstraints = YES;
    m_view.autoresizingMask = UIViewAutoresizingNone;

    /// Pixel-align the frame (same as RetroArch)
    CGFloat scale = UIScreen.mainScreen.scale;
    CGRect aligned = (CGRect){
        .origin.x = floor(frame.origin.x * scale) / scale,
        .origin.y = floor(frame.origin.y * scale) / scale,
        .size.width = floor(frame.size.width * scale) / scale,
        .size.height = floor(frame.size.height * scale) / scale
    };

    if (aligned.size.width <= 0 || aligned.size.height <= 0) {
        ILOG(@"PPSSPP: Aligned frame has invalid size: %@", NSStringFromCGRect(aligned));
        return;
    }

    /// Set the frame
    m_view.frame = aligned;
    ILOG(@"PPSSPP: Set m_view.frame to: %@", NSStringFromCGRect(m_view.frame));

    /// Ensure z-order (below skin, just like RetroArch)
    [parent sendSubviewToBack:m_view];

    /// Ensure view is visible
    m_view.hidden = NO;
    m_view.alpha = 1.0;
    ILOG(@"PPSSPP: Set visibility - hidden: %d, alpha: %.2f", m_view.hidden, m_view.alpha);

    /// Update content scale
    m_view.contentScaleFactor = scale;

    /// Update Metal layer drawable size - CRITICAL for Vulkan swapchain sizing
    CGSize pixelSize = CGSizeMake(aligned.size.width * scale, aligned.size.height * scale);
    if ([m_view.layer isKindOfClass:[CAMetalLayer class]]) {
        CAMetalLayer *ml = (CAMetalLayer *)m_view.layer;
        ml.contentsScale = scale;
        ml.drawableSize = pixelSize;
        ILOG(@"PPSSPP: Updated Metal layer drawableSize to: %.0fx%.0f", pixelSize.width, pixelSize.height);
    }

    /// Force layout update to ensure Vulkan swapchain resizes
    [m_view setNeedsLayout];
    [m_view layoutIfNeeded];

    /// Also trigger parent layout to ensure view hierarchy is updated
    [parent setNeedsLayout];
    [parent layoutIfNeeded];

    ILOG(@"PPSSPP: Applied frame: %@ (scale: %.2f, pixelSize: %.0fx%.0f)", NSStringFromCGRect(aligned), scale, pixelSize.width, pixelSize.height);
    ILOG(@"PPSSPP: m_view after apply - frame: %@, bounds: %@, superview: %@, hidden: %d",
         NSStringFromCGRect(m_view.frame), NSStringFromCGRect(m_view.bounds), m_view.superview, m_view.hidden);
    ILOG(@"PPSSPP: ========================================");

    /// Refresh screen size so PPSSPP knows the new viewport - MUST happen after frame/bounds are set
    /// Use dispatch_async to ensure layout is complete before refreshing
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshScreenSize];

        /// Additional check: if m_view is a PPSSPPVulkanViewController's view, trigger its layout
        if ([m_view.nextResponder isKindOfClass:[UIViewController class]]) {
            UIViewController *vc = (UIViewController *)m_view.nextResponder;
            if ([vc isKindOfClass:NSClassFromString(@"PPSSPPVulkanViewController")]) {
                [vc viewDidLayoutSubviews];
                ILOG(@"PPSSPP: Triggered PPSSPPVulkanViewController.viewDidLayoutSubviews");
            }
        }
    });
}

- (void)setupView {
    ILOG(@"setupView: Starting\n");
    if (m_view) {
        ILOG(@"setupView: Restarting\n");
        [self setupVideo];
        [self startVM:m_view];
        return;
    }
    ILOG(@"setupView: Setting Up View\n");
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

    /// Check if custom layout is enabled - if so, skip constraint creation
    BOOL useCustomLayout = self.useCustomRenderViewLayout;

#if TARGET_OS_TV
    [gl_view_controller addChildViewController:rootController];
    [rootController didMoveToParentViewController:gl_view_controller];
    if ([gl_view_controller respondsToSelector:@selector(mtlView)]) {
        self.renderDelegate.mtlView.autoresizesSubviews = true;
        self.renderDelegate.mtlView.clipsToBounds = true;
        [self.renderDelegate.mtlView addSubview:m_view];
    } else {
        gl_view_controller.view.autoresizesSubviews = true;
        gl_view_controller.view.clipsToBounds = true;
        [gl_view_controller.view addSubview:m_view];
    }
    /// Only create constraints when custom layout is NOT enabled
    if (!useCustomLayout) {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        if (gl_view_controller.view) {
            [m_view.widthAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.widthAnchor].active=true;
            [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
            [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
            [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
            [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
            [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
        }
    } else {
        /// Custom layout enabled - use frame-based layout
        m_view.translatesAutoresizingMaskIntoConstraints = YES;
        m_view.autoresizingMask = UIViewAutoresizingNone;
    }
#else
    if (self.touchViewController) {
        ILOG(@"setupView: Touch View");
        [self.touchViewController.view addSubview:m_view];
        [self.touchViewController addChildViewController:rootController];
        [rootController didMoveToParentViewController:self.touchViewController];
        [self.touchViewController.view sendSubviewToBack:m_view];
        [rootController.view setHidden:false];

        /// Only create constraints when custom layout is NOT enabled
        if (!useCustomLayout) {
            rootController.view.translatesAutoresizingMaskIntoConstraints = false;
            if (self.touchViewController.view) {
                [[rootController.view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
                [[rootController.view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
                [[rootController.view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
                [[rootController.view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
            }
        } else {
            /// Custom layout enabled - use frame-based layout
            rootController.view.translatesAutoresizingMaskIntoConstraints = YES;
            rootController.view.autoresizingMask = UIViewAutoresizingNone;
        }
        self.touchViewController.view.userInteractionEnabled=true;
        self.touchViewController.view.autoresizesSubviews=true;
        self.touchViewController.view.multipleTouchEnabled=true;
    } else {
        [gl_view_controller addChildViewController:rootController];
        [rootController didMoveToParentViewController:gl_view_controller];

        /// Ensure parent view is loaded before adding subview
        UIView *parentView = nil;
        if ([gl_view_controller respondsToSelector:@selector(mtlView)] && self.renderDelegate.mtlView) {
            parentView = self.renderDelegate.mtlView;
            ILOG(@"PPSSPP: Using renderDelegate.mtlView as parent: %@", parentView);
        } else if (gl_view_controller.view) {
            parentView = gl_view_controller.view;
            ILOG(@"PPSSPP: Using renderDelegate.view as parent: %@", parentView);
        }

        if (parentView) {
            parentView.autoresizesSubviews = true;
            parentView.clipsToBounds = true;
            [parentView addSubview:m_view];
            ILOG(@"PPSSPP: Added m_view to parent: %@, m_view.superview: %@", parentView, m_view.superview);

            /// Force view hierarchy update - sometimes superview isn't set immediately
            [parentView setNeedsLayout];
            [parentView layoutIfNeeded];
            ILOG(@"PPSSPP: After layout, m_view.superview: %@", m_view.superview);
        } else {
            ILOG(@"PPSSPP: ERROR - No parent view available to add m_view!");
        }

        /// Only create constraints when custom layout is NOT enabled
        if (!useCustomLayout) {
            if (IS_IPAD()) {
                auto bounds=[[UIScreen mainScreen] bounds];
                if (gl_view_controller.view) {
                    [m_view.widthAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.widthAnchor].active=true;
                    [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
                    [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
                    [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
                    [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
                    [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
                }
            } else {
                auto bounds=[[UIScreen mainScreen] bounds];
                if (gl_view_controller.view) {
                    [m_view.widthAnchor constraintGreaterThanOrEqualToConstant:bounds.size.width].active=true;
                    [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
                    [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
                    [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
                    [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
                    [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
                }
            }
        } else {
            /// Custom layout enabled - use frame-based layout
            m_view.translatesAutoresizingMaskIntoConstraints = YES;
            m_view.autoresizingMask = UIViewAutoresizingNone;
        }
    }
#endif

    // Display connected
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidConnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
            UIScreen *screen = (UIScreen *) notification.object;
            ILOG(@"setupView: New display connected: %@", [screen debugDescription]);
        [self refreshScreenSize];
    }];
    // Display disconnected
    [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidDisconnectNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        UIScreen *screen = (UIScreen *) notification.object;
        ILOG(@"setupView: Display disconnected: %@", [screen debugDescription]);
    }];
    self.isViewReady = true;

    ILOG(@"PPSSPP: setupView complete - m_view: %@, m_view.superview: %@, pendingCustomFrame: %@",
          m_view, m_view.superview, NSStringFromCGRect(self.pendingCustomFrame));

    /// If there's a pending frame, try to apply it now that view is in parent
    /// Check regardless of useCustomLayout since it might be enabled later
    if (!CGRectIsEmpty(self.pendingCustomFrame)) {
        /// Try immediate application
        if (m_view.superview) {
            ILOG(@"PPSSPP: setupView complete, applying pending custom frame: %@", NSStringFromCGRect(self.pendingCustomFrame));
            CGRect frame = self.pendingCustomFrame;
            self.pendingCustomFrame = CGRectZero;
            [self applyRenderViewFrameInTouchView:frame];
        } else {
            ILOG(@"PPSSPP: setupView complete but m_view.superview is nil, scheduling retries");
            /// Retry multiple times with increasing delays to allow view hierarchy to settle
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) return;

                if (!CGRectIsEmpty(strongSelf.pendingCustomFrame) && m_view.superview) {
                    ILOG(@"PPSSPP: Retry 1 - Applying pending frame after setupView");
                    CGRect frame = strongSelf.pendingCustomFrame;
                    strongSelf.pendingCustomFrame = CGRectZero;
                    [strongSelf applyRenderViewFrameInTouchView:frame];
                    return;
                }

                /// Second retry after a short delay
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) return;

                    if (!CGRectIsEmpty(strongSelf.pendingCustomFrame) && m_view.superview) {
                        ILOG(@"PPSSPP: Retry 2 - Applying pending frame after 0.1s delay");
                        CGRect frame = strongSelf.pendingCustomFrame;
                        strongSelf.pendingCustomFrame = CGRectZero;
                        [strongSelf applyRenderViewFrameInTouchView:frame];
                    } else if (!CGRectIsEmpty(strongSelf.pendingCustomFrame)) {
                        ILOG(@"PPSSPP: Retry 2 - m_view.superview still nil, frame will be reapplied when view hierarchy is ready");
                    }
                });
            });
        }
    }

    ILOG(@"setupView: OK\n");
}

- (void)setupVideo {
    ILOG(@"setupVideo: Starting\n");
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
        graphicsContext = new VulkanGraphicsContext(m_metal_layer, "@executable_path/Frameworks/MoltenVK.framework/MoltenVK");
        if(!graphicsContext) {
            graphicsContext = new VulkanGraphicsContext(m_metal_layer, "@executable_path/Frameworks/libMoltenVK.dylib");
        }
    }
    graphicsContext->GetDrawContext()->SetErrorCallback([](const char *shortDesc, const char *details, void *userdata) {
        ILOG(@"setupVideo: Notify User Message: %s %s\n", shortDesc, details);
        System_NotifyUserMessage(details, 5.0, 0xFFFFFFFF, "error_callback");
    }, nullptr);
    dp_xscale = (float)g_display.dp_xres / (float)g_display.pixel_xres;
    dp_yscale = (float)g_display.dp_yres / (float)g_display.pixel_yres;
    PSP_CoreParameter().graphicsContext = graphicsContext;
    self.isGFXReady=true;
    ILOG(@"setupVideo: OK\n");
    }

- (void)runVM {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!self.isViewReady || !self.isGFXReady) {
            ILOG(@"runVM: %d %d", self.isViewReady, self.isGFXReady);
            usleep(200 * 1000);
        }
        ILOG(@"runVM: SetupEmulation Starting\n");
        [self setupEmulation];
        ILOG(@"runVM: SetupEmulation OK\n");
        threadEnabled=true;
        ILOG(@"runVM: NativeInitGraphics Starting\n");
        NativeInitGraphics(graphicsContext);
        self->_isInitialized=true;
        UpdateUIState(UISTATE_INGAME);
        ILOG(@"runVM: NativeInitGraphics OK\n");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self->isPaused=false;
            [self refreshScreenSize];
        });
        ILOG(@"runVM: Emulation thread starting\n");
		while (graphicsContext != NULL && threadEnabled) {
            if (self->isPaused) {
                usleep(700 * 1000);
            } else {
                NativeUpdate();
                NativeRender(graphicsContext);
            }
		}
		ILOG(@"runVM: Emulation thread shutting down\n");
		NativeShutdownGraphics();
		ILOG(@"runVM: Emulation thread stopping\n");
        if (self.gsPreference == 0 && graphicsContext) {
            graphicsContext->StopThread();
            graphicsContext->ThreadEnd();
        }
		threadStopped = true;
	});
}

- (void)stopVM:(bool)deinitViews  {
    ILOG(@"Stop VM");
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
