//
//  PVRecentGame.h
//  Provenance
//
//  Created by James Addyman on 29/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import <Realm/Realm.h>
#import "PVGame.h"

@interface PVRecentGame : RLMObject

@property PVGame *game;
@property NSDate *lastPlayedDate;

- (instancetype)initWithGame:(PVGame *)game;

@end
