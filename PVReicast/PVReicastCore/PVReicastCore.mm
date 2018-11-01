//
//  PVReicastCore.m
//  PVReicast
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVReicastCore.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>


// Reicast imports
#include "types.h"
#include "profiler/profiler.h"
#include "cfg/cfg.h"
#include "rend/rend.h"
#include "rend/TexCache.h"
#include "hw/maple/maple_devs.h"
#include "hw/maple/maple_if.h"
#include "hw/maple/maple_cfg.h"


__weak PVReicastCore *_current = 0;

@interface PVReicastCore() {
	@public
	dispatch_queue_t _callbackQueue;
}
- (void)pollControllers;
@property(nonatomic, strong, nullable) NSString *diskPath;
@end

// Reicast function declerations
extern int screen_width,screen_height;
bool rend_single_frame();
bool gles_init();
extern int reicast_main(int argc, char* argv[]);
void common_linux_setup();
int dc_init(int argc,wchar* argv[]);
void dc_run();
void dc_term();

bool inside_loop     = true;
static bool first_run = true;;

#pragma mark - Reicast C++ interface
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <assert.h>
#include <poll.h>
#include <termios.h>
#include <fcntl.h>
#include <semaphore.h>
#include <stdarg.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/mman.h>
#include <sys/time.h>
#include "hw/sh4/dyna/blockmanager.h"
#include <unistd.h>

void move_pthread_to_realtime_scheduling_class(pthread_t pthread)
{
	mach_timebase_info_data_t timebase_info;
	mach_timebase_info(&timebase_info);

	const uint64_t NANOS_PER_MSEC = 1000000ULL;
	double clock2abs = ((double)timebase_info.denom / (double)timebase_info.numer) * NANOS_PER_MSEC;

	thread_time_constraint_policy_data_t policy;
	policy.period      = 0;
	policy.computation = (uint32_t)(5 * clock2abs); // 5 ms of work
	policy.constraint  = (uint32_t)(10 * clock2abs);
	policy.preemptible = FALSE;

	int kr = thread_policy_set(pthread_mach_thread_np(pthread_self()),
							   THREAD_TIME_CONSTRAINT_POLICY,
							   (thread_policy_t)&policy,
							   THREAD_TIME_CONSTRAINT_POLICY_COUNT);
	if (kr != KERN_SUCCESS) {
		mach_error("thread_policy_set:", kr);
		exit(1);
	}
}

void MakeCurrentThreadRealTime()
{
	move_pthread_to_realtime_scheduling_class(pthread_self());
}

#pragma mark Debugging calls

int msgboxf(const wchar* text,unsigned int type,...)
{
	va_list args;

	wchar temp[2048];
	va_start(args, type);
	vsprintf(temp, text, args);
	va_end(args);

	//printf(NULL,temp,VER_SHORTNAME,type | MB_TASKMODAL);
	puts(temp);
	return 0;
}

int darw_printf(const wchar* text,...) {
	va_list args;

	wchar temp[2048];
	va_start(args, text);
	vsprintf(temp, text, args);
	va_end(args);

	NSLog(@"%s", temp);

	return 0;
}

#pragma mark C Lifecycle calls
void os_DoEvents() {
    GET_CURRENT_OR_RETURN();
    [current videoInterrupt];
////
////	is_dupe = false;
//	[current updateControllers];
//
//	if (settings.UpdateMode || settings.UpdateModeForced)
//	{
//		inside_loop = false;
//		rend_end_render();
//	}
}

u32  os_Push(void*, u32, bool) {
	return 1;
}

void os_SetWindowText(const char* t) {
	puts(t);
}

void os_CreateWindow() {

}

void os_SetupInput() {
    mcfg_CreateDevicesFromConfig();
}

void UpdateInputState(u32 port) {
	GET_CURRENT_OR_RETURN();
	[current pollControllers];
}

void UpdateVibration(u32 port, u32 value) {

}

int get_mic_data(unsigned char* ) {
	return 0;
}

void* libPvr_GetRenderTarget() {
	return 0;
}

void* libPvr_GetRenderSurface() {
	return 0;

}

bool gl_init(void*, void*) {
	return true;
}

void gl_term() {

}

void gl_swap() {
	GET_CURRENT_OR_RETURN();
	[current swapBuffers];
}

#pragma mark Audio Callbacks

#include "oslib/audiobackend_coreaudio.h"
#import "CARingBuffer.h"

volatile Float64 write_ptr = 0;
volatile Float64 read_ptr = 0;


typedef struct MyAUGraphPlayer {
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
} MyAUGraphPlayer;


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
void CreateInputUnit (MyAUGraphPlayer *player);
void CreateMyAUGraph(MyAUGraphPlayer *player);
static void CheckError(OSStatus error, const char *operation);

