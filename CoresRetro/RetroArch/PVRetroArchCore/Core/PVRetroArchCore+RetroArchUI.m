//
//  PVRetroArchCoreBridge.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Controls.h"
#import "PVRetroArchCoreBridge+Audio.h"
#import "PVRetroArchCoreBridge+Video.h"
#import "PVRetroArchCoreBridge+Archive.h"
#import <PVRetroArch/PVRetroArch-Swift.h>
#import <Foundation/Foundation.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "./cocoa_common.h"
#include "./apple_platform.h"
#include "./metal_common.h"

/* RetroArch Includes */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <boolean.h>

#include <file/file_path.h>
#include <queues/task_queue.h>
#include <string/stdstring.h>
#include <retro_timers.h>
#include "../ui_companion_driver.h"
#include "../../configuration.h"
#include "../../frontend/frontend.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../retroarch.h"
#include "../../verbosity.h"
#include "../../paths.h"
#include "../../audio/audio_driver.h"
#include "../../gfx/video_defines.h"
#include "../../gfx/video_driver.h"

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#include "../../menu/menu_driver.h"
#include "../../menu/menu_cbs.h"
#include "../../menu/menu_entries.h"
#include "../../msg_hash.h"
#endif
#import <AVFoundation/AVFoundation.h>
#import <PVLogging/PVLoggingObjC.h>
#import <objc/runtime.h>
@import PVSettings;

#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

static void rarch_draw_observer(CFRunLoopObserverRef observer,
                                CFRunLoopActivity activity, void *info);

static CFRunLoopObserverRef iterate_observer;


apple_frontend_settings_t apple_frontend_settings;
extern id<ApplePlatform> apple_platform;
extern void *apple_gamecontroller_joypad_init(void *data);
extern void apple_gamecontroller_joypad_disconnect(GCController* controller);
static void rarch_draw_observer(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info);
void ui_companion_cocoatouch_event_command(void *data, enum event_command cmd);
void handle_touch_event(NSArray* touches);
void frontend_darwin_get_env(int *argc, char *argv[], void *args, void *params_data);
void dir_check_defaults(const char *custom_ini_path);
void bundle_decompressed(retro_task_t *task, void *task_data, void *user_data, const char *err);
void main_msg_queue_push(const char *msg, unsigned prio, unsigned duration, bool flush);
bool processing_init=false;
int g_gs_preference;
extern GLKView *glk_view;
extern CocoaView* g_instance;
UIView *_renderView;
UIView *_renderContainerView;
apple_view_type_t _vt;
extern bool _isInitialized;
extern bool firstLoad;
char **argv;
int argc =  1;

#pragma mark - PVRetroArchCoreBridge Begin

#ifdef HAVE_COCOA_METAL
// TODO: Use me in Vulkan mode and change the code I edited in the past
// to workaround this not being the layer @JoeMatt
@interface RenderContainerView : UIView
@end

@implementation RenderContainerView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
#if HAVE_IOS_SWIFT
    /// First check if point is in helperBarView area - pass through to it
    CocoaView *cocoaView = [CocoaView get];
    if (cocoaView && cocoaView.helperBarView && cocoaView.helperBarView.superview) {
        CGPoint pointInSuperview = [self convertPoint:point toView:cocoaView.helperBarView.superview];
        if (CGRectContainsPoint(cocoaView.helperBarView.frame, pointInSuperview)) {
            CGPoint pointInHelperBar = [cocoaView.helperBarView.superview convertPoint:pointInSuperview toView:cocoaView.helperBarView];
            UIView *helperHitView = [cocoaView.helperBarView hitTest:pointInHelperBar withEvent:event];
            if (helperHitView) {
                return helperHitView;
            }
        }
    }
#endif

    /// Container doesn't handle touches (userInteractionEnabled = NO), so return nil
    /// This allows touches to pass through to views behind
    return nil;
}

@end

@implementation MetalLayerView

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupMetalLayer];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupMetalLayer];
    }
    return self;
}

- (CAMetalLayer *)metalLayer {
    return (CAMetalLayer *)self.layer;
}

- (void)setupMetalLayer {
    self.metalLayer.device = MTLCreateSystemDefaultDevice();
    self.metalLayer.contentsScale = cocoa_screen_get_native_scale();
    self.metalLayer.opaque = YES;
}

@end
#endif

#pragma mark - PVRetroArchCoreBridge Begin

@interface PVRetroArchCoreBridge (CustomLayout)
@property (nonatomic, assign) BOOL useCustomRenderViewLayout;
@property (nonatomic, assign) BOOL shouldTriggerRetroArchUpdates;
@property (nonatomic, assign) NSInteger pendingFrameApplicationCount;
@end

@implementation PVRetroArchCoreBridge (CustomLayout)

- (void)setUseCustomRenderViewLayout:(BOOL)enabled {
    DLOG(@"[RA] setUseCustomRenderViewLayout called with enabled=%d, _renderView=%@", enabled, _renderView ? @"exists" : @"nil");
    objc_setAssociatedObject(self, @selector(useCustomRenderViewLayout), @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // If _renderView doesn't exist yet, store the flag and apply when view is created
    if (!_renderView) {
        DLOG(@"[RA] _renderView nil, will apply custom layout when view is created");
        return;
    }
    UIView *rootView = [CocoaView get].view;
    if (!rootView) {
        ELOG(@"[RA] rootView nil, exiting");
        return;
    }
    // Don't auto-resize rootView to parent - applyRenderViewFrameInTouchView will size it to match game screen area
    rootView.translatesAutoresizingMaskIntoConstraints = YES;
    rootView.autoresizingMask = UIViewAutoresizingNone;
    // Remove any constraints tying renderView to root
    NSMutableArray<NSLayoutConstraint *> *toDeactivate = [NSMutableArray array];
    for (NSLayoutConstraint *c in rootView.constraints) {
        if (c.firstItem == _renderView || c.secondItem == _renderView) {
            [toDeactivate addObject:c];
        }
    }
    for (NSLayoutConstraint *c in _renderView.constraints) {
        [toDeactivate addObject:c];
    }
    // Also remove constraints from the current superview if different from root
    UIView *currentParent = _renderView.superview;
    if (currentParent && currentParent != rootView) {
        for (NSLayoutConstraint *c in currentParent.constraints) {
            if (c.firstItem == _renderView || c.secondItem == _renderView) {
                [toDeactivate addObject:c];
            }
        }
    }
    if (toDeactivate.count > 0) {
        [NSLayoutConstraint deactivateConstraints:toDeactivate];
        DLOG(@"[RA] CustomLayout: deactivated %lu constraints", (unsigned long)toDeactivate.count);
    }
    _renderView.translatesAutoresizingMaskIntoConstraints = YES;
    /// Use auto-resizing so _renderView automatically fills rootView when rootView.frame changes
    _renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _renderView.frame = rootView.bounds;
    _renderView.transform = CGAffineTransformIdentity;
    _renderView.contentMode = UIViewContentModeScaleToFill;
    _renderView.clipsToBounds = NO;

    UIView *mtkView = rootView.superview;
    if (mtkView) {
        /// Ensure render container exists in MTKView
        if (!_renderContainerView || _renderContainerView.superview != mtkView) {
            [_renderContainerView removeFromSuperview];
            _renderContainerView = [[RenderContainerView alloc] initWithFrame:CGRectZero];
            _renderContainerView.backgroundColor = [UIColor clearColor];
            _renderContainerView.userInteractionEnabled = NO;
            _renderContainerView.translatesAutoresizingMaskIntoConstraints = YES;
            _renderContainerView.autoresizingMask = UIViewAutoresizingNone;
            [mtkView addSubview:_renderContainerView];
        }

        if (_renderView && _renderView.superview != _renderContainerView) {
            [_renderContainerView addSubview:_renderView];
        }
    }
}

- (BOOL)useCustomRenderViewLayout {
    NSNumber *val = objc_getAssociatedObject(self, @selector(useCustomRenderViewLayout));
    return val.boolValue;
}

- (void)setShouldTriggerRetroArchUpdates:(BOOL)enabled {
    objc_setAssociatedObject(self, @selector(shouldTriggerRetroArchUpdates), @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)shouldTriggerRetroArchUpdates {
    NSNumber *val = objc_getAssociatedObject(self, @selector(shouldTriggerRetroArchUpdates));
    return val.boolValue;
}

- (void)setPendingFrameApplicationCount:(NSInteger)count {
    objc_setAssociatedObject(self, @selector(pendingFrameApplicationCount), @(count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)pendingFrameApplicationCount {
    NSNumber *val = objc_getAssociatedObject(self, @selector(pendingFrameApplicationCount));
    return val ? val.integerValue : 0;
}

@end

@interface PVRetroArchCoreBridge ()
@property (nonatomic, assign) BOOL useCustomRenderViewLayout;
@end

@implementation PVRetroArchCoreBridge (RetroArchUI)

- (void)setShowFPSCounterVisible:(BOOL)visible {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setShowFPSCounterVisible:visible];
        });
        return;
    }

    settings_t *settings = config_get_ptr();
    if (!settings) {
        WLOG(@"[RA] setShowFPSCounterVisible: settings not ready");
        return;
    }
    settings->bools.video_fps_show = visible;
}

- (UIView *)_ensureRenderContainerInMTKView:(UIView *)mtkView {
    if (!_renderContainerView || _renderContainerView.superview != mtkView) {
        [_renderContainerView removeFromSuperview];
        _renderContainerView = [[RenderContainerView alloc] initWithFrame:CGRectZero];
        _renderContainerView.backgroundColor = [UIColor clearColor];
        _renderContainerView.userInteractionEnabled = NO;
        _renderContainerView.translatesAutoresizingMaskIntoConstraints = YES;
        _renderContainerView.autoresizingMask = UIViewAutoresizingNone;
        [mtkView addSubview:_renderContainerView];
    }

    if (_renderView && _renderView.superview != _renderContainerView) {
        [_renderContainerView addSubview:_renderView];
    }

    return _renderContainerView;
}

// Helper method to check if a view contains a descendant
- (BOOL)_view:(UIView *)view containsDescendant:(UIView *)descendant {
    if (view == descendant) {
        return YES;
    }
    for (UIView *subview in view.subviews) {
        if ([self _view:subview containsDescendant:descendant]) {
            return YES;
        }
    }
    return NO;
}

