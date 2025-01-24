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
@interface PVRetroArchCore (IntellivisionControls) <PVIntellivisionSystemResponderClient>
@end

@implementation PVRetroArchCore (IntellivisionControls)
#pragma mark - Control
- (void)didPushDreamcastButton:(PVIntellivisionButton)button forPlayer:(NSInteger)player {
    [self handleDreamcastButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseDreamcastButton:(PVIntellivisionButton)button forPlayer:(NSInteger)player {
    [self handleDreamcastButton:button forPlayer:player pressed:false value:0];
}


- (void)handleDreamcastButton:(PVIntellivisionButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVIntellivisionButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVIntellivisionButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVIntellivisionButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVIntellivisionButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVIntellivisionButtonBottomLeftAction):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVIntellivisionButtonBottomRightAction):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
//        case(PVIntellivisionButtonY):
//            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
//            break;
//        case(PVIntellivisionButtonX):
//            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
//            break;
//        case(PVIntellivisionButtonL):
//            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
//            break;
//        case(PVIntellivisionButtonR):
//            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
//            break;
//        case(PVIntellivisionButtonStart):
//            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
//            break;
    }
}
@end
