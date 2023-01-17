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
@interface PVRetroArchCore (PCEControls) <PVPCESystemResponderClient>
@end

@implementation PVRetroArchCore (PCEControls)
#pragma mark - Control
- (void)didPushPCEButton:(PVPCEButton)button forPlayer:(NSInteger)player {
    [self handlePCEButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleasePCEButton:(PVPCEButton)button forPlayer:(NSInteger)player {
    [self handlePCEButton:button forPlayer:player pressed:false value:0];
}

- (void)didMovePCEJoystickDirection:(PVPCEButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self handlePCEButton:button forPlayer:player pressed:(value != 0) value:value];
}
- (void)handlePCEButton:(PVPCEButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    static float ltXAxis=0;
    static float ltYAxis=0;
    static float rtXAxis=0;
    static float rtYAxis=0;
    static float axisMult = 1.0;
    switch (button) {
        case(PVPCEButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCEButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCEButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCEButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVPCEButtonButton1):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVPCEButtonButton2):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVPCEButtonButton3):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVPCEButtonButton4):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVPCEButtonButton5):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVPCEButtonButton6):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVPCEButtonMode):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVPCEButtonCount):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVPCEButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVPCEButtonRun):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
