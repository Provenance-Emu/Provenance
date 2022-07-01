//
//  PVDesmume2015Core.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVDesmume2015Core.h"
#import "PVDesmume2015Core+Controls.h"
#import "PVDesmume2015Core+Audio.h"
#import "PVDesmume2015Core+Video.h"

#import "PVDesmume2015+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

// Desmume2015 imports
//#include "types.h"
////#include "profiler/profiler.h"
//#include "cfg/cfg.h"
//#include "rend/rend.h"
//#include "rend/TexCache.h"
//#include "hw/maple/maple_devs.h"
//#include "hw/maple/maple_if.h"
//#include "hw/maple/maple_cfg.h"

//__weak PVDesmume2015Core *_current = 0;
//
//@interface PVDesmume2015Core() {
//
//}
//
//@property(nonatomic, strong, nullable) NSString *diskPath;
//
//@end
//
//// Desmume2015 function declerations
//extern int screen_width,screen_height;
//bool rend_single_frame();
//bool gles_init();
//extern int desmume2015_main(int argc, char* argv[]);
//void common_linux_setup();
//int dc_init(int argc,wchar* argv[]);
//void dc_run();
//void dc_term();
//void dc_stop();
//extern void MakeCurrentThreadRealTime();
//
//bool inside_loop     = true;
//static bool first_run = true;;
//volatile bool has_init = false;
//
#pragma mark - PVDesmume2015Core Begin

