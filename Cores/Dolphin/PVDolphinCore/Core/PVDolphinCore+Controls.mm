//
//  PVDolphinCore+Controls.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Controls.h"
#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>
#if !TARGET_OS_TV
#import <CoreMotion/CoreMotion.h>
#endif
#import <PVLogging/PVLoggingObjC.h>
@import PVCoreBridge;
@import PVCoreObjCBridge;

/* Dolphin Includes */
#include "Common/CPUDetect.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/Logging/LogManager.h"
#include "Common/MsgHandler.h"
#include "Common/Thread.h"
#include "Common/Version.h"

#include "Core/Boot/Boot.h"
#include "Core/BootManager.h"
#include "Core/Config/GraphicsSettings.h"
#include "Core/Config/MainSettings.h"
#include "Core/Config/SYSCONFSettings.h"
#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/Host.h"
#include "Core/HW/CPU.h"
#include "Core/HW/DVD/DVDInterface.h"
#include "Core/HW/GCKeyboard.h"
#include "Core/HW/GCPad.h"
#include "Core/HW/GCPadEmu.h"
#include "Core/HW/ProcessorInterface.h"
#include "Core/HW/VideoInterface.h"
#include "Core/HW/Wiimote.h"
#include "Core/HW/WiimoteEmu/Extension/Classic.h"
#include "Core/HW/WiimoteReal/WiimoteReal.h"
#include "Core/HW/WiimoteEmu/WiimoteEmu.h"
#include "Core/HW/SI/SI.h"
#include "Core/HW/SI/SI_Device.h"
#include "Core/FreeLookManager.h"
#include "Core/IOS/IOS.h"
#include "Core/IOS/STM/STM.h"
#include "Core/PowerPC/PowerPC.h"
#include "Core/State.h"
#include "Core/WiiUtils.h"

#include "InputCommon/InputConfig.h"
#include "InputCommon/GCPadStatus.h"
#include "InputCommon/ControllerEmu/ControlGroup/Attachments.h"
#include "InputCommon/ControllerEmu/ControlGroup/Cursor.h"
#include "InputCommon/ControllerEmu/ControlGroup/ControlGroup.h"
#include "InputCommon/ControllerEmu/Control/Control.h"
#include "InputCommon/ControlReference/ControlReference.h"
#include "InputCommon/ControllerInterface/iOS/iOS.h"
#include "InputCommon/ControllerInterface/iOS/Motor.h"
#include "InputCommon/ControllerInterface/ControllerInterface.h"
#include "InputCommon/ControllerInterface/iOS/Touchscreen.h"
#include "InputCommon/ControllerInterface/iOS/StateManager.h"
#include "InputCommon/ControllerInterface/iOS/ButtonType.h"

#include "UICommon/CommandLineParse.h"
#include "UICommon/UICommon.h"
#include "UICommon/DiscordPresence.h"

#include "Core/Config/MainSettings.h"

#include "Core/System.h"

#include "Core/Movie.h"
#include "iOS/App/Common/Bridging/DOLConfigBridge.h"

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

// Dolphin Button Maps
// Copyright 2022 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

enum ButtonType
{
  // GC
  BUTTON_A = 0,
  BUTTON_B = 1,
  BUTTON_START = 2,
  BUTTON_X = 3,
  BUTTON_Y = 4,
  BUTTON_Z = 5,
  BUTTON_UP = 6,
  BUTTON_DOWN = 7,
  BUTTON_LEFT = 8,
  BUTTON_RIGHT = 9,
  STICK_MAIN = 10,
  STICK_MAIN_UP = 11,
  STICK_MAIN_DOWN = 12,
  STICK_MAIN_LEFT = 13,
  STICK_MAIN_RIGHT = 14,
  STICK_C = 15,
  STICK_C_UP = 16,
  STICK_C_DOWN = 17,
  STICK_C_LEFT = 18,
  STICK_C_RIGHT = 19,
  TRIGGER_L = 20,
  TRIGGER_R = 21,
  // Wiimote
  WIIMOTE_BUTTON_A = 100,
  WIIMOTE_BUTTON_B = 101,
  WIIMOTE_BUTTON_MINUS = 102,
  WIIMOTE_BUTTON_PLUS = 103,
  WIIMOTE_BUTTON_HOME = 104,
  WIIMOTE_BUTTON_1 = 105,
  WIIMOTE_BUTTON_2 = 106,
  WIIMOTE_UP = 107,
  WIIMOTE_DOWN = 108,
  WIIMOTE_LEFT = 109,
  WIIMOTE_RIGHT = 110,
  WIIMOTE_IR = 111,
  WIIMOTE_IR_UP = 112,
  WIIMOTE_IR_DOWN = 113,
  WIIMOTE_IR_LEFT = 114,
  WIIMOTE_IR_RIGHT = 115,
  WIIMOTE_IR_FORWARD = 116,
  WIIMOTE_IR_BACKWARD = 117,
  WIIMOTE_IR_HIDE = 118,
  WIIMOTE_SWING = 119,
  WIIMOTE_SWING_UP = 120,
  WIIMOTE_SWING_DOWN = 121,
  WIIMOTE_SWING_LEFT = 122,
  WIIMOTE_SWING_RIGHT = 123,
  WIIMOTE_SWING_FORWARD = 124,
  WIIMOTE_SWING_BACKWARD = 125,
  WIIMOTE_TILT = 126,
  WIIMOTE_TILT_FORWARD = 127,
  WIIMOTE_TILT_BACKWARD = 128,
  WIIMOTE_TILT_LEFT = 129,
  WIIMOTE_TILT_RIGHT = 130,
  WIIMOTE_TILT_MODIFIER = 131,
  WIIMOTE_SHAKE_X = 132,
  WIIMOTE_SHAKE_Y = 133,
  WIIMOTE_SHAKE_Z = 134,
  // Nunchuk
  NUNCHUK_BUTTON_C = 200,
  NUNCHUK_BUTTON_Z = 201,
  NUNCHUK_STICK = 202,
  NUNCHUK_STICK_UP = 203,
  NUNCHUK_STICK_DOWN = 204,
  NUNCHUK_STICK_LEFT = 205,
  NUNCHUK_STICK_RIGHT = 206,
  NUNCHUK_SWING = 207,
  NUNCHUK_SWING_UP = 208,
  NUNCHUK_SWING_DOWN = 209,
  NUNCHUK_SWING_LEFT = 210,
  NUNCHUK_SWING_RIGHT = 211,
  NUNCHUK_SWING_FORWARD = 212,
  NUNCHUK_SWING_BACKWARD = 213,
  NUNCHUK_TILT = 214,
  NUNCHUK_TILT_FORWARD = 215,
  NUNCHUK_TILT_BACKWARD = 216,
  NUNCHUK_TILT_LEFT = 217,
  NUNCHUK_TILT_RIGHT = 218,
  NUNCHUK_TILT_MODIFIER = 219,
  NUNCHUK_SHAKE_X = 220,
  NUNCHUK_SHAKE_Y = 221,
  NUNCHUK_SHAKE_Z = 222,
  // Classic
  CLASSIC_BUTTON_A = 300,
  CLASSIC_BUTTON_B = 301,
  CLASSIC_BUTTON_X = 302,
  CLASSIC_BUTTON_Y = 303,
  CLASSIC_BUTTON_MINUS = 304,
  CLASSIC_BUTTON_PLUS = 305,
  CLASSIC_BUTTON_HOME = 306,
  CLASSIC_BUTTON_ZL = 307,
  CLASSIC_BUTTON_ZR = 308,
  CLASSIC_DPAD_UP = 309,
  CLASSIC_DPAD_DOWN = 310,
  CLASSIC_DPAD_LEFT = 311,
  CLASSIC_DPAD_RIGHT = 312,
  CLASSIC_STICK_LEFT = 313,
  CLASSIC_STICK_LEFT_UP = 314,
  CLASSIC_STICK_LEFT_DOWN = 315,
  CLASSIC_STICK_LEFT_LEFT = 316,
  CLASSIC_STICK_LEFT_RIGHT = 317,
  CLASSIC_STICK_RIGHT = 318,
  CLASSIC_STICK_RIGHT_UP = 319,
  CLASSIC_STICK_RIGHT_DOWN = 320,
  CLASSIC_STICK_RIGHT_LEFT = 321,
  CLASSIC_STICK_RIGHT_RIGHT = 322,
  CLASSIC_TRIGGER_L = 323,
  CLASSIC_TRIGGER_R = 324,
  // Wiimote IMU
  WIIMOTE_ACCEL_LEFT = 625,
  WIIMOTE_ACCEL_RIGHT = 626,
  WIIMOTE_ACCEL_FORWARD = 627,
  WIIMOTE_ACCEL_BACKWARD = 628,
  WIIMOTE_ACCEL_UP = 629,
  WIIMOTE_ACCEL_DOWN = 630,
  WIIMOTE_GYRO_PITCH_UP = 631,
  WIIMOTE_GYRO_PITCH_DOWN = 632,
  WIIMOTE_GYRO_ROLL_LEFT = 633,
  WIIMOTE_GYRO_ROLL_RIGHT = 634,
  WIIMOTE_GYRO_YAW_LEFT = 635,
  WIIMOTE_GYRO_YAW_RIGHT = 636,
  // Rumble
  RUMBLE = 700,
  // Nunchuk IMU
  NUNCHUK_ACCEL_LEFT = 900,
  NUNCHUK_ACCEL_RIGHT = 901,
  NUNCHUK_ACCEL_FORWARD = 902,
  NUNCHUK_ACCEL_BACKWARD = 903,
  NUNCHUK_ACCEL_UP = 904,
  NUNCHUK_ACCEL_DOWN = 905
};

static const int GameCubeMap[]  = {
	DC_DPAD_UP, DC_DPAD_DOWN, DC_DPAD_LEFT, DC_DPAD_RIGHT,
	DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y,
	DC_AXIS_LT, DC_AXIS_RT,
	DC_BTN_START
};

typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef unsigned int   u32;
static bool rotateControls = false;
static bool rotateIr = false;
CGFloat adj=10;
CGFloat adj2=5;
constexpr auto INPUT_DETECT_INITIAL_TIME = std::chrono::seconds(3);
constexpr auto INPUT_DETECT_CONFIRMATION_TIME = std::chrono::milliseconds(0);
constexpr auto INPUT_DETECT_MAXIMUM_TIME = std::chrono::seconds(5);
extern bool _isInitialized;
// Reicast controller data
u16 kcode[4];
u8 rt[4];
u8 lt[4];
u32 vks[4];
s8 joyx[4], joyy[4];

@implementation PVDolphinCoreBridge (Controls)

- (void)initControllBuffers {
	memset(&kcode, 0xFFFF, sizeof(kcode));
	bzero(&rt, sizeof(rt));
	bzero(&lt, sizeof(lt));
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCControllerDidDisconnectNotification
                                               object:nil
    ];
	    [self initControllBuffers];
    [self writeWiiIniFile];
    [self writeGCIniFile];
    ciface::iOS::StateManager::GetInstance()->Init();
    ILOG(@"🎮 StateManager initialized");

    // Setup haptic feedback for iOS device rumble
    [self setupHapticFeedback];

    // Setup gyro motion controls for Wii motion
    [self setupGyroMotionControls];

    Wiimote::Initialize(Wiimote::InitializeMode::DO_NOT_WAIT_FOR_WIIMOTES);
    Pad::Initialize();
    Wiimote::LoadConfig();
    Pad::LoadConfig();
    int port=4;
    int gcPort = 0;
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
            controller.extendedGamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:WIIMOTE_BUTTON_A
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:port
                     button:CLASSIC_BUTTON_B
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:BUTTON_B
                     action:(pressed?1:0)];
            };
            controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port
                     button:WIIMOTE_BUTTON_B
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:port
                     button:CLASSIC_BUTTON_Y
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:BUTTON_Y action:(pressed?1:0)];
            };
			controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:WIIMOTE_BUTTON_1
                         action:(pressed?1:0)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadEventOnPad:port
                     button:CLASSIC_BUTTON_A
                     action:(pressed?1:0)];
					[self gamepadEventOnPad:gcPort button:BUTTON_A
                     action:(pressed?1:0)];
			};
            controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port
                     button:WIIMOTE_BUTTON_2
                     action:(pressed?1:0)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_X value:value];
                    [self gamepadEventOnPad:port
                     button:CLASSIC_BUTTON_X
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:BUTTON_X
                     action:(pressed?1:0)];
            };
						controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadEventOnPad:port button:WIIMOTE_BUTTON_PLUS action:(pressed?1:0)];
                    [self gamepadEventOnPad:port
				 button:CLASSIC_BUTTON_ZL
				 action:(pressed?1:0)];
				[self gamepadMoveEventOnPad:gcPort axis:TRIGGER_L value:(pressed?1.0:0.0)];
			};
						controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_X value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:value];
                    [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_MINUS action:(pressed?1:0)];
                    [self gamepadEventOnPad:port
				 button:ciface::iOS::ButtonType::CLASSIC_BUTTON_ZR
				 action:(pressed?1:0)];
				[self gamepadMoveEventOnPad:gcPort axis:ciface::iOS::ButtonType::TRIGGER_R value:(pressed?1.0:0.0)];
			};
						controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::NUNCHUK_BUTTON_C action:(pressed?1:0)];
                    [self gamepadEventOnPad:port
				 button:ciface::iOS::ButtonType::CLASSIC_TRIGGER_L
				 action:(pressed?1:0)];
                    [self gamepadMoveEventOnPad:gcPort axis:ciface::iOS::ButtonType::TRIGGER_L value:(pressed?1.0:0.0)];
			};
						controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_FORWARD value:pressed?1.0:0];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:pressed?1.0:0];
                    [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::NUNCHUK_BUTTON_Z action:(pressed?1:0)];
                    [self gamepadEventOnPad:port
				 button:ciface::iOS::ButtonType::CLASSIC_TRIGGER_R
				 action:(pressed?1:0)];
                    [self gamepadMoveEventOnPad:gcPort axis:ciface::iOS::ButtonType::TRIGGER_R value:(pressed?1.0:0.0)];
			};
			controller.extendedGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_RIGHT action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_UP action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
					 button:ciface::iOS::ButtonType::CLASSIC_DPAD_UP
					 action:(pressed?1:0)];
					[self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_UP action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_UP action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_LEFT action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
					 button:ciface::iOS::ButtonType::CLASSIC_DPAD_LEFT
					 action:(pressed?1:0)];
					[self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_LEFT action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_DOWN action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_RIGHT action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
					 button:ciface::iOS::ButtonType::CLASSIC_DPAD_RIGHT
					 action:(pressed?1:0)];
					[self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_RIGHT action:(pressed?1:0)];
			};
			controller.extendedGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_LEFT action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_DOWN action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
                         button:ciface::iOS::ButtonType::CLASSIC_DPAD_DOWN
                         action:(pressed?1:0)];
					[self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_DOWN action:(pressed?1:0)];
			};
            controller.extendedGamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad* leftJoypad, float xValue, float yValue) {
                // Nunchuk stick controls (always active in Wii mode)
                [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:xValue];
                [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:xValue];
                [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:-yValue];
                [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:-yValue];

                // GameCube main stick (only in GameCube mode)
                if (!self.isWii) {
                    [self gamepadMoveEventOnPad:gcPort axis:11 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:12 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:13 value:CGFloat(xValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:14 value:CGFloat(xValue)];
                }
            };
            controller.extendedGamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad* rightJoypad, float xValue, float yValue) {
                // Wiimote motion controls (always active in Wii mode)
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_FORWARD value:xValue/adj];
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_BACKWARD value:xValue/adj];
                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_LEFT value:xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_RIGHT value:xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_UP value:-yValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_DOWN value:-yValue/adj];
                } else {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_RIGHT value:-xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_LEFT value:-xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_UP value:yValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_DOWN value:yValue/adj];
                }

                // GameCube C-stick (only in GameCube mode)
                if (!self.isWii) {
                    [self gamepadMoveEventOnPad:gcPort axis:16 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:17 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:18 value:CGFloat(xValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:19 value:CGFloat(xValue)];
                }
            };
            controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                ILOG(@"Rotating (opt) controls %d\n", rotateControls);
                [self rotate:pressed];
                // GC
                [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_START action:(pressed?1:0)];
            };
            controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_HOME
                    action:(pressed?1:0)];
//                [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER action:(pressed?1:0)];
                [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_START action:(pressed?1:0)];
                //GC
                [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_START
                 action:(pressed?1:0)];
            };
            controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                ILOG(@"Rotating (opt) controls %d\n", rotateControls);
                [self rotate:pressed];
            };
            controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_HOME
                    action:(pressed?1:0)];
//                [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER action:(pressed?1:0)];
                [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_START action:(pressed?1:0)];
            };
		} else if (controller.microGamepad != nil) {
            controller.microGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_1
                         action:(pressed?1:0)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadEventOnPad:port
                     button:ciface::iOS::ButtonType::CLASSIC_BUTTON_A
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_A
                     action:(pressed?1:0)];
            };
            controller.microGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port
                     button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_2
                     action:(pressed?1:0)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_X value:value];
                    [self gamepadEventOnPad:port
                     button:ciface::iOS::ButtonType::CLASSIC_BUTTON_X
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_X
                     action:(pressed?1:0)];
            };
            controller.microGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_RIGHT action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_UP action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
                     button:ciface::iOS::ButtonType::CLASSIC_DPAD_UP
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_UP action:(pressed?1:0)];
            };
            controller.microGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_UP action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_LEFT action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
                     button:ciface::iOS::ButtonType::CLASSIC_DPAD_LEFT
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_LEFT action:(pressed?1:0)];
            };
            controller.microGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_DOWN action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_RIGHT action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
                     button:ciface::iOS::ButtonType::CLASSIC_DPAD_RIGHT
                     action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_RIGHT action:(pressed?1:0)];
            };
            controller.microGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_LEFT action:(pressed?1:0)];
                    } else {
                        [self gamepadEventOnPad:port button:ciface::iOS::ButtonType::WIIMOTE_DOWN action:(pressed?1:0)];
                    }
                    [self gamepadEventOnPad:port
                         button:ciface::iOS::ButtonType::CLASSIC_DPAD_DOWN
                         action:(pressed?1:0)];
                    [self gamepadEventOnPad:gcPort button:ciface::iOS::ButtonType::BUTTON_DOWN action:(pressed?1:0)];
            };
		}
        if (self.multiPlayer) {
            port += 1;
            gcPort += 1;
        } else {
            port = 4;
            gcPort = 0;
        }
	}
}

- (void)rotate:(BOOL) pressed {
    rotateIr = pressed ? !rotateIr : rotateIr;
    rotateControls = pressed ? !rotateControls : rotateControls;
//    [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER action:(pressed?1:0)];
}

// pad == 4 is WiiMote, pad == 0 is GC (in both GC / Wii Modes)
- (void)gamepadEventOnPad:(int)pad button:(int)button action:(int)action
{
	// Convert action to boolean (1 = pressed, 0 = released)
	bool pressed = (action == 1);
	DLOG(@"🎮 gamepadEventOnPad: pad=%d, button=%d, action=%d, pressed=%s",
	      pad, button, action, pressed ? "YES" : "NO");
	ciface::iOS::StateManager::GetInstance()->SetButtonPressed(pad, static_cast<ciface::iOS::ButtonType>(button), pressed);
}

- (void)gamepadMoveEventOnPad:(int)pad axis:(int)axis value:(CGFloat)value
{
	ciface::iOS::StateManager::GetInstance()->SetAxisValue(pad, static_cast<ciface::iOS::ButtonType>(axis), value);
}

- (void)gamepadEventIrRecenter:(int)action
{
	// 4-8 are Wii Controllers
	for (int i = 4; i < 8; i++) {
	  NSLog(@"Received IR %d \n", action);
	  bool pressed = (action == 1);
//	  ciface::iOS::StateManager::GetInstance()->SetButtonPressed(i, ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER, pressed);
	}
}

