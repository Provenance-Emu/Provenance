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
    
    [gbaCore releaseGBAButton:PVGBAButtonUp];
    [gbaCore releaseGBAButton:PVGBAButtonDown];
    [gbaCore releaseGBAButton:PVGBAButtonLeft];
    [gbaCore releaseGBAButton:PVGBAButtonRight];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [gbaCore pushGBAButton:PVGBAButtonUp];
            [gbaCore pushGBAButton:PVGBAButtonLeft];
            break;
        case JSDPadDirectionUp:
            [gbaCore pushGBAButton:PVGBAButtonUp];
            break;
        case JSDPadDirectionUpRight:
            [gbaCore pushGBAButton:PVGBAButtonUp];
            [gbaCore pushGBAButton:PVGBAButtonRight];
            break;
        case JSDPadDirectionLeft:
            [gbaCore pushGBAButton:PVGBAButtonLeft];
            break;
        case JSDPadDirectionRight:
            [gbaCore pushGBAButton:PVGBAButtonRight];
            break;
        case JSDPadDirectionDownLeft:
            [gbaCore pushGBAButton:PVGBAButtonDown];
            [gbaCore pushGBAButton:PVGBAButtonLeft];
            break;
        case JSDPadDirectionDown:
            [gbaCore pushGBAButton:PVGBAButtonDown];
            break;
        case JSDPadDirectionDownRight:
            [gbaCore pushGBAButton:PVGBAButtonDown];
            [gbaCore pushGBAButton:PVGBAButtonRight];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    [gbaCore releaseGBAButton:PVGBAButtonUp];
    [gbaCore releaseGBAButton:PVGBAButtonDown];
    [gbaCore releaseGBAButton:PVGBAButtonLeft];
    [gbaCore releaseGBAButton:PVGBAButtonRight];
}

- (void)buttonPressed:(JSButton *)button
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    [gbaCore pushGBAButton:[button tag]];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    [gbaCore releaseGBAButton:[button tag]];
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    if ([button isEqual:_b])
    {
        [gbaCore pushGBAButton:PVGBAButtonA];
    }
    else if ([button isEqual:_a])
    {
        [gbaCore pushGBAButton:PVGBAButtonB];
    }
    else if ([button isEqual:_leftShoulder])
    {
        [gbaCore pushGBAButton:PVGBAButtonL];
    }
    else if ([button isEqual:_rightShoulder])
    {
        [gbaCore pushGBAButton:PVGBAButtonR];
    }
    else if ([button isEqual:_x])
    {
        [gbaCore pushGBAButton:PVGBAButtonStart];
    }
    else if ([button isEqual:_y])
    {
        [gbaCore pushGBAButton:PVGBAButtonSelect];
    }
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    if ([button isEqual:_b])
    {
        [gbaCore releaseGBAButton:PVGBAButtonA];
    }
    else if ([button isEqual:_a])
    {
        [gbaCore releaseGBAButton:PVGBAButtonB];
    }
    else if ([button isEqual:_leftShoulder])
    {
        [gbaCore releaseGBAButton:PVGBAButtonL];
    }
    else if ([button isEqual:_rightShoulder])
    {
        [gbaCore releaseGBAButton:PVGBAButtonR];
    }
    else if ([button isEqual:_x])
    {
        [gbaCore releaseGBAButton:PVGBAButtonStart];
    }
    else if ([button isEqual:_y])
    {
        [gbaCore releaseGBAButton:PVGBAButtonSelect];
    }
}

- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    [gbaCore releaseGBAButton:PVGBAButtonUp];
    [gbaCore releaseGBAButton:PVGBAButtonDown];
    [gbaCore releaseGBAButton:PVGBAButtonLeft];
    [gbaCore releaseGBAButton:PVGBAButtonRight];
    
    if ([[dpad xAxis] value] > 0)
    {
        [gbaCore pushGBAButton:PVGBAButtonRight];
    }
    if ([[dpad xAxis] value] < 0)
    {
        [gbaCore pushGBAButton:PVGBAButtonLeft];
    }
    if ([[dpad yAxis] value] > 0)
    {
        [gbaCore pushGBAButton:PVGBAButtonUp];
    }
    if ([[dpad yAxis] value] < 0)
    {
        [gbaCore pushGBAButton:PVGBAButtonDown];
    }
}

- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad
{
    PVGBAEmulatorCore *gbaCore = (PVGBAEmulatorCore *)self.emulatorCore;
    
    [gbaCore releaseGBAButton:PVGBAButtonUp];
    [gbaCore releaseGBAButton:PVGBAButtonDown];
    [gbaCore releaseGBAButton:PVGBAButtonLeft];
    [gbaCore releaseGBAButton:PVGBAButtonRight];
}

@end
