//
//  PV32XControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 08/22/2016.
//  Copyright (c) 2016 Joe Mattiello. All rights reserved.
//

#import "PV32XControllerViewController.h"
#import <PicoDrive/PicodriveGameCore.h>
#import <PicoDrive/OESega32XSystemResponderClient.h>

@interface PV32XControllerViewController ()

@end

@implementation PV32XControllerViewController

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    for (JSButton *button in [self.buttonGroup subviews])
    {
        if (![button isMemberOfClass:[JSButton class]])
        {
            continue; // skip over the PVButtonGroupOverlayView
        }
        
        if ([[[button titleLabel] text] isEqualToString:@"A"]) {
            [button setTag:OESega32XButtonA];
        } else if ([[[button titleLabel] text] isEqualToString:@"B"]) {
            [button setTag:OESega32XButtonB];
        } else if ([[[button titleLabel] text] isEqualToString:@"C"]) {
            [button setTag:OESega32XButtonC];
        } else if ([[[button titleLabel] text] isEqualToString:@"X"]) {
            [button setTag:OESega32XButtonX];
        } else if ([[[button titleLabel] text] isEqualToString:@"Y"]) {
            [button setTag:OESega32XButtonY];
        } else if ([[[button titleLabel] text] isEqualToString:@"Z"]) {
            [button setTag:OESega32XButtonZ];
        }else if ([[[button titleLabel] text] isEqualToString:@"Mode"]) {
            [button setTag:OESega32XButtonMode];
        } else if ([[[button titleLabel] text] isEqualToString:@"Start"]) {
            [button setTag:OESega32XButtonStart];
        }
    }
    
    self.startButton.tag  = OESega32XButtonStart;
    self.selectButton.tag = OESega32XButtonMode;
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    
    [three2xCore didReleaseSega32XButton:OESega32XButtonUp forPlayer:0];
    [three2xCore didReleaseSega32XButton:OESega32XButtonDown forPlayer:0];
    [three2xCore didReleaseSega32XButton:OESega32XButtonLeft forPlayer:0];
    [three2xCore didReleaseSega32XButton:OESega32XButtonRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [three2xCore didPushSega32XButton:OESega32XButtonUp forPlayer:0];
            [three2xCore didPushSega32XButton:OESega32XButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [three2xCore didPushSega32XButton:OESega32XButtonUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [three2xCore didPushSega32XButton:OESega32XButtonUp forPlayer:0];
            [three2xCore didPushSega32XButton:OESega32XButtonRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [three2xCore didPushSega32XButton:OESega32XButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [three2xCore didPushSega32XButton:OESega32XButtonRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [three2xCore didPushSega32XButton:OESega32XButtonDown forPlayer:0];
            [three2xCore didPushSega32XButton:OESega32XButtonLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [three2xCore didPushSega32XButton:OESega32XButtonDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [three2xCore didPushSega32XButton:OESega32XButtonDown forPlayer:0];
            [three2xCore didPushSega32XButton:OESega32XButtonRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    
    [three2xCore didReleaseSega32XButton:OESega32XButtonUp forPlayer:0];
    [three2xCore didReleaseSega32XButton:OESega32XButtonDown forPlayer:0];
    [three2xCore didReleaseSega32XButton:OESega32XButtonLeft forPlayer:0];
    [three2xCore didReleaseSega32XButton:OESega32XButtonRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    NSInteger tag = button.tag;
    [three2xCore didPushSega32XButton:tag forPlayer:0];
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    NSInteger tag = button.tag;
    [three2xCore didReleaseSega32XButton:tag forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    [three2xCore didPushSega32XButton:OESega32XButtonStart forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    [three2xCore didReleaseSega32XButton:OESega32XButtonStart forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    [three2xCore didPushSega32XButton:OESega32XButtonMode forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    PicodriveGameCore *three2xCore = (PicodriveGameCore *)self.emulatorCore;
    [three2xCore didReleaseSega32XButton:OESega32XButtonMode forPlayer:player];
}

@end

