//
//  PVTGBDualCore+Controls.mm
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualCore+Controls.h"
#include "libretro.h"

@implementation PVTGBDualCore (Controls)

const int GBDualMap[] = {
    RETRO_DEVICE_ID_JOYPAD_UP,
    RETRO_DEVICE_ID_JOYPAD_DOWN,
    RETRO_DEVICE_ID_JOYPAD_LEFT,
    RETRO_DEVICE_ID_JOYPAD_RIGHT,
    RETRO_DEVICE_ID_JOYPAD_A,
    RETRO_DEVICE_ID_JOYPAD_B,
    RETRO_DEVICE_ID_JOYPAD_START,
    RETRO_DEVICE_ID_JOYPAD_SELECT,
};

- (void)didPushGBButton:(PVGBButton)button forPlayer:(NSUInteger)player {
    _gb_pad[player][GBDualMap[button]] = 1;
}


- (void)didReleaseGBButton:(PVGBButton)button forPlayer:(NSUInteger)player {
    _gb_pad[player][GBDualMap[button]] = 0;
}

- (void)pollControllers {
    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++)
    {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1) {
            controller = self.controller2;
        }
        
        if ([controller extendedGamepad]) {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.isPressed    || gamepad.leftThumbstick.up.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.isPressed  || gamepad.leftThumbstick.down.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.isPressed  || gamepad.leftThumbstick.left.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonB.isPressed || gamepad.buttonY.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.leftShoulder.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.rightShoulder.isPressed;
        }
        else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonB.isPressed || gamepad.buttonY.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.leftShoulder.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.rightShoulder.isPressed;
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.value > 0.5;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.value > 0.5;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.value > 0.5;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.value > 0.5;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonX.isPressed;
        }
#endif
    }
}

@end
