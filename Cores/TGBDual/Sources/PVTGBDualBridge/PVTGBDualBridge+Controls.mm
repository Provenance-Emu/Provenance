//
//  PVTGBDualCore+Controls.mm
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualBridge+Controls.h"
@import PVTGBDualCPP;
#include "libretro.h"

@implementation PVTGBDualBridge (Controls)

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

- (void)didPushGBButton:(PVGBButton)button forPlayer:(NSInteger)player {
    _gb_pad[player][GBDualMap[button]] = 1;
}


- (void)didReleaseGBButton:(PVGBButton)button forPlayer:(NSInteger)player {
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
            
            
            GCDualSenseGamepad *dualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]] ?  (GCDualSenseGamepad *)gamepad : nil;
            GCDualShockGamepad *dualShock = [gamepad isKindOfClass:[GCDualShockGamepad class]] ?  (GCDualShockGamepad *)gamepad : nil;
            GCXboxGamepad *xbox = [gamepad isKindOfClass:[GCXboxGamepad class]] ? (GCXboxGamepad *)gamepad : nil;
            GCControllerButtonInput *selectButton = nil;
            GCControllerButtonInput *startButton = nil;
            GCControllerButtonInput *shareLikeButton = nil;

            NSDictionary<NSString *, GCControllerButtonInput *> *profileButtons = controller.physicalInputProfile.buttons;
            if ([profileButtons isKindOfClass:[NSDictionary class]]) {
                shareLikeButton = profileButtons[@"Button Share"];
                if (!shareLikeButton) {
                    shareLikeButton = profileButtons[@"Button Create"];
                }
                if (!shareLikeButton) {
                    shareLikeButton = profileButtons[@"Button Capture"];
                }
            }

            if (dualSense || dualShock) {
                selectButton = shareLikeButton;
                startButton = gamepad.buttonMenu;
            } else if (xbox) {
                selectButton = xbox.buttonShare;
                startButton = xbox.buttonMenu;
            } else {
                startButton = gamepad.buttonOptions ? gamepad.buttonOptions : startButton;
                if (!selectButton) {
                    selectButton = shareLikeButton;
                }
            }
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.isPressed    || gamepad.leftThumbstick.up.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.isPressed  || gamepad.leftThumbstick.down.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.isPressed  || gamepad.leftThumbstick.left.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonB.isPressed || gamepad.buttonY.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed;
            
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.leftShoulder.isPressed || startButton.isPressed;
            _gb_pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.rightShoulder.isPressed || (selectButton && selectButton.isPressed);
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
