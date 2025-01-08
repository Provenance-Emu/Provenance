//
//  PVRetroArchCoreBridge+Audio.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Audio.h"

@implementation PVRetroArchCoreBridge (Audio)

- (NSTimeInterval)frameInterval {
	return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount {
	return 2;
}

- (double)audioSampleRate {
	return sampleRate;
}

@end
