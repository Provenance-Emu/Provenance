//
//  PVReicast+Audio.m
//  PVReicast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVReicast+CoreAudio.h"
#import "PVReicast+Audio.h"
#import "PVReicast+AudioTypes.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - Core Audio Setup -

void
InitAUPlayer(ReicastAUGraphPlayer *player) {
    /* allocate some buffers to hold samples between input and output callbacks
     (this part largely copied from CAPlayThrough) */
        //Get the size of the IO buffer(s)
    Float64 sampleRate;
    Float32 bufferDuration;

#if TARGET_OS_IOS
    UInt32 propSize = sizeof(Float64);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                            &propSize,
                            &sampleRate);

    propSize = sizeof(Float32);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
                            &propSize,
                            &bufferDuration);
#else
#endif
    UInt32 bufferLengthInFrames = sampleRate * bufferDuration;
    UInt32 bufferSizeBytes = bufferLengthInFrames * sizeof(Float32);

    if (player->streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
        ILOG(@"format is non-interleaved\n");
            // allocate an AudioBufferList plus enough space for array of AudioBuffers
        UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * player->streamFormat.mChannelsPerFrame);

            //malloc buffer lists
        player->inputBuffer = (AudioBufferList *)malloc(propsize);
        player->inputBuffer->mNumberBuffers = player->streamFormat.mChannelsPerFrame;

            //pre-malloc buffers for AudioBufferLists
        for(UInt32 i =0; i< player->inputBuffer->mNumberBuffers ; i++) {
            player->inputBuffer->mBuffers[i].mNumberChannels = 1;
            player->inputBuffer->mBuffers[i].mDataByteSize = bufferSizeBytes;
            player->inputBuffer->mBuffers[i].mData = malloc(bufferSizeBytes);
        }
    } else {
        ILOG(@"format is interleaved\n");
            // allocate an AudioBufferList plus enough space for array of AudioBuffers
        UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * 1);

            //malloc buffer lists
        player->inputBuffer = (AudioBufferList *)malloc(propsize);
        player->inputBuffer->mNumberBuffers = 1;

            //pre-malloc buffers for AudioBufferLists
        player->inputBuffer->mBuffers[0].mNumberChannels = player->streamFormat.mChannelsPerFrame;
        player->inputBuffer->mBuffers[0].mDataByteSize = bufferSizeBytes;
        player->inputBuffer->mBuffers[0].mData = malloc(bufferSizeBytes);
    }

        //Alloc ring buffer that will hold data between the two audio devices
    player->ringBuffer = new CARingBuffer();
    player->ringBuffer->Allocate(player->streamFormat.mChannelsPerFrame,
                                 player->streamFormat.mBytesPerFrame,
                                 bufferLengthInFrames * 4000);

    player->firstInputSampleTime = -1;
    player->firstOutputSampleTime = -1;
    player->inToOutSampleTimeOffset = -1;

    CheckError(AUGraphStart(player->graph), "AUGraphStart failed");

    settings.aica.BufferSize = bufferLengthInFrames;

        //    settings.aica.LimitFPS = 1;
}

