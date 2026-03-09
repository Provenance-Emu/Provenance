//
//  PVRetroArchCoreBridge+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PVCoreBridge;
#import "PVRetroArchCoreBridge+Controls.h"
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
@interface PVRetroArchCoreBridge (CDiControls) <PVCDiSystemResponderClient>
@end

@implementation PVRetroArchCoreBridge (CDiControls)
#pragma mark - Control
- (void)didPushCDiButton:(PVCDiButton)button forPlayer:(NSInteger)player {
    [self handleCDiButton:button forPlayer:player pressed:true];
}

- (void)didReleaseCDiButton:(PVCDiButton)button forPlayer:(NSInteger)player {
    [self handleCDiButton:button forPlayer:player pressed:false];
}

- (void)handleCDiButton:(PVCDiButton)button forPlayer:(NSInteger)player pressed:(BOOL)pressed {
    static float xAxis=0;
    static float yAxis=0;

    switch (button) {
        case(PVCDiButtonUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVCDiButtonDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVCDiButtonLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVCDiButtonRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVCDiButtonButton1):
            [touch_controller.extendedGamepad.buttonB setValue:pressed?1:0];
            break;
        case(PVCDiButtonButton2):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVCDiButtonButton3):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
    }
}

#pragma mark - Keyboard Support

- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return NO; }

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(true, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    apple_input_keyboard_event(false, (unsigned)key, 0, 0, RETRO_DEVICE_KEYBOARD);
}

@end
