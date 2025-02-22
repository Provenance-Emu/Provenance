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
@interface PVRetroArchCoreBridge (JaguarControls) <PVJaguarSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (JaguarControls)
#pragma mark - Control
- (void)didPushJaguarButton:(enum PVJaguarButton)button forPlayer:(NSInteger)player {
    [self handleJaguarButton:button forPlayer:player pressed:true];
}

- (void)didReleaseJaguarButton:(enum PVJaguarButton)button forPlayer:(NSInteger)player {
    [self handleJaguarButton:button forPlayer:player pressed:false];
}

- (void)handleJaguarButton:(PVJaguarButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVJaguarButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVJaguarButtonA):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVJaguarButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVJaguarButtonC):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVJaguarButton0):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton1):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton2):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton3):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton4):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton5):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton6):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton7):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton8):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButton9):
//            [touch_controller.extendedGamepad.button0 setValue:pressed?1:0];
            break;
        case(PVJaguarButtonPound):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVJaguarButtonAsterisk):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVJaguarButtonOption):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVJaguarButtonPause):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
