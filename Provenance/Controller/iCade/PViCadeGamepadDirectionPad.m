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
    iCadeState state = [PViCadeReader sharedReader].state;
    
    float x = (state & iCadeJoystickLeft)? -1.0f: ((state & iCadeJoystickRight)? 1.0f : 0.0f );
    float y = (state & iCadeJoystickDown)? -1.0f: ((state & iCadeJoystickUp)? 1.0f : 0.0f );
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