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
@interface PVRetroArchCoreBridge (PSXControls) <PVPS2SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (PSXControls)
#pragma mark - Control
- (void)didPushPS2Button:(PVPS2Button)button forPlayer:(NSInteger)player {
    [self handlePSXButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleasePS2Button:(PVPS2Button)button forPlayer:(NSInteger)player {
    [self handlePSXButton:button forPlayer:player pressed:false value:0];
}

- (void)didMovePS2JoystickDirection:(PVPS2Button)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVPS2ButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
        case(PVPS2ButtonRightAnalog):
            if (self.bindAnalogDpad) {
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            }
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
    }
}
- (void)handlePSXButton:(PVPS2Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {

    static float axisRounding = 0.22;

    switch (button) {
        case(PVPS2ButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPS2ButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPS2ButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPS2ButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPS2ButtonCross):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVPS2ButtonCircle):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVPS2ButtonTriangle):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVPS2ButtonSquare):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVPS2ButtonL1):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVPS2ButtonR1):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVPS2ButtonL2):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVPS2ButtonR2):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVPS2ButtonL3):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVPS2ButtonR3):
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            break;
        case(PVPS2ButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVPS2ButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
