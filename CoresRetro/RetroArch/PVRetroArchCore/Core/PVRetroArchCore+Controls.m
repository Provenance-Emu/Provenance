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

#ifndef MAX_MFI_CONTROLLERS
#define MAX_MFI_CONTROLLERS 16
#endif
enum
{
	GCCONTROLLER_PLAYER_INDEX_UNSET = -1,
};
uint32_t mfi_buttons[MAX_USERS];
int16_t  mfi_axes[MAX_USERS][4];
uint32_t mfi_controllers[MAX_MFI_CONTROLLERS];
typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef unsigned int   u32;
extern bool _isInitialized;
extern __weak PVRetroArchCore *_current;
void handle_touch_event(NSArray* touches);
void handle_click_event(CGPoint click, bool pressed);
GCController *touch_controller;
static NSMutableArray *mfiControllers;
void apple_gamecontroller_joypad_connect(GCController *controller);
void refresh_gamecontrollers();
void apple_gamecontroller_joypad_disconnect(GCController* controller);

@implementation PVRetroArchCore (Controls)
- (void)initControllBuffers {}
#pragma mark - Control
-(void)controllerConnected:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        apple_gamecontroller_joypad_connect([notification object]);
        [self refresh_gamecontrollers];
        [self useRetroArchController:self.retroArchControls];
        NSLog(@"Binding Controls\n");
    });
}
-(void)controllerDisconnected:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        apple_gamecontroller_joypad_disconnect([notification object]);
        [self refresh_gamecontrollers];
        [self useRetroArchController:self.retroArchControls];
    });
}

-(void)keyboardConnected:(NSNotification *)notification {
    [self useRetroArchController:self.retroArchControls];
}
-(void)keyboardDisconnected:(NSNotification *)notification {
    [self useRetroArchController:self.retroArchControls];
}
- (void)processKeyPress:(int)key pressed:(bool)pressed {
    if (self.bindAnalogKeys) {
        switch (key) {
                static float dPadX=0;
                static float dPadY=0;
                static float leftXAxis=0;
                static float leftYAxis=0;
                static float rightXAxis=0;
                static float rightYAxis=0;
            case(KEY_S): // down
                leftYAxis=pressed?-1.0:leftYAxis<0 ? 0 : leftYAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_W): // up
                leftYAxis=pressed?1.0:leftYAxis>0 ? 0 : leftYAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_D):  // right
                leftXAxis=pressed?1.0:leftXAxis>0 ? 0 :leftXAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_A):  // left
                leftXAxis=pressed?-1.0:leftXAxis<0 ? 0 : leftXAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_O): // up
                rightYAxis=pressed?1.0:rightYAxis > 0 ? 0 : rightYAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
               break;
            case(KEY_L): // down
                rightYAxis=pressed?-1.0:rightYAxis < 0 ? 0 : rightYAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
               break;
            case(KEY_K):  // left
                rightXAxis=pressed?-1.0:rightXAxis < 0 ? 0 : rightXAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                break;
            case(KEY_Semicolon):  // right
                rightXAxis=pressed?1.0:rightXAxis > 0 ? 0 : rightXAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                break;
            case(KEY_Up):
                dPadY = pressed ? 1.0 : dPadY > 0 ? 0 : dPadY;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_Down):
                dPadY = pressed ? -1.0 : dPadY < 0 ? 0.0 : dPadY;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_Left):
                dPadX = pressed ? -1.0 : dPadX < 0 ? 0.0 : dPadX;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_Right):
                dPadX = pressed ? 1.0 : dPadX > 0 ? 0.0 : dPadX;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_F):
                [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Space):
                [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Q):
                [touch_controller.extendedGamepad.buttonX setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_E):
                [touch_controller.extendedGamepad.buttonY setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_G):
                [touch_controller.extendedGamepad.buttonY setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Y):
                [touch_controller.extendedGamepad.buttonX setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_J):
                [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_B):
                [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_N):
                [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Tab):
                [touch_controller.extendedGamepad.leftShoulder setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_LeftShift):
                [touch_controller.extendedGamepad.leftTrigger 
                    setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_X):
                [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_R):
                [touch_controller.extendedGamepad.rightShoulder setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_V):
                [touch_controller.extendedGamepad.rightTrigger setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_C):
                [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_U):
                [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_I):
                [touch_controller.extendedGamepad.buttonMenu 
                    setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Slash):
                [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_RightShift):
                [touch_controller.extendedGamepad.buttonMenu 
                    setValue:pressed ? 1.0 : 0.0];
                break;
            default:
                break;
        }
    }
    if (self.bindNumKeys) {
        switch (key) {
            case(KEY_Z):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP1, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_X):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP2, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_C):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP3, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_A):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP4, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_S):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP5, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_D):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP6, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Q):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP7, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_W):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP8, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_E):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP9, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Up):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP8, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Down):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP2, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Left):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP4, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Right):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP6, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_LeftControl):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP0, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_LeftAlt):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_PERIOD, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_LeftShift):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_ENTER, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_V):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_ENTER, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_F):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_PLUS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_R):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_MINUS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_3):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_MULTIPLY, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_2):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_DIVIDE, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_4):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_EQUALS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            default:
                break;
        }
    }
    switch (key) {
        case(KEY_RightAlt):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_ESCAPE, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
    }
}
-(void)refresh_gamecontrollers {
    apple_gamecontroller_joypad_connect(touch_controller);
    for (NSInteger player = 0; player < 4; player++) {
        GCController *controller = nil;
        if (_current.controller1 && player == 0)
        {
            controller = _current.controller1;
        }
        else if (_current.controller2 && player == 1)
        {
            controller = _current.controller2;
        }
        else if (_current.controller3 && player == 2)
        {
            controller = _current.controller3;
        }
        else if (_current.controller4 && player == 3)
        {
            controller = _current.controller4;
        }
        if (controller) {
            apple_gamecontroller_joypad_connect(controller);
        }
        [self bindControls];
    }
}
-(void)setupControllers {
    _current=self;
    NSLog(@"Setting up Controller Notification Listeners\n");
    [self initControllBuffers];
    [self useRetroArchController:self.retroArchControls];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCControllerDidDisconnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardConnected:)
                                                 name:GCKeyboardDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDisconnected:)
                                                 name:GCKeyboardDidDisconnectNotification
                                               object:nil
    ];
}
-(void)bindControls {
    for (NSInteger player = 0; player < 4; player++)
    {
        GCController *controller = nil;
        if (self.controller1 && player == 0)
        {
            controller = self.controller1;
        }
        else if (self.controller2 && player == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && player == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && player == 3)
        {
            controller = self.controller4;
        }
        NSLog(@"Controller Vendor Name: %s\n",controller.vendorName.UTF8String);
        if (controller.extendedGamepad != nil && ![controller.vendorName containsString:@"Keyboard"])
        {
            controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.buttonA setValue:value];
            };
            controller.extendedGamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.buttonB setValue:value];
            };
            controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.buttonX setValue:value];
            };
            controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.buttonY setValue:value];
            };
            controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.leftShoulder setValue:value];
            };
            controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.rightShoulder setValue:value];
            };
            controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.leftTrigger setValue:value];
            };
            controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.rightTrigger setValue:value];
            };
            controller.extendedGamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [touch_controller.extendedGamepad.dpad setValueForXAxis:xValue yAxis:yValue];
            };
            controller.extendedGamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            };
            controller.extendedGamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
            };
            controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.leftThumbstickButton setValue:value];
            };
            controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.rightThumbstickButton setValue:value];
            };
            controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.buttonOptions setValue:value];
                if (pressed) {
                    command_event(CMD_EVENT_MENU_TOGGLE, NULL);
                }
            };
            #if defined(__IPHONE_14_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_0
            controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [touch_controller.extendedGamepad.buttonHome setValue:value];
            };
            #endif
        }
    }
}

