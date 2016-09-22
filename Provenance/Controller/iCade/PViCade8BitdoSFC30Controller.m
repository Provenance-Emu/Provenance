//
//  PViCade8BitdoSFC30Controller.m
//  Provenance
//
//  Created by Raf Cabezas on 09/21/16.
//  Based on PViCade8BitdoController by Josejulio Martínez
//  Copyright (c) 2016 Raf Cabezas. All rights reserved.
//


#import "PViCade8BitdoSFC30Controller.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@implementation PViCade8BitdoSFC30Controller

/*
 A  ON,OFF  = y,t
 B  ON,OFF  = h,r
 C  ON,OFF  = u,f
 D  ON,OFF  = j,n
 E  ON,OFF  = i,m
 F  ON,OFF  = k,p
 G  ON,OFF  = o,g
 H  ON,OFF  = l,v
 */

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
    return self;
}

@end
