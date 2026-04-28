//
//  PVYabauseCore.m
//  PVYabause
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVYabauseCore.h"
#include <stdatomic.h>
//#import "PVYabauseCore+Controls.h"
//#import "PVYabauseCore+Audio.h"
//#import "PVYabauseCore+Video.h"
//
//#import "PVYabauseCore+Audio.h"

#import <Foundation/Foundation.h>
@import PVCoreBridge;

// libretro.h is pulled in transitively via PVCoreBridgeRetro/PVCoreBridgeRetro.h
// (imported by PVYabauseCore.h), giving us RETRO_DEVICE_ID_JOYPAD_* constants and
// access to the inherited @public _pad[2][16] ivar from PVLibRetroCoreBridge.

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVYabauseCoreBridge() {

}

@end

#pragma mark - PVYabauseCore Begin

@implementation PVYabauseCoreBridge
{
}

- (instancetype)init {
	if (self = [super init]) {
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
//	const char *dataPath;
//
//    [self initControllBuffers];
//
//	// TODO: Proper path
//	NSString *configPath = self.saveStatesPath;
//	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];
//
//	[[NSFileManager defaultManager] createDirectoryAtPath:configPath
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:nil];
//
//	NSString *batterySavesDirectory = self.batterySavesPath;
//	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:NULL];
//
//    return YES;
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

- (NSTimeInterval)frameInterval {
    return 13.63;
}

- (CGSize)aspectSize {
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize {
    return CGSizeMake(1440, 1080);
}

- (GLenum)pixelFormat {
    return GL_RGB;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    return GL_RGB565;
}

# pragma mark - Audio

- (double)audioSampleRate {
    return 22255;
}

#pragma mark - Saturn Controls

// Saturn → RetroPad mapping for Yabause libretro core. Verified against upstream
// libretro.c desc[] (yabause/src/libretro/libretro.c lines ~566-578):
//   A→Y(1) B→B(0) C→A(8) X→L(10) Y→X(9) Z→R(11) L→L2(12) R→R2(13) Start→START(3)
// Array is indexed by PVSaturnButton enum ordinal (NOT by RETRO_DEVICE_ID_JOYPAD_*) —
// the two orderings differ. leftAnalog/count map to -1 (skipped). _pad[2][16] is the
// inherited @public ivar from PVLibRetroCoreBridge that input_state_callback reads.
static const int PVSaturnButtonToRetroPad[] = {
    RETRO_DEVICE_ID_JOYPAD_UP,    // up
    RETRO_DEVICE_ID_JOYPAD_DOWN,  // down
    RETRO_DEVICE_ID_JOYPAD_LEFT,  // left
    RETRO_DEVICE_ID_JOYPAD_RIGHT, // right
    RETRO_DEVICE_ID_JOYPAD_Y,     // a
    RETRO_DEVICE_ID_JOYPAD_B,     // b
    RETRO_DEVICE_ID_JOYPAD_A,     // c
    RETRO_DEVICE_ID_JOYPAD_L,     // x
    RETRO_DEVICE_ID_JOYPAD_X,     // y
    RETRO_DEVICE_ID_JOYPAD_R,     // z
    RETRO_DEVICE_ID_JOYPAD_L2,    // l
    RETRO_DEVICE_ID_JOYPAD_R2,    // r
    RETRO_DEVICE_ID_JOYPAD_START, // start
    -1,                           // leftAnalog
    -1,                           // count
};

- (void)didPushSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player {
    if (player < 0 || player >= 2) { return; }
    if (button < 0 || button >= PVSaturnButtonCount) { return; }
    int retroId = PVSaturnButtonToRetroPad[button];
    if (retroId < 0) { return; }
    _pad[player][retroId] = 1;
}

- (void)didReleaseSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player {
    if (player < 0 || player >= 2) { return; }
    if (button < 0 || button >= PVSaturnButtonCount) { return; }
    int retroId = PVSaturnButtonToRetroPad[button];
    if (retroId < 0) { return; }
    _pad[player][retroId] = 0;
}

- (void)didMoveSaturnJoystickDirection:(enum PVSaturnButton)button
                            withXValue:(CGFloat)xValue
                            withYValue:(CGFloat)yValue
                             forPlayer:(NSInteger)player {
    // Saturn analog stick (3D Control Pad). Only the left analog is used; right
    // stick has no Saturn equivalent. Yabause currently treats the digital pad as
    // primary input — analog support requires a port-device switch which is left
    // as a future enhancement. Convert obvious axis pushes to D-pad presses so the
    // analog stick is at least usable for movement.
    if (player < 0 || player >= 2) { return; }
    const CGFloat threshold = 0.5;
    _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT]  = (xValue < -threshold) ? 1 : 0;
    _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = (xValue >  threshold) ? 1 : 0;
    _pad[player][RETRO_DEVICE_ID_JOYPAD_UP]    = (yValue >  threshold) ? 1 : 0;
    _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN]  = (yValue < -threshold) ? 1 : 0;
}

@end
