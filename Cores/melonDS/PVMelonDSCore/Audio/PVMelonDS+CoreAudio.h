//
//  PVMelonDS+CoreAudio.h
//  PVMelonDS
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/CARingBuffer.h>
#import <PVSupport/OEGameAudio.h>

typedef struct MelonDSAUGraphPlayer {
    AudioStreamBasicDescription streamFormat;
    AUGraph graph;
    AudioUnit inputUnit;
    AudioUnit outputUnit;
    AudioUnit converterUnit;

    AudioBufferList *inputBuffer;
    CARingBuffer *ringBuffer;
    Float64 firstInputSampleTime;
    Float64 firstOutputSampleTime;
    Float64 inToOutSampleTimeOffset;
} MelonDSAUGraphPlayer;

static MelonDSAUGraphPlayer player;

OSStatus InputRenderProc(void *inRefCon,
                         AudioUnitRenderActionFlags *ioActionFlags,
                         const AudioTimeStamp *inTimeStamp,
                         UInt32 inBusNumber,
                         UInt32 inNumberFrames,
                         AudioBufferList * ioData);
OSStatus GraphRenderProc(void *inRefCon,
                         AudioUnitRenderActionFlags *ioActionFlags,
                         const AudioTimeStamp *inTimeStamp,
                         UInt32 inBusNumber,
                         UInt32 inNumberFrames,
                         AudioBufferList * ioData);

void CreateMyAUGraph(MelonDSAUGraphPlayer *player);
void InitAUPlayer(MelonDSAUGraphPlayer *player);
static void CheckError(OSStatus error, const char *operation);
