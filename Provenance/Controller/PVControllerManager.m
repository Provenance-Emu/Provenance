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
        if ([[GCController controllers] count])
        {
            GCController *firstController = [[GCController controllers] firstObject];
#if TARGET_OS_TV
            if (([[GCController controllers] count] > 1) && ([firstController microGamepad]))
            {
                self.player1 = [[GCController controllers] objectAtIndex:1];
            }
            else
            {
                self.player1 = firstController;
            }

            for (GCController *controller in [GCController controllers])
            {
                if ([controller microGamepad])
                {
                    [[controller microGamepad] setAllowsRotation:YES];
                    [[controller microGamepad] setReportsAbsoluteDpadValues:YES];
                }
            }
#else
            self.player1 = firstController;
#endif
        }

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
    _player1 = player1;
    [_player1 setPlayerIndex:0];
}

- (void)setPlayer2:(GCController *)player2
{
    _player2 = player2;
    [_player2 setPlayerIndex:1];
}

- (BOOL)hasControllers
{
    return (self.player1) || (self.player2);
}

- (void)handleControllerDidConnect:(NSNotification *)note
{
    GCController *controller = [note object];
    NSLog(@"Controller connected: %@", [controller vendorName]);

    // if we didn't have a player set before discovery and discovery found one, auto set it as player.

    if (!self.player1)
    {
        self.player1 = controller;
    }
    else if (!self.player2)
    {
        self.player2 = controller;
    }
#if TARGET_OS_TV
    if ([controller microGamepad])
    {
        [[controller microGamepad] setAllowsRotation:YES];
        [[controller microGamepad] setReportsAbsoluteDpadValues:YES];
    }
#endif

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
}

- (void)listenForICadeControllers
{
    __weak PVControllerManager* weakSelf = self;
    self.iCadeController.controllerPressedAnyKey = ^(PViCadeController* controller) {
        weakSelf.iCadeController.controllerPressedAnyKey = nil;
        if (!weakSelf.player1)
        {
            weakSelf.player1 = weakSelf.iCadeController;
        }
        else if (!weakSelf.player2)
        {
            weakSelf.player2 = weakSelf.iCadeController;
        }
    };
}

@end
