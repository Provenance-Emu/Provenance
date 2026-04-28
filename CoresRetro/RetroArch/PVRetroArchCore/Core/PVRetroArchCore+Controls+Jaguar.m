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

// virtualjaguar libretro core mapping. RA loads the prebuilt dylib at
// CoresRetro/RetroArch/modules/virtualjaguar_libretro_ios.dylib (built by libretro
// buildbot from libretro/virtualjaguar-libretro upstream HEAD). The native
// PVVirtualJaguar core does NOT use this path — it links libjaguar directly.
// Mapping below was verified against upstream libretro.c default-input path
// (enable_alt_inputs=false). With enable_alt_inputs=true the core consults the
// per-button `virtualjaguar_*_pad_*` core options instead, which we do not set.
//   Jaguar A      → RETRO_DEVICE_ID_JOYPAD_A      → MFi buttonB (east)   [mfi_joypad: buttonB→JOYPAD_A]
//   Jaguar B      → RETRO_DEVICE_ID_JOYPAD_B      → MFi buttonA (south)  [mfi_joypad: buttonA→JOYPAD_B]
//   Jaguar C      → RETRO_DEVICE_ID_JOYPAD_Y      → MFi buttonX (west)   [mfi_joypad: buttonX→JOYPAD_Y]
//   Pause         → RETRO_DEVICE_ID_JOYPAD_SELECT → MFi buttonOptions
//   Option        → RETRO_DEVICE_ID_JOYPAD_START  → MFi buttonMenu
//   Numpad 0      → JOYPAD_X  (or RETROK_0)       → MFi buttonY
//   Numpad 1      → JOYPAD_L  (or RETROK_1)       → MFi leftShoulder
//   Numpad 2      → JOYPAD_R  (or RETROK_2)       → MFi rightShoulder
//   Numpad 3      → JOYPAD_L2 (or RETROK_3)       → MFi leftTrigger
//   Numpad 4      → JOYPAD_R2 (or RETROK_4)       → MFi rightTrigger
//   Numpad 5      → JOYPAD_L3 (or RETROK_5)       → MFi leftThumbstickButton
//   Numpad 6      → JOYPAD_R3 (or RETROK_6)       → MFi rightThumbstickButton
// Numpad 7/8/9/* /# have no RetroPad bit — only readable via keyboard:
//   Numpad 7 → RETROK_7    Numpad 8 → RETROK_8    Numpad 9 → RETROK_9
//   Numpad * → RETROK_MINUS    Numpad # → RETROK_EQUALS
// Use apple_direct_input_keyboard_event for these (takes RETROK_* directly; the regular
// apple_input_keyboard_event expects HID USB codes that get translated via rarch_keysym_lut).

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
            // Jaguar A → JOYPAD_A → MFi buttonB (east). Matches native PVVirtualJaguar.
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVJaguarButtonB):
            // Jaguar B → JOYPAD_B → MFi buttonA (south). Matches native PVVirtualJaguar.
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVJaguarButtonC):
            // Jaguar C → JOYPAD_Y → MFi buttonX (west)
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVJaguarButton0):
            // Numpad 0 → JOYPAD_X → MFi buttonY
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVJaguarButton1):
            // Numpad 1 → JOYPAD_L → MFi leftShoulder
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVJaguarButton2):
            // Numpad 2 → JOYPAD_R → MFi rightShoulder
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVJaguarButton3):
            // Numpad 3 → JOYPAD_L2 → MFi leftTrigger
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVJaguarButton4):
            // Numpad 4 → JOYPAD_R2 → MFi rightTrigger
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVJaguarButton5):
            // Numpad 5 → JOYPAD_L3 → MFi leftThumbstickButton
            [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed?1:0];
            break;
        case(PVJaguarButton6):
            // Numpad 6 → JOYPAD_R3 → MFi rightThumbstickButton
            [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed?1:0];
            break;
        case(PVJaguarButton7):
            // Numpad 7-9, *, # have no RetroPad bit — always read from keyboard by core.
            // Use apple_direct_input_keyboard_event (takes RETROK_* directly, no HID translation).
            apple_direct_input_keyboard_event(pressed, (int)RETROK_7, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton8):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_8, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButton9):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_9, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButtonAsterisk):
            // Jaguar * → core reads RETROK_MINUS
            apple_direct_input_keyboard_event(pressed, (int)RETROK_MINUS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButtonPound):
            // Jaguar # → core reads RETROK_EQUALS
            apple_direct_input_keyboard_event(pressed, (int)RETROK_EQUALS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
        case(PVJaguarButtonPause):
            // Pause → JOYPAD_SELECT → MFi buttonOptions
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PVJaguarButtonOption):
            // Option → JOYPAD_START → MFi buttonMenu
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
