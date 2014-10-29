//
//  PVPSXControllerViewController.m
//  Provenance
//
//  Created by Green2, David on 10/27/14.
//  Copyright (c) 2014 James Addyman. All rights reserved.
//

#import "PVPSXControllerViewController.h"
#import "PVPSXEmulatorCore.h"

@interface PVPSXControllerViewController ()

@end

@implementation PVPSXControllerViewController

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	[psxCore didReleasePSXButton:PVPSXButtonUp forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonDown forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonLeft forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonRight forPlayer:1];
		
	switch (direction)
	{
		case JSDPadDirectionUpLeft:
			[psxCore didPushPSXButton:PVPSXButtonUp forPlayer:1];
			[psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:1];
			break;
		case JSDPadDirectionUp:
			[psxCore didPushPSXButton:PVPSXButtonUp forPlayer:1];
			break;
		case JSDPadDirectionUpRight:
			[psxCore didPushPSXButton:PVPSXButtonUp forPlayer:1];
			[psxCore didPushPSXButton:PVPSXButtonRight forPlayer:1];
			break;
		case JSDPadDirectionLeft:
			[psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:1];
			break;
		case JSDPadDirectionRight:
			[psxCore didPushPSXButton:PVPSXButtonRight forPlayer:1];
			break;
		case JSDPadDirectionDownLeft:
			[psxCore didPushPSXButton:PVPSXButtonDown forPlayer:1];
			[psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:1];
			break;
		case JSDPadDirectionDown:
			[psxCore didPushPSXButton:PVPSXButtonDown forPlayer:1];
			break;
		case JSDPadDirectionDownRight:
			[psxCore didPushPSXButton:PVPSXButtonDown forPlayer:1];
			[psxCore didPushPSXButton:PVPSXButtonRight forPlayer:1];
			break;
		default:
			break;
	}
	
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	[psxCore didReleasePSXButton:PVPSXButtonUp forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonDown forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonLeft forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonRight forPlayer:1];
}

- (void)buttonPressed:(JSButton *)button
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	if ([[[button titleLabel] text] isEqualToString:@"O"])
	{
		[psxCore didPushPSXButton:PVPSXButtonCircle forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"X"])
	{
		[psxCore didPushPSXButton:PVPSXButtonCross forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"▵"])
	{
		[psxCore didPushPSXButton:PVPSXButtonTriangle forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"⬜︎"])
	{
		[psxCore didPushPSXButton:PVPSXButtonSquare forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"L1"])
	{
		[psxCore didPushPSXButton:PVPSXButtonL1 forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"R1"])
	{
		[psxCore didPushPSXButton:PVPSXButtonR1 forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"Start"])
	{
		[psxCore didPushPSXButton:PVPSXButtonStart forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"Select"])
	{
		[psxCore didPushPSXButton:PVPSXButtonSelect forPlayer:1];
	}
}

- (void)buttonReleased:(JSButton *)button
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	if ([[[button titleLabel] text] isEqualToString:@"O"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonCircle forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"X"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonCross forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"▵"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonTriangle forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"⬜︎"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonSquare forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"L1"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonL1 forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"R1"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonR1 forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"Start"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonStart forPlayer:1];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"Select"])
	{
		[psxCore didReleasePSXButton:PVPSXButtonSelect forPlayer:1];
	}
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	if ([button isEqual:[[self.gameController extendedGamepad] buttonX]])
	{
		[psxCore didPushPSXButton:PVPSXButtonSquare forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonA]])
	{
		[psxCore didPushPSXButton:PVPSXButtonCross forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonB]])
	{
		[psxCore didPushPSXButton:PVPSXButtonCircle forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonY]])
	{
		[psxCore didPushPSXButton:PVPSXButtonTriangle forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] leftShoulder]])
	{
		[psxCore didPushPSXButton:PVPSXButtonL1 forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] rightShoulder]])
	{
		[psxCore didPushPSXButton:PVPSXButtonR1 forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] leftTrigger]])
	{
		[psxCore didPushPSXButton:PVPSXButtonL2 forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] rightTrigger]])
	{
		[psxCore didPushPSXButton:PVPSXButtonR2 forPlayer:1];
	}
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	if ([button isEqual:[[self.gameController extendedGamepad] buttonX]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonSquare forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonA]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonCross forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonB]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonCircle forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonY]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonTriangle forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] leftShoulder]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonL1 forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] rightShoulder]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonR1 forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] leftTrigger]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonL2 forPlayer:1];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] rightTrigger]])
	{
		[psxCore didReleasePSXButton:PVPSXButtonR2 forPlayer:1];
	}
}

- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	[psxCore didReleasePSXButton:PVPSXButtonUp forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonDown forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonLeft forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonRight forPlayer:1];
	
	if ([[dpad xAxis] value] > 0)
	{
		[psxCore didPushPSXButton:PVPSXButtonRight forPlayer:1];
	}
	if ([[dpad xAxis] value] < -0)
	{
		[psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:1];
	}
	if ([[dpad yAxis] value] > 0)
	{
		[psxCore didPushPSXButton:PVPSXButtonUp forPlayer:1];
	}
	if ([[dpad yAxis] value] < 0)
	{
		[psxCore didPushPSXButton:PVPSXButtonDown forPlayer:1];
	}
}

- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad
{
	PVPSXEmulatorCore *psxCore = (PVPSXEmulatorCore *)self.emulatorCore;
	
	
	[psxCore didReleasePSXButton:PVPSXButtonUp forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonDown forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonLeft forPlayer:1];
	[psxCore didReleasePSXButton:PVPSXButtonRight forPlayer:1];
}

@end
