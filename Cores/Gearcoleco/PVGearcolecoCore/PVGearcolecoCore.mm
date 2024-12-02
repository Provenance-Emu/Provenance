//
//  PVGearcolecoCore.m
//  PVGearcoleco
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVGearcolecoCore.h"
#include <stdatomic.h>
//#import "PVGearcolecoCore+Controls.h"
//#import "PVGearcolecoCore+Audio.h"
//#import "PVGearcolecoCore+Video.h"
//
//#import "PVGearcolecoCore+Audio.h"

#import <Foundation/Foundation.h>
@import PVCoreBridge;
#import <PVLogging/PVLogging.h>
#import <PVGearcoleco/PVGearcoleco-Swift.h>

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
#import <OpenGL/gl3.h>
#import <GLUT/GLUT.h>
#endif

#include "../../Gearcoleco/src/definitions.h"
#include "../../Gearcoleco/src/video.h"

#define SAMPLERATE GC_AUDIO_SAMPLE_RATE
#define SIZESOUNDBUFFER GC_AUDIO_BUFFER_SIZE
#define OpenEmu 1

#define GC_RESOLUTION_WIDTH 256
#define GC_RESOLUTION_HEIGHT 192
#define GC_RESOLUTION_WIDTH_WITH_OVERSCAN 272
#define GC_RESOLUTION_HEIGHT_WITH_OVERSCAN 208

#pragma mark - Private
@interface PVGearcolecoCoreBridge() {

}

@end

#pragma mark - PVGearcolecoCore Begin

@implementation PVGearcolecoCoreBridge
{
}

- (instancetype)init {
	if (self = [super init]) {
		pitch_shift = 1;
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore

#pragma mark - Running

- (NSTimeInterval)frameInterval {
    return av_info.timing.fps ?: 60.0; // Default to 60fps if av_info hasn't been set yet
}

- (CGSize)aspectSize {
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize {
    return CGSizeMake(GC_RESOLUTION_WIDTH_WITH_OVERSCAN, GC_RESOLUTION_HEIGHT_WITH_OVERSCAN);
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, GC_RESOLUTION_WIDTH_WITH_OVERSCAN, GC_RESOLUTION_HEIGHT_WITH_OVERSCAN);
}

- (GLenum)pixelFormat {
    return GL_RGB565;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    return GL_RGB565;
}

# pragma mark - Audio

- (double)audioSampleRate {
    return GC_AUDIO_SAMPLE_RATE;
}

#if 0
{ "gearcoleco_timing", "Refresh Rate (restart); Auto|NTSC (60 Hz)|PAL (50 Hz)" },
{ "gearcoleco_aspect_ratio", "Aspect Ratio (restart); 1:1 PAR|4:3 DAR|16:9 DAR" },
{ "gearcoleco_overscan", "Overscan; Disabled|Top+Bottom|Full (284 width)|Full (320 width)" },
{ "gearcoleco_up_down_allowed", "Allow Up+Down / Left+Right; Disabled|Enabled" },
{ "gearcoleco_spinners", "Spinner support; Disabled|Super Action Controller|Wheel Controller|Roller Controller" },
{ "gearcoleco_spinner_sensitivity", "Spinner Sensitivity; 1|2|3|4|5|6|7|8|9|10" },
#endif

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);


    #define V(x) strcmp(variable, x) == 0
    if (V("gearcoleco_no_sprite_limit")) {
        // { "gearcoleco_no_sprite_limit", "No Sprite Limit; Disabled|Enabled" },
        char *value = PVGearcolecoCoreOptions.no_sprite_limit ? strdup("Enabled") : strdup("Disabled");
        return value;
    } else if (V("gearcoleco_timing")) {
        // { "gearcoleco_timing", "Refresh Rate (restart); Auto|NTSC (60 Hz)|PAL (50 Hz)" },
        char *value = strdup("Auto");
        return value;
    } else if (V("gearcoleco_overscan")) {
//        { "gearcoleco_overscan", "Overscan; Disabled|Top+Bottom|Full (284 width)|Full (320 width)" },
            int overscan = PVGearcolecoCoreOptions.overscan;
            char * value;
            switch (overscan) {
                case 0:
                    value = strdup("Disabled");
                    break;
                case 1:
                    value = strdup("Top+Bottom");
                    break;
                case 2:
                    value = strdup("Full (284 width)");
                    break;
                case 3:
                    value = strdup("Full (320 width)");
                    break;
            }
            return value;
    } else if (V("gearcoleco_up_down_allowed")) {
//        { "gearcoleco_up_down_allowed", "Allow Up+Down / Left+Right; Disabled|Enabled" },
            char *value = strdup("Enabled");
            return value;
    } else if (V("gearcoleco_aspect_ratio")) {
            // { "gearcoleco_aspect_ratio", "Aspect Ratio (restart); 1:1 PAR|4:3 DAR|16:9 DAR" },
            char *value = strdup("4:3 DAR");
            return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }

#undef V
    return NULL;
}
#pragma mark - Control

