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
    if (button == PVDSButtonScreenSwap || button == PVDSButtonRotate) {
        if (button == PVDSButtonRotate) {
            [self screenRotate];
        } else {
            [self screenSwap];
        }
        return;
    }

    /// Map PVDSButton to RETRO_DEVICE_ID_JOYPAD values
    unsigned retro_id;
    switch(button) {
        case PVDSButtonUp:
            retro_id = RETRO_DEVICE_ID_JOYPAD_UP;
            break;
        case PVDSButtonDown:
            retro_id = RETRO_DEVICE_ID_JOYPAD_DOWN;
            break;
        case PVDSButtonLeft:
            retro_id = RETRO_DEVICE_ID_JOYPAD_LEFT;
            break;
        case PVDSButtonRight:
            retro_id = RETRO_DEVICE_ID_JOYPAD_RIGHT;
            break;
        case PVDSButtonA:
            retro_id = RETRO_DEVICE_ID_JOYPAD_A;
            break;
        case PVDSButtonB:
            retro_id = RETRO_DEVICE_ID_JOYPAD_B;
            break;
        case PVDSButtonX:
            retro_id = RETRO_DEVICE_ID_JOYPAD_X;
            break;
        case PVDSButtonY:
            retro_id = RETRO_DEVICE_ID_JOYPAD_Y;
            break;
        case PVDSButtonL:
            retro_id = RETRO_DEVICE_ID_JOYPAD_L;
            break;
        case PVDSButtonR:
            retro_id = RETRO_DEVICE_ID_JOYPAD_R;
            break;
        case PVDSButtonStart:
            retro_id = RETRO_DEVICE_ID_JOYPAD_START;
            break;
        case PVDSButtonSelect:
            retro_id = RETRO_DEVICE_ID_JOYPAD_SELECT;
            break;
        default:
            return;
    }

    /// Update the pad state directly
    _pad[player][retro_id] = 1;
}

-(void)didReleaseDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    /// Handle special cases
    if (button == PVDSButtonScreenSwap || button == PVDSButtonRotate) {
        return;
    }

    /// Map and update pad state
    unsigned retro_id;
    switch(button) {
        case PVDSButtonUp:
            retro_id = RETRO_DEVICE_ID_JOYPAD_UP;
            break;
        case PVDSButtonDown:
            retro_id = RETRO_DEVICE_ID_JOYPAD_DOWN;
            break;
        case PVDSButtonLeft:
            retro_id = RETRO_DEVICE_ID_JOYPAD_LEFT;
            break;
        case PVDSButtonRight:
            retro_id = RETRO_DEVICE_ID_JOYPAD_RIGHT;
            break;
        case PVDSButtonA:
            retro_id = RETRO_DEVICE_ID_JOYPAD_A;
            break;
        case PVDSButtonB:
            retro_id = RETRO_DEVICE_ID_JOYPAD_B;
            break;
        case PVDSButtonX:
            retro_id = RETRO_DEVICE_ID_JOYPAD_X;
            break;
        case PVDSButtonY:
            retro_id = RETRO_DEVICE_ID_JOYPAD_Y;
            break;
        case PVDSButtonL:
            retro_id = RETRO_DEVICE_ID_JOYPAD_L;
            break;
        case PVDSButtonR:
            retro_id = RETRO_DEVICE_ID_JOYPAD_R;
            break;
        case PVDSButtonStart:
            retro_id = RETRO_DEVICE_ID_JOYPAD_START;
            break;
        case PVDSButtonSelect:
            retro_id = RETRO_DEVICE_ID_JOYPAD_SELECT;
            break;
        default:
            return;
    }

    _pad[player][retro_id] = 0;
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
