//
//  PVPSXControllerViewController.m
//  Provenance
//
//  Created by shruglins on 26/8/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVPSXControllerViewController.h"
#import <PVMednafen/MednafenGameCore.h>

@interface PVPSXControllerViewController ()

@end

@implementation PVPSXControllerViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    for (JSButton *button in [self.buttonGroup subviews])
    {
        if (![button isMemberOfClass:[JSButton class]])
        {
            continue; // skip over the PVButtonGroupOverlayView
        }
        
        if ([[[button titleLabel] text] isEqualToString:@"✖"])
        {
            [button setTag:PVPSXButtonCross];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"●"])
        {
            [button setTag:PVPSXButtonCircle];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"◼"])
        {
            [button setTag:PVPSXButtonSquare];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"▲"])
        {
            [button setTag:PVPSXButtonTriangle];
        }
    }
    
    [self.leftShoulderButton setTag:PVPSXButtonL1];
    [self.rightShoulderButton setTag:PVPSXButtonR1];

    [self.selectButton setTag:PVPSXButtonSelect];
    [self.startButton setTag:PVPSXButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    
    [psxCore didReleasePSXButton:PVPSXButtonUp forPlayer:0];
    [psxCore didReleasePSXButton:PVPSXButtonDown forPlayer:0];
    [psxCore didReleasePSXButton:PVPSXButtonLeft forPlayer:0];
    [psxCore didReleasePSXButton:PVPSXButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [psxCore didPushPSXButton:PVPSXButtonUp forPlayer:0];
            [psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [psxCore didPushPSXButton:PVPSXButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [psxCore didPushPSXButton:PVPSXButtonUp forPlayer:0];
            [psxCore didPushPSXButton:PVPSXButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [psxCore didPushPSXButton:PVPSXButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [psxCore didPushPSXButton:PVPSXButtonDown forPlayer:0];
            [psxCore didPushPSXButton:PVPSXButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [psxCore didPushPSXButton:PVPSXButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [psxCore didPushPSXButton:PVPSXButtonDown forPlayer:0];
            [psxCore didPushPSXButton:PVPSXButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    
    [psxCore didReleasePSXButton:PVPSXButtonUp forPlayer:0];
    [psxCore didReleasePSXButton:PVPSXButtonDown forPlayer:0];
    [psxCore didReleasePSXButton:PVPSXButtonLeft forPlayer:0];
    [psxCore didReleasePSXButton:PVPSXButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didPushPSXButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didReleasePSXButton:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didPushPSXButton:PVPSXButtonStart forPlayer:player];
	psxCore.isStartPressed = YES;
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didReleasePSXButton:PVPSXButtonStart forPlayer:player];
	psxCore.isStartPressed = NO;
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didPushPSXButton:PVPSXButtonSelect forPlayer:player];
	psxCore.isSelectPressed = YES;
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didReleasePSXButton:PVPSXButtonSelect forPlayer:player];
	psxCore.isSelectPressed = NO;
}

@end
