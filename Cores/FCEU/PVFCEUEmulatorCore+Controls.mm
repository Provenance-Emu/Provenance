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
@import PVCoreObjCBridge;


#include "fceux/src/fceu.h"
//#include "fceux/src/driver.h"
//#include "fceux/src/input.h"
//#include "fceux/src/sound.h"
//#include "fceux/src/movie.h"
//#include "fceux/src/palette.h"
//#include "fceux/src/state.h"
//#include "fceux/src/emufile.h"

#define DEADZONE 0.1f
static const uint32_t NESMap[] = {JOY_UP, JOY_DOWN, JOY_LEFT, JOY_RIGHT, JOY_A, JOY_B, JOY_START, JOY_SELECT};

// FCEU packs all 4 players into 2 ports (32-bit each):
//   Port 0 (pad[0][0]): P1 = bits 0-7, P3 = bits 16-23
//   Port 1 (pad[1][0]): P2 = bits 8-15, P4 = bits 24-31
static inline int fceuPortIndex(NSInteger player) {
    return (player == 0 || player == 2) ? 0 : 1;
}
static inline int fceuPlayerShift(NSInteger player) {
    switch (player) {
        case 0: return 0;
        case 1: return 8;
        case 2: return 16;
        case 3: return 24;
        default: return 0;
    }
}

@implementation PVFCEUEmulatorCoreBridge (Controls)

# pragma mark - Input

- (void)didPushNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    int portIndex = fceuPortIndex(player);
    int shift = fceuPlayerShift(player);
    pad[portIndex][0] |= NESMap[button] << shift;
}

- (void)didReleaseNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    int portIndex = fceuPortIndex(player);
    int shift = fceuPlayerShift(player);
    pad[portIndex][0] &= ~(NESMap[button] << shift);
}

- (void)updateControllers {
    // FCEU packs 4 players into 2 ports. Iterate all 4 player slots.
    for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
    {
        GCController *controller = nil;
        int portIndex = fceuPortIndex(playerIndex);
        int playerShift = fceuPlayerShift(playerIndex);

        switch (playerIndex) {
            case 0: controller = self.controller1; break;
            case 1: controller = self.controller2; break;
            case 2: controller = self.controller3; break;
            case 3: controller = self.controller4; break;
            default: break;
        }

        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *gamepad = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            GCControllerButtonInput *selectButton = nil;
            GCControllerButtonInput *startButton = nil;
            // NES has Start and Select. Use shared utility with PS touchpad and share-like fallbacks.
            PVResolveStartSelectShareButtons(controller, &startButton, &selectButton, nil);


            (dpad.up.isPressed || gamepad.leftThumbstick.up.value > DEADZONE) ? pad[portIndex][0] |= JOY_UP << playerShift : pad[portIndex][0] &= ~(JOY_UP << playerShift);
            (dpad.down.isPressed || gamepad.leftThumbstick.down.value > DEADZONE) ? pad[portIndex][0] |= JOY_DOWN << playerShift : pad[portIndex][0] &= ~(JOY_DOWN << playerShift);
            (dpad.left.isPressed || gamepad.leftThumbstick.left.value > DEADZONE) ? pad[portIndex][0] |= JOY_LEFT << playerShift : pad[portIndex][0] &= ~(JOY_LEFT << playerShift);
            (dpad.right.isPressed || gamepad.leftThumbstick.right.value > DEADZONE) ? pad[portIndex][0] |= JOY_RIGHT << playerShift : pad[portIndex][0] &= ~(JOY_RIGHT << playerShift);

            (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed) ? pad[portIndex][0] |= JOY_B << playerShift : pad[portIndex][0] &= ~(JOY_B << playerShift);
            (gamepad.buttonX.isPressed || gamepad.buttonB.isPressed) ? pad[portIndex][0] |= JOY_A << playerShift : pad[portIndex][0] &= ~(JOY_A << playerShift);

            (gamepad.leftShoulder.isPressed || gamepad.leftTrigger.isPressed || (selectButton && selectButton.isPressed)) ? pad[portIndex][0] |= JOY_SELECT << playerShift : pad[portIndex][0] &= ~(JOY_SELECT << playerShift);
            (gamepad.rightShoulder.isPressed || gamepad.rightTrigger.isPressed || (startButton && startButton.isPressed)) ? pad[portIndex][0] |= JOY_START << playerShift : pad[portIndex][0] &= ~(JOY_START << playerShift);
        }
#if TARGET_OS_TV
        else if ([controller microGamepad])
        {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            (dpad.up.value > 0.5) ? pad[portIndex][0] |= JOY_UP << playerShift : pad[portIndex][0] &= ~(JOY_UP << playerShift);
            (dpad.down.value > 0.5) ? pad[portIndex][0] |= JOY_DOWN << playerShift : pad[portIndex][0] &= ~(JOY_DOWN << playerShift);
            (dpad.left.value > 0.5) ? pad[portIndex][0] |= JOY_LEFT << playerShift : pad[portIndex][0] &= ~(JOY_LEFT << playerShift);
            (dpad.right.value > 0.5) ? pad[portIndex][0] |= JOY_RIGHT << playerShift : pad[portIndex][0] &= ~(JOY_RIGHT << playerShift);

            gamepad.buttonX.isPressed ? pad[portIndex][0] |= JOY_B << playerShift : pad[portIndex][0] &= ~(JOY_B << playerShift);
            gamepad.buttonA.isPressed ? pad[portIndex][0] |= JOY_A << playerShift : pad[portIndex][0] &= ~(JOY_A << playerShift);
        }
#endif
    }
}

@end
