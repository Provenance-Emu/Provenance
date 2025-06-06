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

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#endif
#import <AVFoundation/AVFoundation.h>
#import <PVLogging/PVLoggingObjC.h>

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
apple_view_type_t _vt;
extern bool _isInitialized;
extern bool firstLoad;
char **argv;
int argc =  1;

#pragma mark - PVRetroArchCoreBridge Begin

#ifdef HAVE_COCOA_METAL
// TODO: Use me in Vulkan mode and change the code I edited in the past
// to workaround this not being the layer @JoeMatt
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

@interface PVRetroArchCoreBridge (RetroArchUI)
@end

@implementation PVRetroArchCoreBridge (RetroArchUI)

- (void)initialize {
    [super initialize];
//    [self setupEmulation];
    ILOG(@"RetroArch: Extract %d\n", self.extractArchive);
}

- (void)setupEmulation {
    self.alwaysUseMetal = true;
    self.skipLayout = true;
    [self parseOptions];
    settings_t *settings = config_get_ptr();
    if (!settings) {
        retroarch_config_init();
        config_set_defaults(global_get_ptr());
        frontend_darwin_get_env(argc, argv, NULL, NULL);
        dir_check_defaults(NULL);
    }
    [self writeConfigFile];
    [self syncResources:self.BIOSPath
                     to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/system" ]];
}

- (void)startEmulation {
	@autoreleasepool {
        _current=self;
        firstLoad=true;
		self.skipEmulationLoop = true;
		[self setupEmulation];
		[self setOptionValues];
		[self startVM:_renderView];
        [self setupControllers];
		[super startEmulation];
	};
}

- (void)setPauseEmulation:(BOOL)flag {
    if (!EmulationState.shared.isOn) {
        WLOG(@"Core isn't set to \"on\", skipping set pause : %i", flag);
        return;
    }
    command_event(flag ? CMD_EVENT_PAUSE : CMD_EVENT_UNPAUSE, NULL);
    runloop_state_t *runloop_st = runloop_state_get_ptr();
    if (flag) {
        ILOG(@"RetroArch: Pause\n");
        runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
        runloop_st->flags &= ~RUNLOOP_FLAG_SLOWMOTION;
        runloop_st->flags |= RUNLOOP_FLAG_PAUSED;
        runloop_st->flags |= RUNLOOP_FLAG_IDLE;
    } else {
        ILOG(@"RetroArch: UnPause\n");
        runloop_st->flags &= ~RUNLOOP_FLAG_FASTMOTION;
        runloop_st->flags &= ~RUNLOOP_FLAG_SLOWMOTION;
        runloop_st->flags &= ~RUNLOOP_FLAG_PAUSED;
        runloop_st->flags &= ~RUNLOOP_FLAG_IDLE;
        [self setSpeed];
    }
    [super setPauseEmulation:flag];
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        settings_t *settings = config_get_ptr();
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
    });
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
    [[[[UIApplication sharedApplication] delegate] window] makeKeyAndVisible];
}
- (void)setOptionValues {
    [PVRetroArchCoreBridge synchronizeOptionsWithRetroArch];
	g_gs_preference = self.gsPreference;
}