void
CreateMyAUGraph(ReicastAUGraphPlayer *player)
{
#if COREAUDIO_USE_DEFAULT
    NAssert(@"Shouldn't be here.");
#endif

    GET_CURRENT_OR_RETURN();

    AUGraphStop(player->graph);
    AUGraphClose(player->graph);
    AUGraphUninitialize(player->graph);

        // create a new AUGraph
    CheckError(NewAUGraph(&player->graph),
               "NewAUGraph failed");

        //Open the graph
    CheckError(AUGraphOpen(player->graph),
               "couldn't open graph");

    AudioComponentDescription desc = {0};

    desc.componentType         = kAudioUnitType_Output;
    desc.componentSubType      = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlagsMask    = 0;
    desc.componentFlags        = 0;


        // adds a node with above description to the graph
    AUNode outputNode;
    CheckError(AUGraphAddNode(player->graph,  (const AudioComponentDescription *)&desc, &outputNode),
               "AUGraphAddNode[kAudioUnitSubType_DefaultOutput] failed");

    CheckError(AUGraphNodeInfo(player->graph, outputNode, NULL, &player->outputUnit),
               "couldn't get output from node");

    desc.componentType = kAudioUnitType_Mixer;
    desc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

        //Create the mixer node
    AUNode mixerNode;

    CheckError(AUGraphAddNode(player->graph, (const AudioComponentDescription *)&desc, &mixerNode),
               "couldn't create node for file player");

    AudioUnit mixerUnit;

    CheckError(AUGraphNodeInfo(player->graph, mixerNode, NULL, &mixerUnit),
               "couldn't get player unit from node");

    desc.componentType = kAudioUnitType_FormatConverter;
    desc.componentSubType = kAudioUnitSubType_AUConverter;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    NSUInteger bufferCount = [current audioBufferCount];

        //Create the converter node
    AUNode mConverterNode;
    CheckError(AUGraphAddNode(player->graph, (const AudioComponentDescription *)&desc, &mConverterNode),
               "couldn't create node for converter");

    CheckError(AUGraphNodeInfo(player->graph, mConverterNode, NULL, &player->converterUnit),
               "couldn't get player unit from converter");


    AURenderCallbackStruct renderStruct;
    renderStruct.inputProc = GraphRenderProc;
    renderStruct.inputProcRefCon = (void*)&player;

    CheckError(AudioUnitSetProperty(player->converterUnit, kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input, 0, &renderStruct, sizeof(AURenderCallbackStruct)),
               "Couldn't set the render callback");

        //    CheckError(AudioUnitSetProperty(player->outputUnit,
        //                                    kAudioUnitProperty_SetRenderCallback,
        //                                    kAudioUnitScope_Global,
        //                                    0,
        //                                    &renderStruct,
        //                                    sizeof(renderStruct)),
        //               "Couldn't set render callback on output unit");

    AudioStreamBasicDescription mDataFormat;
    NSUInteger channelCount =  [current channelCount];
    NSUInteger bytesPerSample = [current audioBitDepth] / 8;

        //    int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
        //    mDataFormat.mSampleRate       = [current audioSampleRateForBuffer:0];
        //    mDataFormat.mFormatID         = kAudioFormatLinearPCM;
        //    mDataFormat.mFormatFlags      = formatFlag | kAudioFormatFlagsNativeEndian;
        //    mDataFormat.mBytesPerPacket   = bytesPerSample * channelCount;
        //    mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
        //    mDataFormat.mBytesPerFrame    = bytesPerSample * channelCount;
        //    mDataFormat.mChannelsPerFrame = channelCount;
        //    mDataFormat.mBitsPerChannel   = 8 * bytesPerSample;

        //        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
    mDataFormat.mSampleRate       = 44100;
    mDataFormat.mFormatID         = kAudioFormatLinearPCM;
    mDataFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; ////formatFlag | kAudioFormatFlagsNativeEndian;
    mDataFormat.mBytesPerPacket   =  2*16/8; //bytesPerSample * channelCount;
    mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
    mDataFormat.mBytesPerFrame    = 2*16/8; //bytesPerSample * channelCount;
    mDataFormat.mChannelsPerFrame =  2; //channelCount;
    mDataFormat.mBitsPerChannel   = 16; //8 * bytesPerSample;

    player->streamFormat = mDataFormat;

    CheckError(AudioUnitSetProperty(player->converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, sizeof(AudioStreamBasicDescription)),
               "couldn't set player's input stream format");

    CheckError(AUGraphConnectNodeInput(player->graph, mConverterNode, 0, mixerNode, 0),
               "Couldn't connect the converter to the mixer");

    CheckError(AUGraphConnectNodeInput(player->graph, mixerNode, 0, outputNode, 0),
               "Could not connect the input of the output");

    AudioUnitSetParameter(player->outputUnit, kAudioUnitParameterUnit_LinearGain, kAudioUnitScope_Global, 0, 1.0 ,0);

        //    AudioDeviceID outputDeviceID = 0;
        //    //    if(outputDeviceID != 0)
        //    CheckError(AudioUnitSetProperty(player->outputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, sizeof(AudioDeviceID)),
        //        "couldn't set device properties");

    CheckError(AUGraphInitialize(player->graph),
               "couldn't initialize graph");

    DLOG(@"Initialized the graph");

        //    CheckError(AUGraphStart(player->graph),
        //        "couldn't start graph");
        //
        //    DLOG(@"Started the graph");

        //     CFShow(player->graph);
    float volume = 1.0;
    AudioUnitSetParameter( mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, volume, 0 ) ;
        //
        //#define PART_II 0
        //#ifdef PART_II
        //    AudioStreamBasicDescription mDataFormat;
        //    NSUInteger channelCount =  [current channelCount];
        //    NSUInteger bytesPerSample = [current audioBitDepth] / 8;
        //
        //    //        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
        //    mDataFormat.mSampleRate       = 44100;
        //    mDataFormat.mFormatID         = kAudioFormatLinearPCM;
        //    mDataFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; ////formatFlag | kAudioFormatFlagsNativeEndian;
        //    mDataFormat.mBytesPerPacket   =  2*16/8; //bytesPerSample * channelCount;
        //    mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
        //    mDataFormat.mBytesPerFrame    = 2*16/8; //bytesPerSample * channelCount;
        //    mDataFormat.mChannelsPerFrame =  2; //channelCount;
        //    mDataFormat.mBitsPerChannel   = 16; //8 * bytesPerSample;
        //
        //    player->streamFormat = mDataFormat;
        //
        //    // add a mixer to the graph,
        //    AudioComponentDescription mixercd = {0};
        //    mixercd.componentType = kAudioUnitType_Mixer;
        //    mixercd.componentSubType = kAudioUnitSubType_MultiChannelMixer; // doesn't work: kAudioUnitSubType_MatrixMixer
        //    mixercd.componentManufacturer = kAudioUnitManufacturer_Apple;
        //    AUNode mixerNode;
        //    CheckError(AUGraphAddNode(player->graph, &mixercd, &mixerNode),
        //               "AUGraphAddNode[kAudioUnitSubType_StereoMixer] failed");
        //
        //    // adds a node with above description to the graph
        ////    AudioComponentDescription speechcd = {0};
        ////    speechcd.componentType = kAudioUnitType_Generator;
        ////    speechcd.componentSubType = kAudioUnitSubType_SpeechSynthesis;
        ////    speechcd.componentManufacturer = kAudioUnitManufacturer_Apple;
        ////    AUNode speechNode;
        ////    CheckError(AUGraphAddNode(player->graph, &speechcd, &speechNode),
        ////               "AUGraphAddNode[kAudioUnitSubType_AudioFilePlayer] failed");
        //
        //    // opening the graph opens all contained audio units but does not allocate any resources yet
        //    CheckError(AUGraphOpen(player->graph),
        //               "AUGraphOpen failed");
        //
        //    // get the reference to the AudioUnit objects for the various nodes
        ////    CheckError(AUGraphNodeInfo(player->graph, outputNode, NULL, &player->outputUnit),
        ////               "AUGraphNodeInfo failed");
        ////    CheckError(AUGraphNodeInfo(player->graph, speechNode, NULL, &player->speechUnit),
        ////               "AUGraphNodeInfo failed");
        //    AudioUnit mixerUnit;
        //    CheckError(AUGraphNodeInfo(player->graph, mixerNode, NULL, &mixerUnit),
        //               "AUGraphNodeInfo failed");
        //
        //    // set ASBDs here
        //    UInt32 propertySize = sizeof (AudioStreamBasicDescription);
        //    CheckError(AudioUnitSetProperty(player->outputUnit,
        //                                    kAudioUnitProperty_StreamFormat,
        //                                    kAudioUnitScope_Input,
        //                                    0,
        //                                    &player->streamFormat,
        //                                    propertySize),
        //               "Couldn't set stream format on output unit");
        //
        //    // problem: badComponentInstance (-2147450879)
        //    CheckError(AudioUnitSetProperty(mixerUnit,
        //                                    kAudioUnitProperty_StreamFormat,
        //                                    kAudioUnitScope_Input,
        //                                    0,
        //                                    &player->streamFormat,
        //                                    propertySize),
        //               "Couldn't set stream format on mixer unit bus 0");
        //    CheckError(AudioUnitSetProperty(mixerUnit,
        //                                    kAudioUnitProperty_StreamFormat,
        //                                    kAudioUnitScope_Input,
        //                                    1,
        //                                    &player->streamFormat,
        //                                    propertySize),
        //               "Couldn't set stream format on mixer unit bus 1");
        //
        //
        //    // connections
        //    // mixer output scope / bus 0 to outputUnit input scope / bus 0
        //    // mixer input scope / bus 0 to render callback (from ringbuffer, which in turn is from inputUnit)
        //    // mixer input scope / bus 1 to speech unit output scope / bus 0
        //
        //    CheckError(AUGraphConnectNodeInput(player->graph, mixerNode, 0, outputNode, 0),
        //               "Couldn't connect mixer output(0) to outputNode (0)");
        ////    CheckError(AUGraphConnectNodeInput(player->graph, speechNode, 0, mixerNode, 1),
        ////               "Couldn't connect speech synth unit output (0) to mixer input (1)");
        //    AURenderCallbackStruct callbackStruct;
        //    callbackStruct.inputProc = GraphRenderProc;
        //    callbackStruct.inputProcRefCon = player;
        //    CheckError(AudioUnitSetProperty(mixerUnit,
        //                                    kAudioUnitProperty_SetRenderCallback,
        //                                    kAudioUnitScope_Global,
        //                                    0,
        //                                    &callbackStruct,
        //                                    sizeof(callbackStruct)),
        //               "Couldn't set render callback on mixer unit");
        //
        //
        //#else
        //
        //    // opening the graph opens all contained audio units but does not allocate any resources yet
        //    CheckError(AUGraphOpen(player->graph),
        //               "AUGraphOpen failed");
        //
        //    // get the reference to the AudioUnit object for the output graph node
        //    CheckError(AUGraphNodeInfo(player->graph, outputNode, NULL, &player->outputUnit),
        //               "AUGraphNodeInfo failed");
        //
        //    AudioStreamBasicDescription mDataFormat;
        //    NSUInteger channelCount =  [current channelCount];
        //    NSUInteger bytesPerSample = [current audioBitDepth] / 8;
        //
        //    //        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
        //    mDataFormat.mSampleRate       = 44100;
        //    mDataFormat.mFormatID         = kAudioFormatLinearPCM;
        //    mDataFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; ////formatFlag | kAudioFormatFlagsNativeEndian;
        //    mDataFormat.mBytesPerPacket   =  2*16/8; //bytesPerSample * channelCount;
        //    mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
        //    mDataFormat.mBytesPerFrame    = 2*16/8; //bytesPerSample * channelCount;
        //    mDataFormat.mChannelsPerFrame =  2; //channelCount;
        //    mDataFormat.mBitsPerChannel   = 16; //8 * bytesPerSample;
        //
        //    player->streamFormat = mDataFormat;
        ////    OSStatus inputProcErr = noErr;
        ////    err = AudioUnitSetProperty(mConverterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, sizeof(AudioStreamBasicDescription));
        //
        //    // set the stream format on the output unit's input scope
        //    UInt32 propertySize = sizeof (AudioStreamBasicDescription);
        //    CheckError(AudioUnitSetProperty(player->outputUnit,
        //                                    kAudioUnitProperty_StreamFormat,
        //                                    kAudioUnitScope_Input,
        //                                    0,
        //                                    &player->streamFormat,
        //                                    propertySize),
        //               "Couldn't set stream format on output unit");
        //
        //    AURenderCallbackStruct callbackStruct;
        //    callbackStruct.inputProc = GraphRenderProc;
        //    callbackStruct.inputProcRefCon = player;
        //
        //    CheckError(AudioUnitSetProperty(player->outputUnit,
        //                                    kAudioUnitProperty_SetRenderCallback,
        //                                    kAudioUnitScope_Global,
        //                                    0,
        //                                    &callbackStruct,
        //                                    sizeof(callbackStruct)),
        //               "Couldn't set render callback on output unit");
        //
        //#endif
        //
        //
        //    // now initialize the graph (causes resources to be allocated)
        //    CheckError(AUGraphInitialize(player->graph),
        //               "AUGraphInitialize failed");

    player->firstOutputSampleTime = -1;

    CALOG("Bottom of CreateSimpleAUGraph()\n");
}

