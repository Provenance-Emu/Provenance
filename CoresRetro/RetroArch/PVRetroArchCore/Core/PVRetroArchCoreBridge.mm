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
#import <PVRetroArch/PVRetroArch-Swift.h>

#import <Foundation/Foundation.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>
#import <PVLogging/PVLoggingObjC.h>

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

#include "./cocoa_common.h"
#include "./apple_platform.h"
#include "../ui_companion_driver.h"
#include "../../configuration.h"
#include "../../frontend/frontend.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../input/drivers_keyboard/keyboard_event_apple.h"
#include "../../retroarch.h"
#include "../../command.h"
#include "../../verbosity.h"

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#endif
#import <AVFoundation/AVFoundation.h>

__weak PVRetroArchCoreBridge *_current;
bool _isInitialized;
extern int g_gs_preference;

#pragma mark - Private
@interface PVRetroArchCoreBridge() {
}
@end

#pragma mark - PVRetroArchCoreBridge Begin
@implementation PVRetroArchCoreBridge {
	NSString *autoLoadStatefileName;
}
@dynamic documentsDirectory;

- (instancetype)init {
	if (self = [super init]) {
        self.skipLayout = true;
        self.extractArchive = false;
        
        PVRetroArchCoreBridge.systemName = self.systemIdentifier;
        PVRetroArchCoreBridge.coreClassName = self.coreIdentifier;
        ILOG(@"PVRetroArchCoreBridge.coreClassName: %@, coreClassName: %@", PVRetroArchCoreBridge.systemName, PVRetroArchCoreBridge.coreClassName);
        [self parseOptions];
		CGRect bounds=[[UIScreen mainScreen] bounds];
		_videoWidth  = bounds.size.width;
		_videoHeight = bounds.size.height;
		_videoBitDepth = 32;
		sampleRate = 48000;
		self->resFactor = 1;
        self.ffSpeed = 300;
        self.smSpeed = 300;
        isNTSC = YES;
		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
		_callbackQueue = dispatch_queue_create("org.provenance-emu.pvretroarchcore.CallbackHandlerQueue", queueAttributes);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
		g_gs_preference = self.gsPreference;
		[self setRootView:false];
        [CocoaView get];
        
        [self setupEmulation];
        
        xAxis = yAxis = ltXAxis = ltYAxis = rtXAxis = rtYAxis = 0.0;
        axisMult = 1.0;
	}
	_current=self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    self.alwaysUseMetal = true;
    self.skipLayout = true;
    self.extractArchive = false;

    PVRetroArchCoreBridge.systemName = self.systemIdentifier;
    PVRetroArchCoreBridge.coreClassName = self.coreIdentifier;
    [self parseOptions];
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
	NSString *configPath = self.saveStatesPath;
	const char * dataPath = [[coreBundle resourcePath] fileSystemRepresentation];
	[[NSFileManager defaultManager] createDirectoryAtPath:configPath
							  withIntermediateDirectories:YES
											   attributes:nil
													error:nil];
	NSString *batterySavesDirectory = self.batterySavesPath;
	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
							  withIntermediateDirectories:YES
											   attributes:nil
													error:NULL];
    romPath = [[path copy] stringByStandardizingPath];
	return YES;
}
-(void)startHaptic { }
-(void)stopHaptic { }
-(void)resetEmulation {
    command_event(CMD_EVENT_RESET, NULL);
}
-(void)optionUpdated:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    for (NSString* key in info.allKeys) {
        NSString *value=[info valueForKey:key];
        [self processOption:key value:value];
        ILOG(@"Received Option key:%s value:%s\n",key.UTF8String, value.UTF8String);
    }
}
-(void)processOption:(NSString *)key value:(NSString*)value {
    typedef void (^Process)();
    NSDictionary *actions = @{
        @USE_RETROARCH_CONTROLLER:
        ^{
            [self useRetroArchController:[value isEqualToString:@"true"]];
        },
        @ENABLE_ANALOG_KEY:
        ^{
            self.bindAnalogKeys=[value isEqualToString:@"true"];
        },
        @ENABLE_NUM_KEY:
        ^{
            self.bindNumKeys=[value isEqualToString:@"true"];
        },
        @ENABLE_ANALOG_DPAD:
        ^{
            self.bindAnalogDpad=[value isEqualToString:@"true"];
            [self setupJoypad];
        },
        @"Audio Volume":
        ^{
            [self setVolume];
        },
        @USE_SECOND_SCREEN:
        ^{
            [value isEqualToString:@"true"] ? [self useSecondaryScreen] : [self usePrimaryScreen];
        },
        @"Fast Forward Speed":
        ^{
            self.ffSpeed = value.intValue;
            [self setSpeed];
        },
        @"Slow Motion Speed":
        ^{
            self.smSpeed = value.intValue;
            [self setSpeed];
        },
        @"System Model":
        ^{
            [self parseOptions];
        }
    };
    Process action=[actions objectForKey:key];
    if (action)
        action();
}
@end

