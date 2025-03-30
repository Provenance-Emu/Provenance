//  PVAzaharCore+Audio.m
//  Copyright © 2023 Provenance. All rights reserved.

#import "PVAzaharCoreBridge+Audio.h"

@implementation PVAzaharCoreBridge (Audio)

- (NSTimeInterval)frameInterval {
    return 60;
}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return 48000;
}

@end
