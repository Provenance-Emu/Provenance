//
//  GCExtendedGamepad+AxisDirections.h
//  Provenance
//
//  Created by Tyler Hedrick on 3/30/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <GameController/GameController.h>

typedef NS_ENUM(NSUInteger, PVControllerAxisDirection) {
    PVControllerAxisDirectionNone,
    PVControllerAxisDirectionUp,
    PVControllerAxisDirectionDown,
    PVControllerAxisDirectionLeft,
    PVControllerAxisDirectionRight
};

@interface GCExtendedGamepad (AxisDirections)

- (PVControllerAxisDirection)currentAxisDirectionForLeftThumbstick;
- (PVControllerAxisDirection)currentAxisDirectionForRightThumbstick;

@end