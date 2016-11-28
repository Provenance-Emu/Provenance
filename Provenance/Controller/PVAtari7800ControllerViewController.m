//
//  PVAtari7800ControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 05/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVAtari7800ControllerViewController.h"
#import <ProSystem/ProSystemGameCore.h>

@interface PVAtari7800ControllerViewController ()

@end

@implementation PVAtari7800ControllerViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    for (JSButton *button in [self.buttonGroup subviews])
    {
        if (![button isMemberOfClass:[JSButton class]])
        {
            continue; // skip over the PVButtonGroupOverlayView
        }
        
        if ([[[button titleLabel] text] isEqualToString:@"Fire 1"]) {
            [button setTag:OE7800ButtonFire1];
        } else  if ([[[button titleLabel] text] isEqualToString:@"Fire 2"]) {
            [button setTag:OE7800ButtonFire2];
        } else if ([[[button titleLabel] text] isEqualToString:@"Select"]) {
            [button setTag:OE7800ButtonSelect];
        } else if ([[[button titleLabel] text] isEqualToString:@"Reset"]) {
            [button setTag:OE7800ButtonReset];
        } else if ([[[button titleLabel] text] isEqualToString:@"Pause"]) {
            [button setTag:OE7800ButtonPause];
        }
    }
    
    self.startButton.tag  = OE7800ButtonReset;
    self.selectButton.tag = OE7800ButtonSelect;
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    
    [proSystemCore didRelease7800Button:OE7800ButtonUp forPlayer:0];
    [proSystemCore didRelease7800Button:OE7800ButtonDown forPlayer:0];
    [proSystemCore didRelease7800Button:OE7800ButtonLeft forPlayer:0];
    [proSystemCore didRelease7800Button:OE7800ButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [proSystemCore didPush7800Button:OE7800ButtonUp forPlayer:0];
            [proSystemCore didPush7800Button:OE7800ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [proSystemCore didPush7800Button:OE7800ButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [proSystemCore didPush7800Button:OE7800ButtonUp forPlayer:0];
            [proSystemCore didPush7800Button:OE7800ButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [proSystemCore didPush7800Button:OE7800ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [proSystemCore didPush7800Button:OE7800ButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [proSystemCore didPush7800Button:OE7800ButtonDown forPlayer:0];
            [proSystemCore didPush7800Button:OE7800ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [proSystemCore didPush7800Button:OE7800ButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [proSystemCore didPush7800Button:OE7800ButtonDown forPlayer:0];
            [proSystemCore didPush7800Button:OE7800ButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    
    [proSystemCore didRelease7800Button:OE7800ButtonUp forPlayer:0];
    [proSystemCore didRelease7800Button:OE7800ButtonDown forPlayer:0];
    [proSystemCore didRelease7800Button:OE7800ButtonLeft forPlayer:0];
    [proSystemCore didRelease7800Button:OE7800ButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    OE7800Button tag = button.tag;
    [proSystemCore didPush7800Button:tag forPlayer:0];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    OE7800Button tag = button.tag;
    [proSystemCore didRelease7800Button:tag forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    [proSystemCore didPush7800Button:OE7800ButtonReset forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    [proSystemCore didRelease7800Button:OE7800ButtonReset forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    [proSystemCore didPush7800Button:OE7800ButtonSelect forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    PVProSystemGameCore *proSystemCore = (PVProSystemGameCore *)self.emulatorCore;
    [proSystemCore didRelease7800Button:OE7800ButtonSelect forPlayer:player];
}

@end