static MyAUGraphPlayer player;
#import <AVFoundation/AVFoundation.h>
static void coreaudio_init()
{
//	GET_CURRENT_OR_RETURN();
//	[current ringBufferAtIndex:0];
//
//	if (settings.aica.GlobalFocus) {
//		// TODO: Allow background audio?
//	}
	NSError *error;
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
	if(error) {
		NSLog(@"Couldn't set av session %@", error.localizedDescription);
	} else {
		NSLog(@"Successfully set audio session to ambient");
	}
	player = {0};

	// build a graph with output unit and set stream format
	CreateMyAUGraph(&player);

	/* allocate some buffers to hold samples between input and output callbacks
	 (this part largely copied from CAPlayThrough) */
	//Get the size of the IO buffer(s)
	Float64 sampleRate;
	UInt32 propSize = sizeof(Float64);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
							&propSize,
							&sampleRate);

	Float32 bufferDuration;
	propSize = sizeof(Float32);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
							&propSize,
							&bufferDuration);

	UInt32 bufferLengthInFrames = sampleRate * bufferDuration;
	UInt32 bufferSizeBytes = bufferLengthInFrames * sizeof(Float32);

	if (player.streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
		printf ("format is non-interleaved\n");
		// allocate an AudioBufferList plus enough space for array of AudioBuffers
		UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * player.streamFormat.mChannelsPerFrame);

		//malloc buffer lists
		player.inputBuffer = (AudioBufferList *)malloc(propsize);
		player.inputBuffer->mNumberBuffers = player.streamFormat.mChannelsPerFrame;

		//pre-malloc buffers for AudioBufferLists
		for(UInt32 i =0; i< player.inputBuffer->mNumberBuffers ; i++) {
			player.inputBuffer->mBuffers[i].mNumberChannels = 1;
			player.inputBuffer->mBuffers[i].mDataByteSize = bufferSizeBytes;
			player.inputBuffer->mBuffers[i].mData = malloc(bufferSizeBytes);
		}
	} else {
		printf ("format is interleaved\n");
		// allocate an AudioBufferList plus enough space for array of AudioBuffers
		UInt32 propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * 1);

		//malloc buffer lists
		player.inputBuffer = (AudioBufferList *)malloc(propsize);
		player.inputBuffer->mNumberBuffers = 1;

		//pre-malloc buffers for AudioBufferLists
		player.inputBuffer->mBuffers[0].mNumberChannels = player.streamFormat.mChannelsPerFrame;
		player.inputBuffer->mBuffers[0].mDataByteSize = bufferSizeBytes;
		player.inputBuffer->mBuffers[0].mData = malloc(bufferSizeBytes);
	}

	//Alloc ring buffer that will hold data between the two audio devices
	player.ringBuffer = new CARingBuffer();
	player.ringBuffer->Allocate(player.streamFormat.mChannelsPerFrame,
								 player.streamFormat.mBytesPerFrame,
								 bufferLengthInFrames * 4000);


	player.firstInputSampleTime = -1;
	player.firstOutputSampleTime = -1;
	player.inToOutSampleTimeOffset = -1;

	CheckError(AUGraphStart(player.graph), "AUGraphStart failed");


	settings.aica.BufferSize = bufferLengthInFrames;

//	settings.aica.LimitFPS = 1;
}


static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;

	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);

	fprintf(stderr, "Error: %s (%s)\n", operation, str);

	exit(1);
}

#pragma mark - render proc -

OSStatus GraphRenderProc(void *inRefCon,
						 AudioUnitRenderActionFlags *ioActionFlags,
						 const AudioTimeStamp *inTimeStamp,
						 UInt32 inBusNumber,
						 UInt32 inNumberFrames,
						 AudioBufferList * ioData)
{

	read_ptr += inNumberFrames;
//		printf ("GraphRenderProc! need %d frames for time %f \n", inNumberFrames, inTimeStamp->mSampleTime);

//	MyAUGraphPlayer *player = (MyAUGraphPlayer*) inRefCon;

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

//	Float64 time = inTimeStamp->mSampleTime + player.inToOutSampleTimeOffset;
	Float64 time = read_ptr + player.inToOutSampleTimeOffset;

	// new CARingBuffer doesn't take bool 4th arg
	outputProcErr = player.ringBuffer->Fetch(ioData,
											  inNumberFrames,
											  time);
//	float freq = 440.f;
//	int seconds = 4;
//	unsigned sample_rate = 44100;
//	size_t buf_size = seconds * sample_rate;
//
//	short *samples;
//	samples = new short[buf_size];
//	for(int i=0; i<buf_size; ++i) {
//		samples[i] = 32760 * sin( (2.f*float(M_PI)*freq)/sample_rate * i );
//	}
//
//	memcpy(ioData->mBuffers[0].mData, samples, inNumberFrames);

//	memcpy(ioData->mBuffers[0].mData, player.inputBuffer->mBuffers[0].mData, inNumberFrames);


	printf ("fetched %d frames at time %f error: %i\n", inNumberFrames, time, outputProcErr);
	return outputProcErr;

}

