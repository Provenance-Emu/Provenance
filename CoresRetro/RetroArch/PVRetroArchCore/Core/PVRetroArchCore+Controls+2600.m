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
@interface PVRetroArchCoreBridge (_2600Controls) <PV2600SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (_2600Controls)
#pragma mark - Control

- (void)didPush2600Button:(PV2600Button)button forPlayer:(NSInteger)player {
    [self handle2600Button:button forPlayer:player pressed:true value:1];
}

- (void)didRelease3DOButton:(PV2600Button)button forPlayer:(NSInteger)player {
    [self handle2600Button:button forPlayer:player pressed:false value:0];
}

- (void)handle2600Button:(PV2600Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PV2600ButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV2600ButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV2600ButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV2600ButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV2600ButtonFire1):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PV2600ButtonReset):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PV2600ButtonSelect):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
