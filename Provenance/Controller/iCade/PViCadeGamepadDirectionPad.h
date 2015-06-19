//
//  PViCadeGamepadDirectionPad.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <GameController/GameController.h>
#import "PViCadeInputAxis.h"

@interface PViCadeGamepadDirectionPad : GCControllerDirectionPad {
    GCControllerDirectionPadValueChangedHandler _handler;
    
    PViCadeAxisInput* _xAxis;
    PViCadeAxisInput* _yAxis;
    
}

-(void) padChanged;
-(PViCadeAxisInput*) xAxis;
-(PViCadeAxisInput*) yAxis;

@end
