//
//  PVRetroArchCore+Controls+SG1000.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/23/25.
//  Copyright © 2025 Provenance. All rights reserved.
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

@interface PVRetroArchCoreBridge (SG1000Controls) <PVSG1000SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (SG1000Controls)
#pragma mark - Control

- (void)didPushSG1000Button:(PVSG1000Button)button forPlayer:(NSInteger)player {
    [self handleSG1000Button:button forPlayer:player pressed:true];
}

- (void)didReleaseSG1000Button:(PVSG1000Button)button forPlayer:(NSInteger)player {
    [self handleSG1000Button:button forPlayer:player pressed:false];
}

- (void)handleSG1000Button:(PVSG1000Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis = 0;
    static float yAxis = 0;

    switch (button) {
        case PVSG1000ButtonUp:
            yAxis = pressed ? (!xAxis ? 1.0 : 0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVSG1000ButtonDown:
            yAxis = pressed ? (!xAxis ? -1.0 : -0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVSG1000ButtonLeft:
            xAxis = pressed ? (!yAxis ? -1.0 : -0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVSG1000ButtonRight:
            xAxis = pressed ? (!yAxis ? 1.0 : 0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVSG1000ButtonB:
            // Button 1 → RETRO_DEVICE_ID_JOYPAD_B → GCController buttonA (south)
            [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1 : 0];
            break;
        case PVSG1000ButtonC:
            // Button 2 → RETRO_DEVICE_ID_JOYPAD_A → GCController buttonB (east)
            [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1 : 0];
            break;
        case PVSG1000ButtonStart:
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed ? 1 : 0];
            break;
        default:
            break;
    }
}

@end