void CreateMyAUGraph(MyAUGraphPlayer *player)
{
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

//	CheckError(AudioUnitSetProperty(player->outputUnit,
//									kAudioUnitProperty_SetRenderCallback,
//									kAudioUnitScope_Global,
//									0,
//									&renderStruct,
//									sizeof(renderStruct)),
//			   "Couldn't set render callback on output unit");





	AudioStreamBasicDescription mDataFormat;
	NSUInteger channelCount =  [current channelCount];
	NSUInteger bytesPerSample = [current audioBitDepth] / 8;

//	int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
//	mDataFormat.mSampleRate       = [current audioSampleRateForBuffer:0];
//	mDataFormat.mFormatID         = kAudioFormatLinearPCM;
//	mDataFormat.mFormatFlags      = formatFlag | kAudioFormatFlagsNativeEndian;
//	mDataFormat.mBytesPerPacket   = bytesPerSample * channelCount;
//	mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
//	mDataFormat.mBytesPerFrame    = bytesPerSample * channelCount;
//	mDataFormat.mChannelsPerFrame = channelCount;
//	mDataFormat.mBitsPerChannel   = 8 * bytesPerSample;

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

//	AudioDeviceID outputDeviceID = 0;
//	//    if(outputDeviceID != 0)
//	CheckError(AudioUnitSetProperty(player->outputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &outputDeviceID, sizeof(AudioDeviceID)),
//		"couldn't set device properties");

	CheckError(AUGraphInitialize(player->graph),
			   "couldn't initialize graph");

	DLOG(@"Initialized the graph");

//	CheckError(AUGraphStart(player->graph),
//		"couldn't start graph");
//
//	DLOG(@"Started the graph");

//	 CFShow(player->graph);
	float volume = 1.0;
	AudioUnitSetParameter( mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, volume, 0 ) ;
//
//#define PART_II 0
//#ifdef PART_II
//	AudioStreamBasicDescription mDataFormat;
//	NSUInteger channelCount =  [current channelCount];
//	NSUInteger bytesPerSample = [current audioBitDepth] / 8;
//
//	//        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
//	mDataFormat.mSampleRate       = 44100;
//	mDataFormat.mFormatID         = kAudioFormatLinearPCM;
//	mDataFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; ////formatFlag | kAudioFormatFlagsNativeEndian;
//	mDataFormat.mBytesPerPacket   =  2*16/8; //bytesPerSample * channelCount;
//	mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
//	mDataFormat.mBytesPerFrame    = 2*16/8; //bytesPerSample * channelCount;
//	mDataFormat.mChannelsPerFrame =  2; //channelCount;
//	mDataFormat.mBitsPerChannel   = 16; //8 * bytesPerSample;
//
//	player->streamFormat = mDataFormat;
//
//	// add a mixer to the graph,
//	AudioComponentDescription mixercd = {0};
//	mixercd.componentType = kAudioUnitType_Mixer;
//	mixercd.componentSubType = kAudioUnitSubType_MultiChannelMixer; // doesn't work: kAudioUnitSubType_MatrixMixer
//	mixercd.componentManufacturer = kAudioUnitManufacturer_Apple;
//	AUNode mixerNode;
//	CheckError(AUGraphAddNode(player->graph, &mixercd, &mixerNode),
//			   "AUGraphAddNode[kAudioUnitSubType_StereoMixer] failed");
//
//	// adds a node with above description to the graph
////	AudioComponentDescription speechcd = {0};
////	speechcd.componentType = kAudioUnitType_Generator;
////	speechcd.componentSubType = kAudioUnitSubType_SpeechSynthesis;
////	speechcd.componentManufacturer = kAudioUnitManufacturer_Apple;
////	AUNode speechNode;
////	CheckError(AUGraphAddNode(player->graph, &speechcd, &speechNode),
////			   "AUGraphAddNode[kAudioUnitSubType_AudioFilePlayer] failed");
//
//	// opening the graph opens all contained audio units but does not allocate any resources yet
//	CheckError(AUGraphOpen(player->graph),
//			   "AUGraphOpen failed");
//
//	// get the reference to the AudioUnit objects for the various nodes
////	CheckError(AUGraphNodeInfo(player->graph, outputNode, NULL, &player->outputUnit),
////			   "AUGraphNodeInfo failed");
////	CheckError(AUGraphNodeInfo(player->graph, speechNode, NULL, &player->speechUnit),
////			   "AUGraphNodeInfo failed");
//	AudioUnit mixerUnit;
//	CheckError(AUGraphNodeInfo(player->graph, mixerNode, NULL, &mixerUnit),
//			   "AUGraphNodeInfo failed");
//
//	// set ASBDs here
//	UInt32 propertySize = sizeof (AudioStreamBasicDescription);
//	CheckError(AudioUnitSetProperty(player->outputUnit,
//									kAudioUnitProperty_StreamFormat,
//									kAudioUnitScope_Input,
//									0,
//									&player->streamFormat,
//									propertySize),
//			   "Couldn't set stream format on output unit");
//
//	// problem: badComponentInstance (-2147450879)
//	CheckError(AudioUnitSetProperty(mixerUnit,
//									kAudioUnitProperty_StreamFormat,
//									kAudioUnitScope_Input,
//									0,
//									&player->streamFormat,
//									propertySize),
//			   "Couldn't set stream format on mixer unit bus 0");
//	CheckError(AudioUnitSetProperty(mixerUnit,
//									kAudioUnitProperty_StreamFormat,
//									kAudioUnitScope_Input,
//									1,
//									&player->streamFormat,
//									propertySize),
//			   "Couldn't set stream format on mixer unit bus 1");
//
//
//	// connections
//	// mixer output scope / bus 0 to outputUnit input scope / bus 0
//	// mixer input scope / bus 0 to render callback (from ringbuffer, which in turn is from inputUnit)
//	// mixer input scope / bus 1 to speech unit output scope / bus 0
//
//	CheckError(AUGraphConnectNodeInput(player->graph, mixerNode, 0, outputNode, 0),
//			   "Couldn't connect mixer output(0) to outputNode (0)");
////	CheckError(AUGraphConnectNodeInput(player->graph, speechNode, 0, mixerNode, 1),
////			   "Couldn't connect speech synth unit output (0) to mixer input (1)");
//	AURenderCallbackStruct callbackStruct;
//	callbackStruct.inputProc = GraphRenderProc;
//	callbackStruct.inputProcRefCon = player;
//	CheckError(AudioUnitSetProperty(mixerUnit,
//									kAudioUnitProperty_SetRenderCallback,
//									kAudioUnitScope_Global,
//									0,
//									&callbackStruct,
//									sizeof(callbackStruct)),
//			   "Couldn't set render callback on mixer unit");
//
//
//#else
//
//	// opening the graph opens all contained audio units but does not allocate any resources yet
//	CheckError(AUGraphOpen(player->graph),
//			   "AUGraphOpen failed");
//
//	// get the reference to the AudioUnit object for the output graph node
//	CheckError(AUGraphNodeInfo(player->graph, outputNode, NULL, &player->outputUnit),
//			   "AUGraphNodeInfo failed");
//
//	AudioStreamBasicDescription mDataFormat;
//	NSUInteger channelCount =  [current channelCount];
//	NSUInteger bytesPerSample = [current audioBitDepth] / 8;
//
//	//        int formatFlag = (bytesPerSample == 4) ? kLinearPCMFormatFlagIsFloat : kLinearPCMFormatFlagIsSignedInteger;
//	mDataFormat.mSampleRate       = 44100;
//	mDataFormat.mFormatID         = kAudioFormatLinearPCM;
//	mDataFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; ////formatFlag | kAudioFormatFlagsNativeEndian;
//	mDataFormat.mBytesPerPacket   =  2*16/8; //bytesPerSample * channelCount;
//	mDataFormat.mFramesPerPacket  = 1; // this means each packet in the AQ has two samples, one for each channel -> 4 bytes/frame/packet
//	mDataFormat.mBytesPerFrame    = 2*16/8; //bytesPerSample * channelCount;
//	mDataFormat.mChannelsPerFrame =  2; //channelCount;
//	mDataFormat.mBitsPerChannel   = 16; //8 * bytesPerSample;
//
//	player->streamFormat = mDataFormat;
////	OSStatus inputProcErr = noErr;
////	err = AudioUnitSetProperty(mConverterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mDataFormat, sizeof(AudioStreamBasicDescription));
//
//	// set the stream format on the output unit's input scope
//	UInt32 propertySize = sizeof (AudioStreamBasicDescription);
//	CheckError(AudioUnitSetProperty(player->outputUnit,
//									kAudioUnitProperty_StreamFormat,
//									kAudioUnitScope_Input,
//									0,
//									&player->streamFormat,
//									propertySize),
//			   "Couldn't set stream format on output unit");
//
//	AURenderCallbackStruct callbackStruct;
//	callbackStruct.inputProc = GraphRenderProc;
//	callbackStruct.inputProcRefCon = player;
//
//	CheckError(AudioUnitSetProperty(player->outputUnit,
//									kAudioUnitProperty_SetRenderCallback,
//									kAudioUnitScope_Global,
//									0,
//									&callbackStruct,
//									sizeof(callbackStruct)),
//			   "Couldn't set render callback on output unit");
//
//#endif
//
//
//	// now initialize the graph (causes resources to be allocated)
//	CheckError(AUGraphInitialize(player->graph),
//			   "AUGraphInitialize failed");

	player->firstOutputSampleTime = -1;

	printf ("Bottom of CreateSimpleAUGraph()\n");
}

