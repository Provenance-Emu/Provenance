//
//  PVPSXEmulatorCore.m
//  PVPSX
//
//  Created by David Green on 10/27/14.
//  Copyright (c) 2014 David Green. All rights reserved.
//

#import "PVPSXEmulatorCore.h"
#import "OERingBuffer.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>

@interface PVPSXEmulatorCore ()
{
	uint32_t *inputBuffer[2];
	int systemType;
	int videoWidth, videoHeight;
	int videoOffsetX, videoOffsetY;
	//NSString *romName;
	//double sampleRate;
	double masterClock;
	
//	NSString *mednafenCoreModule;
//	NSTimeInterval mednafenCoreTiming;
//	OEIntSize mednafenCoreAspect;
}

@end

@implementation PVPSXEmulatorCore

@end
