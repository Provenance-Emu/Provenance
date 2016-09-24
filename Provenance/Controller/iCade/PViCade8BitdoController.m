//
//  PViCade8BitdoController.m
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Support for SFC30 added by Raf Cabezas on 09/21/16.
//  Copyright (c) 2015 Josejulio Martínez, Raf Cabezas. All rights reserved.
//

#import "PViCade8BitdoController.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@implementation PViCade8BitdoController

-(instancetype) initWithControllerType:(ICade8bitdoControllerType)controllerType {
    
    if (self = [super init]) {
        switch (controllerType) {
            case ICade8bitdoControllerTypeNES30:
                [self initNES30];
                break;
            case ICade8bitdoControllerTypeSFC30:
                [self initSFC30];
                break;
        }
    }
    return self;
}

- (void) initNES30 {
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

- (void) initSFC30 {
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

@end
