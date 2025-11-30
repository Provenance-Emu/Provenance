//
//  PVRetroArchCoreBridge+Controls+Gamecube.m
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
@interface PVRetroArchCoreBridge (GameCubeControls) <PVGameCubeSystemResponderClient>
@end

@interface PVRetroArchCoreBridge (WiiControls) <PVWiiSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (GameCubeControls)
#pragma mark - Control
- (void)didPushGameCubeButton:(PVGCButton)button forPlayer:(NSInteger)player {
    [self handleGCButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseGameCubeButton:(PVGCButton)button forPlayer:(NSInteger)player {
    [self handleGCButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveGameCubeJoystickDirection:(PVGCButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVGCLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
        case(PVGCRightAnalog):
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
    }
}

- (void)handleGCButton:(PVGCButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVGCButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGCButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGCButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGCButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVGCButtonA):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVGCButtonB):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVGCButtonY):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVGCButtonX):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVGCButtonZ):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVGCButtonL):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVGCButtonR):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVGCButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end

@implementation PVRetroArchCoreBridge (WiiControls)
#pragma mark - Control
- (void)didPushWiiMoteButton:(PVWiiMoteButton)button forPlayer:(NSInteger)player {
    [self handleWiiMoteButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseWiiMoteButton:(PVWiiMoteButton)button forPlayer:(NSInteger)player {
    [self handleWiiMoteButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveWiiJoystickDirection:(PVWiiMoteButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVWiiMoteButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
        case(PVWiiMoteButtonRightAnalog):
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
    }
}

- (void)handleWiiMoteButton:(PVWiiMoteButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    switch (button) {
        case(PVWiiMoteButtonWiiDPadUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVWiiMoteButtonWiiDPadDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVWiiMoteButtonWiiDPadLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVWiiMoteButtonWiiDPadRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVWiiMoteButtonWiiA):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonWiiB):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonWiiOne):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonWiiTwo):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonNunchukZ):
            [touch_controller.extendedGamepad.rightTrigger setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonClassicZL):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonClassicZR):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVWiiMoteButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