- (void)sendEvent:(UIEvent *)event {
    [super sendEvent:event];
    if (@available(iOS 13.4, *)) {
        if (event.type == UIEventTypeHover)
            return;
    }
    if (event.allTouches.count)
        handle_touch_event(event.allTouches.allObjects);
}

-(void)useRetroArchController:(BOOL)flag {
    self.retroArchControls=flag;
    bool should_update=false;
    settings_t *settings            = config_get_ptr();
    input_driver_state_t  *input_st = input_state_get_ptr();
    input_overlay_t       *ol       = input_st->overlay_ptr;
    input_overlay_state_t *ol_state = &ol->overlay_state;

    NSString *original_overlay = [NSString stringWithUTF8String:settings->paths.path_overlay];
    if (flag) {
        NSLog(@"Option: Use Retro arch controller\n");
        if ([original_overlay
             containsString:@RETROARCH_PVOVERLAY]) {
            NSString *overlay=@RETROARCH_DEFAULT_OVERLAY;
            NSString *new_overlay=[overlay stringByReplacingOccurrencesOfString:@"/RetroArch"
             withString:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch" ]];
            if (![new_overlay isEqualToString:original_overlay]) {
                configuration_set_string(settings,
                        settings->paths.path_overlay,
                        new_overlay.UTF8String
                );
                settings->bools.input_overlay_auto_scale=true;
                settings->floats.input_overlay_opacity=0.3;
                NSLog(@"Updating %s to %s\n", original_overlay.UTF8String, new_overlay.UTF8String);
            }
        }
        settings->bools.input_overlay_enable=true;
        should_update=true;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HideTouchControls" object:nil userInfo:nil];
    } else {
        should_update=true;
        settings->bools.input_overlay_enable=false;
        NSLog(@"Option: Don't Use Retro arch controller\n");
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowTouchControls" object:nil userInfo:nil];
    }
    if (should_update) {
        NSLog(@"Option: Updating Overlay\n");
        command_event(CMD_EVENT_OVERLAY_INIT, NULL);
    }

}
@end
static bool apple_gamecontroller_available(void) {
	return true;
}

static void apple_gamecontroller_joypad_poll_internal(GCController *controller)
{
	uint32_t slot, pause, select, l3, r3;
	uint32_t *buttons;
	if (!controller)
		return;

	slot               = (uint32_t)controller.playerIndex;
	/* If we have not assigned a slot to this controller yet, ignore it. */
    if (slot >= MAX_USERS)
		return;
	buttons            = &mfi_buttons[slot];

	/* retain the values from the paused controller handler and pass them through */
	if (@available(iOS 13, *))
	{
		/* The menu button can be pressed/unpressed
		 * like any other button in iOS 13,
		 * so no need to passthrough anything */
		*buttons = 0;
	}
	else
	{
		/* Use the paused controller handler for iOS versions below 13 */
		pause              = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_START);
		select             = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
		l3                 = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_L3);
		r3                 = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_R3);
		*buttons           = 0 | pause | select | l3 | r3;
	}
	memset(mfi_axes[slot], 0, sizeof(mfi_axes[0]));
    if (controller.extendedGamepad)
	{
		GCExtendedGamepad *gp = (GCExtendedGamepad *)controller.extendedGamepad;

		*buttons             |= gp.dpad.up.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_UP)    : 0;
		*buttons             |= gp.dpad.down.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_DOWN)  : 0;
		*buttons             |= gp.dpad.left.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_LEFT)  : 0;
		*buttons             |= gp.dpad.right.pressed      ? (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT) : 0;
		*buttons             |= gp.buttonA.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_B)     : 0;
		*buttons             |= gp.buttonB.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_A)     : 0;
		*buttons             |= gp.buttonX.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_Y)     : 0;
		*buttons             |= gp.buttonY.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_X)     : 0;
		*buttons             |= gp.leftShoulder.pressed    ? (1 << RETRO_DEVICE_ID_JOYPAD_L)     : 0;
		*buttons             |= gp.rightShoulder.pressed   ? (1 << RETRO_DEVICE_ID_JOYPAD_R)     : 0;
		*buttons             |= gp.leftTrigger.pressed     ? (1 << RETRO_DEVICE_ID_JOYPAD_L2)    : 0;
		*buttons             |= gp.rightTrigger.pressed    ? (1 << RETRO_DEVICE_ID_JOYPAD_R2)    : 0;
        //printf("slot %d button %d extended\n", slot, *buttons);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 120100 || __TV_OS_VERSION_MAX_ALLOWED >= 120100
		if (@available(iOS 12.1, *))
		{
			*buttons         |= gp.leftThumbstickButton.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_L3) : 0;
			*buttons         |= gp.rightThumbstickButton.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_R3) : 0;
		}
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 || __TV_OS_VERSION_MAX_ALLOWED >= 130000
		if (@available(iOS 13, *))
		{
			/* Support "Options" button present in PS4 / XBox One controllers */
			*buttons         |= gp.buttonOptions.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_SELECT) : 0;

			/* Support buttons that aren't supported by older mFi controller via "hotkey" combinations:
			 *
			 * LS + Menu => Select
			 * LT + Menu => L3
			 * RT + Menu => R3
		 */
			if (gp.buttonMenu.pressed )
			{
				if (gp.leftShoulder.pressed)
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_SELECT;
				else if (gp.leftTrigger.pressed)
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_L3;
				else if (gp.rightTrigger.pressed)
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_R3;
				else
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_START;
			}
		}
