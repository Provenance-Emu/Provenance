// Atari ST (Hatari) controls for RetroArch bridge
// Based on PVRetroArchCore+Controls+DOS.m — Atari ST uses same keyboard+mouse device type as DOS
//
//  PVRetroArchCore+Controls+AtariST.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//
// Hatari libretro input mapping:
//   Port 0 / Port 1  → Joystick (RETRO_DEVICE_JOYPAD) — action games
//   Mouse device      → Atari ST mouse (RETRO_DEVICE_MOUSE) — GEM desktop, mouse-driven games
//   Keyboard device   → ST keyboard (RETRO_DEVICE_KEYBOARD) — function keys, shortcuts
//
// On the physical Atari ST, the mouse and joystick shared the same DE-9 port.
// Hatari exposes the mouse as a separate libretro device type; we route it through
// the cocoa input driver so RetroArch picks up pointer deltas and button state.

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
static cocoa_input_data_t * _Nullable atarist_get_cocoa_input(void) {
    return (cocoa_input_data_t *)input_state_get_ptr()->current_data;
}

// Mouse button bitmasks matching cocoa_input_data_t.mouse_buttons bit layout.
#define COCOA_MOUSE_BTN_LEFT  (1u)
#define COCOA_MOUSE_BTN_RIGHT (2u)

@interface PVRetroArchCoreBridge (AtariSTControls) <PVDOSSystemResponderClient>
- (void)handleAtariSTButton:(PVDOSButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed;
@end

@implementation PVRetroArchCoreBridge (AtariSTControls)

#pragma mark - Joystick / Gamepad

// Hatari joystick port 0 maps directly to the libretro joypad device.
// D-pad controls joystick directions; fire maps to RETRO_DEVICE_ID_JOYPAD_B.

- (void)didPushDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player {
    [self handleAtariSTButton:button forPlayer:player pressed:true];
}

- (void)didReleaseDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player {
    [self handleAtariSTButton:button forPlayer:player pressed:false];
}

- (void)handleAtariSTButton:(PVDOSButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis = 0;
    static float yAxis = 0;

    switch (button) {
        case PVDOSButtonUp:
            // Joystick up (north)
            yAxis = pressed ? (!xAxis ? 1.0 : 0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDOSButtonDown:
            // Joystick down (south)
            yAxis = pressed ? (!xAxis ? -1.0 : -0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDOSButtonLeft:
            // Joystick left (west)
            xAxis = pressed ? (!yAxis ? -1.0 : -0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDOSButtonRight:
            // Joystick right (east)
            xAxis = pressed ? (!yAxis ? 1.0 : 0.5) : 0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDOSButtonFire1:
            // Primary fire / ST joystick button 0 → RETRO_DEVICE_ID_JOYPAD_B
            [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1 : 0];
            break;
        case PVDOSButtonFire2:
            // Secondary fire / ST joystick button 1 → RETRO_DEVICE_ID_JOYPAD_A
            [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1 : 0];
            break;
        case PVDOSButtonSelect:
            // Options / pause menu
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1 : 0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed ? 1 : 0];
            break;
        case PVDOSButtonReset:
            // Reset → menu button (triggers RetroArch menu)
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed ? 1 : 0];
            break;
        default:
            break;
    }
}

#pragma mark - Keyboard Support

// ST keyboard pipeline: keyDown/keyUp → apple_input_keyboard_event (RetroArch Cocoa input driver)
// → rarch_keysym_lut translation → RETRO_DEVICE_KEYBOARD dispatcher.
// GCKeyCode.rawValue == HID USB key code, which apple_input_keyboard_event expects.
// This allows function keys (F1–F10), Help, Undo, and other ST-specific keys to reach Hatari.

- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return NO; }

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(true, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    // Key-up clears the core's key state — essential for preventing stuck keys.
    apple_input_keyboard_event(false, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

#pragma mark - Mouse Support

// The Atari ST is a mouse-driven computer. GEM desktop navigation and many ST games
// (Dungeon Master, etc.) require a functional mouse. We update the cocoa input driver's
// absolute position so RetroArch computes relative deltas from these on each poll.

- (BOOL)gameSupportsMouse { return YES; }
- (BOOL)requiresMouse { return NO; }

- (GCMouseMoved)mouseMovedHandler { return nil; }

- (void)didScroll:(GCDeviceCursor *)cursor API_AVAILABLE(ios(14.0), tvos(14.0)) {
    // RetroArch handles scroll via its own input driver; no extra forwarding needed here.
}

// Update the cocoa input driver's absolute mouse position (in view logical points).
// Returns the state pointer for chained button updates, or NULL if not yet initialised.
static cocoa_input_data_t * _Nullable atarist_ra_update_mouse_pos(CGPoint point) {
    cocoa_input_data_t *apple = atarist_get_cocoa_input();
    if (!apple) return NULL;
    apple->window_pos_x = (int16_t)point.x;
    apple->window_pos_y = (int16_t)point.y;
    return apple;
}

- (void)mouseMovedAt:(CGPoint)point { atarist_ra_update_mouse_pos(point); }
- (void)mouseMovedAtPoint:(CGPoint)point { [self mouseMovedAt:point]; }

// GEM left click — primary action (select, open, drag)
- (void)leftMouseDownAt:(CGPoint)point {
    cocoa_input_data_t *apple = atarist_ra_update_mouse_pos(point);
    if (apple) apple->mouse_buttons |= COCOA_MOUSE_BTN_LEFT;
}
- (void)leftMouseDownAtPoint:(CGPoint)point { [self leftMouseDownAt:point]; }
- (void)leftMouseUp {
    cocoa_input_data_t *apple = atarist_get_cocoa_input();
    if (apple) apple->mouse_buttons &= ~COCOA_MOUSE_BTN_LEFT;
}

// GEM right click — context menu / secondary action
- (void)rightMouseDownAtPoint:(CGPoint)point {
    cocoa_input_data_t *apple = atarist_ra_update_mouse_pos(point);
    if (apple) apple->mouse_buttons |= COCOA_MOUSE_BTN_RIGHT;
}
- (void)rightMouseUp {
    cocoa_input_data_t *apple = atarist_get_cocoa_input();
    if (apple) apple->mouse_buttons &= ~COCOA_MOUSE_BTN_RIGHT;
}

@end
