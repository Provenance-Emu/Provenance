//
//  PVAtari5200ControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 11/28/2016.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVAtari5200ControllerViewController.h"
#import <PVAtari800/PVAtari800.h>

@interface PVAtari5200ControllerViewController ()

@end

@implementation PVAtari5200ControllerViewController

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
            [button setTag:OE5200ButtonFire1];
        } else  if ([[[button titleLabel] text] isEqualToString:@"Fire 2"]) {
            [button setTag:OE5200ButtonFire2];
        } else if ([[[button titleLabel] text] isEqualToString:@"Reset"]) {
            [button setTag:OE5200ButtonReset];
        } else if ([[[button titleLabel] text] isEqualToString:@"Pause"]) {
            [button setTag:OE5200ButtonPause];
        }
    }
    
    self.startButton.tag  = OE5200ButtonReset;
    self.selectButton.tag = OE5200ButtonPause;
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    
    [a800SystemCore didRelease5200Button:OE5200ButtonUp forPlayer:0];
    [a800SystemCore didRelease5200Button:OE5200ButtonDown forPlayer:0];
    [a800SystemCore didRelease5200Button:OE5200ButtonLeft forPlayer:0];
    [a800SystemCore didRelease5200Button:OE5200ButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [a800SystemCore didPush5200Button:OE5200ButtonUp forPlayer:0];
            [a800SystemCore didPush5200Button:OE5200ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [a800SystemCore didPush5200Button:OE5200ButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [a800SystemCore didPush5200Button:OE5200ButtonUp forPlayer:0];
            [a800SystemCore didPush5200Button:OE5200ButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [a800SystemCore didPush5200Button:OE5200ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [a800SystemCore didPush5200Button:OE5200ButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [a800SystemCore didPush5200Button:OE5200ButtonDown forPlayer:0];
            [a800SystemCore didPush5200Button:OE5200ButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [a800SystemCore didPush5200Button:OE5200ButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [a800SystemCore didPush5200Button:OE5200ButtonDown forPlayer:0];
            [a800SystemCore didPush5200Button:OE5200ButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    
    [a800SystemCore didRelease5200Button:OE5200ButtonUp forPlayer:0];
    [a800SystemCore didRelease5200Button:OE5200ButtonDown forPlayer:0];
    [a800SystemCore didRelease5200Button:OE5200ButtonLeft forPlayer:0];
    [a800SystemCore didRelease5200Button:OE5200ButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    OE5200Button tag = button.tag;
    [a800SystemCore didPush5200Button:tag forPlayer:0];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    OE5200Button tag = button.tag;
    [a800SystemCore didRelease5200Button:tag forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    [a800SystemCore didPush5200Button:OE5200ButtonReset forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    [a800SystemCore didRelease5200Button:OE5200ButtonReset forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    [a800SystemCore didPush5200Button:OE5200ButtonPause forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    ATR800GameCore *a800SystemCore = (ATR800GameCore *)self.emulatorCore;
    [a800SystemCore didRelease5200Button:OE5200ButtonPause forPlayer:player];
}

@end