#endif

		mfi_axes[slot][0]     = gp.leftThumbstick.xAxis.value * 32767.0f;
		mfi_axes[slot][1]     = gp.leftThumbstick.yAxis.value * 32767.0f;
		mfi_axes[slot][2]     = gp.rightThumbstick.xAxis.value * 32767.0f;
		mfi_axes[slot][3]     = gp.rightThumbstick.yAxis.value * 32767.0f;
        //printf("slot %d axes %d extended\n", slot, mfi_axes[slot][0]);


	}

	/* GCGamepad is deprecated */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
	else if (controller.gamepad)
	{
		GCGamepad *gp = (GCGamepad *)controller.gamepad;

		*buttons |= gp.dpad.up.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_UP)    : 0;
		*buttons |= gp.dpad.down.pressed     ? (1 << RETRO_DEVICE_ID_JOYPAD_DOWN)  : 0;
		*buttons |= gp.dpad.left.pressed     ? (1 << RETRO_DEVICE_ID_JOYPAD_LEFT)  : 0;
		*buttons |= gp.dpad.right.pressed    ? (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT) : 0;
		*buttons |= gp.buttonA.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_B)     : 0;
		*buttons |= gp.buttonB.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_A)     : 0;
		*buttons |= gp.buttonX.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_Y)     : 0;
		*buttons |= gp.buttonY.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_X)     : 0;
		*buttons |= gp.leftShoulder.pressed  ? (1 << RETRO_DEVICE_ID_JOYPAD_L)     : 0;
		*buttons |= gp.rightShoulder.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_R)     : 0;
        //printf("slot %d button %d gamepad\n", slot, *buttons);

	}
#pragma clang diagnostic pop
}

static void apple_gamecontroller_joypad_poll(void)
{
	if (!apple_gamecontroller_available())
		return;
	for (GCController *controller in [GCController controllers])
		apple_gamecontroller_joypad_poll_internal(controller);
    if (touch_controller)
        apple_gamecontroller_joypad_poll_internal(touch_controller);
}

/* GCGamepad is deprecated */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
static void apple_gamecontroller_joypad_register(GCExtendedGamepad *gamepad)
{
#ifdef __IPHONE_14_0
	/* Don't let tvOS or iOS do anything with **our** buttons!!
	 * iOS will start a screen recording if you hold or doubleclick
	 * the OPTIONS button, we don't want that. */
	if (@available(iOS 14.0, tvOS 14.0, *))
	{
		GCExtendedGamepad *gp = (GCExtendedGamepad *)gamepad.controller.extendedGamepad;
		gp.buttonOptions.preferredSystemGestureState = GCSystemGestureStateDisabled;
		gp.buttonMenu.preferredSystemGestureState    = GCSystemGestureStateDisabled;
		gp.buttonHome.preferredSystemGestureState    = GCSystemGestureStateDisabled;
	}
#endif

	gamepad.valueChangedHandler = ^(GCExtendedGamepad *updateGamepad, GCControllerElement *element)
	{
		apple_gamecontroller_joypad_poll_internal(updateGamepad.controller);
	};

	/* controllerPausedHandler is deprecated in favor
	 * of being able to deal with the menu
	 * button as any other button */
	if (@available(iOS 13, *))
	   return;

	{
		gamepad.controller.controllerPausedHandler = ^(GCController *controller)

		{
		   uint32_t slot      = (uint32_t)controller.playerIndex;

		   /* Support buttons that aren't supported by the mFi
			* controller via "hotkey" combinations:
			*
			* LS + Menu => Select
			* LT + Menu => L3
			* RT + Menu => R3
			* Note that these are just button presses, and it
			* does not simulate holding down the button
			*/
		   if (     controller.gamepad.leftShoulder.pressed
				 || controller.extendedGamepad.leftShoulder.pressed )
		   {
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L);
			  mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
			  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
					});
			  return;
		   }

		   if (controller.extendedGamepad.leftTrigger.pressed )
		   {
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L2);
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
			  mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_L3);
			  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L3);
					});
			  return;
		   }

		   if (controller.extendedGamepad.rightTrigger.pressed )
		   {
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R2);
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
			  mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_R3);
			  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R3);
					});
			  return;
		   }

		   mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_START);

		   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				 mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
				 });
		};
	}
}
#pragma clang diagnostic pop
int auto_incr_id=0;
static void mfi_joypad_autodetect_add(unsigned autoconf_pad)
{
    auto_incr_id+=1;    
	input_autoconfigure_connect("mFi Controller", NULL, mfi_joypad.ident, autoconf_pad, auto_incr_id, 0);
}

void apple_gamecontroller_joypad_connect(GCController *controller)
{
	signed desired_index = (int32_t)controller.playerIndex;
	desired_index        = (desired_index >= 0 && desired_index < MAX_MFI_CONTROLLERS)
	? desired_index : 0;
    /* prevent same controller getting set twice */
	if ([mfiControllers containsObject:controller])
		return;
    if ([controller.vendorName containsString:@"Keyboard"])
        return;

	if (mfi_controllers[desired_index] != (uint32_t)controller.hash)
	{
		/* desired slot is unused, take it */
		if (!mfi_controllers[desired_index])
		{
			controller.playerIndex = desired_index;
			mfi_controllers[desired_index] = (uint32_t)controller.hash;
		}
		else
		{
			/* find a new slot for this controller that's unused */
			unsigned i;

			for (i = 0; i < MAX_MFI_CONTROLLERS; ++i)
			{
				if (mfi_controllers[i])
					continue;

				mfi_controllers[i] = (uint32_t)controller.hash;
				controller.playerIndex = i;
				break;
			}
		}
		[mfiControllers addObject:controller];
		/* Move any non-game controllers (like the siri remote) to the end */
		if (mfiControllers.count > 1)
		{
		   int newPlayerIndex = 0;
		   NSInteger connectedNonGameControllerIndex = NSNotFound;
		   NSUInteger index = 0;

		   for (GCController *connectedController in mfiControllers)
		   {
			  if (     connectedController.gamepad         == nil
					&& connectedController.extendedGamepad == nil )
				 connectedNonGameControllerIndex = index;
			  index++;
		   }

		   if (connectedNonGameControllerIndex != NSNotFound)
		   {
			  GCController *nonGameController = [mfiControllers objectAtIndex:connectedNonGameControllerIndex];
			  [mfiControllers removeObjectAtIndex:connectedNonGameControllerIndex];
			  [mfiControllers addObject:nonGameController];
		   }
		   for (GCController *gc in mfiControllers)
			  gc.playerIndex = newPlayerIndex++;
		}
        if (controller.extendedGamepad)
            apple_gamecontroller_joypad_register(controller.extendedGamepad);
        else
            apple_gamecontroller_joypad_register(controller.gamepad);
		mfi_joypad_autodetect_add((unsigned)controller.playerIndex);
	}
}

