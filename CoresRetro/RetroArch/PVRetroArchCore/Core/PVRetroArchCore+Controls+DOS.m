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
@interface PVRetroArchCoreBridge (DOSControls) <PVDOSSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (DOSControls)
#pragma mark - Control
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
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVDOSButtonFire2):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVDOSButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVDOSButtonReset):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
