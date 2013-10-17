//
//  PVGameControllerViewController.m
//  Provenance
//
//  Created by David on 2013-10-14.
//

#import "PVGameControllerViewController.h"
#import "PVSNESEmulatorCore.h"

#import <GameController/GameController.h>

@interface PVGameControllerViewController ()

@end

@implementation PVGameControllerViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    GCGamepad *gamepad = [[GCController controllers] firstObject];
    gamepad.valueChangedHandler = ^(GCGamepad *gamepad, GCControllerElement *element) {
        
        PVSNESEmulatorCore *snesCore = (PVSNESEmulatorCore *)self.emulatorCore;

        // move the active button
        if (gamepad.buttonA.isPressed)
        {
            [snesCore pushSNESButton:PVSNESButtonA];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonA];
        }
        
        if (gamepad.buttonB.isPressed)
        {
            [snesCore pushSNESButton:PVSNESButtonB];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonB];
        }
        
        if (gamepad.buttonX.isPressed)
        {
            [snesCore pushSNESButton:PVSNESButtonX];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonX];
        }
        
        if (gamepad.buttonY.isPressed)
        {
            [snesCore pushSNESButton:PVSNESButtonY];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonY];
        }
        
        if (gamepad.dpad.left.isPressed)
        {
			[snesCore pushSNESButton:PVSNESButtonLeft];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonLeft];
        }
        
        if (gamepad.dpad.right.isPressed)
        {
			[snesCore pushSNESButton:PVSNESButtonRight];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonRight];
        }
        
        if (gamepad.dpad.up.isPressed)
        {
			[snesCore pushSNESButton:PVSNESButtonUp];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonUp];
        }
        
        if (gamepad.dpad.down.isPressed)
        {
			[snesCore pushSNESButton:PVSNESButtonDown];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonDown];
        }
        
        if (gamepad.leftShoulder.isPressed)
        {
			[snesCore pushSNESButton:PVSNESButtonTriggerLeft];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonTriggerLeft];
        }
        
        if (gamepad.rightShoulder.isPressed)
        {
			[snesCore pushSNESButton:PVSNESButtonTriggerRight];
        }
        else
        {
            [snesCore releaseSNESButton:PVSNESButtonTriggerRight];
        }
    };
}


@end
