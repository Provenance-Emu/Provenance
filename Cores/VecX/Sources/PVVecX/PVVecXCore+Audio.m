//
//  PVVecXCore+Audio.m
//  PVVecX
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVVecXCore+Audio.h"

@implementation PVVecXCoreBridge (Audio)

- (NSTimeInterval)frameInterval {
    return 59.72;
}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return 44100;
}

@end
