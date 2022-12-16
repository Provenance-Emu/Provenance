//
//  PVPlayCore+Audio.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore+Audio.h"

@implementation PVPlayCore (Audio)

- (NSTimeInterval)frameInterval {
    return 30.0;
}

//- (NSTimeInterval)frameInterval {
//    return isNTSC ? 60 : 50;
//}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return sampleRate;
}

@end
