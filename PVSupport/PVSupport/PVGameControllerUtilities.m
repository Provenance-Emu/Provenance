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
    static CGFloat thumbstickSensitivty = 0.1;
    BOOL isXAxis = (fabsf(thumbstick.xAxis.value) > fabsf(thumbstick.yAxis.value));
    if (!isXAxis && thumbstick.yAxis.value >= thumbstickSensitivty) {
        return PVControllerAxisDirectionUp;
    }
    if (!isXAxis && thumbstick.yAxis.value <= -thumbstickSensitivty) {
        return PVControllerAxisDirectionDown;
    }
    if (isXAxis && thumbstick.xAxis.value <= -thumbstickSensitivty) {
        return PVControllerAxisDirectionLeft;
    }
    if (isXAxis && thumbstick.xAxis.value >= thumbstickSensitivty) {
        return PVControllerAxisDirectionRight;
    }
    return PVControllerAxisDirectionNone;
}

@end
