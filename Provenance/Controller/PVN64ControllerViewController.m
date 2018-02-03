//
//  PVN64ControllerViewController.m
//  Provenance
//
//  Created by Joe Mattiello on 11/28/2016.
//  Copyright (c) 2016 James Addyman. All rights reserved.
//

#import "PVN64ControllerViewController.h"
#import <PVMupen64Plus/MupenGameCore.h>

@interface PVN64ControllerViewController ()

@end

@implementation PVN64ControllerViewController

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
            [button setTag:OEN64ButtonA];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"B"])
        {
            [button setTag:OEN64ButtonB];
        }
        else if ([[[button titleLabel] text] isEqualToString:@"Z"])
        {
            [button setTag:OEN64ButtonZ];
        }

    }
    
    [self.leftShoulderButton setTag:OEN64ButtonL];
    [self.rightShoulderButton setTag:OEN64ButtonR];
//    [self.selectButton setTag:OEN64ButtonStart];
    [self.startButton setTag:OEN64ButtonStart];
}

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    
    [n64Core didReleaseN64Button:OEN64ButtonDPadUp forPlayer:0];
    [n64Core didReleaseN64Button:OEN64ButtonDPadDown forPlayer:0];
    [n64Core didReleaseN64Button:OEN64ButtonDPadLeft forPlayer:0];
    [n64Core didReleaseN64Button:OEN64ButtonDPadRight forPlayer:0];
    
    switch (direction)
    {
        case JSDPadDirectionUpLeft:
            [n64Core didPushN64Button:OEN64ButtonDPadUp forPlayer:0];
            [n64Core didPushN64Button:OEN64ButtonDPadLeft forPlayer:0];
            break;
        case JSDPadDirectionUp:
            [n64Core didPushN64Button:OEN64ButtonDPadUp forPlayer:0];
            break;
        case JSDPadDirectionUpRight:
            [n64Core didPushN64Button:OEN64ButtonDPadUp forPlayer:0];
            [n64Core didPushN64Button:OEN64ButtonDPadRight forPlayer:0];
            break;
        case JSDPadDirectionLeft:
            [n64Core didPushN64Button:OEN64ButtonDPadLeft forPlayer:0];
            break;
        case JSDPadDirectionRight:
            [n64Core didPushN64Button:OEN64ButtonDPadRight forPlayer:0];
            break;
        case JSDPadDirectionDownLeft:
            [n64Core didPushN64Button:OEN64ButtonDPadDown forPlayer:0];
            [n64Core didPushN64Button:OEN64ButtonDPadLeft forPlayer:0];
            break;
        case JSDPadDirectionDown:
            [n64Core didPushN64Button:OEN64ButtonDPadDown forPlayer:0];
            break;
        case JSDPadDirectionDownRight:
            [n64Core didPushN64Button:OEN64ButtonDPadDown forPlayer:0];
            [n64Core didPushN64Button:OEN64ButtonDPadRight forPlayer:0];
            break;
        default:
            break;
    }
    
    [self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    
    [n64Core didReleaseN64Button:OEN64ButtonDPadUp forPlayer:0];
    [n64Core didReleaseN64Button:OEN64ButtonDPadDown forPlayer:0];
    [n64Core didReleaseN64Button:OEN64ButtonDPadLeft forPlayer:0];
    [n64Core didReleaseN64Button:OEN64ButtonDPadRight forPlayer:0];
}

- (void)buttonPressed:(JSButton *)button
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    [n64Core didReleaseN64Button:(OEN64Button)[button tag] forPlayer:0];
    
    [self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    [n64Core didReleaseN64Button:(OEN64Button)[button tag] forPlayer:0];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    [n64Core didPushN64Button:OEN64ButtonStart forPlayer:player];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    [n64Core didReleaseN64Button:OEN64ButtonStart forPlayer:player];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    [n64Core didPushN64Button:OEN64ButtonZ forPlayer:player];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    MupenGameCore *n64Core = (MupenGameCore *)self.emulatorCore;
    [n64Core didReleaseN64Button:OEN64ButtonZ forPlayer:player];
}

@end

