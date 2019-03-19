//
//  PVGenesisEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

@import Foundation;
@import PVSupport.PVEmulatorCore;


@interface PVGenesisEmulatorCore : PVEmulatorCore <PVGenesisSystemResponderClient>

- (void)didPushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player;

@end
