//
//  PVSNESControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 12/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVSNESControllerViewController.h"
#import "PVSNESEmulatorCore.h"
#import "PVSettingsModel.h"
#import <AudioToolbox/AudioToolbox.h>

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
	
	[snesCore releaseSNESButton:PVSNESButtonUp];
	[snesCore releaseSNESButton:PVSNESButtonDown];
	[snesCore releaseSNESButton:PVSNESButtonLeft];
	[snesCore releaseSNESButton:PVSNESButtonRight];
	
	switch (direction)
	{
		case JSDPadDirectionUpLeft:
			[snesCore pushSNESButton:PVSNESButtonUp];
			[snesCore pushSNESButton:PVSNESButtonLeft];
			break;
		case JSDPadDirectionUp:
			[snesCore pushSNESButton:PVSNESButtonUp];
			break;
		case JSDPadDirectionUpRight:
			[snesCore pushSNESButton:PVSNESButtonUp];
			[snesCore pushSNESButton:PVSNESButtonRight];
			break;
		case JSDPadDirectionLeft:
			[snesCore pushSNESButton:PVSNESButtonLeft];
			break;
		case JSDPadDirectionRight:
			[snesCore pushSNESButton:PVSNESButtonRight];
			break;
		case JSDPadDirectionDownLeft:
			[snesCore pushSNESButton:PVSNESButtonDown];
			[snesCore pushSNESButton:PVSNESButtonLeft];
			break;
		case JSDPadDirectionDown:
			[snesCore pushSNESButton:PVSNESButtonDown];
			break;
		case JSDPadDirectionDownRight:
			[snesCore pushSNESButton:PVSNESButtonDown];
			[snesCore pushSNESButton:PVSNESButtonRight];
			break;
		default:
			break;
	}
	
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
	[snesCore releaseSNESButton:PVSNESButtonUp];
	[snesCore releaseSNESButton:PVSNESButtonDown];
	[snesCore releaseSNESButton:PVSNESButtonLeft];
	[snesCore releaseSNESButton:PVSNESButtonRight];
}

- (void)buttonPressed:(JSButton *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore pushSNESButton:[button tag]];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore releaseSNESButton:[button tag]];
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    
	if ([button isEqual:_x])
	{
		[snesCore pushSNESButton:PVSNESButtonY];
	}
	else if ([button isEqual:_a])
	{
		[snesCore pushSNESButton:PVSNESButtonB];
	}
	else if ([button isEqual:_b])
	{
		[snesCore pushSNESButton:PVSNESButtonA];
	}
	else if ([button isEqual:_y])
	{
		[snesCore pushSNESButton:PVSNESButtonX];
	}
    else if ([button isEqual:_leftShoulder])
    {
        [snesCore pushSNESButton:PVSNESButtonTriggerLeft];
    }
    else if ([button isEqual:_rightShoulder])
    {
        [snesCore pushSNESButton:PVSNESButtonTriggerRight];
    }
    else if ([button isEqual:_leftTrigger])
    {
        [snesCore pushSNESButton:PVSNESButtonStart];
    }
    else if ([button isEqual:_rightTrigger])
    {
        [snesCore pushSNESButton:PVSNESButtonSelect];
    }
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
    if ([button isEqual:_x])
    {
        [snesCore releaseSNESButton:PVSNESButtonY];
    }
    else if ([button isEqual:_a])
    {
        [snesCore releaseSNESButton:PVSNESButtonB];
    }
    else if ([button isEqual:_b])
    {
        [snesCore releaseSNESButton:PVSNESButtonA];
    }
    else if ([button isEqual:_y])
    {
        [snesCore releaseSNESButton:PVSNESButtonX];
    }
    else if ([button isEqual:_leftShoulder])
    {
        [snesCore releaseSNESButton:PVSNESButtonTriggerLeft];
    }
    else if ([button isEqual:_rightShoulder])
    {
        [snesCore releaseSNESButton:PVSNESButtonTriggerRight];
    }
    else if ([button isEqual:_leftTrigger])
    {
        [snesCore releaseSNESButton:PVSNESButtonStart];
    }
    else if ([button isEqual:_rightTrigger])
    {
        [snesCore releaseSNESButton:PVSNESButtonSelect];
    }
}

- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
	[snesCore releaseSNESButton:PVSNESButtonUp];
	[snesCore releaseSNESButton:PVSNESButtonDown];
	[snesCore releaseSNESButton:PVSNESButtonLeft];
	[snesCore releaseSNESButton:PVSNESButtonRight];
	
	if ([[dpad xAxis] value] > 0)
	{
		[snesCore pushSNESButton:PVSNESButtonRight];
	}
	if ([[dpad xAxis] value] < 0)
	{
		[snesCore pushSNESButton:PVSNESButtonLeft];
	}
	if ([[dpad yAxis] value] > 0)
	{
		[snesCore pushSNESButton:PVSNESButtonUp];
	}
	if ([[dpad yAxis] value] < 0)
	{
		[snesCore pushSNESButton:PVSNESButtonDown];
	}
}

- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
	[snesCore releaseSNESButton:PVSNESButtonUp];
	[snesCore releaseSNESButton:PVSNESButtonDown];
	[snesCore releaseSNESButton:PVSNESButtonLeft];
	[snesCore releaseSNESButton:PVSNESButtonRight];
}

@end
