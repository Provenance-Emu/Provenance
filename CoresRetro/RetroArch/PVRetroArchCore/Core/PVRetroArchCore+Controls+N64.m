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
@interface PVRetroArchCore (N64Controls) <PVN64SystemResponderClient>
@end

@implementation PVRetroArchCore (N64Controls)
#pragma mark - Control
- (void)didPushN64Button:(PVN64Button)button forPlayer:(NSInteger)player {
    [self handleN64Button:button forPlayer:player pressed:true value:1];
}

- (void)didReleaseN64Button:(PVN64Button)button forPlayer:(NSInteger)player {
    [self handleN64Button:button forPlayer:player pressed:false value:0];
}

- (void)didMoveN64JoystickDirection:(PVN64Button)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVN64ButtonLeftAnalog):
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            break;
    }
}

- (void)handleN64Button:(PVN64Button)button forPlayer:(NSInteger)player pressed:(BOOL)pressed value:(CGFloat)value {
    static float xAxis=0;
    static float yAxis=0;
    static float ltXAxis=0;
    static float ltYAxis=0;
    static float rtXAxis=0;
    static float rtYAxis=0;
    static float axisMult = 1.0;
    
    switch (button) {
        case(PVN64ButtonDPadUp):
            yAxis=pressed?(!xAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVN64ButtonDPadDown):
            yAxis=pressed?(!xAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVN64ButtonDPadLeft):
            xAxis=pressed?(!yAxis?-1.0:-0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVN64ButtonDPadRight):
            xAxis=pressed?(!yAxis?1.0:0.5):0;
            [touch_controller.extendedGamepad.dpad setValueForXAxis:xAxis yAxis:yAxis];
            break;
        case(PVN64ButtonA):
            [touch_controller.extendedGamepad.buttonA setValue:pressed?1:0];
            break;
        case(PVN64ButtonB):
            [touch_controller.extendedGamepad.buttonX setValue:pressed?1:0];
            break;
        case(PVN64ButtonZ):
            [touch_controller.extendedGamepad.leftTrigger setValue:pressed?1:0];
            break;
        case(PVN64ButtonCUp):
            rtYAxis = value * axisMult;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rtXAxis yAxis:rtYAxis];
            break;
        case(PVN64ButtonCLeft):
            rtXAxis = -value * axisMult;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rtXAxis yAxis:rtYAxis];
            break;
        case(PVN64ButtonCRight):
            rtXAxis = value * axisMult;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rtXAxis yAxis:rtYAxis];
            break;
        case(PVN64ButtonCDown):
            rtYAxis = -value * axisMult;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rtXAxis yAxis:rtYAxis];
            break;
        case(PVN64ButtonL):
            [touch_controller.extendedGamepad.leftShoulder setValue:pressed?1:0];
            break;
        case(PVN64ButtonR):
            [touch_controller.extendedGamepad.rightShoulder setValue:pressed?1:0];
            break;
        case(PVN64ButtonStart):
            [touch_controller.extendedGamepad.buttonMenu setValue:pressed?1:0];
            break;
    }
}
@end
