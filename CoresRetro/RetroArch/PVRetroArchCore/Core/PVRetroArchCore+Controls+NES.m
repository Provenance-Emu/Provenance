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
@interface PVRetroArchCore (NESControls) <PVNESSystemResponderClient>
@end

@implementation PVRetroArchCore (NESControls)
#pragma mark - Control
- (void)didPushNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    [self handleNESButton:button forPlayer:player pressed:true];
}

- (void)didReleaseNESButton:(PVNESButton)button forPlayer:(NSInteger)player {
    [self handleNESButton:button forPlayer:player pressed:false];
}

- (void)handleNESButton:(PVNESButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVNESButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNESButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNESButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVNESButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
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
}
@end
