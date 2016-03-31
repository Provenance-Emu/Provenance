//
//  PVGameControllerUtilities.h
//  PVSupport
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

@class GCControllerDirectionPad;

typedef NS_ENUM(NSUInteger, PVControllerAxisDirection) {
    PVControllerAxisDirectionNone,
    PVControllerAxisDirectionUp,
    PVControllerAxisDirectionDown,
    PVControllerAxisDirectionLeft,
    PVControllerAxisDirectionRight
};

@interface PVGameControllerUtilities : NSObject
+ (PVControllerAxisDirection)axisDirectionForThumbstick:(GCControllerDirectionPad *)thumbstick;
@end
