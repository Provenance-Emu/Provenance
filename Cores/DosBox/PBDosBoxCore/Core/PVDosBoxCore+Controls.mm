//
//  PVDosBoxCore+Controls.m
//  PVDosBox
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVDosBox/PVDosBox.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

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

static const int DOSMap[]  = {
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

@implementation PVDosBoxCore (MouseResponder)
- (BOOL)gameSupportsMouse { return true; }
- (BOOL)requiresMouse{ return false; }

- (void)didScrollWithXValue:(float)xValue yValue:(float)yValue {
    if(yValue == 0) {
        self->mouse_wheel_up = 0;
        self->mouse_wheel_down = 0;
    } else if (yValue > 0.0) {
        self->mouse_wheel_up = yValue;
        self->mouse_wheel_down = 0;
    } else if (yValue < 0.0) {
        self->mouse_wheel_up = 0;
        self->mouse_wheel_down = yValue * -1;
    }
    if(xValue == 0) {
        self->mouse_horiz_wheel_up = 0;
        self->mouse_horiz_wheel_down = 0;
    } else if (xValue > 0.0) {
        self->mouse_horiz_wheel_up = xValue;
        self->mouse_horiz_wheel_down = 0;
    } else if (xValue < 0.0) {
        self->mouse_horiz_wheel_up = 0;
        self->mouse_horiz_wheel_down = xValue * -1;
    }
    [super didScrollWithXValue:xValue yValue:yValue];
}

- (void)mouseMovedAt:(CGPoint)point {
    self->mouse_x = point.x;
    self->mouse_y = point.y;
    [super mouseMovedAt:point];
}

- (void)leftMouseUp {
    self->mouseLeft = false;
    [super leftMouseUp];
}

- (void)leftMouseDown {
    self->mouseLeft = true;
    [super leftMouseDown];
}

- (void)rightMouseUp {
    self->mouseRight = false;
    [super rightMouseUp];
}
- (void)rightMouseDown {
    self->mouseRight = true;
    [super rightMouseDown];
}
- (void)middleMouseUp {
    self->mouseMiddle = false;
    [super middleMouseUp];
}
- (void)middleMouseDown {
    self->mouseMiddle = true;
    [super middleMouseDown];
}
- (void)auxiliaryMouseUp {
    self->mouse_button_4 = false;
    [super auxiliaryMouseUp];
}
- (void)auxiliaryMouseDown {
    self->mouse_button_4 = true;
    [super auxiliaryMouseDown];
}
- (void)auxiliary2MouseUp {
    self->mouse_button_5 = false;
    [super auxiliary2MouseUp];
}
- (void)auxiliary2MouseDown {
    self->mouse_button_5 = true;
    [super auxiliary2MouseDown];
}

@end

@implementation PVDosBoxCore (Controls)

- (void)initControllBuffers {
    memset(&kcode, 0xFFFF, sizeof(kcode));
    bzero(&rt, sizeof(rt));
    bzero(&lt, sizeof(lt));
}

#pragma mark - Control

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
        else if (self.controller3 && playerIndex == 3)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 4)
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
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
        }
#endif
    }
}

-(void)didPushDOSButton:(enum PVDOSButton)button forPlayer:(NSInteger)player {
//	if(_isInitialized)
//	  {
//	  }
}

-(void)didReleaseDOSButton:(enum PVDOSButton)button forPlayer:(NSInteger)player {
//	if(_isInitialized)
//	  {
//	  }
}

- (void)didMoveDOSJoystickDirection:(enum PVDOSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
//	if(_isInitialized)
//	  {
//	  }
}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self didMoveDOSJoystickDirection:(enum PVDOSButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushDOSButton:(PVDOSButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseDOSButton:(PVDOSButton)button forPlayer:player];
}


# pragma mark - Input Wii
//- (oneway void)didMoveWiiJoystickDirection:(OEWiiButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
//{
//	if(_isInitialized)
//	{
//		dol_host->SetAxis(button, value, (int)player);
//	}
//}
//
//- (oneway void)didPushWiiButton:(OEWiiButton)button forPlayer:(NSUInteger)player
//{
//	if(_isInitialized)
//	{
//		if (button > OEWiiButtonCount) {
//			dol_host->processSpecialKeys(button , (int)player);
//		} else {
//			dol_host->setButtonState(button, 1, (int)player);
//		}
//	}
//}
//
//- (oneway void)didReleaseWiiButton:(OEWiiButton)button forPlayer:(NSUInteger)player
//{
//	if(_isInitialized && button != OEWiimoteSideways && button != OEWiimoteUpright)
//	{
//		dol_host->setButtonState(button, 0, (int)player);
//	}
//}

@end
