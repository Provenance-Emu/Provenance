//
//  PVPPSSPPCore+Controls.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVPPSSPP/PVPPSSPP.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

/* PPSSPP Includes */
#import <Foundation/Foundation.h>
#import <Foundation/NSObjCRuntime.h>
#import <GLKit/GLKit.h>

#include "Common/System/Display.h"
#include "Common/System/System.h"
#include "Common/System/NativeApp.h"
#include "Common/TimeUtil.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Input/InputState.h"
#include "Common/Net/Resolve.h"
#include "Common/UI/Screen.h"
#include "Common/GPU/thin3d.h"
#include "Common/Input/KeyCodes.h"
#include "Common/GPU/OpenGL/GLFeatures.h"
#include "Common/Input/KeyCodes.h"
#include "Common/GraphicsContext.h"

#include "Core/Config.h"

#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/machine.h>

#define DC_BTN_C        (1<<0)
#define DC_BTN_B        (1<<1)
#define DC_BTN_A        (1<<2)
#define DC_BTN_START    (1<<3)
#define DC_DPAD_UP      (1<<4)
#define DC_DPAD_DOWN    (1<<5)
#define DC_DPAD_LEFT    (1<<6)
#define DC_DPAD_RIGHT   (1<<7)
#define DC_BTN_Z        (1<<8)
#define DC_BTN_Y        (1<<9)
#define DC_BTN_X        (1<<10)
#define DC_BTN_D        (1<<11)
#define DC_DPAD2_UP     (1<<12)
#define DC_DPAD2_DOWN   (1<<13)
#define DC_DPAD2_LEFT   (1<<14)
#define DC_DPAD2_RIGHT  (1<<15)

#define DC_AXIS_LT       (0X10000)
#define DC_AXIS_RT       (0X10001)
#define DC_AXIS_X        (0X20000)
#define DC_AXIS_Y        (0X20001)

extern bool _isInitialized;

@implementation PVPPSSPPCore (Controls)

- (void)initControllBuffers {
}

#pragma mark - Control
-(void)controllerConnected:(NSNotification *)notification {
    [self setupControllers];
}
-(void)controllerDisconnected:(NSNotification *)notification {
}
-(void)setupControllers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCKeyboardDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCKeyboardDidDisconnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil
    ];
	[self initControllBuffers];
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
		if (controller.extendedGamepad != nil)
		{
			controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_2 action:(pressed?1:0)];
			};
			controller.extendedGamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_3 action:(pressed?1:0)];
			};
			controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_4 action:(pressed?1:0)];
			};
			controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_1 action:(pressed?1:0)];
			};
			controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_7 action:(pressed?1:0)];
			};
			controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_8 action:(pressed?1:0)];
			};
			controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_9 action:(pressed?1:0)];
			};
			controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_10 action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_UP action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_LEFT action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_RIGHT action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_DOWN action:(pressed?1:0)];
			};
			controller.extendedGamepad.leftThumbstick.xAxis.valueChangedHandler = ^(GCControllerAxisInput* xAxis, float value) {
				[self gamepadMoveEventOnPad:player axis:JOYSTICK_AXIS_X value:CGFloat(value)];
			};
			controller.extendedGamepad.leftThumbstick.yAxis.valueChangedHandler = ^(GCControllerAxisInput* yAxis, float value) {
				[self gamepadMoveEventOnPad:player axis:JOYSTICK_AXIS_Y value:CGFloat(-value)];
			};
			controller.extendedGamepad.rightThumbstick.xAxis.valueChangedHandler = ^(GCControllerAxisInput* xAxis, float value) {
				[self gamepadMoveEventOnPad:player axis:JOYSTICK_AXIS_Z value:CGFloat(value)];
			};
			controller.extendedGamepad.rightThumbstick.yAxis.valueChangedHandler = ^(GCControllerAxisInput* yAxis, float value) {
				[self gamepadMoveEventOnPad:player axis:JOYSTICK_AXIS_RZ value:CGFloat(-value)];
			};
			controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_11 action:(pressed?1:0)];
			};
			controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_12 action:(pressed?1:0)];
			};
			controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_10 action:(pressed?1:0)]; // Start
			};
			#if defined(__IPHONE_14_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_0
			controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_15 action:(pressed?1:0)];
			};
			#endif
		} else if (controller.gamepad != nil) {
			controller.gamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_2 action:(pressed?1:0)];
			};
			controller.gamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_3 action:(pressed?1:0)];
			};
			controller.gamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_4 action:(pressed?1:0)];
			};
			controller.gamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_1 action:(pressed?1:0)];
			};
			controller.gamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_7 action:(pressed?1:0)];
			};
			controller.gamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_8 action:(pressed?1:0)];
			};
			controller.gamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_UP action:(pressed?1:0)];
			};
			controller.gamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_LEFT action:(pressed?1:0)];
			};
			controller.gamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_RIGHT action:(pressed?1:0)];
			};
			controller.gamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_DOWN action:(pressed?1:0)];
			};
		} else if (controller.microGamepad != nil) {
			controller.microGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_2 action:(pressed?1:0)];
			};
			controller.microGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_BUTTON_4 action:(pressed?1:0)];
			};
			controller.microGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_UP action:(pressed?1:0)];
			};
			controller.microGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_LEFT action:(pressed?1:0)];
			};
			controller.microGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_RIGHT action:(pressed?1:0)];
			};
			controller.microGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
				[self gamepadEventOnPad:player button:NKCODE_DPAD_DOWN action:(pressed?1:0)];
			};
		}
	}
}

