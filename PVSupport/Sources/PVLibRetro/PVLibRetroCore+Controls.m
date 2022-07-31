//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibretro.h"

#import <PVSupport/PVSupport-Swift.h>

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include <dynamic/dylib.h>
#include <string/stdstring.h>

#include "command.h"
#include "core_info.h"

#include "managers/state_manager.h"
//#include "audio/audio_driver.h"
//#include "camera/camera_driver.h"
//#include "location/location_driver.h"
//#include "record/record_driver.h"
#include "core.h"
#include "runloop.h"
#include "performance_counters.h"
#include "system.h"
#include "record/record_driver.h"
//#include "queues/message_queue.h"
#include "gfx/video_driver.h"
#include "gfx/video_context_driver.h"
#include "gfx/scaler/scaler.h"
//#include "gfx/video_frame.h"

#include <retro_assert.h>

#include "cores/internal_cores.h"
#include "frontend/frontend_driver.h"
#include "content.h"
#ifdef HAVE_CHEEVOS
#include "cheevos.h"
#endif
#include "retroarch.h"
#include "configuration.h"
#include "general.h"
#include "msg_hash.h"
#include "verbosity.h"

char rotation_lut[4][32] =
{
   "Normal",
   "90 deg",
   "180 deg",
   "270 deg"
};

struct aspect_ratio_elem aspectratio_lut[ASPECT_RATIO_END] = {
   { "4:3",           1.3333f },
   { "16:9",          1.7778f },
   { "16:10",         1.6f },
   { "16:15",         16.0f / 15.0f },
   { "1:1",           1.0f },
   { "2:1",           2.0f },
   { "3:2",           1.5f },
   { "3:4",           0.75f },
   { "4:1",           4.0f },
   { "4:4",           1.0f },
   { "5:4",           1.25f },
   { "6:5",           1.2f },
   { "7:9",           0.7777f },
   { "8:3",           2.6666f },
   { "8:7",           1.1428f },
   { "19:12",         1.5833f },
   { "19:14",         1.3571f },
   { "30:17",         1.7647f },
   { "32:9",          3.5555f },
   { "Config",        0.0f },
   { "Square pixel",  1.0f },
   { "Core provided", 1.0f },
   { "Custom",        0.0f }
};

@implementation PVLibRetroCore (Audio)

# pragma mark - Video

- (NSTimeInterval)frameInterval {
    NSTimeInterval fps = av_info.timing.fps ?: 60;
    VLOG(@"%f", fps);
    return fps;
}

- (void)swapBuffers {
    if (videoBuffer == videoBufferA) {
        videoBuffer = videoBufferB;
    } else {
        videoBuffer = videoBufferA;
    }
}

-(BOOL)isDoubleBuffered {
    return YES;
}

- (CGFloat)videoWidth {
    return av_info.geometry.base_width;
}

- (CGFloat)videoHeight {
    return av_info.geometry.base_height;
}

- (const void *)videoBuffer {
    return videoBuffer;
}

- (CGRect)screenRect {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.base_height;
    unsigned width = av_info.geometry.base_width;

//    unsigned height = _videoHeight;
//    unsigned width = _videoWidth;
    
    return CGRectMake(0, 0, width, height);
}

- (CGSize)aspectSize {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    float aspect_ratio = av_info.geometry.aspect_ratio;
    //    unsigned height = av_info.geometry.max_height;
    //    unsigned width = av_info.geometry.max_width;
    if (aspect_ratio == 1.0) {
        return CGSizeMake(1, 1);
    } else if (aspect_ratio < 1.2 && aspect_ratio > 1.1) {
        return CGSizeMake(10, 9);
    } else if (aspect_ratio < 1.26 && aspect_ratio > 1.24) {
        return CGSizeMake(5, 4);
    } else if (aspect_ratio < 1.4 && aspect_ratio > 1.3) {
        return CGSizeMake(4, 3);
    } else if (aspect_ratio < 1.6 && aspect_ratio > 1.4) {
        return CGSizeMake(3, 2);
    } else if (aspect_ratio < 1.7 && aspect_ratio > 1.6) {
        return CGSizeMake(16, 9);
    } else {
        return CGSizeMake(4, 3);
    }
}

- (CGSize)bufferSize {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.max_height;
    unsigned width = av_info.geometry.max_width;
    
    return CGSizeMake(width, height);
}