void apple_gamecontroller_joypad_disconnect(GCController* controller)
{
	signed pad = (int32_t)controller.playerIndex;

	if (pad == GCCONTROLLER_PLAYER_INDEX_UNSET)
		return;

	mfi_controllers[pad] = 0;
	if ([mfiControllers containsObject:controller])
	{
		[mfiControllers removeObject:controller];
		input_autoconfigure_disconnect(pad, mfi_joypad.ident);
	}
}

void *apple_gamecontroller_joypad_init(void *data) {
    if (!apple_gamecontroller_available())
      return NULL;
    
    mfiControllers=[[NSMutableArray alloc] initWithCapacity:MAX_MFI_CONTROLLERS];
    
    for (int i=0; i < MAX_MFI_CONTROLLERS; i++) {
        mfi_controllers[i]=0;
    }
    if (!touch_controller) {
        touch_controller=[[GCController controllerWithExtendedGamepad] init];
        touch_controller.playerIndex=0;
        apple_gamecontroller_joypad_connect(touch_controller);
    }
    [_current refresh_gamecontrollers];
    return (void*)-1;
}

void apple_gamecontroller_joypad_destroy(void) {
    printf("Controller: Disconnecting Controllers\n");
    /*
    if (touch_controller) {
        apple_gamecontroller_joypad_disconnect(touch_controller);
    }
    for (GCController *gc in mfiControllers)
        apple_gamecontroller_joypad_disconnect(gc);
     */
    touch_controller=nil;
}

static int32_t apple_gamecontroller_joypad_button(
	  unsigned port, uint16_t joykey)
{
   if (port >= DEFAULT_MAX_PADS)
	  return 0;
   /* Check hat. */
   else if (GET_HAT_DIR(joykey))
	  return 0;
   else if (joykey < 32)
	  return ((mfi_buttons[port] & (1 << joykey)) != 0);
   return 0;
}

static void apple_gamecontroller_joypad_get_buttons(unsigned port,
	  input_bits_t *state)
{
	BITS_COPY16_PTR(state, mfi_buttons[port]);
}

static int16_t apple_gamecontroller_joypad_axis(
	  unsigned port, uint32_t joyaxis)
{
	int16_t val  = 0;
	int16_t axis = -1;
	bool is_neg  = false;
	bool is_pos  = false;

	if (AXIS_NEG_GET(joyaxis) < 4)
	{
		axis     = AXIS_NEG_GET(joyaxis);
		is_neg   = true;
	}
	else if(AXIS_POS_GET(joyaxis) < 4)
	{
		axis     = AXIS_POS_GET(joyaxis);
		is_pos   = true;
	}
	else
	   return 0;

	if (axis >= 0 && axis < 4)
	   val  = mfi_axes[port][axis];
	if (is_neg && val > 0)
	   return 0;
	else if (is_pos && val < 0)
	   return 0;
	return val;
}

static int16_t apple_gamecontroller_joypad_state(
	  rarch_joypad_info_t *joypad_info,
	  const struct retro_keybind *binds,
	  unsigned port)
{
   unsigned i;
   int16_t ret                          = 0;
   uint16_t port_idx                    = joypad_info->joy_idx;

   if (port_idx >= DEFAULT_MAX_PADS)
	  return 0;

   for (i = 0; i < RARCH_FIRST_CUSTOM_BIND; i++)
   {
	  /* Auto-binds are per joypad, not per user. */
	  const uint64_t joykey  = (binds[i].joykey != NO_BTN)
		 ? binds[i].joykey  : joypad_info->auto_binds[i].joykey;
	  const uint32_t joyaxis = (binds[i].joyaxis != AXIS_NONE)
		 ? binds[i].joyaxis : joypad_info->auto_binds[i].joyaxis;
	  if (     (uint16_t)joykey != NO_BTN
			&& !GET_HAT_DIR(i)
			&& (i < 32)
			&& ((mfi_buttons[port_idx] & (1 << i)) != 0)
		 )
		 ret |= ( 1 << i);
	  else if (joyaxis != AXIS_NONE &&
			((float)abs(apple_gamecontroller_joypad_axis(port_idx, joyaxis))
			 / 0x8000) > joypad_info->axis_threshold)
		 ret |= (1 << i);
   }
   return ret;
}

static bool apple_gamecontroller_joypad_query_pad(unsigned pad)
{
	return pad < MAX_USERS;
}

static const char *apple_gamecontroller_joypad_name(unsigned pad)
{
	if (pad >= MAX_USERS)
		return NULL;

	return "mFi Controller";
}

input_device_driver_t mfi_joypad = {
	apple_gamecontroller_joypad_init,
	apple_gamecontroller_joypad_query_pad,
	apple_gamecontroller_joypad_destroy,
	apple_gamecontroller_joypad_button,
	apple_gamecontroller_joypad_state,
	apple_gamecontroller_joypad_get_buttons,
	apple_gamecontroller_joypad_axis,
	apple_gamecontroller_joypad_poll,
	NULL,
	NULL,
	apple_gamecontroller_joypad_name,
	"mfi",
};

@interface CocoaView (Utility)
-(void) showRetroArchNotification:_:(NSString *)title _:(NSString *)message _:(enum message_queue_icon)icon _:(enum message_queue_category)category;
@end
@implementation CocoaView (Utility)
// A native swift wrapper around displaying notifications
-(void) showRetroArchNotification:_:(NSString *)title _:(NSString *)message _:(enum message_queue_icon)icon _:(enum message_queue_category)category {
	runloop_msg_queue_push([message UTF8String], 1, 100, true, [title UTF8String], icon, category);
}
@end

enum
{
   NSAlphaShiftKeyMask                  = 1 << 16,
   NSShiftKeyMask                       = 1 << 17,
   NSControlKeyMask                     = 1 << 18,
   NSAlternateKeyMask                   = 1 << 19,
   NSCommandKeyMask                     = 1 << 20,
   NSNumericPadKeyMask                  = 1 << 21,
   NSHelpKeyMask                        = 1 << 22,
   NSFunctionKeyMask                    = 1 << 23,
   NSDeviceIndependentModifierFlagsMask = 0xffff0000U
};

