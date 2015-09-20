//
//  PVGenesisEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVEmulatorCore.h"

typedef NS_ENUM(NSUInteger, PVGenesisButton)
{
    PVGenesisButtonUp,
    PVGenesisButtonDown,
    PVGenesisButtonLeft,
    PVGenesisButtonRight,
    PVGenesisButtonA,
    PVGenesisButtonB,
    PVGenesisButtonC,
    PVGenesisButtonX,
    PVGenesisButtonY,
    PVGenesisButtonZ,
    PVGenesisButtonStart,
    PVGenesisButtonMode,
    PVGenesisButtonCount,
};

@interface PVGenesisEmulatorCore : PVEmulatorCore

- (void)pushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)releaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;

@end
