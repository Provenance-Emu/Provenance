//
//  PViCadeGamepad.m
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeGamepad.h"

@interface PViCadeGamepadDirectionPad : GCControllerDirectionPad {
    GCControllerDirectionPadValueChangedHandler _handler;
}

@end
@interface PViCadeGamepadButtonInput : GCControllerButtonInput {
    GCControllerButtonValueChangedHandler _handler;
}

@end

@implementation PViCadeGamepadDirectionPad

-(void) setValueChangedHandler:(GCControllerDirectionPadValueChangedHandler) handler {
    _handler = handler;
}

@end

@implementation PViCadeGamepadButtonInput

-(void) setValueChangedHandler:(GCControllerButtonValueChangedHandler) handler {
    _handler = handler;
}

@end

@implementation PViCadeGamepad

-(instancetype) init {
    if (self = [super init]) {
        _buttonA = [[PViCadeGamepadButtonInput alloc] init];
    }
    return self;
}

-(PViCadeGamepadButtonInput*) buttonA {
    return _buttonA;
}

-(PViCadeGamepadButtonInput*) buttonB {
    return _buttonB;
}

-(PViCadeGamepadButtonInput*) buttonC {
    return _buttonC;
}

-(PViCadeGamepadButtonInput*) buttonD {
    return _buttonD;
}

-(PViCadeGamepadButtonInput*) leftShoulder {
    return _leftShoulder;
}

-(PViCadeGamepadButtonInput*) rightShoulder {
    return _rightShoulder;
}

@end
