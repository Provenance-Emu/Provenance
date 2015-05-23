//
//  PVNESControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 22/03/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVNESControllerViewController.h"
#import "PVNESEmulatorCore.h"

@interface PVNESControllerViewController ()

@end

@implementation PVNESControllerViewController

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
            [button setTag:PVNESButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:PVNESButtonB];
        }
    }
    
    [self.startButton setTag:PVNESButtonStart];
    [self.selectButton setTag:PVNESButtonSelect];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    
    [nesCore releaseNESButton:PVNESButtonUp];
    [nesCore releaseNESButton:PVNESButtonDown];
    [nesCore releaseNESButton:PVNESButtonLeft];
    [nesCore releaseNESButton:PVNESButtonRight];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [nesCore pushNESButton:PVNESButtonUp];
            [nesCore pushNESButton:PVNESButtonLeft];
            break;
        case JSDPadDirectionUp:
            [nesCore pushNESButton:PVNESButtonUp];
            break;
        case JSDPadDirectionUpRight:
            [nesCore pushNESButton:PVNESButtonUp];
            [nesCore pushNESButton:PVNESButtonRight];
            break;
        case JSDPadDirectionLeft:
            [nesCore pushNESButton:PVNESButtonLeft];
            break;
        case JSDPadDirectionRight:
            [nesCore pushNESButton:PVNESButtonRight];
            break;
        case JSDPadDirectionDownLeft:
            [nesCore pushNESButton:PVNESButtonDown];
            [nesCore pushNESButton:PVNESButtonLeft];
            break;
        case JSDPadDirectionDown:
            [nesCore pushNESButton:PVNESButtonDown];
            break;
        case JSDPadDirectionDownRight:
            [nesCore pushNESButton:PVNESButtonDown];
            [nesCore pushNESButton:PVNESButtonRight];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    
    [nesCore releaseNESButton:PVNESButtonUp];
    [nesCore releaseNESButton:PVNESButtonDown];
    [nesCore releaseNESButton:PVNESButtonLeft];
    [nesCore releaseNESButton:PVNESButtonRight];
}

- (void)buttonPressed:(JSButton *)button
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    [nesCore pushNESButton:[button tag]];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    [nesCore releaseNESButton:[button tag]];
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    
    if ([button isEqual:_b])
    {
        [nesCore pushNESButton:PVNESButtonA];
    }
    else if ([button isEqual:_a])
    {
        [nesCore pushNESButton:PVNESButtonB];
    }
    else if ([button isEqual:_x])
    {
        [nesCore pushNESButton:PVNESButtonStart];
    }
    else if ([button isEqual:_y])
    {
        [nesCore pushNESButton:PVNESButtonSelect];
    }
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    
    if ([button isEqual:_b])
    {
        [nesCore releaseNESButton:PVNESButtonA];
    }
    else if ([button isEqual:_a])
    {
        [nesCore releaseNESButton:PVNESButtonB];
    }
    else if ([button isEqual:_x])
    {
        [nesCore releaseNESButton:PVNESButtonStart];
    }
    else if ([button isEqual:_y])
    {
        [nesCore releaseNESButton:PVNESButtonSelect];
    }
}

- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    
    [nesCore releaseNESButton:PVNESButtonUp];
    [nesCore releaseNESButton:PVNESButtonDown];
    [nesCore releaseNESButton:PVNESButtonLeft];
    [nesCore releaseNESButton:PVNESButtonRight];
    
    if ([[dpad xAxis] value] > 0)
    {
        [nesCore pushNESButton:PVNESButtonRight];
    }
    if ([[dpad xAxis] value] < 0)
    {
        [nesCore pushNESButton:PVNESButtonLeft];
    }
    if ([[dpad yAxis] value] > 0)
    {
        [nesCore pushNESButton:PVNESButtonUp];
    }
    if ([[dpad yAxis] value] < 0)
    {
        [nesCore pushNESButton:PVNESButtonDown];
    }
}

- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad
{
    PVNESEmulatorCore *nesCore = (PVNESEmulatorCore *)self.emulatorCore;
    
    [nesCore releaseNESButton:PVNESButtonUp];
    [nesCore releaseNESButton:PVNESButtonDown];
    [nesCore releaseNESButton:PVNESButtonLeft];
    [nesCore releaseNESButton:PVNESButtonRight];
}

@end
