//
//  PVControllerManager.h
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
@import GameController;

@class PViCadeController;

@interface PVControllerManager : NSObject

+ (PVControllerManager *)sharedManager;

@property (nonatomic, strong) GCController *player1;
@property (nonatomic, strong) GCController *player2;
@property (nonatomic, strong) PViCadeController *iCadeController;

- (BOOL)hasControllers;

@end
