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

static const int DSMap[]  = {
    DC_DPAD_UP, DC_DPAD_DOWN, DC_DPAD_LEFT, DC_DPAD_RIGHT,
    DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y,
    DC_AXIS_LT, DC_AXIS_RT,
    DC_BTN_START
};

typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef unsigned int   u32;

    // Desmume2015 controller data
//u16 kcode[4];
//u8 rt[4];
//u8 lt[4];
//u32 vks[4];
//s8 joyx[4], joyy[4];

@implementation PVDesmume2015CoreBridge (Controls)

- (void)initControllBuffers {
//    memset(&kcode, 0xFFFF, sizeof(kcode));
//    bzero(&rt, sizeof(rt));
//    bzero(&lt, sizeof(lt));
}

#pragma mark - Control
//
//- (void)pollControllers {
//    for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
//    {
//        GCController *controller = nil;
//
//        if (self.controller1 && playerIndex == 0)
//        {
//            controller = self.controller1;
//        }
//        else if (self.controller2 && playerIndex == 1)
//        {
//            controller = self.controller2;
//        }
//        else if (self.controller3 && playerIndex == 3)
//        {
//            controller = self.controller3;
//        }
//        else if (self.controller4 && playerIndex == 4)
//        {
//            controller = self.controller4;
//        }
//
//        if ([controller extendedGamepad])
//        {
//            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
//            GCControllerDirectionPad *dpad = [gamepad dpad];
//
//            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
//            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
//            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
//            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);
//
//            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
//            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
//            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
//            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);
//
//            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
//            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
//
//            gamepad.leftTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Z) : kcode[playerIndex] |= (DC_BTN_Z);
//            gamepad.rightTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_START) : kcode[playerIndex] |= (DC_BTN_START);
//
//
//            float xvalue = gamepad.leftThumbstick.xAxis.value;
//            s8 x=(s8)(xvalue*127);
//            joyx[0] = x;
//
//            float yvalue = gamepad.leftThumbstick.yAxis.value;
//            s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
//            joyy[0] = y;
//
//        } else if ([controller gamepad]) {
//            GCGamepad *gamepad = [controller gamepad];
//            GCControllerDirectionPad *dpad = [gamepad dpad];
//
//            dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
//            dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
//            dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
//            dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);
//
//            gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
//            gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
//            gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
//            gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);
//
//            gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
//            gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
//        }
//#if TARGET_OS_TV
//        else if ([controller microGamepad]) {
//            GCMicroGamepad *gamepad = [controller microGamepad];
//            GCControllerDirectionPad *dpad = [gamepad dpad];
//        }
//#endif
//    }
//}

-(void)didPushDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    if (player >= 2) return; // Only support 2 players in libretro
    
    // Map DS buttons to libretro device IDs
    switch (button) {
        case PVDSButtonUp:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = 1;
            break;
        case PVDSButtonDown:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = 1;
            break;
        case PVDSButtonLeft:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = 1;
            break;
        case PVDSButtonRight:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = 1;
            break;
        case PVDSButtonA:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_A] = 1;
            break;
        case PVDSButtonB:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_B] = 1;
            break;
        case PVDSButtonX:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_X] = 1;
            break;
        case PVDSButtonY:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_Y] = 1;
            break;
        case PVDSButtonL:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L] = 1;
            break;
        case PVDSButtonR:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R] = 1;
            break;
        case PVDSButtonStart:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_START] = 1;
            break;
        case PVDSButtonSelect:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_SELECT] = 1;
            break;
        case PVDSButtonScreenSwap:
            // Screen swap is typically handled by the core, map to L2
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L2] = 1;
            break;
        case PVDSButtonRotate:
            // Screen rotate is typically handled by the core, map to R2
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R2] = 1;
            break;
        default:
            break;
    }
}

-(void)didReleaseDSButton:(enum PVDSButton)button forPlayer:(NSInteger)player {
    if (player >= 2) return; // Only support 2 players in libretro
    
    // Map DS buttons to libretro device IDs
    switch (button) {
        case PVDSButtonUp:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = 0;
            break;
        case PVDSButtonDown:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = 0;
            break;
        case PVDSButtonLeft:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = 0;
            break;
        case PVDSButtonRight:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = 0;
            break;
        case PVDSButtonA:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_A] = 0;
            break;
        case PVDSButtonB:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_B] = 0;
            break;
        case PVDSButtonX:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_X] = 0;
            break;
        case PVDSButtonY:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_Y] = 0;
            break;
        case PVDSButtonL:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L] = 0;
            break;
        case PVDSButtonR:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R] = 0;
            break;
        case PVDSButtonStart:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_START] = 0;
            break;
        case PVDSButtonSelect:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_SELECT] = 0;
            break;
        case PVDSButtonScreenSwap:
            // Screen swap is typically handled by the core, map to L2
            _pad[player][RETRO_DEVICE_ID_JOYPAD_L2] = 0;
            break;
        case PVDSButtonRotate:
            // Screen rotate is typically handled by the core, map to R2
            _pad[player][RETRO_DEVICE_ID_JOYPAD_R2] = 0;
            break;
        default:
            break;
    }
}

- (void)didMoveDSJoystickDirection:(enum PVDSButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    if (player >= 2) return; // Only support 2 players in libretro
    
    // Handle analog stick input by converting to digital for libretro
    const float threshold = 0.5f;
    
    switch (button) {
        case PVDSButtonUp:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = (value > threshold) ? 1 : 0;
            break;
        case PVDSButtonDown:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = (value > threshold) ? 1 : 0;
            break;
        case PVDSButtonLeft:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = (value > threshold) ? 1 : 0;
            break;
        case PVDSButtonRight:
            _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = (value > threshold) ? 1 : 0;
            break;
        default:
            break;
    }
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

@end