@implementation PVDesmume2015Core { }
//	dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
//	dispatch_semaphore_t coreWaitToEndFrameSemaphore;
//    dispatch_semaphore_t coreWaitForExitSemaphore;
//
//	NSMutableDictionary *_callbackHandlers;
//}
//
//- (instancetype)init {
//	if (self = [super init]) {
//		mupenWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
//		coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
//        coreWaitForExitSemaphore       = dispatch_semaphore_create(0);
//
//		_videoWidth  = screen_width = 640;
//		_videoHeight = screen_height = 480;
//		_videoBitDepth = 32; // ignored
//		videoDepthBitDepth = 0; // TODO
//
//		sampleRate = 44100;
//
//		isNTSC = YES;
//
//		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
//
//		_callbackQueue = dispatch_queue_create("org.openemu.Desmume2015.CallbackHandlerQueue", queueAttributes);
//		_callbackHandlers = [[NSMutableDictionary alloc] init];
//	}
//
//	_current = self;
//	return self;
//}
//
//- (void)dealloc {
//#if !__has_feature(objc_arc)
//	dispatch_release(mupenWaitToBeginFrameSemaphore);
//	dispatch_release(coreWaitToEndFrameSemaphore);
//    dispatch_release(coreWaitForExitSemaphore);
//#endif
//
//	_current = nil;
//}
//
//#pragma mark - PVEmulatorCore
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
//	const char *dataPath;
//
//    [self copyCFGIfMissing];
//	[self copyShadersIfMissing];
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
//
////	if (!success) {
////		NSDictionary *userInfo = @{
////								   NSLocalizedDescriptionKey: @"Failed to load game.",
////								   NSLocalizedFailureReasonErrorKey: @"Desmume2015 failed to load GLES graphics.",
////								   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
////								   };
////
////		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
////												code:PVEmulatorCoreErrorCodeCouldNotLoadRom
////											userInfo:userInfo];
////
////		*error = newError;
////		return NO;
////	}
//
//	self.diskPath = path;
//
//	return YES;
//}
//
//- (void)printSettings {
//#define LIST_OF_VARIABLES \
//X(dynarec.Enable) \
//X(dynarec.idleskip) \
//X(DS.region) \
//X(DS.region) \
//X(aica.LimitFPS) \
//X(aica.NoSound) \
//X(aica.NoBatch) \
//X(aica.GlobalFocus) \
//X(aica.BufferSize) \
//X(aica.OldSyncronousDma) \
//X(bios.UseReios) \
//X(rend.WideScreen) \
//X(rend.UseMipmaps) \
//X(pvr.MaxThreads) \
//X(pvr.SynchronousRender)
//
//
//    NSMutableString *s = [NSMutableString stringWithFormat:@"----------\nDesmume2015 Settings:\n---------\n"];
//#define X(name) \
//[s appendString: [NSString stringWithFormat:@"%@ : %i\n", @#name , settings.name ]];
//LIST_OF_VARIABLES
//#undef X
//
//    ILOG(@"%@", s);
//}
//
//
//- (void)copyShadersIfMissing {
//
//	NSArray *shaders = @[@"Shader.vsh",@"Shader.fsh"];
//	NSString *destinationFolder = self.BIOSPath;
//	NSFileManager *fm = [NSFileManager defaultManager];
//
//	for (NSString* shader in shaders) {
//		NSString *destinationPath = [destinationFolder stringByAppendingPathComponent:shader];
//		ILOG(@"Checking for shader %@", destinationPath);
//		if( ![fm fileExistsAtPath:destinationPath]  ) {
//			NSString *source = [[NSBundle bundleForClass:[self class]] pathForResource:[shader stringByDeletingPathExtension] ofType:[shader pathExtension]];
//			[fm copyItemAtPath:source
//						toPath:destinationPath
//						 error:nil];
//			ILOG(@"Copied %@ from %@ to %@", shader, source, destinationPath);
//		}
//	}
//}
//
//- (void)copyCFGIfMissing {
//
//    NSString *cfg = @"emu.cfg";
//
////    Whcih one is it again?
//    NSString *destinationFolder = self.BIOSPath;
////    NSString *destinationFolder = self.diskPath;
//
//    NSFileManager *fm = [NSFileManager defaultManager];
//    NSString *destinationPath = [destinationFolder stringByAppendingPathComponent:cfg];
//
//    if( ![fm fileExistsAtPath:destinationPath] ) {
//            NSString *source = [[NSBundle bundleForClass:[self class]] pathForResource:@"emu" ofType:@"cfg"];
//            [fm copyItemAtPath:source
//                        toPath:destinationPath
//                         error:nil];
//            ILOG(@"Copied %@ from %@ to %@", cfg, source, destinationPath);
//    } else {
//        ILOG(@"emu.cfg already exists at path (%@). Skipping installing default version.", destinationFolder);
//    }
//}
//
//#pragma mark - Running
//- (void)startEmulation {
//	if(!self.isRunning) {
//		[super startEmulation];
//        [NSThread detachNewThreadSelector:@selector(runDesmume2015RenderThread) toTarget:self withObject:nil];
//	}
//}
//
//- (void)runDesmume2015EmuThread {
//	@autoreleasepool
//	{
//		[self desmume2015Main];
//
//		// Core returns
//
//		// Unlock rendering thread
//		dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);
//
//		[super stopEmulation];
//	}
//}
//
//- (void)runDesmume2015RenderThread {
//    @autoreleasepool
//    {
//        [self.renderDelegate startRenderingOnAlternateThread];
//        BOOL success = gles_init();
//        assert(success);
//        [NSThread detachNewThreadSelector:@selector(runDesmume2015EmuThread) toTarget:self withObject:nil];
//
//        CFAbsoluteTime lastTime = CFAbsoluteTimeGetCurrent();
//
//        while (!has_init) {}
//        while ( !shouldStop )
//        {
//            [self.frontBufferCondition lock];
//            while (!shouldStop && self.isFrontBufferReady) [self.frontBufferCondition wait];
//            [self.frontBufferCondition unlock];
//
//            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
//            CFTimeInterval deltaTime = now - lastTime;
//            while ( !shouldStop && !rend_single_frame() ) {}
//            [self swapBuffers];
//            lastTime = now;
//        }
//    }
//}
//
//- (void)desmume2015Main {
//	//    #if !TARGET_OS_SIMULATOR
//	// install_prof_handler(1);
//	//   #endif
//
//	char *Args[3];
//	const char *P;
//
//	P = (const char *)[self.diskPath UTF8String];
//	Args[0] = "dc";
//	Args[1] = "-config";
//	Args[2] = P&&P[0]? (char *)malloc(strlen(P)+32):0;
//
//	if(Args[2])
//	{
//		strcpy(Args[2],"config:image=");
//		strcat(Args[2],P);
//	}
//
//	MakeCurrentThreadRealTime();
//
//	int argc = Args[2]? 3:1;
//
//    // Set directories
//	set_user_config_dir(self.BIOSPath.UTF8String);
//    set_user_data_dir(self.BIOSPath.UTF8String);
//    // Shouuld be this, but it looks for BIOS there too and  have to copy BIOS into battery saves dir of every game then
//        //    set_user_data_dir(self.batterySavesPath.UTF8String);
//
//    add_system_data_dir(self.BIOSPath.UTF8String);
//    add_system_config_dir(self.BIOSPath.UTF8String);
//
//    NSString *systemPath = [self.diskPath stringByDeletingLastPathComponent];
//
//    NSString *configDirs = [NSString stringWithFormat:@"%@", systemPath];
//    NSString *dataDirs = [NSString stringWithFormat:@"%@", systemPath];
//
//    setenv("XDG_CONFIG_DIRS", configDirs.UTF8String, true);
//    setenv("XDG_DATA_DIRS", dataDirs.UTF8String, true);
//
//    ILOG(@"Config dir is: %s\n", get_writable_config_path("/").c_str());
//	ILOG(@"Data dir is:   %s\n", get_writable_data_path("/").c_str());
//
//	common_linux_setup();
//
//	settings.profile.run_counts=0;
//
//	desmume2015_main(argc, Args);
//
//    dispatch_semaphore_signal(coreWaitForExitSemaphore);
//}
//
//int desmume2015_main(int argc, wchar* argv[]) {
//	int status = dc_init(argc, argv);
//    if (status != 0) {
//        ELOG(@"Desmume2015 dc_init failed with code: %i", status);
//        return status;
//    }
//
//    ILOG(@"Desmume2015 init status: %i", status);
//
//    [_current printSettings];
//
//    has_init = true;
//
//	dc_run();
//
//    has_init = false;
////    _current->shouldStop = true;
//
//    dc_term();
//
//	return 0;
//}
//
//- (void)setPauseEmulation:(BOOL)flag {
//	[super setPauseEmulation:flag];
//
//	if (flag)
//	{
//        dc_stop();
//		dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//		[self.frontBufferCondition lock];
//		[self.frontBufferCondition signal];
//		[self.frontBufferCondition unlock];
//    } else {
//        dc_run();
//    }
//}
//
//- (void)stopEmulation {
//    has_init = false;
//
//	// TODO: Call desmume2015 stop command here
//	dc_term();
//    self->shouldStop = YES;
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//
//	[super stopEmulation];
//}
//
//- (void)resetEmulation {
//	// TODO: Call desmume2015 reset command here
//	plugins_Reset(true);
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//}

@end

