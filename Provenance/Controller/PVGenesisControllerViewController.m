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
	else if ([[[button titleLabel] text] isEqualToString:@"B"])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonB];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"C"])
	{
		[genesisCore pushGenesisButton:PVGenesisButtonC];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"Start"])
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
	else if ([[[button titleLabel] text] isEqualToString:@"B"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonB];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"C"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonC];
	}
	else if ([[[button titleLabel] text] isEqualToString:@"Start"])
	{
		[genesisCore releaseGenesisButton:PVGenesisButtonStart];
	}
}

@end