-(void)didPushWiiButton:(PVWiiMoteButton)button forPlayer:(NSInteger)player {
	if(_isInitialized) {
		[self sendWiiButtonInput:(PVWiiMoteButton)button isPressed:true withValue:1.0
		 forPlayer:player];
	}
}

-(void)didReleaseWiiButton:(PVWiiMoteButton)button forPlayer:(NSInteger)player {
	if(_isInitialized) {
		[self sendWiiButtonInput:(PVWiiMoteButton)button isPressed:false withValue:0.0
		 forPlayer:player];
	}
}

- (void)didMoveWiiJoystickDirection:(PVWiiMoteButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    if(_isInitialized) {
        int port = 4;
        int gcPort = 0;
        switch (button) {
            case(PVWiiMoteButtonLeftAnalog):
                // Optional: IR cursor control from left joystick (can be disabled)
                if (!self.disableJoystickIRCursor) {
                    // Using IR axis numbers from WiimoteNew.ini: 112-117
                    [self gamepadMoveEventOnPad:port axis:116 value:xValue]; // IR Forward
                    [self gamepadMoveEventOnPad:port axis:117 value:xValue]; // IR Backward

                    if (!rotateIr) {
                        [self gamepadMoveEventOnPad:port axis:114 value:xValue]; // IR Left
                        [self gamepadMoveEventOnPad:port axis:115 value:xValue]; // IR Right
                    } else {
                        [self gamepadMoveEventOnPad:port axis:115 value:-xValue]; // IR Right
                        [self gamepadMoveEventOnPad:port axis:114 value:-xValue]; // IR Left
                    }
                    if (!rotateIr) {
                        [self gamepadMoveEventOnPad:port axis:113 value:-yValue]; // IR Down
                        [self gamepadMoveEventOnPad:port axis:112 value:-yValue]; // IR Up
                    } else {
                        [self gamepadMoveEventOnPad:port axis:112 value:yValue]; // IR Up
                        [self gamepadMoveEventOnPad:port axis:113 value:yValue]; // IR Down
                    }
                }

                // Always handle Nunchuk stick (unaffected by IR disable option)
                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:-yValue];
                } else {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:yValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:yValue];
                }
                // GC
                [self gamepadMoveEventOnPad:gcPort axis:11 value:CGFloat(-yValue)];
                [self gamepadMoveEventOnPad:gcPort axis:12 value:CGFloat(-yValue)];
                [self gamepadMoveEventOnPad:gcPort axis:13 value:CGFloat(xValue)];
                [self gamepadMoveEventOnPad:gcPort axis:14 value:CGFloat(xValue)];
                break;
            case(PVWiiMoteButtonRightAnalog):
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_FORWARD value:xValue/adj];
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_BACKWARD value:xValue/adj];
                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_LEFT value:xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_RIGHT value:xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_UP value:-yValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_DOWN value:-yValue/adj];
                } else {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_RIGHT value:-xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_LEFT value:-xValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_UP value:yValue/adj];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_DOWN value:yValue/adj];
                }
                // GC
                [self gamepadMoveEventOnPad:gcPort axis:16 value:CGFloat(-yValue)];
                [self gamepadMoveEventOnPad:gcPort axis:17 value:CGFloat(-yValue)];
                [self gamepadMoveEventOnPad:gcPort axis:18 value:CGFloat(xValue)];
                [self gamepadMoveEventOnPad:gcPort axis:19 value:CGFloat(xValue)];
                break;
        }
    }
}

-(void)didPushGameCubeButton:(NSInteger)button forPlayer:(NSInteger)player {
	if(_isInitialized) {
		[self sendGCButtonInput:(PVGCButton)button isPressed:true withValue:1.0
		 forPlayer:player];
	}
}

-(void)didReleaseGameCubeButton:(NSInteger)button forPlayer:(NSInteger)player {
	if(_isInitialized) {
		[self sendGCButtonInput:(PVGCButton)button isPressed:false withValue:0.0
		 forPlayer:player];
	}
}

- (void)didMoveGameCubeJoystickDirection:(NSInteger)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    if(_isInitialized) {
            int port = 4;
            int gcPort = 0;
            switch (button) {
                case(PVGCLeftAnalog):
                    // GC
                    [self gamepadMoveEventOnPad:gcPort axis:11 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:12 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:13 value:CGFloat(xValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:14 value:CGFloat(xValue)];
                    break;
                case(PVGCRightAnalog):
                    // GC
                    [self gamepadMoveEventOnPad:gcPort axis:16 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:17 value:CGFloat(-yValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:18 value:CGFloat(xValue)];
                    [self gamepadMoveEventOnPad:gcPort axis:19 value:CGFloat(xValue)];
                    break;
            }
    }
}

-(void)didMoveJoystick:(NSInteger)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
	[self didMoveWiiJoystickDirection:(PVWiiMoteButton)button withXValue:xValue withYValue: yValue forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
	[self didPushWiiButton:(PVWiiMoteButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
	[self didReleaseWiiButton:(PVWiiMoteButton)button forPlayer:player];
}

-(void)sendWiiButtonInput:(enum PVWiiMoteButton)button isPressed:(bool)pressed withValue:(CGFloat)value forPlayer:(NSInteger)player {
	switch (button) {
        case(PVWiiMoteButtonSelect):
            [self rotate:pressed];
            ILOG(@"Rotating Controls %d\n", rotateControls);
            break;
        case(PVWiiMoteButtonStart):
            [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_START
             action:(pressed?1:0)];
            break;
		case(PVWiiMoteButtonWiiHome):
//            [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER
//             action:(pressed?1:0)];
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_HOME
             action:(pressed?1:0)];
			break;
		case(PVWiiMoteButtonWiiDPadLeft):
            // Don't also send nunchuck, why was this here?
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_LEFT value:-value];
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_RIGHT value:-value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_UP
                 action:(pressed?1:0)];
            else
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_LEFT
                 action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_LEFT
                 action:(pressed?1:0)];
            }
			break;
		case(PVWiiMoteButtonWiiDPadRight):
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_RIGHT value:value];
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_LEFT value:value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_DOWN
                 action:(pressed?1:0)];
            else
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_RIGHT
                 action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_RIGHT
                 action:(pressed?1:0)];
            }
			break;
		case(PVWiiMoteButtonWiiDPadUp):
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_UP value:-value];
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_DOWN value:-value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_RIGHT
                 action:(pressed?1:0)];
            else
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_UP
                 action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_UP
                 action:(pressed?1:0)];
            }
			break;
		case(PVWiiMoteButtonWiiDPadDown):
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_UP value:value];
//            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_DOWN value:value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_LEFT
                    action:(pressed?1:0)];
            else
                [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_DOWN
                 action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_DOWN
                 action:(pressed?1:0)];
            }
			break;
		case(PVWiiMoteButtonWiiA):
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_A
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_A
                 action:(pressed?1:0)];
            }
			break;
		case(PVWiiMoteButtonWiiB):
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_B
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_B
                 action:(pressed?1:0)];
            }
			break;
		case(PVWiiMoteButtonWiiOne):
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_1
             action:(pressed?1:0)];
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Z value:value];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_Y
                 action:(pressed?1:0)];
            }
            break;
        case(PVWiiMoteButtonWiiTwo):
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_X value:value];
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Y value:value];
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Z value:value];
            [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_2
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_X
                 action:(pressed?1:0)];
            }
            break;
		case(PVWiiMoteButtonWiiPlus):
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Z value:value];
            [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_PLUS
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadMoveEventOnPad:0 axis:ciface::iOS::ButtonType::TRIGGER_L value:(pressed?1.0:0.0)];
            }
			break;
		case(PVWiiMoteButtonWiiMinus):
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_X value:value];
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Y value:value];
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_MINUS
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadMoveEventOnPad:0 axis:ciface::iOS::ButtonType::TRIGGER_R value:(pressed?1.0:0.0)];
            }
			break;
		case(PVWiiMoteButtonNunchukC):
		[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::NUNCHUK_BUTTON_C
             action:(pressed?1:0)];
        // Only send to GameCube controller if we're not in Wii mode
        if (!self.isWii) {
            [self gamepadMoveEventOnPad:0 axis:ciface::iOS::ButtonType::TRIGGER_R value:(pressed?1.0:0.0)];
        }
			break;
		case(PVWiiMoteButtonNunchukZ):
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SWING_FORWARD value:value];
//            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Y value:value];
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::NUNCHUK_BUTTON_Z
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_Z
                 action:(pressed?1:0)];
            }
			break;
		default:
            WLOG(@"Unhandled Wii button %i player: %i, value: %f", button, player, value);
//            [self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_IR_RECENTER
//             action:(pressed?1:0)];
			[self gamepadEventOnPad:4 button:ciface::iOS::ButtonType::WIIMOTE_BUTTON_HOME
             action:(pressed?1:0)];
            // Only send to GameCube controller if we're not in Wii mode
            if (!self.isWii) {
                [self gamepadEventOnPad:0 button:ciface::iOS::ButtonType::BUTTON_START
                 action:(pressed?1:0)];
            }
			break;
	}
}


