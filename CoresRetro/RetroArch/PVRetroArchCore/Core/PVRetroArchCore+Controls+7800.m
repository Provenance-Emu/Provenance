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
@interface PVRetroArchCoreBridge (_7800Controls) <PV7800SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (_7800Controls)
#pragma mark - Control

- (void)didPush7800Button:(PV7800Button)button forPlayer:(NSInteger)player {
    [self handle7800Button:button forPlayer:player pressed:true value:1];
}

- (void)didRelease7800Button:(PV7800Button)button forPlayer:(NSInteger)player {
    [self handle7800Button:button forPlayer:player pressed:false value:0];
}

- (void)handle7800Button:(PV7800Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PV7800ButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV7800ButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV7800ButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV7800ButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PV7800ButtonFire1):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PV7800ButtonFire2):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PV7800ButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PV7800ButtonPause):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
        case(PV7800ButtonReset):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
