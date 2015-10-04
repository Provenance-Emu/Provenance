//
//  PViCadeGamepadDirectionPad.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import <GameController/GameController.h>
#import "PViCadeInputAxis.h"
#import "PViCadeGamepadButtonInput.h"

@interface PViCadeGamepadDirectionPad : GCControllerDirectionPad {
    GCControllerDirectionPadValueChangedHandler _handler;
    
    PViCadeAxisInput* _xAxis;
    PViCadeAxisInput* _yAxis;

    PViCadeGamepadButtonInput* _up;
    PViCadeGamepadButtonInput* _down;
    PViCadeGamepadButtonInput* _left;
    PViCadeGamepadButtonInput* _right;
    
}

-(void) padChanged;
-(PViCadeAxisInput*) xAxis;
-(PViCadeAxisInput*) yAxis;
-(PViCadeGamepadButtonInput*) up;
-(PViCadeGamepadButtonInput*) down;
-(PViCadeGamepadButtonInput*) left;
-(PViCadeGamepadButtonInput*) right;

@end
