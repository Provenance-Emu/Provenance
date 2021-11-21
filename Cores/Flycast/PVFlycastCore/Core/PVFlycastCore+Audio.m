//
//  PVFlycastCore+Audio.m
//  PVFlycast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVFlycastCore+Audio.h"

@implementation PVFlycastCore (Audio)

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