-(void)sendGCButtonInput:(enum PVGCButton)button isPressed:(bool)pressed withValue:(CGFloat)value forPlayer:(NSInteger)player {
	DLOG(@"🎮 sendGCButtonInput: button=%d, pressed=%s", (int)button, pressed ? "YES" : "NO");

	switch (button) {
			case(PVGCButtonStart):
		[self gamepadEventOnPad:0 button:BUTTON_START action:(pressed?1:0)];
		break;
        case(PVGCButtonCUp):
            [self gamepadMoveEventOnPad:0 axis:STICK_C_UP value:-value];
            [self gamepadMoveEventOnPad:0 axis:STICK_C_DOWN value:-value];
            break;
        case(PVGCButtonCDown):
            [self gamepadMoveEventOnPad:0 axis:STICK_C_UP value:value];
            [self gamepadMoveEventOnPad:0 axis:STICK_C_DOWN value:value];
            break;
        case(PVGCButtonCLeft):
            [self gamepadMoveEventOnPad:0 axis:STICK_C_LEFT value:-value];
            [self gamepadMoveEventOnPad:0 axis:STICK_C_RIGHT value:-value];
            break;
        case(PVGCButtonCRight):
            [self gamepadMoveEventOnPad:0 axis:STICK_C_LEFT value:value];
            [self gamepadMoveEventOnPad:0 axis:STICK_C_RIGHT value:value];
            break;
			case(PVGCButtonLeft):
		[self gamepadEventOnPad:0 button:BUTTON_LEFT action:(pressed?1:0)];
		break;
	case(PVGCButtonRight):
		[self gamepadEventOnPad:0 button:BUTTON_RIGHT action:(pressed?1:0)];
		break;
	case(PVGCButtonUp):
		[self gamepadEventOnPad:0 button:BUTTON_UP action:(pressed?1:0)];
		break;
	case(PVGCButtonDown):
		[self gamepadEventOnPad:0 button:BUTTON_DOWN action:(pressed?1:0)];
		break;
		case(PVGCAnalogUp):
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_UP value:-value];
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_DOWN value:-value];
			break;
		case(PVGCAnalogDown):
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_UP value:value];
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_DOWN value:value];
			break;
		case(PVGCAnalogLeft):
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_LEFT value:-value];
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_RIGHT value:-value];
			break;
		case(PVGCAnalogRight):
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_LEFT value:value];
            [self gamepadMoveEventOnPad:0 axis:STICK_MAIN_RIGHT value:value];
			break;
			case(PVGCButtonZ):
		DLOG(@"🎮 Hit PVGCButtonZ case - calling BUTTON_Z");
		[self gamepadEventOnPad:0 button:BUTTON_Z action:(pressed?1:0)];
		break;
	case(PVGCButtonL):
            DLOG(@"🎮 Hit PVGCButtonL case - calling TRIGGER_L");
		[self gamepadMoveEventOnPad:0 axis:TRIGGER_L value:value];
		break;
	case(PVGCButtonR):
            DLOG(@"🎮 Hit PVGCButtonR case - calling TRIGGER_R");
		[self gamepadMoveEventOnPad:0 axis:TRIGGER_R value:value];
		break;
			case(PVGCButtonX):
		[self gamepadEventOnPad:0 button:BUTTON_X action:(pressed?1:0)];
		break;
	case(PVGCButtonY):
		[self gamepadEventOnPad:0 button:BUTTON_Y action:(pressed?1:0)];
		break;
	case(PVGCButtonA):
		NSLog(@"🎮 Hit PVGCButtonA case - calling BUTTON_A");
		[self gamepadEventOnPad:0 button:BUTTON_A action:(pressed?1:0)];
		break;
	case(PVGCButtonB):
		[self gamepadEventOnPad:0 button:BUTTON_B action:(pressed?1:0)];
		break;

		default:
			WLOG(@"🎮 Hit DEFAULT case - button %d not handled", (int)button);
			break;
	}
}

// Required ini file for the Button Manager WiiMote is at 4-8 port
-(void) writeWiiIniFile {
	NSString *fileName = [NSString stringWithFormat:@"%@/../DolphinData/Config/WiimoteNew.ini",
						  self.batterySavesPath];
    NSString *content = @"";
    if (self.multiPlayer) {
        int wiiPort = 1;
        for (NSInteger player = 0; player < 4; player++) {
            GCController *controller = nil;
            if (self.controller1 && player == 0) {
                controller = self.controller1;
            } else if (self.controller2 && player == 1) {
                controller = self.controller2;
            } else if (self.controller3 && player == 2) {
                controller = self.controller3;
            } else if (self.controller4 && player == 3) {
                controller = self.controller4;
            }
            content = [content stringByAppendingString:[self getWiiTouchpadConfig:wiiPort wiiMotePort:(wiiPort + 3) source:(controller != nil) ? 1:0]];
            wiiPort += 1;
        }
    } else {
        content = [content stringByAppendingString:[self getWiiTouchpadConfig:1 wiiMotePort:4 source:1]];
    }
    ILOG(@"Config File: %s\n%s\n", fileName.UTF8String, content.UTF8String);
    ILOG(@"🎮 Writing Wii config with iOS device source");
	[content writeToFile:fileName
	   atomically:NO
	   encoding:NSStringEncodingConversionAllowLossy
	   error:nil];
}

-(NSString *)getWiiTouchpadConfig:(int)port wiiMotePort:(int)wiiMotePort source:(int)source {
    NSString *content = [NSString stringWithFormat:
     @"[Wiimote%d]\n"
     @"Device = iOS/%d/Touchscreen\n"
     @"Buttons/A = `Button 100`\n"
     @"Buttons/B = `Button 101`\n"
     @"Buttons/- = `Button 102`\n"
     @"Buttons/+ = `Button 103`\n"
     @"Buttons/Home = `Button 104`\n"
     @"Buttons/1 = `Button 105`\n"
     @"Buttons/2 = `Button 106`\n"
     @"D-Pad/Up = `Button 107`\n"
     @"D-Pad/Down = `Button 108`\n"
     @"D-Pad/Left = `Button 109`\n"
     @"D-Pad/Right = `Button 110`\n"
     @"IR/Up = `Axis 112`\n"
     @"IR/Down = `Axis 113`\n"
     @"IR/Left = `Axis 114`\n"
     @"IR/Right = `Axis 115`\n"
     @"IR/Forward = `Axis 116`\n"
     @"IR/Backward = `Axis 117`\n"
     @"IR/Hide = `Button 118`\n"
     @"IR/Total Pitch = 15.000000000000000\n"
     @"IR/Total Yaw = 15.000000000000000\n"
     @"Swing/Up = `Axis 120`\n"
     @"Swing/Down = `Axis 121`\n"
     @"Swing/Left = `Axis 122`\n"
     @"Swing/Right = `Axis 123`\n"
     @"Swing/Forward = `Axis 124`\n"
     @"Swing/Backward = `Axis 125`\n"
     @"Tilt/Forward = `Axis 127`\n"
     @"Tilt/Backward = `Axis 128`\n"
     @"Tilt/Left = `Axis 129`\n"
     @"Tilt/Right = `Axis 130`\n"
     @"Tilt/Modifier = `Button 131`\n"
     @"Tilt/Modifier/Range = 50.000000000000000\n"
     @"Shake/X = `Button 132`\n"
     @"Shake/Y = `Button 133`\n"
     @"Shake/Z = `Button 134`\n"
     @"Nunchuk/Buttons/C = `Button 200`\n"
     @"Nunchuk/Buttons/Z = `Button 201`\n"
     @"Nunchuk/Stick/Up = `Axis 203`\n"
     @"Nunchuk/Stick/Down = `Axis 204`\n"
     @"Nunchuk/Stick/Left = `Axis 205`\n"
     @"Nunchuk/Stick/Right = `Axis 206`\n"
     @"Nunchuk/Swing/Up = `Axis 208`\n"
     @"Nunchuk/Swing/Down = `Axis 209`\n"
     @"Nunchuk/Swing/Left = `Axis 210`\n"
     @"Nunchuk/Swing/Right = `Axis 211`\n"
     @"Nunchuk/Swing/Forward = `Axis 212`\n"
     @"Nunchuk/Swing/Backward = `Axis 213`\n"
     @"Nunchuk/Tilt/Forward = `Axis 215`\n"
     @"Nunchuk/Tilt/Backward = `Axis 216`\n"
     @"Nunchuk/Tilt/Left = `Axis 217`\n"
     @"Nunchuk/Tilt/Right = `Axis 218`\n"
     @"Nunchuk/Tilt/Modifier = `Button 219`\n"
     @"Nunchuk/Tilt/Modifier/Range = 50.000000000000000\n"
     @"Nunchuk/Shake/X = `Button 220`\n"
     @"Nunchuk/Shake/Y = `Button 221`\n"
     @"Nunchuk/Shake/Z = `Button 222`\n"
     @"Classic/Buttons/A = `Button 300`\n"
     @"Classic/Buttons/B = `Button 301`\n"
     @"Classic/Buttons/X = `Button 302`\n"
     @"Classic/Buttons/Y = `Button 303`\n"
     @"Classic/Buttons/- = `Button 304`\n"
     @"Classic/Buttons/+ = `Button 305`\n"
     @"Classic/Buttons/Home = `Button 306`\n"
     @"Classic/Buttons/ZL = `Button 307`\n"
     @"Classic/Buttons/ZR = `Button 308`\n"
     @"Classic/D-Pad/Up = `Button 309`\n"
     @"Classic/D-Pad/Down = `Button 310`\n"
     @"Classic/D-Pad/Left = `Button 311`\n"
     @"Classic/D-Pad/Right = `Button 312`\n"
     @"Classic/Left Stick/Up = `Axis 314`\n"
     @"Classic/Left Stick/Down = `Axis 315`\n"
     @"Classic/Left Stick/Left = `Axis 316`\n"
     @"Classic/Left Stick/Right = `Axis 317`\n"
     @"Classic/Right Stick/Up = `Axis 319`\n"
     @"Classic/Right Stick/Down = `Axis 320`\n"
     @"Classic/Right Stick/Left = `Axis 321`\n"
     @"Classic/Right Stick/Right = `Axis 322`\n"
     @"Classic/Triggers/L = `Axis 323`\n"
     @"Classic/Triggers/R = `Axis 324`\n"
     @"Guitar/Buttons/- = `Button 400`\n"
     @"Guitar/Buttons/+ = `Button 401`\n"
     @"Guitar/Frets/Green = `Button 402`\n"
     @"Guitar/Frets/Red = `Button 403`\n"
     @"Guitar/Frets/Yellow = `Button 404`\n"
     @"Guitar/Frets/Blue = `Button 405`\n"
     @"Guitar/Frets/Orange = `Button 406`\n"
     @"Guitar/Strum/Up = `Button 407`\n"
     @"Guitar/Strum/Down = `Button 408`\n"
     @"Guitar/Stick/Up = `Axis 410`\n"
     @"Guitar/Stick/Down = `Axis 411`\n"
     @"Guitar/Stick/Left = `Axis 412`\n"
     @"Guitar/Stick/Right = `Axis 413`\n"
     @"Guitar/Whammy/Bar = `Axis 414`\n"
     @"Drums/Buttons/- = `Button 500`\n"
     @"Drums/Buttons/+ = `Button 501`\n"
     @"Drums/Pads/Red = `Button 502`\n"
     @"Drums/Pads/Yellow = `Button 503`\n"
     @"Drums/Pads/Blue = `Button 504`\n"
     @"Drums/Pads/Green = `Button 505`\n"
     @"Drums/Pads/Orange = `Button 506`\n"
     @"Drums/Pads/Bass = `Button 507`\n"
     @"Drums/Stick/Up = `Axis 509`\n"
     @"Drums/Stick/Down = `Axis 510`\n"
     @"Drums/Stick/Left = `Axis 511`\n"
     @"Drums/Stick/Right = `Axis 512`\n"
     @"Turntable/Buttons/Green Left = `Button 600`\n"
     @"Turntable/Buttons/Red Left = `Button 601`\n"
     @"Turntable/Buttons/Blue Left = `Button 602`\n"
     @"Turntable/Buttons/Green Right = `Button 603`\n"
     @"Turntable/Buttons/Red Right = `Button 604`\n"
     @"Turntable/Buttons/Blue Right = `Button 605`\n"
     @"Turntable/Buttons/- = `Button 606`\n"
     @"Turntable/Buttons/+ = `Button 607`\n"
     @"Turntable/Buttons/Home = `Button 608`\n"
     @"Turntable/Buttons/Euphoria = `Button 609`\n"
     @"Turntable/Table Left/Left = `Axis 611`\n"
     @"Turntable/Table Left/Right = `Axis 612`\n"
     @"Turntable/Table Right/Left = `Axis 614`\n"
     @"Turntable/Table Right/Right = `Axis 615`\n"
     @"Turntable/Stick/Up = `Axis 617`\n"
     @"Turntable/Stick/Down = `Axis 618`\n"
     @"Turntable/Stick/Left = `Axis 619`\n"
     @"Turntable/Stick/Right = `Axis 620`\n"
     @"Turntable/Effect/Dial = `Axis 621`\n"
     @"Turntable/Crossfade/Left = `Axis 623`\n"
     @"Turntable/Crossfade/Right = `Axis 624`\n"
     @"IMUAccelerometer/Left = `Axis 625`\n"
     @"IMUAccelerometer/Right = `Axis 626`\n"
     @"IMUAccelerometer/Forward = `Axis 627`\n"
     @"IMUAccelerometer/Backward = `Axis 628`\n"
     @"IMUAccelerometer/Up = `Axis 629`\n"
     @"IMUAccelerometer/Down = `Axis 630`\n"
     @"IMUGyroscope/Pitch Up = `Axis 631`\n"
     @"IMUGyroscope/Pitch Down = `Axis 632`\n"
     @"IMUGyroscope/Roll Left = `Axis 633`\n"
     @"IMUGyroscope/Roll Right = `Axis 634`\n"
     @"IMUGyroscope/Yaw Left = `Axis 635`\n"
     @"IMUGyroscope/Yaw Right = `Axis 636`\n"
     @"IMUIR/Recenter = `Button 800`\n"
     @"Rumble/Motor = `Rumble 700`\n"
     @"Nunchuk/Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
     @"Classic/Left Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
     @"Classic/Right Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
     @"Guitar/Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
     @"Drums/Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
     @"Turntable/Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
     @"IMUIR/Enabled = True\n"
     @"Extension = Nunchuk\n"
     @"Extension/Attach MotionPlus = `Attached MotionPlus`\n"
     @"Source = %d\n",
     port, wiiMotePort, source];
    return content;
}