- (void)initialize {
    [super initialize];
//    [self setupEmulation];
    ILOG(@"RetroArch: Extract %d\n", self.extractArchive);
}

- (void)setupEmulation {
    self.alwaysUseMetal = true;
    self.skipLayout = true;
    self.skipEmulationLoop = true;
    [self parseOptions];
    settings_t *settings = config_get_ptr();
    if (!settings) {
        retroarch_config_init();
        config_set_defaults(global_get_ptr());
        frontend_darwin_get_env(argc, argv, NULL, NULL);
        dir_check_defaults(NULL);
    }
    /// Enable savestate bypass to allow save states for all cores
    /// This bypasses the core info database check which may not be properly initialized
    settings = config_get_ptr();
    if (settings) {

        // TODO: This isn't working?
        settings->bools.video_fps_show = PVSettingsWrapper.showFPS;

        // Bypass save info, this is mostly for Dreamcast
        settings->bools.core_info_savestate_bypass = true;

        // TODO: We could setup cheevos options from PVCheevos and bridge through swift
        //settings->bools.cheevos_enable = true;
    }
    [self writeConfigFile];
    /// Sync BIOS resources, but exclude tos.img as it's handled specially in writeConfigFile
    /// This prevents overwriting the fixed TOS image
    NSString *systemDir = [self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/system"];
    [self syncResources:self.BIOSPath to:systemDir];

    // SPIKE 2823: This byte-mutation is a temporary hack that only works with TOS 1.02 US.
    // It should be replaced with proper Hatari configuration once the root cause of the
    // crash (incorrect TOS path or TOS content validation) is determined.
    // See: https://github.com/Provenance-Emu/Provenance/issues/2823
    /// Re-apply TOS fix after sync to ensure it's not overwritten
    if ([self.systemIdentifier containsString:@"atarist"] || [self.coreIdentifier containsString:@"hatari"]) {
        NSString *tosImagePath = [systemDir stringByAppendingPathComponent:@"tos.img"];
        NSString *biosTosPath = [self.BIOSPath stringByAppendingPathComponent:@"tos.img"];
        NSFileManager *fm = [[NSFileManager alloc] init];
        if ([fm fileExistsAtPath:biosTosPath] && [fm fileExistsAtPath:tosImagePath]) {
            NSData *tosData = [NSData dataWithContentsOfFile:biosTosPath];
            if (tosData && tosData.length >= 12) {
                NSMutableData *fixedTosData = [tosData mutableCopy];
                const unsigned char *bytes = (const unsigned char *)tosData.bytes;
                /// Ensure address bytes are correct
                /// Try [0x00, 0x00, 0xFC, 0x00] which reads as LE 0x00FC0000 (no swap needed)
                NSMutableData *postSyncTosData = [tosData mutableCopy];
                unsigned char *postSyncBytes = (unsigned char *)postSyncTosData.mutableBytes;
                postSyncBytes[8] = 0x00;
                postSyncBytes[9] = 0x00;
                postSyncBytes[10] = 0xFC;
                postSyncBytes[11] = 0x00;
                [postSyncTosData writeToFile:tosImagePath options:NSDataWritingAtomic error:nil];
                ILOG(@"Re-applied TOS address fix after sync: set to [0x00, 0x00, 0xFC, 0x00]");
            }
        }
    }
}

- (void)startEmulation {
	@autoreleasepool {
        _current=self;
        firstLoad=true;

        /// Ensure any existing RetroArch state is properly cleaned up before starting
        /// This prevents crashes when trying to destroy Vulkan contexts from previous failed loads
        if (_isInitialized) {
            ILOG(@"RetroArch: Cleaning up existing state before starting new game");
            self.shouldStop = YES;
            if (iterate_observer) {
                CFRunLoopObserverInvalidate(iterate_observer);
                CFRelease(iterate_observer);
                iterate_observer = NULL;
            }
            /// Properly shut down RetroArch before starting fresh
            /// This ensures Vulkan contexts are cleaned up in the correct order
            /// Must be on main thread for RetroArch cleanup
            if ([NSThread isMainThread]) {
                @try {
                    /// Use main_exit to properly clean up RetroArch state
                    /// This matches the cleanup in stopEmulation and ensures proper teardown
                    retroarch_config_init();
                    task_queue_init(true, (void (*)(struct retro_task *, const char *, unsigned int, unsigned int, bool)) main_msg_queue_push);
                    main_exit(NULL);
                    task_queue_deinit();
                } @catch (NSException *e) {
                    WLOG(@"RetroArch: Exception during cleanup: %@", e);
                }
            } else {
                /// If not on main thread, dispatch cleanup synchronously
                dispatch_sync(dispatch_get_main_queue(), ^{
                    @try {
                        retroarch_config_init();
                        task_queue_init(true, (void (*)(struct retro_task *, const char *, unsigned int, unsigned int, bool)) main_msg_queue_push);
                        main_exit(NULL);
                        task_queue_deinit();
                    } @catch (NSException *e) {
                        WLOG(@"RetroArch: Exception during cleanup: %@", e);
                    }
                });
            }
            _isInitialized = false;
        }

		self.skipEmulationLoop = true;
		[self setupEmulation];
		[self setOptionValues];
		[self startVM:_renderView];
        [self setupControllers];
		[super startEmulation];
	};
}

- (void)setPauseEmulation:(BOOL)flag {
    [super setPauseEmulation:flag];

//    DLOG(@"RetroArchCoreBridge setPauseEmulation: %i", flag);
//    if (!EmulationState.shared.isOn) {
//        WLOG(@"Core isn't set to \"on\", skipping set pause : %i", flag);
//        return;
//    }
    command_event(flag ? CMD_EVENT_PAUSE : CMD_EVENT_UNPAUSE, NULL);
    // I don't know what this code was suppoed to do, but it breaks the retroarch menu
    // after pausing, seems fine to remove this. @JoeMatt
//    runloop_state_t *runloop_st = runloop_state_get_ptr();
//    if (flag) {
//        ILOG(@"RetroArch: Pause\n");
//        runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
//        runloop_st->flags &= ~RUNLOOP_FLAG_SLOWMOTION;
//        runloop_st->flags |= RUNLOOP_FLAG_PAUSED;
//        runloop_st->flags |= RUNLOOP_FLAG_IDLE;
//    } else {
//        ILOG(@"RetroArch: UnPause\n");
//        runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
//        runloop_st->flags &= ~RUNLOOP_FLAG_SLOWMOTION;
//        runloop_st->flags &= ~RUNLOOP_FLAG_PAUSED;
//        runloop_st->flags &= ~RUNLOOP_FLAG_IDLE;
//        [self setSpeed];
//    }
}

- (void)setSpeed {
    settings_t *settings = config_get_ptr();
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    apple_direct_input_keyboard_event(false, (int)RETROK_F14, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
    apple_direct_input_keyboard_event(false, (int)RETROK_F15, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
    runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
    runloop_st->flags &= ~RUNLOOP_FLAG_SLOWMOTION;
    runloop_st->flags &= ~RUNLOOP_FLAG_PAUSED;
    runloop_st->flags &= ~RUNLOOP_FLAG_IDLE;
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
//        settings_t *settings = config_get_ptr();
        float sm = self.smSpeed / 100.0;
        float ff = self.ffSpeed / 100.0;
        settings->floats.slowmotion_ratio  = sm;
        settings->floats.fastforward_ratio = ff;
        if (self.gameSpeed > 1) {
            ILOG(@"RetroArch:fast forward %f", ff);
            apple_direct_input_keyboard_event(true, (int)RETROK_F15, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
        } else if (self.gameSpeed < 1) {
            ILOG(@"RetroArch:slow motion %f", sm);
            apple_direct_input_keyboard_event(true, (int)RETROK_F14, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
        }
//    });
}

- (void)stopEmulation {
	[super stopEmulation];
	self.shouldStop = YES;
	if (iterate_observer) {
		CFRunLoopObserverInvalidate(iterate_observer);
		CFRelease(iterate_observer);
	}
	iterate_observer = NULL;
    retroarch_config_init();
	task_queue_init(true, (void (*)(struct retro_task *, const char *, unsigned int, unsigned int, bool)) main_msg_queue_push);
	main_exit(NULL);
    task_queue_deinit();
	_isInitialized = false;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.window != nil) {
        [self.window resignFirstResponder];
        [self.window removeFromSuperview];
        [self.window.rootViewController.view removeFromSuperview];
        self.window.rootViewController = nil;
        self.window = nil;
    }
    // [[[[UIApplication sharedApplication] delegate] window] makeKeyAndVisible];
}

- (void)setOptionValues {
    [PVRetroArchCoreBridge synchronizeOptionsWithRetroArch];
	g_gs_preference = self.gsPreference;
}

void extract_bundles();

- (void) writeConfigFile {

    [PVRetroArchCoreBridge synchronizeOptionsWithRetroArch];

    // Initialize file manager
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *fileName = [NSString stringWithFormat:@"%@/RetroArch/config/retroarch.cfg",
                          self.documentsDirectory];
    ILOG(@"Expecting config file to be at %@", fileName);

    // Get the version number from the app's Info.plist
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!appVersion) {
        appVersion = @"unknown";
    }
    ILOG(@"App version: %@", appVersion);

    NSString *verFile = [NSString stringWithFormat:@"%@/RetroArch/config/%@.cfg",
                         self.documentsDirectory, appVersion];
    ILOG(@"Expecting version file to be at %@", verFile);

    BOOL configFileExists = [fm fileExistsAtPath:fileName];
    ILOG(@"Config file exists: %@", configFileExists ? @"YES" : @"NO");

    BOOL versionFileExists = [fm fileExistsAtPath:verFile];
    ILOG(@"Version file exists: %@", versionFileExists ? @"YES" : @"NO");

    BOOL isFirstRunOrVersionUpdate = !configFileExists || !versionFileExists;

    BOOL shouldUpdateAssets = [self shouldUpdateAssets];
    ILOG(@"Should update assets: %@", shouldUpdateAssets ? @"YES" : @"NO");

#if TARGET_OS_TV
    BOOL shouldUpdateOverlays = false;
#else
    BOOL shouldUpdateOverlays = [self shouldUpdateOverlays];
#endif
    ILOG(@"Should update overlays: %@", shouldUpdateOverlays ? @"YES" : @"NO");


    if (isFirstRunOrVersionUpdate || shouldUpdateAssets) {

        NSString *src = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"retroarch.cfg" ofType:nil];

        if (!configFileExists) {
            ILOG(@"Writing config file to %@", fileName);
            [self syncResource:src to:fileName];
        }

        if (!versionFileExists) {
            ILOG(@"Writing config file to %@", verFile);
            [self syncResource:src to:verFile];
        }


        if(shouldUpdateAssets) {
            NSString *overlay_back = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"arrow.png" ofType:nil];
            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/flatui/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/monochrome/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/automatic/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/pixel/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/daite/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/dot-art/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/neoactive/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/retroactive/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/retrosystem/png/arrow.png", self.documentsDirectory]];

            [self syncResource:overlay_back to:[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/systematic/png/arrow.png", self.documentsDirectory]];
        }

        processing_init = true;
    }

    // Handle overlay updates
    if (shouldUpdateOverlays) {
        ILOG(@"Overlays need updating, starting download...");
        [self downloadAndExtractOverlays];
    }

    // Check if we need to trigger RetroArch updates (first run or version update)
    BOOL shouldTriggerUpdates = isFirstRunOrVersionUpdate;
    if (shouldTriggerUpdates) {
        ILOG(@"First run or version update detected - will trigger RetroArch resource updates after initialization");
        // Store flag to trigger updates after RetroArch is initialized
        self.shouldTriggerRetroArchUpdates = YES;
    }
    // Additional Override Settings
    NSString* content = @"video_driver = \"vulkan\"\n";
    if (self.gsPreference == 0) {
        content=@"video_driver = \"metal\"\n";
    } else if (self.gsPreference == 1) {
        content=@"video_driver = \"gl\"\n";
    } else if (self.gsPreference == 2) {
        content=@"video_driver = \"vulkan\"\n";
    }
    ILOG(@"Video driver set to: %@", content);

    /// Set video settings for Hatari to ensure correct color rendering
    /// Note: We don't set video_pixel_format here as cores should set it themselves via SET_PIXEL_FORMAT
    /// Setting it in config can conflict with cores that request different formats (e.g., geolith uses XRGB8888)
    if ([self.systemIdentifier containsString:@"atarist"] || [self.coreIdentifier containsString:@"hatari"]) {
        content = [content stringByAppendingString:@"video_scale_integer = \"true\"\n"];
        content = [content stringByAppendingString:@"video_smooth = \"false\"\n"];
        ILOG(@"Hatari video settings: integer scaling, no smoothing (pixel format set by core)");
    }

    /// Only sync bundled resources on first-run or version update
    /// These are copy-if-missing, but enumerating bundles is expensive; avoid doing it every launch.
    if (isFirstRunOrVersionUpdate) {
        [self syncResources:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"pv_ui_overlay" ofType:nil]
                         to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/overlays/pv_ui_overlay" ]];
        [self syncResources:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"mame_plugins" ofType:nil]
                         to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/system/mame/plugins" ]];
    }
    NSString *systemDirectory = [self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/system"];

    // SPIKE 2823: This byte-mutation is a temporary hack that only works with TOS 1.02 US.
    // It should be replaced with proper Hatari configuration once the root cause of the
    // crash (incorrect TOS path or TOS content validation) is determined.
    // See: https://github.com/Provenance-Emu/Provenance/issues/2823
    /// Ensure TOS image is properly synced for Hatari core (force update if corrupted)
    if ([self.systemIdentifier containsString:@"atarist"] || [self.coreIdentifier containsString:@"hatari"]) {
        NSString *tosImagePath = [systemDirectory stringByAppendingPathComponent:@"tos.img"];
        NSString *biosTosPath = [self.BIOSPath stringByAppendingPathComponent:@"tos.img"];

        if ([fm fileExistsAtPath:biosTosPath]) {
            /// Get file attributes to verify it's a valid TOS image
            NSDictionary *biosAttrs = [fm attributesOfItemAtPath:biosTosPath error:nil];
            NSNumber *biosSize = biosAttrs[NSFileSize];
            ILOG(@"TOS image in BIOS directory: %@, size: %@ bytes", biosTosPath, biosSize);

            /// Verify file is not a ZIP or other archive format
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:biosTosPath];
            if (fileHandle) {
                NSData *header = [fileHandle readDataOfLength:4];
                [fileHandle closeFile];

                if (header.length >= 2) {
                    const unsigned char *bytes = (const unsigned char *)header.bytes;
                    /// Check for ZIP signature (PK)
                    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
                        ELOG(@"ERROR: TOS image appears to be a ZIP file! The file must be extracted first. Expected raw ROM image, not ZIP archive.");
                    }
                    /// Check for common ROM signatures or validate it's binary data
                    else if (bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0x00 && bytes[3] == 0x00) {
                        WLOG(@"Warning: TOS image starts with all zeros - file may be empty or invalid");
                    }
                }
            }

            /// Expected TOS 1.02 US MD5: c1c57ce48e8ee4135885cee9e63a68a2
            /// Valid TOS image sizes are typically: 192KB (0x30000), 256KB (0x40000), 512KB (0x80000)
            BOOL shouldCopy = YES;
            if ([fm fileExistsAtPath:tosImagePath]) {
                NSDictionary *existingAttrs = [fm attributesOfItemAtPath:tosImagePath error:nil];
                NSNumber *existingSize = existingAttrs[NSFileSize];
                /// Always replace to ensure we have a fresh copy (file might be corrupted)
                ILOG(@"Replacing existing TOS image (existing: %@ bytes, BIOS: %@ bytes)", existingSize, biosSize);
                [fm removeItemAtPath:tosImagePath error:nil];
            }

            /// Always copy fresh from BIOS directory to ensure integrity
            /// Use NSData to copy to ensure binary integrity (not text mode)
            NSError *readError = nil;
            NSData *tosData = [NSData dataWithContentsOfFile:biosTosPath options:NSDataReadingMappedIfSafe error:&readError];
            if (readError || !tosData) {
                ELOG(@"Failed to read TOS image from %@: %@", biosTosPath, readError.localizedDescription);
            } else {
                /// Verify TOS version bytes at offset 2-3 (should be 0x01 0x02 for TOS 1.02)
                /// Hatari reads: TosVersion = SDL_SwapBE16(*(Uint16 *)&pTosFile[2]);
                /// SDL_SwapBE16 swaps FROM big-endian TO native (little-endian on iOS)
                /// So if file has [0x01, 0x02] (BE 0x0102), after swap it becomes 0x0201 = 513 = 0x201
                if (tosData.length >= 16) {
                    const unsigned char *bytes = (const unsigned char *)tosData.bytes;
                    ILOG(@"TOS image first 16 bytes: %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X",
                         bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                         bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);

                    /// Read version at offset 2-3 (big-endian)
                    uint16_t versionBE = (bytes[2] << 8) | bytes[3];
                    /// Simulate SDL_SwapBE16 on little-endian (swaps bytes)
                    uint16_t versionLE = (versionBE >> 8) | ((versionBE & 0xFF) << 8);

                    /// Read address at offset 8-11
                    /// When Hatari does: TosAddress = SDL_SwapBE32(*(Uint32 *)&pTosFile[8]);
                    /// On little-endian: bytes [0x00, 0xFC, 0x00, 0x00] read as Uint32 = 0x0000FC00 (LSB first)
                    /// SDL_SwapBE32 assumes input is big-endian and swaps to native (little-endian)
                    /// SDL_SwapBE32(0x0000FC00) treats it as BE 0x0000FC00 = bytes [0x00, 0x00, 0xFC, 0x00] in BE
                    /// Swaps to LE: [0x00, 0xFC, 0x00, 0x00] = 0x00FC0000
                    /// So: bytes [0x00, 0xFC, 0x00, 0x00] -> LE read 0x0000FC00 -> SDL_SwapBE32 -> 0x00FC0000 ✓
                    /// On little-endian system, bytes [0x00, 0xFC, 0x00, 0x00] read as Uint32 = 0x0000FC00
                    /// (LSB first: bytes[8]=0x00, bytes[9]=0xFC, bytes[10]=0x00, bytes[11]=0x00)
                    uint32_t addressAsLE = (bytes[8]) | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24);
                    /// SDL_SwapBE32 treats input as big-endian and swaps to little-endian
                    /// For 0x0000FC00 (BE): bytes are [0x00, 0x00, 0xFC, 0x00] in BE
                    /// Swap to LE: [0x00, 0xFC, 0x00, 0x00] = 0x00FC0000
                    /// Extract bytes and swap: byte0->byte3, byte1->byte2, byte2->byte1, byte3->byte0
                    uint32_t byte0 = (addressAsLE >> 0) & 0xFF;
                    uint32_t byte1 = (addressAsLE >> 8) & 0xFF;
                    uint32_t byte2 = (addressAsLE >> 16) & 0xFF;
                    uint32_t byte3 = (addressAsLE >> 24) & 0xFF;
                    uint32_t addressAfterSwap = (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | byte3;

                    ILOG(@"TOS version: bytes[2-3] = [0x%02X, 0x%02X], BE=0x%04X, after SDL_SwapBE16=0x%04X (%u decimal)",
                         bytes[2], bytes[3], versionBE, versionLE, versionLE);
                    ILOG(@"TOS address: bytes[8-11] = [0x%02X, 0x%02X, 0x%02X, 0x%02X], read as LE Uint32=0x%08X, after SDL_SwapBE32=0x%08X",
                         bytes[8], bytes[9], bytes[10], bytes[11], addressAsLE, addressAfterSwap);

                    /// TOS 1.02 should have version bytes [0x01, 0x02] = BE 0x0102 -> LE 0x0201 = 513 = 0x201
                    /// Address should be 0x00FC0000 (for TOS < 1.06) or 0x00E00000 (for TOS >= 1.06) after SDL_SwapBE32
                    BOOL versionOK = (versionBE == 0x0102);
                    BOOL addressOK = (addressAfterSwap == 0x00FC0000 || addressAfterSwap == 0x00E00000);

                    if (versionOK && addressOK) {
                        ILOG(@"TOS image validation PASSED: version 1.02, address 0x%08X", addressAfterSwap);
                    } else {
                        if (!versionOK) {
                            ELOG(@"TOS version validation FAILED: expected [0x01, 0x02] (BE 0x0102 -> LE 0x0201), got [0x%02X, 0x%02X] (BE 0x%04X -> LE 0x%04X)",
                                 bytes[2], bytes[3], versionBE, versionLE);
                        }
                        if (!addressOK) {
                            ELOG(@"TOS address validation FAILED: expected 0x00FC0000 or 0x00E00000 after SDL_SwapBE32, got 0x%08X", addressAfterSwap);
                        }
                    }
                }

                /// Always ensure address bytes are correct for Hatari
                /// Hatari reads: TosAddress = SDL_SwapBE32(*(Uint32 *)&pTosFile[8]);
                /// Hatari expects TosAddress to be 0x00FC0000 or 0x00E00000 AFTER SDL_SwapBE32
                ///
                /// The issue: Hatari reports $fc00 (0x0000FC00) which is the value BEFORE swap
                /// This suggests the bytes might need to be in a different order
                ///
                /// If file has [0x00, 0x00, 0xFC, 0x00]: LE read = 0x00FC0000, SDL_SwapBE32 = 0x0000FC00 (wrong)
                /// If file has [0xFC, 0x00, 0x00, 0x00]: LE read = 0x000000FC, SDL_SwapBE32 = 0xFC000000 (wrong)
                /// If file has [0x00, 0xFC, 0x00, 0x00]: LE read = 0x0000FC00, SDL_SwapBE32 = 0x00FC0000 (correct!)
                ///
                /// But Hatari reports $fc00, so maybe it's NOT swapping? Or reading differently?
                /// Let's try the big-endian byte order directly: [0x00, 0x00, 0xFC, 0x00] = BE 0x0000FC00
                /// If Hatari reads this as BE directly (without swap), it would get 0x0000FC00
                /// But the code clearly does SDL_SwapBE32, so this shouldn't work...
                ///
                /// Actually, wait - maybe the file needs bytes that when read as LE give 0x00FC0000 directly?
                /// That would be [0x00, 0x00, 0xFC, 0x00] in the file
                /// But then SDL_SwapBE32 would swap it to 0x0000FC00, which is wrong
                ///
                /// Let's try: if Hatari is reporting the pre-swap value, maybe we need bytes that read as 0x00FC0000
                /// File bytes: [0x00, 0x00, 0xFC, 0x00] -> LE read = 0x00FC0000
                /// But SDL_SwapBE32(0x00FC0000) = 0x0000FC00, which Hatari reports as wrong
                ///
                /// Hmm, let's just try the reverse order: [0x00, 0x00, 0xFC, 0x00]
                NSMutableData *fixedTosData = [tosData mutableCopy];
                if (tosData.length >= 12) {
                    const unsigned char *bytes = (const unsigned char *)tosData.bytes;
                    /// Current bytes are [0x00, 0xFC, 0x00, 0x00] which should work but doesn't
                    /// Try reverse order: [0x00, 0x00, 0xFC, 0x00]
                    /// This gives: LE read = 0x00FC0000, SDL_SwapBE32 = 0x0000FC00
                    /// But Hatari wants 0x00FC0000, so maybe it's NOT swapping?
                    /// Let's try setting bytes to give 0x00FC0000 when read as LE (no swap needed)
                    unsigned char *fixedBytes = (unsigned char *)fixedTosData.mutableBytes;
                    fixedBytes[8] = 0x00;
                    fixedBytes[9] = 0x00;
                    fixedBytes[10] = 0xFC;
                    fixedBytes[11] = 0x00;
                    ILOG(@"TOS address bytes set to [0x%02X, 0x%02X, 0x%02X, 0x%02X] (was [0x%02X, 0x%02X, 0x%02X, 0x%02X]) - testing if Hatari reads without swap",
                         fixedBytes[8], fixedBytes[9], fixedBytes[10], fixedBytes[11],
                         bytes[8], bytes[9], bytes[10], bytes[11]);
                }

                /// Write using NSData to ensure binary integrity
                NSError *writeError = nil;
                BOOL writeSuccess = [fixedTosData writeToFile:tosImagePath options:NSDataWritingAtomic error:&writeError];
                if (writeError || !writeSuccess) {
                    ELOG(@"Failed to write TOS image to %@: %@", tosImagePath, writeError.localizedDescription);
                } else {
                    NSDictionary *copiedAttrs = [fm attributesOfItemAtPath:tosImagePath error:nil];
                    NSNumber *copiedSize = copiedAttrs[NSFileSize];
                    ILOG(@"Successfully synced TOS image to RetroArch system directory: %@ (size: %@ bytes)", tosImagePath, copiedSize);

                    /// Verify file size matches expected TOS sizes
                    unsigned long long sizeBytes = copiedSize.unsignedLongLongValue;
                    if (sizeBytes != 192*1024 && sizeBytes != 256*1024 && sizeBytes != 512*1024) {
                        WLOG(@"Warning: TOS image size (%llu bytes) doesn't match typical TOS sizes (192KB, 256KB, or 512KB). File may be invalid.", sizeBytes);
                    }

                    /// Verify the copied file matches source
                    NSData *verifyData = [NSData dataWithContentsOfFile:tosImagePath];
                    if (!verifyData || verifyData.length != tosData.length) {
                        ELOG(@"ERROR: Copied TOS image size mismatch! Source: %lu bytes, Copied: %lu bytes", (unsigned long)tosData.length, (unsigned long)verifyData.length);
                    } else if (![verifyData isEqualToData:tosData]) {
                        ELOG(@"ERROR: Copied TOS image data doesn't match source! File may be corrupted.");
                    } else {
                        ILOG(@"TOS image copy verified - data integrity confirmed");
                    }
                }
            }
        } else {
            ELOG(@"TOS image not found in BIOS directory: %@", biosTosPath);
        }
    }

    /// Update hatari.cfg with dynamic paths (must be updated each time as app dir can change on iOS)
    /// Only relevant for Hatari/AtariST; do not copy/sync for every other system.
    if ([self.systemIdentifier containsString:@"atarist"] || [self.coreIdentifier containsString:@"hatari"]) {
        NSString *hatariCfgPath = [systemDirectory stringByAppendingPathComponent:@"hatari.cfg"];
        NSString *hatariCfgSource = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"hatari.cfg" ofType:nil];
        if (hatariCfgSource) {
            NSString *hatariCfgContent = [NSString stringWithContentsOfFile:hatariCfgSource encoding:NSUTF8StringEncoding error:nil];
            if (hatariCfgContent) {
                /// Update TOS image path with full absolute path
                NSString *tosImagePath = [systemDirectory stringByAppendingPathComponent:@"tos.img"];
                hatariCfgContent = [hatariCfgContent stringByReplacingOccurrencesOfString:@"szTosImageFileName = tos.img"
                                                                               withString:[NSString stringWithFormat:@"szTosImageFileName = %@", tosImagePath]];

                /// Update disk image directory - expand tilde and use full path
                NSString *romsDirectory = [self.documentsDirectory stringByAppendingPathComponent:@"ROMs"];
                if (self.systemIdentifier) {
                    romsDirectory = [romsDirectory stringByAppendingPathComponent:self.systemIdentifier];
                }
                /// Replace tilde path with full absolute path
                hatariCfgContent = [hatariCfgContent stringByReplacingOccurrencesOfString:@"szDiskImageDirectory = ~/Documents/ROMs/com.provenance.atarist/"
                                                                               withString:[NSString stringWithFormat:@"szDiskImageDirectory = %@/", romsDirectory]];
                /// Also handle case where system identifier might be different
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"szDiskImageDirectory = ~/Documents/ROMs/[^\\n]+"
                                                                                        options:0 error:nil];
                hatariCfgContent = [regex stringByReplacingMatchesInString:hatariCfgContent
                                                                   options:0
                                                                     range:NSMakeRange(0, hatariCfgContent.length)
                                                              withTemplate:[NSString stringWithFormat:@"szDiskImageDirectory = %@/", romsDirectory]];

                [hatariCfgContent writeToFile:hatariCfgPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
                ILOG(@"Updated hatari.cfg with TOS path: %@ and ROMs directory: %@", tosImagePath, romsDirectory);
            } else {
                /// Fallback to standard sync if we can't read the source
                [self syncResource:hatariCfgSource to:hatariCfgPath];
            }
        }
    }

    /// Set system directory in RetroArch config (required for Hatari to find TOS image)
    content = [content stringByAppendingString:
               [NSString stringWithFormat:@"system_directory = \"%@\"\n", systemDirectory]];
    ILOG(@"System directory set to: %@", systemDirectory);

    if (!self.retroArchControls) {
        content = [content stringByAppendingString:
                       @"input_overlay_enable = \"false\"\n"
        ];
        ILOG(@"Input overlay disabled.");
    }
    if (self.coreOptionConfigPath.length > 0 && self.coreOptionConfig.length > 0) {
        fileName = [NSString stringWithFormat:@"%@/RetroArch/config/%@", self.documentsDirectory, self.coreOptionConfigPath];
        if (![fm fileExistsAtPath: fileName] || self.coreOptionOverwrite) {
            [fm createDirectoryAtPath:[fileName stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
            [self.coreOptionConfig writeToFile:fileName
                                    atomically:NO
                                    encoding:NSStringEncodingConversionAllowLossy
                                        error:nil];
            ILOG(@"Core option config written to %@", fileName);
        }
    } else if (self.coreOptionConfig.length > 0) {
        content=[content stringByAppendingString:self.coreOptionConfig];
    }
    content = [content stringByAppendingString:
               [NSString stringWithFormat:@"cache_directory = \"%@\"\n", self.batterySavesPath]];
    ILOG(@"Cache directory set to: %@", self.batterySavesPath);
    fileName = [NSString stringWithFormat:@"%@/RetroArch/config/opt.cfg", self.documentsDirectory];
    ILOG(@"Writing options config to %@", fileName);
    NSError *error;
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:&error];
    if (error) {
        ELOG(@"Error writing options config to %@: %@", fileName, error.localizedDescription);
    } else {
        ILOG(@"Options config written to %@", fileName);
    }
}

- (bool)shouldUpdateAssets {
// #if DEBUG
//     return true;
// #else
    // If assets were updated, refresh config
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *file=[NSString stringWithFormat:@"%@/RetroArch/assets/xmb/flatui/png/arrow.png", self.documentsDirectory];
    ILOG(@"Checking if assets exist at %@", file);

    if ([fm fileExistsAtPath:file]) {
        unsigned long long fileSize = [[fm attributesOfItemAtPath:file error:nil] fileSize];
        ILOG(@"File size: %llu", fileSize);

        /// Any non-empty asset means we already synced this version; skip
        if (fileSize > 0) {
            ILOG(@"Assets present; no update needed");
            return false;
        }
    }

    ILOG(@"File missing or empty, update assets");
    return true;
// #endif
}

- (bool)shouldUpdateOverlays {
    /// Check if overlays need to be downloaded by looking for the COPYING file
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *copyingFile = [NSString stringWithFormat:@"%@/RetroArch/overlays/COPYING", self.documentsDirectory];
    ILOG(@"Checking if overlays COPYING file exists at %@", copyingFile);

    if ([fm fileExistsAtPath:copyingFile]) {
        ILOG(@"Overlays COPYING file exists, no update needed");
        return false;
    }

    ILOG(@"Overlays COPYING file does not exist, update needed");
    return true;
}

- (void)downloadAndExtractOverlays {
    /// Download and extract overlays from libretro buildbot
    NSString *overlayURL = @"https://buildbot.libretro.com/assets/frontend/overlays.zip";
    NSString *overlaysDestination = [NSString stringWithFormat:@"%@/RetroArch/overlays", self.documentsDirectory];

    ILOG(@"Starting overlay download from %@", overlayURL);

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 300.0; // 5 minutes for large file

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURL *url = [NSURL URLWithString:overlayURL];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL *tempLocation, NSURLResponse *response, NSError *error) {

        if (error) {
            ELOG(@"Error downloading overlays: %@", error.localizedDescription);
            return;
        }

        if (!tempLocation) {
            ELOG(@"No temporary file location for downloaded overlays");
            return;
        }

        ILOG(@"Overlays downloaded successfully to temporary location: %@", tempLocation.path);

        dispatch_async(dispatch_get_main_queue(), ^{
            NSFileManager *fm = [[NSFileManager alloc] init];

            // Create overlays directory if it doesn't exist
            NSError *dirError;
            if (![fm fileExistsAtPath:overlaysDestination]) {
                [fm createDirectoryAtPath:overlaysDestination withIntermediateDirectories:YES attributes:nil error:&dirError];
                if (dirError) {
                    ELOG(@"Error creating overlays directory: %@", dirError.localizedDescription);
                    return;
                }
                ILOG(@"Created overlays directory at %@", overlaysDestination);
            }

            // Extract the downloaded zip file
            BOOL extractSuccess = [self extractZIP:tempLocation.path toDestination:overlaysDestination overwrite:YES];

            if (extractSuccess) {
                ILOG(@"Overlays extracted successfully to %@", overlaysDestination);

                // Verify the COPYING file exists after extraction
                NSString *copyingFile = [NSString stringWithFormat:@"%@/COPYING", overlaysDestination];
                if ([fm fileExistsAtPath:copyingFile]) {
                    ILOG(@"Overlay installation verified - COPYING file found");
                } else {
                    WLOG(@"Warning: COPYING file not found after extraction");
                }
            } else {
                ELOG(@"Failed to extract overlays zip file");
            }

            // Clean up temporary file
            NSError *removeError;
            [fm removeItemAtURL:tempLocation error:&removeError];
            if (removeError) {
                WLOG(@"Warning: Could not remove temporary file: %@", removeError.localizedDescription);
            }
        });
    }];

    [downloadTask resume];
}
#pragma mark - Running

