//
//  PVPlayCore+Controls.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVPlay/PVPlay.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PS2VM.h"

#include "PH_Generic.h"
#include "PS2VM.h"
#include "CGSH_Provenance_OGL.h"

extern CGSH_Provenance_OGL *gsHandler;
extern CPH_Generic *padHandler;
extern UIView *m_view;
extern CPS2VM *_ps2VM;

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

static const int DreamcastMap[]  = {
    DC_DPAD_UP, DC_DPAD_DOWN, DC_DPAD_LEFT, DC_DPAD_RIGHT,
    DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y,
    DC_AXIS_LT, DC_AXIS_RT,
    DC_BTN_START
};

typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef unsigned int   u32;

    // Reicast controller data
u16 kcode[4];
u8 rt[4];
u8 lt[4];
u32 vks[4];
s8 joyx[4], joyy[4];

@implementation PVPlayCore (Controls)

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
                padHandler->SetButtonState(PS2::CControllerInfo::CROSS, pressed);
            };
            controller.extendedGamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, pressed);
            };
            controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, pressed);
            };
            controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, pressed);
            };
            controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::L1, pressed);
            };
            controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::R1, pressed);
            };
            controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::L2, pressed);
            };
            controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::R2, pressed);
            };
            controller.extendedGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, pressed);
            };
            controller.extendedGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, pressed);
            };
            controller.extendedGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, pressed);
            };
            controller.extendedGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, pressed);
            };
            controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::SELECT, pressed);
            };
            controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::START, pressed);
            };
            controller.extendedGamepad.leftThumbstick.xAxis.valueChangedHandler = ^(GCControllerAxisInput* xAxis, float value) {
                padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, value);
            };
            controller.extendedGamepad.leftThumbstick.yAxis.valueChangedHandler = ^(GCControllerAxisInput* yAxis, float value) {
                padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, -value);
            };
            controller.extendedGamepad.rightThumbstick.xAxis.valueChangedHandler = ^(GCControllerAxisInput* xAxis, float value) {
                padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_X, value);
            };
            controller.extendedGamepad.rightThumbstick.yAxis.valueChangedHandler = ^(GCControllerAxisInput* yAxis, float value) {
                padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_Y, -value);
            };
            controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::L3, pressed);
            };
            controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::R3, pressed);
            };
        }
        else if (controller.gamepad != nil)
        {
            controller.gamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::CROSS, pressed);
            };
            controller.gamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, pressed);
            };
            controller.gamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, pressed);
            };
            controller.gamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, pressed);
            };
            controller.gamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::L1, pressed);
            };
            controller.gamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::R1, pressed);
            };
            controller.gamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, pressed);
            };
            controller.gamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, pressed);
            };
            controller.gamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, pressed);
            };
            controller.gamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, pressed);
            };
        }
        else if (controller.microGamepad != nil)
        {
            controller.microGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::CROSS, pressed);
            };
            controller.microGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, pressed);
            };
            controller.microGamepad.dpad.up.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, pressed);
            };
            controller.microGamepad.dpad.left.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, pressed);
            };
            controller.microGamepad.dpad.right.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, pressed);
            };
            controller.microGamepad.dpad.down.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, pressed);
            };
        }
    }
}

- (void)pollControllers {
    for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
    {
        GCController *controller = nil;

        if (self.controller1 && playerIndex == 0)
        {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && playerIndex == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 3)
        {
            controller = self.controller4;
        }

        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);

            gamepad.leftTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Z) : kcode[playerIndex] |= (DC_BTN_Z);
            gamepad.rightTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_START) : kcode[playerIndex] |= (DC_BTN_START);


            float xvalue = gamepad.leftThumbstick.xAxis.value;
            s8 x=(s8)(xvalue*127);
            joyx[0] = x;

            float yvalue = gamepad.leftThumbstick.yAxis.value;
            s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
            joyy[0] = y;
            [self sendExtendedGamepadInput:gamepad forPlayer:playerIndex];
            return;
        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
            [self sendGamepadInput:gamepad forPlayer:playerIndex];
            return;

        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            [self sendMicroGamepadInput:gamepad forPlayer:playerIndex];
            return;
        }
#endif
    }
}

-(void)sendExtendedGamepadInput:(GCExtendedGamepad *) gamepad forPlayer:(NSInteger)player {
    padHandler->SetButtonState(PS2::CControllerInfo::CROSS, gamepad.buttonA.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, gamepad.buttonB.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, gamepad.buttonX.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, gamepad.buttonY.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, gamepad.dpad.up.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, gamepad.dpad.down.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, gamepad.dpad.left.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, gamepad.dpad.right.isPressed);
    padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, gamepad.leftThumbstick.xAxis.value);
    padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, -gamepad.leftThumbstick.yAxis.value);
    padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_X, gamepad.rightThumbstick.xAxis.value);
    padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_Y, -gamepad.rightThumbstick.yAxis.value);
    padHandler->SetButtonState(PS2::CControllerInfo::L1, gamepad.leftShoulder.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::R1, gamepad.rightShoulder.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::L2, gamepad.leftTrigger.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::R2, gamepad.rightTrigger.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::L3, gamepad.leftThumbstickButton.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::R3, gamepad.rightThumbstickButton.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::SELECT, gamepad.buttonMenu.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::START, gamepad.buttonHome.isPressed);
}


