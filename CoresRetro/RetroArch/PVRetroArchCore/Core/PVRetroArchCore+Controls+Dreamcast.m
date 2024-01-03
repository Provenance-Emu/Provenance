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
@interface PVRetroArchCore (DreamcastControls) <PVDreamcastSystemResponderClient>
@end

@implementation PVRetroArchCore (DreamcastControls)
#pragma mark - Control
- (void)didPushDreamcastButton:(PVDreamcastButton)button forPlayer:(NSInteger)player {
    [self handleDreamcastButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseDreamcastButton:(PVDreamcastButton)button forPlayer:(NSInteger)player {
    [self handleDreamcastButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveDreamcastJoystickDirection:(PVDreamcastButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVDreamcastButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
    }
}

- (void)handleDreamcastButton:(PVDreamcastButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    static float ltXAxis=0;
    static float ltYAxis=0;
    static float rtXAxis=0;
    static float rtYAxis=0;
    static float axisMult = 1.0;
    switch (button) {
        case(PVDreamcastButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDreamcastButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDreamcastButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDreamcastButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVDreamcastButtonA):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVDreamcastButtonB):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVDreamcastButtonY):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVDreamcastButtonX):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVDreamcastButtonL):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVDreamcastButtonR):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVDreamcastButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
