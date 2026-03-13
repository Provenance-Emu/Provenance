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

// Note: Button enums such as PVDOSButton are made visible to Objective-C
// via the generated Swift header from the PVCoreBridge module
// (imported above with `@import PVCoreBridge;`).

/* RetroArch Includes */
#include <stdint.h>
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

// Atari ST / Hatari relative-mouse tracking.
// Hatari libretro uses RETRO_DEVICE_MOUSE which expects *relative* delta (mouse_rel_x/y)
// rather than the absolute window position (window_pos_x/y) used by RETRO_DEVICE_POINTER
// cores such as DOSBox-Pure.  The TouchTrackpadView sends accumulated normalised 0–1
// cursor positions; we compute the frame-to-frame delta here and scale it to useful units.
//
// NOTE: st_mouse_prev is file-scope static and therefore shared across all instances and
// sessions.  The valid flag is reset on leftMouseUp and rightMouseUp (finger-lift events)
// which covers the common case.  If a session is terminated while a button is held, valid
// may be YES at the start of the next session; the first mouseMovedAt call will produce
// a harmless delta from the stale position, and valid-tracking immediately becomes correct
// from the second event onward.
static struct {
    CGFloat x, y;           // last known normalised cursor position
    BOOL    valid;          // NO until the first mouse-moved event; reset on button-up
} st_mouse_prev = { 0.5f, 0.5f, NO };

// Scale factor: a 1 % (0.01) normalised delta → this many mouse_rel units.
// Tuned so normal trackpad movement produces comfortable cursor speed on a 320×200 display.
#define ST_MOUSE_SCALE (300.0f)

static BOOL dos_is_atarist(PVRetroArchCoreBridge *bridge) {
    return ([bridge.systemIdentifier containsString:@"atarist"] ||
            [bridge.coreIdentifier   containsString:@"hatari"]);
}

