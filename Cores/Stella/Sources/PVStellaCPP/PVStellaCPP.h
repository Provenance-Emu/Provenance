//
//  PVStellaCPP.hxx
//
//
//  Created by Joseph Mattiello on 5/30/24.
//

#ifndef PVStellaCPP_hxx
#define PVStellaCPP_hxx

#import <Foundation/Foundation.h>

#include "libretro.h"

// Size and screen buffer consants
typedef                         uint32_t     stellabuffer_t;
#define STELLA_PITCH_SHIFT      2
#define STELLA_PIXEL_TYPE       GL_UNSIGNED_BYTE
#if TARGET_OS_MACCATALYST
#define STELLA_PIXEL_FORMAT     GL_UNSIGNED_SHORT_5_6_5
#define STELLA_INTERNAL_FORMAT  GL_UNSIGNED_SHORT_5_6_5
#else
#define STELLA_PIXEL_FORMAT     GL_RGB565
#define STELLA_INTERNAL_FORMAT  GL_RGB565
#endif

#define STELLA_WIDTH 160
#define STELLA_HEIGHT 256


const NSUInteger A2600EmulatorValues[] = {
    RETRO_DEVICE_ID_JOYPAD_UP,
    RETRO_DEVICE_ID_JOYPAD_DOWN,
    RETRO_DEVICE_ID_JOYPAD_LEFT,
    RETRO_DEVICE_ID_JOYPAD_RIGHT,
    RETRO_DEVICE_ID_JOYPAD_B,
    RETRO_DEVICE_ID_JOYPAD_L,
    RETRO_DEVICE_ID_JOYPAD_L2,
    RETRO_DEVICE_ID_JOYPAD_R,
    RETRO_DEVICE_ID_JOYPAD_R2,
    RETRO_DEVICE_ID_JOYPAD_START,
    RETRO_DEVICE_ID_JOYPAD_SELECT
};

#define NUMBER_OF_PADS 2
#define NUMBER_OF_PAD_INPUTS 16

#endif /* PVStellaCPP_hxx */
