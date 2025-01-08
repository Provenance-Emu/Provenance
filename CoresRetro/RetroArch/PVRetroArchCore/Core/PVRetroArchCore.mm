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
#import <PVRetroArch/RetroArch-Swift.h>

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
- (instancetype)init {
	if (self = [super init]) {
        self.skipLayout = true;
        self.extractArchive = false;
        PVRetroArchCoreCore.systemName = self.systemIdentifier;
        PVRetroArchCoreCore.coreClassName = self.coreIdentifier;

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
    PVRetroArchCoreCore.systemName = self.systemIdentifier;
    PVRetroArchCoreCore.coreClassName = self.coreIdentifier;

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
