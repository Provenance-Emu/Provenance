//
//  PVPSXEmulatorCore.h
//  PVPSX
//
//  Created by David Green on 10/27/14.
//  Copyright (c) 2014 David Green. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVEmulatorCore.h"

typedef NS_ENUM(NSUInteger, PVPSXButton)
{
	PVPSXButtonUp,
	PVPSXButtonDown,
	PVPSXButtonLeft,
	PVPSXButtonRight,
	PVPSXButtonTriangle,
	PVPSXButtonCircle,
	PVPSXButtonCross,
	PVPSXButtonSquare,
	PVPSXButtonL1,
	PVPSXButtonL2,
	PVPSXButtonL3,
	PVPSXButtonR1,
	PVPSXButtonR2,
	PVPSXButtonR3,
	PVPSXButtonStart,
	PVPSXButtonSelect,
	PVPSXButtonAnalogMode,
	PVPSXLeftAnalogUp,
	PVPSXLeftAnalogDown,
	PVPSXLeftAnalogLeft,
	PVPSXLeftAnalogRight,
	PVPSXRightAnalogUp,
	PVPSXRightAnalogDown,
	PVPSXRightAnalogLeft,
	PVPSXRightAnalogRight,
	PVPSXButtonCount
};

@interface PVPSXEmulatorCore : PVEmulatorCore

- (void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value;
- (void)didPushPSXButton:(PVPSXButton)button;
- (void)didReleasePSXButton:(PVPSXButton)button;

@end
