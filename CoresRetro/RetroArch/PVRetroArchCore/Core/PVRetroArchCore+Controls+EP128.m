//
//  PVRetroArchCoreBridge+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PVCoreBridge;
#import "PVRetroArchCoreBridge+Controls.h"
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
@interface PVRetroArchCoreBridge (EP128Controls) <PVEP128SystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (EP128Controls)
#pragma mark - Control
- (void)didPushEP128Button:(PVEP128Button)button forPlayer:(NSInteger)player {
    [self handleEP128Button:button forPlayer:player pressed:true];
}

- (void)didReleaseEP128Button:(PVEP128Button)button forPlayer:(NSInteger)player {
    [self handleEP128Button:button forPlayer:player pressed:false];
}

- (void)handleEP128Button:(PVEP128Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVEP128ButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVEP128ButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVEP128ButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVEP128ButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVEP128ButtonFire1):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVEP128ButtonFire2):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVEP128ButtonReset):
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVEP128ButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PVEP128ButtonPause):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
