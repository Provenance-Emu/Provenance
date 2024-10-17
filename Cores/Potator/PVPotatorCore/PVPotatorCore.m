//
//  PVPotatorCore.m
//  PVPotator
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVPotatorCore.h"
#include <stdatomic.h>
//#import "PVPotatorCore+Controls.h"
//#import "PVPotatorCore+Audio.h"
//#import "PVPotatorCore+Video.h"
//
//#import "PVPotatorCore+Audio.h"

#import <Foundation/Foundation.h>
@import PVEmulatorCore;
@import PVLoggingObjC;

#if SWIFT_MODULE
@import libpotator;
@import PVPotatorSwift;
#endif

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVPotatorCoreBridge() {

}

@end

#pragma mark - PVPotatorCore Begin

@implementation PVPotatorCoreBridge

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
//#warning "Finish me"
//
//    struct retro_game_info game;
////    game.size = 0;
////    game.data = nil;
////    game.meta = "";
//    game.path = [path cStringUsingEncoding:kCFStringEncodingUTF8];
//
//    retro_load_game(&game);
//    return YES;
//}
//
//#pragma mark - Running
//- (void)startEmulation {
//    retro_run();
//}
//
//- (void)setPauseEmulation:(BOOL)flag {
//	[super setPauseEmulation:flag];
//}
//
//- (void)stopEmulation {
//#warning "Finish me"
//}
//
//- (void)resetEmulation {
//    retro_reset();
//}
//
# pragma mark - Cheats
////- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
////}
////
//- (BOOL)supportsRumble { return NO; }
//- (BOOL)supportsCheatCode { return NO; }
//
- (NSTimeInterval)frameInterval {
    return 60.0;
}

//- (CGSize)aspectSize {
//    return CGSizeMake(1, 1);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(160, 160);
//}

- (GLenum)pixelFormat {
    return GL_RGB;
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

# pragma mark - Audio

- (double)audioSampleRate {
    return 44100;
}

- (NSUInteger)channelCount {
    return 1;
}

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
#warning "Finish me"

    ILOG(@"%s", variable);
    
    
#define V(x) strcmp(variable, x) == 0
    if (V("potator_palette")) {
            // none,simple,detailed
            char *value = strdup("potator_green");
            return value;
    } else if (V("potator_lcd_ghosting")) {
            // Off|Interlaced|Progressive
            char *value = strdup("3");
            return value;
    } else if (V("potator_frameskip")) {
            // on,rewind,disable
            char *value = strdup("auto");
            return value;
    } else if (V("potator_frameskip_threshold")) {
            // true,false
            // Enable the On Screen Keyboard feature which can be activated with the L3 button on the controller.
            char *value = strdup("30");
            return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
#undef V
    return NULL;
}

@end

@implementation PVPotatorCoreBridge (PVSupervisionSystemResponderClient)

-(void)didPushSupervisionButton:(enum PVSupervisionButton)button forPlayer:(NSInteger)player {
#warning "Finish me"
    uint8_t controls_state = 0;
    unsigned joypad_bits = 0;
    size_t i;

//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_UP)     ? 0x08 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT)  ? 0x01 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_LEFT)   ? 0x02 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_DOWN)   ? 0x04 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_A)      ? 0x20 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_B)      ? 0x10 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_SELECT) ? 0x40 : 0;
//    controls_state |= joypad_bits & (1 << RETRO_DEVICE_ID_JOYPAD_START)  ? 0x80 : 0;
//
//    supervision_set_input(controls_state);
//    retro_input_state_t state;
//    retro_set_input_state(state);
}

-(void)didReleaseSupervisionButton:(enum PVSupervisionButton)button forPlayer:(NSInteger)player {
#warning "Finish me"
//    retro_input_state_t state;
//    retro_set_input_state(state);
}

@end
