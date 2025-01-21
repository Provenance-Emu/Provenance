//
//  PVOperaCore.m
//  PVOpera
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVOperaCore.h"
#include <stdatomic.h>
//#import "PVOperaCore+Controls.h"
//#import "PVOperaCore+Audio.h"
//#import "PVOperaCore+Video.h"
//
//#import "PVOperaCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVOpera/PVOpera-Swift.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVLoggingObjC;

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVOperaCoreBridge() <PV3DOSystemResponderClient> {
    
}

@end

#pragma mark - PVOperaCore Begin

@implementation PVOperaCoreBridge
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
//
//- (CGSize)aspectSize {
//    return CGSizeMake(4, 3);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(1440, 1080);
//}
//
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
//
//# pragma mark - Audio
//
//- (double)audioSampleRate {
//    return 22255;
//}

- (void *)getVariable:(const char *)variable {
    ILOG(@"Opera getVariable: %s", variable);
    
#define V(x) (strcmp(variable, "opera_" x) == 0 || strcmp(variable, "4do_" x) == 0)
    
    // Special handling for BIOS options which need to be dynamically populated
    if (strcmp(variable, "opera_bios") == 0 || strcmp(variable, "4do_bios") == 0) {
        NSString *biosPath = self.BIOSPath;
        ILOG(@"Checking BIOS path: %@", biosPath);
        
        if (!biosPath) {
            ELOG(@"BIOS path is nil!");
            return strdup("panafz10.bin");
        }
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error = nil;
        
        // List of known BIOS files
        NSArray *knownBIOSFiles = @[
            @"panafz1.bin",
            @"panafz10.bin",
            @"panafz10-norsa.bin",
            @"panafz10e-anvil.bin",
            @"panafz10e-anvil-norsa.bin",
            @"panafz1j.bin",
            @"panafz1j-norsa.bin",
            @"goldstar.bin",
            @"sanyotry.bin",
            @"3do_arcade.bin"
        ];
        
        // Check which BIOS files exist
        NSMutableArray *availableBIOSFiles = [NSMutableArray array];
        for (NSString *biosFile in knownBIOSFiles) {
            NSString *fullPath = [biosPath stringByAppendingPathComponent:biosFile];
            ILOG(@"Checking for BIOS file at: %@", fullPath);
            if ([fm fileExistsAtPath:fullPath]) {
                ILOG(@"Found BIOS file: %@", biosFile);
                [availableBIOSFiles addObject:biosFile];
            }
        }
        
        // Also try listing all files in the BIOS directory
        NSArray *allFiles = [fm contentsOfDirectoryAtPath:biosPath error:&error];
        if (error) {
            ELOG(@"Error listing BIOS directory: %@", error);
        } else {
            ILOG(@"All files in BIOS directory: %@", allFiles);
        }
        
        ILOG(@"Found BIOS files: %@", availableBIOSFiles);
        
        // If no BIOS files found, return default
        if (availableBIOSFiles.count == 0) {
            WLOG(@"No BIOS files found, returning default panafz10.bin");
            return strdup("panafz10.bin");
        }
        
        // Format the string as the core expects (null-terminated strings)
        NSMutableString *biosString = [NSMutableString string];
        for (NSString *biosFile in availableBIOSFiles) {
            [biosString appendString:biosFile];
            [biosString appendString:@"|"];
        }
        // Remove last separator
        if ([biosString hasSuffix:@"|"]) {
            [biosString deleteCharactersInRange:NSMakeRange(biosString.length - 1, 1)];
        }
        
        ILOG(@"Returning BIOS options: %@", biosString);
        char *result = strdup(biosString.UTF8String);
        ILOG(@"Returned C string: %s", result);
        return result;
    }
    
    if (strcmp(variable, "opera_font") == 0 || strcmp(variable, "4do_font") == 0) {
        const char* fontName = "panafz10-norsa.bin";
        ILOG(@"Opera setting font ROM to %s", fontName);
        return strdup(fontName);
    }
    
    // Strip prefix to get the base variable name
    const char *baseVariable = variable;
    if (strncmp(variable, "4do_", 4) == 0) {
        baseVariable = variable + 4;
    } else if (strncmp(variable, "opera_", 6) == 0) {
        baseVariable = variable + 6;
    }
    
    // Get value using the opera_ prefix version
    NSString *operaKey = [NSString stringWithFormat:@"opera_%s", baseVariable];
    id value = [OperaOptions getVariable:operaKey];
    
    if (!value) {
        ELOG(@"Unprocessed Opera var: %s", variable);
        return NULL;
    }
    
    // Convert the value to the expected C string format
    NSString *stringValue;
    if ([value isKindOfClass:[NSNumber class]]) {
        if (V("active_devices") || V("nvram_version")) {
            stringValue = [NSString stringWithFormat:@"%d", [value intValue]];
        } else if (V("vdlp_bypass_clut") ||
                   V("high_resolution") ||
                   V("swi_hle") ||
                   V("hack_timing_1") ||
                   V("hack_timing_3") ||
                   V("hack_timing_5") ||
                   V("hack_timing_6") ||
                   V("hack_graphics_step_y") ||
                   V("dsp_threaded") ||
                   V("kprint")) {
            stringValue = [value boolValue] ? @"enabled" : @"disabled";
        }
    } else if ([value isKindOfClass:[NSString class]]) {
        if (V("region")) {
            // Convert our friendly names back to libretro values
            NSDictionary *regionMap = @{
                @"NTSC 320x240@60": @"ntsc",
                @"PAL1 320x288@50": @"pal1",
                @"PAL2 352x288@50": @"pal2"
            };
            stringValue = regionMap[value] ?: value;
        } else if (V("nvram_storage")) {
            // Convert our friendly names back to libretro values
            NSDictionary *storageMap = @{
                @"Per Game": @"per game",
                @"Shared": @"shared"
            };
            stringValue = storageMap[value] ?: value;
        } else if (V("madam_matrix_engine")) {
            // Convert our friendly names back to libretro values
            NSDictionary *engineMap = @{
                @"Hardware": @"hardware",
                @"Software": @"software"
            };
            stringValue = engineMap[value] ?: value;
        } else {
            // For other string values (like CPU overclock and pixel format),
            // use the value directly
            stringValue = value;
        }
    }
    
    DLOG(@"Options: %@ value: %@", operaKey, [stringValue UTF8String]);
    
    if (stringValue) {
        return strdup([stringValue UTF8String]);
    }
    
#undef V
    return NULL;
}