-(void)sendGamepadInput:(GCGamepad *) gamepad forPlayer:(NSInteger)player {
    padHandler->SetButtonState(PS2::CControllerInfo::CROSS, gamepad.buttonA.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, gamepad.buttonB.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, gamepad.buttonX.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, gamepad.buttonY.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::L1, gamepad.leftShoulder.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::R1, gamepad.rightShoulder.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, gamepad.dpad.up.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, gamepad.dpad.down.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, gamepad.dpad.left.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, gamepad.dpad.right.isPressed);
}


-(void)sendMicroGamepadInput:(GCMicroGamepad *) gamepad forPlayer:(NSInteger)player {
    padHandler->SetButtonState(PS2::CControllerInfo::CROSS, gamepad.buttonA.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, gamepad.buttonX.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, gamepad.dpad.up.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, gamepad.dpad.down.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, gamepad.dpad.left.isPressed);
    padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, gamepad.dpad.right.isPressed);
}

-(void)sendButtonInput:(enum PVPS2Button)button isPressed:(bool)pressed withValue:(CGFloat)value forPlayer:(NSInteger)player {
    switch (button) {
        case(PVPS2ButtonStart):
            padHandler->SetButtonState(PS2::CControllerInfo::START, pressed);
            break;
        case(PVPS2ButtonSelect):
            padHandler->SetButtonState(PS2::CControllerInfo::SELECT, pressed);
            break;
        case(PVPS2ButtonLeft):
            padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT, pressed);
            break;
        case(PVPS2ButtonRight):
            padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, pressed);
            break;
        case(PVPS2ButtonUp):
            padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP, pressed);
            break;
        case(PVPS2ButtonDown):
            padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN, pressed);
            break;
        case(PVPS2ButtonSquare):
            padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, pressed);
            break;
        case(PVPS2ButtonCross):
            padHandler->SetButtonState(PS2::CControllerInfo::CROSS, pressed);
            break;
        case(PVPS2ButtonTriangle):
            padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, pressed);
            break;
        case(PVPS2ButtonCircle):
            padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, pressed);
            break;
        case(PVPS2ButtonL1):
            padHandler->SetButtonState(PS2::CControllerInfo::L1, pressed);
            break;
        case(PVPS2ButtonR1):
            padHandler->SetButtonState(PS2::CControllerInfo::R1, pressed);
            break;
        case(PVPS2ButtonL2):
            padHandler->SetButtonState(PS2::CControllerInfo::L2, pressed);
            break;
        case(PVPS2ButtonR2):
            padHandler->SetButtonState(PS2::CControllerInfo::R2, pressed);
            break;
        case(PVPS2ButtonL3):
            padHandler->SetButtonState(PS2::CControllerInfo::L3, pressed);
            break;
        case(PVPS2ButtonR3):
            padHandler->SetButtonState(PS2::CControllerInfo::R3, pressed);
            break;
        case(PVPS2ButtonLeftAnalogLeft):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, -value);
            break;
        case(PVPS2ButtonLeftAnalogRight):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, value);
            break;
        case(PVPS2ButtonLeftAnalogUp):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, -value);
            break;
        case(PVPS2ButtonLeftAnalogDown):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, value);
            break;
        case(PVPS2ButtonRightAnalogLeft):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_X, -value);
            break;
        case(PVPS2ButtonRightAnalogRight):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_X, value);
            break;
        case(PVPS2ButtonRightAnalogUp):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_Y, -value);
            break;
        case(PVPS2ButtonRightAnalogDown):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_Y, value * 3);
            break;
        default:
            break;
    }
}

-(void)didPushPS2Button:(enum PVPS2Button)button forPlayer:(NSInteger)player {
    [self sendButtonInput:button isPressed:true withValue:1 forPlayer:player];
}

- (void)didReleasePS2Button:(enum PVPS2Button)button forPlayer:(NSInteger)player {
    [self sendButtonInput:button isPressed:false withValue:0 forPlayer:player];
}

- (void)didMovePS2JoystickDirection:(enum PVPS2Button)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    switch (button) {
        case(PVPS2ButtonLeftAnalog):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, xValue);
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, -yValue);
            break;
        case(PVPS2ButtonRightAnalog):
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_X, xValue);
            padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_Y, -yValue);
            break;
        default:
            break;
    }
}

-(void)didMoveJoystick:(NSInteger)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    [self didMovePS2JoystickDirection:(enum PVPS2Button)button withXValue:xValue withYValue:yValue forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushPS2Button:(PVPS2Button)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleasePS2Button:(PVPS2Button)button forPlayer:player];
}

@end
