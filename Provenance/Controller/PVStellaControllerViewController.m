//
//  PVStellaControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVStellaControllerViewController.h"
#import "PVStellaGameCore.h"

@interface PVStellaControllerViewController ()

@end

@implementation PVStellaControllerViewController

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
            [button setTag:OE2600ButtonFire1];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"] || [[[button titleLabel] text] isEqualToString:@"1"])
        {
            [button setTag:OE2600ButtonFire1];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"C"] || [[[button titleLabel] text] isEqualToString:@"2"])
        {
            [button setTag:OE2600ButtonFire1];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"X"])
        {
            [button setTag:OE2600ButtonFire1];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Y"])
        {
            [button setTag:OE2600ButtonFire1];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Z"])
        {
            [button setTag:OE2600ButtonFire1];
        }
    }
    
    [self.startButton setTag:OE2600ButtonReset];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    
    [stellaCore didRelease2600Button:OE2600ButtonUp forPlayer:0];
    [stellaCore didRelease2600Button:OE2600ButtonDown forPlayer:0];
    [stellaCore didRelease2600Button:OE2600ButtonLeft forPlayer:0];
    [stellaCore didRelease2600Button:OE2600ButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [stellaCore didPush2600Button:OE2600ButtonUp forPlayer:0];
            [stellaCore didPush2600Button:OE2600ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [stellaCore didPush2600Button:OE2600ButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [stellaCore didPush2600Button:OE2600ButtonUp forPlayer:0];
            [stellaCore didPush2600Button:OE2600ButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [stellaCore didPush2600Button:OE2600ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [stellaCore didPush2600Button:OE2600ButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [stellaCore didPush2600Button:OE2600ButtonDown forPlayer:0];
            [stellaCore didPush2600Button:OE2600ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [stellaCore didPush2600Button:OE2600ButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [stellaCore didPush2600Button:OE2600ButtonDown forPlayer:0];
            [stellaCore didPush2600Button:OE2600ButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    
    [stellaCore didRelease2600Button:OE2600ButtonUp forPlayer:0];
    [stellaCore didRelease2600Button:OE2600ButtonDown forPlayer:0];
    [stellaCore didRelease2600Button:OE2600ButtonLeft forPlayer:0];
    [stellaCore didRelease2600Button:OE2600ButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    [stellaCore didPush2600Button:[button tag] forPlayer:0];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    [stellaCore didPush2600Button:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    [stellaCore didPush2600Button:OE2600ButtonReset forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    [stellaCore didRelease2600Button:OE2600ButtonReset forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    [stellaCore didPush2600Button:OE2600ButtonSelect forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    [stellaCore didRelease2600Button:OE2600ButtonSelect forPlayer:player];
}

@end

