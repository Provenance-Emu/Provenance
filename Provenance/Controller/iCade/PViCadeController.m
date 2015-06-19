//
//  PViCadeController.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PViCadeController.h"
#import "iCadeReaderView.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@interface PViCadeController(PVPrivateAPI)<iCadeEventDelegate>
@end

@implementation PViCadeController

-(instancetype) init {
    if (self = [super init]) {
        _gamepad = [[PViCadeGamepad alloc] init];
        _reader = [PViCadeReader sharedReader];
        [_reader listenToKeyWindow];
        
        __unsafe_unretained PViCadeController* weakSelf = self;
        _reader.buttonDown = ^(iCadeState button) {
            switch (button) {
                case iCadeButtonA:
                    [[weakSelf->_gamepad rightTrigger] buttonPressed];
                    break;
                case iCadeButtonB:
                    [[weakSelf->_gamepad leftShoulder] buttonPressed];
                    break;
                case iCadeButtonC:
                    [[weakSelf->_gamepad leftTrigger] buttonPressed];
                    break;
                case iCadeButtonD:
                    [[weakSelf->_gamepad rightShoulder] buttonPressed];
                    break;
                case iCadeButtonE:
                    [[weakSelf->_gamepad buttonX] buttonPressed];
                    break;
                case iCadeButtonF:
                    [[weakSelf->_gamepad buttonA] buttonPressed];
                    break;
                case iCadeButtonG:
                    [[weakSelf->_gamepad buttonY] buttonPressed];
                    break;
                case iCadeButtonH:
                    [[weakSelf->_gamepad buttonB] buttonPressed];
                    break;
                case iCadeJoystickDown:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                case iCadeJoystickLeft:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                case iCadeJoystickRight:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                case iCadeJoystickUp:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                default:
                    break;
            }
            if (weakSelf.controllerPressedAnyKey) {
                weakSelf.controllerPressedAnyKey(weakSelf);
            }
        };
        
        _reader.buttonUp = ^(iCadeState button) {
            switch (button) {
                case iCadeButtonA:
                    [[weakSelf->_gamepad rightTrigger] buttonReleased];
                    break;
                case iCadeButtonB:
                    [[weakSelf->_gamepad leftShoulder] buttonReleased];
                    break;
                case iCadeButtonC:
                    [[weakSelf->_gamepad leftTrigger] buttonReleased];
                    break;
                case iCadeButtonD:
                    [[weakSelf->_gamepad rightShoulder] buttonReleased];
                    break;
                case iCadeButtonE:
                    [[weakSelf->_gamepad buttonX] buttonReleased];
                    break;
                case iCadeButtonF:
                    [[weakSelf->_gamepad buttonA] buttonReleased];
                    break;
                case iCadeButtonG:
                    [[weakSelf->_gamepad buttonY] buttonReleased];
                    break;
                case iCadeButtonH:
                    [[weakSelf->_gamepad buttonB] buttonReleased];
                    break;
                case iCadeJoystickDown:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                case iCadeJoystickLeft:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                case iCadeJoystickRight:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                case iCadeJoystickUp:
                    [[weakSelf->_gamepad dpad] padChanged];
                    break;
                default:
                    break;
            }
        };
    }
    return self;
}

- (void) setControllerPausedHandler:(void (^)(GCController *controller)) controllerPausedHandler {
    // dummy method to avoid NSInternalInconsistencyException
}


-(GCGamepad*) gamepad {
    return nil;
}

-(PViCadeGamepad*) extendedGamepad {
    return _gamepad;
}

@end