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
@interface PVRetroArchCore (DSControls) <PVDSSystemResponderClient>
@end

@implementation PVRetroArchCore (DSControls)
#pragma mark - Control
- (void)didPushDSButton:(PVDSButton)button forPlayer:(NSInteger)player {
    [self handleDSButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseDSButton:(PVDSButton)button forPlayer:(NSInteger)player {
    [self handleDSButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveDSJoystickDirection:(PVDSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self handleDSButton:button forPlayer:player pressed:(value != 0) value:value];
}
- (void)handleDSButton:(PVDSButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    static float ltXAxis=0;
    static float ltYAxis=0;
    static float rtXAxis=0;
    static float rtYAxis=0;
    static float axisMult = 1.0;
    switch (button) {
        case(PVDSButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDSButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDSButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDSButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDSButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVDSButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVDSButtonY):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVDSButtonX):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVDSButtonL):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVDSButtonR):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVDSButtonScreenSwap):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVDSButtonRotate):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVDSButtonSelect):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVDSButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