-(NSString *)getWiiMFIConfig:(int)port wiiMotePort:(int)wiiMotePort name:(NSString*)name source:(int)source {
    NSString *content = [NSString stringWithFormat:
    @"[Wiimote%d]\n"
    @"Device = MFi/%d/%s\n"
    @"Buttons/A = `Button B`\n"
    @"Buttons/B = `Button Y`\n"
    @"Buttons/1 = `Button A`\n"
    @"Buttons/2 = `Button X`\n"
    @"Buttons/+ = `L Trigger`\n"
    @"Buttons/- = `R Trigger`\n"
    @"Buttons/Home = `L Stick Button`\n"
    @"D-Pad/Up = `D-Pad Up`\n"
    @"D-Pad/Down = `D-Pad Down`\n"
    @"D-Pad/Left = `D-Pad Left`\n"
    @"D-Pad/Right = `D-Pad Right`\n"
    @"IR/Forward = `Axis 116`\n"
    @"IR/Backward = `Axis 117`\n"
    @"IR/Total Pitch = 15.000000000000000\n"
    @"IR/Total Yaw = 15.000000000000000\n"
    @"Extension = Nunchuk\n"
    @"Nunchuk/Buttons/C = `L Shoulder`\n"
    @"Nunchuk/Buttons/Z = `R Shoulder`\n"
    @"Nunchuk/Stick/Up = `L Stick Y+`\n"
    @"Nunchuk/Stick/Down = `L Stick Y-`\n"
    @"Nunchuk/Stick/Left = `L Stick X-`\n"
    @"Nunchuk/Stick/Right = `L Stick X+`\n"
    @"Turntable/Buttons/Home = `Button 608`\n"
    @"Turntable/Effect/Dial = `Axis 621`\n"
    @"IMUAccelerometer/Left = `Accel Left`\n"
    @"IMUAccelerometer/Right = `Accel Right`\n"
    @"IMUAccelerometer/Forward = `Accel Forward`\n"
    @"IMUAccelerometer/Backward = `Accel Back`\n"
    @"IMUAccelerometer/Up = `Accel Up`\n"
    @"IMUAccelerometer/Down = `Accel Down`\n"
    @"IMUGyroscope/Pitch Up = `Gyro Pitch Up`\n"
    @"IMUGyroscope/Pitch Down = `Gyro Pitch Down`\n"
    @"IMUGyroscope/Roll Left = `Gyro Roll Left`\n"
    @"IMUGyroscope/Roll Right = `Gyro Roll Right`\n"
    @"IMUGyroscope/Yaw Left = `Gyro Yaw Left`\n"
    @"IMUGyroscope/Yaw Right = `Gyro Yaw Right`\n"
    @"Source = %d\n",
    port, wiiMotePort, name.UTF8String, source];
    return content;
}
// Required ini file for the Button Manager GC is at 0-3 port
-(void) writeGCIniFile {
	NSString *fileName = [NSString stringWithFormat:@"%@/../DolphinData/Config/GCPadNew.ini",
						  self.batterySavesPath];
    NSString *content = @"";
    if (self.multiPlayer) {
        int port = 1;
        for (NSInteger player = 0; player < 4; player++) {
            GCController *controller = nil;
            if (self.controller1 && player == 0) {
                controller = self.controller1;
            } else if (self.controller2 && player == 1) {
                controller = self.controller2;
            } else if (self.controller3 && player == 2) {
                controller = self.controller3;
            } else if (self.controller4 && player == 3) {
                controller = self.controller4;
            }
            content = [content stringByAppendingString:[self getGCTouchConfig:port gcPort:(port - 1) source:1]];
                    Config::SetBase(Config::GetInfoForSIDevice(port - 1), SerialInterface::SIDEVICE_GC_CONTROLLER);
        Core::System::GetInstance().GetSerialInterface().ChangeDevice(SerialInterface::SIDEVICE_GC_CONTROLLER, port - 1);
            port += 1;
        }
    } else {
        content = [self getGCTouchConfig:1 gcPort:0 source:1];
    }
    ILOG(@"Config File: %s\n%s\n", fileName.UTF8String, content.UTF8String);
    ILOG(@"🎮 Writing GC config with iOS device source");
    [content writeToFile:fileName
       atomically:NO
       encoding:NSStringEncodingConversionAllowLossy
       error:nil];
}

-(NSString *)getGCTouchConfig:(int)port gcPort:(int)gcPort source:(int)source {
    NSString *content = [NSString stringWithFormat:
    @"[GCPad%d]\n"
    @"Device = iOS/%d/Touchscreen\n"
    @"Buttons/A = `Button 0`\n"
    @"Buttons/B = `Button 1`\n"
    @"Buttons/Start = `Button 2`\n"
    @"Buttons/X = `Button 3`\n"
    @"Buttons/Y = `Button 4`\n"
    @"Buttons/Z = `Button 5`\n"
    @"D-Pad/Up = `Button 6`\n"
    @"D-Pad/Down = `Button 7`\n"
    @"D-Pad/Left = `Button 8`\n"
    @"D-Pad/Right = `Button 9`\n"
    @"Main Stick/Up = `Axis 11`\n"
    @"Main Stick/Down = `Axis 12`\n"
    @"Main Stick/Left = `Axis 13`\n"
    @"Main Stick/Right = `Axis 14`\n"
    @"C-Stick/Up = `Axis 16`\n"
    @"C-Stick/Down = `Axis 17`\n"
    @"C-Stick/Left = `Axis 18`\n"
    @"C-Stick/Right = `Axis 19`\n"
    @"Triggers/L = `Axis 20`\n"
    @"Triggers/R = `Axis 21`\n"
    @"Triggers/L-Analog = `Axis 20`\n"
    @"Triggers/R-Analog = `Axis 21`\n"
    @"Rumble/Motor = `Rumble 700`\n"
    @"Main Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
    @"C-Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42\n"
    @"Source = %d\n",
    port, gcPort, source];
    return content;
}

