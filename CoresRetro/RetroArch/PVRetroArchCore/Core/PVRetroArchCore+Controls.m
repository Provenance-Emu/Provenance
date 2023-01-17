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
        ELOG(@"Binding Controls\n");
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
    if (!self.bindAnalogKeys)
        return;
    switch (key) {
        static float leftXAxis=0;
        static float leftYAxis=0;
        static float rightXAxis=0;
        static float rightYAxis=0;
        case(22): // s
            leftYAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
            break;
        case(26): // w
            leftYAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
            break;
        case(7):  // d
            leftXAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
            break;
        case(4):  // a
            leftXAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
            break;
        case(11): // h
            rightYAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
            break;
        case(28): // y
            rightYAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
            break;
        case(13):  // j
            rightXAxis=pressed?1.0:0;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
            break;
        case(10):  // g
            rightXAxis=pressed?-1.0:0;
            [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
            break;
        default:
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
    ELOG(@"Setting up Controller Notification Listeners\n");
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
        ELOG(@"Controller Vendor Name: %s\n",controller.vendorName.UTF8String);
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
            controller.extendedGamepad.leftThumbstick.xAxis.valueChangedHandler = ^(GCControllerAxisInput* xAxis, float value) {
                [touch_controller.extendedGamepad.leftThumbstick.xAxis setValue:value];
            };
            controller.extendedGamepad.leftThumbstick.yAxis.valueChangedHandler = ^(GCControllerAxisInput* yAxis, float value) {
                [touch_controller.extendedGamepad.leftThumbstick.yAxis setValue:value];
            };
            controller.extendedGamepad.rightThumbstick.xAxis.valueChangedHandler = ^(GCControllerAxisInput* xAxis, float value) {
                [touch_controller.extendedGamepad.rightThumbstick.xAxis setValue:value];
            };
            controller.extendedGamepad.rightThumbstick.yAxis.valueChangedHandler = ^(GCControllerAxisInput* yAxis, float value) {
                [touch_controller.extendedGamepad.rightThumbstick.yAxis setValue:value];
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
            //controller.extendedGamepad.buttonMenu.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
            //    [[NSNotificationCenter defaultCenter] postNotificationName:@"PauseGame" object:nil userInfo:nil];
            //};
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
        ELOG(@"Option: Use Retro arch controller\n");
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
                should_update=true;
                ELOG(@"Updating %s to %s\n", original_overlay.UTF8String, new_overlay.UTF8String);
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HideTouchControls" object:nil userInfo:nil];
    } else {
        ELOG(@"Option: Don't Use Retro arch controller\n");
        settings_t *settings                     = config_get_ptr();
        NSString *overlay=@RETROARCH_PVOVERLAY;
        NSString *new_overlay =  [overlay stringByReplacingOccurrencesOfString:@"/RetroArch"
         withString:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch" ]];
        if (![new_overlay isEqualToString:original_overlay]) {
            configuration_set_string(settings,
                    settings->paths.path_overlay,
                    new_overlay.UTF8String
            );
            should_update=true;
            ELOG(@"Updating %s to %s\n", original_overlay.UTF8String, new_overlay.UTF8String);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowTouchControls" object:nil userInfo:nil];
    }
    if (should_update) {
        ELOG(@"Option: Updating Overlay\n");
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
