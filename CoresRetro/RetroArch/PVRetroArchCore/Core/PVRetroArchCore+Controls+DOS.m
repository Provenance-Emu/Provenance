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

// Helper: get the cocoa input driver state (may be NULL before core init)
static cocoa_input_data_t * _Nullable dos_get_cocoa_input(void) {
    return (cocoa_input_data_t *)input_state_get_ptr()->current_data;
}

// Mouse button bitmasks matching cocoa_input_data_t.mouse_buttons bit layout.
#define COCOA_MOUSE_BTN_LEFT  (1u)
#define COCOA_MOUSE_BTN_RIGHT (2u)

@interface PVRetroArchCoreBridge (DOSControls) <PVDOSSystemResponderClient>
- (void)handleDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed;
@end

@implementation PVRetroArchCoreBridge (DOSControls)

#pragma mark - Gamepad

- (void)didPushDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player {
    [self handleDOSButton:button forPlayer:player pressed:true];
}

- (void)didReleaseDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player {
    [self handleDOSButton:button forPlayer:player pressed:false];
}

- (void)handleDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVDOSButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDOSButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDOSButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDOSButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDOSButtonFire1):
            // buttonA (south) → RETRO_DEVICE_ID_JOYPAD_B → Fire/Shoot in PrBoom
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVDOSButtonFire2):
            // buttonB (east) → RETRO_DEVICE_ID_JOYPAD_A → Use/Interact in PrBoom
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVDOSButtonSelect):
            // buttonOptions → RETRO_DEVICE_ID_JOYPAD_SELECT → Automap in PrBoom / menu in DOS
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            // For non-Doom systems (e.g. DOSBox) also forward to buttonHome so the RetroArch
            // menu remains accessible from the on-screen Select button. Doom intentionally
            // omits this to prevent the automap press from toggling the RetroArch menu.
            if (![self.systemIdentifier isEqualToString:@"com.provenance.doom"]) {
                [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            }
            break;
        case(PVDOSButtonPause):
            // buttonMenu → RETRO_DEVICE_ID_JOYPAD_START → Pause in PrBoom
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
        case(PVDOSButtonReset):
            // buttonMenu → RETRO_DEVICE_ID_JOYPAD_START → used for reset/restart in generic DOS
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
        // Doom-specific controls (also usable by other FPS games via PrBoom/RetroArch)
        case(PVDOSButtonStrafeLeft):
            // Maps to RETRO_DEVICE_ID_JOYPAD_L (Strafe left in PrBoom)
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVDOSButtonStrafeRight):
            // Maps to RETRO_DEVICE_ID_JOYPAD_R (Strafe right in PrBoom)
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVDOSButtonRun):
            // buttonY (north) → RETRO_DEVICE_ID_JOYPAD_X → Speed/Run in PrBoom
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVDOSButtonWeaponNext):
            // Maps to RETRO_DEVICE_ID_JOYPAD_R2 (Next weapon in PrBoom)
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVDOSButtonWeaponPrev):
            // Maps to RETRO_DEVICE_ID_JOYPAD_L2 (Previous weapon in PrBoom)
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVDOSButtonLeftDiff):
        case(PVDOSButtonRightDiff):
        case(PVDOSButtonCount):
            break;
    }
}

#pragma mark - Keyboard Support

// Keyboard pipeline: keyDown/keyUp → apple_input_keyboard_event (RetroArch Cocoa input driver)
// → rarch_keysym_lut translation → RETRO_DEVICE_KEYBOARD dispatcher.
// Independent of the PVLibRetroCoreBridge path; GCKeyCode.rawValue == HID USB key code.

- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return NO; }

// GCKeyCode.rawValue matches HID USB usage page key codes, which apple_input_keyboard_event
// expects. It translates them to RETRO_KEY values via rarch_keysym_lut internally.
- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(true, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    // Key-up clears the core's key state — essential for preventing stuck keys.
    apple_input_keyboard_event(false, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

#pragma mark - Mouse Support

- (BOOL)gameSupportsMouse { return YES; }
- (BOOL)requiresMouse { return NO; }

- (GCMouseMoved)mouseMovedHandler { return nil; }

- (void)didScroll:(GCDeviceCursor *)cursor API_AVAILABLE(ios(14.0), tvos(14.0)) {
    // RetroArch handles scroll via its own input driver; no extra forwarding needed here.
}

// Update the cocoa input driver's absolute mouse position (in view logical points).
// RetroArch computes relative deltas from these on each poll.
// Returns the cocoa input state pointer so callers can perform additional updates
// without a second lookup, or NULL if the input driver is not yet initialised.
static cocoa_input_data_t * _Nullable dos_ra_update_mouse_pos(CGPoint point) {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (!apple) return NULL;
    apple->window_pos_x = (int16_t)point.x;
    apple->window_pos_y = (int16_t)point.y;
    return apple;
}

- (void)mouseMovedAt:(CGPoint)point { dos_ra_update_mouse_pos(point); }
- (void)mouseMovedAtPoint:(CGPoint)point { [self mouseMovedAt:point]; }

- (void)leftMouseDownAt:(CGPoint)point {
    cocoa_input_data_t *apple = dos_ra_update_mouse_pos(point);
    if (apple) apple->mouse_buttons |= COCOA_MOUSE_BTN_LEFT;
}
- (void)leftMouseDownAtPoint:(CGPoint)point { [self leftMouseDownAt:point]; }
- (void)leftMouseUp {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (apple) apple->mouse_buttons &= ~COCOA_MOUSE_BTN_LEFT;
}

- (void)rightMouseDownAtPoint:(CGPoint)point {
    cocoa_input_data_t *apple = dos_ra_update_mouse_pos(point);
    if (apple) apple->mouse_buttons |= COCOA_MOUSE_BTN_RIGHT;
}
- (void)rightMouseUp {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (apple) apple->mouse_buttons &= ~COCOA_MOUSE_BTN_RIGHT;
}

@end