AudioBufferList *
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

uint clearedCounter = 0;
static u32 coreaudio_push(void* frame, u32 samples, bool wait)
{
	GET_CURRENT_OR_RETURN(1);

	OERingBuffer *rb = [current ringBufferAtIndex:0];

	if (rb == nil) {
		ELOG("Ring buffer was nil!");
		return 1;
	}

//	if (current.isEmulationPaused) {
//		TPCircularBufferClear(&rb->buffer);
//		return 1;
//	}

#define CALLBACK_VERSION 7
#define USE_DIRECTSOUND_THING 1

#if USE_DIRECTSOUND_THING
	u16* f=(u16*)frame;

	bool w=false;

	for (u32 i = 0; i < samples*2; i++)
	{
		if (f[i])
		{
			w = true;
			break;
		}
	}

	wait &= w;

	int ffs=1;
#endif

	// Fill the buffer and wait for it to empty
#if CALLBACK_VERSION == 0
	// Results: Too slow
	while (rb.availableBytes == 0 && wait) { }
	[rb write:(const unsigned char *)frame maxLength:samples * 4];
#elif CALLBACK_VERSION == 1
	// Results: Too slow

	// Same as 1, but do the buffer copy first so we don't stall on the memcpy
	[rb write:(const unsigned char *)frame maxLength:samples * 4];
	while (rb.availableBytes == 0 && wait) { }
#elif CALLBACK_VERSION == 2
	// Faster, stutters
//	NSLog(@"%lu %lu diff: %lu", samples_ptr, rb.bytesWritten, samples_ptr-rb.bytesWritten);
	// Use a sample counter instead of filling the buffer
	while (samples_ptr > rb.bytesWritten && wait) { }
	if(samples_ptr <= rb.bytesWritten) {
		[rb write:(const unsigned char *)frame maxLength:samples * 4];
		samples_ptr += samples * 4;
	}
#elif CALLBACK_VERSION == 3
	// Faster, stutters

	NSLog(@"%lu %lu diff: %lu", (unsigned long)samples_ptr, (unsigned long)rb.bytesWritten, (unsigned long)samples_ptr-rb.bytesWritten);

	// Use a sample counter instead of filling the buffer
	while (samples_ptr != 0 && samples_ptr != rb.bytesRead && rb.bytesRead != 0 && wait) { }
	[rb write:(const unsigned char *)frame maxLength:samples * 4];
	samples_ptr += samples * 4;
#elif CALLBACK_VERSION == 4
	// Use a sample counter instead of filling the buffer
	while (samples_ptr >= rb.bytesWritten && wait) { }
	if (samples_ptr >= rb.bytesWritten)
		[rb write:(const unsigned char *)frame maxLength:samples * 4];
		samples_ptr += samples * 4;
	}
