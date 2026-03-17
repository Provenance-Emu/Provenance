//
//  PVRetroArchCoreBridge+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PVCoreBridge;
#import "PVRetroArchCoreBridge+Controls.h"
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
@interface PVRetroArchCoreBridge (ColecoVisionControls) <PVColecoVisionSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (ColecoVisionControls)
#pragma mark - Control
- (void)didPushColecoVisionButton:(PVColecoVisionButton)button forPlayer:(NSInteger)player {
    [self handleColecoVisionButton:button forPlayer:player pressed:true];
}

- (void)didReleaseColecoVisionButton:(PVColecoVisionButton)button forPlayer:(NSInteger)player {
    [self handleColecoVisionButton:button forPlayer:player pressed:false];
}

- (void)handleColecoVisionButton:(PVColecoVisionButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVColecoVisionButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonLeftAction):
            // Fire 1 → buttonA (south) → JOYPAD_B
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVColecoVisionButtonRightAction):
            // Fire 2 → buttonB (east) → JOYPAD_A
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        // ColecoVision keypad buttons mapped to RetroPad
        // Gearcoleco libretro mapping: 1=Y, 2=X, 3=L, 4=R, 5=L2, 6=R2, 7=L3, 8=R3, 9=SELECT, 0=START
        case(PVColecoVisionButton1):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton2):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton3):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton4):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton5):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton6):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton7):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton8):
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton9):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PVColecoVisionButton0):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
        case(PVColecoVisionButtonAsterisk):
            // * → buttonHome (no standard RetroPad mapping, use buttonHome)
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVColecoVisionButtonPound):
            // # → no standard mapping available — skip
            break;
        default:
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
