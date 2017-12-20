//
//  PVPCEControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 03/206/17.
//  Copyright © 2017 James Addyman. All rights reserved.
//

#import "PVPCEControllerViewController.h"
#import <PVMednafen/MednafenGameCore.h>

@interface PVPCEControllerViewController ()

@end

@implementation PVPCEControllerViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    for (JSButton *button in [self.buttonGroup subviews])
    {
        if (![button isMemberOfClass:[JSButton class]])
        {
            continue; // skip over the PVButtonGroupOverlayView
        }
        
        if ([[[button titleLabel] text] isEqualToString:@"I"])
        {
            [button setTag:OEPCEButton1];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"II"])
        {
            [button setTag:OEPCEButton2];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"III"])
        {
            [button setTag:OEPCEButton3];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"IV"])
        {
            [button setTag:OEPCEButton4];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"V"])
        {
            [button setTag:OEPCEButton5];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"VI"])
        {
            [button setTag:OEPCEButton6];
        }
    }
	
    [self.selectButton setTag:OEPCEButtonSelect];
    [self.startButton setTag:OEPCEButtonRun];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    
    [pceCore didReleasePCEButton:OEPCEButtonUp forPlayer:0];
    [pceCore didReleasePCEButton:OEPCEButtonDown forPlayer:0];
    [pceCore didReleasePCEButton:OEPCEButtonLeft forPlayer:0];
    [pceCore didReleasePCEButton:OEPCEButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [pceCore didPushPCEButton:OEPCEButtonUp forPlayer:0];
            [pceCore didPushPCEButton:OEPCEButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [pceCore didPushPCEButton:OEPCEButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [pceCore didPushPCEButton:OEPCEButtonUp forPlayer:0];
            [pceCore didPushPCEButton:OEPCEButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [pceCore didPushPCEButton:OEPCEButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [pceCore didPushPCEButton:OEPCEButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [pceCore didPushPCEButton:OEPCEButtonDown forPlayer:0];
            [pceCore didPushPCEButton:OEPCEButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [pceCore didPushPCEButton:OEPCEButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [pceCore didPushPCEButton:OEPCEButtonDown forPlayer:0];
            [pceCore didPushPCEButton:OEPCEButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    
    [pceCore didReleasePCEButton:OEPCEButtonUp forPlayer:0];
    [pceCore didReleasePCEButton:OEPCEButtonDown forPlayer:0];
    [pceCore didReleasePCEButton:OEPCEButtonLeft forPlayer:0];
    [pceCore didReleasePCEButton:OEPCEButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    [pceCore didPushPCEButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    [pceCore didReleasePCEButton:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    [pceCore didPushPCEButton:OEPCEButtonMode forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    [pceCore didReleasePCEButton:OEPCEButtonMode forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    [pceCore didPushPCEButton:OEPCEButtonSelect forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *pceCore = (MednafenGameCore *)self.emulatorCore;
    [pceCore didReleasePCEButton:OEPCEButtonSelect forPlayer:player];
}

@end
