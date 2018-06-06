//
//  PViCadeMocuteController.m
//  Provenance
//
//  Created by Edgar Neto on 8/12/17.
//  Copyright © 2017 James Addyman. All rights reserved.
//

#import "PViCadeMocuteController.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@implementation PViCadeMocuteController

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
                    [[weakSelf.iCadeGamepad buttonB] buttonPressed];
                    break;
                case iCadeButtonD:
                    [[weakSelf.iCadeGamepad buttonY] buttonPressed];
                    break;
                case iCadeButtonE:
                    [[weakSelf.iCadeGamepad leftShoulder] buttonPressed];
                    break;
                case iCadeButtonF:
                    [[weakSelf.iCadeGamepad rightShoulder] buttonPressed];
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
					WLOG(@"Unknown iCade key %0x", button);
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
                    [[weakSelf.iCadeGamepad buttonB] buttonReleased];
                    break;
                case iCadeButtonD:
                    [[weakSelf.iCadeGamepad buttonY] buttonReleased];
                    break;
                case iCadeButtonE:
                    [[weakSelf.iCadeGamepad leftShoulder] buttonReleased];
                    break;
                case iCadeButtonF:
                    [[weakSelf.iCadeGamepad rightShoulder] buttonReleased];
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
    return @"Mocute";
}

@end
