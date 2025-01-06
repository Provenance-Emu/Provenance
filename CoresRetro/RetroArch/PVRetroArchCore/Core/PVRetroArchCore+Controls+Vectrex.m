//
//  PVRetroArchCore+Controls.m
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
@interface PVRetroArchCore (VectrexControls) <PVVectrexSystemResponderClient>
@end

@implementation PVRetroArchCore (VectrexControls)
#pragma mark - Control
- (void)didPushVectrexButton:(PVVectrexButton)button forPlayer:(NSInteger)player {
    [self handleVectrexButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseVectrexButton:(PVVectrexButton)button forPlayer:(NSInteger)player {
    [self handleVectrexButton:button forPlayer:player pressed:false value:0];
}


- (void)handleVectrexButton:(PVVectrexButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVVectrexAnalogUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVectrexAnalogDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVectrexAnalogLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVectrexAnalogRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVVectrexButton1):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVVectrexButton2):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVVectrexButton3):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVVectrexButton4):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
    }
}
@end
