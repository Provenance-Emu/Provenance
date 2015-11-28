//
//  PViCadeSteelSeriesController.m
//  Provenance
//
//  Created by Simon Frost on 17/11/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PViCadeSteelSeriesController.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@implementation PViCadeSteelSeriesController

-(instancetype) init {
    if (self = [super init]) {
        __unsafe_unretained PViCadeController* weakSelf = self;
        self.reader.buttonDown = ^(iCadeState button) {
            switch (button) {
                case iCadeButtonA:
                    [[weakSelf.iCadeGamepad buttonX] buttonPressed];
                    break;
                case iCadeButtonB:
                    [[weakSelf.iCadeGamepad buttonA] buttonPressed];
                    break;
                case iCadeButtonC:
                    [[weakSelf.iCadeGamepad buttonY] buttonPressed];
                    break;
                case iCadeButtonD:
                    [[weakSelf.iCadeGamepad buttonB] buttonPressed];
                    break;
                case iCadeButtonE:
                    [[weakSelf.iCadeGamepad leftShoulder] buttonPressed];
                    break;
                case iCadeButtonF:
                    [[weakSelf.iCadeGamepad rightShoulder] buttonPressed];
                    break;
                case iCadeButtonG:
                    [[weakSelf.iCadeGamepad rightTrigger] buttonPressed];
                    break;
                case iCadeButtonH:
                    [[weakSelf.iCadeGamepad leftTrigger] buttonPressed];
                    break;
                case iCadeJoystickDown:
                case iCadeJoystickLeft:
                case iCadeJoystickRight:
                case iCadeJoystickUp:
                    [[weakSelf.iCadeGamepad dpad] padChanged];
                    break;
                default:
                    break;
            }
            if (weakSelf.controllerPressedAnyKey) {
                weakSelf.controllerPressedAnyKey(weakSelf);
            }
        };
        
        self.reader.buttonUp = ^(iCadeState button) {
            switch (button) {
                case iCadeButtonA:
                    [[weakSelf.iCadeGamepad buttonX] buttonReleased];
                    break;
                case iCadeButtonB:
                    [[weakSelf.iCadeGamepad buttonA] buttonReleased];
                    break;
                case iCadeButtonC:
                    [[weakSelf.iCadeGamepad buttonY] buttonReleased];
                    break;
                case iCadeButtonD:
                    [[weakSelf.iCadeGamepad buttonB] buttonReleased];
                    break;
                case iCadeButtonE:
                    [[weakSelf.iCadeGamepad leftShoulder] buttonReleased];
                    break;
                case iCadeButtonF:
                    [[weakSelf.iCadeGamepad rightShoulder] buttonReleased];
                    break;
                case iCadeButtonG:
                    [[weakSelf.iCadeGamepad rightTrigger] buttonReleased];
                    break;
                case iCadeButtonH:
                    [[weakSelf.iCadeGamepad leftTrigger] buttonReleased];
                    break;
                case iCadeJoystickDown:
                case iCadeJoystickLeft:
                case iCadeJoystickRight:
                case iCadeJoystickUp:
                    [[weakSelf.iCadeGamepad dpad] padChanged];
                    break;
                default:
                    break;
            }
        };
    }
    return self;
}

@end
