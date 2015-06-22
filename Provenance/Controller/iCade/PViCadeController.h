//
//  PViCadeController.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import <GameController/GameController.h>

@class PViCadeGamepad;
@class PViCadeReader;

@interface PViCadeController : GCController {
    PViCadeGamepad* _gamepad;
    PViCadeReader* _reader;
}

@property (copy) void (^controllerPressedAnyKey)(PViCadeController *controller);

@end