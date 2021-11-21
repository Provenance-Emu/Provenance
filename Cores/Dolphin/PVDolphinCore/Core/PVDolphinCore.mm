//
//  PVDolphinCore.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore.h"
#import "PVDolphinCore+Controls.h"
#import "PVDolphinCore+Audio.h"
#import "PVDolphinCore+Video.h"

#import "PVDolphinCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

__weak PVDolphinCore *_current = 0;

#pragma mark - Private
@interface PVDolphinCore() {

}

@end

#pragma mark - PVDolphinCore Begin

@implementation PVDolphinCore

- (instancetype)init {
	if (self = [super init]) {
		_videoWidth  = 640;
		_videoHeight = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO

		sampleRate = 44100;

		isNTSC = YES;

		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);

		_callbackQueue = dispatch_queue_create("org.provenance-emu.play.CallbackHandlerQueue", queueAttributes);
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
	if(!self.isRunning) {
		[super startEmulation];
//        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
	}
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

	if (flag)
	{
//        dc_stop();
//		dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
		[self.frontBufferCondition lock];
		[self.frontBufferCondition signal];
		[self.frontBufferCondition unlock];
    } else {
//        dc_run();
    }
}

- (void)stopEmulation {
//    has_init = false;

	// TODO: Call reicast stop command here
//	dc_term();
    self->shouldStop = YES;
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];

	[super stopEmulation];
}

- (void)resetEmulation {
	// TODO: Call reicast reset command here
//	plugins_Reset(true);
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];
}

@end

