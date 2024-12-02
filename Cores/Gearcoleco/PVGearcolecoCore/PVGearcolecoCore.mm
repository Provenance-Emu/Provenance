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
    return CGRectMake(0, 0, GC_RESOLUTION_WIDTH, GC_RESOLUTION_HEIGHT);
}

- (GLenum)pixelFormat {
    return GL_RGB;
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
const struct retro_variable vars[] = {
   { "Gearcoleco_mode", "MSX Mode; MSX2+|MSX1|MSX2" },
   { "Gearcoleco_video_mode", "MSX Video Mode; NTSC|PAL|Dynamic" },
   { "Gearcoleco_hires", "Support high resolution; Off|Interlaced|Progressive" },
   { "Gearcoleco_overscan", "Support overscan; No|Yes" },
   { "Gearcoleco_mapper_type_mode", "MSX Mapper Type Mode; "
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
   { "Gearcoleco_ram_pages", "MSX Main Memory; Auto|64KB|128KB|256KB|512KB|4MB" },
   { "Gearcoleco_vram_pages", "MSX Video Memory; Auto|32KB|64KB|128KB|192KB" },
   { "Gearcoleco_log_level", "Gearcoleco logging; Off|Info|Debug|Spam" },
   { "Gearcoleco_game_master", "Support Game Master; No|Yes" },
   { "Gearcoleco_simbdos", "Simulate DiskROM disk access calls; No|Yes" },
   { "Gearcoleco_autospace", "Use autofire on SPACE; No|Yes" },
   { "Gearcoleco_allsprites", "Show all sprites; No|Yes" },
   { "Gearcoleco_font", "Text font; standard|DEFAULT.FNT|ITALIC.FNT|INTERNAT.FNT|CYRILLIC.FNT|KOREAN.FNT|JAPANESE.FNT" },
   { "Gearcoleco_flush_disk", "Save disk changes; Never|Immediate|On close|To/From SRAM" },
   { "Gearcoleco_phantom_disk", "Create empty disk when none loaded; No|Yes" },
   { "Gearcoleco_custom_keyboard_up", up_value},
   { "Gearcoleco_custom_keyboard_down", down_value},
   { "Gearcoleco_custom_keyboard_left", left_value},
   { "Gearcoleco_custom_keyboard_right", right_value},
   { "Gearcoleco_custom_keyboard_a", a_value},
   { "Gearcoleco_custom_keyboard_b", b_value},
   { "Gearcoleco_custom_keyboard_y", y_value},
   { "Gearcoleco_custom_keyboard_x", x_value},
   { "Gearcoleco_custom_keyboard_start", start_value},
   { "Gearcoleco_custom_keyboard_select", select_value},
   { "Gearcoleco_custom_keyboard_l", l_value},
   { "Gearcoleco_custom_keyboard_r", r_value},
   { "Gearcoleco_custom_keyboard_l2", l2_value},
   { "Gearcoleco_custom_keyboard_r2", r2_value},
   { "Gearcoleco_custom_keyboard_l3", l3_value},
   { "Gearcoleco_custom_keyboard_r3", r3_value},
   { NULL, NULL },
};
#endif

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);


    #define V(x) strcmp(variable, x) == 0
    if (V("Gearcoleco_video_mode")) {
        // NTSC|PAL|Dynamic
        char *value = strdup("Dynamic");
        return value;
    } else if (V("Gearcoleco_mode")) {
            // MSX2+|MSX1|MSX2
            char * value = strdup("MSX2+");
            return value;
    } else if (V("Gearcoleco_hires")) {
            // Off|Interlaced|Progressive
            char *value = strdup("Progressive");
            return value;
    } else if (V("Gearcoleco_overscan")) {
            // No|Yes
            char *value = strdup("Yes");
            return value;
    } else if (V("Gearcoleco_mapper_type_mode")) {
//        { "Gearcoleco_mapper_type_mode", "MSX Mapper Type Mode; "
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
            char *value = strdup("Guess");
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
    pitch_shift = 0;
}

@end
