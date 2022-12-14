//
//  PVDolphinCore.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore.h"
#include "DolHost.h"
#include "AudioCommon/SoundStream.h"
#include "OpenEmuAudioStream.h"
#include <stdatomic.h>
#import "PVDolphinCore+Controls.h"
#import "PVDolphinCore+Audio.h"
#import "PVDolphinCore+Video.h"

#import "PVDolphinCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

__weak PVDolphinCore *_current = 0;

#pragma mark - Private
@interface PVDolphinCore() {

}

@end

#pragma mark - PVDolphinCore Begin

@implementation PVDolphinCore
{
	DolHost *dol_host;

	uint16_t *_soundBuffer;
	bool _isWii;
	atomic_bool _isInitialized;
	float _frameInterval;

	NSString *autoLoadStatefileName;
	NSString *_dolphinCoreModule;
	CGSize _dolphinCoreAspect;
	CGSize _dolphinCoreScreen;
}

- (instancetype)init {
	if (self = [super init]) {
		_videoWidth  = 640;
		_videoHeight = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO

		sampleRate = 44100;

		isNTSC = YES;

		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);

		_callbackQueue = dispatch_queue_create("org.provenance-emu.dolphin.CallbackHandlerQueue", queueAttributes);

		dol_host = DolHost::GetInstance();
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

//	self.filePath = path;

	if([[self systemIdentifier] isEqualToString:@"com.provenance.gamecube"])
	{
		_dolphinCoreModule = @"gc";
		_isWii = false;
		_frameInterval = 60;
		_dolphinCoreAspect = CGSizeMake(4, 3);
		_dolphinCoreScreen = CGSizeMake(640, 480);
	}
	else
	{
		_dolphinCoreModule = @"Wii";
		_isWii = true;
		_frameInterval = 60;
		_dolphinCoreAspect = CGSizeMake(16,9);
		_dolphinCoreScreen = CGSizeMake(854, 480);
	}

//	dol_host->Init([[self supportDirectoryPath] fileSystemRepresentation], [path fileSystemRepresentation] );

	usleep(5000);
	return YES;
}

#pragma mark - Running
- (void)startEmulation {
	if (!_isInitialized)
	{
//		[self.renderDelegate willRenderFrameOnAlternateThread];

//		dol_host->SetPresentationFBO((int)[[self.renderDelegate presentationFramebuffer] integerValue]);

		if(dol_host->LoadFileAtPath())
			_isInitialized = true;

		_frameInterval = dol_host->GetFrameInterval();

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
	dol_host->Pause(flag);

	[super setPauseEmulation:flag];
}

- (void)stopEmulation {
	_isInitialized = false;

	dol_host->RequestStop();

	self->shouldStop = YES;
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];

	[super stopEmulation];
}

- (void)resetEmulation {
	dol_host->Reset();
	//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];
}

# pragma mark - Cheats
- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
	dol_host->SetCheat([code UTF8String], [type UTF8String], enabled);
}

- (BOOL)supportsRumble { return YES; }
- (BOOL)supportsCheatCode { return YES; }

@end