-(NSString *)getGCMFIConfig:(int)port gcPort:(int)gcPort name:(NSString*)name source:(int)source {
    NSString *content = [NSString stringWithFormat:
    @"[GCPad%d]\n"
    @"Device = MFi/%d/%s\n"
    @"Buttons/A = `Button A`\n"
    @"Buttons/B = `Button B`\n"
    @"Buttons/Start = `L Shoulder`\n"
    @"Buttons/X = `Button X`\n"
    @"Buttons/Y = `Button Y`\n"
    @"Buttons/Z = `R Shoulder`\n"
    @"D-Pad/Up = `D-Pad Up`\n"
    @"D-Pad/Down = `D-Pad Down`\n"
    @"D-Pad/Left = `D-Pad Left`\n"
    @"D-Pad/Right = `D-Pad Right`\n"
    @"Main Stick/Up = `L Stick Y+`\n"
    @"Main Stick/Down = `L Stick Y-`\n"
    @"Main Stick/Left = `L Stick X-`\n"
    @"Main Stick/Right = `L Stick X+`\n"
    @"C-Stick/Up = `R Stick Y+`\n"
    @"C-Stick/Down = `R Stick Y-`\n"
    @"C-Stick/Left = `R Stick X-`\n"
    @"C-Stick/Right = `R Stick X+`\n"
    @"Triggers/L-Analog = `L Trigger`\n"
    @"Triggers/R-Analog = `R Trigger`\n"
    @"Source = %d\n",
    port, gcPort, name.UTF8String, source];
    return content;
}

#pragma mark - Touch Screen Support for Wii IR Cursor

/// Touch screen support for Wii IR cursor positioning
/// This replaces the previous joystick-based IR control system which caused conflicts.
/// Only active in Wii mode - GameCube mode uses joysticks normally.
///
/// Touch coordinates are mapped to IR cursor axes:
/// - Screen center = IR cursor center
/// - Touch position = IR cursor position
/// - Supports rotation via rotateIr flag
/// - Cursor resets to center when touch ends

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player {
    if (!self.isWii || !_isInitialized) return;

    UITouch *touch = [touches anyObject];
    if (!touch) return;

    UIView *view = touch.view;
    CGPoint location = [touch locationInView:view];
    [self updateIRCursorWithLocation:location inView:view forPlayer:player];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player {
    if (!self.isWii || !_isInitialized) return;

    UITouch *touch = [touches anyObject];
    if (!touch) return;

    UIView *view = touch.view;
    CGPoint location = [touch locationInView:view];
    [self updateIRCursorWithLocation:location inView:view forPlayer:player];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player {
    if (!self.isWii || !_isInitialized) return;

    // Reset IR cursor to center when touch ends
    [self resetIRCursorForPlayer:player];
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player {
    if (!self.isWii || !_isInitialized) return;

    // Reset IR cursor to center when touch is cancelled
    [self resetIRCursorForPlayer:player];
}

-(void)updateIRCursorWithLocation:(CGPoint)location inView:(UIView*)view forPlayer:(NSInteger)player {
    if (!view) return;

    // Convert touch coordinates to normalized [-1.0, 1.0] range
    // Origin (0,0) is top-left, we want center to be (0,0)
    float normalizedX = (location.x / view.bounds.size.width) * 2.0f - 1.0f;
    float normalizedY = (location.y / view.bounds.size.height) * 2.0f - 1.0f;

    // Clamp to valid range
    normalizedX = fmaxf(-1.0f, fminf(1.0f, normalizedX));
    normalizedY = fmaxf(-1.0f, fminf(1.0f, normalizedY));

    // Apply rotation if enabled
    if (rotateIr) {
        float temp = normalizedX;
        normalizedX = normalizedY;
        normalizedY = -temp;
    }

    // Map to Dolphin IR axes (pad 4 is Wiimote controller)
    int port = 4 + (self.multiPlayer ? player : 0);

    // Set IR cursor position - positive values for right/down, negative for left/up
    // Using axis numbers from WiimoteNew.ini: IR/Left=114, IR/Right=115, IR/Up=112, IR/Down=113
    [self gamepadMoveEventOnPad:port axis:114 value:normalizedX < 0 ? -normalizedX : 0]; // IR Left
    [self gamepadMoveEventOnPad:port axis:115 value:normalizedX > 0 ? normalizedX : 0]; // IR Right
    [self gamepadMoveEventOnPad:port axis:112 value:normalizedY < 0 ? -normalizedY : 0]; // IR Up
    [self gamepadMoveEventOnPad:port axis:113 value:normalizedY > 0 ? normalizedY : 0]; // IR Down

    NSLog(@"🎯 Touch IR: x=%.2f, y=%.2f -> normalizedX=%.2f, normalizedY=%.2f",
          location.x, location.y, normalizedX, normalizedY);
}

-(void)resetIRCursorForPlayer:(NSInteger)player {
    // Reset all IR axes to center (0.0)
    // Using axis numbers from WiimoteNew.ini: IR/Left=114, IR/Right=115, IR/Up=112, IR/Down=113
    int port = 4 + (self.multiPlayer ? player : 0);
    [self gamepadMoveEventOnPad:port axis:114 value:0.0f]; // IR Left
    [self gamepadMoveEventOnPad:port axis:115 value:0.0f]; // IR Right
    [self gamepadMoveEventOnPad:port axis:112 value:0.0f]; // IR Up
    [self gamepadMoveEventOnPad:port axis:113 value:0.0f]; // IR Down
}

#pragma mark - Haptic Feedback Setup

/// Sets up haptic feedback for Dolphin rumble
/// The iOS touchscreen devices created by StateManager automatically include
/// Motor outputs if the device supports CoreHaptics. This method just logs status.
-(void)setupHapticFeedback {
    // Check if haptic feedback is enabled by user
    if (!self.enableHapticFeedback) {
        ILOG(@"🎮 Haptic feedback disabled by user setting");
        Config::SetBase(Config::SYSCONF_WIIMOTE_MOTOR, false);
        return;
    }

    // Check if device supports haptics
    if ([[CHHapticEngine capabilitiesForHardware] supportsHaptics]) {
        ILOG(@"🎮 Haptic feedback enabled - device supports CoreHaptics");
        Config::SetBase(Config::SYSCONF_WIIMOTE_MOTOR, true);
    } else {
        NSLog(@"🎮 Device does not support haptics - rumble disabled");
        Config::SetBase(Config::SYSCONF_WIIMOTE_MOTOR, false);
    }
}

#pragma mark - Gyro Motion Controls Setup

// Shared CoreMotion manager instance for gyro controls
#if !TARGET_OS_TV
static CMMotionManager *g_motionManager = nil;

/// Get or create the shared motion manager instance
+(CMMotionManager*)sharedMotionManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_motionManager = [[CMMotionManager alloc] init];
    });
    return g_motionManager;
}
#endif

/// Sets up iPhone/iPad gyroscope for Wii motion controls
/// Maps device rotation to Wiimote gyro axes for natural motion control
-(void)setupGyroMotionControls {
    // Check if any motion features are enabled
    BOOL fullMotionEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_enable_full_6dof"];
    BOOL enhancedShakeEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_enhanced_shake_detection"];
    BOOL gyroIRMode = YES; //(DOLConfigBridge.mainTouchPadIRMode == 0); // TouchIRMode.gyro = 0

    if (!self.enableGyroMotionControls && !gyroIRMode && !fullMotionEnabled && !enhancedShakeEnabled) {
        ILOG(@"🎮 All motion controls disabled by user setting");
        return;
    }

    // Check if device supports motion
#if !TARGET_OS_TV
    CMMotionManager *motionManager = [[self class] sharedMotionManager];
    if (![motionManager isDeviceMotionAvailable]) {
        ILOG(@"🎮 Device does not support motion - gyro controls disabled");
        return;
    }
#endif

    // Log which motion features are active
    NSMutableArray *activeFeatures = [[NSMutableArray alloc] init];
    if (self.enableGyroMotionControls) [activeFeatures addObject:@"Wiimote Motion"];
    if (gyroIRMode) [activeFeatures addObject:@"IR Cursor"];
    if (fullMotionEnabled) [activeFeatures addObject:@"6DOF Motion"];
    if (enhancedShakeEnabled) [activeFeatures addObject:@"Enhanced Shake"];

    ILOG(@"🎮 Setting up motion controls: %@", [activeFeatures componentsJoinedByString:@", "]);

    // Listen for motion settings changes during gameplay
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleMotionSettingsChanged:)
                                                 name:@"DOLMotionSettingsChanged"
                                               object:nil];

    // Listen for IR cursor reset requests
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleResetIRCursor:)
                                                 name:@"DOLResetIRCursor"
                                               object:nil];

    // Initialize motion manager in the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        // Reset cursor to center before starting motion updates
        [self resetIRCursorForPlayer:0];
        [self startMotionUpdates];
    });
}

/// Start CoreMotion updates for gyro input
/// Now uses TCDeviceMotion as the unified motion system

-(void)startMotionUpdates {
    // Check if any motion features are enabled
    BOOL fullMotionEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_enable_full_6dof"];
    BOOL enhancedShakeEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_enhanced_shake_detection"];
    BOOL gyroIRMode = YES; // (DOLConfigBridge.mainTouchPadIRMode == 0); // TouchIRMode.gyro = 0

    if (!self.enableGyroMotionControls && !gyroIRMode && !fullMotionEnabled && !enhancedShakeEnabled) {
        return;
    }

    // Use TCDeviceMotion as the unified motion system (handles all enhanced features)
    NSMutableArray *activeFeatures = [[NSMutableArray alloc] init];
    if (self.enableGyroMotionControls) [activeFeatures addObject:@"Gyro Controls"];
    if (gyroIRMode) [activeFeatures addObject:@"IR Cursor"];
    if (fullMotionEnabled) [activeFeatures addObject:@"6DOF Motion"];
    if (enhancedShakeEnabled) [activeFeatures addObject:@"Enhanced Shake"];

    ILOG(@"🎮 Enabling motion controls via TCDeviceMotion - Features: %@", [activeFeatures componentsJoinedByString:@", "]);

//    [[TCDeviceMotion shared] setMotionEnabled:YES];
}

/// Stop CoreMotion updates to save battery
-(void)stopMotionUpdates {
//    [[TCDeviceMotion shared] setMotionEnabled:NO];
    NSLog(@"🎮 Motion controls stopped via TCDeviceMotion");

    // Remove notification observer when stopping motion updates
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                     name:@"DOLMotionSettingsChanged"
                                                   object:nil];
}

