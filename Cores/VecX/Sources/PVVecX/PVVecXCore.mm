//
//  PVVecXCore.m
//  PVVecX
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVVecXCore.h"
#include <stdatomic.h>
#import "PVVecXCore+Controls.h"
#import "PVVecXCore+Audio.h"
#import "PVVecXCore+Video.h"

#import "PVVecXCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVVecX/PVVecX-Swift.h>
@import PVCoreBridge;
#import <PVLogging/PVLogging.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVVecXCoreBridge() {

}

@end

#pragma mark - PVVecXCore Begin

@implementation PVVecXCoreBridge
{
}

- (instancetype)init {
	if (self = [super init]) {
        pitch_shift = 1;
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//    BOOL loaded = [super loadFileAtPath:path completionHandler:error];
//
//    return loaded;
//}

#pragma mark - Running
//- (void)startEmulation {
//	if (!_isInitialized)
//	{
//		[self.renderDelegate willRenderFrameOnAlternateThread];
//        _isInitialized = true;
//		_frameInterval = dol_host->GetFrameInterval();
//	}
//	[super startEmulation];
//
	//Disable the OE framelimiting
//	[self.renderDelegate suspendFPSLimiting];
//	if(!self.isRunning) {
//		[super startEmulation];
////        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
//	}
//}

//- (void)setPauseEmulation:(BOOL)flag {
//	[super setPauseEmulation:flag];
//}
//
//- (void)stopEmulation {
//	_isInitialized = false;
//
//	self->shouldStop = YES;
////	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
////    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//
//	[super stopEmulation];
//}
//
//- (void)resetEmulation {
//	//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//}

//# pragma mark - Cheats
//- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
//}
//
//- (BOOL)supportsRumble { return NO; }
//- (BOOL)supportsCheatCode { return NO; }
#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"Vecx getVariable: %s", variable);
    
    #define V(x) strcmp(variable, x) == 0
    
    id value = [VecxOptions getVariable:[NSString stringWithUTF8String:variable]];
    if (!value) {
        // Handle legacy/special cases that aren't in the options class
        if (V("VecX_pure_memory_size")) {
            return strdup("16");
        } else if (V("VecX_pure_cpu_type")) {
            return strdup("auto");
        } else if (V("VecX_pure_cpu_core")) {
            return strdup("auto");
        } else if (V("VecX_pure_keyboard_layout")) {
            return strdup("us");
        } else {
            ELOG(@"Unprocessed Vecx var: %s", variable);
            return NULL;
        }
    }
    
    // Convert the value to the expected C string format
    NSString *stringValue;
    if ([value isKindOfClass:[NSNumber class]]) {
        // Handle numeric values
        if (V("vecx_res_multi") ||
            V("vecx_line_brightness") ||
            V("vecx_line_width") ||
            V("vecx_bloom_brightness")) {
            stringValue = [value stringValue];
        }
    } else if ([value isKindOfClass:[NSString class]]) {
        if (V("vecx_use_hw")) {
            // Convert our friendly names back to libretro values
            NSDictionary *renderMap = @{
                @"Software": @"Software",
                @"Hardware": @"Hardware"
            };
            stringValue = renderMap[value] ?: value;
        } else if (V("vecx_res_hw") ||
                  V("vecx_bloom_width") ||
                  V("vecx_scale_x") ||
                  V("vecx_scale_y") ||
                  V("vecx_shift_x") ||
                  V("vecx_shift_y")) {
            // Use the string value directly for these options
            stringValue = value;
        }
    }
    
    if (stringValue) {
        return strdup([stringValue UTF8String]);
    }
    
    #undef V
    return NULL;
}

@end
