//
//  PVRetroArchCore+Controls+TIC80.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/28/26.
//  Copyright © 2026 Provenance. All rights reserved.
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

@interface PVRetroArchCoreBridge (TIC80Controls) <PVTIC80SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (TIC80Controls)
#pragma mark - Control

- (void)didPushTIC80Button:(PVTIC80Button)button forPlayer:(NSInteger)player {
    [self handleTIC80Button:button forPlayer:player pressed:YES];
}

- (void)didReleaseTIC80Button:(PVTIC80Button)button forPlayer:(NSInteger)player {
    [self handleTIC80Button:button forPlayer:player pressed:NO];
}

- (void)handleTIC80Button:(PVTIC80Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis = 0;
    static float yAxis = 0;

    switch (button) {
        case PVTIC80ButtonUp:
            yAxis = pressed ? (!xAxis ? 1.0 : 0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVTIC80ButtonDown:
            yAxis = pressed ? (!xAxis ? -1.0 : -0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVTIC80ButtonLeft:
            xAxis = pressed ? (!yAxis ? -1.0 : -0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVTIC80ButtonRight:
            xAxis = pressed ? (!yAxis ? 1.0 : 0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVTIC80ButtonA:
            // A → RETRO_DEVICE_ID_JOYPAD_A → GCController buttonB (east)
            [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonB:
            // B → RETRO_DEVICE_ID_JOYPAD_B → GCController buttonA (south)
            [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonX:
            // X → RETRO_DEVICE_ID_JOYPAD_X → GCController buttonY (north)
            [touch_controller.extendedGamepad.buttonY setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonY:
            // Y → RETRO_DEVICE_ID_JOYPAD_Y → GCController buttonX (west)
            [touch_controller.extendedGamepad.buttonX setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonL:
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonR:
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonStart:
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed ? 1 : 0];
            break;
        case PVTIC80ButtonSelect:
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1 : 0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed ? 1 : 0];
            break;
        default:
            break;
    }
}

#pragma mark - Keyboard Support

- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return YES; }

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(true, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(false, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

@end
