//
//  PVDolphinCore+Controls.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVDolphin/PVDolphin.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

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
#include "InputCommon/ControllerInterface/Touch/ButtonManager.h"
#include "InputCommon/ControllerInterface/iOS/ControllerScanner.h"
#include "InputCommon/ControllerInterface/iOS/iOS.h"
#include "InputCommon/ControllerInterface/iOS/Motor.h"
#include "InputCommon/ControllerInterface/ControllerInterface.h"
#include "InputCommon/ControllerInterface/Touch/Touchscreen.h"

#include "UICommon/CommandLineParse.h"
#include "UICommon/UICommon.h"
#include "UICommon/DiscordPresence.h"

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
  STICK_MAIN = 10,  // Used on Java Side
  STICK_MAIN_UP = 11,
  STICK_MAIN_DOWN = 12,
  STICK_MAIN_LEFT = 13,
  STICK_MAIN_RIGHT = 14,
  STICK_C = 15,  // Used on Java Side
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
  WIIMOTE_IR = 111,  // To Be Used on Java Side
  WIIMOTE_IR_UP = 112,
  WIIMOTE_IR_DOWN = 113,
  WIIMOTE_IR_LEFT = 114,
  WIIMOTE_IR_RIGHT = 115,
  WIIMOTE_IR_FORWARD = 116,
  WIIMOTE_IR_BACKWARD = 117,
  WIIMOTE_IR_HIDE = 118,
  WIIMOTE_SWING = 119,  // To Be Used on Java Side
  WIIMOTE_SWING_UP = 120,
  WIIMOTE_SWING_DOWN = 121,
  WIIMOTE_SWING_LEFT = 122,
  WIIMOTE_SWING_RIGHT = 123,
  WIIMOTE_SWING_FORWARD = 124,
  WIIMOTE_SWING_BACKWARD = 125,
  WIIMOTE_TILT = 126,  // To Be Used on Java Side
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
  NUNCHUK_STICK = 202,  // To Be Used on Java Side
  NUNCHUK_STICK_UP = 203,
  NUNCHUK_STICK_DOWN = 204,
  NUNCHUK_STICK_LEFT = 205,
  NUNCHUK_STICK_RIGHT = 206,
  NUNCHUK_SWING = 207,  // To Be Used on Java Side
  NUNCHUK_SWING_UP = 208,
  NUNCHUK_SWING_DOWN = 209,
  NUNCHUK_SWING_LEFT = 210,
  NUNCHUK_SWING_RIGHT = 211,
  NUNCHUK_SWING_FORWARD = 212,
  NUNCHUK_SWING_BACKWARD = 213,
  NUNCHUK_TILT = 214,  // To Be Used on Java Side
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
  CLASSIC_STICK_LEFT = 313,  // To Be Used on Java Side
  CLASSIC_STICK_LEFT_UP = 314,
  CLASSIC_STICK_LEFT_DOWN = 315,
  CLASSIC_STICK_LEFT_LEFT = 316,
  CLASSIC_STICK_LEFT_RIGHT = 317,
  CLASSIC_STICK_RIGHT = 318,  // To Be Used on Java Side
  CLASSIC_STICK_RIGHT_UP = 319,
  CLASSIC_STICK_RIGHT_DOWN = 320,
  CLASSIC_STICK_RIGHT_LEFT = 321,
  CLASSIC_STICK_RIGHT_RIGHT = 322,
  CLASSIC_TRIGGER_L = 323,
  CLASSIC_TRIGGER_R = 324,
  // Guitar
  GUITAR_BUTTON_MINUS = 400,
  GUITAR_BUTTON_PLUS = 401,
  GUITAR_FRET_GREEN = 402,
  GUITAR_FRET_RED = 403,
  GUITAR_FRET_YELLOW = 404,
  GUITAR_FRET_BLUE = 405,
  GUITAR_FRET_ORANGE = 406,
  GUITAR_STRUM_UP = 407,
  GUITAR_STRUM_DOWN = 408,
  GUITAR_STICK = 409,  // To Be Used on Java Side
  GUITAR_STICK_UP = 410,
  GUITAR_STICK_DOWN = 411,
  GUITAR_STICK_LEFT = 412,
  GUITAR_STICK_RIGHT = 413,
  GUITAR_WHAMMY_BAR = 414,
  // Drums
  DRUMS_BUTTON_MINUS = 500,
  DRUMS_BUTTON_PLUS = 501,
  DRUMS_PAD_RED = 502,
  DRUMS_PAD_YELLOW = 503,
  DRUMS_PAD_BLUE = 504,
  DRUMS_PAD_GREEN = 505,
  DRUMS_PAD_ORANGE = 506,
  DRUMS_PAD_BASS = 507,
  DRUMS_STICK = 508,  // To Be Used on Java Side
  DRUMS_STICK_UP = 509,
  DRUMS_STICK_DOWN = 510,
  DRUMS_STICK_LEFT = 511,
  DRUMS_STICK_RIGHT = 512,
  // Turntable
  TURNTABLE_BUTTON_GREEN_LEFT = 600,
  TURNTABLE_BUTTON_RED_LEFT = 601,
  TURNTABLE_BUTTON_BLUE_LEFT = 602,
  TURNTABLE_BUTTON_GREEN_RIGHT = 603,
  TURNTABLE_BUTTON_RED_RIGHT = 604,
  TURNTABLE_BUTTON_BLUE_RIGHT = 605,
  TURNTABLE_BUTTON_MINUS = 606,
  TURNTABLE_BUTTON_PLUS = 607,
  TURNTABLE_BUTTON_HOME = 608,
  TURNTABLE_BUTTON_EUPHORIA = 609,
  TURNTABLE_TABLE_LEFT = 610,  // To Be Used on Java Side
  TURNTABLE_TABLE_LEFT_LEFT = 611,
  TURNTABLE_TABLE_LEFT_RIGHT = 612,
  TURNTABLE_TABLE_RIGHT = 613,  // To Be Used on Java Side
  TURNTABLE_TABLE_RIGHT_LEFT = 614,
  TURNTABLE_TABLE_RIGHT_RIGHT = 615,
  TURNTABLE_STICK = 616,  // To Be Used on Java Side
  TURNTABLE_STICK_UP = 617,
  TURNTABLE_STICK_DOWN = 618,
  TURNTABLE_STICK_LEFT = 619,
  TURNTABLE_STICK_RIGHT = 620,
  TURNTABLE_EFFECT_DIAL = 621,
  TURNTABLE_CROSSFADE = 622,  // To Be Used on Java Side
  TURNTABLE_CROSSFADE_LEFT = 623,
  TURNTABLE_CROSSFADE_RIGHT = 624,
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
  // Wiimote IMU IR
  WIIMOTE_IR_RECENTER = 800,
  // Rumble
  RUMBLE = 700,
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

