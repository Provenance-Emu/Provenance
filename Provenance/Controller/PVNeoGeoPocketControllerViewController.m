//
//  PVNeoGeoPocketControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 03/06/17.
//  Copyright © 2017 James Addyman. All rights reserved.
//

#import "PVNeoGeoPocketControllerViewController.h"
#import <PVMednafen/MednafenGameCore.h>

@interface PVNeoGeoPocketControllerViewController ()

@end

@implementation PVNeoGeoPocketControllerViewController

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
            [button setTag:OENGPButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:OENGPButtonB];
        }
    }
    
//    [self.leftShoulderButton setTag:PVPSXButtonL1];
//    [self.rightShoulderButton setTag:PVPSXButtonR1];

    [self.selectButton setTag:OENGPButtonOption];
    [self.startButton setTag:OENGPButtonOption];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    
    [ngCore didReleaseNGPButton:OENGPButtonUp forPlayer:0];
    [ngCore didReleaseNGPButton:OENGPButtonDown forPlayer:0];
    [ngCore didReleaseNGPButton:OENGPButtonLeft forPlayer:0];
    [ngCore didReleaseNGPButton:OENGPButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [ngCore didPushNGPButton:OENGPButtonUp forPlayer:0];
            [ngCore didPushNGPButton:OENGPButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [ngCore didPushNGPButton:OENGPButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [ngCore didPushNGPButton:OENGPButtonUp forPlayer:0];
            [ngCore didPushNGPButton:OENGPButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [ngCore didPushNGPButton:OENGPButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [ngCore didPushNGPButton:OENGPButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [ngCore didPushNGPButton:OENGPButtonDown forPlayer:0];
            [ngCore didPushNGPButton:OENGPButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [ngCore didPushNGPButton:OENGPButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [ngCore didPushNGPButton:OENGPButtonDown forPlayer:0];
            [ngCore didPushNGPButton:OENGPButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    
    [ngCore didReleaseNGPButton:OENGPButtonUp forPlayer:0];
    [ngCore didReleaseNGPButton:OENGPButtonDown forPlayer:0];
    [ngCore didReleaseNGPButton:OENGPButtonLeft forPlayer:0];
    [ngCore didReleaseNGPButton:OENGPButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    [ngCore didPushNGPButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    [ngCore didReleaseNGPButton:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    [ngCore didPushNGPButton:OENGPButtonOption forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    [ngCore didReleaseNGPButton:OENGPButtonOption forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    [ngCore didPushNGPButton:OENGPButtonOption forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *ngCore = (MednafenGameCore *)self.emulatorCore;
    [ngCore didReleaseNGPButton:OENGPButtonOption forPlayer:player];
}

@end