#elif CALLBACK_VERSION == 5
	// Use a sample counter instead of filling the buffer
	if (samples_ptr <= rb.bytesWritten)
		[[current ringBufferAtIndex:0] write:(const unsigned char *)frame maxLength:samples * 4];
		samples_ptr += samples * 4;
	}

	while (samples_ptr >= rb.bytesWritten > 0 && wait) { }
#elif CALLBACK_VERSION == 6

	TPCircularBuffer buffer = rb->buffer;
	NSUInteger maxFillSize = clearedCounter > 4 ? samples * 8 : -1;
//	NSLog(@"used bytes: %lu", (unsigned long)buffer.fillCount);
#define notfull [rb write:(const unsigned char *)frame maxLength:samples * 4]

	while ([rb availableBytes] > maxFillSize && wait) {	}

	[rb write:(const unsigned char *)frame maxLength:samples * 4];

//	dispatch_async(current->_callbackQueue, ^{
//		[rb write:(const unsigned char *)frame maxLength:samples * 4];
//	});
	if (buffer.fillCount == 0) {
		clearedCounter++;
	}

#elif CALLBACK_VERSION == 7
	// render into our buffer
	OSStatus inputProcErr = noErr;
	UInt32 inNumberFrames = samples;
	UInt32 inNumberBytes = samples * 4;

AudioTimeStamp timeStamp = {0};
FillOutAudioTimeStampWithSampleTime(timeStamp, settings.dreamcast.RTC);

//write_ptr += inNumberFrames;

// have we ever logged input timing? (for offset calculation)
if (player.firstInputSampleTime < 0.0) {
	player.firstInputSampleTime = write_ptr;
	if ((player.firstOutputSampleTime > -1.0) &&
			(player.inToOutSampleTimeOffset < 0.0)) {
			player.inToOutSampleTimeOffset =
			player.firstInputSampleTime - player.firstOutputSampleTime;
	}
}

// In order to render continuously, the effect audio unit needs a new time stamp for each buffer
// Use the number of frames for each unit of time continuously incrementing
//player.firstInputSampleTime += (double)samples * 4;
//AudioBufferList ioData = {0};
//ioData.mNumberBuffers = 1;
//ioData.mBuffers[0] =
//ioData.mBuffers[0].mNumberChannels = 2;
//ioData.mBuffers[0].mDataByteSize = (UInt32)(inNumberBytes);
//ioData.mBuffers[0].mData = frame;

//AudioBufferList *bufferList = NULL;
//UInt32 numBuffers = 1;
//UInt32 channelsPerBuffer = 2;
//bufferList = static_cast<AudioBufferList *>(calloc(1, offsetof(AudioBufferList, mBuffers) + (sizeof(AudioBuffer) * numBuffers)));
//bufferList->mNumberBuffers = numBuffers;
//
//for(UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; ++bufferIndex) {
//	bufferList->mBuffers[bufferIndex].mData = frame; //static_cast<void *>(calloc(capacityFrames, bytesPerFrame));
//	bufferList->mBuffers[bufferIndex].mDataByteSize = inNumberBytes;
//	bufferList->mBuffers[bufferIndex].mNumberChannels = 2;
//}



printf ("set %d frames at time %f\n", inNumberFrames, timeStamp.mSampleTime);

/*
 #define kNumChannels 2
 AudioBufferList *bufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList) * kNumChannels);
 bufferList->mNumberBuffers = kNumChannels; // 2 for stereo, 1 for mono
 for(int i = 0; i < 2; i++) {
 int numSamples = 123456; // Number of sample frames in the buffer
 bufferList->mBuffers[i].mNumberChannels = 1;
 bufferList->mBuffers[i].mDataByteSize = numSamples * sizeof(Float32);
 bufferList->mBuffers[i].mData = (Float32*)malloc(sizeof(Float32) * numSamples);
 }

 // Do stuff...

 for(int i = 0; i < 2; i++) {
 free(bufferList->mBuffers[i].mData);
 }
 free(bufferList);
 */
