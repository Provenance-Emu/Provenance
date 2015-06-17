//
//  PViCadeGamepad.h
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <GameController/GameController.h>

@class PViCadeGamepadDirectionPad;
@class PViCadeGamepadButtonInput;

@interface PViCadeGamepad : GCGamepad {
    PViCadeGamepadDirectionPad* _dpad;
    
    PViCadeGamepadButtonInput* _buttonA;
    PViCadeGamepadButtonInput* _buttonB;
    PViCadeGamepadButtonInput* _buttonC;
    PViCadeGamepadButtonInput* _buttonD;
    
    PViCadeGamepadButtonInput* _leftShoulder;
    PViCadeGamepadButtonInput* _rightShoulder;
    
}


@end
