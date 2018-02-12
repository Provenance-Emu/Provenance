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

extern NSString * _Nonnull const PVControllerManagerControllerReassignedNotification;

@interface PVControllerManager : NSObject

+ (PVControllerManager * _Nonnull)sharedManager;

@property (nonatomic, strong, nullable) GCController *player1;
@property (nonatomic, strong, nullable) GCController *player2;
@property (nonatomic, strong, nullable) PViCadeController *iCadeController;

- (BOOL)hasControllers;
- (void)listenForICadeControllersForPlayer:(NSInteger)player window:(UIWindow *_Nullable)window completion:(void (^_Nullable)(void))completion;
- (void)stopListeningForICadeControllers;

@end