@interface CocoaView (InputEvents)
@end
@implementation CocoaView (InputEvents)
float oldX, oldY;
bool dragging=false;

// In a view or view controller subclass:
- (BOOL)canBecomeFirstResponder
{
	return YES;
}

- (void)pressesBegan:(NSSet<UIPress *> *)touches withEvent:(UIPressesEvent *)event {
	for (int i = 0; i < touches.allObjects.count; i++) {
		UIKey *key = touches.allObjects[i].key;
		NSUInteger mods = key.modifierFlags;
		uint32_t mod       = 0;
		if (mods & NSAlphaShiftKeyMask)
			mod |= RETROKMOD_CAPSLOCK;
		if (mods & NSShiftKeyMask)
			mod |= RETROKMOD_SHIFT;
		if (mods & NSControlKeyMask)
			mod |= RETROKMOD_CTRL;
		if (mods & NSAlternateKeyMask)
			mod |= RETROKMOD_ALT;
		if (mods & NSCommandKeyMask)
			mod |= RETROKMOD_META;
		if (mods & NSNumericPadKeyMask)
			mod |= RETROKMOD_NUMLOCK;
        [_current processKeyPress:key.keyCode pressed:true];
        apple_input_keyboard_event(true,
		 (uint32_t)key.keyCode,
		 key.characters.length > 0 ? (uint32_t)[key.characters characterAtIndex:0] : 0,
		 mod,
		 RETRO_DEVICE_KEYBOARD);
	}
}

- (void)pressesEnded:(NSSet<UIPress *> *)touches withEvent:(UIPressesEvent *)event {
    for (int i = 0; i < touches.allObjects.count; i++) {
		UIKey *key = touches.allObjects[i].key;
		NSUInteger mods = key.modifierFlags;
		uint32_t mod       = 0;
		if (mods & NSAlphaShiftKeyMask)
			mod |= RETROKMOD_CAPSLOCK;
		if (mods & NSShiftKeyMask)
			mod |= RETROKMOD_SHIFT;
		if (mods & NSControlKeyMask)
			mod |= RETROKMOD_CTRL;
		if (mods & NSAlternateKeyMask)
			mod |= RETROKMOD_ALT;
		if (mods & NSCommandKeyMask)
			mod |= RETROKMOD_META;
		if (mods & NSNumericPadKeyMask)
			mod |= RETROKMOD_NUMLOCK;
        [_current processKeyPress:key.keyCode pressed:false];
        apple_input_keyboard_event(false,
		   (uint32_t)key.keyCode,
		   key.characters.length > 0 ? (uint32_t)[key.characters characterAtIndex:0] : 0,
		   mod,
		   RETRO_DEVICE_KEYBOARD);
	 }
}

-(void)handle_touch_event:(NSSet*) touches {
	handle_touch_event(touches.allObjects);
}
@end

void handle_touch_event(NSArray* touches) {
   cocoa_input_data_t *apple = (cocoa_input_data_t*)
      input_state_get_ptr()->current_data;
   float scale               = cocoa_screen_get_native_scale();
   if (!apple)
      return;
   apple->touch_count = 0;
   for (int i = 0; i < touches.count && (apple->touch_count < MAX_TOUCHES); i++) {
      UITouch      *touch = [touches objectAtIndex:i];
      CGPoint       coord = [touch locationInView:[touch view]];
      if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
         apple->touches[apple->touch_count   ].screen_x = coord.x * scale;
         apple->touches[apple->touch_count ++].screen_y = coord.y * scale;
      }
   }
}

void handle_click_event(CGPoint click, bool pressed) {
   cocoa_input_data_t *apple = (cocoa_input_data_t*)input_state_get_ptr()->current_data;
   float scale = cocoa_screen_get_native_scale();
   if (!apple) return;
   apple->touch_count = 0;
   CGPoint coord = click;
   if (pressed) {
     apple->touches[apple->touch_count   ].screen_x = coord.x * scale;
     apple->touches[apple->touch_count ++].screen_y = coord.y * scale;
   }
}

/* cocoa input */


#if TARGET_OS_IPHONE
#define HIDKEY(X) X
#else
#define HIDKEY(X) (X < 128) ? MAC_NATIVE_TO_HID[X] : 0
#endif

#define MAX_ICADE_PROFILES 4
#define MAX_ICADE_KEYS     0x100

typedef struct icade_map
{
   bool up;
   enum retro_key key;
} icade_map_t;

/* TODO/FIXME -
 * fix game focus toggle */

/*
 * FORWARD DECLARATIONS
 */
#ifdef OSX
float cocoa_screen_get_backing_scale_factor(void);
#endif

#if TARGET_OS_IPHONE
/* TODO/FIXME - static globals */
static bool small_keyboard_active = false;
static icade_map_t icade_maps[MAX_ICADE_PROFILES][MAX_ICADE_KEYS];
#if TARGET_OS_IOS && !TARGET_OS_TV
static UISelectionFeedbackGenerator *feedbackGenerator;
#endif
#endif

static bool apple_key_state[MAX_KEYS];

/* Send keyboard inputs directly using RETROK_* codes
 * Used by the iOS custom keyboard implementation */
void apple_direct_input_keyboard_event(bool down,
      unsigned code, uint32_t character, uint32_t mod, unsigned device)
{
    int apple_key              = rarch_keysym_lut[code];
    apple_key_state[apple_key] = down;
    input_keyboard_event(down,
          code,
          character, (enum retro_mod)mod, device);
}

void apple_init_small_keyboard() {
    settings_t *settings         = config_get_ptr();
    settings->bools.input_small_keyboard_enable = true;
}
#if TARGET_OS_IPHONE
static bool apple_input_handle_small_keyboard(unsigned* code, bool down)
{
   static uint8_t mapping[128];
   static bool map_initialized;
   static const struct { uint8_t orig; uint8_t mod; } mapping_def[] =
   {
      { KEY_Grave,      KEY_Escape     }, { KEY_1,          KEY_F1         },
      { KEY_2,          KEY_F2         }, { KEY_3,          KEY_F3         },
      { KEY_4,          KEY_F4         }, { KEY_5,          KEY_F5         },
      { KEY_6,          KEY_F6         }, { KEY_7,          KEY_F7         },
      { KEY_8,          KEY_F8         }, { KEY_9,          KEY_F9         },
      { KEY_0,          KEY_F10        }, { KEY_Minus,      KEY_F11        },
      { KEY_Equals,     KEY_F12        }, { KEY_Up,         KEY_PageUp     },
      { KEY_Down,       KEY_PageDown   }, { KEY_Left,       KEY_Home       },
      { KEY_Right,      KEY_End        }, { KEY_Q,          KP_7           },
      { KEY_W,          KP_8           }, { KEY_E,          KP_9           },
      { KEY_A,          KP_4           }, { KEY_S,          KP_5           },
      { KEY_D,          KP_6           }, { KEY_Z,          KP_1           },
      { KEY_X,          KP_2           }, { KEY_C,          KP_3           },
      { 0 }
   };
   unsigned translated_code  = 0;

   if (!map_initialized)
   {
      int i;
      for (i = 0; mapping_def[i].orig; i ++)
         mapping[mapping_def[i].orig] = mapping_def[i].mod;
      map_initialized = true;
   }

   if (*code == KEY_RightShift)
   {
      small_keyboard_active = down;
      *code = 0;
      return true;
   }

   if (*code < 128)
      translated_code = mapping[*code];

   /* Allow old keys to be released. */
   if (!down && apple_key_state[*code])
      return false;

   if ((!down && apple_key_state[translated_code]) ||
         small_keyboard_active)
   {
      *code = translated_code;
      return true;
   }

   return false;
}

