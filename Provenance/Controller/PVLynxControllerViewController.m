//
//  PVLynxControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVLynxControllerViewController.h"
#import <PVMednafen/MednafenGameCore.h>

@interface PVLynxControllerViewController ()

@end

@implementation PVLynxControllerViewController

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
            [button setTag:OELynxButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:OELynxButtonB];
        }
    }
    
    [self.leftShoulderButton setTag:OELynxButtonOption1];
    [self.rightShoulderButton setTag:OELynxButtonOption2];
    [self.selectButton setTag:OELynxButtonOption2];
    [self.startButton setTag:OELynxButtonOption1];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;

    [lynxCore didReleaseLynxButton:OELynxButtonUp forPlayer:0];
    [lynxCore didReleaseLynxButton:OELynxButtonDown forPlayer:0];
    [lynxCore didReleaseLynxButton:OELynxButtonLeft forPlayer:0];
    [lynxCore didReleaseLynxButton:OELynxButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [lynxCore didPushLynxButton:OELynxButtonUp forPlayer:0];
            [lynxCore didPushLynxButton:OELynxButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [lynxCore didPushLynxButton:OELynxButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [lynxCore didPushLynxButton:OELynxButtonUp forPlayer:0];
            [lynxCore didPushLynxButton:OELynxButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [lynxCore didPushLynxButton:OELynxButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [lynxCore didPushLynxButton:OELynxButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [lynxCore didPushLynxButton:OELynxButtonDown forPlayer:0];
            [lynxCore didPushLynxButton:OELynxButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [lynxCore didPushLynxButton:OELynxButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [lynxCore didPushLynxButton:OELynxButtonDown forPlayer:0];
            [lynxCore didPushLynxButton:OELynxButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    
    [lynxCore didReleaseLynxButton:OELynxButtonUp forPlayer:0];
    [lynxCore didReleaseLynxButton:OELynxButtonDown forPlayer:0];
    [lynxCore didReleaseLynxButton:OELynxButtonLeft forPlayer:0];
    [lynxCore didReleaseLynxButton:OELynxButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    [lynxCore didPushLynxButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    [lynxCore didReleaseLynxButton:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    [lynxCore didPushLynxButton:OELynxButtonOption1 forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    [lynxCore didReleaseLynxButton:OELynxButtonOption1 forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    [lynxCore didPushLynxButton:OELynxButtonOption2 forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *lynxCore = (MednafenGameCore *)self.emulatorCore;
    [lynxCore didReleaseLynxButton:OELynxButtonOption2 forPlayer:player];
}

@end
