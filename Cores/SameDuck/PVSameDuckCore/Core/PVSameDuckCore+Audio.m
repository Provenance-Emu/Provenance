//
//  PVSameDuckCore+Audio.m
//  PVSameDuck
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVSameDuckCore+Audio.h"

@implementation PVSameDuckCore (Audio)

- (NSTimeInterval)frameInterval {
    return 60;
}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return 44100;
}

@end