- (void)gamepadEventOnPad:(int)pad button:(int)button action:(int)action
{
	if (_isInitialized) {
		KeyInput key;
		key.deviceId = DEVICE_ID_PAD_0;
		key.flags = action == 1 ? KEY_DOWN : KEY_UP;
		key.keyCode = (InputKeyCode)button;
		NativeKey(key);
	}
}

- (void)gamepadMoveEventOnPad:(int)pad axis:(int)axis value:(CGFloat)value
{
	if (_isInitialized) {
		AxisInput axisInput;
		axisInput.deviceId = DEVICE_ID_PAD_0;
        axisInput.axisId = axis == 0 ? JOYSTICK_AXIS_X : JOYSTICK_AXIS_Y;
		axisInput.value = value;
		NativeAxis(axisInput);
	}
}

-(void)didPushPSPButton:(PVPSPButton)button forPlayer:(NSInteger)player {
	[self sendPSPButtonInput:(PVPSPButton)button isPressed:true withValue:0.0 forPlayer:player];
}

-(void)didReleasePSPButton:(PVPSPButton)button forPlayer:(NSInteger)player {
	[self sendPSPButtonInput:(PVPSPButton)button isPressed:false withValue:0.0 forPlayer:player];
}

- (void)didMovePSPJoystickDirection:(PVPSXButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVPSPButtonLeftAnalog):
            [self gamepadMoveEventOnPad:player axis:JOYSTICK_AXIS_X value:CGFloat(xValue)];
            [self gamepadMoveEventOnPad:player axis:JOYSTICK_AXIS_Y value:CGFloat(-yValue)];
            break;
    }
}
- (void)didMovePSPJoystickDirection:(PVPSPButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
	[self sendPSPButtonInput:(PVPSPButton)button isPressed:value != 0 withValue:value forPlayer:player];
}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
	[self didMovePSPJoystickDirection:(PVPSPButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
	[self didPushPSPButton:(PVPSPButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
	[self didReleasePSPButton:(PVPSPButton)button forPlayer:player];
}


-(void)sendPSPButtonInput:(enum PVPSPButton)button isPressed:(bool)pressed withValue:(CGFloat)value forPlayer:(NSInteger)player {
	switch (button) {
		case(PVPSPButtonStart):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_10 action:(pressed?1:0)]; // Start
			break;
		case(PVPSPButtonSelect):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_9 action:(pressed?1:0)]; // Select
			break;
		case(PVPSPButtonSquare):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_4 action:(pressed?1:0)]; // Square
			break;
		case(PVPSPButtonCross):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_2 action:(pressed?1:0)]; // Cross
			break;
		case(PVPSPButtonTriangle):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_1 action:(pressed?1:0)]; // Triangle
			break;
		case(PVPSPButtonCircle):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_3 action:(pressed?1:0)]; // Circle
			break;
		case(PVPSPButtonL1):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_7 action:(pressed?1:0)];
			break;
		case(PVPSPButtonR1):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_8 action:(pressed?1:0)];
			break;
		case(PVPSPButtonL2):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_9 action:(pressed?1:0)];
			break;
		case(PVPSPButtonR2):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_10 action:(pressed?1:0)];
			break;
		case(PVPSPButtonL3):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_11 action:(pressed?1:0)];
			break;
		case(PVPSPButtonR3):
			[self gamepadEventOnPad:player button:NKCODE_BUTTON_12 action:(pressed?1:0)];
			break;
		case(PVPSPButtonLeft):
			[self gamepadEventOnPad:player button:NKCODE_DPAD_LEFT action:(pressed?1:0)];
			break;
		case(PVPSPButtonRight):
			[self gamepadEventOnPad:player button:NKCODE_DPAD_RIGHT action:(pressed?1:0)];
			break;
		case(PVPSPButtonUp):
			[self gamepadEventOnPad:player button:NKCODE_DPAD_UP action:(pressed?1:0)];
			break;
		case(PVPSPButtonDown):
			[self gamepadEventOnPad:player button:NKCODE_DPAD_DOWN action:(pressed?1:0)];
			break;
		default:
			break;
	}
}
@end