/// Update Wiimote gyro axes from device motion (for motion sensing games)
/// Maps device tilt to gyro controls: left/right tilt → roll, forward/back tilt → pitch
/// Using axis numbers from WiimoteNew.ini: IMUGyroscope entries (631-636)
#if !TARGET_OS_TV
-(void)updateWiimoteGyroFromMotion:(CMDeviceMotion*)motion {
    const double deadZone = 0.1; // Prevent drift when device is still
    const double sensitivity = 1.5; // Adjust sensitivity as needed

    // Roll: Tilt left/right → Wiimote gyro roll
    // Positive roll = tilt right, Negative roll = tilt left
    // IMUGyroscope/Roll Left = Axis 633, IMUGyroscope/Roll Right = Axis 634
    double roll = motion.attitude.roll; // Radians
    if (roll > deadZone) {
        [self gamepadMoveEventOnPad:4 axis:634 value:MIN(roll * sensitivity, 1.0)]; // Roll Right
        [self gamepadMoveEventOnPad:4 axis:633 value:0.0]; // Roll Left
    } else if (roll < -deadZone) {
        [self gamepadMoveEventOnPad:4 axis:633 value:MIN(-roll * sensitivity, 1.0)]; // Roll Left
        [self gamepadMoveEventOnPad:4 axis:634 value:0.0]; // Roll Right
    } else {
        [self gamepadMoveEventOnPad:4 axis:633 value:0.0]; // Roll Left
        [self gamepadMoveEventOnPad:4 axis:634 value:0.0]; // Roll Right
    }

    // Pitch: Tilt forward/back → Wiimote gyro pitch
    // Positive pitch = tilt back (towards you), Negative pitch = tilt forward (away from you)
    // IMUGyroscope/Pitch Up = Axis 631, IMUGyroscope/Pitch Down = Axis 632
    double pitch = motion.attitude.pitch; // Radians
    if (pitch > deadZone) {
        [self gamepadMoveEventOnPad:4 axis:632 value:MIN(pitch * sensitivity, 1.0)]; // Pitch Down
        [self gamepadMoveEventOnPad:4 axis:631 value:0.0]; // Pitch Up
    } else if (pitch < -deadZone) {
        [self gamepadMoveEventOnPad:4 axis:631 value:MIN(-pitch * sensitivity, 1.0)]; // Pitch Up
        [self gamepadMoveEventOnPad:4 axis:632 value:0.0]; // Pitch Down
    } else {
        [self gamepadMoveEventOnPad:4 axis:631 value:0.0]; // Pitch Up
        [self gamepadMoveEventOnPad:4 axis:632 value:0.0]; // Pitch Down
    }
}

/// Update IR cursor from device motion (alternative to touch screen)
/// Maps device tilt to IR cursor movement: left/right tilt → cursor left/right, forward/back tilt → cursor up/down
/// Using axis numbers from WiimoteNew.ini: IR entries (112-115)
-(void)updateIRCursorFromMotion:(CMDeviceMotion*)motion {
    const double deadZone = 0.05; // Smaller dead zone for cursor precision
    const double verticalSensitivity = 2.0;
    const double horizontalSensitivity = 3.00;

    int port = 4 + (self.multiPlayer ? 0 : 0); // Wiimote port

    // Get inversion settings from UserDefaults
    BOOL invertRoll = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_invert_roll"];
    BOOL invertPitch = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_invert_pitch"];

    // Left/Right Movement: Use yaw instead of roll for more natural feel
    // When holding phone in landscape, yaw (turning left/right) feels more natural than roll
    // IR/Left = Axis 114, IR/Right = Axis 115
    BOOL useYawForHorizontal = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_use_yaw_for_horizontal"];
    double horizontalAxis = useYawForHorizontal ? motion.attitude.yaw : motion.attitude.roll;

    if (invertRoll) { // Keep using "invertRoll" key for backward compatibility
        horizontalAxis = -horizontalAxis; // Invert horizontal direction
    }

    // Calculate horizontal output with enhanced sensitivity and proper clamping
    double horizontalOutput = horizontalAxis * horizontalSensitivity;
    horizontalOutput = fmax(-1.0, fmin(1.0, horizontalOutput)); // Clamp to [-1, 1]

    if (horizontalAxis > deadZone) {
        double rightValue = fmax(0.0, fmin(1.0, horizontalOutput)); // Ensure positive and clamped
        [self gamepadMoveEventOnPad:port axis:115 value:rightValue]; // IR Right
        [self gamepadMoveEventOnPad:port axis:114 value:0.0]; // IR Left
    } else if (horizontalAxis < -deadZone) {
        double leftValue = fmax(0.0, fmin(1.0, -horizontalOutput)); // Convert to positive and clamp
        [self gamepadMoveEventOnPad:port axis:114 value:leftValue]; // IR Left
        [self gamepadMoveEventOnPad:port axis:115 value:0.0]; // IR Right
    } else {
        [self gamepadMoveEventOnPad:port axis:114 value:0.0]; // IR Left
        [self gamepadMoveEventOnPad:port axis:115 value:0.0]; // IR Right
    }

    // Pitch: Tilt forward/back → IR cursor up/down
    // Positive pitch = tilt back → cursor down, Negative pitch = tilt forward → cursor up
    // IR/Up = Axis 112, IR/Down = Axis 113
    double pitch = motion.attitude.pitch; // Radians
    if (invertPitch) {
        pitch = -pitch; // Invert pitch direction
    }

    // Calculate vertical output with standard sensitivity and proper clamping
    double verticalOutput = pitch * verticalSensitivity;
    verticalOutput = fmax(-1.0, fmin(1.0, verticalOutput)); // Clamp to [-1, 1]

    if (pitch > deadZone) {
        double downValue = fmax(0.0, fmin(1.0, verticalOutput)); // Ensure positive and clamped
        [self gamepadMoveEventOnPad:port axis:113 value:downValue]; // IR Down
        [self gamepadMoveEventOnPad:port axis:112 value:0.0]; // IR Up
    } else if (pitch < -deadZone) {
        double upValue = fmax(0.0, fmin(1.0, -verticalOutput)); // Convert to positive and clamp
        [self gamepadMoveEventOnPad:port axis:112 value:upValue]; // IR Up
        [self gamepadMoveEventOnPad:port axis:113 value:0.0]; // IR Down
    } else {
        [self gamepadMoveEventOnPad:port axis:112 value:0.0]; // IR Up
        [self gamepadMoveEventOnPad:port axis:113 value:0.0]; // IR Down
    }
}

