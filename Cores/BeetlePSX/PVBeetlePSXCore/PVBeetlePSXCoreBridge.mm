//
//  PVBeetlePSXCore.m
//  PVBeetlePSX
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVBeetlePSXCoreBridge.h"
#import <PVBeetlePSX/PVBeetlePSX-Swift.h>
#include <stdatomic.h>
#include "libretro_options.h"
//#import "PVBeetlePSXCore+Controls.h"
//#import "PVBeetlePSXCore+Audio.h"
//#import "PVBeetlePSXCore+Video.h"
//
//#import "PVBeetlePSXCore+Audio.h"
#import <PVLogging/PVLoggingObjC.h>
#import <Foundation/Foundation.h>
@import PVCoreBridge;

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVBeetlePSXCoreBridge() {

}

@end

#pragma mark - PVBeetlePSXCore Begin

@implementation PVBeetlePSXCoreBridge
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

- (BOOL)supportsSaveStates { return YES; }
- (BOOL)supportsRumble { return YES; }
- (BOOL)supportsCheatCode { return YES; }

//- (NSTimeInterval)frameInterval {
/*
 The Beetle PSX HW core's core provided FPS is 59.826 for NTSC games and 49.761 for PAL games (non-interlaced rates) and is toggleable to 59.940 for NTSC games and 50.000 for PAL games (interlaced rates) through core options
 */
//    return 60;
//}
//
//- (CGSize)aspectSize {
//    return CGSizeMake(10, 7);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(1024, 1024);
//}
//
//- (GLenum)pixelFormat {
//    return GL_RGBA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_BYTE;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGBA;
//}

//- (BOOL)isDoubleBuffered {
//    return YES;
//}
//
//- (void)swapBuffers
//{
//    Mednafen::MDFN_Surface *tempSurf = backBufferSurf;
//    backBufferSurf = frontBufferSurf;
//    frontBufferSurf = tempSurf;
//}


- (BOOL)rendersToOpenGL { return YES; }

# pragma mark - Audio

- (double)audioSampleRate {
//    return 22255;
     return 44100;
}

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    
#define V(x) strcmp(variable, x) == 0
    if (V(BEETLE_OPT(renderer))) {
        // hardware, hardware_gl, hardware_vk, software
        NSInteger intValue = PVBeetlePSXCoreOptions.video_renderer;
        char *value = strdup("hardware");
        switch (intValue) {
            case 0:
                value = strdup("hardware");
                break;
            case 1:
                value = strdup("hardware_gl");
                break;
            case 2:
                value = strdup("hardware_vk");
                break;
            case 3:
                value = strdup("software");
                break;

            default:
                break;
        }
        return value;
    } else if (V(BEETLE_OPT(renderer_software_fb))) {
//        "Enable accurate emulation of framebuffer effects (e.g. motion blur, FF7 battle swirl) when using hardware renderers by running a copy of the software renderer at native resolution in the background. If disabled, these operations are omitted (OpenGL) or rendered on the GPU (Vulkan). Disabling can improve performance but may cause severe graphical errors. Leave enabled if unsure.",
//        NULL,
//        "video",
//        {
//           { "enabled",  NULL },
//           { "disabled", NULL },
//           { NULL, NULL },
//        },
            BOOL boolValue = PVBeetlePSXCoreOptions.video_renderer_software_framebuffer;
            char *value = boolValue ? strdup("enabled") : strdup("disabled");
            return value;
    } else if (V(BEETLE_OPT(internal_resolution))) {
        // 1,2,4,8,16
        char *value = strdup("2x");
        NSInteger intValue = PVBeetlePSXCoreOptions.video_renderer_upscale;
        switch (intValue) {
            case 0:
                value = strdup("1x");
                break;
            case 1:
                value = strdup("2x");
                break;
            case 2:
                value = strdup("4x");
                break;
            case 3:
                value = strdup("8x");
                break;
            case 4:
                value = strdup("16x");
                break;
            default:
                break;
        }
        return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
#undef V
    return NULL;
}

// Override buffer size for BeetlePSX's requirements
//- (CGSize)bufferSize {
//    return CGSizeMake(640, 480);  // Standard PSX resolution
//}

// Set aspect ratio
//- (CGSize)aspectSize {
//    return CGSizeMake(4, 3);  // Standard PSX aspect ratio
//}

#pragma MARK: Controls
- (void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSInteger)player {
    DLOG(@"TODO");
}

- (void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSInteger)player {
    DLOG(@"TODO");
}

- (void)didMovePSXJoystickDirection:(PVPSXButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    DLOG(@"TODO");
}

@end
