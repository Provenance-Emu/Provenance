//
//  PVPokeMiniControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 10/04/2017.
//  Copyright (c) 2017 Joe Mattiello. All rights reserved.
//

#import "PVPokeMiniControllerViewController.h"
#import <PVPokeMini/PVPokeMini.h>

@interface PVPokeMiniControllerViewController ()

@end

@implementation PVPokeMiniControllerViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    for (JSButton *button in [self.buttonGroup subviews])
    {
        if (![button isMemberOfClass:[JSButton class]])
        {
            continue;
        }
        
        if ([[[button titleLabel] text] isEqualToString:@"A"])
        {
            [button setTag:PVPMButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:PVPMButtonB];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"C"])
        {
            [button setTag:PVPMButtonC];
        }
    }
    
    [self.leftShoulderButton setTag:PVPMButtonMenu];
    
    [self.startButton setTag:PVPMButtonPower];
    [self.selectButton setTag:PVPMButtonShake];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    
    [pokeCore didReleasePMButton:PVPMButtonUp forPlayer:0];
    [pokeCore didReleasePMButton:PVPMButtonDown forPlayer:0];
    [pokeCore didReleasePMButton:PVPMButtonLeft forPlayer:0];
    [pokeCore didReleasePMButton:PVPMButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [pokeCore didPushPMButton:PVPMButtonUp forPlayer:0];
            [pokeCore didPushPMButton:PVPMButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [pokeCore didPushPMButton:PVPMButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [pokeCore didPushPMButton:PVPMButtonUp forPlayer:0];
            [pokeCore didPushPMButton:PVPMButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [pokeCore didPushPMButton:PVPMButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [pokeCore didPushPMButton:PVPMButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [pokeCore didPushPMButton:PVPMButtonDown forPlayer:0];
            [pokeCore didPushPMButton:PVPMButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [pokeCore didPushPMButton:PVPMButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [pokeCore didPushPMButton:PVPMButtonDown forPlayer:0];
            [pokeCore didPushPMButton:PVPMButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
	[super dPad:dPad didPressDirection:direction];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    
    [pokeCore didReleasePMButton:PVPMButtonUp forPlayer:0];
    [pokeCore didReleasePMButton:PVPMButtonDown forPlayer:0];
    [pokeCore didReleasePMButton:PVPMButtonLeft forPlayer:0];
    [pokeCore didReleasePMButton:PVPMButtonRight forPlayer:0];
	[super dPadDidReleaseDirection:dPad];
}

- (void)buttonPressed:(JSButton *)button
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    [pokeCore didPushPMButton:[button tag] forPlayer:0];
    
	[super buttonPressed:button];
}

- (void)buttonReleased:(JSButton *)button
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    [pokeCore didReleasePMButton:[button tag] forPlayer:0];
	[super buttonReleased:button];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    [pokeCore didPushPMButton:PVPMButtonPower forPlayer:player];
	[super pressStartForPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    [pokeCore didReleasePMButton:PVPMButtonPower forPlayer:player];
	[super releaseStartForPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    [pokeCore didPushPMButton:PVPMButtonShake forPlayer:player];
	[super pressSelectForPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    PVPokeMiniEmulatorCore *pokeCore = (PVPokeMiniEmulatorCore *)self.emulatorCore;
    [pokeCore didReleasePMButton:PVPMButtonShake forPlayer:player];
	[super releaseSelectForPlayer:player];
}

@end
