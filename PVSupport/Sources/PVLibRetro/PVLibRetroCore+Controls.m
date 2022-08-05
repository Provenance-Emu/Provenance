//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

@import Foundation;
#import "PVLibretro.h"
@import GameController;

#import <PVSupport/PVSupport-Swift.h>
#import <UIKit/UIKeyConstants.h>

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

# pragma mark - Keyboard
@implementation PVLibRetroCore (Keyboard)
char * keyStringForKeyCode(int keyCode)
{
    // Proper key detection seems to want a switch statement, unfortunately
    switch (keyCode) {
        case 0: return("a");
        case 1: return("s");
        case 2: return("d");
        case 3: return("f");
        case 4: return("h");
        case 5: return("g");
        case 6: return("z");
        case 7: return("x");
        case 8: return("c");
        case 9: return("v");
        // what is 10?
        case 11: return("b");
        case 12: return("q");
        case 13: return("w");
        case 14: return("e");
        case 15: return("r");
        case 16: return("y");
        case 17: return("t");
        case 18: return("1");
        case 19: return("2");
        case 20: return("3");
        case 21: return("4");
        case 22: return("6");
        case 23: return("5");
        case 24: return("=");
        case 25: return("9");
        case 26: return("7");
        case 27: return("-");
        case 28: return("8");
        case 29: return("0");
        case 30: return("]");
        case 31: return("o");
        case 32: return("u");
        case 33: return("[");
        case 34: return("i");
        case 35: return("p");
        case 36: return("RETURN");
        case 37: return("l");
        case 38: return("j");
        case 39: return("'");
        case 40: return("k");
        case 41: return(";");
        case 42: return("\\");
        case 43: return(",");
        case 44: return("/");
        case 45: return("n");
        case 46: return("m");
        case 47: return(".");
        case 48: return("TAB");
        case 49: return("SPACE");
        case 50: return("`");
        case 51: return("DELETE");
        case 52: return("ENTER");
        case 53: return("ESCAPE");

        // some more missing codes abound, reserved I presume, but it would
        // have been helpful for Apple to have a document with them all listed

        case 65: return(".");

        case 67: return("*");

        case 69: return("+");

        case 71: return("CLEAR");

        case 75: return("/");
        case 76: return("ENTER");   // numberpad on full kbd

        case 78: return("-");

        case 81: return("=");
        case 82: return("0");
        case 83: return("1");
        case 84: return("2");
        case 85: return("3");
        case 86: return("4");
        case 87: return("5");
        case 88: return("6");
        case 89: return("7");

        case 91: return("8");
        case 92: return("9");

        case 96: return("F5");
        case 97: return("F6");
        case 98: return("F7");
        case 99: return("F3");
        case 100: return("F8");
        case 101: return("F9");

        case 103: return("F11");

        case 105: return("F13");

        case 107: return("F14");

        case 109: return("F10");

        case 111: return("F12");

        case 113: return("F15");
        case 114: return("HELP");
        case 115: return("HOME");
        case 116: return("PGUP");
        case 117: return("DELETE");  // full keyboard right side numberpad
        case 118: return("F4");
        case 119: return("END");
        case 120: return("F2");
        case 121: return("PGDN");
        case 122: return("F1");
        case 123: return("LEFT");
        case 124: return("RIGHT");
        case 125: return("DOWN");
        case 126: return("UP");

        default:
            // Unknown key, bail and note that RUI needs improvement
            return("");
//            fprintf(stderr, "%ld\tKey\t%c (DEBUG: %d)\n", currenttime, keyCode);
//            exit(EXIT_FAILURE);
    }
}

- (BOOL)gameSupportsKeyboard { return true; }
- (BOOL)requiresKeyboard { return false; }

- (void)keyUp:(GCKeyCode)key {
    unsigned keycode = virtualPhysicalKeyMap[@(key)];
    uint32_t character = (uint32_t)keyStringForKeyCode(key)[0];
    uint16_t key_modifiers = 0;
    keyboard_event(false, keycode, character, key_modifiers);
}

- (void)keyDown:(GCKeyCode)key {
    unsigned keycode = virtualPhysicalKeyMap[@(key)];
    uint32_t character = (uint32_t)keyStringForKeyCode(key)[0];
    uint16_t key_modifiers = 0;
    keyboard_event(true, keycode, character, key_modifiers);
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
