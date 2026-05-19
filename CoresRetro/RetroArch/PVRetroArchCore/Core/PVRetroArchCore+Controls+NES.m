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
@interface PVRetroArchCoreBridge (NESControls) <PVNESSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (NESControls)
#pragma mark - Control
- (void)didPushNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    [self handleNESButton:button forPlayer:player pressed:true];
}

- (void)didReleaseNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    [self handleNESButton:button forPlayer:player pressed:false];
}

- (void)handleNESButton:(PVNESButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    // Track per-direction held state so we can recompute the dpad axes correctly
    // when one direction is released while another is still held. The previous
    // implementation cached only xAxis/yAxis floats and lost the held-state when
    // a diagonal partner was released, leaving the remaining direction at a
    // diagonal magnitude (0.5) instead of the full 1.0, which made dpad input
    // feel "weird" on tvOS — particularly for turbo-driven rapid taps that
    // interleave with directional holds. (tester-18may-ra-nes)
    static bool dpadUp = false, dpadDown = false, dpadLeft = false, dpadRight = false;

    switch (button) {
        case(PVNESButtonUp):
        case(PVNESButtonDown):
        case(PVNESButtonLeft):
        case(PVNESButtonRight): {
            switch (button) {
                case PVNESButtonUp:    dpadUp = pressed; break;
                case PVNESButtonDown:  dpadDown = pressed; break;
                case PVNESButtonLeft:  dpadLeft = pressed; break;
                case PVNESButtonRight: dpadRight = pressed; break;
                default: break;
            }
            // SOCD: opposing inputs cancel; diagonals get full 1.0 magnitude per axis
            // (GCControllerDirectionPad normalises internally for diagonal pressure).
            float x = 0.0f, y = 0.0f;
            if (dpadLeft != dpadRight) x = dpadRight ? 1.0f : -1.0f;
            if (dpadUp   != dpadDown)  y = dpadUp    ? 1.0f : -1.0f;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:x yAxis:y];
            break;
        }
        case(PVNESButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVNESButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVNESButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVNESButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
    // TODO(tvos-tester-18may-ra-nes): PVRemappableController button swaps (e.g. swap A/B)
    // are installed via `valueChangedHandler` on the physical controller, but the RA
    // wrapper's hardware→touch_controller forwarding uses identity `pressedChangedHandler`
    // bindings (see PVRetroArchCore+Controls.m bindControls ~L824) and the per-frame
    // poll reads `gp.buttonA.pressed` directly (poll_internal ~L1026), so user remaps
    // never reach the libretro core. Needs a follow-up to query PVRemappableController
    // and re-route the forwarder when a mapping exists.
    // TODO(tvos-tester-18may-ra-nes): Turbo is driven by TurboManager toggling at ~10Hz
    // via setValue: on the virtual touch_controller. If turbo "doesn't work on RA cores",
    // verify that the 60Hz poll on the emulation thread observes the alternating .pressed
    // state — the virtual controller fires valueChangedHandler but NOT pressedChangedHandler
    // (Apple GC quirk for programmatic snapshots). poll_internal reads `.pressed` only, so
    // sub-frame toggles can be missed; consider polling `.value > 0.1` for virtual ports.
}
@end
