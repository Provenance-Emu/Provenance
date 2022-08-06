//
//  PVGMECore+Controls.m
//  PVGME
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVGME/PVGME.h>
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

@implementation PVGMECore (Controls)

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

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP] = dpad.up.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN] = dpad.down.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT] = dpad.left.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonB.isPressed;

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START] = gamepad.buttonHome.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.buttonMenu.isPressed;

        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP] = dpad.up.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN] = dpad.down.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT] = dpad.left.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonB.isPressed;

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START] = gamepad.buttonX.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.buttonY.isPressed;
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP] = dpad.up.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN] = dpad.down.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT] = dpad.left.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;

            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonX.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START] = gamepad.buttonMenu.isPressed;
        }
#endif
    }
}

-(void)didPushNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PVNESButtonUp: _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = 1;
        case PVNESButtonDown: _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = 1;
        case PVNESButtonLeft: _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = 1;
        case PVNESButtonRight: _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = 1;
        case PVNESButtonA: _pad[player][RETRO_DEVICE_ID_JOYPAD_A] = 1;
        case PVNESButtonB: _pad[player][RETRO_DEVICE_ID_JOYPAD_B] = 1;
        case PVNESButtonStart: _pad[player][RETRO_DEVICE_ID_JOYPAD_START] = 1;
        case PVNESButtonSelect: _pad[player][RETRO_DEVICE_ID_JOYPAD_SELECT] = 1;
        default:
            break;
    }
}

-(void)didReleaseNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PVNESButtonUp: _pad[player][RETRO_DEVICE_ID_JOYPAD_UP] = 0;
        case PVNESButtonDown: _pad[player][RETRO_DEVICE_ID_JOYPAD_DOWN] = 0;
        case PVNESButtonLeft: _pad[player][RETRO_DEVICE_ID_JOYPAD_LEFT] = 0;
        case PVNESButtonRight: _pad[player][RETRO_DEVICE_ID_JOYPAD_RIGHT] = 0;
        case PVNESButtonA: _pad[player][RETRO_DEVICE_ID_JOYPAD_A] = 0;
        case PVNESButtonB: _pad[player][RETRO_DEVICE_ID_JOYPAD_B] = 0;
        case PVNESButtonStart: _pad[player][RETRO_DEVICE_ID_JOYPAD_START] = 0;
        case PVNESButtonSelect: _pad[player][RETRO_DEVICE_ID_JOYPAD_SELECT] = 0;
        default:
            break;
    }
}

@end
