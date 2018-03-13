//
//  PVNESControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 22/03/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVNESControllerViewController.h"
#import <PVFCEU/PVFCEUEmulatorCore.h>

@interface PVNESControllerViewController ()

@end

@implementation PVNESControllerViewController

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
            [button setTag:PVNESButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:PVNESButtonB];
        }
    }
    
    [self.startButton setTag:PVNESButtonStart];
    [self.selectButton setTag:PVNESButtonSelect];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    
    [nesCore releaseNESButton:PVNESButtonUp forPlayer:0];
    [nesCore releaseNESButton:PVNESButtonDown forPlayer:0];
    [nesCore releaseNESButton:PVNESButtonLeft forPlayer:0];
    [nesCore releaseNESButton:PVNESButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [nesCore pushNESButton:PVNESButtonUp forPlayer:0];
            [nesCore pushNESButton:PVNESButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [nesCore pushNESButton:PVNESButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [nesCore pushNESButton:PVNESButtonUp forPlayer:0];
            [nesCore pushNESButton:PVNESButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [nesCore pushNESButton:PVNESButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [nesCore pushNESButton:PVNESButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [nesCore pushNESButton:PVNESButtonDown forPlayer:0];
            [nesCore pushNESButton:PVNESButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [nesCore pushNESButton:PVNESButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [nesCore pushNESButton:PVNESButtonDown forPlayer:0];
            [nesCore pushNESButton:PVNESButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
	[super dPad:dPad didPressDirection:direction];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    
    [nesCore releaseNESButton:PVNESButtonUp forPlayer:0];
    [nesCore releaseNESButton:PVNESButtonDown forPlayer:0];
    [nesCore releaseNESButton:PVNESButtonLeft forPlayer:0];
    [nesCore releaseNESButton:PVNESButtonRight forPlayer:0];
	[super dPadDidReleaseDirection:dPad];
}

- (void)buttonPressed:(JSButton *)button
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    [nesCore pushNESButton:[button tag] forPlayer:0];
    
	[super buttonPressed:button];
}

- (void)buttonReleased:(JSButton *)button
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    [nesCore releaseNESButton:[button tag] forPlayer:0];
	[super buttonReleased:button];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    [nesCore pushNESButton:PVNESButtonStart forPlayer:player];
	[super pressStartForPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    [nesCore releaseNESButton:PVNESButtonStart forPlayer:player];
	[super releaseStartForPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    [nesCore pushNESButton:PVNESButtonSelect forPlayer:player];
	[super pressSelectForPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    PVFCEUEmulatorCore *nesCore = (PVFCEUEmulatorCore *)self.emulatorCore;
    [nesCore releaseNESButton:PVNESButtonSelect forPlayer:player];
	[super releaseSelectForPlayer:player];
}

@end