- (void)setVolume {
    [self parseOptions];
    settings_t *settings = config_get_ptr();
    settings->floats.audio_mixer_volume = 92.0 * self.volume/92.0 - 80;
    command_event_set_mixer_volume(settings, 0);
}

- (void)syncResources:(NSString*)from to:(NSString*)to {
	if (!from) {
        ELOG(@"From path is nil");
        return;
    }
	NSError *error;
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSArray* files = [fm contentsOfDirectoryAtPath:from error:&error];
    if (![fm fileExistsAtPath: to]) {
        [fm createDirectoryAtPath:to withIntermediateDirectories:true attributes:nil error:&error];
        if (error) {
            ELOG(@"Error creating directory at %@: %@", to, error.localizedDescription);
        } else {
            ILOG(@"Created directory at %@", to);
        }
    }
	for (NSString *file in files) {
		NSString *src=  [NSString stringWithFormat:@"%@/%@", from, file];
		NSString *dst = [NSString stringWithFormat:@"%@/%@", to, file];
		if (![fm fileExistsAtPath: dst]) {
            NSError *error;
			[fm copyItemAtPath:src toPath:dst error:&error];
            if (error) {
                ELOG(@"Error copying %@ to %@: %@", src, dst, error.localizedDescription);
            } else {
                ILOG(@"Copied %@ -> %@", src, dst);
            }
		}
	}
}

