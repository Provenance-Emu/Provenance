//
//  PVRetroArchCoreBridge+Controls+VB.m
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
@interface PVRetroArchCoreBridge (VBControls) <PVVirtualBoySystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (VBControls)
#pragma mark - Control
- (void)didPushVBButton:(PVVBButton)button forPlayer:(NSInteger)player {
    [self handleVBButton:button forPlayer:player pressed:true];
}

- (void)didReleaseVBButton:(PVVBButton)button forPlayer:(NSInteger)player {
    [self handleVBButton:button forPlayer:player pressed:false];
}

- (void)handleVBButton:(PVVBButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVVBButtonLeftUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVBButtonLeftDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVBButtonLeftLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVBButtonLeftRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
//        case(PVVBButtonRightUp):
//            yAxis=pressed?(!xAxis?1.0:0.5):0;
//            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
//            break;
//        case(PVVBButtonRightDown):
//            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
//            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
//            break;
//        case(PVVBButtonRightLeft):
//            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
//            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
//            break;
//        case(PVVBButtonRightRight):
//            xAxis=pressed?(!yAxis?1.0:0.5):0;
//            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
//            break;
        case(PVVBButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVVBButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVVBButtonL):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVVBButtonR):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVVBButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVVBButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
