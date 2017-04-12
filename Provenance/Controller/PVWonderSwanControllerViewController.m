//
//  PVWonderSwanControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVWonderSwanControllerViewController.h"
#import <PVMednafen/MednafenGameCore.h>

@interface PVWonderSwanControllerViewController ()

@end

@implementation PVWonderSwanControllerViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    for (JSButton *button in [self.buttonGroup subviews])
    {
        if (![button isMemberOfClass:[JSButton class]])
        {
            continue; // skip over the PVButtonGroupOverlayView
        }
        
        if ([[[button titleLabel] text] isEqualToString:@"A"])
        {
            [button setTag:OEWSButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:OEWSButtonB];
        }
    }
    
//    [self.leftShoulderButton setTag:PVPSXButtonL1];
//    [self.rightShoulderButton setTag:PVPSXButtonR1];

    [self.selectButton setTag:OEWSButtonSound];
    [self.startButton setTag:OEWSButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    
    /*
     OEWSButtonX1 == Up
     OEWSButtonX2 == Right
     OEWSButtonX3 == Down
     OEWSButtonX4 == Left
     */
    if (dPad == self.dPad) {
        [wsCore didReleaseWSButton:OEWSButtonX1 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonX2 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonX3 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonX4 forPlayer:0];
        
        switch (direction)
        {
            case JSDPadDirectionUpLeft:
                [wsCore didPushWSButton:OEWSButtonX1 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonX4 forPlayer:0];
                break;
            case JSDPadDirectionUp:
                [wsCore didPushWSButton:OEWSButtonX1 forPlayer:0];
                break;
            case JSDPadDirectionUpRight:
                [wsCore didPushWSButton:OEWSButtonX1 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonX2 forPlayer:0];
                break;
            case JSDPadDirectionLeft:
                [wsCore didPushWSButton:OEWSButtonX4 forPlayer:0];
                break;
            case JSDPadDirectionRight:
                [wsCore didPushWSButton:OEWSButtonX2 forPlayer:0];
                break;
            case JSDPadDirectionDownLeft:
                [wsCore didPushWSButton:OEWSButtonX3 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonX4 forPlayer:0];
                break;
            case JSDPadDirectionDown:
                [wsCore didPushWSButton:OEWSButtonX3 forPlayer:0];
                break;
            case JSDPadDirectionDownRight:
                [wsCore didPushWSButton:OEWSButtonX3 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonX2 forPlayer:0];
                break;
            default:
                break;
        }
    } else {
        [wsCore didReleaseWSButton:OEWSButtonY1 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonY2 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonY3 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonY4 forPlayer:0];
        
        switch (direction)
        {
            case JSDPadDirectionUpLeft:
                [wsCore didPushWSButton:OEWSButtonY1 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonY4 forPlayer:0];
                break;
            case JSDPadDirectionUp:
                [wsCore didPushWSButton:OEWSButtonY1 forPlayer:0];
                break;
            case JSDPadDirectionUpRight:
                [wsCore didPushWSButton:OEWSButtonY1 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonY2 forPlayer:0];
                break;
            case JSDPadDirectionLeft:
                [wsCore didPushWSButton:OEWSButtonY4 forPlayer:0];
                break;
            case JSDPadDirectionRight:
                [wsCore didPushWSButton:OEWSButtonY2 forPlayer:0];
                break;
            case JSDPadDirectionDownLeft:
                [wsCore didPushWSButton:OEWSButtonY3 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonY4 forPlayer:0];
                break;
            case JSDPadDirectionDown:
                [wsCore didPushWSButton:OEWSButtonY3 forPlayer:0];
                break;
            case JSDPadDirectionDownRight:
                [wsCore didPushWSButton:OEWSButtonY3 forPlayer:0];
                [wsCore didPushWSButton:OEWSButtonY2 forPlayer:0];
                break;
            default:
                break;
        }
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    if (dPad == self.dPad) {
        [wsCore didReleaseWSButton:OEWSButtonX1 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonX2 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonX3 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonX4 forPlayer:0];
    } else {
        [wsCore didReleaseWSButton:OEWSButtonY1 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonY2 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonY3 forPlayer:0];
        [wsCore didReleaseWSButton:OEWSButtonY4 forPlayer:0];
    }
}

- (void)buttonPressed:(JSButton *)button
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    [wsCore didPushWSButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    [wsCore didReleaseWSButton:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    [wsCore didPushWSButton:OEWSButtonStart forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    [wsCore didReleaseWSButton:OEWSButtonStart forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    [wsCore didPushWSButton:OEWSButtonSound forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *wsCore = (MednafenGameCore *)self.emulatorCore;
    [wsCore didReleaseWSButton:OEWSButtonSound forPlayer:player];
}

@end