- (void)syncResource:(NSString*)from to:(NSString*)to {
    if (!from) {
        ELOG(@"From path is nil");
        return;
    }
    NSFileManager *fm = [[NSFileManager alloc] init];

    NSString *destDir = [to stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:destDir]) {
        NSError *dirError = nil;
        [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:&dirError];
        if (dirError) {
            ELOG(@"Error creating directory %@: %@", destDir, dirError.localizedDescription);
            return;
        }
    }

    if ([fm fileExistsAtPath:to]) {
        return;
    }

    NSData *fileData = [NSData dataWithContentsOfFile:from];
    if (!fileData) {
        ELOG(@"Failed to read data from %@", from);
        return;
    }

    NSError *writeError = nil;
    BOOL ok = [fileData writeToFile:to options:NSDataWritingAtomic error:&writeError];
    if (!ok || writeError) {
        ELOG(@"Error writing file to %@: %@", to, writeError.localizedDescription);
    } else {
        ILOG(@"Copied %@ -> %@", from, to);
    }
}

- (void)setViewType:(apple_view_type_t)vt
{
    if (vt == _vt)
        return;

    _vt = vt;
    if (_renderView != nil)
    {
        [_renderView removeFromSuperview];
        _renderView = nil;
    }

    switch (vt)
    {
#ifdef HAVE_COCOA_METAL
        case APPLE_VIEW_TYPE_VULKAN: {
            self.gsPreference = 2;
            MetalView *v = [MetalView new];
            v.paused                = YES;
            v.enableSetNeedsDisplay = NO;
#if TARGET_OS_IOS
            v.multipleTouchEnabled  = YES;
#endif
            _renderView = v;
        }
            break;
        case APPLE_VIEW_TYPE_METAL: {
            self.gsPreference = 0;
            MetalView *v = [MetalView new];
            v.paused                = YES;
            v.enableSetNeedsDisplay = NO;
#if TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH && !TARGET_OS_OSX
            v.multipleTouchEnabled  = YES;
#endif
            if (!self.isRootView) {
                v.frame = [[UIScreen mainScreen] bounds];
                [v setDrawableSize:v.frame.size];
            }
            v.autoresizesSubviews=true;
            v.autoResizeDrawable=true;
            v.contentMode=UIViewContentModeScaleToFill;
            _renderView = v;
        }
            break;
#endif
        case APPLE_VIEW_TYPE_OPENGL_ES:
            self.gsPreference = 1;
            glkitview_init();
            _renderView = glk_view;
            break;
        case APPLE_VIEW_TYPE_NONE:
        default:
            return;
    }

    UIView *rootView = [CocoaView get].view;
    [rootView addSubview:_renderView];

//    _renderView.backgroundColor = [UIColor greenColor];
//    rootView.backgroundColor = [UIColor redColor];

    _renderView.translatesAutoresizingMaskIntoConstraints = NO;

    // Apply custom layout if it was requested before _renderView was created
    if (self.useCustomRenderViewLayout) {
        DLOG(@"[RA] Applying custom layout in setViewType (view was created)");
        // Re-apply custom layout setup now that _renderView exists
        [self setUseCustomRenderViewLayout:YES];
    } else {
        DLOG(@"[RA] Default: pin to full-screen");
#if TARGET_OS_TV
        /// tvOS: Center within superview (the actual container) to avoid rootView offset issues
        UIView *containerView = rootView.superview ?: rootView;
        [[_renderView.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor] setActive:YES];
        [[_renderView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor] setActive:YES];
        [[_renderView.widthAnchor constraintEqualToAnchor:containerView.widthAnchor] setActive:YES];
        [[_renderView.heightAnchor constraintEqualToAnchor:containerView.heightAnchor] setActive:YES];
#else
        /// iOS: Use safe area to respect notch/dynamic island
        [[_renderView.topAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.topAnchor] setActive:YES];
        [[_renderView.bottomAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.bottomAnchor] setActive:YES];
        [[_renderView.leadingAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.leadingAnchor] setActive:YES];
        [[_renderView.trailingAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.trailingAnchor] setActive:YES];
#endif
    }
}

