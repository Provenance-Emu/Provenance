//
//  PVGameControllerUtilities.m
//  PVSupport
//
//  Created by Tyler Hedrick on 4/3/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVGameControllerUtilities.h"

#import <GameController/GameController.h>

@implementation PVGameControllerUtilities

+ (PVControllerAxisDirection)axisDirectionForThumbstick:(GCControllerDirectionPad *)thumbstick {
    static CGFloat thumbstickSensitivty = 0.2;
        
    if (fabsf(thumbstick.xAxis.value) <= thumbstickSensitivty && fabsf(thumbstick.yAxis.value) <= thumbstickSensitivty) {
        return PVControllerAxisDirectionNone;
    }
    
    float angle = atan2f(thumbstick.yAxis.value, thumbstick.xAxis.value);

    if (angle >= 7 * M_PI / 8 || angle <= -7 * M_PI / 8) {
        return PVControllerAxisDirectionLeft;
    }
    
    if (angle > 5 * M_PI / 8) {
        return PVControllerAxisDirectionUpLeft;
    }
    if (angle >= 3 * M_PI / 8) {
        return PVControllerAxisDirectionUp;
    }
    if (angle > 1 * M_PI / 8) {
        return PVControllerAxisDirectionUpRight;
    }
    
    if (angle < -5 * M_PI / 8) {
        return PVControllerAxisDirectionDownLeft;
    }
    if (angle <= -3 * M_PI / 8) {
        return PVControllerAxisDirectionDown;
    }
    if (angle < -1 * M_PI / 8) {
        return PVControllerAxisDirectionDownRight;
    }
    
    return PVControllerAxisDirectionRight;
}

@end
