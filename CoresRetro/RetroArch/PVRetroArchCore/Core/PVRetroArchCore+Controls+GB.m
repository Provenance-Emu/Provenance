//
//  PVRetroArchCore+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVRetroArch/PVRetroArch.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Controls.h"
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
@interface PVRetroArchCore (GBControls) <PVGBSystemResponderClient>
@end

@implementation PVRetroArchCore (GBControls)
#pragma mark - Control
- (void)didPushGBButton:(PVGBButton)button forPlayer:(NSInteger)player {
    [self handleGBButton:button forPlayer:player pressed:true];
}

- (void)didReleaseGBButton:(PVGBButton)button forPlayer:(NSInteger)player {
    [self handleGBButton:button forPlayer:player pressed:false];
}

- (void)handleGBButton:(PVGBButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVGBButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGBButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGBButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGBButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGBButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVGBButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVGBButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVGBButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
