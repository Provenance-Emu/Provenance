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
@interface PVRetroArchCoreBridge (ColecoVisionControls) <PVColecoVisionSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (ColecoVisionControls)
#pragma mark - Control
- (void)didPushColecoVisionButton:(PVColecoVisionButton)button forPlayer:(NSInteger)player {
    [self handleColecoVisionButton:button forPlayer:player pressed:true];
}

- (void)didReleaseColecoVisionButton:(PVColecoVisionButton)button forPlayer:(NSInteger)player {
    [self handleColecoVisionButton:button forPlayer:player pressed:false];
}

- (void)handleColecoVisionButton:(PVColecoVisionButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVColecoVisionButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVColecoVisionButtonLeftAction):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVColecoVisionButtonRightAction):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
//        case(PVColecoVisionButtonAsterisk):
//            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
//            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
//            break;
//        case(PVColecoVisionButtonPound):
//            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
//            break;
    }
}
@end