/// Full 6DOF motion mapping to Wiimote and Nunchuck accelerometer/gyro controls
/// Maps device motion to all 6 degrees of freedom when not using gyro IR cursor
/// This provides comprehensive motion control for games that use MotionPlus/IMU features
-(void)updateFull6DOFMotionFromMotion:(CMDeviceMotion*)motion {
    const double deadZone = 0.02; // Small dead zone to prevent noise
    const double accelSensitivity = 1.5; // Sensitivity for accelerometer
    const double gyroSensitivity = 1.0; // Sensitivity for gyroscope

    int port = 4 + (self.multiPlayer ? 0 : 0); // Wiimote port

    // Get settings for which controls to enable
    BOOL enableWiimoteIMU = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_wiimote_imu_enabled"];
    BOOL enableNunchuckIMU = [[NSUserDefaults standardUserDefaults] boolForKey:@"motion_nunchuck_imu_enabled"];

    // === WIIMOTE IMU CONTROLS ===
    if (enableWiimoteIMU) {
        // === ACCELEROMETER (User Acceleration - gravity removed) ===
        CMAcceleration userAccel = motion.userAcceleration;

        // X-axis: Left/Right acceleration
        if (fabs(userAccel.x) > deadZone) {
            if (userAccel.x > 0) {
                [self gamepadMoveEventOnPad:port axis:626 value:MIN(userAccel.x * accelSensitivity, 1.0)]; // Accel Right
                [self gamepadMoveEventOnPad:port axis:625 value:0.0]; // Accel Left
            } else {
                [self gamepadMoveEventOnPad:port axis:625 value:MIN(-userAccel.x * accelSensitivity, 1.0)]; // Accel Left
                [self gamepadMoveEventOnPad:port axis:626 value:0.0]; // Accel Right
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:625 value:0.0]; // Accel Left
            [self gamepadMoveEventOnPad:port axis:626 value:0.0]; // Accel Right
        }

        // Y-axis: Forward/Backward acceleration
        if (fabs(userAccel.y) > deadZone) {
            if (userAccel.y > 0) {
                [self gamepadMoveEventOnPad:port axis:628 value:MIN(userAccel.y * accelSensitivity, 1.0)]; // Accel Backward
                [self gamepadMoveEventOnPad:port axis:627 value:0.0]; // Accel Forward
            } else {
                [self gamepadMoveEventOnPad:port axis:627 value:MIN(-userAccel.y * accelSensitivity, 1.0)]; // Accel Forward
                [self gamepadMoveEventOnPad:port axis:628 value:0.0]; // Accel Backward
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:627 value:0.0]; // Accel Forward
            [self gamepadMoveEventOnPad:port axis:628 value:0.0]; // Accel Backward
        }

        // Z-axis: Up/Down acceleration
        if (fabs(userAccel.z) > deadZone) {
            if (userAccel.z > 0) {
                [self gamepadMoveEventOnPad:port axis:629 value:MIN(userAccel.z * accelSensitivity, 1.0)]; // Accel Up
                [self gamepadMoveEventOnPad:port axis:630 value:0.0]; // Accel Down
            } else {
                [self gamepadMoveEventOnPad:port axis:630 value:MIN(-userAccel.z * accelSensitivity, 1.0)]; // Accel Down
                [self gamepadMoveEventOnPad:port axis:629 value:0.0]; // Accel Up
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:629 value:0.0]; // Accel Up
            [self gamepadMoveEventOnPad:port axis:630 value:0.0]; // Accel Down
        }

        // === GYROSCOPE (Rotation Rate) ===
        CMRotationRate rotationRate = motion.rotationRate;

        // Pitch: Forward/Back rotation
        if (fabs(rotationRate.x) > deadZone) {
            if (rotationRate.x > 0) {
                [self gamepadMoveEventOnPad:port axis:631 value:MIN(rotationRate.x * gyroSensitivity, 1.0)]; // Pitch Up
                [self gamepadMoveEventOnPad:port axis:632 value:0.0]; // Pitch Down
            } else {
                [self gamepadMoveEventOnPad:port axis:632 value:MIN(-rotationRate.x * gyroSensitivity, 1.0)]; // Pitch Down
                [self gamepadMoveEventOnPad:port axis:631 value:0.0]; // Pitch Up
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:631 value:0.0]; // Pitch Up
            [self gamepadMoveEventOnPad:port axis:632 value:0.0]; // Pitch Down
        }

        // Roll: Left/Right rotation
        if (fabs(rotationRate.y) > deadZone) {
            if (rotationRate.y > 0) {
                [self gamepadMoveEventOnPad:port axis:633 value:MIN(rotationRate.y * gyroSensitivity, 1.0)]; // Roll Left
                [self gamepadMoveEventOnPad:port axis:634 value:0.0]; // Roll Right
            } else {
                [self gamepadMoveEventOnPad:port axis:634 value:MIN(-rotationRate.y * gyroSensitivity, 1.0)]; // Roll Right
                [self gamepadMoveEventOnPad:port axis:633 value:0.0]; // Roll Left
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:633 value:0.0]; // Roll Left
            [self gamepadMoveEventOnPad:port axis:634 value:0.0]; // Roll Right
        }

        // Yaw: Turning rotation
        if (fabs(rotationRate.z) > deadZone) {
            if (rotationRate.z > 0) {
                [self gamepadMoveEventOnPad:port axis:635 value:MIN(rotationRate.z * gyroSensitivity, 1.0)]; // Yaw Left
                [self gamepadMoveEventOnPad:port axis:636 value:0.0]; // Yaw Right
            } else {
                [self gamepadMoveEventOnPad:port axis:636 value:MIN(-rotationRate.z * gyroSensitivity, 1.0)]; // Yaw Right
                [self gamepadMoveEventOnPad:port axis:635 value:0.0]; // Yaw Left
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:635 value:0.0]; // Yaw Left
            [self gamepadMoveEventOnPad:port axis:636 value:0.0]; // Yaw Right
        }
    }

    // === NUNCHUCK IMU CONTROLS ===
    if (enableNunchuckIMU) {
        CMAcceleration userAccel = motion.userAcceleration;

        // X-axis: Left/Right acceleration
        if (fabs(userAccel.x) > deadZone) {
            if (userAccel.x > 0) {
                [self gamepadMoveEventOnPad:port axis:901 value:MIN(userAccel.x * accelSensitivity, 1.0)]; // Nunchuck Accel Right
                [self gamepadMoveEventOnPad:port axis:900 value:0.0]; // Nunchuck Accel Left
            } else {
                [self gamepadMoveEventOnPad:port axis:900 value:MIN(-userAccel.x * accelSensitivity, 1.0)]; // Nunchuck Accel Left
                [self gamepadMoveEventOnPad:port axis:901 value:0.0]; // Nunchuck Accel Right
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:900 value:0.0]; // Nunchuck Accel Left
            [self gamepadMoveEventOnPad:port axis:901 value:0.0]; // Nunchuck Accel Right
        }

        // Y-axis: Forward/Backward acceleration
        if (fabs(userAccel.y) > deadZone) {
            if (userAccel.y > 0) {
                [self gamepadMoveEventOnPad:port axis:903 value:MIN(userAccel.y * accelSensitivity, 1.0)]; // Nunchuck Accel Backward
                [self gamepadMoveEventOnPad:port axis:902 value:0.0]; // Nunchuck Accel Forward
            } else {
                [self gamepadMoveEventOnPad:port axis:902 value:MIN(-userAccel.y * accelSensitivity, 1.0)]; // Nunchuck Accel Forward
                [self gamepadMoveEventOnPad:port axis:903 value:0.0]; // Nunchuck Accel Backward
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:902 value:0.0]; // Nunchuck Accel Forward
            [self gamepadMoveEventOnPad:port axis:903 value:0.0]; // Nunchuck Accel Backward
        }

        // Z-axis: Up/Down acceleration
        if (fabs(userAccel.z) > deadZone) {
            if (userAccel.z > 0) {
                [self gamepadMoveEventOnPad:port axis:904 value:MIN(userAccel.z * accelSensitivity, 1.0)]; // Nunchuck Accel Up
                [self gamepadMoveEventOnPad:port axis:905 value:0.0]; // Nunchuck Accel Down
            } else {
                [self gamepadMoveEventOnPad:port axis:905 value:MIN(-userAccel.z * accelSensitivity, 1.0)]; // Nunchuck Accel Down
                [self gamepadMoveEventOnPad:port axis:904 value:0.0]; // Nunchuck Accel Up
            }
        } else {
            [self gamepadMoveEventOnPad:port axis:904 value:0.0]; // Nunchuck Accel Up
            [self gamepadMoveEventOnPad:port axis:905 value:0.0]; // Nunchuck Accel Down
        }

        // Note: Nunchuck doesn't have gyroscope controls in Dolphin
    }
}

/// Enhanced shake detection using user acceleration variance over time
/// Triggers Wiimote shake events when device is shaken with sufficient intensity
-(void)updateShakeDetectionFromMotion:(CMDeviceMotion*)motion {
    static NSMutableArray<NSNumber*> *shakeHistory = nil;
    static NSTimeInterval lastShakeTime = 0;

    if (!shakeHistory) {
        shakeHistory = [[NSMutableArray alloc] init];
    }

    // Calculate user acceleration magnitude (gravity already removed by Core Motion)
    CMAcceleration userAccel = motion.userAcceleration;
    double userAccelMagnitude = sqrt(userAccel.x * userAccel.x +
                                   userAccel.y * userAccel.y +
                                   userAccel.z * userAccel.z);

    // Add to history for variance calculation
    [shakeHistory addObject:@(userAccelMagnitude)];
    if ([shakeHistory count] > 15) { // Keep last 15 samples (about 1/4 second at 60fps)
        [shakeHistory removeObjectAtIndex:0];
    }

    // Calculate variance in acceleration
    if ([shakeHistory count] >= 8) {
        double mean = 0.0;
        for (NSNumber *value in shakeHistory) {
            mean += [value doubleValue];
        }
        mean /= [shakeHistory count];

        double variance = 0.0;
        for (NSNumber *value in shakeHistory) {
            double diff = [value doubleValue] - mean;
            variance += diff * diff;
        }
        variance /= [shakeHistory count];

        double standardDeviation = sqrt(variance);

        // Detect shake when standard deviation is high AND peak acceleration is above threshold
        const double varianceThreshold = 0.15; // Tuned for user acceleration (no gravity)
        const double accelerationThreshold = 0.8; // Lower threshold since gravity is removed
        const double shakeCooldown = 0.5; // Minimum time between shake events (seconds)

        BOOL hasHighVariance = standardDeviation > varianceThreshold;
        BOOL hasHighAcceleration = userAccelMagnitude > accelerationThreshold;
        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
        BOOL cooldownExpired = (currentTime - lastShakeTime) > shakeCooldown;

        if (hasHighVariance && hasHighAcceleration && cooldownExpired) {
            [self triggerWiimoteShakeEvent];
            lastShakeTime = currentTime;

            NSLog(@"🎮 Shake detected! Accel: %.3f StdDev: %.3f", userAccelMagnitude, standardDeviation);
        }
    }
}
#endif

/// Triggers shake events for the Wiimote controller
/// Using shake button types from TCButtonType: wiiShakeX/Y/Z (132-134)
-(void)triggerWiimoteShakeEvent {
    int port = 4 + (self.multiPlayer ? 0 : 0); // Wiimote port

    // Trigger shake on all axes for maximum compatibility
    // Different games may look for shake on different axes
    [self gamepadEventOnPad:port button:132 action: 1]; // wiiShakeX
    [self gamepadEventOnPad:port button:133 action: 1]; // wiiShakeY
    [self gamepadEventOnPad:port button:134 action: 1]; // wiiShakeZ

    // Release shake buttons after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self gamepadEventOnPad:port button:132 action: 0]; // wiiShakeX
        [self gamepadEventOnPad:port button:133 action: 0]; // wiiShakeY
        [self gamepadEventOnPad:port button:134 action: 0]; // wiiShakeZ
    });
}

/// Handle notification that motion settings have changed during gameplay
-(void)handleMotionSettingsChanged:(NSNotification*)notification {
    NSLog(@"🎮 Motion settings changed - restarting motion system");

    // Reset IR cursor to center when motion system restarts
    [self resetIRCursorForPlayer:0];

    // Stop current motion updates
    [self stopMotionUpdates];

    // Restart after a brief delay to ensure clean restart
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startMotionUpdates];
        NSLog(@"🎮 Motion system restarted with new settings - cursor reset to center");
    });
}

/// Enable enhanced motion controls by default for touchscreen controller profiles
-(void)enableEnhancedMotionControlsForTouchscreen {
    // Set motion control preferences for optimal touchscreen experience
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"motion_enhanced_shake_detection"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"motion_enable_ir_cursor"];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"motion_enable_full_6dof"];

    // Use roll instead of yaw for more intuitive tilt-based horizontal movement
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"motion_use_yaw_for_horizontal"];

    // Enable Wiimote IMU by default (required for most motion games), Nunchuck IMU off by default
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"motion_wiimote_imu_enabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"motion_nunchuck_imu_enabled"];

    // Set sensible defaults for axis inversion (can be adjusted by user)
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"motion_invert_roll"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"motion_invert_roll"];
    }
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"motion_invert_pitch"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"motion_invert_pitch"];
    }

    // Enable gyro IR cursor by default for touchscreen
    self.enableGyroIRCursor = YES;

    NSLog(@"🎮 Enhanced motion controls enabled for touchscreen controller profile");
}

@end
