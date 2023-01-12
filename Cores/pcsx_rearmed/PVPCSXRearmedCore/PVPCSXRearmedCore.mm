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

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVPCSXRearmedCore() {

}

@end

#pragma mark - PVPCSXRearmedCore Begin

@implementation PVPCSXRearmedCore
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

- (GLenum)pixelFormat {
    return GL_BGRA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

- (BOOL)rendersToOpenGL { return YES; }
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
        char *value = strdup("auto");
        return value;
    }
    else if (V(gpu_thread_rendering)) {
        char *value = strdup("async"); //disabled, sync, async
        return value;
    }
    else if (V(duping_enable)) {
        char *value = strdup("enabled"); //disabled, sync, async
        return value;
    }
    else if (V(neon_interlace_enable)) {
        char *value = strdup("disabled"); //disabled, sync, async
        return value;
    }
    else if (V(neon_enhancement_enable)) {
            // Might be slow
        char *value = strdup("enabled");
        return value;
    }
    else if (V(neon_enhancement_no_main)) {
            // "Improves performance when 'Enhanced Resolution (Slow)' is enabled, but reduces compatibility and may cause rendering errors."
        char *value = strdup("enabled");
        return value;
    }
    else if (V(drc)) {
            //       "Dynamically recompile PSX CPU instructions to native instructions. Much faster than using an interpreter, but may be less accurate on some platforms.",
        char *value = strdup("enabled");
        return value;
    }
    else if (V(async_cd)) {
            // "Select method used to read data from content disk images. 'Synchronous' mimics original hardware. 'Asynchronous' can reduce stuttering on devices with slow storage. 'Pre-Cache (CHD)' loads disk image into memory for faster access (CHD files only)."
        char *value = strdup("precache"); //sync, async, precache(chd)
        return value;
    }
    else if (V(show_bios_bootlogo)) {
        char *value = strdup("enabled");
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
