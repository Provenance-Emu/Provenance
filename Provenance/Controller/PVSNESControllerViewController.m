//
//  PVSNESControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 12/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVSNESControllerViewController.h"
#import <PVSNES/PVSNESEmulatorCore.h>

@interface PVSNESControllerViewController ()

@end

@implementation PVSNESControllerViewController

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
            [button setTag:PVSNESButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"] || [[[button titleLabel] text] isEqualToString:@"1"])
        {
            [button setTag:PVSNESButtonB];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"X"] || [[[button titleLabel] text] isEqualToString:@"2"])
        {
            [button setTag:PVSNESButtonX];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Y"])
        {
            [button setTag:PVSNESButtonY];
        }
    }
    
    [self.leftShoulderButton setTag:PVSNESButtonTriggerLeft];
    [self.rightShoulderButton setTag:PVSNESButtonTriggerRight];
    [self.selectButton setTag:PVSNESButtonSelect];
    [self.startButton setTag:PVSNESButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
	[snesCore releaseSNESButton:PVSNESButtonUp forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonDown forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonLeft forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonRight forPlayer:0];
	
	switch (direction)
	{
		case JSDPadDirectionUpLeft:
			[snesCore pushSNESButton:PVSNESButtonUp forPlayer:0];
			[snesCore pushSNESButton:PVSNESButtonLeft forPlayer:0];
			break;
		case JSDPadDirectionUp:
			[snesCore pushSNESButton:PVSNESButtonUp forPlayer:0];
			break;
		case JSDPadDirectionUpRight:
			[snesCore pushSNESButton:PVSNESButtonUp forPlayer:0];
			[snesCore pushSNESButton:PVSNESButtonRight forPlayer:0];
			break;
		case JSDPadDirectionLeft:
			[snesCore pushSNESButton:PVSNESButtonLeft forPlayer:0];
			break;
		case JSDPadDirectionRight:
			[snesCore pushSNESButton:PVSNESButtonRight forPlayer:0];
			break;
		case JSDPadDirectionDownLeft:
			[snesCore pushSNESButton:PVSNESButtonDown forPlayer:0];
			[snesCore pushSNESButton:PVSNESButtonLeft forPlayer:0];
			break;
		case JSDPadDirectionDown:
			[snesCore pushSNESButton:PVSNESButtonDown forPlayer:0];
			break;
		case JSDPadDirectionDownRight:
			[snesCore pushSNESButton:PVSNESButtonDown forPlayer:0];
			[snesCore pushSNESButton:PVSNESButtonRight forPlayer:0];
			break;
		default:
			break;
	}
	
	[super dPad:dPad didPressDirection:direction];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
	[snesCore releaseSNESButton:PVSNESButtonUp forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonDown forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonLeft forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonRight forPlayer:0];
	[super dPadDidReleaseDirection:dPad];
}

- (void)buttonPressed:(JSButton *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore pushSNESButton:[button tag] forPlayer:0];
    
	[super buttonPressed:button];
}

- (void)buttonReleased:(JSButton *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore releaseSNESButton:[button tag] forPlayer:0];
	[super buttonReleased:button];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore pushSNESButton:PVSNESButtonStart forPlayer:player];
	[super pressStartForPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore releaseSNESButton:PVSNESButtonStart forPlayer:player];
	[super releaseStartForPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore pushSNESButton:PVSNESButtonSelect forPlayer:player];
	[super pressSelectForPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore releaseSNESButton:PVSNESButtonSelect forPlayer:player];
	[super releaseSelectForPlayer:player];
}

@end