static bool apple_input_handle_icade_event(unsigned kb_type_idx, unsigned *code, bool *keydown)
{
   static bool initialized = false;
   bool ret                = false;

   if (!initialized)
   {
      unsigned i;
      unsigned j = 0;

      for (j = 0; j < MAX_ICADE_PROFILES; j++)
      {
         for (i = 0; i < MAX_ICADE_KEYS; i++)
         {
            icade_maps[j][i].key = RETROK_UNKNOWN;
            icade_maps[j][i].up  = false;
         }
      }

      /* iPega PG-9017 */
      j = 1;

      icade_maps[j][rarch_keysym_lut[RETROK_a]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_d]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_e]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_w]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_x]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_u]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_i]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_j]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_k]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_h]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_y]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].key = RETROK_s;

      icade_maps[j][rarch_keysym_lut[RETROK_e]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].up  = true;

      /* 8-bitty */
      j = 2;

      icade_maps[j][rarch_keysym_lut[RETROK_a]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_d]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_e]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_w]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_x]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_h]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_j]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_i]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_k]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_y]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_u]].key = RETROK_RETURN;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].key = RETROK_RETURN;
      icade_maps[j][rarch_keysym_lut[RETROK_l]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_v]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_o]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].key = RETROK_s;

      icade_maps[j][rarch_keysym_lut[RETROK_e]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_v]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].up  = true;

      /* SNES30 8bitDo */
      j = 3;

      icade_maps[j][rarch_keysym_lut[RETROK_e]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_w]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_x]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_a]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_d]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_u]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_h]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_y]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_j]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_k]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_i]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_l]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_v]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_o]].key = RETROK_RETURN;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].key = RETROK_RETURN;

      icade_maps[j][rarch_keysym_lut[RETROK_v]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_e]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].up  = true;

      initialized = true;
   }

   if ((*code < 0x20) && (icade_maps[kb_type_idx][*code].key != RETROK_UNKNOWN))
   {
      *keydown     = icade_maps[kb_type_idx][*code].up ? false : true;
      ret          = true;
      *code        = rarch_keysym_lut[icade_maps[kb_type_idx][*code].key];
   }

   return ret;
}

void apple_input_keyboard_event(bool down,
      unsigned code, uint32_t character, uint32_t mod, unsigned device)
{
   settings_t *settings         = config_get_ptr();
   bool keyboard_gamepad_enable = settings->bools.input_keyboard_gamepad_enable;
   bool small_keyboard_enable   = settings->bools.input_small_keyboard_enable;

   if (keyboard_gamepad_enable)
   {
      if (apple_input_handle_icade_event(
               settings->uints.input_keyboard_gamepad_mapping_type,
               &code, &down))
         character = 0;
      else
         code      = 0;
   }
   else if (small_keyboard_enable)
   {
      if (apple_input_handle_small_keyboard(&code, down))
         character = 0;
   }

   if (code == 0 || code >= MAX_KEYS)
      return;

   apple_key_state[code] = down;

   input_keyboard_event(down,
         input_keymaps_translate_keysym_to_rk(code),
         character, (enum retro_mod)mod, device);
}
#else
void apple_input_keyboard_event(bool down,
      unsigned code, uint32_t character, uint32_t mod, unsigned device)
{
   /* Taken from https://github.com/depp/keycode,
    * check keycode.h for license. */
   static const unsigned char MAC_NATIVE_TO_HID[128] = {
      4, 22,  7,  9, 11, 10, 29, 27,  6, 25,255,  5, 20, 26,  8, 21,
      28, 23, 30, 31, 32, 33, 35, 34, 46, 38, 36, 45, 37, 39, 48, 18,
      24, 47, 12, 19, 40, 15, 13, 52, 14, 51, 49, 54, 56, 17, 16, 55,
      43, 44, 53, 42,255, 41,231,227,225, 57,226,224,229,230,228,255,
      108, 99,255, 85,255, 87,255, 83,255,255,255, 84, 88,255, 86,109,
      110,103, 98, 89, 90, 91, 92, 93, 94, 95,111, 96, 97,255,255,255,
      62, 63, 64, 60, 65, 66,255, 68,255,104,107,105,255, 67,255, 69,
      255,106,117, 74, 75, 76, 61, 77, 59, 78, 58, 80, 79, 81, 82,255
   };
   code                  = HIDKEY(code);
   if (code == 0 || code >= MAX_KEYS)
      return;

   apple_key_state[code] = down;

   input_keyboard_event(down,
         input_keymaps_translate_keysym_to_rk(code),
         character, (enum retro_mod)mod, device);
}
#endif

static void *cocoa_input_init(const char *joypad_driver)
{
   cocoa_input_data_t *apple = NULL;
#ifdef HAVE_COREMOTION
   if (@available(macOS 10.15, *))
      if (!motionManager)
         motionManager = [[CMMotionManager alloc] init];
#endif

#if TARGET_OS_IOS && !TARGET_OS_TV
   if (!feedbackGenerator)
      feedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
   [feedbackGenerator prepare];
#endif

   /* TODO/FIXME - shouldn't we free the above in case this fails for
    * TARGET_OS_IOS / HAVE_COREMOTION? */
   if (!(apple = (cocoa_input_data_t*)calloc(1, sizeof(*apple))))
      return NULL;

   input_keymaps_init_keyboard_lut(rarch_key_map_apple_hid);

   return apple;
}

