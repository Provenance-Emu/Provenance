//
//  PViCadeGamepadInputButton.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <GameController/GameController.h>

@interface PViCadeGamepadButtonInput : GCControllerButtonInput {
    GCControllerButtonValueChangedHandler _handler;
}

-(void) buttonPressed;
-(void) buttonReleased;

@end