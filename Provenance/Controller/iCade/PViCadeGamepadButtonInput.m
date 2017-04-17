//
//  PViCadeGamepadInputButton.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeGamepadButtonInput.h"

@implementation PViCadeGamepadButtonInput

-(void) setValueChangedHandler:(GCControllerButtonValueChangedHandler) handler {
    _handler = handler;
}

-(void) setPressedChangedHandler:(GCControllerButtonValueChangedHandler) handler {
    _handler = handler;
}

-(void) buttonPressed {
    if (_handler) {
        _handler(self, 1.0, YES);
    }
    [self setPressed:YES];
}

-(void) buttonReleased {
    if (_handler) {
        _handler(self, 0.0, NO);
    }
    [self setPressed:NO];
}

-(void) setPressed:(BOOL)pressed {
    _pressed = pressed;
    _value = pressed ? 1.0f : 0.0f;
}

-(BOOL) isPressed {
    return _pressed;
}

- (float)value {
    return _value;
}

@end
