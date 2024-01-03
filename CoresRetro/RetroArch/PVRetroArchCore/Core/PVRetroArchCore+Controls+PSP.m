//
//  PVRetroArchCore+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Controls.h"
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
@interface PVRetroArchCore (PSPControls) <PVPSPSystemResponderClient>
@end

@implementation PVRetroArchCore (PSPControls)
#pragma mark - Control
- (void)didPushPSPButton:(PVPSPButton)button forPlayer:(NSInteger)player {
    [self handlePSPButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleasePSPButton:(PVPSPButton)button forPlayer:(NSInteger)player {
    [self handlePSPButton:button forPlayer:player pressed:false value:0];
}

- (void)didMovePSPJoystickDirection:(PVPSPButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVPSPButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
    }
}

- (void)handlePSPButton:(PVPSPButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    switch (button) {
        case(PVPSPButtonUp):
            yAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPSPButtonDown):
            yAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPSPButtonLeft):
            xAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPSPButtonRight):
            xAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPSPButtonCross):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVPSPButtonCircle):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVPSPButtonTriangle):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVPSPButtonSquare):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVPSPButtonL1):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVPSPButtonR1):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVPSPButtonL2):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVPSPButtonR2):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVPSPButtonL3):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVPSPButtonR3):
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            break;
        case(PVPSPButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVPSPButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
