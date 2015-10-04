//
//  PVRecentGame.m
//  Provenance
//
//  Created by James Addyman on 29/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVRecentGame.h"

@implementation PVRecentGame

- (instancetype)initWithGame:(PVGame *)game
{
    if ((self = [super init]))
    {
        self.game = game;
        self.lastPlayedDate = [NSDate date];
    }

    return self;
}

@end
