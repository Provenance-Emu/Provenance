//
//  PVDesmume2015Core+Controls.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVDesmume2015/PVDesmume2015.h>
#import <Foundation/Foundation.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;
#import "NDSSystem.h"

#include "libretro.h"
extern retro_log_printf_t log_cb;
extern retro_environment_t environ_cb;

@implementation PVDesmume2015CoreBridge (Controls)

#pragma mark - Control
//
//- (void)pollControllers {
//    for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
//    {
//        GCController *controller = nil;
//
//        if (self.controller1 && playerIndex == 0)
//        {
//            controller = self.controller1;
//        }
//        else if (self.controller2 && playerIndex == 1)
//        {
//            controller = self.controller2;
//        }
//        else if (self.controller3 && playerIndex == 3)
//        {
//            controller = self.controller3;
//        }
//        else if (self.controller4 && playerIndex == 4)
//        {
//            controller = self.controller4;
//        }
//
//        if ([controller extendedGamepad])
//        {
//            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
//            GCControllerDirectionPad *dpad = [gamepad dpad];
//
//            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
//            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
//            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
//            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);
//
//            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
//            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
//            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
//            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);
//
//            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
//            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
//
//            gamepad.leftTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Z) : kcode[playerIndex] |= (DC_BTN_Z);
//            gamepad.rightTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_START) : kcode[playerIndex] |= (DC_BTN_START);
//
//
//            float xvalue = gamepad.leftThumbstick.xAxis.value;
//            s8 x=(s8)(xvalue*127);
//            joyx[0] = x;
//
//            float yvalue = gamepad.leftThumbstick.yAxis.value;
//            s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
//            joyy[0] = y;
//
//        } else if ([controller gamepad]) {
//            GCGamepad *gamepad = [controller gamepad];
//            GCControllerDirectionPad *dpad = [gamepad dpad];
//
//            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
//            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
//            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
//            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);
//
//            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
//            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
//            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
//            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);
//
//            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
//            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
//        }
//#if TARGET_OS_TV
//        else if ([controller microGamepad]) {
//            GCMicroGamepad *gamepad = [controller microGamepad];
//            GCControllerDirectionPad *dpad = [gamepad dpad];
//        }
//#endif
//    }
//}

- (void)screenSwap {
    // TODO
}

- (void)screenRotate {
    /// Current layout state stored as static to persist between calls
    static int currentLayout = LAYOUT_TOP_BOTTOM;

    /// Cycle through the layouts in a logical order
    currentLayout = (currentLayout + 1) % 8;

    /// Map our layout enum to the string values expected by desmume
    const char *layoutValue;
    switch(currentLayout) {
        case LAYOUT_TOP_BOTTOM:
            layoutValue = "top/bottom";
            break;
        case LAYOUT_BOTTOM_TOP:
            layoutValue = "bottom/top";
            break;
        case LAYOUT_LEFT_RIGHT:
            layoutValue = "left/right";
            break;
        case LAYOUT_RIGHT_LEFT:
            layoutValue = "right/left";
            break;
        case LAYOUT_TOP_ONLY:
            layoutValue = "top only";
            break;
        case LAYOUT_BOTTOM_ONLY:
            layoutValue = "bottom only";
            break;
        case LAYOUT_HYBRID_TOP_ONLY:
            layoutValue = "hybrid/top";
            break;
        case LAYOUT_HYBRID_BOTTOM_ONLY:
            layoutValue = "hybrid/bottom";
            break;
    }

    /// Override the getVariable response for screen layout
    extern int current_layout;
    current_layout = currentLayout;

    /// Force a check of variables on next frame
    bool updated = true;
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated);
}

-(void)didPushDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    /// Handle special cases first
    if (button == PVDSButtonScreenSwap) {
        [self screenSwap];
        return;
    } else if (button == PVDSButtonRotate) {
        [self screenRotate];
        return;
    }

    /// Map PVDSButton to NDS button states
    bool R = false, L = false, D = false, U = false, T = false;
    bool S = false, B = false, A = false, Y = false, X = false;
    bool W = false, E = false, G = false, F = false;

    switch(button) {
        case PVDSButtonUp:
            U = true;
            break;
        case PVDSButtonDown:
            D = true;
            break;
        case PVDSButtonLeft:
            L = true;
            break;
        case PVDSButtonRight:
            R = true;
            break;
        case PVDSButtonA:
            A = true;
            break;
        case PVDSButtonB:
            B = true;
            break;
        case PVDSButtonX:
            X = true;
            break;
        case PVDSButtonY:
            Y = true;
            break;
        case PVDSButtonL:
            W = true; /// Left shoulder is W in desmume
            break;
        case PVDSButtonR:
            E = true; /// Right shoulder is E in desmume
            break;
        case PVDSButtonStart:
            S = true;
            break;
        case PVDSButtonSelect:
            T = true;
            break;
        default:
            break;
    }

    /// Set the button states in desmume
    NDS_setPad(R, L, D, U, T, S, B, A, Y, X, W, E, G, F);
}

-(void)didReleaseDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    /// Handle special cases first
    if (button == PVDSButtonScreenSwap || button == PVDSButtonRotate) {
        return;
    }

    /// Get current button states from desmume
    const UserInput& currentInput = NDS_getRawUserInput();
    const UserButtons& buttons = currentInput.buttons;

    /// Map current states, but set the released button to false
    bool R = buttons.R, L = buttons.L, D = buttons.D, U = buttons.U;
    bool T = buttons.T, S = buttons.S, B = buttons.B, A = buttons.A;
    bool Y = buttons.Y, X = buttons.X, W = buttons.W, E = buttons.E;
    bool G = buttons.G, F = buttons.F;

    /// Update the released button's state
    switch(button) {
        case PVDSButtonUp:
            U = false;
            break;
        case PVDSButtonDown:
            D = false;
            break;
        case PVDSButtonLeft:
            L = false;
            break;
        case PVDSButtonRight:
            R = false;
            break;
        case PVDSButtonA:
            A = false;
            break;
        case PVDSButtonB:
            B = false;
            break;
        case PVDSButtonX:
            X = false;
            break;
        case PVDSButtonY:
            Y = false;
            break;
        case PVDSButtonL:
            W = false; /// Left shoulder is W in desmume
            break;
        case PVDSButtonR:
            E = false; /// Right shoulder is E in desmume
            break;
        case PVDSButtonStart:
            S = false;
            break;
        case PVDSButtonSelect:
            T = false;
            break;
        default:
            break;
    }

    /// Update button states in desmume
    NDS_setPad(R, L, D, U, T, S, B, A, Y, X, W, E, G, F);
}

- (void)didMoveDSJoystickDirection:(enum PVDSButton)button
                            withValue:(CGFloat)value
                            forPlayer:(NSInteger)player {

}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self didMoveDSJoystickDirection:(enum PVDSButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushDSButton:(PVDSButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseDSButton:(PVDSButton)button forPlayer:player];
}

@end
