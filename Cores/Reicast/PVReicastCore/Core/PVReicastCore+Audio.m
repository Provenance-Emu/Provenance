//
//  PVReicastCore+Audio.m
//  PVReicast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVReicastCore+Audio.h"

@implementation PVReicastCoreBridge (Audio)

- (NSTimeInterval)frameInterval {
    return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return sampleRate;
}

// In PVReicast implementation
- (NSUInteger)audioBufferSize
{
    // Use a larger buffer in interpreter mode to handle timing variations
    #ifdef TARGET_NO_REC
    return 4096; // Larger buffer for interpreter mode
    #else
    return 2048; // Normal buffer size for JIT mode
    #endif
}

@end
