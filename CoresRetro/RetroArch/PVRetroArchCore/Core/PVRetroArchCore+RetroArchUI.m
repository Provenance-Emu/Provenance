//
//  PVRetroArchCore+RetroArchUI.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Controls.h"
#import "PVRetroArchCoreBridge+Audio.h"
#import "PVRetroArchCoreBridge+Video.h"
#import "PVRetroArchCoreBridge+Archive.h"
#import "PVRetroArchCoreBridge+BIOSAtariST.h"
#import "PVRetroArchCore+ExceptionTrampoline.h"
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
#include "./PVRetroArchEmulationThread.h"

/* RetroArch Includes */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

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

/// Set while `overlays.zip` is downloading so duplicate `writeConfigFile` / boot paths do not start parallel downloads.
static BOOL s_overlayZipDownloadInFlight = NO;

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
@property (nonatomic, assign) BOOL isShuttingDownForViewportUpdates;
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

- (void)setIsShuttingDownForViewportUpdates:(BOOL)isShuttingDown {
    objc_setAssociatedObject(self, @selector(isShuttingDownForViewportUpdates), @(isShuttingDown), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isShuttingDownForViewportUpdates {
    NSNumber *val = objc_getAssociatedObject(self, @selector(isShuttingDownForViewportUpdates));
    return val.boolValue;
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

/// repairTOSImageAtPath:, validateTOSReadyOrLog:fallback:, findBestTOSInDirectory:,
/// and all other Hatari/Atari ST BIOS helpers live in PVRetroArchCore+BIOS+AtariST.m.

- (void)setupEmulation {
    ILOG(@"setupEmulation: ENTER — retroArchRootPath=%@", self.retroArchRootPath);
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
    ILOG(@"setupEmulation: writeConfigFile returned, checking retroarch.cfg exists=%d",
         [[NSFileManager defaultManager] fileExistsAtPath:[self.retroArchRootPath stringByAppendingPathComponent:@"config/retroarch.cfg"]]);
    /// Sync BIOS resources to the RetroArch system directory.
    /// writeConfigFile already validated and wrote tos.img (for Hatari/Atari ST) before this call.
    /// syncResources only copies files that are absent at the destination, so if writeConfigFile
    /// wrote a valid tos.img it will not be overwritten.  If writeConfigFile skipped tos.img
    /// (e.g. because it detected a ZIP), syncResources would otherwise blindly copy the invalid
    /// file — guard against that by removing any ZIP tos.img after the sync.
    NSString *systemDir = [self.retroArchRootPath stringByAppendingPathComponent:@"system"];
    [self syncResources:self.BIOSPath to:systemDir];

    // For Hatari/Atari ST: repair any TOS files that arrived via syncResources with
    // byte-swapped addresses, and do a final validation before launch.
    // Full logic is in PVRetroArchCore+BIOS+AtariST.m.
    if ([self pv_isHatariSystem]) {
        [self repairHatariTOSInSystemDir:systemDir];
        NSString *hatariTosPath = [[systemDir stringByAppendingPathComponent:@"hatari"]
                                   stringByAppendingPathComponent:@"tos.img"];
        NSString *tosImagePath  = [systemDir stringByAppendingPathComponent:@"tos.img"];
        [self validateTOSReadyOrLog:hatariTosPath fallback:tosImagePath];
    }
}

- (void)startEmulation {
	@autoreleasepool {
        _current=self;
        firstLoad=true;

        // TODO(tvos-tester-18may): PPSSPP RA wrapper insta-crashes on tvOS launch
        // (native PVPPSSPP + OpenGL is fine, so this is wrapper-specific). PPSSPP
        // requires GLES3/Vulkan; the wrapper currently sets `alwaysUseMetal = true`
        // in loadFileAtPath (PVRetroArchCoreBridge.mm:105) which may conflict with
        // PPSSPP's gfx backend negotiation. The existing [PPSSPP-DIAG] logging will
        // pinpoint whether the crash is in startEmulation → setupEmulation/setOptionValues
        // or later inside rarch_main → video_driver_init when Vulkan/GLES is requested.
        // Repro on a real Apple TV + capture the device console to localise.

        /// [PPSSPP-DIAG] startEmulation entry — useful to confirm we make it
        /// past loadFileAtPath and into the emulation kickoff. If logs stop
        /// here, the crash is during teardown of a previous run or in
        /// setupEmulation/setOptionValues/startVM.
        {
            NSString *diagSysId = self.systemIdentifier ?: @"<nil>";
            if ([[diagSysId lowercaseString] containsString:@"psp"]) {
                ILOG(@"[PPSSPP-DIAG] startEmulation ENTER systemIdentifier=%@ coreIdentifier=%@ isInitialized=%d", diagSysId, self.coreIdentifier, _isInitialized);
            }
        }

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
            // Wait for any in-flight observer callback on the emu thread to
            // finish before tearing down RetroArch state in main_exit.
            pv_retro_emu_thread_drain();
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
    if (!_isInitialized) {
        WLOG(@"RetroArchCoreBridge setPauseEmulation ignored because RetroArch is not initialized: %i", flag);
        return;
    }
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (!runloop_st) {
        WLOG(@"RetroArchCoreBridge setPauseEmulation ignored because runloop state is unavailable: %i", flag);
        return;
    }
    command_event(flag ? CMD_EVENT_PAUSE : CMD_EVENT_UNPAUSE, NULL);
    // Set RUNLOOP_FLAG_IDLE when pausing so that rarch_draw_observer stops
    // calling CFRunLoopWakeUp in a tight loop, which blocks the main thread
    // and makes the Provenance pause menu (SwiftUI) unresponsive.
    //
    // We *also* explicitly set/clear RUNLOOP_FLAG_PAUSED here. Although
    // CMD_EVENT_PAUSE/UNPAUSE normally toggles RUNLOOP_FLAG_PAUSED on the
    // emu thread, the command is processed asynchronously, so the IDLE bit
    // we flip below can be observed by task_queue_check() before PAUSED has
    // been updated. That window lets stale callbacks fire across the
    // IDLE -> PAUSED -> RUNNING transition. Setting both flags atomically
    // here keeps the runloop state machine consistent for any observer that
    // checks the flags directly (see runloop.c task_queue_check call sites).
    if (flag) {
        runloop_st->flags |= (RUNLOOP_FLAG_IDLE | RUNLOOP_FLAG_PAUSED);
    } else {
        runloop_st->flags &= ~(RUNLOOP_FLAG_IDLE | RUNLOOP_FLAG_PAUSED);
    }
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

- (void)drainEmulationThread {
    // Wraps pv_retro_emu_thread_drain so non-RA modules (PVUI) can dispatch to
    // the emulation-thread barrier via NSSelectorFromString without taking a
    // module-level dependency on PVRetroArch. Safe before the emu thread has
    // started (the underlying helper is a no-op in that case).
    pv_retro_emu_thread_drain();
}

- (void)stopEmulation {
    self.isShuttingDownForViewportUpdates = YES;
	[super stopEmulation];
	self.shouldStop = YES;
	if (iterate_observer) {
		CFRunLoopObserverInvalidate(iterate_observer);
		CFRelease(iterate_observer);
	}
	iterate_observer = NULL;
    // Wait for any in-flight rarch_draw_observer callback on the emu thread to
    // finish before tearing down RetroArch state. Without this barrier
    // main_exit could free state that the emu thread is still iterating.
    pv_retro_emu_thread_drain();
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
    ILOG(@"writeConfigFile: ENTER");
    [PVRetroArchCoreBridge synchronizeOptionsWithRetroArch];

    // Initialize file manager
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *fileName = [self.retroArchRootPath stringByAppendingPathComponent:@"config/retroarch.cfg"];
    ILOG(@"Expecting config file to be at %@", fileName);

    // Get the version number from the app's Info.plist
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!appVersion) {
        appVersion = @"unknown";
    }
    ILOG(@"App version: %@", appVersion);

    NSString *verFile = [self.retroArchRootPath stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"config/%@.cfg", appVersion]];
    ILOG(@"Expecting version file to be at %@", verFile);

    BOOL configFileExists = [fm fileExistsAtPath:fileName];
    ILOG(@"Config file exists: %@", configFileExists ? @"YES" : @"NO");

    BOOL versionFileExists = [fm fileExistsAtPath:verFile];
    ILOG(@"Version file exists: %@", versionFileExists ? @"YES" : @"NO");

    BOOL isFirstRunOrVersionUpdate = !configFileExists || !versionFileExists;

    BOOL shouldUpdateAssets = [self shouldUpdateAssets];
    ILOG(@"Should update assets: %@", shouldUpdateAssets ? @"YES" : @"NO");

    if (isFirstRunOrVersionUpdate || shouldUpdateAssets) {
        [PVOSDNotification postMessage:@"Setting up RetroArch resources…" type:PVOSDTypeInfo duration:0];

        NSString *src = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"retroarch.cfg" ofType:nil];
        ILOG(@"writeConfigFile: bundled retroarch.cfg source path: %@", src ?: @"(nil!)");
        if (!src) {
            ELOG(@"writeConfigFile: CRITICAL — retroarch.cfg not found in bundle [%@]! Config will not be created.",
                 [NSBundle bundleForClass:[PVRetroArchCoreBridge class]].bundlePath);
        }

        // Ensure the config directory exists before trying to write
        NSString *configDir = [self.retroArchRootPath stringByAppendingPathComponent:@"config"];
        if (![fm fileExistsAtPath:configDir]) {
            NSError *mkdirErr = nil;
            [fm createDirectoryAtPath:configDir withIntermediateDirectories:YES attributes:nil error:&mkdirErr];
            if (mkdirErr) {
                ELOG(@"writeConfigFile: Failed to create config dir %@: %@", configDir, mkdirErr.localizedDescription);
            } else {
                ILOG(@"writeConfigFile: Created config directory: %@", configDir);
            }
        }

        if (!configFileExists) {
            ILOG(@"writeConfigFile: Writing config file to %@", fileName);
            [self syncResource:src to:fileName];
            // Verify it was actually written
            if ([fm fileExistsAtPath:fileName]) {
                ILOG(@"writeConfigFile: Successfully created retroarch.cfg");
            } else {
                ELOG(@"writeConfigFile: FAILED to create retroarch.cfg at %@", fileName);
            }
        } else if (!versionFileExists) {
            // Version update: merge forced defaults into existing user config.
            // Keys listed here will be overwritten to match the bundled cfg value.
            // User customizations for all OTHER keys are preserved.
            ILOG(@"Version update detected — merging forced defaults into existing config at %@", fileName);
            [self mergeForcedDefaultsFromBundledCfg:src intoUserCfg:fileName];
        }

        if (!versionFileExists) {
            ILOG(@"Writing version file to %@", verFile);
            [self syncResource:src to:verFile];
        }

        if(shouldUpdateAssets) {
            NSString *overlay_back = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"arrow.png" ofType:nil];
            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/flatui/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/monochrome/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/automatic/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/pixel/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/daite/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/dot-art/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/neoactive/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/retroactive/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/retrosystem/png/arrow.png"]];

            [self syncResource:overlay_back to:[self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/systematic/png/arrow.png"]];
        }

        processing_init = true;
    }

#if !TARGET_OS_TV
    // When the user's config file already exists, apply the MIDI preference
    // (retroArchMIDIEnabled) so the in-game toggle takes effect on the next
    // session start. On first run the bundled retroarch.cfg already ships
    // with "coremidi" as the default, so no patch is needed before the file exists.
    if ([fm fileExistsAtPath:fileName]) {
        [self applyMIDIPreferenceToUserCfg:fileName];
    }
#endif // !TARGET_OS_TV

    // Overlay download disabled — Provenance uses its own skin system.
    // The bundled pv_ui_overlay (RGUI button overlay) is synced via syncResources above.

    // Check if we need to trigger RetroArch updates (first run or version update)
    BOOL shouldTriggerUpdates = isFirstRunOrVersionUpdate;
    if (shouldTriggerUpdates) {
        ILOG(@"First run or version update detected - will trigger RetroArch resource updates after initialization");
        // Store flag to trigger updates after RetroArch is initialized
        self.shouldTriggerRetroArchUpdates = YES;
    }

    // Always sync user_language in retroarch.cfg so locale/override changes
    // take effect on next core launch (not just on first-run or version update).
    NSString *mainCfgPath = [NSString stringWithFormat:@"%@/config/retroarch.cfg",
                             self.retroArchRootPath];
    if ([fm fileExistsAtPath:mainCfgPath]) {
        [self applyUserLanguageToRetroArchConfig:mainCfgPath];
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

    /// Set video settings for Hatari (Atari ST) to ensure correct color rendering.
    ///
    /// Pixel format: Hatari libretro uses RETRO_PIXEL_FORMAT_RGB565 by default.
    /// This is set by the core via RETRO_ENVIRONMENT_SET_PIXEL_FORMAT during retro_load_game().
    /// RetroArch's runloop stores this in video_st->pix_fmt and the Metal/GL video driver
    /// converts it appropriately. We do NOT override video_pixel_format in the config file
    /// as that can conflict with cores requesting different formats (e.g., geolith uses XRGB8888).
    ///
    /// hatari.cfg nMonitorType values (in hatari.cfg [Screen] section):
    ///   0 = Color ST monitor  (correct for most color games - default)
    ///   1 = Monochrome monitor (SM124 - only for mono games, renders in B&W)
    ///   2 = VGA monitor       (for Atari STE/Falcon VGA output)
    ///   3 = TV output         (for RF/composite output simulation)
    ///
    /// Wrong colors after boot are typically caused by:
    ///   1. nMonitorType != 0 (using mono/VGA mode for a color game)
    ///   2. TOS image corruption or byte-order issues (see Spike 2823)
    ///   3. nSpec512Threshold too low (causes Spectrum 512 dithering artifacts)
    /// See: hatari.cfg [Screen] section - nMonitorType = 0, nSpec512Threshold = 4
    if ([self pv_isHatariSystem]) {
        content = [content stringByAppendingString:@"video_scale_integer = \"true\"\n"];
        content = [content stringByAppendingString:@"video_smooth = \"false\"\n"];
        ILOG(@"Hatari video settings: integer scaling, no smoothing (pixel format RGB565 set by core via SET_PIXEL_FORMAT)");
    }

    /// Only sync bundled resources on first-run or version update
    /// These are copy-if-missing, but enumerating bundles is expensive; avoid doing it every launch.
    if (isFirstRunOrVersionUpdate) {
        [self syncResources:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"pv_ui_overlay" ofType:nil]
                         to:[self.retroArchRootPath stringByAppendingPathComponent:@"overlays/pv_ui_overlay" ]];
        [self syncResources:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"mame_plugins" ofType:nil]
                         to:[self.retroArchRootPath stringByAppendingPathComponent:@"system/mame/plugins" ]];
    }
    NSString *systemDirectory = [self.retroArchRootPath stringByAppendingPathComponent:@"system"];

    /// Hatari TOS BIOS setup and hatari.cfg generation.
    /// Full logic (including BIOS search across all known locations, repair,
    /// validation, and config writing) lives in PVRetroArchCore+BIOS+AtariST.m.
    if ([self pv_isHatariSystem]) {
        DLOG(@"Hatari: writeConfigFile — detected Hatari system, running TOS setup + config write");
        [self setupHatariTOSForSystemDir:systemDirectory];
        [self writeHatariConfigForSystemDir:systemDirectory];
        DLOG(@"Hatari: writeConfigFile — TOS setup + config write complete for systemDir: %@", systemDirectory);
    }

    /// Set system directory in RetroArch config (required for Hatari to find TOS image)
    content = [content stringByAppendingString:
               [NSString stringWithFormat:@"system_directory = \"%@\"\n", systemDirectory]];
    ILOG(@"System directory set to: %@", systemDirectory);

    /// NOTE: hatari_boot_hd is NOT set here.  Core variables must be written to the
    /// per-core options file (Hatari/Hatari.opt), not to the main appendconfig (opt.cfg).
    /// PVRetroArchCore+Options.swift writes hatari_boot_hd = "disabled" to Hatari/Hatari.opt.

    if (!self.retroArchControls) {
        content = [content stringByAppendingString:
                       @"input_overlay_enable = \"false\"\n"
        ];
        ILOG(@"Input overlay disabled.");
    }
    if (self.coreOptionConfigPath.length > 0 && self.coreOptionConfig.length > 0) {
        fileName = [self.retroArchRootPath stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"config/%@", self.coreOptionConfigPath]];
        if (![fm fileExistsAtPath: fileName] || self.coreOptionOverwrite) {
            [fm createDirectoryAtPath:[fileName stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
            // Log BEFORE state for Hatari to confirm what was on disk previously.
            if ([self pv_isHatariSystem]) {
                NSString *prevContent = [NSString stringWithContentsOfFile:fileName
                                                                  encoding:NSUTF8StringEncoding
                                                                     error:nil];
                if (prevContent) {
                    NSRange bootHdRange = [prevContent rangeOfString:@"hatari_boot_hd"];
                    NSString *prevBootHd = nil;
                    if (bootHdRange.location != NSNotFound) {
                        NSUInteger lineStart = bootHdRange.location;
                        NSRange beforeNewlineRange = [prevContent rangeOfString:@"\n"
                                                                         options:NSBackwardsSearch
                                                                           range:NSMakeRange(0, bootHdRange.location)];
                        if (beforeNewlineRange.location != NSNotFound) {
                            lineStart = beforeNewlineRange.location + beforeNewlineRange.length;
                        }
                        NSRange afterNewlineRange = [prevContent rangeOfString:@"\n"
                                                                        options:0
                                                                          range:NSMakeRange(bootHdRange.location,
                                                                                            prevContent.length - bootHdRange.location)];
                        NSUInteger lineEnd = (afterNewlineRange.location != NSNotFound)
                            ? afterNewlineRange.location
                            : prevContent.length;
                        prevBootHd = [prevContent substringWithRange:NSMakeRange(lineStart, lineEnd - lineStart)];
                    } else {
                        prevBootHd = @"(key absent)";
                    }
                    DLOG(@"Hatari opts BEFORE overwrite — hatari_boot_hd: %@, file: %@", prevBootHd, fileName);
                } else {
                    DLOG(@"Hatari opts BEFORE overwrite — file did not exist at %@", fileName);
                }
            }
            NSError *optWriteErr = nil;
            BOOL optWriteOK = [self.coreOptionConfig writeToFile:fileName
                                    atomically:NO
                                    encoding:NSUTF8StringEncoding
                                        error:&optWriteErr];
            if (optWriteOK) {
                ILOG(@"Core option config written to %@", fileName);
                if ([self pv_isHatariSystem]) {
                    // Log AFTER state so we can confirm hatari_boot_hd was written correctly.
                    NSString *afterContent = [NSString stringWithContentsOfFile:fileName
                                                                       encoding:NSUTF8StringEncoding
                                                                          error:nil] ?: @"(read failed)";
                    NSRange afterRange = [afterContent rangeOfString:@"hatari_boot_hd"];
                    NSString *afterBootHd = (afterRange.location != NSNotFound)
                        ? [afterContent substringWithRange:NSMakeRange(afterRange.location,
                            MIN(40u, afterContent.length - afterRange.location))]
                        : @"(key absent — write may have failed)";
                    ILOG(@"Hatari opts AFTER overwrite — hatari_boot_hd: %@, file: %@", afterBootHd, fileName);
                }
            } else {
                ELOG(@"Core option config write failed for %@: %@",
                     fileName, optWriteErr.localizedDescription);
            }
        } else if ([self pv_isHatariSystem]) {
            /// The Hatari opts file already exists — do a targeted in-place key repair so we
            /// never wipe user-configured options.  The hatari core uses "disabled"/"enabled"
            /// (not "false"/"true") for hatari_boot_hd.  Replace any wrong value with
            /// "disabled"; if the key is absent, append it.
            NSError *hatariReadErr = nil;
            NSString *existing = [NSString stringWithContentsOfFile:fileName
                                                           encoding:NSUTF8StringEncoding
                                                              error:&hatariReadErr];
            if (!hatariReadErr && existing) {
                DLOG(@"Hatari opts BEFORE in-place repair — full content of %@:\n%@", fileName, existing);
                NSString *correct = @"hatari_boot_hd = \"disabled\"";
                NSString *updated = nil;
                /// Replace ANY invalid hatari_boot_hd value. The hatari core ONLY accepts
                /// "enabled" or "disabled". Anything else causes GET_VARIABLE to fail
                /// and triggers the --acsi empty-string crash.
                NSRange keyRange = [existing rangeOfString:@"hatari_boot_hd"];
                if (keyRange.location != NSNotFound) {
                    // Find the full line containing hatari_boot_hd
                    NSRange lineStart = [existing rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                                                 options:NSBackwardsSearch
                                                                   range:NSMakeRange(0, keyRange.location)];
                    NSUInteger start = (lineStart.location == NSNotFound) ? 0 : lineStart.location + 1;
                    NSRange lineEnd = [existing rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                                               options:0
                                                                 range:NSMakeRange(keyRange.location, existing.length - keyRange.location)];
                    NSUInteger end = (lineEnd.location == NSNotFound) ? existing.length : lineEnd.location;
                    NSString *line = [existing substringWithRange:NSMakeRange(start, end - start)];
                    DLOG(@"Hatari: found hatari_boot_hd line in opts: \"%@\"", line);

                    // Only keep "enabled" — replace everything else with "disabled"
                    if (![line containsString:@"\"enabled\""] && ![line containsString:@"\"disabled\""]) {
                        existing = [existing stringByReplacingCharactersInRange:NSMakeRange(start, end - start)
                                                                    withString:correct];
                        updated = existing;
                        ILOG(@"Hatari opts: corrected invalid hatari_boot_hd line (%@) → \"disabled\"", line);
                    } else {
                        DLOG(@"Hatari opts: hatari_boot_hd line already valid (%@) — no repair needed", line);
                    }
                }
                if (!updated && ![existing containsString:@"hatari_boot_hd"]) {
                    BOOL needsNewline = ![existing hasSuffix:@"\n"] && ![existing hasSuffix:@"\r"];
                    updated = needsNewline
                        ? [existing stringByAppendingFormat:@"\n%@\n", correct]
                        : [existing stringByAppendingFormat:@"%@\n", correct];
                    ILOG(@"Hatari opts: appended missing hatari_boot_hd key to %@", fileName);
                }
                if (updated) {
                    NSError *hatariWriteErr = nil;
                    [updated writeToFile:fileName
                              atomically:YES
                                encoding:NSUTF8StringEncoding
                                   error:&hatariWriteErr];
                    if (hatariWriteErr) {
                        ELOG(@"Hatari opts repair write failed for %@: %@",
                             fileName, hatariWriteErr.localizedDescription);
                    } else {
                        ILOG(@"Hatari opts AFTER in-place repair — successfully wrote updated hatari_boot_hd to %@", fileName);
                    }
                } else {
                    DLOG(@"Hatari opts: no repair was needed for %@ — hatari_boot_hd is already correct", fileName);
                }
            } else if (hatariReadErr) {
                ELOG(@"Hatari opts: failed to read %@ for in-place repair: %@",
                     fileName, hatariReadErr.localizedDescription);
            }
        }
    } else if (self.coreOptionConfig.length > 0) {
        content=[content stringByAppendingString:self.coreOptionConfig];
    }
    // Use batterySavesPath when available; fall back to <retroArchRoot>/cache
    // so opt.cfg never contains "(null)" when called early (before initCore sets paths).
    NSString *cacheDir = self.batterySavesPath;
    if (!cacheDir.length) {
        cacheDir = [self.retroArchRootPath stringByAppendingPathComponent:@"cache"];
        [fm createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
        WLOG(@"batterySavesPath is nil during writeConfigFile — using fallback cache dir: %@", cacheDir);
    }
    content = [content stringByAppendingString:
               [NSString stringWithFormat:@"cache_directory = \"%@\"\n", cacheDir]];
    ILOG(@"Cache directory set to: %@", cacheDir);

    // NOTE: OSD notification suppression is handled via the bundled retroarch.cfg defaults
    // and forcedDefaultKeys() migration.  Do NOT put retroarch.cfg-format keys in opt.cfg —
    // opt.cfg may contain core option values whose format differs from retroarch.cfg.

    fileName = [self.retroArchRootPath stringByAppendingPathComponent:@"config/opt.cfg"];
    ILOG(@"writeConfigFile: Writing opt.cfg to %@", fileName);

    // Ensure config directory exists (may be a fresh install)
    NSString *optConfigDir = [fileName stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:optConfigDir]) {
        [fm createDirectoryAtPath:optConfigDir withIntermediateDirectories:YES attributes:nil error:nil];
        ILOG(@"writeConfigFile: Created config directory for opt.cfg: %@", optConfigDir);
    }

    NSError *error;
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:&error];
    if (error) {
        ELOG(@"writeConfigFile: Error writing opt.cfg to %@: %@", fileName, error.localizedDescription);
    } else {
        ILOG(@"writeConfigFile: opt.cfg written successfully to %@", fileName);
    }
}

- (bool)shouldUpdateAssets {
    NSFileManager *fm = [[NSFileManager alloc] init];

    // Primary check: if the version-stamped config exists, we already set up
    // assets for this app version — don't redo the work.
    // Use objectForInfoDictionaryKey: to match writeConfigFile's version lookup.
    NSString *appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown";
    NSString *verFile = [self.retroArchRootPath stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"config/%@.cfg", appVersion]];
    if ([fm fileExistsAtPath:verFile]) {
        // Sanity: verify a representative asset actually exists on disk.
        // On tvOS the system can purge files independently, so the version
        // stamp alone isn't proof the assets survived.
        NSString *assetFile = [self.retroArchRootPath stringByAppendingPathComponent:@"assets/xmb/flatui/png/arrow.png"];
        if ([fm fileExistsAtPath:assetFile]) {
            DLOG(@"shouldUpdateAssets: version file + asset present — skip");
            return false;
        }
        ILOG(@"shouldUpdateAssets: version file exists but asset missing — re-syncing");
    } else {
        ILOG(@"shouldUpdateAssets: no version file for %@ — first run or update", appVersion);
    }

    return true;
}

- (bool)shouldUpdateOverlays {
    @synchronized([PVRetroArchCoreBridge class]) {
        if (s_overlayZipDownloadInFlight) {
            DLOG(@"shouldUpdateOverlays: download already in-flight, skipping");
            return false;
        }
    }
    /// The libretro buildbot `overlays.zip` has entries at the root level (COPYING,
    /// gamepads/, keyboards/, etc. — no `overlays/` prefix). We extract into
    /// `retroArchRootPath/overlays/` so that files land at `overlays/COPYING`, etc.
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *overlaysDir = [self.retroArchRootPath stringByAppendingPathComponent:@"overlays"];
    NSString *copyingPath = [overlaysDir stringByAppendingPathComponent:@"COPYING"];

    if ([fm fileExistsAtPath:copyingPath]) {
        DLOG(@"shouldUpdateOverlays: COPYING present at %@, no download needed", copyingPath);
        return false;
    }

    ILOG(@"shouldUpdateOverlays: COPYING missing at %@, download needed", copyingPath);
    return true;
}

- (void)downloadAndExtractOverlays {
    @synchronized([PVRetroArchCoreBridge class]) {
        if (s_overlayZipDownloadInFlight) {
            DLOG(@"Overlay download already in progress, ignoring duplicate request");
            return;
        }
        s_overlayZipDownloadInFlight = YES;
    }

    /// The buildbot `overlays.zip` has root-level entries (COPYING, gamepads/, etc.).
    /// Extract into `retroArchRootPath/overlays/` so they land at the correct paths.
    /// Use `overwrite:NO` to preserve bundled content like `pv_ui_overlay`.
    NSString *overlayURL = @"https://buildbot.libretro.com/assets/frontend/overlays.zip";
    NSString *extractRoot = [self.retroArchRootPath stringByAppendingPathComponent:@"overlays"];

    ILOG(@"Starting overlay download from %@ → %@", overlayURL, extractRoot);

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 300.0;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURL *url = [NSURL URLWithString:overlayURL];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL *tempLocation, NSURLResponse *response, NSError *error) {

        void (^clearInFlight)(void) = ^{
            @synchronized([PVRetroArchCoreBridge class]) {
                s_overlayZipDownloadInFlight = NO;
            }
        };

        if (error) {
            ELOG(@"Error downloading overlays: %@", error.localizedDescription);
            clearInFlight();
            return;
        }

        if (!tempLocation) {
            ELOG(@"No temporary file location for downloaded overlays");
            clearInFlight();
            return;
        }

        ILOG(@"Overlays downloaded (%lld bytes), extracting on background thread",
             [[[NSFileManager defaultManager] attributesOfItemAtPath:tempLocation.path error:nil] fileSize]);

        /// Extract on a background queue — ZIP extraction is pure file I/O and can
        /// take 20+ seconds. Running it on main thread blocks `setViewType:` dispatch_sync
        /// from the RetroArch video thread, deadlocking core initialization.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSFileManager *fm = [[NSFileManager alloc] init];

            /// Ensure the overlays directory exists before extraction
            NSError *mkdirErr = nil;
            [fm createDirectoryAtPath:extractRoot withIntermediateDirectories:YES attributes:nil error:&mkdirErr];
            if (mkdirErr) {
                ELOG(@"Failed to create overlays dir %@: %@", extractRoot, mkdirErr.localizedDescription);
            }

            [PVOSDNotification postMessage:@"Extracting overlays…" type:PVOSDTypeInfo duration:0];
            BOOL extractSuccess = [self extractZIP:tempLocation.path toDestination:extractRoot overwrite:NO];

            if (extractSuccess) {
                NSString *copyingPath = [extractRoot stringByAppendingPathComponent:@"COPYING"];
                if ([fm fileExistsAtPath:copyingPath]) {
                    ILOG(@"Overlays extracted and verified at %@", extractRoot);
                    [PVOSDNotification postMessage:@"RetroArch overlays ready" type:PVOSDTypeSuccess duration:2.0];
                } else {
                    WLOG(@"Overlays extracted to %@ but COPYING not found — zip structure may have changed", extractRoot);
                    NSArray *contents = [fm contentsOfDirectoryAtPath:extractRoot error:nil];
                    ILOG(@"overlays/ contents (%lu items): %@",
                         (unsigned long)contents.count,
                         [[contents subarrayWithRange:NSMakeRange(0, MIN(contents.count, 20))] componentsJoinedByString:@", "]);
                }
            } else {
                ELOG(@"Failed to extract overlays zip file");
            }

            NSError *removeError;
            [fm removeItemAtURL:tempLocation error:&removeError];
            if (removeError) {
                WLOG(@"Could not remove temporary overlay zip: %@", removeError.localizedDescription);
            }
            clearInFlight();
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
    ILOG(@"syncResource: %@ -> %@", from ?: @"(nil)", to ?: @"(nil)");
    if (!from) {
        ELOG(@"syncResource: source path is nil, cannot copy");
        return;
    }
    NSFileManager *fm = [[NSFileManager alloc] init];

    if (![fm fileExistsAtPath:from]) {
        ELOG(@"syncResource: source file does not exist: %@", from);
        return;
    }

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

/// Keys listed here will be force-synced from the bundled retroarch.cfg
/// into the user's existing config on every app version update.
/// Add any key here whose bundled default MUST reach existing users.
static NSArray<NSString *> *forcedDefaultKeys(void) {
    return @[
        @"notification_show_autoconfig",
        @"notification_show_autoconfig_fails",
        @"notification_show_cheats_applied",
        @"notification_show_config_override_load",
        @"notification_show_disk_control",
        @"notification_show_fast_forward",
        @"notification_show_patch_applied",
        @"notification_show_refresh_rate",
        @"notification_show_remap_load",
        @"notification_show_save_state",
        @"notification_show_screenshot",
        @"notification_show_set_initial_disk",
        @"notification_show_when_menu_is_alive",
        @"video_font_enable",
        @"menu_enable_widgets",
        @"midi_input",
        @"midi_output",
    ];
}

/// Reads the bundled cfg and the user's cfg, then overwrites (or appends)
/// any key listed in forcedDefaultKeys() so the bundled value wins.
/// All other keys in the user's cfg are left untouched.
- (void)mergeForcedDefaultsFromBundledCfg:(NSString *)bundledPath
                              intoUserCfg:(NSString *)userPath {
    NSError *err = nil;
    NSString *bundledContent = [NSString stringWithContentsOfFile:bundledPath
                                                        encoding:NSUTF8StringEncoding
                                                           error:&err];
    if (!bundledContent) {
        ELOG(@"Failed to read bundled cfg at %@: %@", bundledPath, err.localizedDescription);
        return;
    }

    NSString *userContent = [NSString stringWithContentsOfFile:userPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:&err];
    if (!userContent) {
        ELOG(@"Failed to read user cfg at %@: %@", userPath, err.localizedDescription);
        return;
    }

    // Parse forced keys from bundled cfg
    NSArray<NSString *> *keys = forcedDefaultKeys();
    NSMutableDictionary<NSString *, NSString *> *forcedValues = [NSMutableDictionary dictionary];

    for (NSString *line in [bundledContent componentsSeparatedByCharactersInSet:
                            [NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        if ([trimmed hasPrefix:@"#"] || trimmed.length == 0) continue;

        for (NSString *key in keys) {
            if ([trimmed hasPrefix:key]) {
                // Verify it's actually "key = value" and not a prefix match
                NSRange eqRange = [trimmed rangeOfString:@"="];
                if (eqRange.location != NSNotFound) {
                    NSString *parsedKey = [[trimmed substringToIndex:eqRange.location]
                                           stringByTrimmingCharactersInSet:
                                           [NSCharacterSet whitespaceCharacterSet]];
                    if ([parsedKey isEqualToString:key]) {
                        forcedValues[key] = trimmed;  // full "key = value" line
                    }
                }
            }
        }
    }

    if (forcedValues.count == 0) {
        ILOG(@"No forced defaults found in bundled cfg — nothing to merge.");
        return;
    }

    // Apply each forced value into the user cfg
    NSMutableString *result = [userContent mutableCopy];
    for (NSString *key in forcedValues) {
        NSString *bundledLine = forcedValues[key];
        // Find existing line for this key in user cfg
        NSString *pattern = [NSString stringWithFormat:@"(?m)^[ \\t]*%@[ \\t]*=.*$",
                             [NSRegularExpression escapedPatternForString:key]];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                              options:0
                                                                                error:&err];
        if (!regex) {
            ELOG(@"Bad regex for key %@: %@", key, err.localizedDescription);
            continue;
        }
        NSTextCheckingResult *match = [regex firstMatchInString:result options:0
                                                          range:NSMakeRange(0, result.length)];
        if (match) {
            NSString *existingLine = [result substringWithRange:match.range];
            if (![existingLine isEqualToString:bundledLine]) {
                [result replaceCharactersInRange:match.range withString:bundledLine];
                ILOG(@"Forced default updated: %@ → %@", existingLine, bundledLine);
            }
        } else {
            // Key not present in user cfg — append it
            if (![result hasSuffix:@"\n"]) {
                [result appendString:@"\n"];
            }
            [result appendFormat:@"%@\n", bundledLine];
            ILOG(@"Forced default appended: %@", bundledLine);
        }
    }

    // Write back
    NSError *writeErr = nil;
    BOOL ok = [result writeToFile:userPath atomically:YES encoding:NSUTF8StringEncoding error:&writeErr];
    if (!ok || writeErr) {
        ELOG(@"Failed to write merged cfg to %@: %@", userPath, writeErr.localizedDescription);
    } else {
        ILOG(@"Successfully merged %lu forced defaults into user cfg at %@",
             (unsigned long)forcedValues.count, userPath);
    }
}

/// Patches a single key in `cfgPath` to the given value.
/// The replacement is done in-place using a regex that matches `key = "..."` lines.
/// If the key is absent the line is appended.
- (void)patchCfgKey:(NSString *)key value:(NSString *)value inFile:(NSString *)cfgPath {
    [self patchCfgKeys:@{key: value} inFile:cfgPath];
}

/// Patches multiple keys in `cfgPath` in a single read-modify-write cycle.
/// Each key is replaced (or appended) using a regex matching `key = "..."` lines.
/// The file is only written when at least one value actually changes, avoiding
/// unnecessary I/O on repeated calls with the same values.
- (void)patchCfgKeys:(NSDictionary<NSString *, NSString *> *)patches inFile:(NSString *)cfgPath {
    NSError *err = nil;
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:cfgPath
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&err];
    if (!content) {
        ELOG(@"patchCfgKeys: failed to read %@: %@", cfgPath, err.localizedDescription);
        return;
    }

    BOOL didModify = NO;
    for (NSString *key in patches) {
        NSString *value = patches[key];
        NSString *newLine = [NSString stringWithFormat:@"%@ = \"%@\"", key, value];
        NSString *escapedKey = [NSRegularExpression escapedPatternForString:key];
        NSString *pattern = [NSString stringWithFormat:@"(?m)^[ \\t]*%@[ \\t]*=.*$", escapedKey];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                              options:0
                                                                                error:&err];
        if (!regex) {
            ELOG(@"patchCfgKeys: bad regex for key %@: %@", key, err.localizedDescription);
            continue;
        }
        NSTextCheckingResult *match = [regex firstMatchInString:content options:0
                                                          range:NSMakeRange(0, content.length)];
        if (match) {
            NSString *existing = [content substringWithRange:match.range];
            if (![existing isEqualToString:newLine]) {
                [content replaceCharactersInRange:match.range withString:newLine];
                didModify = YES;
            }
        } else {
            if (![content hasSuffix:@"\n"]) [content appendString:@"\n"];
            [content appendFormat:@"%@\n", newLine];
            didModify = YES;
        }
    }

    if (!didModify) {
        return;
    }

    NSError *writeErr = nil;
    BOOL ok = [content writeToFile:cfgPath atomically:YES encoding:NSUTF8StringEncoding error:&writeErr];
    if (!ok) {
        ELOG(@"patchCfgKeys: failed to write %@: %@", cfgPath, writeErr.localizedDescription);
    }
}

/// Reads the `retroArchMIDIEnabled` preference from NSUserDefaults (default: YES when absent)
/// and patches `midi_input` / `midi_output` in the user's retroarch.cfg accordingly.
/// Called at core startup when the user cfg already exists; on first run the bundled
/// retroarch.cfg already ships with "coremidi" as the default so no patch is needed.
/// Both keys are patched in a single read-modify-write cycle to avoid unnecessary I/O.
#if !TARGET_OS_TV
- (void)applyMIDIPreferenceToUserCfg:(NSString *)cfgPath {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL midiEnabled = YES;
    // Key matches PVSettingsModel's `retroArchMIDIEnabled` Defaults key.
    if ([ud objectForKey:@"retroArchMIDIEnabled"] != nil) {
        midiEnabled = [ud boolForKey:@"retroArchMIDIEnabled"];
    }
    NSString *deviceValue = midiEnabled ? @"coremidi" : @"Off";
    ILOG(@"Applying MIDI preference to cfg: midi_input/output = \"%@\"", deviceValue);
    [self patchCfgKeys:@{@"midi_input": deviceValue, @"midi_output": deviceValue}
                inFile:cfgPath];
}
#endif // !TARGET_OS_TV

/// Updates (or adds) `user_language = "N"` in the RetroArch config file at
/// `configPath` to match the language resolved from the `coreLanguage` user setting.
/// Called every time `writeConfigFile` runs so that locale changes take effect at
/// the next core launch without requiring a config reset.
- (void)applyUserLanguageToRetroArchConfig:(NSString *)configPath {
    NSInteger langID = [PVRetroArchCoreBridge resolvedUserLanguage];
    NSString *langValue = [NSString stringWithFormat:@"%ld", (long)langID];
    ILOG(@"applyUserLanguageToRetroArchConfig: setting user_language = %ld", (long)langID);
    [self patchCfgKey:@"user_language" value:langValue inFile:configPath];
}


- (void)setViewType:(apple_view_type_t)vt
{
    // This method creates UIViews and modifies the view hierarchy — must run on main thread.
    // RetroArch's threaded video driver calls metal_init from video_thread_loop (background thread).
    // Use dispatch_SYNC so the video thread blocks until the view is fully set up before it
    // attempts to render; dispatch_async caused a race where metal_frame ran before the Metal
    // render target was attached, producing a "no output textures" Metal validation crash.
    if (!NSThread.isMainThread) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self setViewType:vt];
        });
        return;
    }

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
    if (self.isShuttingDownForViewportUpdates) {
        WLOG(@"[RA] Skipping frame apply during shutdown");
        return;
    }

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

    if (!mtkView.window) {
        WLOG(@"[RA] MTKView not in window yet, skipping frame apply");
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
    if (!isfinite(scale) || scale <= 0) {
        WLOG(@"[RA] Invalid screen scale: %f", scale);
        return;
    }

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
    if (!isfinite(pixelSize.width) || !isfinite(pixelSize.height) || pixelSize.width < 1.0 || pixelSize.height < 1.0) {
        WLOG(@"[RA] Invalid pixel size: %@", NSStringFromCGSize(pixelSize));
        return;
    }
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
        settings->bools.video_scale_integer = PVSettingsWrapper.useIntegerScale;
        settings->bools.video_force_aspect = false;
        settings->uints.video_aspect_ratio_idx = ASPECT_RATIO_CORE;
        command_event(CMD_EVENT_VIDEO_SET_ASPECT_RATIO, NULL);

        unsigned int w = (unsigned)lrintf(pixelSize.width);
        unsigned int h = (unsigned)lrintf(pixelSize.height);
        if (w == 0 || h == 0) {
            WLOG(@"[RA] Skipping viewport update due to zero size: %ux%u", w, h);
            return;
        }
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
    self.isShuttingDownForViewportUpdates = NO;
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

    // Capture properties on the calling thread so they can be used safely in the
    // background block below.  All filesystem I/O (fileExistsAtPath, bundlePath,
    // checkROM, archive extraction) is deferred to the background queue to avoid
    // blocking the main thread.
    NSString *capturedRetroArchRoot    = self.retroArchRootPath;
    NSString *capturedCoreIdentifier   = [self coreIdentifier];
    NSString *capturedRomPath          = romPath;
    NSString *capturedSystemIdentifier = [self systemIdentifier];
    BOOL      capturedProcessingInit   = processing_init;
    if (capturedProcessingInit) processing_init = false;

    ILOG(@"startVM: coreIdentifier=%@, romPath=%@, systemIdentifier=%@, retroArchRoot=%@",
         capturedCoreIdentifier ?: @"(nil)", capturedRomPath ?: @"(nil)",
         capturedSystemIdentifier ?: @"(nil)", capturedRetroArchRoot ?: @"(nil)");

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];

	[self refreshSystemConfig];
	[self showGameView];

    // rarch_main blocks in video_thread_send_and_wait_user_to_thread while the
    // RetroArch video thread initialises. During that init the video thread calls
    // setViewType: via dispatch_sync(main_queue). If we are already on the main
    // thread that dispatch_sync deadlocks (main blocked waiting for video thread;
    // video thread blocked waiting for main). Run rarch_main on a background
    // thread so the main thread stays free to service those UI-setup dispatches.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *optConfig = [capturedRetroArchRoot stringByAppendingPathComponent:@"config/opt.cfg"];
        NSFileManager *fm = [[NSFileManager alloc] init];

        int bgArgc = 0;
        char **bgArgv = NULL;

        if (!capturedCoreIdentifier || [capturedCoreIdentifier isEqualToString:@"com.provenance.core.retroarch"] || !capturedRomPath) {
            if (capturedRomPath != nil && capturedRomPath.length > 0 && [fm fileExistsAtPath:capturedRomPath]) {
                optConfig = capturedRomPath;
            }
            bgArgc = 4;
            bgArgv = malloc(sizeof(char *) * (bgArgc + 1));
            bgArgv[0] = strdup("retroarch");
            bgArgv[1] = strdup(CORE_TYPE_PLAIN);
            bgArgv[2] = strdup("--appendconfig");
            bgArgv[3] = strdup(optConfig.UTF8String);
            bgArgv[4] = NULL;
            ILOG(@"startVM: plain core mode (no core identifier), optConfig=%@", optConfig);
        } else {
            NSString *mainBundlePath = [NSBundle mainBundle].bundlePath;
            // Pass the .framework directory to -L; RetroArch's dylib_load() natively
            // handles .framework bundles by resolving the inner Mach-O binary itself
            // (see dylib.c:131-143). Do NOT pass the inner binary path directly.
            NSString *sysPath = [NSString stringWithFormat:@"%@/Frameworks/%@", mainBundlePath, capturedCoreIdentifier];

            ILOG(@"startVM: mainBundlePath=%@", mainBundlePath);
            ILOG(@"startVM: coreIdentifier=%@", capturedCoreIdentifier);
            ILOG(@"startVM: framework path=%@", sysPath);

            if ([fm fileExistsAtPath:sysPath]) {
                ILOG(@"Found Module %@\n", sysPath);
            } else {
                ELOG(@"Error: No module found at %@ (Core.plist PVCoreIdentifier: %@)\n", sysPath, capturedCoreIdentifier);
                NSString *fwParent = [mainBundlePath stringByAppendingPathComponent:@"Frameworks"];
                NSArray *contents = [fm contentsOfDirectoryAtPath:fwParent error:nil];

                // Log partial matches so we can see similar framework names
                NSString *coreStem = [capturedCoreIdentifier stringByDeletingPathExtension]; // e.g. "a5200.libretro"
                NSMutableArray *partialMatches = [NSMutableArray new];
                for (NSString *item in contents) {
                    if ([item.lowercaseString containsString:coreStem.lowercaseString] ||
                        [item.lowercaseString containsString:@"libretro"] ||
                        [item.lowercaseString containsString:@"retroarch"]) {
                        [partialMatches addObject:item];
                    }
                }
                ELOG(@"Looking for: '%@' in %@/Frameworks/ (%lu total)",
                     capturedCoreIdentifier, mainBundlePath, (unsigned long)contents.count);
                ELOG(@"Related frameworks: %@",
                     partialMatches.count > 0 ? [partialMatches componentsJoinedByString:@", "] : @"NONE found");
                ILOG(@"All frameworks: %@", [contents componentsJoinedByString:@", "]);

                // Post OSD error so user sees it on screen
                [PVOSDNotification postMessage:[NSString stringWithFormat:@"Core not found: %@", capturedCoreIdentifier]
                                          type:PVOSDTypeError
                                      duration:5.0];

                // Don't proceed — rarch_main will just fail after a long wait
                ELOG(@"Aborting startVM: core framework not present in this build");
                return;
            }

            NSString *resolvedRomPath = capturedRomPath;
            if ([fm fileExistsAtPath:resolvedRomPath]) {
                resolvedRomPath = [self checkROM:resolvedRomPath];
                WLOG(@"Found Game %s\n", resolvedRomPath.UTF8String);
            } else {
                ELOG(@"No game found at path: %@", resolvedRomPath);
            }

            bgArgc = 7;
            bgArgv = malloc(sizeof(char *) * (bgArgc + 1));
            bgArgv[0] = strdup("retroarch");
            bgArgv[1] = strdup("-L");
            bgArgv[2] = strdup(sysPath.stringByStandardizingPath.UTF8String);
            bgArgv[3] = strdup(resolvedRomPath.stringByStandardizingPath.UTF8String);
            bgArgv[4] = strdup("--appendconfig");
            bgArgv[5] = strdup(optConfig.UTF8String);
            bgArgv[6] = strdup("--verbose");
            bgArgv[7] = NULL;
            ILOG(@"Loading %s %s\n", bgArgv[2], bgArgv[3]);
        }

        if (capturedProcessingInit) {
            ILOG(@"startVM: Extracting assets.zip to %@", capturedRetroArchRoot);
            [PVOSDNotification postMessage:@"Extracting RetroArch assets…" type:PVOSDTypeInfo duration:0];
            /// Use overwrite:NO so we don't delete the entire retroArchRootPath (which
            /// contains config/retroarch.cfg written moments ago by writeConfigFile).
            /// overwrite:YES was nuking the config every boot, causing rarch_main to fail
            /// with "Config not found" and preventing cores from ever initializing.
            [self extractArchive:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"assets.zip" ofType:nil] toDestination:capturedRetroArchRoot overwrite:false];
        }

        // Log the full argv for debugging
        ILOG(@"startVM: optConfig=%@", optConfig);
        ILOG(@"startVM: optConfig exists=%d", [fm fileExistsAtPath:optConfig]);
        NSString *retroarchCfg = [capturedRetroArchRoot stringByAppendingPathComponent:@"config/retroarch.cfg"];
        ILOG(@"startVM: retroarch.cfg=%@, exists=%d", retroarchCfg, [fm fileExistsAtPath:retroarchCfg]);
        for (int i = 0; i < bgArgc; i++) {
            ILOG(@"startVM: argv[%d]=%s", i, bgArgv[i]);
        }

        [PVOSDNotification postMessage:@"Starting RetroArch…" type:PVOSDTypeInfo duration:0];
        int rarchResult = rarch_main(bgArgc, bgArgv, NULL);

        for (int i = 0; i < bgArgc; i++) { free(bgArgv[i]); }
        free(bgArgv);

        if (rarchResult != 0) {
            ELOG(@"startVM: rarch_main returned error %d — skipping observer and joypad setup to prevent crash", rarchResult);
            [PVOSDNotification postMessage:[NSString stringWithFormat:@"RetroArch failed to start (error %d)", rarchResult]
                                      type:PVOSDTypeError
                                  duration:5.0];
            return;
        }

        ILOG(@"startVM: rarch_main returned successfully, setting up observer and joypad");
        _isInitialized = true;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
            runloop_state_t *runloop_st = runloop_state_get_ptr();
            runloop_st->flags &= ~RUNLOOP_FLAG_OVERRIDES_ACTIVE;
        });
        // Drive RetroArch's frame loop on a dedicated emulation thread so a
        // long-running runloop_iterate (netplay handshake, blocking task) cannot
        // block the main thread / UI.
        pv_retro_emu_thread_start();
        CFRunLoopRef emuRL = pv_retro_emu_thread_runloop();
        if (!emuRL) {
            ELOG(@"startVM: emulation thread runloop not available, falling back to main");
            emuRL = CFRunLoopGetMain();
        }
        iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting, true, 0, rarch_draw_observer, 0);
        CFRunLoopAddObserver(emuRL, iterate_observer, kCFRunLoopCommonModes);
        CFRunLoopWakeUp(emuRL);
        apple_gamecontroller_joypad_init(NULL);
        [self setupJoypad];
    });
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
    self.isShuttingDownForViewportUpdates = NO;

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
        if (self.isShuttingDownForViewportUpdates) {
            DLOG(@"[RA] Skipping delayed showGameView work during shutdown");
            return;
        }
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
                if (self.isShuttingDownForViewportUpdates) {
                    DLOG(@"[RA] Skipping update trigger during shutdown");
                    return;
                }
                [self triggerRetroArchResourceUpdates];
                // Resume after updates are triggered (they run in background)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    if (self.isShuttingDownForViewportUpdates) {
                        DLOG(@"[RA] Skipping unpause during shutdown");
                        return;
                    }
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
   (void)mode;
   void (^apply)(void) = ^{
      MetalView *metalView = (MetalView *)_renderView;
      if (!metalView)
         return;
      CGFloat scale = [[UIScreen mainScreen] scale];
      [metalView setDrawableSize:CGSizeMake(
                                             _renderView.bounds.size.width * scale,
                                             _renderView.bounds.size.height * scale
                                             )];
   };
   if ([NSThread isMainThread])
      apply();
   else
      dispatch_sync(dispatch_get_main_queue(), apply);
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
-(NSString*)retroArchRootPath {
    return [self.documentsDirectory stringByAppendingPathComponent:@"RetroArch"];
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
			self.batterySavesPath = [self.retroArchRootPath stringByAppendingPathComponent:@"config"];
			NSString *fileName = [NSString stringWithFormat:@"%@/config/retroarch.cfg",
                                  self.retroArchRootPath];
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

   pv_retro_emu_thread_start();
   CFRunLoopRef emuRL = pv_retro_emu_thread_runloop();
   if (!emuRL)
       emuRL = CFRunLoopGetMain();

   iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting,
                                              true, 0, rarch_draw_observer, 0);
   CFRunLoopAddObserver(emuRL, iterate_observer, kCFRunLoopCommonModes);
   CFRunLoopWakeUp(emuRL);
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
   /* Guard against calling runloop_iterate before rarch_main has initialised
    * the video driver.  If the driver data pointer is NULL we would crash in
    * vulkan_alive / gl_alive / etc.  This can happen if the observer is fired
    * before init completes or after a failed init. */
   if (!_isInitialized) {
       return;
   }

   /* When the core is paused+idle (Provenance pause menu is showing),
    * skip runloop_iterate entirely so the main thread stays responsive
    * for SwiftUI / UIKit event handling. */
   uint32_t pre_flags = runloop_get_flags();
   if (pre_flags & RUNLOOP_FLAG_IDLE) {
       return;
   }

   uint32_t runloop_flags;
   // Route through PVRetroArchCore+ExceptionTrampoline.mm so a C++
   // exception thrown from inside the dlopened libretro core (most
   // commonly `vk::DeviceLostError` from a core's own Vulkan-HPP
   // layer on iOS GPU pressure) is caught at the dylib boundary
   // instead of propagating up to `_objc_terminate` → `abort` and
   // killing the entire app. See PVRetroArchCore+ExceptionTrampoline.h
   // for the API. -1 here matches runloop_iterate's "exit loop" return.
   int          ret   = pv_safe_runloop_iterate();
   if (ret == -1) {
	   command_event(CMD_EVENT_MENU_SAVE_CURRENT_CONFIG, NULL);
       ILOG(@"exit loop\n");
	   return;
   }

    task_queue_check();

   runloop_flags = runloop_get_flags();
   if (!(runloop_flags & RUNLOOP_FLAG_IDLE)) {
      // Self-wake the emulation thread runloop so the observer fires again on
      // the next sleep cycle. Without this the runloop would idle indefinitely
      // since no source (CADisplayLink etc.) is attached to the emu thread.
      CFRunLoopWakeUp(CFRunLoopGetCurrent());
   }
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