#pragma mark - Render Callback -

OSStatus
GraphRenderProc(void *inRefCon,
                AudioUnitRenderActionFlags *ioActionFlags,
                const AudioTimeStamp *inTimeStamp,
                UInt32 inBusNumber,
                UInt32 inNumberFrames,
                AudioBufferList * ioData)
{
#if COREAUDIO_USE_DEFAULT
    NAssert(@"Shouldn't be here.");
    return 0;
#else

    read_ptr += inNumberFrames;
        //  CALOG("GraphRenderProc! need %d frames for time %f \n", inNumberFrames, inTimeStamp->mSampleTime);

        //  ReicastAUGraphPlayer *player = (ReicastAUGraphPlayer*) inRefCon;

        // have we ever logged output timing? (for offset calculation)
    if (player.firstOutputSampleTime < 0.0) {
        player.firstOutputSampleTime = inTimeStamp->mSampleTime;
        if ((player.firstInputSampleTime > -1.0) &&
            (player.inToOutSampleTimeOffset < 0.0)) {
            player.inToOutSampleTimeOffset =
            player.firstInputSampleTime - player.firstOutputSampleTime;
        }
    }

        // copy samples out of ring buffer
    OSStatus outputProcErr = noErr;

        //    Float64 time = inTimeStamp->mSampleTime + player.inToOutSampleTimeOffset;
    Float64 time = read_ptr + player.inToOutSampleTimeOffset;

        // new CARingBuffer doesn't take bool 4th arg
    outputProcErr = player.ringBuffer->Fetch(ioData,
                                             inNumberFrames,
                                             time);
        //    float freq = 440.f;
        //    int seconds = 4;
        //    unsigned sample_rate = 44100;
        //    size_t buf_size = seconds * sample_rate;
        //
        //    short *samples;
        //    samples = new short[buf_size];
        //    for(int i=0; i<buf_size; ++i) {
        //        samples[i] = 32760 * sin( (2.f*float(M_PI)*freq)/sample_rate * i );
        //    }
        //
        //    memcpy(ioData->mBuffers[0].mData, samples, inNumberFrames);

        //    memcpy(ioData->mBuffers[0].mData, player.inputBuffer->mBuffers[0].mData, inNumberFrames);
        //
    samples_ptr -= inNumberFrames * 2 * 2;

    if (samples_ptr < 0)
        samples_ptr = 0;

    printf ("fetched %d frames at time %f error: %i\n", inNumberFrames, time, outputProcErr);
    return outputProcErr;
#endif
}


