//
//  PVGMECore+Controls.m
//  PVGME
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVGME/PVGME.h>
#import <Foundation/Foundation.h>
#import "player.h"
@import PVCoreBridge;

@implementation PVGMECoreBridge (Controls)

#pragma mark - Control

-(void)didPushNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PVNESButtonUp:
        case PVNESButtonLeft:
            prev_track();
            break;
        case PVNESButtonDown:
        case PVNESButtonRight:
            next_track();
            break;
        case PVNESButtonA:
        case PVNESButtonB:
            play_pause();
            break;
        default:
            break;
    }
}

-(void)didReleaseNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {

}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushNESButton:(PVNESButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseNESButton:(PVNESButton)button forPlayer:player];
}

@end
