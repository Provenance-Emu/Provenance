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
@interface PVRetroArchCoreBridge (SNESControls) <PVSNESSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (SNESControls)
#pragma mark - Control
- (void)didPushSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player {
    [self handleSNESButton:button forPlayer:player pressed:true];
}

- (void)didReleaseSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player {
    [self handleSNESButton:button forPlayer:player pressed:false];
}

- (void)handleSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    // Per-direction held state (see PVRetroArchCore+Controls+NES.m for rationale —
    // cached float axes leak diagonal magnitude across release events). SOCD
    // applied: opposing directions cancel; diagonals get full 1.0 magnitude.
    static bool dpadUp = false, dpadDown = false, dpadLeft = false, dpadRight = false;

    switch (button) {
        case(PVSNESButtonUp):
        case(PVSNESButtonDown):
        case(PVSNESButtonLeft):
        case(PVSNESButtonRight): {
            switch (button) {
                case PVSNESButtonUp:    dpadUp = pressed; break;
                case PVSNESButtonDown:  dpadDown = pressed; break;
                case PVSNESButtonLeft:  dpadLeft = pressed; break;
                case PVSNESButtonRight: dpadRight = pressed; break;
                default: break;
            }
            float x = 0.0f, y = 0.0f;
            if (dpadLeft != dpadRight) x = dpadRight ? 1.0f : -1.0f;
            if (dpadUp   != dpadDown)  y = dpadUp    ? 1.0f : -1.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:x yAxis:y];
            break;
        }
        case(PVSNESButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVSNESButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVSNESButtonX):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVSNESButtonY):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVSNESButtonTriggerLeft):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVSNESButtonTriggerRight):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVSNESButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVSNESButtonStart):
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
