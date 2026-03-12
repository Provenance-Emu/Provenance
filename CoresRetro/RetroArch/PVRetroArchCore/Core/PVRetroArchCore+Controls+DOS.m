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

// Forward-declare the Wolf3D button enum to allow use from Objective-C.
// The actual declaration lives in PVWolf3DButton.swift (PVCoreBridge module).
// We re-use the raw integer values here via the ObjC bridge name.
// See PVWolf3DButton.swift for the canonical mapping.

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
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVDOSButtonReset):
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
            // Maps to RETRO_DEVICE_ID_JOYPAD_X (Speed/Run in PrBoom)
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
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

// MARK: - Wolf3D (ECWolf) Controls
//
// Wolfenstein 3D is served by the ECWolf RetroArch core whose libretro button layout
// differs from PrBoom (DOS/Doom) in one important way:
//   * Run/Speed  -> JOYPAD_X (north, GCController.buttonY) -- NOT JOYPAD_Y
//   * Strafe On (toggle) -> JOYPAD_Y (west, GCController.buttonX)
//
// This category implements PVWolf3DSystemResponderClient on the shared
// PVRetroArchCoreBridge so Wolf3D gets the correct ecwolf button constants
// without polluting the generic DOS responder.

@interface PVRetroArchCoreBridge (Wolf3DControls) <PVWolf3DSystemResponderClient>
- (void)handleWolf3DButton:(PVWolf3DButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed;
@end

@implementation PVRetroArchCoreBridge (Wolf3DControls)

#pragma mark - Gamepad

- (void)didPushWolf3DButton:(PVWolf3DButton)button forPlayer:(NSInteger)player {
    [self handleWolf3DButton:button forPlayer:player pressed:YES];
}

- (void)didReleaseWolf3DButton:(PVWolf3DButton)button forPlayer:(NSInteger)player {
    [self handleWolf3DButton:button forPlayer:player pressed:NO];
}

- (void)handleWolf3DButton:(PVWolf3DButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis = 0;
    static float yAxis = 0;
    float v = pressed ? 1.0f : 0.0f;

    switch (button) {
        case PVWolf3DButtonUp:
            yAxis = pressed ? (!xAxis ? 1.0f : 0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVWolf3DButtonDown:
            yAxis = pressed ? (!xAxis ? -1.0f : -0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVWolf3DButtonLeft:
            xAxis = pressed ? (!yAxis ? -1.0f : -0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVWolf3DButtonRight:
            xAxis = pressed ? (!yAxis ? 1.0f : 0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVWolf3DButtonFire:
            // JOYPAD_B (south) -> GCController.buttonA
            [touch_controller.extendedGamepad.buttonA setValue:v];
            break;
        case PVWolf3DButtonOpen:
            // JOYPAD_A (east) -> GCController.buttonB
            [touch_controller.extendedGamepad.buttonB setValue:v];
            break;
        case PVWolf3DButtonStrafeOn:
            // JOYPAD_Y (west) -> GCController.buttonX  (strafe-on toggle)
            [touch_controller.extendedGamepad.buttonX setValue:v];
            break;
        case PVWolf3DButtonRun:
            // JOYPAD_X (north) -> GCController.buttonY  (run/speed)
            // NOTE: this differs from the generic DOS bridge which maps run->buttonX (west).
            [touch_controller.extendedGamepad.buttonY setValue:v];
            break;
        case PVWolf3DButtonStrafeLeft:
            // JOYPAD_L -> leftShoulder
            [touch_controller.extendedGamepad.leftShoulder setValue:v];
            break;
        case PVWolf3DButtonStrafeRight:
            // JOYPAD_R -> rightShoulder
            [touch_controller.extendedGamepad.rightShoulder setValue:v];
            break;
        case PVWolf3DButtonWeaponPrev:
            // JOYPAD_L2 -> leftTrigger
            [touch_controller.extendedGamepad.leftTrigger setValue:v];
            break;
        case PVWolf3DButtonWeaponNext:
            // JOYPAD_R2 -> rightTrigger
            [touch_controller.extendedGamepad.rightTrigger setValue:v];
            break;
        case PVWolf3DButtonMap:
            // JOYPAD_SELECT -> buttonOptions
            [touch_controller.extendedGamepad.buttonOptions setValue:v];
            break;
        case PVWolf3DButtonMenu:
            // JOYPAD_START -> buttonMenu
            [touch_controller.extendedGamepad.buttonMenu setValue:v];
            break;
        case PVWolf3DButtonCount:
            break;
    }
}

// Wolf3D shares the keyboard and mouse pipeline with DOS (same RetroArch backend).
// The keyboard and mouse methods declared in PVWolf3DSystemResponderClient are
// already implemented by the DOSControls category above on the same class,
// so no duplicate implementations are needed here.

@end
