//
//  PViCadeGamepad.m
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeGamepad.h"
#import "PViCadeReader.h"
#import "PViCadeGamepadButtonInput.h"
#import "PViCadeGamepadDirectionPad.h"
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

		_start = [[PViCadeGamepadButtonInput alloc] init];
		_select = [[PViCadeGamepadButtonInput alloc] init];

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
