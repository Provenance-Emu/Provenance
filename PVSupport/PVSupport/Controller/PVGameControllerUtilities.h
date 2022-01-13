//
//  PVGameControllerUtilities.h
//  PVSupport
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <GameController/GameController.h>

typedef NS_ENUM(NSUInteger, PVControllerAxisDirection) {
    PVControllerAxisDirectionNone,
    PVControllerAxisDirectionUp,
    PVControllerAxisDirectionDown,
    PVControllerAxisDirectionLeft,
    PVControllerAxisDirectionRight,
    PVControllerAxisDirectionUpRight,
    PVControllerAxisDirectionUpLeft,
    PVControllerAxisDirectionDownRight,
    PVControllerAxisDirectionDownLeft
};

@interface PVGameControllerUtilities : NSObject
+ (PVControllerAxisDirection)axisDirectionForThumbstick:(GCControllerDirectionPad *)thumbstick;
@end
