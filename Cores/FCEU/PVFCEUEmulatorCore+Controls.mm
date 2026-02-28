//
//  PVFCEUEmulatorCore+Controls.m
//  PVFCEU-iOS
//
//  Created by Joseph Mattiello on 11/3/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

#import "PVFCEUEmulatorCore+Controls.h"
#import "PVFCEUEmulatorCore.h"
@import PVCoreBridge;


#include "fceux/src/fceu.h"
//#include "fceux/src/driver.h"
//#include "fceux/src/input.h"
//#include "fceux/src/sound.h"
//#include "fceux/src/movie.h"
//#include "fceux/src/palette.h"
//#include "fceux/src/state.h"
//#include "fceux/src/emufile.h"

#define DEADZONE 0.1f
static const int NESMap[] = {JOY_UP, JOY_DOWN, JOY_LEFT, JOY_RIGHT, JOY_A, JOY_B, JOY_START, JOY_SELECT};

@implementation PVFCEUEmulatorCoreBridge (Controls)

# pragma mark - Input

- (void)didPushNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    int playerShift = player != 0 ? 8 : 0;

    pad[player][0] |= NESMap[button] << playerShift;
}

- (void)didReleaseNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    int playerShift = player != 0 ? 8 : 0;

    pad[player][0] &= ~NESMap[button] << playerShift;
}

- (void)updateControllers {
    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++)
    {
        GCController *controller = nil;
        int playerShift = playerIndex != 0 ? 8: 0;

        if (self.controller1 && playerIndex == 0)
        {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }

        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *gamepad = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            GCDualSenseGamepad *dualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]] ?  (GCDualSenseGamepad *)gamepad : nil;
            GCDualShockGamepad *dualShock = [gamepad isKindOfClass:[GCDualShockGamepad class]] ?  (GCDualShockGamepad *)gamepad : nil;
            GCXboxGamepad *xbox = [gamepad isKindOfClass:[GCXboxGamepad class]] ? (GCXboxGamepad *)gamepad : nil;
            GCControllerButtonInput *selectButton = nil;
            GCControllerButtonInput *startButton = nil;
            GCControllerButtonInput *shareLikeButton = nil;
            GCControllerButtonInput *psTouchpadButton = nil;
            BOOL shareLikePressed = NO;
            BOOL psTouchpadPressed = NO;

            NSDictionary<NSString *, GCControllerButtonInput *> *profileButtons = controller.physicalInputProfile.buttons;
            if ([profileButtons isKindOfClass:[NSDictionary class]]) {
                // Some controllers expose Share/Create/Capture only through physical profile button names.
                shareLikeButton = profileButtons[@"Button Share"];
                if (!shareLikeButton) {
                    shareLikeButton = profileButtons[@"Button Create"];
                }
                if (!shareLikeButton) {
                    shareLikeButton = profileButtons[@"Button Capture"];
                }
            }

            if (@available(iOS 14.0, tvOS 14.0, *)) {
                if (dualSense && dualSense.touchpadButton) {
                    psTouchpadButton = dualSense.touchpadButton;
                } else if (dualShock && dualShock.touchpadButton) {
                    psTouchpadButton = dualShock.touchpadButton;
                }
            }

            if (dualSense || dualShock) {
                selectButton = psTouchpadButton ? psTouchpadButton : shareLikeButton;
                if (!selectButton) {
                    selectButton = gamepad.buttonOptions;
                }
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

            if (shareLikeButton) {
                shareLikePressed = shareLikeButton.isPressed;
            }
            if (psTouchpadButton) {
                psTouchpadPressed = psTouchpadButton.isPressed;
            }


            (dpad.up.isPressed || gamepad.leftThumbstick.up.value > DEADZONE) ? pad[playerIndex][0] |= JOY_UP << playerShift : pad[playerIndex][0] &= ~JOY_UP << playerShift;
            (dpad.down.isPressed || gamepad.leftThumbstick.down.value > DEADZONE) ? pad[playerIndex][0] |= JOY_DOWN << playerShift : pad[playerIndex][0] &= ~JOY_DOWN << playerShift;
            (dpad.left.isPressed || gamepad.leftThumbstick.left.value > DEADZONE) ? pad[playerIndex][0] |= JOY_LEFT << playerShift : pad[playerIndex][0] &= ~JOY_LEFT << playerShift;
            (dpad.right.isPressed || gamepad.leftThumbstick.right.value > DEADZONE) ? pad[playerIndex][0] |= JOY_RIGHT << playerShift : pad[playerIndex][0] &= ~JOY_RIGHT << playerShift;

            (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed) ? pad[playerIndex][0] |= JOY_B << playerShift : pad[playerIndex][0] &= ~JOY_B << playerShift;
            (gamepad.buttonX.isPressed || gamepad.buttonB.isPressed) ? pad[playerIndex][0] |= JOY_A << playerShift : pad[playerIndex][0] &= ~JOY_A << playerShift;

            (gamepad.leftShoulder.isPressed || gamepad.leftTrigger.isPressed || (selectButton && selectButton.isPressed) || shareLikePressed || psTouchpadPressed) ? pad[playerIndex][0] |= JOY_SELECT << playerShift : pad[playerIndex][0] &= ~JOY_SELECT << playerShift;
            (gamepad.rightShoulder.isPressed || gamepad.rightTrigger.isPressed || startButton.isPressed) ? pad[playerIndex][0] |= JOY_START << playerShift : pad[playerIndex][0] &= ~JOY_START << playerShift;
        }
#if TARGET_OS_TV
        else if ([controller microGamepad])
        {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            (dpad.up.value > 0.5) ? pad[playerIndex][0] |= JOY_UP << playerShift : pad[playerIndex][0] &= ~JOY_UP << playerShift;
            (dpad.down.value > 0.5) ? pad[playerIndex][0] |= JOY_DOWN << playerShift : pad[playerIndex][0] &= ~JOY_DOWN << playerShift;
            (dpad.left.value > 0.5) ? pad[playerIndex][0] |= JOY_LEFT << playerShift : pad[playerIndex][0] &= ~JOY_LEFT << playerShift;
            (dpad.right.value > 0.5) ? pad[playerIndex][0] |= JOY_RIGHT << playerShift : pad[playerIndex][0] &= ~JOY_RIGHT << playerShift;

            gamepad.buttonX.isPressed ? pad[playerIndex][0] |= JOY_B << playerShift : pad[playerIndex][0] &= ~JOY_B << playerShift;
            gamepad.buttonA.isPressed ? pad[playerIndex][0] |= JOY_A << playerShift : pad[playerIndex][0] &= ~JOY_A << playerShift;
        }
#endif
    }
}

@end