@implementation PVRetroArchCoreBridge (CoreOptions)

+ (core_option_manager_t  * _Nullable ) getOptions {
    struct core_option *option      = NULL;
    core_option_manager_t *coreopts = NULL;
    retroarch_ctl(RARCH_CTL_CORE_OPTIONS_LIST_GET, &coreopts);

    if (coreopts) {
        int numberOfGroups = coreopts->cats_size;
        int numberOfRootOptions = coreopts->size;
    }
    return coreopts;
}

@end

// Disc swap
@implementation PVRetroArchCoreBridge (DiscSwappable)

- (unsigned long) numberOfDiscs {
    unsigned images               = 0;
    unsigned current              = 0;
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;

    if (!sys_info)
       return 1;

    if (!disk_control_enabled(&sys_info->disk_control))
       return 1;

    images  = disk_control_get_num_images(&sys_info->disk_control);
    return images;
}

- (BOOL) currentGameSupportsMultipleDiscs {
    unsigned images               = 0;
    unsigned current              = 0;
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;

    if (!sys_info)
       return NO;

    if (!disk_control_enabled(&sys_info->disk_control))
       return NO;

    images  = disk_control_get_num_images(&sys_info->disk_control);
    current = disk_control_get_image_index(&sys_info->disk_control);
    return images > 1;
}

- (void) swapDiscWithNumber:(NSUInteger)number {
    unsigned disk_index = number - 1;
    
    [self setEjected:true];
    BOOL success = runloop_environment_cb(CMD_EVENT_DISK_INDEX, &disk_index);
    MAKEWEAK(self);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        MAKESTRONG_RETURN_IF_NIL(self);
        [self setEjected:false];
    });
}

- (void)toggleEjectState {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;

    if (!sys_info)
       return;

    if (disk_control_enabled(&sys_info->disk_control))
    {
        bool eject                      = !disk_control_get_eject_state(
                                                                        &sys_info->disk_control);
 
        
        bool verbose = true;
        bool success = disk_control_set_eject_state(
                                     &sys_info->disk_control, eject, verbose);
        
#ifdef HAVE_AUDIOMIXER
      audio_driver_mixer_play_menu_sound(AUDIO_MIXER_SYSTEM_SLOT_OK);
#endif
    }
}

- (void)setEjected:(BOOL)eject {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;

    if (!sys_info)
       return;

    if (disk_control_enabled(&sys_info->disk_control))
    {
        bool verbose = true;
        disk_control_set_eject_state(
                                     &sys_info->disk_control, eject, verbose);
        
#ifdef HAVE_AUDIOMIXER
      audio_driver_mixer_play_menu_sound(AUDIO_MIXER_SYSTEM_SLOT_OK);
#endif
    }
}

- (BOOL) isEjected {
    rarch_system_info_t *sys_info = &runloop_state_get_ptr()->system;

    if (!sys_info)
       return NO;
    
    return disk_control_get_eject_state(&sys_info->disk_control);
}
@end
