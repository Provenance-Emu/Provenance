//
//  PViCade8BitdoZeroController.m
//  Provenance
//
//  Created by Justin Weiss on 7/2/17.
//  Copyright © 2017 Justin Weiss. All rights reserved.
//

#import "PViCade8BitdoZeroController.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@implementation PViCade8BitdoZeroController

-(instancetype) init {
    if (self = [super init]) {
        __unsafe_unretained PViCadeController* weakSelf = self;
        self.reader.buttonDown = ^(iCadeState button) {
            switch (button) {
                case iCadeButtonA:
                    [[weakSelf.iCadeGamepad buttonY] buttonPressed];
                    break;
                case iCadeButtonB:
                    [[weakSelf.iCadeGamepad buttonB] buttonPressed];
                    break;
                case iCadeButtonC:
                    [[weakSelf.iCadeGamepad buttonA] buttonPressed];
                    break;
                case iCadeButtonD:
                    [[weakSelf.iCadeGamepad buttonX] buttonPressed];
                    break;
                case iCadeButtonE:
                    [[weakSelf.iCadeGamepad rightShoulder] buttonPressed];
                    break;
                case iCadeButtonF:
                    [[weakSelf.iCadeGamepad leftShoulder] buttonPressed];
                    break;
                case iCadeButtonG:
                    [[weakSelf.iCadeGamepad leftTrigger] buttonPressed];
                    break;
                case iCadeButtonH:
                    [[weakSelf.iCadeGamepad rightTrigger] buttonPressed];
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
                    [[weakSelf.iCadeGamepad buttonY] buttonReleased];
                    break;
                case iCadeButtonB:
                    [[weakSelf.iCadeGamepad buttonB] buttonReleased];
                    break;
                case iCadeButtonC:
                    [[weakSelf.iCadeGamepad buttonA] buttonReleased];
                    break;
                case iCadeButtonD:
                    [[weakSelf.iCadeGamepad buttonX] buttonReleased];
                    break;
                case iCadeButtonE:
                    [[weakSelf.iCadeGamepad rightShoulder] buttonReleased];
                    break;
                case iCadeButtonF:
                    [[weakSelf.iCadeGamepad leftShoulder] buttonReleased];
                    break;
                case iCadeButtonG:
                    [[weakSelf.iCadeGamepad leftTrigger] buttonReleased];
                    break;
                case iCadeButtonH:
                    [[weakSelf.iCadeGamepad rightTrigger] buttonReleased];
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

- (NSString *) vendorName {
    return @"8Bitdo Zero";
}

@end