static void cocoa_input_poll(void *data)
{
   uint32_t i;
   cocoa_input_data_t *apple    = (cocoa_input_data_t*)data;
#ifndef IOS
   float   backing_scale_factor = cocoa_screen_get_backing_scale_factor();
#endif

   if (!apple)
      return;

   for (i = 0; i < apple->touch_count; i++)
   {
      struct video_viewport vp;

      vp.x                        = 0;
      vp.y                        = 0;
      vp.width                    = 0;
      vp.height                   = 0;
      vp.full_width               = 0;
      vp.full_height              = 0;

#ifndef IOS
      apple->touches[i].screen_x *= backing_scale_factor;
      apple->touches[i].screen_y *= backing_scale_factor;
#endif
      video_driver_translate_coord_viewport_wrap(
            &vp,
            apple->touches[i].screen_x,
            apple->touches[i].screen_y,
            &apple->touches[i].fixed_x,
            &apple->touches[i].fixed_y,
            &apple->touches[i].full_x,
            &apple->touches[i].full_y);
   }
}

static int16_t cocoa_input_state(
      void *data,
      const input_device_driver_t *joypad,
      const input_device_driver_t *sec_joypad,
      rarch_joypad_info_t *joypad_info,
      const retro_keybind_set *binds,
      bool keyboard_mapping_blocked,
      unsigned port,
      unsigned device,
      unsigned idx,
      unsigned id)
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   switch (device)
   {
      case RETRO_DEVICE_JOYPAD:
         if (id == RETRO_DEVICE_ID_JOYPAD_MASK)
         {
            unsigned i;
            /* Do a bitwise OR to combine both input
             * states together */
            int16_t ret = 0;

            if (!keyboard_mapping_blocked)
            {
               for (i = 0; i < RARCH_FIRST_CUSTOM_BIND; i++)
               {
                  if ((binds[port][i].key < RETROK_LAST)
                        && apple_key_state[rarch_keysym_lut[binds[port][i].key]])
                     ret |= (1 << i);
               }
            }
            return ret;
         }

         if (binds[port][id].valid)
         {
            if (id < RARCH_BIND_LIST_END)
               if (!keyboard_mapping_blocked || (id == RARCH_GAME_FOCUS_TOGGLE))
                  if (apple_key_state[rarch_keysym_lut[binds[port][id].key]])
                     return 1;

         }
         break;
      case RETRO_DEVICE_ANALOG:
         {
            int16_t ret           = 0;
            int id_minus_key      = 0;
            int id_plus_key       = 0;
            unsigned id_minus     = 0;
            unsigned id_plus      = 0;
            bool id_plus_valid    = false;
            bool id_minus_valid   = false;

            input_conv_analog_id_to_bind_id(idx, id, id_minus, id_plus);

            id_minus_valid        = binds[port][id_minus].valid;
            id_plus_valid         = binds[port][id_plus].valid;
            id_minus_key          = binds[port][id_minus].key;
            id_plus_key           = binds[port][id_plus].key;

            if (id_plus_valid && id_plus_key < RETROK_LAST)
            {
               if (apple_key_state[rarch_keysym_lut[(enum retro_key)id_plus_key]])
                  ret = 0x7fff;
            }
            if (id_minus_valid && id_minus_key < RETROK_LAST)
            {
               if (apple_key_state[rarch_keysym_lut[(enum retro_key)id_minus_key]])
                  ret += -0x7fff;
            }
            return ret;
         }
         break;

      case RETRO_DEVICE_KEYBOARD:
         return (id < RETROK_LAST) && apple_key_state[rarch_keysym_lut[(enum retro_key)id]];
      case RETRO_DEVICE_MOUSE:
      case RARCH_DEVICE_MOUSE_SCREEN:
         {
            int16_t val = 0;
            switch (id)
            {
               case RETRO_DEVICE_ID_MOUSE_X:
                  if (device == RARCH_DEVICE_MOUSE_SCREEN)
                  {
#ifdef IOS
                     return apple->window_pos_x;
#else
                     return apple->window_pos_x * cocoa_screen_get_backing_scale_factor();
#endif
                  }
#ifdef IOS
#ifdef HAVE_IOS_TOUCHMOUSE
                  if (apple->window_pos_x > 0)
                  {
                     val = apple->window_pos_x - apple->mouse_x_last;
                     apple->mouse_x_last = apple->window_pos_x;
                  }
                  else
                     val = apple->mouse_rel_x;
#else
                  val = apple->mouse_rel_x;
#endif
#else
                  val = apple->window_pos_x - apple->mouse_x_last;
                  apple->mouse_x_last = apple->window_pos_x;
#endif
                  return val;
               case RETRO_DEVICE_ID_MOUSE_Y:
                  if (device == RARCH_DEVICE_MOUSE_SCREEN)
                  {
#ifdef IOS
                     return apple->window_pos_y;
#else
                     return apple->window_pos_y * cocoa_screen_get_backing_scale_factor();
#endif
                  }
#ifdef IOS
#ifdef HAVE_IOS_TOUCHMOUSE
                  if (apple->window_pos_y > 0)
                  {
                     val = apple->window_pos_y - apple->mouse_y_last;
                     apple->mouse_y_last = apple->window_pos_y;
                  }
                  else
                     val = apple->mouse_rel_y;
#else
                  val    = apple->mouse_rel_y;
#endif
#else
                  val = apple->window_pos_y - apple->mouse_y_last;
                  apple->mouse_y_last = apple->window_pos_y;
#endif
                  return val;
               case RETRO_DEVICE_ID_MOUSE_LEFT:
                  return apple->mouse_buttons & 1;
               case RETRO_DEVICE_ID_MOUSE_RIGHT:
                  return apple->mouse_buttons & 2;
               case RETRO_DEVICE_ID_MOUSE_WHEELUP:
                  return apple->mouse_wu;
               case RETRO_DEVICE_ID_MOUSE_WHEELDOWN:
                  return apple->mouse_wd;
               case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELUP:
                  return apple->mouse_wl;
               case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELDOWN:
                  return apple->mouse_wr;
            }
         }
         break;
      case RETRO_DEVICE_POINTER:
      case RARCH_DEVICE_POINTER_SCREEN:
         {

            if (idx < apple->touch_count && (idx < MAX_TOUCHES))
            {
               const cocoa_touch_data_t *touch = (const cocoa_touch_data_t *)
                  &apple->touches[idx];

               if (touch)
               {
                  switch (id)
                  {
                     case RETRO_DEVICE_ID_POINTER_PRESSED:
                        if (device == RARCH_DEVICE_POINTER_SCREEN)
                           return (touch->full_x  != -0x8000) && (touch->full_y  != -0x8000); /* Inside? */
                        return    (touch->fixed_x != -0x8000) && (touch->fixed_y != -0x8000); /* Inside? */
                     case RETRO_DEVICE_ID_POINTER_X:
                        return (device == RARCH_DEVICE_POINTER_SCREEN) ? touch->full_x : touch->fixed_x;
                     case RETRO_DEVICE_ID_POINTER_Y:
                        return (device == RARCH_DEVICE_POINTER_SCREEN) ? touch->full_y : touch->fixed_y;
                     case RETRO_DEVICE_ID_POINTER_COUNT:
                        return apple->touch_count;
                  }
               }
            }
         }
         break;
   }

   return 0;
}

