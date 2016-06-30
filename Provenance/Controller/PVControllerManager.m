//
//  PVControllerManager.m
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVControllerManager.h"
#import "PVSettingsModel.h"
#import "PViCadeController.h"
#import "kICadeControllerSetting.h"

NSString * const PVControllerManagerControllerReassignedNotification = @"PVControllerManagerControllerReassignedNotification";

@interface PVControllerManager ()

@end

@implementation PVControllerManager

+ (PVControllerManager *)sharedManager
{
    static PVControllerManager *_sharedManager;

    if (!_sharedManager)
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _sharedManager = [[PVControllerManager alloc] init];
        });
    }
    
    return _sharedManager;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleControllerDidConnect:)
                                                     name:GCControllerDidConnectNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleControllerDidDisconnect:)
                                                     name:GCControllerDidDisconnectNotification
                                                   object:nil];

        // automatically assign the first connected controller to player 1
        // prefer gamepad or extendedGamepad over a microGamepad
        [self assignControllers];

        if (!self.iCadeController)
        {
            PVSettingsModel* settings = [PVSettingsModel sharedInstance];
            self.iCadeController = kIcadeControllerSettingToPViCadeController(settings.iCadeControllerSetting);
            if (self.iCadeController) {
                [self listenForICadeControllers];
            }
        }
    }

    return self;
}

- (void)setPlayer1:(GCController *)player1
{
    [self setController:player1 toPlayer:1];
}

- (void)setPlayer2:(GCController *)player2
{
    [self setController:player2 toPlayer:2];
}

- (BOOL)hasControllers
{
    return (self.player1) || (self.player2);
}

- (void)handleControllerDidConnect:(NSNotification *)note
{
    GCController *controller = [note object];
    NSLog(@"Controller connected: %@", [controller vendorName]);

    [self assignController:controller];
}

- (void)handleControllerDidDisconnect:(NSNotification *)note
{
    GCController *controller = [note object];
    NSLog(@"Controller disconnected: %@", [controller vendorName]);

    if (controller == self.player1)
    {
        self.player1 = nil;
    }
    if (controller == self.player2)
    {
        self.player2 = nil;
    }
    
    // Reassign any controller which we are unassigned
    BOOL assigned = [self assignControllers];
    if (!assigned) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PVControllerManagerControllerReassignedNotification
                                                            object:self];
    }
}

- (void)listenForICadeControllers
{
    __weak PVControllerManager* weakSelf = self;
    self.iCadeController.controllerPressedAnyKey = ^(PViCadeController* controller) {
        weakSelf.iCadeController.controllerPressedAnyKey = nil;
        [weakSelf assignController:weakSelf.iCadeController];
    };
}

#pragma mark - Controllers assignment

- (void)setController:(GCController *)controller toPlayer:(NSUInteger)player;
{
#if TARGET_OS_TV
    if ([controller microGamepad])
    {
        [[controller microGamepad] setAllowsRotation:YES];
        [[controller microGamepad] setReportsAbsoluteDpadValues:YES];
    }
#endif
    
    controller.playerIndex = (player-1);
    
    // TODO: keep an array of players/controllers we support more than 2 players
    if (player==1) {
        _player1 = controller;
    } else if (player==2) {
        _player2 = controller;
    }
    
    if (controller) {
        NSLog(@"Controller [%@] assigned to player %@", [controller vendorName], [NSNumber numberWithUnsignedInteger:player]);
    }
}

- (GCController *)controllerForPlayer:(NSUInteger)player;
{
    if (player==1) {
        return self.player1;
    } else if (player==2) {
        return self.player2;
    } else {
        return nil;
    }
}

- (BOOL)assignControllers;
{
    NSMutableArray *controllers = [[GCController controllers] mutableCopy];
    if (self.iCadeController) {
        [controllers addObject:self.iCadeController];
    }
    
    BOOL assigned = NO;
    for (GCController *controller in controllers) {
        if (self.player1 != controller && self.player2 != controller) {
            assigned = assigned || [self assignController:controller];
        }
    }
    return assigned;
}

- (BOOL)assignController:(GCController *)controller;
{
    // Assign the controller to the first player without a controller assigned, or
    // if this is an extended controller, replace the first controller which is not extended (the Siri remote on tvOS).
    for (NSUInteger i = 1; i<=2; i++) {
        GCController *previouslyAssignedController = [self controllerForPlayer:i];
        if (!previouslyAssignedController || (controller.extendedGamepad && !previouslyAssignedController.extendedGamepad)) {
            [self setController:controller toPlayer:i];
            
            // Move the previously assigned controller to another player
            if (previouslyAssignedController) {
                [self assignController:previouslyAssignedController];
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:PVControllerManagerControllerReassignedNotification
                                                                object:self];
            
            return YES;
        }
    }
    
    return NO;
}


@end
