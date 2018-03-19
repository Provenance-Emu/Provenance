//
//  PVGenesisEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

@interface PVGenesisEmulatorCore : PVEmulatorCore <PVGenesisSystemResponderClient>

- (void)didPushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;

@end