//
// Custom Viewport Positioning methods
- (void)applyRenderViewFrameInTouchView:(CGRect)frame {
    if (!_renderView) {
        WLOG(@"_renderView nil, exiting.");
        return;
    }

    /// Get MTKView where container will be positioned
    UIView *rootView = [CocoaView get].view;
    if (!rootView) {
        WLOG(@"[RA] CocoaView root view nil");
        return;
    }
    UIView *mtkView = rootView.superview;
    if (!mtkView) {
        WLOG(@"[RA] No MTKView superview");
        return;
    }

    /// Frame is already in MTKView coordinates (converted in Swift)
    /// Just validate and clamp to bounds
    CGRect mtkBounds = mtkView.bounds;

    /// Ensure MTKView has valid bounds
    if (mtkBounds.size.width <= 0 || mtkBounds.size.height <= 0) {
        WLOG(@"[RA] MTKView bounds invalid: %@, forcing layout", NSStringFromCGRect(mtkBounds));
        [mtkView setNeedsLayout];
        [mtkView layoutIfNeeded];
        mtkBounds = mtkView.bounds;
    }

    /// Validate input frame
    if (frame.size.width <= 0 || frame.size.height <= 0 ||
        isnan(frame.size.width) || isnan(frame.size.height)) {
        WLOG(@"[RA] Invalid input frame: %@", NSStringFromCGRect(frame));
        return;
    }

    /// Clamp to bounds
    CGRect clamped = frame;
    clamped.origin.x = MAX(0, MIN(clamped.origin.x, mtkBounds.size.width - clamped.size.width));
    clamped.origin.y = MAX(0, MIN(clamped.origin.y, mtkBounds.size.height - clamped.size.height));
    clamped.size.width = MIN(clamped.size.width, mtkBounds.size.width);
    clamped.size.height = MIN(clamped.size.height, mtkBounds.size.height);

    /// Pixel-align
    CGFloat scale = UIScreen.mainScreen.scale;
    CGRect aligned = CGRectMake(
        floor(clamped.origin.x * scale) / scale,
        floor(clamped.origin.y * scale) / scale,
        floor(clamped.size.width * scale) / scale,
        floor(clamped.size.height * scale) / scale
    );

    ILOG(@"[RA] Frame: %@ -> %@ (mtkBounds=%@)", NSStringFromCGRect(frame), NSStringFromCGRect(aligned), NSStringFromCGRect(mtkBounds));

    /// Get or create container view
    UIView *containerView = [self _ensureRenderContainerInMTKView:mtkView];

    /// Remove all existing constraints - start fresh
    NSMutableArray<NSLayoutConstraint *> *toRemove = [NSMutableArray array];
    for (NSLayoutConstraint *c in mtkView.constraints) {
        if (c.firstItem == containerView || c.secondItem == containerView) [toRemove addObject:c];
    }
    for (NSLayoutConstraint *c in containerView.constraints) {
        [toRemove addObject:c];
    }
    for (NSLayoutConstraint *c in _renderView.constraints) {
        [toRemove addObject:c];
    }
    [NSLayoutConstraint deactivateConstraints:toRemove];

    /// Setup container: frame-based layout, positioned at converted frame
    containerView.translatesAutoresizingMaskIntoConstraints = YES;
    containerView.autoresizingMask = UIViewAutoresizingNone;
    containerView.clipsToBounds = YES;
    containerView.hidden = NO;
    containerView.alpha = 1.0;
    containerView.userInteractionEnabled = NO;
    containerView.frame = aligned;
    [mtkView bringSubviewToFront:containerView];

#if HAVE_IOS_SWIFT
    CocoaView *cocoaView = [CocoaView get];
    if (cocoaView && cocoaView.helperBarView && cocoaView.helperBarView.superview) {
        cocoaView.helperBarView.layer.zPosition = 1000;
        [cocoaView.helperBarView.superview bringSubviewToFront:cocoaView.helperBarView];
    }
#endif

    /// Setup render view: simple constraints to fill container (always centered, always fills)
    if (_renderView.superview != containerView) {
        [_renderView removeFromSuperview];
        [containerView addSubview:_renderView];
    }
    _renderView.translatesAutoresizingMaskIntoConstraints = NO;
    _renderView.clipsToBounds = YES;

    /// Use simple, consistent constraints: center and fill container
    [NSLayoutConstraint activateConstraints:@[
        [_renderView.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
        [_renderView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
        [_renderView.widthAnchor constraintEqualToAnchor:containerView.widthAnchor],
        [_renderView.heightAnchor constraintEqualToAnchor:containerView.heightAnchor]
    ]];

    /// Update Metal layer size to match container
    CGSize pixelSize = CGSizeMake(aligned.size.width * scale, aligned.size.height * scale);
    _renderView.contentScaleFactor = scale;

    if ([_renderView respondsToSelector:@selector(setDrawableSize:)]) {
        [(id)_renderView setDrawableSize:pixelSize];
    }
    if ([_renderView.layer isKindOfClass:[CAMetalLayer class]]) {
        CAMetalLayer *ml = (CAMetalLayer *)_renderView.layer;
        ml.contentsScale = scale;
        ml.drawableSize = pixelSize;
    }

    /// Update RetroArch viewport to match container size
    settings_t *settings = config_get_ptr();
    if (settings) {
        settings->bools.video_scale_integer = PVSettingsWrapper.integerScaleEnabled; // This could come from PVSettigns?
        settings->bools.video_force_aspect = false;
        settings->uints.video_aspect_ratio_idx = ASPECT_RATIO_CORE;
        command_event(CMD_EVENT_VIDEO_SET_ASPECT_RATIO, NULL);

        unsigned int w = (unsigned)lrintf(pixelSize.width);
        unsigned int h = (unsigned)lrintf(pixelSize.height);
        video_driver_set_size(w, h);

        settings->video_vp_custom.x = 0;
        settings->video_vp_custom.y = 0;
        settings->video_vp_custom.width = w;
        settings->video_vp_custom.height = h;

        struct video_viewport vp = {0, 0, w, h, w, h};
        video_driver_update_viewport(&vp, true, false);
        command_event(CMD_EVENT_VIDEO_SET_ASPECT_RATIO, NULL);

        ILOG(@"[RA] Viewport: %ux%u pixels", w, h);
    }

    /// Force immediate layout
    [containerView setNeedsLayout];
    [containerView layoutIfNeeded];

    ILOG(@"[RA] Applied: container.frame=%@, renderView.frame=%@",
         NSStringFromCGRect(containerView.frame), NSStringFromCGRect(_renderView.frame));
}

- (void)setupView {
    printf("Set:SetupView %d", self.gsPreference);
	if(self.gsPreference == 0) {
		[self setViewType:APPLE_VIEW_TYPE_METAL];
	} else if(self.gsPreference == 1) {
		[self setViewType:APPLE_VIEW_TYPE_OPENGL_ES];
	} else if(self.gsPreference == 2) {
		[self setViewType:APPLE_VIEW_TYPE_VULKAN];
    } else {
        [self setViewType:APPLE_VIEW_TYPE_METAL];
    }
}

- (void)startVM:(UIView *)view {
	apple_platform     = self;
    ILOG(@"Starting VM\n");
	NSString *optConfig = [NSString stringWithFormat:@"%@/../../RetroArch/config/opt.cfg",
						  self.batterySavesPath];
    NSFileManager *fm = [[NSFileManager alloc] init];
	if(!self.coreIdentifier || [[self coreIdentifier] isEqualToString:@"com.provenance.core.retroarch"] || !romPath) {
        if (romPath != nil && romPath.length > 0 && [fm fileExistsAtPath: romPath]) {
            optConfig = romPath;
        }
		char *param[] = {
            "retroarch",
            CORE_TYPE_PLAIN,
            "--appendconfig",
            optConfig.UTF8String,
            NULL};
        argc = 4;
		argv = param;
        ILOG(@"Loading %s\n", param[0]);
	} else {
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *mainBundlePath = mainBundle.bundlePath;

        NSString *coreIdentifier = [self coreIdentifier];
        NSString *coreBinary = [coreIdentifier stringByDeletingPathExtension];
        NSString *resourceName = [NSString stringWithFormat:@"%@", coreIdentifier];
        NSString *resourcePath = [NSString stringWithFormat:@"Frameworks/%@", resourceName];
        NSString *sysPath = [NSString stringWithFormat:@"%@/%@", mainBundlePath, resourcePath];

        /// Check if the module is found at the expected path
        if ([fm fileExistsAtPath: sysPath]) {
            ILOG(@"Found Module %@\n", sysPath);
        } else {
            ELOG(@"Error: No module found at %@\n", sysPath);
        }

        /// Check if the ROM is found at the expected path
		if ([fm fileExistsAtPath: romPath]) {
            romPath=[self checkROM:romPath];
			WLOG(@"Found Game %s\n", romPath.UTF8String);
        } else {
            ELOG(@"No game found at path: %@", romPath);
        }

		// Core Identifier is the dylib file name
        char *param[] = { "retroarch",
            "-L", sysPath.stringByStandardizingPath.UTF8String, romPath.stringByStandardizingPath.UTF8String,
            "--appendconfig", optConfig.UTF8String,
            "--verbose", NULL };
		argc=7;
		argv=param;
        ILOG(@"Loading %s %s\n", param[2], param[3]);
	}
    if (processing_init) {
        dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [self extractArchive:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"assets.zip" ofType:nil] toDestination:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch"] overwrite:true];
        });
        processing_init=false;
    }
//	NSError *error;
//    [[AVAudioSession sharedInstance]
//     setCategory:AVAudioSessionCategoryAmbient
//     mode:AVAudioSessionModeDefault
//     options:AVAudioSessionCategoryOptionAllowBluetooth |
//     AVAudioSessionCategoryOptionAllowAirPlay |
//     AVAudioSessionCategoryOptionAllowBluetoothA2DP |
//     AVAudioSessionCategoryOptionMixWithOthers
//     error:&error];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];

	[self refreshSystemConfig];
	[self showGameView];
	rarch_main(argc, argv, NULL);
	_isInitialized=true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        runloop_state_t *runloop_st = runloop_state_get_ptr();
        runloop_st->flags &= ~RUNLOOP_FLAG_OVERRIDES_ACTIVE;
    });
	iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting, true, 0, rarch_draw_observer, 0);
	CFRunLoopAddObserver(CFRunLoopGetMain(), iterate_observer, kCFRunLoopCommonModes);
	apple_gamecontroller_joypad_init(NULL);
    [self setupJoypad];
}

