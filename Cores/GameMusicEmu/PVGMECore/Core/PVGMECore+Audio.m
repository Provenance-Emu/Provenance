//
//  PVGMECore+Audio.m
//  PVGME
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVGMECore+Audio.h"

@implementation PVGMECore (Audio)

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
