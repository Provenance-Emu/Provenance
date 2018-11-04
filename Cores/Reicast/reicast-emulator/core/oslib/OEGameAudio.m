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

#import <CoreAudio/CoreAudioTypes.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

volatile int samples_ptr = 0;

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
//
//	samples_ptr -= inNumberFrames * 2 * 2;
//
//	if (samples_ptr < 0)
//		samples_ptr = 0;

    return noErr;
}

@interface OEGameAudio ()
{
    OEGameAudioContext *_contexts;
    NSNumber           *_outputDeviceID; // nil if no output device has been set (use default)

	OERingBuffer __strong **ringBuffers;
}
@end

@implementation OEGameAudio

// Designated Initializer
- (id)init
{
    self = [super init];
    if(self != nil)
    {
        NSError *error;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
        if(error) {
			NSLog(@"%@", error);
        } else {
            //NSLog(@"Successfully set audio session to ambient");
        }

		_outputDeviceID = 0;
		volume = 1;
		
		NSUInteger count = [self audioBufferCount];
		ringBuffers = (__strong OERingBuffer **)calloc(count, sizeof(OERingBuffer *));

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

	for (NSUInteger i = 0, count = [self audioBufferCount]; i < count; i++)
	{
		ringBuffers[i] = nil;
	}

	free(ringBuffers);
}

- (void)pauseAudio
{
    [self stopAudio];
}

- (void)startAudio
{
    [self createGraph];
}

- (void)stopAudio
{
    ExtAudioFileDispose(recordingFile);
    AUGraphStop(mGraph);
    AUGraphClose(mGraph);
    AUGraphUninitialize(mGraph);
}

- (NSTimeInterval)frameInterval
{
	// TODO: PAL?
	return 59.95;
}

- (double)audioSampleRate
{
	// Correct?
	return 44100;
}

- (NSUInteger)audioBufferCount
{
	return 1;
}

- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer
{
	// 4 frames is a complete guess
	double frameSampleCount = [self audioSampleRateForBuffer:buffer] / [self frameInterval];
	NSUInteger channelCount = [self channelCountForBuffer:buffer];
	NSUInteger bytesPerSample = [self audioBitDepth] / 8;
	NSAssert(frameSampleCount, @"frameSampleCount is 0");
	return channelCount*bytesPerSample * frameSampleCount;
}

- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index
{
	if (ringBuffers[index] == nil)
	{
		ringBuffers[index] = [[OERingBuffer alloc] initWithLength:[self audioBufferSizeForBuffer:index] * 16];
	}

	return ringBuffers[index];
}

- (NSUInteger)channelCount
{
	return 2;
}

- (NSUInteger)audioBitDepth
{
	return 16;
}

- (double)audioSampleRateForBuffer:(NSUInteger)buffer
{
	if(buffer == 0)
	{
		return [self audioSampleRate];
	}

	return 0;
}

- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer
{
	if (buffer == 0)
	{
		return [self channelCount];
	}

	return 0;
}

- (void)createGraph
{
    OSStatus err;
    
    AUGraphStop(mGraph);
    AUGraphClose(mGraph);
    AUGraphUninitialize(mGraph);
    
    //Create the graph
    err = NewAUGraph(&mGraph);
    if(err) NSLog(@"NewAUGraph failed");
    
    //Open the graph
    err = AUGraphOpen(mGraph);
    if(err) NSLog(@"couldn't open graph");
    
    AudioComponentDescription desc;
    
    desc.componentType         = kAudioUnitType_Output;
    desc.componentSubType      = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlagsMask    = 0;
    desc.componentFlags        = 0;

    //Create the output node
    err = AUGraphAddNode(mGraph, (const AudioComponentDescription *)&desc, &mOutputNode);
    if(err) NSLog(@"couldn't create node for output unit");
    
    err = AUGraphNodeInfo(mGraph, mOutputNode, NULL, &mOutputUnit);
    if(err) NSLog(@"couldn't get output from node");
    
    
    desc.componentType = kAudioUnitType_Mixer;
    desc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    //Create the mixer node
    err = AUGraphAddNode(mGraph, (const AudioComponentDescription *)&desc, &mMixerNode);
    if(err) NSLog(@"couldn't create node for file player");
    
    err = AUGraphNodeInfo(mGraph, mMixerNode, NULL, &mMixerUnit);
    if(err) NSLog(@"couldn't get player unit from node");

    desc.componentType = kAudioUnitType_FormatConverter;
    desc.componentSubType = kAudioUnitSubType_AUConverter;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    NSUInteger bufferCount = 1;

    if (_contexts)
        free(_contexts);
    _contexts = malloc(sizeof(OEGameAudioContext) * bufferCount);
    for (int i = 0; i < bufferCount; ++i)
    {
        _contexts[i] = (OEGameAudioContext){&([self ringBufferAtIndex:i]->buffer), [self channelCountForBuffer:i], [self audioBitDepth]/8};
        
        //Create the converter node
        err = AUGraphAddNode(mGraph, (const AudioComponentDescription *)&desc, &mConverterNode);
        if(err)  NSLog(@"couldn't create node for converter");
        
        err = AUGraphNodeInfo(mGraph, mConverterNode, NULL, &mConverterUnit);
        if(err) NSLog(@"couldn't get player unit from converter");
        
        
        AURenderCallbackStruct renderStruct;
        renderStruct.inputProc = RenderCallback;
        renderStruct.inputProcRefCon = (void*)&_contexts[i];
        
        err = AudioUnitSetProperty(mConverterUnit, kAudioUnitProperty_SetRenderCallback,
                                   kAudioUnitScope_Input, 0, &renderStruct, sizeof(AURenderCallbackStruct));
        if(err) {
            NSLog(@"Couldn't set the render callback");
        }
        else {
            NSLog(@"Set the render callback");
        }
        AudioStreamBasicDescription mDataFormat;
        NSUInteger channelCount = _contexts[i].channelCount;
        NSUInteger bytesPerSample = _contexts[i].bytesPerSample;

		/*
		//static inline void    FillOutASBDForLPCM(AudioStreamBasicDescription& outASBD, Float64 inSampleRate, UInt32 inChannelsPerFrame, UInt32 inValidBitsPerChannel, UInt32 inTotalBitsPerChannel, bool inIsFloat, bool inIsBigEndian, bool inIsNonInterleaved = false)    {
		 outASBD.mSampleRate = 44100;
		 outASBD.mFormatID = kAudioFormatLinearPCM;
		 outASBD.mFormatFlags = CalculateLPCMFlags(inValidBitsPerChannel, inTotalBitsPerChannel, inIsFloat, inIsBigEndian, inIsNonInterleaved);
		 outASBD.mBytesPerPacket = (inIsNonInterleaved ? 1 : 2) * (inTotalBitsPerChannel / 8);
		 outASBD.mFramesPerPacket = 1;
		 outASBD.mBytesPerFrame = (inIsNonInterleaved ? 1 : 2) * (inTotalBitsPerChannel / 8);
		 outASBD.mChannelsPerFrame = 2;
		 outASBD.mBitsPerChannel = inValidBitsPerChannel; }

		FillOutASBDForLPCM(mDataFormat, 44100,
						   2, 16, 16, false, false, false);

		  CalculateLPCMFlags(UInt32 inValidBitsPerChannel, UInt32 inTotalBitsPerChannel, bool inIsFloat, bool inIsBigEndian, bool inIsNonInterleaved = false) {
		 return kAudioFormatFlagIsSignedInteger |  0) | kAudioFormatFlagIsPacked | (inIsNonInterleaved ? ((UInt32)kAudioFormatFlagIsNonInterleaved) : 0); }

		 */

//        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
        mDataFormat.mSampleRate       = [self audioSampleRateForBuffer:i];
        mDataFormat.mFormatID         = kAudioFormatLinearPCM;
		mDataFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; ////formatFlag | kAudioFormatFlagsNativeEndian;
        mDataFormat.mBytesPerPacket   =  2*16/8; //bytesPerSample * channelCount;
        mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
		mDataFormat.mBytesPerFrame    = 2*16/8; //bytesPerSample * channelCount;
		mDataFormat.mChannelsPerFrame =  2; //channelCount;
		mDataFormat.mBitsPerChannel   = 16; //8 * bytesPerSample;

        err = AudioUnitSetProperty(mConverterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, sizeof(AudioStreamBasicDescription));
        if(err) {
            NSLog(@"couldn't set player's input stream format");
        } {
            NSLog(@"Set the play'ers input stream format");
        }

        err = AUGraphConnectNodeInput(mGraph, mConverterNode, 0, mMixerNode, i);
        if(err) { NSLog(@"Couldn't connect the converter to the mixer"); }
        else { NSLog(@"Conncted the converter to the mixer"); }
    }
    // connect the player to the output unit (stream format will propagate)
         
    err = AUGraphConnectNodeInput(mGraph, mMixerNode, 0, mOutputNode, 0);
    if(err) {
        NSLog(@"Could not connect the input of the output");
    } {
        NSLog(@"Conncted input of the output");
    }
    
    //AudioUnitSetParameter(mOutputUnit, kAudioUnitParameterUnit_LinearGain, kAudioUnitScope_Global, 0, [[[GameDocumentController sharedDocumentController] preferenceController] volume] ,0);
    AudioUnitSetParameter(mOutputUnit, kAudioUnitParameterUnit_LinearGain, kAudioUnitScope_Global, 0, 1.0 ,0);

    AudioDeviceID outputDeviceID = [_outputDeviceID unsignedIntValue];
//    if(outputDeviceID != 0)
    err = AudioUnitSetProperty(mOutputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, sizeof(outputDeviceID));
    if(err){ NSLog(@"couldn't set device properties"); }

    err = AUGraphInitialize(mGraph);
    if(err){ NSLog(@"couldn't initialize graph"); }
    else { NSLog(@"Initialized the graph"); }

    err = AUGraphStart(mGraph);
    if(err){ NSLog(@"couldn't start graph"); }
    else { NSLog(@"Started the graph"); }
	
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