- (void)setupJoypad {
    ILOG(@"Analog Dpad %d", self.bindAnalogDpad);
    if (self.bindAnalogDpad) {
        settings_t *settings = config_get_ptr();
        settings->uints.input_analog_dpad_mode[0]=ANALOG_DPAD_LSTICK_FORCED;
    } else {
        settings_t *settings = config_get_ptr();
        settings->uints.input_analog_dpad_mode[0]=ANALOG_DPAD_NONE;
    }
}

- (void)setupWindow {
    ILOG(@"Set:METAL VULKAN OPENGLES:Attaching View Controller. isRootView %@\n", self.isRootView ? @"Yes" : @"No");
    // Ensure UI work is performed on main thread
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupWindow];
        });
        return;
    }
    if (m_view) {
        [m_view removeFromSuperview];
        m_view=nil;
    }
    if (m_view_controller) {
        [m_view_controller dismissViewControllerAnimated:NO completion:nil];
        m_view_controller=nil;
    }
    if (self.isRootView) {
        self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        [self.window makeKeyAndVisible];
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        m_view=[CocoaView get].view;
        self.view=m_view;
        UIWindow *originalWindow=[UIApplication sharedApplication].keyWindow;
        self->backup_view_controller=originalWindow.rootViewController;
        UIViewController *rootController = [CocoaView get];
        // Detach from any previous parent before making it a window root
        if (rootController.parentViewController) {
            [rootController willMoveToParentViewController:nil];
            [rootController.view removeFromSuperview];
            [rootController removeFromParentViewController];
        }
        [self.window setRootViewController:rootController];
        self.window.userInteractionEnabled=true;
        [rootController.view setHidden:false];
        rootController.view.translatesAutoresizingMaskIntoConstraints = false;
        rootController.view.contentMode = UIViewContentModeScaleToFill;
        [[rootController.view.topAnchor constraintEqualToAnchor:self.window.topAnchor] setActive:YES];
        [[rootController.view.bottomAnchor constraintEqualToAnchor:self.window.bottomAnchor] setActive:YES];
        [[rootController.view.leadingAnchor constraintEqualToAnchor:self.window.leadingAnchor] setActive:YES];
        [[rootController.view.trailingAnchor constraintEqualToAnchor:self.window.trailingAnchor] setActive:YES];
    } else {
        UIViewController *gl_view_controller = self.renderDelegate;
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        m_view_controller=[CocoaView get];
        m_view=m_view_controller.view;
        self.view=m_view;
        UIViewController *rootController = [CocoaView get];
        if (self.touchViewController) {
            // If CocoaView is already attached to a different parent, detach first
            if (rootController.parentViewController && rootController.parentViewController != self.touchViewController) {
                [rootController willMoveToParentViewController:nil];
                [rootController.view removeFromSuperview];
                [rootController removeFromParentViewController];
            }
            [self.touchViewController.view addSubview:self.view];
            [self.touchViewController addChildViewController:rootController];
            [rootController didMoveToParentViewController:self.touchViewController];
            [self.touchViewController.view sendSubviewToBack:self.view];
            [rootController.view setHidden:false];
            if (IS_IPHONE()) {
                rootController.view.translatesAutoresizingMaskIntoConstraints = YES;
                rootController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                rootController.view.frame = self.touchViewController.view.bounds;
            } else {
                rootController.view.translatesAutoresizingMaskIntoConstraints = false;
                [[rootController.view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
                [[rootController.view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
                [[rootController.view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
                [[rootController.view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
            }
            self.touchViewController.view.userInteractionEnabled=true;
            self.touchViewController.view.autoresizesSubviews=true;
            self.touchViewController.view.userInteractionEnabled=true;
#if !TARGET_OS_TV
            self.touchViewController.view.multipleTouchEnabled=true;
#endif
        } else {
            // If CocoaView is already attached to a different parent, detach first
            if (rootController.parentViewController && rootController.parentViewController != gl_view_controller) {
                [rootController willMoveToParentViewController:nil];
                [rootController.view removeFromSuperview];
                [rootController removeFromParentViewController];
            }
            [gl_view_controller.view addSubview:self.view];
            [gl_view_controller addChildViewController:rootController];
            [rootController didMoveToParentViewController:gl_view_controller];
            [rootController.view setHidden:false];
            if (IS_IPHONE()) {
                rootController.view.translatesAutoresizingMaskIntoConstraints = YES;
                rootController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                rootController.view.frame = gl_view_controller.view.bounds;
            } else {
                rootController.view.translatesAutoresizingMaskIntoConstraints = false;
                [[rootController.view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor] setActive:YES];
                [[rootController.view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor] setActive:YES];
                [[rootController.view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor] setActive:YES];
                [[rootController.view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor] setActive:YES];
            }
            gl_view_controller.view.userInteractionEnabled=true;
            gl_view_controller.view.autoresizesSubviews=true;
            gl_view_controller.view.userInteractionEnabled=true;
#if !TARGET_OS_TV
            gl_view_controller.view.multipleTouchEnabled=true;
#endif
        }
        self.view.userInteractionEnabled=true;
#if !TARGET_OS_TV
        self.view.multipleTouchEnabled=true;
#endif
        self.view.autoresizesSubviews=true;
        self.view.contentMode=UIViewContentModeScaleToFill;
    }
}

- (void)showGameView {
    ILOG(@"In Show Game View now\n");
    // Ensure UI operations happen on the main thread
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showGameView];
        });
        return;
    }

#if TARGET_OS_IOS
//    [self.touchViewController.navigationController setToolbarHidden:true animated:NO];
   [[UIApplication sharedApplication] setStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
   [[UIApplication sharedApplication] setIdleTimerDisabled:true];
#endif

    /// Check if skins are being used (Delta or Manic skin)
    BOOL usingSkins = self.useCustomRenderViewLayout;

    /// When using skins, always disable RetroArch overlay
    /// Otherwise, respect the retroArchControls setting
    if (usingSkins) {
        settings_t *settings = config_get_ptr();
        settings->bools.input_overlay_enable = false;
        command_event(CMD_EVENT_OVERLAY_INIT, NULL);
        ILOG(@"[RA] Disabled RA overlay due to skin usage");
    } else {
        /// Not using skins - respect retroArchControls setting
        /// The overlay state will be set by useRetroArchController: which is called later
        ILOG(@"[RA] Not using skins - overlay state will respect retroArchControls setting");
    }

    [self setupWindow];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self setVolume];
		command_event(CMD_EVENT_AUDIO_START, NULL);
        command_event(CMD_EVENT_UNPAUSE, NULL);
        [self useRetroArchController:self.retroArchControls];

        // Trigger RetroArch resource updates if needed
        if (self.shouldTriggerRetroArchUpdates) {
            // Only trigger updates when core is paused to avoid interfering with active emulation
            // Pause the core before triggering updates to ensure safe state
            command_event(CMD_EVENT_PAUSE, NULL);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self triggerRetroArchResourceUpdates];
                // Resume after updates are triggered (they run in background)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    command_event(CMD_EVENT_UNPAUSE, NULL);
                });
            });
        }
	});
}

