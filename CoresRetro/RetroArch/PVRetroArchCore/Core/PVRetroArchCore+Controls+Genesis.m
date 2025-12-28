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
@interface PVRetroArchCoreBridge (GenesisControls) <PVGenesisSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (GenesisControls)
#pragma mark - Control
- (void)didPushGenesisButton:(PVSega32XButton)button forPlayer:(NSInteger)player {
    [self handleGenesisButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseGenesisButton:(PVSega32XButton)button forPlayer:(NSInteger)player {
    [self handleGenesisButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveGenesisJoystickDirection:(PVSega32XButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self handleGenesisButton:button forPlayer:player pressed:(value != 0) value:value];
}
- (void)handleGenesisButton:(PVSega32XButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {

    switch (button) {
        case(PVSega32XButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonA):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVSega32XButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVSega32XButtonC):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVSega32XButtonY):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVSega32XButtonX):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVSega32XButtonZ):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVSega32XButtonMode):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVSega32XButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end

@interface PVRetroArchCoreBridge (Sega32XControls) <PVSega32XSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (Sega32XControls)
#pragma mark - Control
- (void)didPushSega32XButton:(PVSega32XButton)button forPlayer:(NSInteger)player {
    [self handleSega32XButton:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseSega32XButton:(PVSega32XButton)button forPlayer:(NSInteger)player {
    [self handleSega32XButton:button forPlayer:player pressed:false value:0];
}

- (void)didMoveSega32XJoystickDirection:(PVSega32XButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self handleSega32XButton:button forPlayer:player pressed:(value != 0) value:value];
}
- (void)handleSega32XButton:(PVSega32XButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {

    switch (button) {
        case(PVSega32XButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVSega32XButtonA):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVSega32XButtonB):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVSega32XButtonC):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVSega32XButtonY):
            [touch_controller.extendedGamepad.buttonY setValue:pressed?1:0];
            break;
        case(PVSega32XButtonX):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVSega32XButtonZ):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVSega32XButtonMode):
            [touch_controller.extendedGamepad.buttonOptions setValue:pressed?1:0];
            [touch_controller.extendedGamepad.buttonHome setValue:pressed?1:0];
            break;
        case(PVSega32XButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
