//
//  PViCadeGamepadInputButton.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import <GameController/GameController.h>

@interface PViCadeGamepadButtonInput : GCControllerButtonInput {
    GCControllerButtonValueChangedHandler _handler;

    BOOL _pressed;
    float _value;
}

-(void) buttonPressed;
-(void) buttonReleased;

@end