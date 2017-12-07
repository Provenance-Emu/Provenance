//
//  PVVBControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 12/21/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVVBControllerViewController.h"
#import <PVMednafen/MednafenGameCore.h>

@interface PVVBControllerViewController ()

@end

@implementation PVVBControllerViewController

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
            [button setTag:OEVBButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:OEVBButtonB];
        }
    }
    
    [self.leftShoulderButton setTag:OEVBButtonL];
    [self.rightShoulderButton setTag:OEVBButtonR];

    [self.selectButton setTag:OEVBButtonSelect];
    [self.startButton setTag:OEVBButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    
    [vbCore didReleaseVBButton:OEVBButtonLeftUp forPlayer:0];
    [vbCore didReleaseVBButton:OEVBButtonLeftDown forPlayer:0];
    [vbCore didReleaseVBButton:OEVBButtonLeftLeft forPlayer:0];
    [vbCore didReleaseVBButton:OEVBButtonLeftRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [vbCore didPushVBButton:OEVBButtonLeftUp forPlayer:0];
            [vbCore didPushVBButton:OEVBButtonLeftLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [vbCore didPushVBButton:OEVBButtonLeftUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [vbCore didPushVBButton:OEVBButtonLeftUp forPlayer:0];
            [vbCore didPushVBButton:OEVBButtonLeftRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [vbCore didPushVBButton:OEVBButtonLeftLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [vbCore didPushVBButton:OEVBButtonLeftRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [vbCore didPushVBButton:OEVBButtonLeftDown forPlayer:0];
            [vbCore didPushVBButton:OEVBButtonLeftLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [vbCore didPushVBButton:OEVBButtonLeftDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [vbCore didPushVBButton:OEVBButtonLeftDown forPlayer:0];
            [vbCore didPushVBButton:OEVBButtonLeftRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    
    [vbCore didReleaseVBButton:OEVBButtonLeftUp forPlayer:0];
    [vbCore didReleaseVBButton:OEVBButtonLeftDown forPlayer:0];
    [vbCore didReleaseVBButton:OEVBButtonLeftLeft forPlayer:0];
    [vbCore didReleaseVBButton:OEVBButtonLeftRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    [vbCore didPushVBButton:[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    [vbCore didReleaseVBButton:[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    [vbCore didPushVBButton:OEVBButtonStart forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    [vbCore didReleaseVBButton:OEVBButtonStart forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    [vbCore didPushVBButton:OEVBButtonSelect forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MednafenGameCore *vbCore = (MednafenGameCore *)self.emulatorCore;
    [vbCore didReleaseVBButton:OEVBButtonSelect forPlayer:player];
}

@end