@interface PVRetroArchCoreBridge (DOSControls) <PVDOSSystemResponderClient>
- (void)handleDOSButton:(PVDOSButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed;
@end

@interface PVRetroArchCoreBridge (DoomControls) <PVDoomSystemResponderClient>
- (void)handleDoomButton:(PVDoomButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed;
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
            // buttonOptions → RETRO_DEVICE_ID_JOYPAD_SELECT → menu/select in generic DOS
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            // Also forward to buttonHome so the RetroArch menu remains accessible
            // from the on-screen Select button in generic DOS/DOSBox sessions.
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
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

// Update the cocoa input driver's absolute pointer position (in view logical points).
// Used by RETRO_DEVICE_POINTER cores such as DOSBox-Pure.
// Returns the cocoa input state pointer, or NULL if not yet initialised.
static cocoa_input_data_t * _Nullable dos_ra_update_mouse_pos(CGPoint point) {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (!apple) return NULL;
    apple->window_pos_x = (int16_t)point.x;
    apple->window_pos_y = (int16_t)point.y;
    return apple;
}

// Drive relative mouse movement for Hatari / Atari ST.
// The TouchTrackpadView sends normalised 0–1 cursor positions accumulated from touchpad
// deltas.  We recover the per-event delta, scale it, and write it to mouse_rel_x/y which
// is what RETRO_DEVICE_MOUSE cores (Hatari) read each frame.
static void st_ra_update_mouse_rel(CGPoint normPos) {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (!apple) return;

    // Zero the absolute-position fields so the cocoa input path always returns mouse_rel_*
    // deltas.  On iOS with HAVE_IOS_TOUCHMOUSE, window_pos_* takes priority over mouse_rel_*;
    // if a prior pointer/absolute path left these non-zero, Hatari would silently ignore the
    // relative values.
    apple->window_pos_x = 0;
    apple->window_pos_y = 0;

    if (st_mouse_prev.valid) {
        CGFloat dx = normPos.x - st_mouse_prev.x;
        CGFloat dy = normPos.y - st_mouse_prev.y;
        // Assign to rel fields; RetroArch resets these each poll.
        apple->mouse_rel_x = (int16_t)(dx * ST_MOUSE_SCALE);
        apple->mouse_rel_y = (int16_t)(dy * ST_MOUSE_SCALE);
    }
    st_mouse_prev.x     = normPos.x;
    st_mouse_prev.y     = normPos.y;
    st_mouse_prev.valid = YES;
}

- (void)mouseMovedAt:(CGPoint)point {
    if (dos_is_atarist(self)) {
        st_ra_update_mouse_rel(point);
    } else {
        dos_ra_update_mouse_pos(point);
    }
}
- (void)mouseMovedAtPoint:(CGPoint)point { [self mouseMovedAt:point]; }

- (void)leftMouseDownAt:(CGPoint)point {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (!apple) return;
    if (dos_is_atarist(self)) {
        // Relative-mouse path: update position then set button.
        st_ra_update_mouse_rel(point);
    } else {
        dos_ra_update_mouse_pos(point);
    }
    apple->mouse_buttons |= COCOA_MOUSE_BTN_LEFT;
}
- (void)leftMouseDownAtPoint:(CGPoint)point { [self leftMouseDownAt:point]; }
- (void)leftMouseUp {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (apple) apple->mouse_buttons &= ~COCOA_MOUSE_BTN_LEFT;
    // Reset delta tracking so finger re-placement doesn't produce a phantom jump.
    if (dos_is_atarist(self)) {
        st_mouse_prev.valid = NO;
    }
}

- (void)rightMouseDownAtPoint:(CGPoint)point {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (!apple) return;
    if (dos_is_atarist(self)) {
        st_ra_update_mouse_rel(point);
    } else {
        dos_ra_update_mouse_pos(point);
    }
    apple->mouse_buttons |= COCOA_MOUSE_BTN_RIGHT;
}
- (void)rightMouseUp {
    cocoa_input_data_t *apple = dos_get_cocoa_input();
    if (apple) apple->mouse_buttons &= ~COCOA_MOUSE_BTN_RIGHT;
    // Mirror leftMouseUp: reset delta tracking on right-button release so a subsequent
    // touch doesn't produce a phantom jump from the stale previous position.
    if (dos_is_atarist(self)) {
        st_mouse_prev.valid = NO;
    }
}

@end

// MARK: - Doom / PrBoom Controls
//
// Doom is served by the PrBoom RetroArch core. Its libretro button layout is:
//   JOYPAD_B (south, buttonA)    → Fire / Shoot
//   JOYPAD_A (east,  buttonB)    → Use / Interact
//   JOYPAD_X (north, buttonY)    → Run / Speed
//   JOYPAD_L (leftShoulder)      → Strafe Left
//   JOYPAD_R (rightShoulder)     → Strafe Right
//   JOYPAD_L2 (leftTrigger)      → Previous Weapon
//   JOYPAD_R2 (rightTrigger)     → Next Weapon
//   JOYPAD_SELECT (buttonOptions) → Automap (must NOT also fire buttonHome)
//   JOYPAD_START (buttonMenu)    → Pause / Menu
//
// This dedicated category keeps Doom input logic fully separate from the generic
// DOS responder so neither bleeds into the other.

@implementation PVRetroArchCoreBridge (DoomControls)

#pragma mark - Gamepad

- (void)didPushDoomButton:(PVDoomButton)button forPlayer:(NSInteger)player {
    [self handleDoomButton:button forPlayer:player pressed:YES];
}

- (void)didReleaseDoomButton:(PVDoomButton)button forPlayer:(NSInteger)player {
    [self handleDoomButton:button forPlayer:player pressed:NO];
}

- (void)handleDoomButton:(PVDoomButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis = 0;
    static float yAxis = 0;
    float v = pressed ? 1.0f : 0.0f;

    switch (button) {
        case PVDoomButtonUp:
            yAxis = pressed ? (!xAxis ? 1.0f : 0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDoomButtonDown:
            yAxis = pressed ? (!xAxis ? -1.0f : -0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDoomButtonLeft:
            xAxis = pressed ? (!yAxis ? -1.0f : -0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDoomButtonRight:
            xAxis = pressed ? (!yAxis ? 1.0f : 0.5f) : 0.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case PVDoomButtonFire:
            // JOYPAD_B (south) → buttonA
            [touch_controller.extendedGamepad.buttonA setValue:v];
            break;
        case PVDoomButtonUse:
            // JOYPAD_A (east) → buttonB
            [touch_controller.extendedGamepad.buttonB setValue:v];
            break;
        case PVDoomButtonRun:
            // JOYPAD_X (north) → buttonY
            [touch_controller.extendedGamepad.buttonY setValue:v];
            break;
        case PVDoomButtonStrafeLeft:
            // JOYPAD_L → leftShoulder
            [touch_controller.extendedGamepad.leftShoulder setValue:v];
            break;
        case PVDoomButtonStrafeRight:
            // JOYPAD_R → rightShoulder
            [touch_controller.extendedGamepad.rightShoulder setValue:v];
            break;
        case PVDoomButtonWeaponPrev:
            // JOYPAD_L2 → leftTrigger
            [touch_controller.extendedGamepad.leftTrigger setValue:v];
            break;
        case PVDoomButtonWeaponNext:
            // JOYPAD_R2 → rightTrigger
            [touch_controller.extendedGamepad.rightTrigger setValue:v];
            break;
        case PVDoomButtonMap:
            // JOYPAD_SELECT → buttonOptions only; intentionally does NOT fire buttonHome
            // so the automap button doesn't accidentally open the RetroArch menu.
            [touch_controller.extendedGamepad.buttonOptions setValue:v];
            break;
        case PVDoomButtonPause:
            // JOYPAD_START → buttonMenu
            [touch_controller.extendedGamepad.buttonMenu setValue:v];
            break;
        case PVDoomButtonCount:
            break;
    }
}

// Doom shares the keyboard and mouse pipeline with DOS (same RetroArch backend).
// The keyboard and mouse methods declared in PVDoomSystemResponderClient are
// already implemented by the DOSControls category on the same class,
// so no duplicate implementations are needed here.

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
            // JOYPAD_SELECT -> buttonOptions (+ buttonHome for controllers without Options)
            [touch_controller.extendedGamepad.buttonOptions setValue:v];
            [touch_controller.extendedGamepad.buttonHome setValue:v];
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
