//
//  PVGenesisControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGenesisControllerViewController.h"
#import "PVGenesisEmulatorCore.h"
#import "PVSettingsModel.h"
#import <AudioToolbox/AudioToolbox.h>

@interface PVGenesisControllerViewController ()

@end

@implementation PVGenesisControllerViewController

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
            [button setTag:PVGenesisButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"] || [[[button titleLabel] text] isEqualToString:@"1"])
        {
            [button setTag:PVGenesisButtonB];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"C"] || [[[button titleLabel] text] isEqualToString:@"2"])
        {
            [button setTag:PVGenesisButtonC];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"X"])
        {
            [button setTag:PVGenesisButtonX];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Y"])
        {
            [button setTag:PVGenesisButtonY];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Z"])
        {
            [button setTag:PVGenesisButtonZ];
        }
    }
    
    [self.startButton setTag:PVGenesisButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	[genesisCore releaseGenesisButton:PVGenesisButtonUp];
	[genesisCore releaseGenesisButton:PVGenesisButtonDown];
	[genesisCore releaseGenesisButton:PVGenesisButtonLeft];
	[genesisCore releaseGenesisButton:PVGenesisButtonRight];

	switch (direction)
	{
		case JSDPadDirectionUpLeft:
			[genesisCore pushGenesisButton:PVGenesisButtonUp];
			[genesisCore pushGenesisButton:PVGenesisButtonLeft];
			break;
		case JSDPadDirectionUp:
			[genesisCore pushGenesisButton:PVGenesisButtonUp];
			break;
		case JSDPadDirectionUpRight:
			[genesisCore pushGenesisButton:PVGenesisButtonUp];
			[genesisCore pushGenesisButton:PVGenesisButtonRight];
			break;
		case JSDPadDirectionLeft:
			[genesisCore pushGenesisButton:PVGenesisButtonLeft];
			break;
		case JSDPadDirectionRight:
			[genesisCore pushGenesisButton:PVGenesisButtonRight];
			break;
		case JSDPadDirectionDownLeft:
			[genesisCore pushGenesisButton:PVGenesisButtonDown];
			[genesisCore pushGenesisButton:PVGenesisButtonLeft];
			break;
		case JSDPadDirectionDown:
			[genesisCore pushGenesisButton:PVGenesisButtonDown];
			break;
		case JSDPadDirectionDownRight:
			[genesisCore pushGenesisButton:PVGenesisButtonDown];
			[genesisCore pushGenesisButton:PVGenesisButtonRight];
			break;
		default:
			break;
	}
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	[genesisCore releaseGenesisButton:PVGenesisButtonUp];
	[genesisCore releaseGenesisButton:PVGenesisButtonDown];
	[genesisCore releaseGenesisButton:PVGenesisButtonLeft];
	[genesisCore releaseGenesisButton:PVGenesisButtonRight];
}

- (void)buttonPressed:(JSButton *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
    [genesisCore pushGenesisButton:[button tag]];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
    [genesisCore releaseGenesisButton:[button tag]];
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	if ([button isEqual:_x])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonA];
	}
	else if ([button isEqual:_a])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonB];
	}
	else if ([button isEqual:_b])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonC];
	}
    else if ([button isEqual:_leftShoulder])
    {
        [genesisCore pushGenesisButton:PVGenesisButtonX];
    }
	else if ([button isEqual:_y])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonY];
	}
    else if ([button isEqual:_rightShoulder])
    {
        [genesisCore pushGenesisButton:PVGenesisButtonZ];
    }
    else if ([button isEqual:_leftTrigger])
    {
        [genesisCore pushGenesisButton:PVGenesisButtonStart];
    }
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
    PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
    
    if ([button isEqual:_x])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonA];
    }
    else if ([button isEqual:_a])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonB];
    }
    else if ([button isEqual:_b])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonC];
    }
    else if ([button isEqual:_leftShoulder])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonX];
    }
    else if ([button isEqual:_y])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonY];
    }
    else if ([button isEqual:_rightShoulder])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonZ];
    }
    else if ([button isEqual:_leftTrigger])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonStart];
    }
}

- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	[genesisCore releaseGenesisButton:PVGenesisButtonUp];
	[genesisCore releaseGenesisButton:PVGenesisButtonDown];
	[genesisCore releaseGenesisButton:PVGenesisButtonLeft];
	[genesisCore releaseGenesisButton:PVGenesisButtonRight];
	
	if ([[dpad xAxis] value] > 0)
	{
		[genesisCore pushGenesisButton:PVGenesisButtonRight];
	}
	if ([[dpad xAxis] value] < -0)
	{
		[genesisCore pushGenesisButton:PVGenesisButtonLeft];
	}
	if ([[dpad yAxis] value] > 0)
	{
		[genesisCore pushGenesisButton:PVGenesisButtonUp];
	}
	if ([[dpad yAxis] value] < 0)
	{
		[genesisCore pushGenesisButton:PVGenesisButtonDown];
	}
}

- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	[genesisCore releaseGenesisButton:PVGenesisButtonUp];
	[genesisCore releaseGenesisButton:PVGenesisButtonDown];
	[genesisCore releaseGenesisButton:PVGenesisButtonLeft];
	[genesisCore releaseGenesisButton:PVGenesisButtonRight];
}

@end
