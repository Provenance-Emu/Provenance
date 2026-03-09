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
@interface PVRetroArchCoreBridge (Atari8BitControls) <PVA8SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (Atari8BitControls)
#pragma mark - Control

- (void)didPushA8Button:(PVA8Button)button forPlayer:(NSInteger)player {
    [self handleAtari8BitButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseA8Button:(PVA8Button)button forPlayer:(NSInteger)player {
    [self handleAtari8BitButton:button forPlayer:player pressed:false value:0];
}

- (void)handleAtari8BitButton:(PVA8Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVA8ButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVA8ButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVA8ButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVA8ButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVA8ButtonFire):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
    }
}

#pragma mark - Keyboard Support

// Atari 8-bit computers used a keyboard as primary input
- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return YES; }

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(true, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(false, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

// TODO: Mouse responder
@end
