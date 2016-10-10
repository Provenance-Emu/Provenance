//
//  PViCadeController.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeController.h"
#import "iCadeReaderView.h"
#import "PViCadeGamepad.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"

@interface PViCadeController(PVPrivateAPI)<iCadeEventDelegate>
@end

@implementation PViCadeController

-(void) refreshListener {
    [_reader stopListening];
    [_reader listenToKeyWindow];
}

-(void) dealloc {
    [_reader stopListening];
}

-(instancetype) init {
    if (self = [super init]) {
        _iCadeGamepad = [[PViCadeGamepad alloc] init];
        _reader = [PViCadeReader sharedReader];
        [_reader listenToKeyWindow];
        
        __unsafe_unretained PViCadeController* weakSelf = self;
        _reader.buttonDown = ^(iCadeState button) {
            switch (button) {
                case iCadeButtonA:
                    [[weakSelf->_iCadeGamepad rightTrigger] buttonPressed];
                    break;
                case iCadeButtonB:
                    [[weakSelf->_iCadeGamepad leftShoulder] buttonPressed];
                    break;
                case iCadeButtonC:
                    [[weakSelf->_iCadeGamepad leftTrigger] buttonPressed];
                    break;
                case iCadeButtonD:
                    [[weakSelf->_iCadeGamepad rightShoulder] buttonPressed];
                    break;
                case iCadeButtonE:
                    [[weakSelf->_iCadeGamepad buttonY] buttonPressed];
                    break;
                case iCadeButtonF:
                    [[weakSelf->_iCadeGamepad buttonB] buttonPressed];
                    break;
                case iCadeButtonG:
                    [[weakSelf->_iCadeGamepad buttonX] buttonPressed];
                    break;
                case iCadeButtonH:
                    [[weakSelf->_iCadeGamepad buttonA] buttonPressed];
                    
                    break;
                case iCadeJoystickDown:
                case iCadeJoystickLeft:
                case iCadeJoystickRight:
                case iCadeJoystickUp:
                    [[weakSelf->_iCadeGamepad dpad] padChanged];
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
                    [[weakSelf->_iCadeGamepad rightTrigger] buttonReleased];
                    break;
                case iCadeButtonB:
                    [[weakSelf->_iCadeGamepad leftShoulder] buttonReleased];
                    break;
                case iCadeButtonC:
                    [[weakSelf->_iCadeGamepad leftTrigger] buttonReleased];
                    break;
                case iCadeButtonD:
                    [[weakSelf->_iCadeGamepad rightShoulder] buttonReleased];
                    break;
                case iCadeButtonE:
                    [[weakSelf->_iCadeGamepad buttonY] buttonReleased];
                    break;
                case iCadeButtonF:
                    [[weakSelf->_iCadeGamepad buttonB] buttonReleased];
                    break;
                case iCadeButtonG:
                    [[weakSelf->_iCadeGamepad buttonX] buttonReleased];
                    break;
                case iCadeButtonH:
                    [[weakSelf->_iCadeGamepad buttonA] buttonReleased];
                    break;
                case iCadeJoystickDown:
                case iCadeJoystickLeft:
                case iCadeJoystickRight:
                case iCadeJoystickUp:
                    [[weakSelf->_iCadeGamepad dpad] padChanged];
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

-(GCExtendedGamepad*) extendedGamepad {
    return _iCadeGamepad;
}

- (NSString *)vendorName {
    return @"iCade";
}

// don't know if it's nessesary but seems good
- (BOOL)isAttachedToDevice {
    return FALSE;
}

-(GCControllerPlayerIndex) playerIndex {
    return _playerIndex;
}

// don't know if it's nessesary to set a specific index but without implementing this method the app crashes
-(void) setPlayerIndex:(GCControllerPlayerIndex) playerIndex {
     _playerIndex = playerIndex;
}



@end
