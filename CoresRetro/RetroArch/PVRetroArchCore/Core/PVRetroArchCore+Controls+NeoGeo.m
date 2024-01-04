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
@interface PVRetroArchCore (NeoGeoControls) <PVNeoGeoSystemResponderClient>
@end

@implementation PVRetroArchCore (NeoGeoControls)
#pragma mark - Control
- (void)didPushNeoGeoButton:(PVNeoGeoButton)button forPlayer:(NSInteger)player {
    [self handleNeoGeoButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseNeoGeoButton:(PVNeoGeoButton)button forPlayer:(NSInteger)player {
    [self handleNeoGeoButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveNeoGeoJoystickDirection:(PVNeoGeoButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVNeoGeoButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
        case(PVNeoGeoButtonRightAnalog):
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
    }
}

- (void)handleNeoGeoButton:(PVNeoGeoButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    switch (button) {
        case(PVNeoGeoButtonUp):
            yAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNeoGeoButtonDown):
            yAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNeoGeoButtonLeft):
            xAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNeoGeoButtonRight):
            xAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNeoGeoButtonCross):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonCircle):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonTriangle):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonSquare):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonL1):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonR1):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonL2):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonR2):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonL3):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonR3):
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVNeoGeoButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
