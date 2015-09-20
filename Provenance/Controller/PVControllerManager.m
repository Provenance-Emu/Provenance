//
//  PVControllerManager.m
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVControllerManager.h"

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
        if ([[GCController controllers] count])
        {
            self.player1 = [[GCController controllers] firstObject];
            [self.player1 setPlayerIndex:0];
        }

//        // start discovery for any new controllers
//        [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
//            NSLog(@"Controller discovery completed");
//            if (!self.player1 && [[GCController controllers] count])
//            {
//                // if we didn't have a player1 set before discovery and discovery found one, auto set it as player1.
//                self.player1 = [[GCController controllers] firstObject];
//                [self.player1 setPlayerIndex:0];
//            }
//        }];
    }

    return self;
}

- (void)setPlayer1:(GCController *)player1
{
    if (!player1)
    {
        [_player1 setPlayerIndex:GCControllerPlayerIndexUnset];
    }
    _player1 = player1;
    [_player1 setPlayerIndex:0];
}

- (void)setPlayer2:(GCController *)player2
{
    if (!player2)
    {
        [_player2 setPlayerIndex:GCControllerPlayerIndexUnset];
    }

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

    [controller setPlayerIndex:GCControllerPlayerIndexUnset];
}

@end
