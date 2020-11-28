/*
 Copyright (c) 2009, OpenEmu Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEGameAudio.h"
#import "TPCircularBuffer.h"
#import "OERingBuffer.h"
#import "PVEmulatorCore.h"
#import "DebugUtils.h"
#import "PVLogging.h"

@import AVFoundation;

typedef struct
{
    TPCircularBuffer *buffer;
    int channelCount;
    int bytesPerSample;
} OEGameAudioContext;

ExtAudioFileRef recordingFile;

static void StretchSamples(int16_t *outBuf, const int16_t *inBuf,
                           int outFrames, int inFrames, int channels)
{
    int frame;
    float ratio = outFrames / (float)inFrames;
    
    for (frame = 0; frame < outFrames; frame++) {
        float iFrame = frame / ratio, iFrameF = floorf(iFrame);
        float lerp = iFrame - iFrameF;
        int iFrameI = iFrameF;
        int ch;
        
        for (ch = 0; ch < channels; ch++) {
            int a, b, c;
            
            a = inBuf[(iFrameI+0)*channels+ch];
            b = inBuf[(iFrameI+1)*channels+ch];
            
            c = a + lerp*(b-a);
            c = MAX(c, SHRT_MIN);
            c = MIN(c, SHRT_MAX);
            
            outBuf[frame*channels+ch] = c;
        }
    }
}
# include <mach/mach_time.h>

OSStatus RenderCallback(void                       *in,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp       *inTimeStamp,
                        UInt32                      inBusNumber,
                        UInt32                      inNumberFrames,
                        AudioBufferList            *ioData);

OSStatus RenderCallback(void                       *in,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp       *inTimeStamp,
                        UInt32                      inBusNumber,
                        UInt32                      inNumberFrames,
                        AudioBufferList            *ioData)
{
//	Float64 timeAtBeginning = convertHostTimeToSeconds(inTimestamp->mHostTime);


    OEGameAudioContext *context = (OEGameAudioContext*)in;
    int availableBytes = 0;
    void *head = TPCircularBufferTail(context->buffer, &availableBytes);
    int bytesRequested = inNumberFrames * context->bytesPerSample * context->channelCount;
    availableBytes = MIN(availableBytes, bytesRequested);
    int leftover = bytesRequested - availableBytes;
    char *outBuffer = ioData->mBuffers[0].mData;

    if (leftover > 0 && context->bytesPerSample==2) {
        // time stretch
        // FIXME this works a lot better with a larger buffer
        int framesRequested = inNumberFrames;
        int framesAvailable = availableBytes / (context->bytesPerSample * context->channelCount);
        StretchSamples((int16_t*)outBuffer, head, framesRequested, framesAvailable, context->channelCount);
    } else if (availableBytes) {
        memcpy(outBuffer, head, availableBytes);
    } else {
        memset(outBuffer, 0, bytesRequested);
    }
    
    TPCircularBufferConsume(context->buffer, availableBytes);
    return noErr;
}

@interface OEGameAudio ()
{
    OEGameAudioContext *_contexts;
    NSNumber           *_outputDeviceID; // nil if no output device has been set (use default)
}
@property (readwrite, nonatomic, assign) BOOL running;
@end

@implementation OEGameAudio

// No default version for this class
- (id)init
{
    return nil;
}

// Designated Initializer
- (id)initWithCore:(PVEmulatorCore *)core
{
    self = [super init];
    if(self != nil)
    {
        NSError *error;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
        if(error) {
            ELOG(@"Audio Error: %@", error.description);
        } else {
            ILOG(@"Successfully set audio session to ambient");
        }

		// You can adjust the latency of RemoteIO (and, in fact, any other audio framework) by setting the kAudioSessionProperty_PreferredHardwareIOBufferDuration property
//		float aBufferLength = 0.005; // In seconds
//		AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(aBufferLength), &aBufferLength);

		_outputDeviceID = 0;
		volume = 1;

        gameCore = core;
        [self createGraph];
    }
    
    return self;
}

- (void)dealloc
{
    if (_contexts)
        free(_contexts);
    AUGraphUninitialize(mGraph);
    //FIXME: added this line tonight.  do we need it?  Fuckety fuck fucking shitty Core Audio documentation... :X
    DisposeAUGraph(mGraph);
}

- (void)pauseAudio
{
    [self stopAudio];
	self.running = NO;
}

- (void)startAudio
{
    [self createGraph];
	self.running = YES;
}

- (void)stopAudio
{
    ExtAudioFileDispose(recordingFile);
    AUGraphStop(mGraph);
    AUGraphClose(mGraph);
    AUGraphUninitialize(mGraph);
	self.running = NO;
}

- (void)createGraph
{
    OSStatus err;
    
    AUGraphStop(mGraph);
    AUGraphClose(mGraph);
    AUGraphUninitialize(mGraph);
    
    //Create the graph
    err = NewAUGraph(&mGraph);
    if(err) ELOG(@"NewAUGraph failed");
    
    //Open the graph
    err = AUGraphOpen(mGraph);
    if(err) ELOG(@"couldn't open graph");
    
    AudioComponentDescription desc;
    
    desc.componentType         = kAudioUnitType_Output;
    desc.componentSubType      = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlagsMask    = 0;
    desc.componentFlags        = 0;

    //Create the output node
    err = AUGraphAddNode(mGraph, (const AudioComponentDescription *)&desc, &mOutputNode);
    if(err) ELOG(@"couldn't create node for output unit");
    
    err = AUGraphNodeInfo(mGraph, mOutputNode, NULL, &mOutputUnit);
    if(err) ELOG(@"couldn't get output from node");
    
    
    desc.componentType = kAudioUnitType_Mixer;
    desc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    //Create the mixer node
    err = AUGraphAddNode(mGraph, (const AudioComponentDescription *)&desc, &mMixerNode);
    if(err) ELOG(@"couldn't create node for file player");
    
    err = AUGraphNodeInfo(mGraph, mMixerNode, NULL, &mMixerUnit);
    if(err) ELOG(@"couldn't get player unit from node");

    desc.componentType = kAudioUnitType_FormatConverter;
    desc.componentSubType = kAudioUnitSubType_AUConverter;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    NSUInteger bufferCount = [gameCore audioBufferCount];
    if (_contexts)
        free(_contexts);
    _contexts = malloc(sizeof(OEGameAudioContext) * bufferCount);
    for (int i = 0; i < bufferCount; ++i)
    {
		TPCircularBufferClear(&([gameCore ringBufferAtIndex:i]->buffer));
		_contexts[i] = (OEGameAudioContext){&([gameCore ringBufferAtIndex:i]->buffer), [gameCore channelCountForBuffer:i], [gameCore audioBitDepth]/8};
        
        //Create the converter node
        err = AUGraphAddNode(mGraph, (const AudioComponentDescription *)&desc, &mConverterNode);
        if(err)  ELOG(@"couldn't create node for converter");
        
        err = AUGraphNodeInfo(mGraph, mConverterNode, NULL, &mConverterUnit);
        if(err) ELOG(@"couldn't get player unit from converter");
        
        
        AURenderCallbackStruct renderStruct;
        renderStruct.inputProc = RenderCallback;
        renderStruct.inputProcRefCon = (void*)&_contexts[i];
        
        err = AudioUnitSetProperty(mConverterUnit, kAudioUnitProperty_SetRenderCallback,
                                   kAudioUnitScope_Input, 0, &renderStruct, sizeof(AURenderCallbackStruct));
        if(err) {
            ELOG(@"Couldn't set the render callback");
        }
        else {
            DLOG(@"Set the render callback");
        }
        AudioStreamBasicDescription mDataFormat;
        NSUInteger channelCount = _contexts[i].channelCount;
        NSUInteger bytesPerSample = _contexts[i].bytesPerSample;
        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
        mDataFormat.mSampleRate       = [gameCore audioSampleRateForBuffer:i];
        mDataFormat.mFormatID         = kAudioFormatLinearPCM;
        mDataFormat.mFormatFlags      = formatFlag | kAudioFormatFlagsNativeEndian;
        mDataFormat.mBytesPerPacket   = bytesPerSample * channelCount;
        mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
        mDataFormat.mBytesPerFrame    = bytesPerSample * channelCount;
        mDataFormat.mChannelsPerFrame = channelCount;
        mDataFormat.mBitsPerChannel   = 8 * bytesPerSample;
        
        err = AudioUnitSetProperty(mConverterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, sizeof(AudioStreamBasicDescription));
        if(err) {
            ELOG(@"couldn't set player's input stream format");
        } {
            DLOG(@"Set the play'ers input stream format");
        }

        err = AUGraphConnectNodeInput(mGraph, mConverterNode, 0, mMixerNode, i);
        if(err) { ELOG(@"Couldn't connect the converter to the mixer"); }
        else { ELOG(@"Connected the converter to the mixer"); }
    }
    // connect the player to the output unit (stream format will propagate)
         
    err = AUGraphConnectNodeInput(mGraph, mMixerNode, 0, mOutputNode, 0);
    if(err) {
        ELOG(@"Could not connect the input of the output");
    } {
        DLOG(@"Connected input of the output");
    }
    
    //AudioUnitSetParameter(mOutputUnit, kAudioUnitParameterUnit_LinearGain, kAudioUnitScope_Global, 0, [[[GameDocumentController sharedDocumentController] preferenceController] volume] ,0);
    AudioUnitSetParameter(mOutputUnit, kAudioUnitParameterUnit_LinearGain, kAudioUnitScope_Global, 0, 1.0 ,0);

    AudioDeviceID outputDeviceID = [_outputDeviceID unsignedIntValue];
//    if(outputDeviceID != 0)
    err = AudioUnitSetProperty(mOutputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, sizeof(outputDeviceID));
    if(err){ ELOG(@"couldn't set device properties"); }

    err = AUGraphInitialize(mGraph);
    if(err){ ELOG(@"couldn't initialize graph"); }
    else { DLOG(@"Initialized the graph"); }

    err = AUGraphStart(mGraph);
    if(err){ ELOG(@"couldn't start graph"); }
    else { DLOG(@"Started the graph"); }
	
        //    CFShow(mGraph);
    [self setVolume:[self volume]];
}

- (AudioDeviceID)outputDeviceID
{
    return [_outputDeviceID unsignedIntValue];
}

- (void)setOutputDeviceID:(AudioDeviceID)outputDeviceID
{
    AudioDeviceID currentID = [self outputDeviceID];
    if(outputDeviceID != currentID)
    {
        _outputDeviceID = (outputDeviceID == 0 ? nil : @(outputDeviceID));

        if(mOutputUnit)
            AudioUnitSetProperty(mOutputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, sizeof(outputDeviceID));
    }
}

- (float)volume
{
    return volume;
}

- (void)setVolume:(float)aVolume
{
    volume = aVolume;
//    NSLog(@"Setting volume to: %f", volume);

    if (mMixerUnit) {
        AudioUnitSetParameter( mMixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, volume, 0 ) ;
    }
}

- (void)volumeUp
{
    float newVolume = volume + 0.1;
    if(newVolume>1.0) newVolume = 1.0;

    [self setVolume:newVolume];
}

- (void)volumeDown
{
    float newVolume = volume - 0.1;
    if(newVolume<0.0) newVolume = 0.0;

    [self setVolume:newVolume];
}

@end