//AudioUnitGetProperty(player.graph,
//					 kAudioUnitProperty_CurrentPlayTime,
//					 kAudioUnitScope_Global,
//					 0,
//					 &ts,
//					 &size);
//
//AudioUnitGetProperty(player.graph,
//					 kAudioUnitProperty_CurrentPlayTime,
//					 kAudioUnitScope_Global,
//					 0,
//					 (void*)&ts,
//					 &size);

//	float freq = 440.f;
//	int seconds = 4;
//	unsigned sample_rate = 44100;
//	size_t buf_size = seconds * sample_rate;
//
//	short *staticsamples;
//	staticsamples = new short[buf_size];
//	for(int i=0; i<buf_size; ++i) {
//		staticsamples[i] = 32760 * sin( (2.f*float(M_PI)*freq)/sample_rate * i );
//	}

//	memcpy(player.inputBuffer->mBuffers[0].mData, frame, inNumberBytes);


//	player.inputBuffer->mBuffers[0].mDataByteSize = inNumberBytes;

//	memcpy(player.inputBuffer->mBuffers[0].mData, frame, inNumberBytes);
	player.inputBuffer->mBuffers[0].mData = frame;
	player.inputBuffer->mBuffers[0].mDataByteSize = inNumberBytes;
	player.inputBuffer->mBuffers[0].mNumberChannels = 2;

	// copy from our buffer to ring buffer
	if (! inputProcErr) {
		inputProcErr = player.ringBuffer->Store(player.inputBuffer,
												 inNumberFrames,
												 timeStamp.mSampleTime);
		printf("Stored: %i", inputProcErr);
	}
#endif

	//	});
	/* Yeah, right */
	//    while (samples_ptr != 0 && wait) ;
	//
	//    if (samples_ptr == 0) {
	//        memcpy(&samples_temp[samples_ptr], frame, samples * 4);
	//        samples_ptr += samples * 4;
	//    }
	//
	return 1;
}

static void coreaudio_term()
{
	GET_CURRENT_OR_RETURN();
}

audiobackend_t audiobackend_coreaudio = {
	"coreaudio", // Slug
	"Core Audio", // Name
	&coreaudio_init,
	&coreaudio_push,
	&coreaudio_term
};

#pragma mark - PVReicastCore Begin


// Reicast controller data
u16 kcode[4];
u8 rt[4];
u8 lt[4];
u32 vks[4];
s8 joyx[4], joyy[4];

@implementation PVReicastCore
{
	dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
	dispatch_semaphore_t coreWaitToEndFrameSemaphore;
    dispatch_semaphore_t coreWaitForExitSemaphore;

	NSMutableDictionary *_callbackHandlers;
}

- (instancetype)init
{
	if (self = [super init]) {
		mupenWaitToBeginFrameSemaphore = dispatch_semaphore_create(0);
		coreWaitToEndFrameSemaphore    = dispatch_semaphore_create(0);
        coreWaitForExitSemaphore       = dispatch_semaphore_create(0);

		_videoWidth  = screen_width = 640;
		_videoHeight = screen_height = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO

		sampleRate = 44100;

		isNTSC = YES;

		memset(&kcode, 0xFFFF, sizeof(kcode));
		bzero(&rt, sizeof(rt));
		bzero(&lt, sizeof(lt));

		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);

		_callbackQueue = dispatch_queue_create("org.openemu.Reicast.CallbackHandlerQueue", queueAttributes);
		_callbackHandlers = [[NSMutableDictionary alloc] init];
	}
	_current = self;
	return self;
}

- (void)dealloc
{
#if !__has_feature(objc_arc)
	dispatch_release(mupenWaitToBeginFrameSemaphore);
	dispatch_release(coreWaitToEndFrameSemaphore);
    dispatch_release(coreWaitForExitSemaphore);
#endif

	_current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
	const char *dataPath;

	[self copyShadersIfMissing];

	// TODO: Proper path
	NSString *configPath = self.saveStatesPath;
	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];

	[[NSFileManager defaultManager] createDirectoryAtPath:configPath withIntermediateDirectories:YES attributes:nil error:nil];

	NSString *batterySavesDirectory = self.batterySavesPath;
	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];


//	if (!success) {
//		NSDictionary *userInfo = @{
//								   NSLocalizedDescriptionKey: @"Failed to load game.",
//								   NSLocalizedFailureReasonErrorKey: @"Reicast failed to load GLES graphics.",
//								   NSLocalizedRecoverySuggestionErrorKey: @"Provenance may not be compiled correctly."
//								   };
//
//		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
//												code:PVEmulatorCoreErrorCodeCouldNotLoadRom
//											userInfo:userInfo];
//
//		*error = newError;
//		return NO;
//	}

	self.diskPath = path;

	// 	while(!rend_single_frame()) ; // Where should this go?

//	// Reicast part
//	common_linux_setup();
//
//	settings.profile.run_counts=0;
//
//	dc_init(argc,argv);
//
//	dc_run();

	return YES;
}