-(void)didPushColecoVisionButton:(enum PVColecoVisionButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PVColecoVisionButtonUp:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = 1;
            break;
        case PVColecoVisionButtonDown:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = 1;
            break;
        case PVColecoVisionButtonLeft:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = 1;
            break;
        case PVColecoVisionButtonRight:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = 1;
            break;
        case PVColecoVisionButtonLeftAction:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_B] = 1; // Fire 1
            break;
        case PVColecoVisionButtonRightAction:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_A] = 1; // Fire 2
            break;
        // Keypad buttons
        case PVColecoVisionButton1:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_Y] = 1; // Keypad 1
            break;
        case PVColecoVisionButton2:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_X] = 1; // Keypad 2
            break;
        case PVColecoVisionButton3:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L] = 1; // Keypad 3
            break;
        case PVColecoVisionButton4:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R] = 1; // Keypad 4
            break;
        case PVColecoVisionButton5:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L2] = 1; // Keypad 5
            break;
        case PVColecoVisionButton6:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R2] = 1; // Keypad 6
            break;
        case PVColecoVisionButton7:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L3] = 1; // Keypad 7
            break;
        case PVColecoVisionButton8:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R3] = 1; // Keypad 8
            break;
        case PVColecoVisionButton9:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_SELECT] = 1; // Keypad 9
            break;
        case PVColecoVisionButton0:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_START] = 1; // Keypad 0
            break;
        case PVColecoVisionButtonAsterisk:
            _pad[player][12] = 1; // Keypad *
            break;
        case PVColecoVisionButtonPound:
            _pad[player][13] = 1; // Keypad #
            break;
        default:
            break;
    }
}

-(void)didReleaseColecoVisionButton:(enum PVColecoVisionButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PVColecoVisionButtonUp:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = 0;
            break;
        case PVColecoVisionButtonDown:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = 0;
            break;
        case PVColecoVisionButtonLeft:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = 0;
            break;
        case PVColecoVisionButtonRight:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = 0;
            break;
        case PVColecoVisionButtonLeftAction:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_B] = 0;
            break;
        case PVColecoVisionButtonRightAction:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_A] = 0;
            break;
        // Keypad buttons
        case PVColecoVisionButton1:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_Y] = 0;
            break;
        case PVColecoVisionButton2:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_X] = 0;
            break;
        case PVColecoVisionButton3:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L] = 0;
            break;
        case PVColecoVisionButton4:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R] = 0;
            break;
        case PVColecoVisionButton5:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L2] = 0;
            break;
        case PVColecoVisionButton6:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R2] = 0;
            break;
        case PVColecoVisionButton7:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L3] = 0;
            break;
        case PVColecoVisionButton8:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R3] = 0;
            break;
        case PVColecoVisionButton9:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_SELECT] = 0;
            break;
        case PVColecoVisionButton0:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_START] = 0;
            break;
        case PVColecoVisionButtonAsterisk:
            _pad[player][12] = 0;
            break;
        case PVColecoVisionButtonPound:
            _pad[player][13] = 0;
            break;
        default:
            break;
    }
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushColecoVisionButton:(PVColecoVisionButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseColecoVisionButton:(PVColecoVisionButton)button forPlayer:player];
}

- (void)swapBuffers {
    [super swapBuffers];
}

@end