static void cocoa_input_free(void *data)
{
   unsigned i;
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   if (!apple || !data)
      return;

   for (i = 0; i < MAX_KEYS; i++)
      apple_key_state[i] = 0;

   free(apple);
}

static uint64_t cocoa_input_get_capabilities(void *data)
{
   return
        (1 << RETRO_DEVICE_JOYPAD)
      | (1 << RETRO_DEVICE_MOUSE)
      | (1 << RETRO_DEVICE_KEYBOARD)
      | (1 << RETRO_DEVICE_POINTER)
      | (1 << RETRO_DEVICE_ANALOG);
}

static bool cocoa_input_set_sensor_state(void *data, unsigned port,
      enum retro_sensor_action action, unsigned rate)
{
   if (   (action != RETRO_SENSOR_ACCELEROMETER_ENABLE)
       && (action != RETRO_SENSOR_ACCELEROMETER_DISABLE)
       && (action != RETRO_SENSOR_GYROSCOPE_ENABLE)
       && (action != RETRO_SENSOR_GYROSCOPE_DISABLE))
      return false;

#ifdef HAVE_MFI
   if (@available(iOS 14.0, macOS 11.0, *))
   {
      for (GCController *controller in [GCController controllers])
      {
         if (!controller || controller.playerIndex != port)
            continue;
         if (!controller.motion)
            break;
         if (controller.motion.sensorsRequireManualActivation)
         {
            /* This is a bug, we assume if you turn on/off either
             * you want both on/off */
            if (     (action == RETRO_SENSOR_ACCELEROMETER_ENABLE)
                  || (action == RETRO_SENSOR_GYROSCOPE_ENABLE))
               controller.motion.sensorsActive = YES;
            else
               controller.motion.sensorsActive = NO;
         }
         /* no such thing as update interval for GCController? */
         return true;
      }
   }
#endif

#ifdef HAVE_COREMOTION
   if (port != 0)
      return false;

   if (!motionManager || !motionManager.deviceMotionAvailable)
      return false;

   if (     (action == RETRO_SENSOR_ACCELEROMETER_ENABLE)
         || (action == RETRO_SENSOR_GYROSCOPE_ENABLE))
   {
      if (!motionManager.deviceMotionActive)
         [motionManager startDeviceMotionUpdates];
      motionManager.deviceMotionUpdateInterval = 1.0f / (float)rate;
   }
   else
   {
      if (motionManager.deviceMotionActive)
         [motionManager stopDeviceMotionUpdates];
   }

   return true;
#else
   return false;
#endif
}

static float cocoa_input_get_sensor_input(void *data, unsigned port, unsigned id)
{
#ifdef HAVE_MFI
   if (@available(iOS 14.0, *))
   {
      for (GCController *controller in [GCController controllers])
      {
         if (!controller || controller.playerIndex != port)
            continue;
         if (!controller.motion)
            break;
         switch (id)
         {
            case RETRO_SENSOR_ACCELEROMETER_X:
               return controller.motion.userAcceleration.x;
            case RETRO_SENSOR_ACCELEROMETER_Y:
               return controller.motion.userAcceleration.y;
            case RETRO_SENSOR_ACCELEROMETER_Z:
               return controller.motion.userAcceleration.z;
            case RETRO_SENSOR_GYROSCOPE_X:
               return controller.motion.rotationRate.x;
            case RETRO_SENSOR_GYROSCOPE_Y:
               return controller.motion.rotationRate.y;
            case RETRO_SENSOR_GYROSCOPE_Z:
               return controller.motion.rotationRate.z;
         }
      }
   }
#endif

#ifdef HAVE_COREMOTION
   if (port == 0 && motionManager && motionManager.deviceMotionActive)
   {
      switch (id)
      {
         case RETRO_SENSOR_ACCELEROMETER_X:
            return motionManager.deviceMotion.userAcceleration.x;
         case RETRO_SENSOR_ACCELEROMETER_Y:
            return motionManager.deviceMotion.userAcceleration.y;
         case RETRO_SENSOR_ACCELEROMETER_Z:
            return motionManager.deviceMotion.userAcceleration.z;
         case RETRO_SENSOR_GYROSCOPE_X:
            return motionManager.deviceMotion.rotationRate.x;
         case RETRO_SENSOR_GYROSCOPE_Y:
            return motionManager.deviceMotion.rotationRate.y;
         case RETRO_SENSOR_GYROSCOPE_Z:
            return motionManager.deviceMotion.rotationRate.z;
      }
   }
#endif

   return 0.0f;
}

#if TARGET_OS_IOS
static void cocoa_input_keypress_vibrate(void)
{
#if !TARGET_OS_TV
   [feedbackGenerator selectionChanged];
   [feedbackGenerator prepare];
#endif
}
#endif

#ifdef OSX
static void cocoa_input_grab_mouse(void *data, bool state)
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   if (state)
   {
      NSWindow *window      = (BRIDGE NSWindow*)ui_companion_cocoa.get_main_window(nil);
      CGPoint window_pos    = window.frame.origin;
      CGSize window_size    = window.frame.size;
      CGPoint window_center = CGPointMake(window_pos.x + window_size.width / 2.0f, window_pos.y + window_size.height / 2.0f);
      CGWarpMouseCursorPosition(window_center);
   }

   CGAssociateMouseAndMouseCursorPosition(!state);
   cocoa_show_mouse(nil, !state);
   apple->mouse_grabbed = state;
}
#endif

input_driver_t input_cocoa = {
   cocoa_input_init,
   cocoa_input_poll,
   cocoa_input_state,
   cocoa_input_free,
   cocoa_input_set_sensor_state,
   cocoa_input_get_sensor_input,
   cocoa_input_get_capabilities,
   "cocoa",
#ifdef OSX
   cocoa_input_grab_mouse,
#else
   NULL,                         /* grab_mouse */
#endif
   NULL,                         /* grab_stdin */
#if TARGET_OS_IOS
   cocoa_input_keypress_vibrate
#else
   NULL                          /* vibrate */
#endif
};

