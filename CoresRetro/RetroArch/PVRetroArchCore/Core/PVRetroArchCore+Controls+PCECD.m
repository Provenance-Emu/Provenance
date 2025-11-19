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
@interface PVRetroArchCoreBridge (PCEControls) <PVPCECDSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (PCEControls)
#pragma mark - Control
- (void)didPushPCEButton:(PVPCECDButton)button forPlayer:(NSInteger)player {
    [self handlePCEButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleasePCEButton:(PVPCECDButton)button forPlayer:(NSInteger)player {
    [self handlePCEButton:button forPlayer:player pressed:false value:0];
}

- (void)didMovePCEJoystickDirection:(PVPCECDButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self handlePCEButton:button forPlayer:player pressed:(value != 0) value:value];
}
- (void)handlePCEButton:(PVPCECDButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {

    switch (button) {
        case(PVPCECDButtonUp):
            yAxis = pressed ? 1.0 :0;
            DLOG(@"Pressed %@ : %@", @"up", pressed ? @"Yes" : @"No");
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCECDButtonDown):
            yAxis = pressed ? -1.0 :0;
            DLOG(@"Pressed %@ : %@", @"down", pressed ? @"Yes" : @"No");
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCECDButtonLeft):
            xAxis = pressed ? -1.0 :0;
            DLOG(@"Pressed %@ : %@", @"left", pressed ? @"Yes" : @"No");
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCECDButtonRight):
            xAxis = pressed ? 1.0 :0;
            DLOG(@"Pressed %@ : %@", @"right", pressed ? @"Yes" : @"No");
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCECDButtonButton1):
            [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonButton2):
            [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonButton3):
            [touch_controller.extendedGamepad.buttonX setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonButton4):
            [touch_controller.extendedGamepad.buttonY setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonButton5):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonButton6):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonMode):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonCount):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVPCECDButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1 : 0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed ? 1 : 0];
            break;
        case(PVPCECDButtonRun):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed ? 1 : 0];
            break;
    }
}
@end
