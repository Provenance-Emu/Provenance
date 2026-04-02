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
@interface PVRetroArchCoreBridge (_5200Controls) <PV5200SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (_5200Controls)
#pragma mark - Control

- (void)didPush5200Button:(PV5200Button)button forPlayer:(NSInteger)player {
    [self handle5200Button:button forPlayer:player pressed:true value:1];
}

- (void)didRelease5200Button:(PV5200Button)button forPlayer:(NSInteger)player {
    [self handle5200Button:button forPlayer:player pressed:false value:0];
}

- (void)didMove5200JoystickDirection:(PV5200Button)button withValue:(CGFloat)value forPlayer:(NSUInteger)player {
    [self handle5200Button:button forPlayer:player pressed:(value != 0) value:value];
}

- (void)handle5200Button:(PV5200Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    switch (button) {
        // The 5200 had an analog joystick — map to leftThumbstick so the
        // libretro core (a800/atari800) receives RETRO_DEVICE_INDEX_ANALOG_LEFT.
        // Mapping to dpad only sends digital RETRO_DEVICE_JOYPAD bits which
        // the core ignores for joystick movement.
        case(PV5200ButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV5200ButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV5200ButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV5200ButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV5200ButtonFire1):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PV5200ButtonFire2):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PV5200ButtonPause):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
        case(PV5200ButtonReset):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PV5200ButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
