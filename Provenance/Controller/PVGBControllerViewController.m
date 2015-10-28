//
//  PVGBControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 22/03/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVGBControllerViewController.h"
#import "PVGBEmulatorCore.h"

@interface PVGBControllerViewController ()

@end

@implementation PVGBControllerViewController

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
            [button setTag:PVGBButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:PVGBButtonB];
        }
    }
    
    [self.startButton setTag:PVGBButtonStart];
    [self.selectButton setTag:PVGBButtonSelect];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;
    
    [gbCore releaseGBButton:PVGBButtonUp];
    [gbCore releaseGBButton:PVGBButtonDown];
    [gbCore releaseGBButton:PVGBButtonLeft];
    [gbCore releaseGBButton:PVGBButtonRight];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [gbCore pushGBButton:PVGBButtonUp];
            [gbCore pushGBButton:PVGBButtonLeft];
            break;
        case JSDPadDirectionUp:
            [gbCore pushGBButton:PVGBButtonUp];
            break;
        case JSDPadDirectionUpRight:
            [gbCore pushGBButton:PVGBButtonUp];
            [gbCore pushGBButton:PVGBButtonRight];
            break;
        case JSDPadDirectionLeft:
            [gbCore pushGBButton:PVGBButtonLeft];
            break;
        case JSDPadDirectionRight:
            [gbCore pushGBButton:PVGBButtonRight];
            break;
        case JSDPadDirectionDownLeft:
            [gbCore pushGBButton:PVGBButtonDown];
            [gbCore pushGBButton:PVGBButtonLeft];
            break;
        case JSDPadDirectionDown:
            [gbCore pushGBButton:PVGBButtonDown];
            break;
        case JSDPadDirectionDownRight:
            [gbCore pushGBButton:PVGBButtonDown];
            [gbCore pushGBButton:PVGBButtonRight];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;
    
    [gbCore releaseGBButton:PVGBButtonUp];
    [gbCore releaseGBButton:PVGBButtonDown];
    [gbCore releaseGBButton:PVGBButtonLeft];
    [gbCore releaseGBButton:PVGBButtonRight];
}

- (void)buttonPressed:(JSButton *)button
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;
    [gbCore pushGBButton:[button tag]];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;
    [gbCore releaseGBButton:[button tag]];
}

- (void)controllerPressedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;

    switch (button) {
        case PVControllerButtonA:
            [gbCore pushGBButton:PVGBButtonB];
            break;
        case PVControllerButtonB:
            [gbCore pushGBButton:PVGBButtonA];
            break;
        case PVControllerButtonX:
        case PVControllerButtonLeftShoulder:
        case PVControllerButtonLeftTrigger:
            [gbCore pushGBButton:PVGBButtonStart];
            break;
        case PVControllerButtonY:
        case PVControllerButtonRightShoulder:
        case PVControllerButtonRightTrigger:
            [gbCore pushGBButton:PVGBButtonSelect];
            break;
        default:
            break;
    }
}

- (void)controllerReleasedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;
    
    switch (button) {
        case PVControllerButtonA:
            [gbCore releaseGBButton:PVGBButtonB];
            break;
        case PVControllerButtonB:
            [gbCore releaseGBButton:PVGBButtonA];
            break;
        case PVControllerButtonX:
        case PVControllerButtonLeftShoulder:
        case PVControllerButtonLeftTrigger:
            [gbCore releaseGBButton:PVGBButtonStart];
            break;
        case PVControllerButtonY:
        case PVControllerButtonRightShoulder:
        case PVControllerButtonRightTrigger:
            [gbCore releaseGBButton:PVGBButtonSelect];
            break;
        default:
            break;
    }
}

- (void)controllerDirectionValueChanged:(GCControllerDirectionPad *)dpad forPlayer:(NSInteger)player
{
    PVGBEmulatorCore *gbCore = (PVGBEmulatorCore *)self.emulatorCore;

    float xAxis = [[dpad xAxis] value];
    float yAxis = [[dpad yAxis] value];
    if (xAxis != 0)
    {
        if (xAxis > 0)
        {
            [gbCore pushGBButton:PVGBButtonRight];
            [gbCore releaseGBButton:PVGBButtonLeft];
        }
        else if (xAxis < 0)
        {
            [gbCore pushGBButton:PVGBButtonLeft];
            [gbCore releaseGBButton:PVGBButtonRight];
        }
    }
    else
    {
        [gbCore releaseGBButton:PVGBButtonRight];
        [gbCore releaseGBButton:PVGBButtonLeft];
    }

    if (yAxis != 0)
    {
        if (yAxis > 0)
        {
            [gbCore pushGBButton:PVGBButtonUp];
            [gbCore releaseGBButton:PVGBButtonDown];
        }
        else if (yAxis < 0)
        {
            [gbCore pushGBButton:PVGBButtonDown];
            [gbCore releaseGBButton:PVGBButtonUp];
        }
    }
    else
    {
        [gbCore releaseGBButton:PVGBButtonDown];
        [gbCore releaseGBButton:PVGBButtonUp];
    }
}

@end
