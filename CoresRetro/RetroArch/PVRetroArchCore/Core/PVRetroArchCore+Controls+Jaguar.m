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
@interface PVRetroArchCoreBridge (JaguarControls) <PVJaguarSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (JaguarControls)
#pragma mark - Control

// virtualjaguar libretro core mapping — dual-path input for maximum compatibility.
//
// Upstream virtualjaguar-libretro has two numpad input modes controlled by the
// core option `virtualjaguar_p[1-2]_numpad_to_kb`:
//   "disabled" → numpad 0-6 read from RETRO_DEVICE_JOYPAD only; 7-9/*/# unreachable
//   "numbers"  → all numpad buttons ALSO readable via RETRO_DEVICE_KEYBOARD (RETROK_0-9)
//   "keypad"   → same, but via keypad keys (KP_0-KP_9)
//
// We default `numpad_to_kb = "numbers"` via parseOptions() (PVRetroArchCore+Options.swift).
// To support both modes, numpad 0-6 send BOTH joypad (MFi) AND keyboard events.
// Numpad 7-9/*/# send keyboard only (no RetroPad bit exists for these).
//
// Joypad mapping (default mode, enable_alt_inputs=false):
//   A → JOYPAD_A → MFi buttonB     B → JOYPAD_B → MFi buttonA     C → JOYPAD_Y → MFi buttonX
//   Pause → JOYPAD_SELECT → buttonOptions    Option → JOYPAD_START → buttonMenu
//   Num0 → JOYPAD_X → buttonY    Num1 → JOYPAD_L    Num2 → JOYPAD_R
//   Num3 → JOYPAD_L2   Num4 → JOYPAD_R2   Num5 → JOYPAD_L3   Num6 → JOYPAD_R3
// Keyboard mapping (numpad_to_kb="numbers"):
//   Num0-9 → RETROK_0-9    * → RETROK_MINUS    # → RETROK_EQUALS

- (void)didPushJaguarButton:(enum PVJaguarButton)button forPlayer:(NSInteger)player {
    [self handleJaguarButton:button forPlayer:player pressed:true];
}

- (void)didReleaseJaguarButton:(enum PVJaguarButton)button forPlayer:(NSInteger)player {
    [self handleJaguarButton:button forPlayer:player pressed:false];
}

- (void)handleJaguarButton:(PVJaguarButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVJaguarButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVJaguarButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVJaguarButtonC):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVJaguarButton0):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_0, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton1):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_1, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton2):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_2, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton3):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_3, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton4):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_4, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton5):
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_5, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton6):
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            apple_direct_input_keyboard_event(pressed, (int)RETROK_6, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton7):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_7, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton8):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_8, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton9):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_9, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButtonAsterisk):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_MINUS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButtonPound):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_EQUALS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButtonPause):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PVJaguarButtonOption):
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
