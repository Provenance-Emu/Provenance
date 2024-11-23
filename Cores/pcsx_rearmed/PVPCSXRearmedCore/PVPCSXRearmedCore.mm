//
//  PVPCSXRearmedCore.m
//  PVPCSXRearmed
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVPCSXRearmedCore.h"
#include <stdatomic.h>

//#import "PVPCSXRearmedCore+Controls.h"
//#import "PVPCSXRearmedCore+Audio.h"
//#import "PVPCSXRearmedCore+Video.h"
//
//#import "PVPCSXRearmedCore+Audio.h"

@import PVCoreBridge;
@import PVCoreObjCBridge;
#import <PVPCSXRearmed/PVPCSXRearmed-Swift.h>
#import <Foundation/Foundation.h>
#import <PVLogging/PVLoggingObjC.h>

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVPCSXRearmedCoreBridge() {

}

@end

#pragma mark - PVPCSXRearmedCore Begin

@implementation PVPCSXRearmedCoreBridge
{
}

- (instancetype)init {
	if (self = [super init]) {
	}

//    Config.Cpu = CPU_INTERPRETER;
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

//- (NSTimeInterval)frameInterval {
//    return 13.63;
//}

//- (CGSize)aspectSize {
//    return CGSizeMake(4, 3);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(1440, 1080);
//}

//- (GLenum)pixelFormat {
//    return GL_BGRA;
//}
//
//- (GLenum)pixelType {
//    return GL_RGB565 ;// GL_UNSIGNED_SHORT_5_6_5;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGBA;
//}

- (GLenum)pixelFormat {
    return GL_RGB565;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
    return GL_RGB565;
#else
    return GL_UNSIGNED_SHORT_5_6_5;
#endif
}


#if GPU_NEON
- (BOOL)rendersToOpenGL { return NO; }
#else
- (BOOL)rendersToOpenGL { return YES; }
#endif

# pragma mark - Audio

- (double)audioSampleRate {
    return SAMPLERATE;
}

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);

#define STRINGIFY(x) #x
#define ESYM(name) STRINGIFY(pcsx_rearmed_##name)
#define V(x) strcmp(variable, ESYM(x)) == 0

    if (V(frameskip_type)) {
        char *value;
        switch(PCSXRearmedOptions.frameSkip) {
            case 0:
                value = strdup("off");
                break;
            case 1:
                value = strdup("auto");
                break;
            case 2:
                value = strdup("manual");
                break;
        }
        
        return value;
    }
    else if (V(gpu_thread_rendering)) {
        char *value = strdup("async"); //disabled, sync, async
        switch(PCSXRearmedOptions.frameDuplication) {
            case 0:
                value = strdup("disabled");
                break;
            case 1:
                value = strdup("sync");
                break;
            case 2:
                value = strdup("async");
                break;
        }
        return value;
    }
    else if (V(duping_enable)) {
        char *value = PCSXRearmedOptions.frameDuplication ?
        strdup("enabled") : strdup("disabled") ; //disabled, enabled
        
        return value;
    }
    else if (V(neon_interlace_enable)) {
        char *value = strdup("disabled"); //disabled, sync, async
        return value;
    }
    else if (V(neon_enhancement_enable)) {
            // Might be slow
        char *value = PCSXRearmedOptions.gpuNeonEnhancment ?
        strdup("enabled") : strdup("disabled");

        return value;
    }
    else if (V(neon_enhancement_no_main)) {
            // "Improves performance when 'Enhanced Resolution (Slow)' is enabled, but reduces compatibility and may cause rendering errors."
        char *value = PCSXRearmedOptions.gpuNeonEnhancmenSpeedHack ?
        strdup("enabled") : strdup("disabled");

        return value;
    }
    else if (V(drc)) {
            //       "Dynamically recompile PSX CPU instructions to native instructions. Much faster than using an interpreter, but may be less accurate on some platforms.",
        char *value = PCSXRearmedOptions.jit ? strdup("enabled") : strdup("disabled");
        return value;
    }
    else if (V(async_cd)) {
            // "Select method used to read data from content disk images. 'Synchronous' mimics original hardware. 'Asynchronous' can reduce stuttering on devices with slow storage. 'Pre-Cache (CHD)' loads disk image into memory for faster access (CHD files only)."
        char *value = strdup("precache"); //sync, async, precache(chd)
        return value;
    }
    else if (V(show_bios_bootlogo)) {
        char *value = PCSXRearmedOptions.showBootLogo ? strdup("enabled") : strdup("disabled");
        return value;
    }
    else if (V(memcard2)) {
            //       "Emulate a second memory card in slot 2. This will be shared by all games.",

        char *value = strdup("enabled"); //sync, async, precache(chd)
        return value;
    }
    else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }

#undef V
#undef ESYM
    return NULL;
}
@end

static void flipEGL(void)
{
    GET_CURRENT_OR_RETURN();
    [current swapBuffers];
// eglSwapBuffers(display, surface);
}
