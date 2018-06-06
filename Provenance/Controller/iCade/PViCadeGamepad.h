//
//  PViCadeGamepad.h
//  Provenance
//
//  Created by Josejulio Martínez on 16/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import <GameController/GameController.h>
#import "PViCadeReader.h"

@class PViCadeGamepadDirectionPad;
@class PViCadeGamepadButtonInput;


@interface PViCadeGamepad : GCExtendedGamepad {
    PViCadeGamepadDirectionPad* _dpad;
    
    PViCadeGamepadButtonInput* _buttonA;
    PViCadeGamepadButtonInput* _buttonB;
    PViCadeGamepadButtonInput* _buttonX;
    PViCadeGamepadButtonInput* _buttonY;
    
    PViCadeGamepadButtonInput* _leftShoulder;
    PViCadeGamepadButtonInput* _rightShoulder;
    
    PViCadeGamepadButtonInput* _leftTrigger;
    PViCadeGamepadButtonInput* _rightTrigger;

	PViCadeGamepadButtonInput* _start;
	PViCadeGamepadButtonInput* _select;

    PViCadeGamepadDirectionPad* _dummyThumbstick;
}

-(PViCadeGamepadDirectionPad*) dpad;

// iCade only support 1 dpad and 8 buttons :(,
// thus these are dummies.
-(PViCadeGamepadDirectionPad*) leftThumbstick;
-(PViCadeGamepadDirectionPad*) rightThumbstick;

-(PViCadeGamepadButtonInput*) buttonA;
-(PViCadeGamepadButtonInput*) buttonB;
-(PViCadeGamepadButtonInput*) buttonX;
-(PViCadeGamepadButtonInput*) buttonY;
-(PViCadeGamepadButtonInput*) leftShoulder;
-(PViCadeGamepadButtonInput*) rightShoulder;
-(PViCadeGamepadButtonInput*) leftTrigger;
-(PViCadeGamepadButtonInput*) rightTrigger;
@end

