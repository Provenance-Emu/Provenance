//
//  PVRetroArchCore.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Controls.h"
#import "PVRetroArchCore+Audio.h"
#import "PVRetroArchCore+Video.h"
#import <PVRetroArch/RetroArch-Swift.h>

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVLogging.h>

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

__weak PVRetroArchCore *_current;
bool _isInitialized;
extern int g_gs_preference;

#pragma mark - Private
@interface PVRetroArchCore() {
}
@end

#pragma mark - PVRetroArchCore Begin
@implementation PVRetroArchCore {
	NSString *autoLoadStatefileName;
}
- (instancetype)init {
	if (self = [super init]) {
        self.alwaysUseMetal = true;
		CGRect bounds=[[UIScreen mainScreen] bounds];
		_videoWidth  = bounds.size.width;
		_videoHeight = bounds.size.height;
		_videoBitDepth = 32;
		sampleRate = 44100;
		self->resFactor = 1;
		self->gsPreference = 0;
		isNTSC = YES;
		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
		_callbackQueue = dispatch_queue_create("org.provenance-emu.pvretroarchcore.CallbackHandlerQueue", queueAttributes);
		g_gs_preference = self.gsPreference;
		[self setRootView:false];
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
	romPath = [path copy];
	return YES;
}
-(void)startHaptic { }
-(void)stopHaptic { }
-(void)resetEmulation { }
@end