- (GLenum)pixelFormat {
    switch (pix_fmt)
    {
       case RETRO_PIXEL_FORMAT_0RGB1555:
            return GL_RGB5_A1; // GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT
       case RETRO_PIXEL_FORMAT_RGB565:
            return GL_RGB565;
       case RETRO_PIXEL_FORMAT_XRGB8888:
            return GL_RGBA8; // GL_RGBA8
       default:
            return GL_RGBA;
    }
}

- (GLenum)internalPixelFormat {
    switch (pix_fmt)
    {
       case RETRO_PIXEL_FORMAT_0RGB1555:
            return GL_RGB5_A1;
       case RETRO_PIXEL_FORMAT_RGB565:
            return GL_RGB565;
       case RETRO_PIXEL_FORMAT_XRGB8888:
            return GL_RGBA8;
       default:
            return GL_RGBA;
    }

    return GL_RGBA;
}

- (GLenum)pixelType {
    // GL_UNSIGNED_SHORT_5_6_5
    // GL_UNSIGNED_BYTE
    return GL_UNSIGNED_SHORT;
}

# pragma mark - Audio

- (double)audioSampleRate {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    double sample_rate = av_info.timing.sample_rate;
    return sample_rate ?: 44100;
}

- (NSUInteger)channelCount {
    return 2;
}

@end

# pragma mark - Options
@implementation PVLibRetroCore (Options)
- (void *)getVariable:(const char *)variable {
    WLOG(@"This should be done in sub class: %s", variable);
    return NULL;
}
@end

# pragma mark - Controls
@implementation PVLibRetroCore (Controls)
- (void)pollControllers {
    // TODO: This should warn or something if not in subclass
    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        
        if ([controller extendedGamepad]) {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            /* TODO: To support paddles we would need to circumvent libRetro's emulation of analog controls or drop libRetro and talk to stella directly like OpenEMU did */
            
            // D-Pad
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = (dpad.up.isPressed    || gamepad.leftThumbstick.up.isPressed);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = (dpad.down.isPressed  || gamepad.leftThumbstick.down.isPressed);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = (dpad.left.isPressed  || gamepad.leftThumbstick.left.isPressed);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = (dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed);

            // #688, use second thumb to control second player input if no controller active
            // some games used both joysticks for 1 player optionally
            if(playerIndex == 0 && self.controller2 == nil) {
                _pad[1][RETRO_DEVICE_ID_JOYPAD_UP]    = gamepad.rightThumbstick.up.isPressed;
                _pad[1][RETRO_DEVICE_ID_JOYPAD_DOWN]  = gamepad.rightThumbstick.down.isPressed;
                _pad[1][RETRO_DEVICE_ID_JOYPAD_LEFT]  = gamepad.rightThumbstick.left.isPressed;
                _pad[1][RETRO_DEVICE_ID_JOYPAD_RIGHT] = gamepad.rightThumbstick.right.isPressed;
            }

            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] =  gamepad.buttonB.isPressed || gamepad.rightTrigger.isPressed;
            // Booster
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = gamepad.buttonX.isPressed || gamepad.buttonY.isPressed || gamepad.leftTrigger.isPressed;
            
            // Reset
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.rightShoulder.isPressed;
            
            // Select
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.leftShoulder.isPressed;
   
            /*
             #define RETRO_DEVICE_ID_JOYPAD_B        0 == JoystickZeroFire1
             #define RETRO_DEVICE_ID_JOYPAD_Y        1 == Unmapped
             #define RETRO_DEVICE_ID_JOYPAD_SELECT   2 == ConsoleSelect
             #define RETRO_DEVICE_ID_JOYPAD_START    3 == ConsoleReset
             #define RETRO_DEVICE_ID_JOYPAD_UP       4 == Up
             #define RETRO_DEVICE_ID_JOYPAD_DOWN     5 == Down
             #define RETRO_DEVICE_ID_JOYPAD_LEFT     6 == Left
             #define RETRO_DEVICE_ID_JOYPAD_RIGHT    7 == Right
             #define RETRO_DEVICE_ID_JOYPAD_A        8 == JoystickZeroFire2
             #define RETRO_DEVICE_ID_JOYPAD_X        9 == JoystickZeroFire3
             #define RETRO_DEVICE_ID_JOYPAD_L       10 == ConsoleLeftDiffA
             #define RETRO_DEVICE_ID_JOYPAD_R       11 == ConsoleRightDiffA
             #define RETRO_DEVICE_ID_JOYPAD_L2      12 == ConsoleLeftDiffB
             #define RETRO_DEVICE_ID_JOYPAD_R2      13 == ConsoleRightDiffB
             #define RETRO_DEVICE_ID_JOYPAD_L3      14 == ConsoleColor
             #define RETRO_DEVICE_ID_JOYPAD_R3      15 == ConsoleBlackWhite
             */
        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // D-Pad
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;
            
            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] =  gamepad.buttonB.isPressed;
            // Booster
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = gamepad.buttonX.isPressed || gamepad.buttonY.isPressed;
            
            // Reset
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.rightShoulder.isPressed;
            
            // Select
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.leftShoulder.isPressed;
            
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.value > 0.5;

            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonX.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
        }
