//
//  PViCadeGamepad.m
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeGamepad.h"

static iCadeReaderView* _reader;


@interface PViCadeAxisInput : GCControllerAxisInput {
    float _value;
}
@end

@implementation PViCadeAxisInput

-(void) setValue:(float) value {
    _value = value;
}

-(float) value {
    return _value;
}

@end

@interface PViCadeGamepadDirectionPad : GCControllerDirectionPad {
    GCControllerDirectionPadValueChangedHandler _handler;
    
    PViCadeAxisInput* _xAxis;
    PViCadeAxisInput* _yAxis;
    
}

-(void) padChanged;
-(PViCadeAxisInput*) xAxis;
-(PViCadeAxisInput*) yAxis;

@end
@interface PViCadeGamepadButtonInput : GCControllerButtonInput {
    GCControllerButtonValueChangedHandler _handler;
}

-(void) buttonPressed;
-(void) buttonReleased;

@end

@implementation PViCadeGamepadDirectionPad

-(instancetype) init {
    if (self = [super init]) {
        _xAxis = [[PViCadeAxisInput alloc] init];
        _yAxis = [[PViCadeAxisInput alloc] init];
    }
    return self;
}

-(void) setValueChangedHandler:(GCControllerDirectionPadValueChangedHandler) handler {
    _handler = handler;
}

-(void) padChanged {
    float x = (_reader.iCadeState & iCadeJoystickLeft)? -1.0f: ((_reader.iCadeState & iCadeJoystickRight)? 1.0f : 0.0f );
    float y = (_reader.iCadeState & iCadeJoystickDown)? -1.0f: ((_reader.iCadeState & iCadeJoystickUp)? 1.0f : 0.0f );
    [_xAxis setValue:x];
    [_yAxis setValue:y];
    if (_handler) {
        _handler(self, x, y);
    }
}

-(PViCadeAxisInput*) xAxis {
    return _xAxis;
}

-(PViCadeAxisInput*) yAxis {
    return _yAxis;
}

@end

@implementation PViCadeGamepadButtonInput

-(void) setValueChangedHandler:(GCControllerButtonValueChangedHandler) handler {
    _handler = handler;
}

-(void) buttonPressed {
    if (_handler) {
        _handler(self, 1.0, YES);
    }
}

-(void) buttonReleased {
    if (_handler) {
        _handler(self, 0.0, NO);
    }
}

@end

@implementation PViCadeController

-(instancetype) init {
    if (self = [super init]) {
        _gamepad = [[PViCadeGamepad alloc] init];
        _reader = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
        UIWindow* window = [[UIApplication sharedApplication] windows][1];
        //[[[UIApplication sharedApplication] delegate] window];//
        [window addSubview:_reader];
        [window makeKeyAndVisible];
        _reader.active = YES;
        _reader.delegate = self;
        
        
    }
    return self;
}

- (void) setControllerPausedHandler:(void (^)(GCController *controller)) controllerPausedHandler {
    // dummy method to avoid NSInternalInconsistencyException
}

- (void)buttonDown:(iCadeState)button {
    switch (button) {
        case iCadeButtonA:
            [[_gamepad rightTrigger] buttonPressed];
            break;
        case iCadeButtonB:
            [[_gamepad leftShoulder] buttonPressed];
            break;
        case iCadeButtonC:
            [[_gamepad leftTrigger] buttonPressed];
            break;
        case iCadeButtonD:
            [[_gamepad rightShoulder] buttonPressed];
            break;
        case iCadeButtonE:
            [[_gamepad buttonX] buttonPressed];
            break;
        case iCadeButtonF:
            [[_gamepad buttonA] buttonPressed];
            break;
        case iCadeButtonG:
            [[_gamepad buttonY] buttonPressed];
            break;
        case iCadeButtonH:
            [[_gamepad buttonB] buttonPressed];
            break;
        case iCadeJoystickDown:
            [[_gamepad dpad] padChanged];
            break;
        case iCadeJoystickLeft:
            [[_gamepad dpad] padChanged];
            break;
        case iCadeJoystickRight:
            [[_gamepad dpad] padChanged];
            break;
        case iCadeJoystickUp:
            [[_gamepad dpad] padChanged];
            break;
        default:
            break;
    }
    if (self.controllerPressedAnyKey) {
        self.controllerPressedAnyKey(self);
    }
}

- (void)buttonUp:(iCadeState)button {
    switch (button) {
        case iCadeButtonA:
            [[_gamepad rightTrigger] buttonReleased];
            break;
        case iCadeButtonB:
            [[_gamepad leftShoulder] buttonReleased];
            break;
        case iCadeButtonC:
            [[_gamepad leftTrigger] buttonReleased];
            break;
        case iCadeButtonD:
            [[_gamepad rightShoulder] buttonReleased];
            break;
        case iCadeButtonE:
            [[_gamepad buttonX] buttonReleased];
            break;
        case iCadeButtonF:
            [[_gamepad buttonA] buttonReleased];
            break;
        case iCadeButtonG:
            [[_gamepad buttonY] buttonReleased];
            break;
        case iCadeButtonH:
            [[_gamepad buttonB] buttonReleased];
            break;
        case iCadeJoystickDown:
            [[_gamepad dpad] padChanged];
            break;
        case iCadeJoystickLeft:
            [[_gamepad dpad] padChanged];
            break;
        case iCadeJoystickRight:
            [[_gamepad dpad] padChanged];
            break;
        case iCadeJoystickUp:
            [[_gamepad dpad] padChanged];
            break;
        default:
            break;
    }
}

-(GCGamepad*) gamepad {
    return nil;
}

-(PViCadeGamepad*) extendedGamepad {
    return _gamepad;
}

@end

@implementation PViCadeGamepad

-(instancetype) init {
    if (self = [super init]) {
        _dpad = [[PViCadeGamepadDirectionPad alloc] init];
        _buttonA = [[PViCadeGamepadButtonInput alloc] init];
        _buttonB = [[PViCadeGamepadButtonInput alloc] init];
        _buttonX = [[PViCadeGamepadButtonInput alloc] init];
        _buttonY = [[PViCadeGamepadButtonInput alloc] init];
        _leftShoulder = [[PViCadeGamepadButtonInput alloc] init];
        _rightShoulder = [[PViCadeGamepadButtonInput alloc] init];
        
        _leftTrigger = [[PViCadeGamepadButtonInput alloc] init];
        _rightTrigger = [[PViCadeGamepadButtonInput alloc] init];
        
        _dummyThumbstick = [[PViCadeGamepadDirectionPad alloc] init];
    }
    return self;
}

-(PViCadeGamepadDirectionPad*) dpad {
    return _dpad;
}

-(PViCadeGamepadDirectionPad*) leftThumbstick {
    return _dummyThumbstick;
}

-(PViCadeGamepadDirectionPad*) rightThumbstick {
    return _dummyThumbstick;
}

-(PViCadeGamepadButtonInput*) buttonA {
    return _buttonA;
}

-(PViCadeGamepadButtonInput*) buttonB {
    return _buttonB;
}

-(PViCadeGamepadButtonInput*) buttonX {
    return _buttonX;
}

-(PViCadeGamepadButtonInput*) buttonY {
    return _buttonY;
}

-(PViCadeGamepadButtonInput*) leftShoulder {
    return _leftShoulder;
}

-(PViCadeGamepadButtonInput*) rightShoulder {
    return _rightShoulder;
}

-(PViCadeGamepadButtonInput*) leftTrigger {
    return _leftTrigger;
}

-(PViCadeGamepadButtonInput*) rightTrigger {
    return _rightTrigger;
}

@end
