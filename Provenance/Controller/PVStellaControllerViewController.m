//
//  PVStellaControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVStellaControllerViewController.h"
#import <PVStella/PVStellaGameCore.h>

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
        
        if ([[[button titleLabel] text] isEqualToString:@"Fire"])
        {
            [button setTag:OE2600ButtonFire1];
        } else if ([[[button titleLabel] text] isEqualToString:@"Select"]) {
            [button setTag:OE2600ButtonSelect];
        } else if ([[[button titleLabel] text] isEqualToString:@"Reset"]) {
            [button setTag:OE2600ButtonReset];
        }
    }
    
    self.startButton.tag  = OE2600ButtonReset;
    self.selectButton.tag = OE2600ButtonSelect;
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
    NSInteger tag = button.tag;
    [stellaCore didPush2600Button:tag forPlayer:0];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVStellaGameCore *stellaCore = (PVStellaGameCore *)self.emulatorCore;
    NSInteger tag = button.tag;
    [stellaCore didRelease2600Button:tag forPlayer:0];
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

