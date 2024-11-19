//
//  PVDesmume2015Core+Controls.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVDesmume2015/PVDesmume2015.h>
#import <Foundation/Foundation.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;

// Desmume 2015
#include "NDSSystem.h"
// Retroarch
#include "libretro.h"

// Retro arch globals
extern retro_log_printf_t log_cb;
extern retro_environment_t environ_cb;

@implementation PVDesmume2015CoreBridge (Controls)

#pragma mark - Control

- (void)screenSwap {
    /// Get current layout through environment callback
    struct retro_variable var = { "desmume_screens_layout", NULL };
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

    /// Determine current layout from variable value
    const char *new_layout;
    if (strstr(var.value, "top only"))
        new_layout = "bottom only";
    else if (strstr(var.value, "bottom only"))
        new_layout = "top only";
    else if (strstr(var.value, "hybrid/top"))
        new_layout = "hybrid/bottom";
    else if (strstr(var.value, "hybrid/bottom"))
        new_layout = "hybrid/top";
    else
        new_layout = "top only";  // Default fallback

    /// Set new layout through environment callback
    var.value = new_layout;
    environ_cb(RETRO_ENVIRONMENT_SET_VARIABLE, &var);

    /// Force a check of variables on next frame
    bool updated = true;
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated);
}

- (void)screenRotate {
    /// Current layout state stored as static to persist between calls
    static int currentLayout = LAYOUT_TOP_BOTTOM;

    /// Cycle through the layouts in a logical order
    currentLayout = (currentLayout + 1) % 8;

    /// Map our layout enum to the string values expected by desmume
    const char *layoutValue;
    switch(currentLayout) {
        case LAYOUT_TOP_BOTTOM:
            layoutValue = "top/bottom";
            break;
        case LAYOUT_BOTTOM_TOP:
            layoutValue = "bottom/top";
            break;
        case LAYOUT_LEFT_RIGHT:
            layoutValue = "left/right";
            break;
        case LAYOUT_RIGHT_LEFT:
            layoutValue = "right/left";
            break;
        case LAYOUT_TOP_ONLY:
            layoutValue = "top only";
            break;
        case LAYOUT_BOTTOM_ONLY:
            layoutValue = "bottom only";
            break;
        case LAYOUT_HYBRID_TOP_ONLY:
            layoutValue = "hybrid/top";
            break;
        case LAYOUT_HYBRID_BOTTOM_ONLY:
            layoutValue = "hybrid/bottom";
            break;
    }

    /// Override the getVariable response for screen layout
    extern int current_layout;
    current_layout = currentLayout;

    /// Force a check of variables on next frame
    bool updated = true;
    environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated);
}

-(void)didPushDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    /// Handle special cases first
    if (button == PVDSButtonScreenSwap || button == PVDSButtonRotate) {
        if (button == PVDSButtonRotate) {
            [self screenRotate];
        } else {
            [self screenSwap];
        }
        return;
    }

    /// Map PVDSButton to RETRO_DEVICE_ID_JOYPAD values
    unsigned retro_id;
    switch(button) {
        case PVDSButtonUp:
            retro_id = RETRO_DEVICE_ID_JOYPAD_UP;
            break;
        case PVDSButtonDown:
            retro_id = RETRO_DEVICE_ID_JOYPAD_DOWN;
            break;
        case PVDSButtonLeft:
            retro_id = RETRO_DEVICE_ID_JOYPAD_LEFT;
            break;
        case PVDSButtonRight:
            retro_id = RETRO_DEVICE_ID_JOYPAD_RIGHT;
            break;
        case PVDSButtonA:
            retro_id = RETRO_DEVICE_ID_JOYPAD_A;
            break;
        case PVDSButtonB:
            retro_id = RETRO_DEVICE_ID_JOYPAD_B;
            break;
        case PVDSButtonX:
            retro_id = RETRO_DEVICE_ID_JOYPAD_X;
            break;
        case PVDSButtonY:
            retro_id = RETRO_DEVICE_ID_JOYPAD_Y;
            break;
        case PVDSButtonL:
            retro_id = RETRO_DEVICE_ID_JOYPAD_L;
            break;
        case PVDSButtonR:
            retro_id = RETRO_DEVICE_ID_JOYPAD_R;
            break;
        case PVDSButtonStart:
            retro_id = RETRO_DEVICE_ID_JOYPAD_START;
            break;
        case PVDSButtonSelect:
            retro_id = RETRO_DEVICE_ID_JOYPAD_SELECT;
            break;
        default:
            return;
    }

    /// Update the pad state directly
    _pad[player][retro_id] = 1;
}

-(void)didReleaseDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    /// Handle special cases
    if (button == PVDSButtonScreenSwap || button == PVDSButtonRotate) {
        return;
    }

    /// Map and update pad state
    unsigned retro_id;
    switch(button) {
        case PVDSButtonUp:
            retro_id = RETRO_DEVICE_ID_JOYPAD_UP;
            break;
        case PVDSButtonDown:
            retro_id = RETRO_DEVICE_ID_JOYPAD_DOWN;
            break;
        case PVDSButtonLeft:
            retro_id = RETRO_DEVICE_ID_JOYPAD_LEFT;
            break;
        case PVDSButtonRight:
            retro_id = RETRO_DEVICE_ID_JOYPAD_RIGHT;
            break;
        case PVDSButtonA:
            retro_id = RETRO_DEVICE_ID_JOYPAD_A;
            break;
        case PVDSButtonB:
            retro_id = RETRO_DEVICE_ID_JOYPAD_B;
            break;
        case PVDSButtonX:
            retro_id = RETRO_DEVICE_ID_JOYPAD_X;
            break;
        case PVDSButtonY:
            retro_id = RETRO_DEVICE_ID_JOYPAD_Y;
            break;
        case PVDSButtonL:
            retro_id = RETRO_DEVICE_ID_JOYPAD_L;
            break;
        case PVDSButtonR:
            retro_id = RETRO_DEVICE_ID_JOYPAD_R;
            break;
        case PVDSButtonStart:
            retro_id = RETRO_DEVICE_ID_JOYPAD_START;
            break;
        case PVDSButtonSelect:
            retro_id = RETRO_DEVICE_ID_JOYPAD_SELECT;
            break;
        default:
            return;
    }

    _pad[player][retro_id] = 0;
}

- (void)didMoveDSJoystickDirection:(enum PVDSButton)button
                            withValue:(CGFloat)value
                            forPlayer:(NSInteger)player {

}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self didMoveDSJoystickDirection:(enum PVDSButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushDSButton:(PVDSButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseDSButton:(PVDSButton)button forPlayer:player];
}

// Touch Screen controls
-(void)sendEvent:(UIEvent * _Nullable)event {
    [super sendEvent:event];
}

@end
