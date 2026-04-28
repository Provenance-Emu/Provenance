//
//  PVRetroArchCoreBridge+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PVCoreBridge;
#import "./cocoa_common.h"

/* RetroArch Includes */
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <boolean.h>
#include <Availability.h>
#import <GameController/GameController.h>
#include "libretro-common/include/libretro.h"
#include "../../frontend/frontend.h"
#include "../../tasks/tasks_internal.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../input/drivers_keyboard/keyboard_event_apple.h"
#include "../../input/input_keymaps.h"
#include "../../configuration.h"
#include "../../retroarch.h"
#include "../../verbosity.h"
#include "../ui_companion_driver.h"

extern GCController *touch_controller;
@interface PVRetroArchCoreBridge (MAMEControls) <PVMAMESystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (MAMEControls)
#pragma mark - Control
- (void)didPushMAMEButton:(PVMAMEButton)button forPlayer:(NSInteger)player {
    [self handleMAMEButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseMAMEButton:(PVMAMEButton)button forPlayer:(NSInteger)player {
    [self handleMAMEButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveMAMEJoystickDirection:(PVMAMEButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVMAMEButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
        case(PVMAMEButtonRightAnalog):
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
    }
}

- (void)handleMAMEButton:(PVMAMEButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVMAMEButtonUp):
            yAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVMAMEButtonDown):
            yAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVMAMEButtonLeft):
            xAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVMAMEButtonRight):
            xAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVMAMEButtonCross):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVMAMEButtonCircle):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVMAMEButtonTriangle):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVMAMEButtonSquare):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVMAMEButtonL1):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVMAMEButtonR1):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVMAMEButtonL2):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVMAMEButtonR2):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVMAMEButtonL3):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVMAMEButtonR3):
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            break;
        case(PVMAMEButtonSelect):
            // Select maps to RetroPad Select via buttonOptions only.
            // Coin (Insert Coin) is now a dedicated button — see PVMAMEButtonCoin below.
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PVMAMEButtonCoin):
            // buttonHome is mapped to JOYPAD_SELECT in RetroArch's cocoa input driver,
            // which MAME treats as Insert Coin. This de-overloads Select from Coin so
            // hardware that distinguishes the two can drive each independently.
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVMAMEButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}

#pragma mark - Keyboard Support

- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return NO; }

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(true, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(false, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

@end