- (void)copyShadersIfMissing {

	NSArray *shaders = @[@"Shader.vsh",@"Shader.fsh"];
	NSString *destinationFolder = self.BIOSPath;
	NSFileManager *fm = [NSFileManager defaultManager];

	for (NSString* shader in shaders) {
		NSString *destinationPath = [destinationFolder stringByAppendingPathComponent:shader];
		ILOG(@"Checking for shader %@", destinationPath);
		if( ![fm fileExistsAtPath:destinationPath]  ) {
			NSString *source = [[NSBundle bundleForClass:[self class]] pathForResource:[shader stringByDeletingPathExtension] ofType:[shader pathExtension]];
			[fm copyItemAtPath:source
						toPath:destinationPath
						 error:nil];
			ILOG(@"Copied %@ from %@ to %@", shader, source, destinationPath);
		}
	}
}
volatile bool has_init = false;

#pragma mark - Running
- (void)startEmulation
{
	if(!isRunning)
	{

		[super startEmulation];
        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
	}

}

- (void)runReicastEmuThread
{
	@autoreleasepool
	{
		[self reicastMain];

		// Core returns

		// Unlock rendering thread
		dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

		[super stopEmulation];
	}
}

- (void)runReicastRenderThread
{
    @autoreleasepool
    {
        [self.renderDelegate startRenderingOnAlternateThread];
        BOOL success = gles_init();
        assert(success);
        [NSThread detachNewThreadSelector:@selector(runReicastEmuThread) toTarget:self withObject:nil];
        
        while (!has_init) {}
        while ( !shouldStop )
        {
            [self.frontBufferCondition lock];
            while (self.isFrontBufferReady) [self.frontBufferCondition wait];
            [self.frontBufferCondition unlock];
            
            while ( !rend_single_frame() ) {}
            [self swapBuffers];
        }
    }
}

- (void)reicastMain {
	//    #if !TARGET_OS_SIMULATOR
	install_prof_handler(1);
	//   #endif

	char *Args[3];
	const char *P;

	P = (const char *)[self.diskPath UTF8String];
	Args[0] = "dc";
	Args[1] = "-config";
	Args[2] = P&&P[0]? (char *)malloc(strlen(P)+32):0;

	if(Args[2])
	{
		strcpy(Args[2],"config:image=");
		strcat(Args[2],P);
	}

	MakeCurrentThreadRealTime();

	int argc = Args[2]? 3:1;

	set_user_config_dir(self.BIOSPath.UTF8String);
	set_user_data_dir(self.batterySavesPath.UTF8String);

	printf("Config dir is: %s\n", get_writable_config_path("/").c_str());
	printf("Data dir is:   %s\n", get_writable_data_path("/").c_str());

	common_linux_setup();

	settings.profile.run_counts=0;

	reicast_main(argc, Args);
    
    dispatch_semaphore_signal(coreWaitForExitSemaphore);
}

int reicast_main(int argc, wchar* argv[]) {
	int status = dc_init(argc, argv);
	NSLog(@"Reicast init status: %i", status);
	has_init = true;

	dc_run();
	return 0;
}

- (void)videoInterrupt
{
	//dispatch_semaphore_signal(coreWaitToEndFrameSemaphore);

	//dispatch_semaphore_wait(mupenWaitToBeginFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)swapBuffers
{
	[self.renderDelegate didRenderFrameOnAlternateThread];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
	//dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);

	//dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, DISPATCH_TIME_FOREVER);
}

- (void)executeFrame
{
	[self executeFrameSkippingFrame:NO];
}

- (void)setPauseEmulation:(BOOL)flag
{
	[super setPauseEmulation:flag];
	if (flag)
	{
		dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
		[self.frontBufferCondition lock];
		[self.frontBufferCondition signal];
		[self.frontBufferCondition unlock];
	}
}

- (void)stopEmulation
{
	// TODO: Call reicast stop command here
	dc_term();
	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];

	[super stopEmulation];
}

- (void)resetEmulation
{
	// TODO: Call reicast reset command here
	plugins_Reset(true);
	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
	[self.frontBufferCondition lock];
	[self.frontBufferCondition signal];
	[self.frontBufferCondition unlock];
}

#pragma mark - Video
- (CGSize)bufferSize
{
	return CGSizeMake(1024, 512);
}

- (CGRect)screenRect
{
	return CGRectMake(0, 0, _videoWidth, _videoHeight);
}

- (CGSize)aspectSize
{
	return CGSizeMake(_videoWidth, _videoHeight);
}

- (BOOL)rendersToOpenGL
{
	return YES;
}

- (const void *)videoBuffer
{
	return NULL;
}

- (GLenum)pixelFormat
{
	return GL_RGBA;
}

- (GLenum)pixelType
{
	return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
	return GL_RGBA;
}

#pragma mark - Audio

- (NSTimeInterval)frameInterval
{
	return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount
{
	return 2;
}

- (double)audioSampleRate
{
	return sampleRate;
}

#pragma mark - Save States
- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	return NO;
}
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
}


- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	return NO;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{

}

#pragma mark - Control

#define DC_BTN_C		(1)
#define DC_BTN_B		(1<<1)
#define DC_BTN_A		(1<<2)
#define DC_BTN_START	(1<<3)
#define DC_DPAD_UP		(1<<4)
#define DC_DPAD_DOWN	(1<<5)
#define DC_DPAD_LEFT	(1<<6)
#define DC_DPAD_RIGHT	(1<<7)
#define DC_BTN_Z		(1<<8)
#define DC_BTN_Y		(1<<9)
#define DC_BTN_X		(1<<10)
#define DC_BTN_D		(1<<11)
#define DC_DPAD2_UP		(1<<12)
#define DC_DPAD2_DOWN	(1<<13)
#define DC_DPAD2_LEFT	(1<<14)
#define DC_DPAD2_RIGHT	(1<<15)