void extract_bundles();
-(void) writeConfigFile {
    
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

    BOOL shouldUpdateAssets = [self shouldUpdateAssets];
    ILOG(@"Should update assets: %@", shouldUpdateAssets ? @"YES" : @"NO");

    if (!configFileExists || !versionFileExists || shouldUpdateAssets) {

        ILOG(@"Writing config file to %@", fileName);

        NSString *src = [[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"retroarch.cfg" ofType:nil];
        [self syncResource:src to:fileName];
        [self syncResource:src to:verFile];

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

        processing_init=true;
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

    [self syncResources:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"pv_ui_overlay" ofType:nil]
                     to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/overlays/pv_ui_overlay" ]];
    [self syncResource:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"pv_ui_overlay/pv_ui.cfg" ofType:nil]
                     to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/overlays/pv_ui_overlay/pv_ui.cfg" ]];
    [self syncResources:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"mame_plugins" ofType:nil]
                     to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/system/mame/plugins" ]];
    [self syncResource:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"hatari.cfg" ofType:nil]
                     to:[self.documentsDirectory stringByAppendingPathComponent:@"/RetroArch/system/hatari.cfg" ]];

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
    if ([fm fileExistsAtPath: file]) {
        unsigned long long fileSize = [[fm attributesOfItemAtPath:file error:nil] fileSize];
        ILOG(@"File size: %llu", fileSize);
//        if (fileSize == 1687) {
//            ILOG(@"File size is 1687, returning false");
            return false;
//        }
    }
    ILOG(@"File does not exist or size is not 1687, returning true");
    return true;
// #endif
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
    ILOG(@"Syncing %@ to %@", from, to);
	NSError *error;
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSArray* files = [fm contentsOfDirectoryAtPath:from error:&error];
    if (![fm fileExistsAtPath: to]) {
        ILOG(@"Creating directory at %@", to);

        [fm createDirectoryAtPath:to withIntermediateDirectories:true attributes:nil error:&error];
        if (error) {
            ELOG(@"Error creating directory at %@: %@", to, error.localizedDescription);
        } else {
            ILOG(@"Directory created at %@", to);
        }
    }
	for (NSString *file in files) {
		NSString *src=  [NSString stringWithFormat:@"%@/%@", from, file];
		NSString *dst = [NSString stringWithFormat:@"%@/%@", to, file];
        ILOG(@"Syncing %@ %@", src, dst);
		if (![fm fileExistsAtPath: dst]) {
            ILOG(@"Copying %@ to %@", src, dst);
            NSError *error;
			[fm copyItemAtPath:src toPath:dst error:&error];
            if (error) {
                ELOG(@"Error copying %@ to %@: %@", src, dst, error.localizedDescription);
            } else {
                ILOG(@"Copied %@ to %@", src, dst);
            }
		}
	}
}

- (void)syncResource:(NSString*)from to:(NSString*)to {
    if (!from) {
        ELOG(@"From path is nil");
        return;
    }
    ILOG(@"Syncing %@ to %@", from, to);
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSData *fileData = [NSData dataWithContentsOfFile:from];
    [fileData writeToFile:to atomically:NO];
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
//            v.autoresizesSubviews=true;
//            v.autoResizeDrawable=true;
//            v.contentMode=UIViewContentModeScaleToFill;
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

    _renderView.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *rootView = [CocoaView get].view;
    [rootView addSubview:_renderView];
    [[_renderView.safeAreaLayoutGuide.topAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.topAnchor] setActive:YES];
    [[_renderView.safeAreaLayoutGuide.bottomAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.bottomAnchor] setActive:YES];
    [[_renderView.safeAreaLayoutGuide.leadingAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.leadingAnchor] setActive:YES];
    [[_renderView.safeAreaLayoutGuide.trailingAnchor constraintEqualToAnchor:rootView.safeAreaLayoutGuide.trailingAnchor] setActive:YES];
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
        [self extractArchive:[[NSBundle bundleForClass:[PVRetroArchCoreBridge class]] pathForResource:@"assets.zip" ofType:nil] toDestination:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch"] overwrite:true];
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
    ILOG(@"Set:METAL VULKAN OPENGLES:Attaching View Controller\n");
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
            [self.touchViewController.view addSubview:self.view];
            [self.touchViewController addChildViewController:rootController];
            [rootController didMoveToParentViewController:self.touchViewController];
            [self.touchViewController.view sendSubviewToBack:self.view];
            [rootController.view setHidden:false];
            if (IS_IPHONE())
                rootController.view.translatesAutoresizingMaskIntoConstraints = true;
            else {
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
            [gl_view_controller.view addSubview:self.view];
            [gl_view_controller addChildViewController:rootController];
            [rootController didMoveToParentViewController:gl_view_controller];
            [rootController.view setHidden:false];
            if (IS_IPHONE())
                rootController.view.translatesAutoresizingMaskIntoConstraints = true;
            else {
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
    
#if TARGET_OS_IOS
//    [self.touchViewController.navigationController setToolbarHidden:true animated:NO];
   [[UIApplication sharedApplication] setStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
   [[UIApplication sharedApplication] setIdleTimerDisabled:true];
#endif
    
    [self setupWindow];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self setVolume];
		command_event(CMD_EVENT_AUDIO_START, NULL);
        command_event(CMD_EVENT_UNPAUSE, NULL);
        [self useRetroArchController:self.retroArchControls];
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
   task_queue_check();
   if (ret == -1) {
	   command_event(CMD_EVENT_MENU_SAVE_CURRENT_CONFIG, NULL);
       ILOG(@"exit loop\n");
	   return;
   }
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
