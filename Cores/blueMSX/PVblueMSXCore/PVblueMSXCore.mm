//
//  PVblueMSXCore.m
//  PVblueMSX
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVblueMSXCore.h"
#include <stdatomic.h>
//#import "PVblueMSXCore+Controls.h"
//#import "PVblueMSXCore+Audio.h"
//#import "PVblueMSXCore+Video.h"
//
//#import "PVblueMSXCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVblueMSXCore() {

}

@end

#pragma mark - PVblueMSXCore Begin

@implementation PVblueMSXCore
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
    return 60;
}

- (CGSize)aspectSize {
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize {
    return CGSizeMake(1024, 768);
}

- (GLenum)pixelFormat {
    return GL_RGB;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    // TODO: use struct retro_pixel_format var, set with, RETRO_ENVIRONMENT_SET_PIXEL_FORMAT
    return GL_RGB565;
}


//- (GLenum)pixelFormat {
//    return GL_BGRA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_BYTE;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGBA;
//}
# pragma mark - Audio

- (double)audioSampleRate {
    return 48000;
}

#if 0
const struct retro_variable vars[] = {
   { "blueMSX_mode", "MSX Mode; MSX2+|MSX1|MSX2" },
   { "blueMSX_video_mode", "MSX Video Mode; NTSC|PAL|Dynamic" },
   { "blueMSX_hires", "Support high resolution; Off|Interlaced|Progressive" },
   { "blueMSX_overscan", "Support overscan; No|Yes" },
   { "blueMSX_mapper_type_mode", "MSX Mapper Type Mode; "
         "Guess|"
         "Generic 8kB|"
         "Generic 16kB|"
         "Konami5 8kB|"
         "Konami4 8kB|"
         "ASCII 8kB|"
         "ASCII 16kB|"
         "GameMaster2|"
         "FMPAC"
   },
   { "blueMSX_ram_pages", "MSX Main Memory; Auto|64KB|128KB|256KB|512KB|4MB" },
   { "blueMSX_vram_pages", "MSX Video Memory; Auto|32KB|64KB|128KB|192KB" },
   { "blueMSX_log_level", "blueMSX logging; Off|Info|Debug|Spam" },
   { "blueMSX_game_master", "Support Game Master; No|Yes" },
   { "blueMSX_simbdos", "Simulate DiskROM disk access calls; No|Yes" },
   { "blueMSX_autospace", "Use autofire on SPACE; No|Yes" },
   { "blueMSX_allsprites", "Show all sprites; No|Yes" },
   { "blueMSX_font", "Text font; standard|DEFAULT.FNT|ITALIC.FNT|INTERNAT.FNT|CYRILLIC.FNT|KOREAN.FNT|JAPANESE.FNT" },
   { "blueMSX_flush_disk", "Save disk changes; Never|Immediate|On close|To/From SRAM" },
   { "blueMSX_phantom_disk", "Create empty disk when none loaded; No|Yes" },
   { "blueMSX_custom_keyboard_up", up_value},
   { "blueMSX_custom_keyboard_down", down_value},
   { "blueMSX_custom_keyboard_left", left_value},
   { "blueMSX_custom_keyboard_right", right_value},
   { "blueMSX_custom_keyboard_a", a_value},
   { "blueMSX_custom_keyboard_b", b_value},
   { "blueMSX_custom_keyboard_y", y_value},
   { "blueMSX_custom_keyboard_x", x_value},
   { "blueMSX_custom_keyboard_start", start_value},
   { "blueMSX_custom_keyboard_select", select_value},
   { "blueMSX_custom_keyboard_l", l_value},
   { "blueMSX_custom_keyboard_r", r_value},
   { "blueMSX_custom_keyboard_l2", l2_value},
   { "blueMSX_custom_keyboard_r2", r2_value},
   { "blueMSX_custom_keyboard_l3", l3_value},
   { "blueMSX_custom_keyboard_r3", r3_value},
   { NULL, NULL },
};
#endif

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    
    #define V(x) strcmp(variable, x) == 0
    if (V("blueMSX_video_mode")) {
        // NTSC|PAL|Dynamic
        char *value = strdup("Dynamic");
        return value;
    } else if (V("blueMSX_mode")) {
            // MSX2+|MSX1|MSX2
            char * value = strdup("MSX2+");
            return value;
    } else if (V("blueMSX_hires")) {
            // Off|Interlaced|Progressive
            char *value = strdup("Progressive");
            return value;
    } else if (V("blueMSX_overscan")) {
            // No|Yes
            char *value = strdup("Yes");
            return value;
    } else if (V("blueMSX_mapper_type_mode")) {
//        { "blueMSX_mapper_type_mode", "MSX Mapper Type Mode; "
//              "Guess|"
//              "Generic 8kB|"
//              "Generic 16kB|"
//              "Konami5 8kB|"
//              "Konami4 8kB|"
//              "ASCII 8kB|"
//              "ASCII 16kB|"
//              "GameMaster2|"
//              "FMPAC"
//        },
            char *value = strdup("FMPAC");
            return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
    
#undef V
    return NULL;
}
@end
