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
@interface PVRetroArchCoreBridge (_LynxControls) <PVLynxSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (_LynxControls)
#pragma mark - Control

- (void)didPushLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player {
    [self handleLynxButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player {
    [self handleLynxButton:button forPlayer:player pressed:false value:0];
}

// TODO: Finish joystick repsonder for Lynx
//- (void)didMoveLynxJoystickDirection:(PVLynxButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
//    switch (button) {
//        case(PVLynxButtonAnalog):
//            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
//            break;
//    }
//}

- (void)handleLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVLynxButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVLynxButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVLynxButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVLynxButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVLynxButtonA):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVLynxButtonB):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVLynxButtonPause):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
        case(PVLynxButtonOption1):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            break;
        case(PVLynxButtonOption2):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
