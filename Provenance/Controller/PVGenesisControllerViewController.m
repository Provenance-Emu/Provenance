//
//  PVGenesisControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGenesisControllerViewController.h"
#import "PVGenesisEmulatorCore.h"

@interface PVGenesisControllerViewController ()

@end

@implementation PVGenesisControllerViewController

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
	
	if ([[[button titleLabel] text] isEqualToString:@"A"])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonA];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"B"] || [[[button titleLabel] text] isEqualToString:@"1"])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonB];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"C"] || [[[button titleLabel] text] isEqualToString:@"2"])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonC];
	}
    else if ([[[button titleLabel] text] isEqualToString:@"X"])
    {
        [genesisCore pushGenesisButton:PVGenesisButtonX];
    }
    else if ([[[button titleLabel] text] isEqualToString:@"Y"])
    {
        [genesisCore pushGenesisButton:PVGenesisButtonY];
    }
    else if ([[[button titleLabel] text] isEqualToString:@"Z"])
    {
        [genesisCore pushGenesisButton:PVGenesisButtonZ];
    }
	else if ([[[button titleLabel] text] isEqualToString:@"Start"] || [[[button titleLabel] text] isEqualToString:@"Pause"])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonStart];
	}
}

- (void)buttonReleased:(JSButton *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	if ([[[button titleLabel] text] isEqualToString:@"A"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonA];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"B"] || [[[button titleLabel] text] isEqualToString:@"1"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonB];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"C"] || [[[button titleLabel] text] isEqualToString:@"2"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonC];
	}
    else if ([[[button titleLabel] text] isEqualToString:@"X"])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonX];
    }
    else if ([[[button titleLabel] text] isEqualToString:@"Y"])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonY];
    }
    else if ([[[button titleLabel] text] isEqualToString:@"Z"])
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonZ];
    }
	else if ([[[button titleLabel] text] isEqualToString:@"Start"] || [[[button titleLabel] text] isEqualToString:@"Pause"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonStart];
	}
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	if ([button isEqual:[[self.gameController extendedGamepad] buttonX]])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonA];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonA]])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonB];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonB]])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonC];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonY]])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonStart];
	}
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	if ([button isEqual:[[self.gameController extendedGamepad] buttonX]])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonA];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonA]])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonB];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonB]])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonC];
	}
	else if ([button isEqual:[[self.gameController extendedGamepad] buttonY]])
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
