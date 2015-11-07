//
//  PVGBAControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 21/03/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVGBAControllerViewController.h"
#import "PVGBAEmulatorCore.h"
#import "PVSettingsModel.h"
#import <AudioToolbox/AudioToolbox.h>

@interface PVGBAControllerViewController ()

@end

@implementation PVGBAControllerViewController

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
            [button setTag:PVGBAButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:PVGBAButtonB];
        }
    }
    
    [self.leftShoulderButton setTag:PVGBAButtonL];
    [self.rightShoulderButton setTag:PVGBAButtonR];
    [self.startButton setTag:PVGBAButtonStart];
    [self.selectButton setTag:PVGBAButtonSelect];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    [gbaCore releaseGBAButton:PVGBAButtonUp forPlayer:0];
    [gbaCore releaseGBAButton:PVGBAButtonDown forPlayer:0];
    [gbaCore releaseGBAButton:PVGBAButtonLeft forPlayer:0];
    [gbaCore releaseGBAButton:PVGBAButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [gbaCore pushGBAButton:PVGBAButtonUp forPlayer:0];
            [gbaCore pushGBAButton:PVGBAButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [gbaCore pushGBAButton:PVGBAButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [gbaCore pushGBAButton:PVGBAButtonUp forPlayer:0];
            [gbaCore pushGBAButton:PVGBAButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [gbaCore pushGBAButton:PVGBAButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [gbaCore pushGBAButton:PVGBAButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [gbaCore pushGBAButton:PVGBAButtonDown forPlayer:0];
            [gbaCore pushGBAButton:PVGBAButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [gbaCore pushGBAButton:PVGBAButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [gbaCore pushGBAButton:PVGBAButtonDown forPlayer:0];
            [gbaCore pushGBAButton:PVGBAButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    [gbaCore releaseGBAButton:PVGBAButtonUp forPlayer:0];
    [gbaCore releaseGBAButton:PVGBAButtonDown forPlayer:0];
    [gbaCore releaseGBAButton:PVGBAButtonLeft forPlayer:0];
    [gbaCore releaseGBAButton:PVGBAButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    [gbaCore pushGBAButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    [gbaCore releaseGBAButton:[button tag] forPlayer:0];
}

- (void)controllerPressedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;

    switch (button) {
        case PVControllerButtonA:
            [gbaCore pushGBAButton:PVGBAButtonB forPlayer:player];
            break;
        case PVControllerButtonB:
            [gbaCore pushGBAButton:PVGBAButtonA forPlayer:player];
            break;
        case PVControllerButtonLeftShoulder:
            [gbaCore pushGBAButton:PVGBAButtonL forPlayer:player];
            break;
        case PVControllerButtonRightShoulder:
            [gbaCore pushGBAButton:PVGBAButtonR forPlayer:player];
            break;
        case PVControllerButtonX:
        case PVControllerButtonLeftTrigger:
            [gbaCore pushGBAButton:PVGBAButtonStart forPlayer:player];
            break;
        case PVControllerButtonY:
        case PVControllerButtonRightTrigger:
            [gbaCore pushGBAButton:PVGBAButtonSelect forPlayer:player];
            break;
        default:
            break;
    }
}

- (void)controllerReleasedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    switch (button) {
        case PVControllerButtonA:
            [gbaCore releaseGBAButton:PVGBAButtonB forPlayer:player];
            break;
        case PVControllerButtonB:
            [gbaCore releaseGBAButton:PVGBAButtonA forPlayer:player];
            break;
        case PVControllerButtonLeftShoulder:
            [gbaCore releaseGBAButton:PVGBAButtonL forPlayer:player];
            break;
        case PVControllerButtonRightShoulder:
            [gbaCore releaseGBAButton:PVGBAButtonR forPlayer:player];
            break;
        case PVControllerButtonX:
        case PVControllerButtonLeftTrigger:
            [gbaCore releaseGBAButton:PVGBAButtonStart forPlayer:player];
            break;
        case PVControllerButtonY:
        case PVControllerButtonRightTrigger:
            [gbaCore releaseGBAButton:PVGBAButtonSelect forPlayer:player];
            break;
        default:
            break;
    }
}

- (void)controllerDirectionValueChanged:(GCControllerDirectionPad *)dpad forPlayer:(NSInteger)player
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;

    float xAxis = [[dpad xAxis] value];
    float yAxis = [[dpad yAxis] value];
    float deadzone = [[PVSettingsModel sharedInstance] dPadDeadzoneValue];

    if (xAxis > deadzone || xAxis < -deadzone)
    {
        if (xAxis > deadzone)
        {
            [gbaCore pushGBAButton:PVGBAButtonRight forPlayer:player];
            [gbaCore releaseGBAButton:PVGBAButtonLeft forPlayer:player];
        }
        else if (xAxis < -deadzone)
        {
            [gbaCore pushGBAButton:PVGBAButtonLeft forPlayer:player];
            [gbaCore releaseGBAButton:PVGBAButtonRight forPlayer:player];
        }
    }
    else
    {
        [gbaCore releaseGBAButton:PVGBAButtonRight forPlayer:player];
        [gbaCore releaseGBAButton:PVGBAButtonLeft forPlayer:player];
    }
    
    if (yAxis > deadzone || yAxis < -deadzone)
    {
        if (yAxis > deadzone)
        {
            [gbaCore pushGBAButton:PVGBAButtonUp forPlayer:player];
            [gbaCore releaseGBAButton:PVGBAButtonDown forPlayer:player];
        }
        else if (yAxis < -deadzone)
        {
            [gbaCore pushGBAButton:PVGBAButtonDown forPlayer:player];
            [gbaCore releaseGBAButton:PVGBAButtonUp forPlayer:player];
        }
    }
    else
    {
        [gbaCore releaseGBAButton:PVGBAButtonDown forPlayer:player];
        [gbaCore releaseGBAButton:PVGBAButtonUp forPlayer:player];
    }
}

@end
