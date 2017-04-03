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
        
        if ([[[button titleLabel] text] isEqualToString:@"A"])
        {
            [button setTag:OEPSXButtonCross];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:OEPSXButtonCircle];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"X"])
        {
            [button setTag:OEPSXButtonSquare];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Y"])
        {
            [button setTag:OEPSXButtonTriangle];
        }
    }
    
    [self.leftShoulderButton setTag:OEPSXButtonL1];
    [self.rightShoulderButton setTag:OEPSXButtonR1];

    [self.selectButton setTag:OEPSXButtonSelect];
    [self.startButton setTag:OEPSXButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    
    [psxCore didReleasePSXButton:OEPSXButtonUp forPlayer:0];
    [psxCore didReleasePSXButton:OEPSXButtonDown forPlayer:0];
    [psxCore didReleasePSXButton:OEPSXButtonLeft forPlayer:0];
    [psxCore didReleasePSXButton:OEPSXButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [psxCore didPushPSXButton:OEPSXButtonUp forPlayer:0];
            [psxCore didPushPSXButton:OEPSXButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [psxCore didPushPSXButton:OEPSXButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [psxCore didPushPSXButton:OEPSXButtonUp forPlayer:0];
            [psxCore didPushPSXButton:OEPSXButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [psxCore didPushPSXButton:OEPSXButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [psxCore didPushPSXButton:OEPSXButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [psxCore didPushPSXButton:OEPSXButtonDown forPlayer:0];
            [psxCore didPushPSXButton:OEPSXButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [psxCore didPushPSXButton:OEPSXButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [psxCore didPushPSXButton:OEPSXButtonDown forPlayer:0];
            [psxCore didPushPSXButton:OEPSXButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    
    [psxCore didReleasePSXButton:OEPSXButtonUp forPlayer:0];
    [psxCore didReleasePSXButton:OEPSXButtonDown forPlayer:0];
    [psxCore didReleasePSXButton:OEPSXButtonLeft forPlayer:0];
    [psxCore didReleasePSXButton:OEPSXButtonRight forPlayer:0];
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
    [psxCore didPushPSXButton:OEPSXButtonStart forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didReleasePSXButton:OEPSXButtonStart forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didPushPSXButton:OEPSXButtonSelect forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *psxCore = (MednafenGameCore *)self.emulatorCore;
    [psxCore didReleasePSXButton:OEPSXButtonSelect forPlayer:player];
}

@end
