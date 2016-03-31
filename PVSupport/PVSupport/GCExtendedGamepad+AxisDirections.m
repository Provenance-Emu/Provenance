//
//  GCExtendedGamepad+AxisDirections.m
//  Provenance
//
//  Created by Tyler Hedrick on 3/30/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "GCExtendedGamepad+AxisDirections.h"

@implementation GCExtendedGamepad (AxisDirections)

- (PVControllerAxisDirection)currentAxisDirectionForLeftThumbstick {
    return [self axisDirectionForThumbstick:self.leftThumbstick];
}

- (PVControllerAxisDirection)currentAxisDirectionForRightThumbstick {
    return [self axisDirectionForThumbstick:self.rightThumbstick];
}

#pragma mark - Private

- (PVControllerAxisDirection)axisDirectionForThumbstick:(GCControllerDirectionPad *)thumbstick {
    static CGFloat thumbstickSensitivty = 0.5;
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