@implementation PVDolphinCore (Controls)

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
    ButtonManager::Init("AAAA01");
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
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_A
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_BUTTON_B
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_B
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::WIIMOTE_BUTTON_B
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_BUTTON_Y
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_Y action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
			controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_1
                         action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_BUTTON_A
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_A
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
            controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::WIIMOTE_BUTTON_2
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_X value:value];
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_BUTTON_X
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_X
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
			controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_PLUS action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_BUTTON_ZL
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::TRIGGER_L action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_X value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:value];
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_MINUS action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_BUTTON_ZR
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::TRIGGER_R action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::NUNCHUK_BUTTON_C action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_TRIGGER_L
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::TRIGGER_L action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SWING_FORWARD value:pressed?1.0:0];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:pressed?1.0:0];
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::NUNCHUK_BUTTON_Z action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_TRIGGER_R
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::TRIGGER_R action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_DPAD_UP
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_DPAD_LEFT
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
					 button:ButtonManager::ButtonType::CLASSIC_DPAD_RIGHT
					 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
			controller.extendedGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
                         button:ButtonManager::ButtonType::CLASSIC_DPAD_DOWN
                         action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
					[self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			};
            controller.extendedGamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad* leftJoypad, float xValue, float yValue) {
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_FORWARD value:xValue];
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_BACKWARD value:xValue];
                
                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_LEFT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_RIGHT value:xValue];
                } else {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_RIGHT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_LEFT value:-xValue];
                }
                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_DOWN value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_UP value:-yValue];
                } else {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_UP value:yValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_DOWN value:yValue];
                }
                // GC
                [self gamepadMoveEventOnPad:gcPort axis:11 value:CGFloat(-yValue)];
                [self gamepadMoveEventOnPad:gcPort axis:12 value:CGFloat(-yValue)];
                [self gamepadMoveEventOnPad:gcPort axis:13 value:CGFloat(xValue)];
                [self gamepadMoveEventOnPad:gcPort axis:14 value:CGFloat(xValue)];
 
            };
            controller.extendedGamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad* rightJoypad, float xValue, float yValue) {
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
            };
            controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                NSLog(@"Rotating (opt) controls %d\n", rotateControls);
                [self rotate:pressed];
                // GC
                [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_START action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_HOME
                    action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_IR_RECENTER action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_START action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                //GC
                [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_START
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                NSLog(@"Rotating (opt) controls %d\n", rotateControls);
                [self rotate:pressed];
            };
            controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_HOME
                    action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_IR_RECENTER action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_START action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
		} else if (controller.microGamepad != nil) {
            controller.microGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_BUTTON_1
                         action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_BUTTON_A
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_A
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.microGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::WIIMOTE_BUTTON_2
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Z value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_Y value:value];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_SHAKE_X value:value];
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_BUTTON_X
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_X
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.microGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_DPAD_UP
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.microGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_DPAD_LEFT
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.microGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
                     button:ButtonManager::ButtonType::CLASSIC_DPAD_RIGHT
                     action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            };
            controller.microGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                    if (rotateControls) {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    } else {
                        [self gamepadEventOnPad:port button:ButtonManager::ButtonType::WIIMOTE_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    }
                    [self gamepadEventOnPad:port
                         button:ButtonManager::ButtonType::CLASSIC_DPAD_DOWN
                         action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
                    [self gamepadEventOnPad:gcPort button:ButtonManager::ButtonType::BUTTON_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
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
    [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_IR_RECENTER action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
}

// pad == 4 is WiiMote, pad == 0 is GC (in both GC / Wii Modes)
- (void)gamepadEventOnPad:(int)pad button:(int)button action:(int)action
{
	ButtonManager::GamepadEvent("Touchscreen", pad, button, action);
}

- (void)gamepadMoveEventOnPad:(int)pad axis:(int)axis value:(CGFloat)value
{
	ButtonManager::GamepadAxisEvent("Touchscreen", pad, axis, value);
}

- (void)gamepadEventIrRecenter:(int)action
{
	// 4-8 are Wii Controllers
	for (int i = 4; i < 8; i++) {
	  NSLog(@"Received IR %d \n", action);
	  ButtonManager::GamepadEvent("Touchscreen", i, ButtonManager::ButtonType::WIIMOTE_IR_RECENTER, action);
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
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_FORWARD value:xValue];
                [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_BACKWARD value:xValue];

                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_LEFT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_RIGHT value:xValue];
                } else {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_RIGHT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_RIGHT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_LEFT value:-xValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_LEFT value:-xValue];
                }
                if (!rotateIr) {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_DOWN value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:-yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_UP value:-yValue];
                } else {
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_UP value:yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_UP value:yValue];
                    [self gamepadMoveEventOnPad:port axis:NUNCHUK_STICK_DOWN value:yValue];
                    [self gamepadMoveEventOnPad:port axis:WIIMOTE_IR_DOWN value:yValue];
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
            NSLog(@"Rotating Controls %d\n", rotateControls);
            break;
		case(PVWiiMoteButtonWiiHome):
            [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_IR_RECENTER
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_HOME
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_START
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiDPadLeft):
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_LEFT value:-value];
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_RIGHT value:-value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_UP
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            else
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_LEFT
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_LEFT
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiDPadRight):
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_RIGHT value:value];
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_LEFT value:value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_DOWN
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            else
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_RIGHT
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_RIGHT
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiDPadUp):
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_UP value:-value];
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_DOWN value:-value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_RIGHT
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            else
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_UP
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_UP
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiDPadDown):
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_UP value:value];
            [self gamepadMoveEventOnPad:4 axis:NUNCHUK_STICK_DOWN value:value];
            if (rotateControls)
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_LEFT
                    action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            else
                [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_DOWN
                 action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_DOWN
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiA):
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_A
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_A
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiB):
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_B
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_B
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiOne):
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_1
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Z value:value];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_Y
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            break;
        case(PVWiiMoteButtonWiiTwo):
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_X value:value];
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Y value:value];
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Z value:value];
            [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_2
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_X
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            break;
		case(PVWiiMoteButtonWiiPlus):
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Z value:value];
            [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_PLUS
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::TRIGGER_L
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonWiiMinus):
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_X value:value];
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Y value:value];
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_MINUS
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::TRIGGER_R
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonNunchukC):
		[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::NUNCHUK_BUTTON_C
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::TRIGGER_R
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVWiiMoteButtonNunchukZ):
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SWING_FORWARD value:value];
            [self gamepadMoveEventOnPad:4 axis:WIIMOTE_SHAKE_Y value:value];
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::NUNCHUK_BUTTON_Z
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_Z
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		default:
            [self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_IR_RECENTER
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			[self gamepadEventOnPad:4 button:ButtonManager::ButtonType::WIIMOTE_BUTTON_HOME
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
            [self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_START
             action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
	}
}


-(void)sendGCButtonInput:(enum PVGCButton)button isPressed:(bool)pressed withValue:(CGFloat)value forPlayer:(NSInteger)player {
	switch (button) {
		case(PVGCButtonStart):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_START action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
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
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_LEFT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonRight):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_RIGHT action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonUp):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_UP action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonDown):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_DOWN action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
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
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_Z action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonL):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::TRIGGER_L action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonR):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::TRIGGER_R action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonX):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_X action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonY):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_Y action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonA):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_A action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		case(PVGCButtonB):
			[self gamepadEventOnPad:0 button:ButtonManager::ButtonType::BUTTON_B action:(pressed?ButtonManager::BUTTON_PRESSED:ButtonManager::BUTTON_RELEASED)];
			break;
		default:
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
    NSLog(@"Config File: %s\n%s\n", fileName.UTF8String, content.UTF8String);
	[content writeToFile:fileName
	   atomically:NO
	   encoding:NSStringEncodingConversionAllowLossy
	   error:nil];
}

-(NSString *)getWiiTouchpadConfig:(int)port wiiMotePort:(int)wiiMotePort source:(int)source {
    NSString *content = [NSString stringWithFormat:
     @"[Wiimote%d]\n"
     @"Device = Android/%d/Touchscreen\n"
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
            SConfig::GetInstance().m_SIDevice[port - 1] = SerialInterface::SIDEVICE_GC_CONTROLLER;
            SerialInterface::ChangeDevice(SConfig::GetInstance().m_SIDevice[port - 1], port - 1);
            port += 1;
        }
    } else {
        content = [self getGCTouchConfig:1 gcPort:0 source:1];
    }
    NSLog(@"Config File: %s\n%s\n", fileName.UTF8String, content.UTF8String);
    [content writeToFile:fileName
       atomically:NO
       encoding:NSStringEncodingConversionAllowLossy
       error:nil];
}

-(NSString *)getGCTouchConfig:(int)port gcPort:(int)gcPort source:(int)source {
    NSString *content = [NSString stringWithFormat:
    @"[GCPad%d]\n"
    @"Device = Android/%d/Touchscreen\n"
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
@end
