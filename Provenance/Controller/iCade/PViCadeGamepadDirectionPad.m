//
//  PViCadeGamepadDirectionPad.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeGamepadDirectionPad.h"
#import "PViCadeReader.h"

@interface PViCadeAxisInput(PVPrivateAPI)
-(void) setValue:(float) value;
@end

@interface PViCadeGamepadButtonInput(PVPrivateAPI)
-(void) setPressed:(BOOL)pressed;
@end

@implementation PViCadeGamepadDirectionPad

-(instancetype) init {
    if (self = [super init]) {
        _xAxis = [[PViCadeAxisInput alloc] init];
        _yAxis = [[PViCadeAxisInput alloc] init];

        _up = [[PViCadeGamepadButtonInput alloc] init];
        _down = [[PViCadeGamepadButtonInput alloc] init];
        _left = [[PViCadeGamepadButtonInput alloc] init];
        _right = [[PViCadeGamepadButtonInput alloc] init];
    }
    return self;
}

-(void) setValueChangedHandler:(GCControllerDirectionPadValueChangedHandler) handler {
    _handler = handler;
}

-(void) padChanged {
    iCadeState state = [PViCadeReader sharedReader].state;
    
    float x = (state & iCadeJoystickLeft)? -1.0f: ((state & iCadeJoystickRight)? 1.0f : 0.0f );
    float y = (state & iCadeJoystickDown)? -1.0f: ((state & iCadeJoystickUp)? 1.0f : 0.0f );
    [_xAxis setValue:x];
    [_yAxis setValue:y];

    if (x == -1.0f) {
        [_left setPressed:YES];
    } else if (x == 1.0f) {
        [_right setPressed:YES];
    } else {
        [_left setPressed:NO];
        [_right setPressed:NO];
    }

    if (y == -1.0f) {
        [_down setPressed:YES];
    } else if (y == 1.0f) {
        [_up setPressed:YES];
    } else {
        [_down setPressed:NO];
        [_up setPressed:NO];
    }

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

-(PViCadeGamepadButtonInput*) up
{
    return _up;
}

-(PViCadeGamepadButtonInput*) down;
{
    return _down;
}

-(PViCadeGamepadButtonInput*) left;
{
    return _left;
}

-(PViCadeGamepadButtonInput*) right;
{
    return _right;
}

@end