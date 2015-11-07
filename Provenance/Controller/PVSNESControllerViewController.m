//
//  PVSNESControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 12/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVSNESControllerViewController.h"
#import "PVSNESEmulatorCore.h"

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
	
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
	[snesCore releaseSNESButton:PVSNESButtonUp forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonDown forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonLeft forPlayer:0];
	[snesCore releaseSNESButton:PVSNESButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore pushSNESButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
    [snesCore releaseSNESButton:[button tag] forPlayer:0];
}

- (void)controllerPressedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;

    switch (button) {
        case PVControllerButtonX:
            [snesCore pushSNESButton:PVSNESButtonY forPlayer:player];
            break;
        case PVControllerButtonA:
            [snesCore pushSNESButton:PVSNESButtonB forPlayer:player];
            break;
        case PVControllerButtonB:
            [snesCore pushSNESButton:PVSNESButtonA forPlayer:player];
            break;
        case PVControllerButtonY:
            [snesCore pushSNESButton:PVSNESButtonX forPlayer:player];
            break;
        case PVControllerButtonLeftShoulder:
            [snesCore pushSNESButton:PVSNESButtonTriggerLeft forPlayer:player];
            break;
        case PVControllerButtonRightShoulder:
            [snesCore pushSNESButton:PVSNESButtonTriggerRight forPlayer:player];
            break;
        case PVControllerButtonLeftTrigger:
            [snesCore pushSNESButton:PVSNESButtonStart forPlayer:player];
            break;
        case PVControllerButtonRightTrigger:
            [snesCore pushSNESButton:PVSNESButtonSelect forPlayer:player];
            break;
        default:
            break;
    }
}

- (void)controllerReleasedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
	PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;
	
    switch (button) {
        case PVControllerButtonX:
            [snesCore releaseSNESButton:PVSNESButtonY forPlayer:player];
            break;
        case PVControllerButtonA:
            [snesCore releaseSNESButton:PVSNESButtonB forPlayer:player];
            break;
        case PVControllerButtonB:
            [snesCore releaseSNESButton:PVSNESButtonA forPlayer:player];
            break;
        case PVControllerButtonY:
            [snesCore releaseSNESButton:PVSNESButtonX forPlayer:player];
            break;
        case PVControllerButtonLeftShoulder:
            [snesCore releaseSNESButton:PVSNESButtonTriggerLeft forPlayer:player];
            break;
        case PVControllerButtonRightShoulder:
            [snesCore releaseSNESButton:PVSNESButtonTriggerRight forPlayer:player];
            break;
        case PVControllerButtonLeftTrigger:
            [snesCore releaseSNESButton:PVSNESButtonStart forPlayer:player];
            break;
        case PVControllerButtonRightTrigger:
            [snesCore releaseSNESButton:PVSNESButtonSelect forPlayer:player];
            break;
        default:
            break;
    }
}

- (void)controllerDirectionValueChanged:(GCControllerDirectionPad *)dpad forPlayer:(NSInteger)player
{
    PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;

    float xAxis = [[dpad xAxis] value];
    float yAxis = [[dpad yAxis] value];
    float deadzone = [[PVSettingsModel sharedInstance] dPadDeadzoneValue];

    if (xAxis > deadzone || xAxis < -deadzone)
    {
        if (xAxis > deadzone)
        {
            [snesCore pushSNESButton:PVSNESButtonRight forPlayer:player];
            [snesCore releaseSNESButton:PVSNESButtonLeft forPlayer:player];
        }
        else if (xAxis < -deadzone)
        {
            [snesCore pushSNESButton:PVSNESButtonLeft forPlayer:player];
            [snesCore releaseSNESButton:PVSNESButtonRight forPlayer:player];
        }
    }
    else
    {
        [snesCore releaseSNESButton:PVSNESButtonRight forPlayer:player];
        [snesCore releaseSNESButton:PVSNESButtonLeft forPlayer:player];
    }
    
    if (yAxis > deadzone || yAxis < -deadzone)
    {
        if (yAxis > deadzone)
        {
            [snesCore pushSNESButton:PVSNESButtonUp forPlayer:player];
            [snesCore releaseSNESButton:PVSNESButtonDown forPlayer:player];
        }
        else if (yAxis < -deadzone)
        {
            [snesCore pushSNESButton:PVSNESButtonDown forPlayer:player];
            [snesCore releaseSNESButton:PVSNESButtonUp forPlayer:player];
        }
    }
    else
    {
        [snesCore releaseSNESButton:PVSNESButtonDown forPlayer:player];
        [snesCore releaseSNESButton:PVSNESButtonUp forPlayer:player];
    }
}

@end