- (void)handleAudioSessionInterruption:(NSNotification *)notification
{
   NSNumber *type = notification.userInfo[AVAudioSessionInterruptionTypeKey];
   if (![type isKindOfClass:[NSNumber class]])
      return;

   if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeBegan)
   {
      RARCH_LOG("AudioSession Interruption Began\n");
      audio_driver_stop();
   }
   else if ([type unsignedIntegerValue] == AVAudioSessionInterruptionTypeEnded)
   {
      RARCH_LOG("AudioSession Interruption Ended\n");
      audio_driver_start(false);
   }
}

#ifdef HAVE_MENU
/// C helper function to trigger RetroArch update actions
/// Uses menu callback system to trigger the update downloads
/// NOTE: Should only be called when RetroArch is paused or not running
static void trigger_retroarch_update_action(enum msg_hash_enums enum_idx) {
    // Check if menu system is initialized
    struct menu_state *menu_st = menu_state_get_ptr();
    if (!menu_st || !menu_st->driver_ctx) {
        RARCH_LOG("Menu system not initialized, skipping update for enum_idx %d\n", enum_idx);
        return;
    }

    // Get the label string for this enum_idx
    const char *label = msg_hash_to_str(enum_idx);
    if (!label) {
        RARCH_LOG("Could not get label for enum_idx %d\n", enum_idx);
        return;
    }

    // Initialize the callback binding for this menu entry
    // This will set up the action_ok callback based on the label
    menu_file_list_cbs_t cbs;
    memset(&cbs, 0, sizeof(menu_file_list_cbs_t));

    // Bind the OK action callback using the label
    // This looks up the appropriate action handler from the menu callback system
    menu_cbs_init_bind_ok(&cbs, "", label, strlen(label), MENU_SETTING_ACTION, 0, label, strlen(label));

    // Now call the action_ok callback if it was set
    if (cbs.action_ok) {
        cbs.action_ok("", label, MENU_SETTING_ACTION, 0, 0);
    } else {
        RARCH_LOG("No action_ok callback found for enum_idx %d (label: %s)\n", enum_idx, label);
    }
}
#endif

/// Trigger all RetroArch resource updates (core info, assets, controller profiles, cheats, databases, overlays, shaders)
/// NOTE: Should only be called when RetroArch is paused or not running
- (void)triggerRetroArchResourceUpdates {
#ifdef HAVE_MENU
    // Verify menu system is ready
    struct menu_state *menu_st = menu_state_get_ptr();
    if (!menu_st || !menu_st->driver_ctx) {
        WLOG(@"Menu system not ready - skipping RetroArch resource updates");
        return;
    }

    ILOG(@"Triggering RetroArch resource updates...");

    // Trigger updates with delays between them to avoid overwhelming the network/system
    // Core Info Files
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch core info files...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_CORE_INFO_FILES);
    });

    // Assets
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch assets...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_ASSETS);
    });

    // Controller Profiles (Autoconfig)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch controller profiles...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_AUTOCONFIG_PROFILES);
    });

    // Databases
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch databases...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_DATABASES);
    });

    // Cheats
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch cheats...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_CHEATS);
    });

    // Overlays (if not already handled)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch overlays...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_OVERLAYS);
    });

    // Slang Shaders
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ILOG(@"Updating RetroArch slang shaders...");
        trigger_retroarch_update_action(MENU_ENUM_LABEL_UPDATE_SLANG_SHADERS);
    });

    ILOG(@"All RetroArch resource updates triggered");
#else
    WLOG(@"RetroArch menu system not available - cannot trigger updates");
#endif
}

