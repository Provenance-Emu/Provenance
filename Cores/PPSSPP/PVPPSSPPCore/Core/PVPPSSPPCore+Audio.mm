//
//  PVPPSSPPCore+Audio.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPPSSPPCore+Audio.h"
@import PVSupport;
@import PVEmulatorCore;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVLoggingObjC;

/* PPSSPP Includes */
#include "Common/Log.h"
#include <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenAL/al.h>
#import <OpenAL/alc.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <string>

#define AUDIO_CHANNELS      2
#define AUDIO_SAMPLES       8192
#define AUDIO_SAMPLESIZE    sizeof(int16_t)
#define AUDIO_BUFFERSIZE   (AUDIO_SAMPLESIZE * AUDIO_CHANNELS * AUDIO_SAMPLES)
#define SAMPLE_SIZE 44100

@implementation PVPPSSPPCoreBridge (Audio)

- (NSTimeInterval)frameInterval {
	return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount {
	return AUDIO_CHANNELS;
}

- (double)audioSampleRate {
	return SAMPLE_SIZE;
}
@end
