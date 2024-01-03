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
@interface PVRetroArchCore (_3DOControls) <PV3DOSystemResponderClient>
@end

@implementation PVRetroArchCore (_3DOControls)
#pragma mark - Control
- (void)didPush3DOButton:(PV3DOButton)button forPlayer:(NSInteger)player {
    [self handle3DOButton:button forPlayer:player pressed:true value:1];
}

- (void)didRelease3DOButton:(PV3DOButton)button forPlayer:(NSInteger)player {
    [self handle3DOButton:button forPlayer:player pressed:false value:0];
}

- (void)didMove3DOJoystickDirection:(PV3DOButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self handle3DOButton:button forPlayer:player pressed:(value != 0) value:value];
}
- (void)handle3DOButton:(PV3DOButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    static float ltXAxis=0;
    static float ltYAxis=0;
    static float rtXAxis=0;
    static float rtYAxis=0;
    static float axisMult = 1.0;
    switch (button) {
        case(PV3DOButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV3DOButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV3DOButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV3DOButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV3DOButtonA):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PV3DOButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PV3DOButtonC):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PV3DOButtonL):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PV3DOButtonR):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PV3DOButtonX):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PV3DOButtonP):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