#pragma mark - ApplePlatform
-(id)renderView { return _renderView; }
-(bool)hasFocus { return YES; }
- (apple_view_type_t)viewType { return _vt; }
- (void)setVideoMode:(gfx_ctx_mode_t)mode
{
#ifdef HAVE_COCOA_METAL
   MetalView *metalView = (MetalView*) _renderView;
   CGFloat scale        = [[UIScreen mainScreen] scale];
   [metalView setDrawableSize:CGSizeMake(
                                          _renderView.bounds.size.width * scale,
                                          _renderView.bounds.size.height * scale
                                          )];
#endif
}
- (void)setCursorVisible:(bool)v { /* no-op for iOS */ }
- (bool)setDisableDisplaySleep:(bool)disable { /* no-op for iOS */ return NO; }
+(PVRetroArchCoreBridge *) get { self; }
-(NSString*)documentsDirectory {
    static dispatch_once_t onceToken;
    static NSString* _documentsDirectory;
    dispatch_once(&onceToken, ^{
#if TARGET_OS_IOS
        NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#elif TARGET_OS_TV
        NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#endif
        _documentsDirectory = paths.firstObject;
    });
	return _documentsDirectory;
}
- (void)refreshSystemConfig {
#if TARGET_OS_IOS && !TARGET_OS_TV
	/* Get enabled orientations */
	apple_frontend_settings.orientation_flags = UIInterfaceOrientationMaskAll;
	if (string_is_equal(apple_frontend_settings.orientations, "landscape"))
		apple_frontend_settings.orientation_flags =
		UIInterfaceOrientationMaskLandscape;
	else if (string_is_equal(apple_frontend_settings.orientations, "portrait"))
		apple_frontend_settings.orientation_flags =
		UIInterfaceOrientationMaskPortrait
		| UIInterfaceOrientationMaskPortraitUpsideDown;
#endif
}
- (void)supportOtherAudioSessions { }
- (void)setupMainWindow { }
/* Delegate */
- (void)applicationDidFinishLaunching:(UIApplication *)application { }
- (void)applicationDidEnterBackground:(UIApplication *)application {
    rarch_stop_draw_observer();
    command_event(CMD_EVENT_SAVE_FILES, NULL);
}
- (void)applicationWillTerminate:(UIApplication *)application {
    rarch_stop_draw_observer();
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    rarch_start_draw_observer();

   settings_t *settings            = config_get_ptr();
   bool ui_companion_start_on_boot = settings->bools.ui_companion_start_on_boot;
   if (!ui_companion_start_on_boot)
	  [self showGameView];
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
   NSFileManager *manager = [NSFileManager defaultManager];
   NSString     *filename = (NSString*)url.path.lastPathComponent;
   NSError         *error = nil;
   NSString  *destination = [self.documentsDirectory stringByAppendingPathComponent:filename];
   /* Copy file to documents directory if it's not already
	* inside Documents directory */
   if ([url startAccessingSecurityScopedResource]) {
	  if (![[url path] containsString: self.documentsDirectory])
		 if (![manager fileExistsAtPath:destination])
			[manager copyItemAtPath:[url path] toPath:destination error:&error];
	  [url stopAccessingSecurityScopedResource];
   }
   return true;
}

- (void) setRootView:(BOOL)flag {
	if (flag) {
		if (!self.batterySavesPath) {
			NSFileManager *fm = [[NSFileManager alloc] init];
			self.batterySavesPath = [NSString stringWithFormat:@"%@/RetroArch/config", self.documentsDirectory];
			NSString *fileName = [NSString stringWithFormat:@"%@/RetroArch/config/retroarch.cfg",
								  self.documentsDirectory];
			if ([fm fileExistsAtPath: fileName]) {
				//[fm removeItemAtPath:fileName error:nil];
			}
		}
	}
	self.isRootView=flag;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
   [self refreshSystemConfig];
}

void rarch_start_draw_observer(void)
{
   if (iterate_observer && CFRunLoopObserverIsValid(iterate_observer))
       return;

   if (iterate_observer != NULL)
      CFRelease(iterate_observer);
   iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting,
                                              true, 0, rarch_draw_observer, 0);
   CFRunLoopAddObserver(CFRunLoopGetMain(), iterate_observer, kCFRunLoopCommonModes);
}

void rarch_stop_draw_observer(void)
{
    if (!iterate_observer || !CFRunLoopObserverIsValid(iterate_observer))
        return;
    CFRunLoopObserverInvalidate(iterate_observer);
    CFRelease(iterate_observer);
    iterate_observer = NULL;
}

@end

/* RetroArch */


void ui_companion_cocoatouch_event_command(
	  void *data, enum event_command cmd) {

    ILOG(@"Event command: %d", cmd);
    if (cmd == CMD_EVENT_MENU_SAVE_CURRENT_CONFIG) {
        ILOG(@"Saving current config");
    } else if (cmd == CMD_EVENT_MENU_TOGGLE) {
        ILOG(@"Toggling menu");
    }

}

static struct string_list *ui_companion_cocoatouch_get_app_icons(void)
{
   static struct string_list *list = NULL;
   static dispatch_once_t onceToken;

   dispatch_once(&onceToken, ^{
         union string_list_elem_attr attr;
         attr.i = 0;
         NSDictionary *iconfiles = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIcons"];
         NSString *primary;
         const char *cstr;
#if TARGET_OS_TV
         primary = iconfiles[@"CFBundlePrimaryIcon"];
#else
         primary = iconfiles[@"CFBundlePrimaryIcon"][@"CFBundleIconName"];
#endif
         list = string_list_new();
         cstr = [primary cStringUsingEncoding:kCFStringEncodingUTF8];
         if (cstr)
            string_list_append(list, cstr, attr);

         NSArray<NSString *> *alts;
#if TARGET_OS_TV
         alts = iconfiles[@"CFBundleAlternateIcons"];
#else
         alts = [iconfiles[@"CFBundleAlternateIcons"] allKeys];
#endif
         NSArray<NSString *> *sorted = [alts sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
         for (NSString *str in sorted)
         {
            cstr = [str cStringUsingEncoding:kCFStringEncodingUTF8];
            if (cstr)
               string_list_append(list, cstr, attr);
         }
      });

   return list;
}

static void ui_companion_cocoatouch_set_app_icon(const char *iconName)
{
   NSString *str;
   if (!string_is_equal(iconName, "Default"))
      str = [NSString stringWithCString:iconName encoding:NSUTF8StringEncoding];
   [[UIApplication sharedApplication] setAlternateIconName:str completionHandler:nil];
}

static uintptr_t ui_companion_cocoatouch_get_app_icon_texture(const char *icon)
{
   static NSMutableDictionary<NSString *, NSNumber *> *textures = nil;
   static dispatch_once_t once;
   dispatch_once(&once, ^{
      textures = [NSMutableDictionary dictionaryWithCapacity:6];
   });

   NSString *iconName = [NSString stringWithUTF8String:icon];
   if (!textures[iconName])
   {
      UIImage *img = [UIImage imageNamed:iconName];
      if (!img)
      {
         RARCH_LOG("could not load %s\n", icon);
         return 0;
      }
      NSData *png = UIImagePNGRepresentation(img);
      if (!png)
      {
         RARCH_LOG("could not get png for %s\n", icon);
         return 0;
      }

      uintptr_t item;
      gfx_display_reset_textures_list_buffer(&item, TEXTURE_FILTER_MIPMAP_LINEAR,
                                             (void*)[png bytes], (unsigned int)[png length], IMAGE_TYPE_PNG,
                                             NULL, NULL);
      textures[iconName] = [NSNumber numberWithUnsignedLong:item];
   }

   return [textures[iconName] unsignedLongValue];
}

static void rarch_draw_observer(CFRunLoopObserverRef observer,
	CFRunLoopActivity activity, void *info)
{
   uint32_t runloop_flags;
   int          ret   = runloop_iterate();
   if (ret == -1) {
	   command_event(CMD_EVENT_MENU_SAVE_CURRENT_CONFIG, NULL);
       ILOG(@"exit loop\n");
	   return;
   }

    task_queue_check();

   runloop_flags = runloop_get_flags();
   if (!(runloop_flags & RUNLOOP_FLAG_IDLE))
	  CFRunLoopWakeUp(CFRunLoopGetMain());
}

void get_ios_version(int *major, int *minor) {
	NSArray *decomposed_os_version = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
	if (major && decomposed_os_version.count > 0)
		*major = (int)[decomposed_os_version[0] integerValue];
	if (minor && decomposed_os_version.count > 1)
		*minor = (int)[decomposed_os_version[1] integerValue];
}

void bundle_decompressed(retro_task_t *task,
	  void *task_data,
	  void *user_data, const char *err) {
   decompress_task_data_t *dec = (decompress_task_data_t*)task_data;
    ILOG(@"Bundle Decompressed\n");
   if (err)
	   ELOG(@"%s", err);
   if (dec) {
       [_current useRetroArchController:_current.retroArchControls];
       if (!err) {
           //command_event(CMD_EVENT_REINIT, NULL);
       }
	  free(dec->source_file);
	  free(dec);
   }
   processing_init=false;
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
       runloop_state_t *runloop_st = runloop_state_get_ptr();
       runloop_st->flags &= ~RUNLOOP_FLAG_OVERRIDES_ACTIVE;
   });
}
void extract_bundles() {
	settings_t *settings = config_get_ptr();
	task_push_decompress(
				settings->paths.bundle_assets_src,
				settings->paths.bundle_assets_dst,
				NULL,
				settings->paths.bundle_assets_dst_subdir,
				NULL,
				bundle_decompressed,
				NULL,
				NULL,
				false);
}
void main_msg_queue_push(const char *msg,
	  unsigned prio, unsigned duration,
	  bool flush) {
	ILOG(@"MSGQ: %s\n", msg);
}

void menuToggle() {
    command_event(CMD_EVENT_MENU_TOGGLE, NULL);
}

bool ios_running_on_ipad(void)
{
   return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
}

ui_companion_driver_t ui_companion_cocoatouch = {
   NULL, /* init */
   NULL, /* deinit */
   NULL, /* toggle */
   ui_companion_cocoatouch_event_command,
   NULL, /* notify_refresh */
   NULL, /* msg_queue_push */
   NULL, /* render_messagebox */
   NULL, /* get_main_window */
   NULL, /* log_msg */
   NULL, /* is_active */
   ui_companion_cocoatouch_get_app_icons,
   ui_companion_cocoatouch_set_app_icon,
   ui_companion_cocoatouch_get_app_icon_texture,
   NULL, /* browser_window */
   NULL, /* msg_window */
   NULL, /* window */
   NULL, /* application */
   "cocoatouch",
};