- (void)didPush3DOButton:(PV3DOButton)button forPlayer:(NSInteger)player {
    int retroButton = 0;
    
    switch (button) {
        case PV3DOButtonUp:
            retroButton = RETRO_DEVICE_ID_JOYPAD_UP;
            break;
        case PV3DOButtonDown:
            retroButton = RETRO_DEVICE_ID_JOYPAD_DOWN;
            break;
        case PV3DOButtonLeft:
            retroButton = RETRO_DEVICE_ID_JOYPAD_LEFT;
            break;
        case PV3DOButtonRight:
            retroButton = RETRO_DEVICE_ID_JOYPAD_RIGHT;
            break;
        case PV3DOButtonA:
            retroButton = RETRO_DEVICE_ID_JOYPAD_A;
            break;
        case PV3DOButtonB:
            retroButton = RETRO_DEVICE_ID_JOYPAD_B;
            break;
        case PV3DOButtonC:
            retroButton = RETRO_DEVICE_ID_JOYPAD_X;
            break;
        case PV3DOButtonL:
            retroButton = RETRO_DEVICE_ID_JOYPAD_L;
            break;
        case PV3DOButtonR:
            retroButton = RETRO_DEVICE_ID_JOYPAD_R;
            break;
        case PV3DOButtonP:
            retroButton = RETRO_DEVICE_ID_JOYPAD_START;
            break;
        case PV3DOButtonX:
            retroButton = RETRO_DEVICE_ID_JOYPAD_SELECT;
            break;
        default:
            break;
    }
    
    // Send button press to libretro
    //    [self.emulatorBridge buttonPressed:retroButton forPlayer:player];
}

- (void)didRelease3DOButton:(PV3DOButton)button forPlayer:(NSInteger)player {
    int retroButton = 0;
    
    switch (button) {
        case PV3DOButtonUp:
            retroButton = RETRO_DEVICE_ID_JOYPAD_UP;
            break;
        case PV3DOButtonDown:
            retroButton = RETRO_DEVICE_ID_JOYPAD_DOWN;
            break;
        case PV3DOButtonLeft:
            retroButton = RETRO_DEVICE_ID_JOYPAD_LEFT;
            break;
        case PV3DOButtonRight:
            retroButton = RETRO_DEVICE_ID_JOYPAD_RIGHT;
            break;
        case PV3DOButtonA:
            retroButton = RETRO_DEVICE_ID_JOYPAD_A;
            break;
        case PV3DOButtonB:
            retroButton = RETRO_DEVICE_ID_JOYPAD_B;
            break;
        case PV3DOButtonC:
            retroButton = RETRO_DEVICE_ID_JOYPAD_X;
            break;
        case PV3DOButtonL:
            retroButton = RETRO_DEVICE_ID_JOYPAD_L;
            break;
        case PV3DOButtonR:
            retroButton = RETRO_DEVICE_ID_JOYPAD_R;
            break;
        case PV3DOButtonP:
            retroButton = RETRO_DEVICE_ID_JOYPAD_START;
            break;
        case PV3DOButtonX:
            retroButton = RETRO_DEVICE_ID_JOYPAD_SELECT;
            break;
        default:
            break;
    }
    
    // Send button release to libretro
    //    [self.emulatorBridge buttonReleased:retroButton forPlayer:player];
}

@end
