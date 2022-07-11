//
//  PVMelonDSCore.m
//  PVMelonDS
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVMelonDSCore.h"
#import "PVMelonDSCore+Controls.h"
#import "PVMelonDSCore+Audio.h"
#import "PVMelonDSCore+Video.h"

#import "PVMelonDS+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

// MelonDS imports
//#include "types.h"
////#include "profiler/profiler.h"
//#include "cfg/cfg.h"
//#include "rend/rend.h"
//#include "rend/TexCache.h"
//#include "hw/maple/maple_devs.h"
//#include "hw/maple/maple_if.h"
//#include "hw/maple/maple_cfg.h"

//__weak PVMelonDSCore *_current = 0;
//
//@interface PVMelonDSCore() {
//
//}
//
//@property(nonatomic, strong, nullable) NSString *diskPath;
//
//@end
//
//// MelonDS function declerations
//extern int screen_width,screen_height;
//bool rend_single_frame();
//bool gles_init();
//extern int MelonDS_main(int argc, char* argv[]);
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
#pragma mark - PVMelonDSCore Begin
#import <dlfcn.h>
#import <errno.h>
#import <mach/mach.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>

//static void *dlopen_myself()
//{
//    Dl_info info;
//    
//    dladdr(dlopen_myself, &info);
//    
//    return dlopen(info.dli_fname, RTLD_LAZY | RTLD_GLOBAL);
//}

@implementation PVMelonDSCore {
//	dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
//	dispatch_semaphore_t coreWaitToEndFrameSemaphore;
//    dispatch_semaphore_t coreWaitForExitSemaphore;
//
//	NSMutableDictionary *_callbackHandlers;
}

- (instancetype)init {
	if (self = [super init]) {
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
//		_callbackQueue = dispatch_queue_create("org.openemu.MelonDS.CallbackHandlerQueue", queueAttributes);
//		_callbackHandlers = [[NSMutableDictionary alloc] init];
        _current = self;
	}
	return self;
}


#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    #define V(x) strcmp(variable, x) == 0
    
    if (V("melonds_console_mode")) {
        // Console Mode; DS|DSi
        char * value = strdup("DS");
        return value;
    } else if (V("melonds_boot_directly")) {
        // Boot game directly; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_threaded_renderer")) {
        // Threaded software renderer; disabled|enabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_touch_mode")) {
        // disabled|Mouse|Touch|Joystick
        char * value = strdup("touch");
        return value;
    } else if (V("melonds_jit_enable")) {
        // JIT Enable (Restart); enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_jit_branch_optimisations")) {
        // JIT Branch optimisations; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_jit_literal_optimisations")) {
        // JIT Literal optimisations; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_jit_fast_memory")) {
        // JIT Fast memory; enabled|disabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_dsi_sdcard")) {
        // Enable DSi SD card; disabled|enabled
        char * value = strdup("disabled");
        return value;
    } else if (V("melonds_audio_bitrate")) {
        // Audio bitrate; Automatic|10-bit|16-bit
        char * value = strdup("16-bit");
        return value;
    } else if (V("melonds_audio_interpolation")) {
        // Audio Interpolation; None|Linear|Cosine|Cubic
        char * value = strdup("Cubic");
        return value;
    } else if (V("melonds_opengl_filtering")) {
        // "OpenGL filtering; nearest|linear"
        char * value = strdup("linear");
        return value;
    } else if (V("melonds_opengl_better_polygons")) {
        // OpenGL Improved polygon splitting; disabled|enabled
        char * value = strdup("enabled");
        return value;
    } else if (V("melonds_opengl_renderer")) {
        // OpenGL Renderer (Restart); disabled|enabled
        char * value = strdup("disabled");
        return value;
    } else if (V("melonds_hybrid_ratio")) {
        // Hybrid ratio (OpenGL only); 2|3
        char * value = strdup("3");
        return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
    
#undef V
    return NULL;
}

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
////								   NSLocalizedFailureReasonErrorKey: @"MelonDS failed to load GLES graphics.",
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
//    NSMutableString *s = [NSMutableString stringWithFormat:@"----------\nMelonDS Settings:\n---------\n"];
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
//        [NSThread detachNewThreadSelector:@selector(runMelonDSRenderThread) toTarget:self withObject:nil];
//	}
//}
//
//- (void)runMelonDSEmuThread {
//	@autoreleasepool
//	{
//		[self MelonDSMain];
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
//- (void)runMelonDSRenderThread {
//    @autoreleasepool
//    {
//        [self.renderDelegate startRenderingOnAlternateThread];
//        BOOL success = gles_init();
//        assert(success);
//        [NSThread detachNewThreadSelector:@selector(runMelonDSEmuThread) toTarget:self withObject:nil];
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
//- (void)MelonDSMain {
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
//	MelonDS_main(argc, Args);
//
//    dispatch_semaphore_signal(coreWaitForExitSemaphore);
//}
//
//int MelonDS_main(int argc, wchar* argv[]) {
//	int status = dc_init(argc, argv);
//    if (status != 0) {
//        ELOG(@"MelonDS dc_init failed with code: %i", status);
//        return status;
//    }
//
//    ILOG(@"MelonDS init status: %i", status);
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
//	// TODO: Call MelonDS stop command here
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
//	// TODO: Call MelonDS reset command here
//	plugins_Reset(true);
//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//}

@end

