//
//  PVGenesisEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVEmulatorCore.h"
#import "libretro.h"

typedef NS_ENUM(NSUInteger, PVGenesisButton)
{
    PVGenesisButtonUp = RETRO_DEVICE_ID_JOYPAD_UP,
    PVGenesisButtonDown = RETRO_DEVICE_ID_JOYPAD_DOWN,
    PVGenesisButtonLeft = RETRO_DEVICE_ID_JOYPAD_LEFT,
    PVGenesisButtonRight = RETRO_DEVICE_ID_JOYPAD_RIGHT,
    PVGenesisButtonA = RETRO_DEVICE_ID_JOYPAD_Y,
    PVGenesisButtonB = RETRO_DEVICE_ID_JOYPAD_B,
    PVGenesisButtonC = RETRO_DEVICE_ID_JOYPAD_A,
    PVGenesisButtonX = RETRO_DEVICE_ID_JOYPAD_L,
    PVGenesisButtonY = RETRO_DEVICE_ID_JOYPAD_X,
    PVGenesisButtonZ = RETRO_DEVICE_ID_JOYPAD_R,
    PVGenesisButtonStart = RETRO_DEVICE_ID_JOYPAD_START,
    PVGenesisButtonMode = RETRO_DEVICE_ID_JOYPAD_SELECT,
    PVGenesisButtonCount,
};

@interface PVGenesisEmulatorCore : PVEmulatorCore

- (void)pushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)releaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;

@end