#define DC_AXIS_LT		(0X10000)
#define DC_AXIS_RT		(0X10001)
#define DC_AXIS_X		(0X20000)
#define DC_AXIS_Y		(0X20001)

- (void)pollControllers
{
	for (NSInteger playerIndex = 0; playerIndex < 4; playerIndex++)
	{
		GCController *controller = nil;

		if (self.controller1 && playerIndex == 0)
		{
			controller = self.controller1;
		}
		else if (self.controller2 && playerIndex == 1)
		{
			controller = self.controller2;
		}
		else if (self.controller3 && playerIndex == 3)
		{
			controller = self.controller3;
		}
		else if (self.controller4 && playerIndex == 4)
		{
			controller = self.controller4;
		}

		if ([controller extendedGamepad])
		{
			GCExtendedGamepad *gamepad     = [controller extendedGamepad];
			GCControllerDirectionPad *dpad = [gamepad dpad];

			dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
			dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
			dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
			dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

			gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
			gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
			gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
			gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

			gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
			gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);

			gamepad.leftTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Z) : kcode[playerIndex] |= (DC_BTN_Z);
			gamepad.rightTrigger.isPressed ? kcode[playerIndex] &= ~(DC_BTN_START) : kcode[playerIndex] |= (DC_BTN_START);


			float xvalue = gamepad.leftThumbstick.xAxis.value;
			s8 x=(s8)(xvalue*127);
			joyx[0] = x;

			float yvalue = gamepad.leftThumbstick.yAxis.value;
			s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
			joyy[0] = y;

		} else if ([controller gamepad]) {
			GCGamepad *gamepad = [controller gamepad];
			GCControllerDirectionPad *dpad = [gamepad dpad];

			dpad.up.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_UP) : kcode[playerIndex] |= (DC_DPAD_UP);
			dpad.down.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_DOWN) : kcode[playerIndex] |= (DC_DPAD_DOWN);
			dpad.left.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_LEFT) : kcode[playerIndex] |= (DC_DPAD_LEFT);
			dpad.right.isPressed ? kcode[playerIndex] &= ~(DC_DPAD_RIGHT) : kcode[playerIndex] |= (DC_DPAD_RIGHT);

			gamepad.buttonA.isPressed ? kcode[playerIndex] &= ~(DC_BTN_A) : kcode[playerIndex] |= (DC_BTN_A);
			gamepad.buttonB.isPressed ? kcode[playerIndex] &= ~(DC_BTN_B) : kcode[playerIndex] |= (DC_BTN_B);
			gamepad.buttonX.isPressed ? kcode[playerIndex] &= ~(DC_BTN_X) : kcode[playerIndex] |= (DC_BTN_X);
			gamepad.buttonY.isPressed ? kcode[playerIndex] &= ~(DC_BTN_Y) : kcode[playerIndex] |= (DC_BTN_Y);

			gamepad.leftShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_LT) : kcode[playerIndex] |= (DC_AXIS_LT);
			gamepad.rightShoulder.isPressed ? kcode[playerIndex] &= ~(DC_AXIS_RT) : kcode[playerIndex] |= (DC_AXIS_RT);
		}
#if TARGET_OS_TV
		else if ([controller microGamepad]) {
			GCMicroGamepad *gamepad = [controller microGamepad];
			GCControllerDirectionPad *dpad = [gamepad dpad];
		}
#endif
	}
}

const int DreamcastMap[]  = { DC_DPAD_UP, DC_DPAD_DOWN, DC_DPAD_LEFT, DC_DPAD_RIGHT, DC_BTN_A, DC_BTN_B, DC_BTN_X, DC_BTN_Y, DC_AXIS_LT, DC_AXIS_RT, DC_BTN_START};

-(void)didPushDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player {
	if (button == PVDreamcastButtonL) {
		lt[player] |= 0xff * true;
	} else if (button == PVDreamcastButtonR) {
		rt[player] |= 0xff * true;
	} else {
		int mapped = DreamcastMap[button];
		kcode[player] &= ~(mapped);
	}
}

-(void)didReleaseDreamcastButton:(enum PVDreamcastButton)button forPlayer:(NSInteger)player {
	if (button == PVDreamcastButtonL) {
		lt[player] |= 0xff * false;
	} else if (button == PVDreamcastButtonR) {
		rt[player] |= 0xff * false;
	} else {
		int mapped = DreamcastMap[button];
		kcode[player] |= (mapped);
	}
}

- (void)didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
	/*
	float xvalue = gamepad.leftThumbstick.xAxis.value;
	s8 x=(s8)(xvalue*127);
	joyx[0] = x;

	float yvalue = gamepad.leftThumbstick.yAxis.value;
	s8 y=(s8)(yvalue*127 * - 1); //-127 ... + 127 range
	joyy[0] = y;
	*/
}

-(void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
	[self didMoveDreamcastJoystickDirection:(enum PVDreamcastButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
	[self didPushDreamcastButton:(PVDreamcastButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
	[self didReleaseDreamcastButton:(PVDreamcastButton)button forPlayer:player];
}

@end

