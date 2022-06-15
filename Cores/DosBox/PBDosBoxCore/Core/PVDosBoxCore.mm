//
//  PVDosBoxCore.m
//  PVDosBox
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVDosBoxCore.h"
#include <stdatomic.h>
#import "PVDosBoxCore+Controls.h"
#import "PVDosBoxCore+Audio.h"
#import "PVDosBoxCore+Video.h"

#import "PVDosBoxCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

__weak PVDosBoxCore *_current = 0;

#pragma mark - Private
@interface PVDosBoxCore() {

}

@end

#pragma mark - PVDosBoxCore Begin

@implementation PVDosBoxCore
{
	uint16_t *_soundBuffer;
	atomic_bool _isInitialized;
	float _frameInterval;

	NSString *autoLoadStatefileName;
}

- (instancetype)init {
	if (self = [super init]) {
		_videoWidth  = 640;
		_videoHeight = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO

		sampleRate = 44100;

		isNTSC = YES;
        _frameInterval = 60;
        
		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);

		_callbackQueue = dispatch_queue_create("org.provenance-emu.dosbox.CallbackHandlerQueue", queueAttributes);
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
	const char *dataPath;

    [self initControllBuffers];

	// TODO: Proper path
	NSString *configPath = self.saveStatesPath;
	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];

	[[NSFileManager defaultManager] createDirectoryAtPath:configPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

	NSString *batterySavesDirectory = self.batterySavesPath;
	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    return YES;
}

#pragma mark - Running
- (void)startEmulation {
	if (!_isInitialized)
	{
//		[self.renderDelegate willRenderFrameOnAlternateThread];
        _isInitialized = true;
//		_frameInterval = dol_host->GetFrameInterval();
	}
	[super startEmulation];

	//Disable the OE framelimiting
//	[self.renderDelegate suspendFPSLimiting];
//	if(!self.isRunning) {
//		[super startEmulation];
////        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
//	}
}

- (void)runReicastEmuThread {
	@autoreleasepool
	{
//		[self reicastMain];

		// Core returns

		// Unlock rendering thread
//		dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

		[super stopEmulation];
	}
}

- (void)setPauseEmulation:(BOOL)flag {
	[super setPauseEmulation:flag];
}

- (void)stopEmulation {
	_isInitialized = false;

	self->shouldStop = YES;
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];

	[super stopEmulation];
}

- (void)resetEmulation {
	//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];
}

//# pragma mark - Cheats
//- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
//}
//
//- (BOOL)supportsRumble { return NO; }
//- (BOOL)supportsCheatCodes { return NO; }

@end