#pragma mark - Utilities -


static AudioBufferList *
AllocateABL(UInt32 channelsPerFrame, UInt32 bytesPerFrame, bool interleaved, UInt32 capacityFrames)
{
    AudioBufferList *bufferList = NULL;

    UInt32 numBuffers = interleaved ? 1 : channelsPerFrame;
    UInt32 channelsPerBuffer = interleaved ? channelsPerFrame : 1;

    bufferList = static_cast<AudioBufferList *>(calloc(1, offsetof(AudioBufferList, mBuffers) + (sizeof(AudioBuffer) * numBuffers)));

    bufferList->mNumberBuffers = numBuffers;

    for(UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; ++bufferIndex) {
        bufferList->mBuffers[bufferIndex].mData = static_cast<void *>(calloc(capacityFrames, bytesPerFrame));
        bufferList->mBuffers[bufferIndex].mDataByteSize = capacityFrames * bytesPerFrame;
        bufferList->mBuffers[bufferIndex].mNumberChannels = channelsPerBuffer;
    }

    return bufferList;
}

static void
CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;

    char errorString[20];
        // see if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
            // no, format it as an integer
        sprintf(errorString, "%d", (int)error);
    }

    ELOG(@"CoreAudio: %s (%s)", operation, errorString);

    exit(1);
}
