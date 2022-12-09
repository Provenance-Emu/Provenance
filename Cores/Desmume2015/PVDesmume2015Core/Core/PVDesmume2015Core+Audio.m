//
//  PVDesmume2015Core+Audio.m
//  PVDesmume2015
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVDesmume2015Core+Audio.h"

@implementation PVDesmume2015Core (Audio)

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
