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
	
	[genesisCore releaseGenesisButton:PVGenesisButtonUp forPlayer:0];
	[genesisCore releaseGenesisButton:PVGenesisButtonDown forPlayer:0];
	[genesisCore releaseGenesisButton:PVGenesisButtonLeft forPlayer:0];
	[genesisCore releaseGenesisButton:PVGenesisButtonRight forPlayer:0];

	switch (direction)
	{
		case JSDPadDirectionUpLeft:
			[genesisCore pushGenesisButton:PVGenesisButtonUp forPlayer:0];
			[genesisCore pushGenesisButton:PVGenesisButtonLeft forPlayer:0];
			break;
		case JSDPadDirectionUp:
			[genesisCore pushGenesisButton:PVGenesisButtonUp forPlayer:0];
			break;
		case JSDPadDirectionUpRight:
			[genesisCore pushGenesisButton:PVGenesisButtonUp forPlayer:0];
			[genesisCore pushGenesisButton:PVGenesisButtonRight forPlayer:0];
			break;
		case JSDPadDirectionLeft:
			[genesisCore pushGenesisButton:PVGenesisButtonLeft forPlayer:0];
			break;
		case JSDPadDirectionRight:
			[genesisCore pushGenesisButton:PVGenesisButtonRight forPlayer:0];
			break;
		case JSDPadDirectionDownLeft:
			[genesisCore pushGenesisButton:PVGenesisButtonDown forPlayer:0];
			[genesisCore pushGenesisButton:PVGenesisButtonLeft forPlayer:0];
			break;
		case JSDPadDirectionDown:
			[genesisCore pushGenesisButton:PVGenesisButtonDown forPlayer:0];
			break;
		case JSDPadDirectionDownRight:
			[genesisCore pushGenesisButton:PVGenesisButtonDown forPlayer:0];
			[genesisCore pushGenesisButton:PVGenesisButtonRight forPlayer:0];
			break;
		default:
			break;
	}
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
	
	[genesisCore releaseGenesisButton:PVGenesisButtonUp forPlayer:0];
	[genesisCore releaseGenesisButton:PVGenesisButtonDown forPlayer:0];
	[genesisCore releaseGenesisButton:PVGenesisButtonLeft forPlayer:0];
	[genesisCore releaseGenesisButton:PVGenesisButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
    [genesisCore pushGenesisButton:[button tag] forPlayer:0];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
    [genesisCore releaseGenesisButton:[button tag] forPlayer:0];
}

- (void)controllerPressedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;

    switch (button) {
        case PVControllerButtonX:
            [genesisCore pushGenesisButton:PVGenesisButtonA forPlayer:player];
            break;
        case PVControllerButtonA:
            [genesisCore pushGenesisButton:PVGenesisButtonB forPlayer:player];
            break;
        case PVControllerButtonB:
            [genesisCore pushGenesisButton:PVGenesisButtonC forPlayer:player];
            break;
        case PVControllerButtonLeftShoulder:
            [genesisCore pushGenesisButton:PVGenesisButtonX forPlayer:player];
            break;
        case PVControllerButtonY:
            [genesisCore pushGenesisButton:PVGenesisButtonY forPlayer:player];
            break;
        case PVControllerButtonRightShoulder:
            [genesisCore pushGenesisButton:PVGenesisButtonZ forPlayer:player];
            break;
        case PVControllerButtonLeftTrigger:
            [genesisCore pushGenesisButton:PVGenesisButtonStart forPlayer:player];
            break;
        case PVControllerButtonRightTrigger:
            break;
        default:
            break;
    }

}

- (void)controllerReleasedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;
    
    switch (button) {
        case PVControllerButtonX:
            [genesisCore releaseGenesisButton:PVGenesisButtonA forPlayer:player];
            break;
        case PVControllerButtonA:
            [genesisCore releaseGenesisButton:PVGenesisButtonB forPlayer:player];
            break;
        case PVControllerButtonB:
            [genesisCore releaseGenesisButton:PVGenesisButtonC forPlayer:player];
            break;
        case PVControllerButtonLeftShoulder:
            [genesisCore releaseGenesisButton:PVGenesisButtonX forPlayer:player];
            break;
        case PVControllerButtonY:
            [genesisCore releaseGenesisButton:PVGenesisButtonY forPlayer:player];
            break;
        case PVControllerButtonRightShoulder:
            [genesisCore releaseGenesisButton:PVGenesisButtonZ forPlayer:player];
            break;
        case PVControllerButtonLeftTrigger:
            [genesisCore releaseGenesisButton:PVGenesisButtonStart forPlayer:player];
            break;
        case PVControllerButtonRightTrigger:
            break;
        default:
            break;
    }
}

- (void)controllerDirectionValueChanged:(GCControllerDirectionPad *)dpad forPlayer:(NSInteger)player
{
	PVGenesisEmulatorCore *genesisCore = (PVGenesisEmulatorCore *)self.emulatorCore;

    float xAxis = [[dpad xAxis] value];
    float yAxis = [[dpad yAxis] value];
    float deadzone = [[PVSettingsModel sharedInstance] dPadDeadzoneValue];

    if (xAxis > deadzone || xAxis < -deadzone)
    {
        if (xAxis > deadzone)
        {
            [genesisCore pushGenesisButton:PVGenesisButtonRight forPlayer:player];
            [genesisCore releaseGenesisButton:PVGenesisButtonLeft forPlayer:player];
        }
        else if (xAxis < -deadzone)
        {
            [genesisCore pushGenesisButton:PVGenesisButtonLeft forPlayer:player];
            [genesisCore releaseGenesisButton:PVGenesisButtonRight forPlayer:player];
        }
    }
    else
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonRight forPlayer:player];
        [genesisCore releaseGenesisButton:PVGenesisButtonLeft forPlayer:player];
    }

    if (yAxis > deadzone || yAxis < -deadzone)
    {
        if (yAxis > deadzone)
        {
            [genesisCore pushGenesisButton:PVGenesisButtonUp forPlayer:player];
            [genesisCore releaseGenesisButton:PVGenesisButtonDown forPlayer:player];
        }
        else if (yAxis < -deadzone)
        {
            [genesisCore pushGenesisButton:PVGenesisButtonDown forPlayer:player];
            [genesisCore releaseGenesisButton:PVGenesisButtonUp forPlayer:player];
        }
    }
    else
    {
        [genesisCore releaseGenesisButton:PVGenesisButtonDown forPlayer:player];
        [genesisCore releaseGenesisButton:PVGenesisButtonUp forPlayer:player];
    }
}

@end