#endif
    }
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player
{
    // TODO: This should warn or something if not in subclass

    GCController *controller = nil;

    if (player == 0)
    {
        controller = self.controller1;
    }
    else
    {
        controller = self.controller2;
    }

    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        if (PVSettingsModel.shared.use8BitdoM30) // Maps the Sega Controls to the 8BitDo M30 if enabled in Settings / Controller
        { switch (buttonID) {
            case PVSega32XButtonUp:
                return [[[gamepad leftThumbstick] up] value] > 0.1;
            case PVSega32XButtonDown:
                return [[[gamepad leftThumbstick] down] value] > 0.1;
            case PVSega32XButtonLeft:
                return [[[gamepad leftThumbstick] left] value] > 0.1;
            case PVSega32XButtonRight:
                return [[[gamepad leftThumbstick] right] value] > 0.1;
            case PVSega32XButtonA:
                return [[gamepad buttonA] isPressed];
            case PVSega32XButtonB:
                return [[gamepad buttonB] isPressed];
            case PVSega32XButtonC:
                return [[gamepad rightShoulder] isPressed];
            case PVSega32XButtonX:
                return [[gamepad buttonX] isPressed];
            case PVSega32XButtonY:
                return [[gamepad buttonY] isPressed];
            case PVSega32XButtonZ:
                return [[gamepad leftShoulder] isPressed];
            case PVSega32XButtonMode:
                return [[gamepad leftTrigger] isPressed];
            case PVSega32XButtonStart:
#if TARGET_OS_TV
                return [[gamepad buttonMenu] isPressed]?:[[gamepad rightTrigger] isPressed];
#else
                return [[gamepad rightTrigger] isPressed];
#endif
            default:
                break;
        }}
        { switch (buttonID) {
            case PVSega32XButtonUp:
                return [[dpad up] isPressed]?:[[[gamepad leftThumbstick] up] isPressed];
            case PVSega32XButtonDown:
                return [[dpad down] isPressed]?:[[[gamepad leftThumbstick] down] isPressed];
            case PVSega32XButtonLeft:
                return [[dpad left] isPressed]?:[[[gamepad leftThumbstick] left] isPressed];
            case PVSega32XButtonRight:
                return [[dpad right] isPressed]?:[[[gamepad leftThumbstick] right] isPressed];
            case PVSega32XButtonA:
                return [[gamepad buttonX] isPressed];
            case PVSega32XButtonB:
                return [[gamepad buttonA] isPressed];
            case PVSega32XButtonC:
                return [[gamepad buttonB] isPressed];
            case PVSega32XButtonX:
                return [[gamepad buttonY] isPressed];
            case PVSega32XButtonY:
                return [[gamepad leftShoulder] isPressed];
            case PVSega32XButtonZ:
                return [[gamepad rightShoulder] isPressed];
            case PVSega32XButtonStart:
                return [[gamepad rightTrigger] isPressed];
             case PVSega32XButtonMode:
                return [[gamepad leftTrigger] isPressed];
            default:
                break;
        }}
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSega32XButtonUp:
                return [[dpad up] isPressed];
            case PVSega32XButtonDown:
                return [[dpad down] isPressed];
            case PVSega32XButtonLeft:
                return [[dpad left] isPressed];
            case PVSega32XButtonRight:
                return [[dpad right] isPressed];
            case PVSega32XButtonA:
                return [[gamepad buttonY] isPressed];
            case PVSega32XButtonB:
                return [[gamepad buttonX] isPressed];
            case PVSega32XButtonC:
                return [[gamepad buttonA] isPressed];
            case PVSega32XButtonX:
                return [[gamepad buttonB] isPressed];
            case PVSega32XButtonY:
                return [[gamepad leftShoulder] isPressed];
            case PVSega32XButtonZ:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSega32XButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVSega32XButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVSega32XButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVSega32XButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVSega32XButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            case PVSega32XButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            default:
                break;
        }
    }
#endif

    return 0;
}

@end
