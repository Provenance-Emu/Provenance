//
//  MIKOfflineMIDISynthesizer.m
//  MIDI To Audio
//
//  Created by Andrew Madsen on 2/17/15.
//  Copyright (c) 2015-2016 Mixed In Key. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#import "MIKOfflineMIDISynthesizer.h"
#import <MIKMIDI/MIKMIDISynthesizer_SubclassMethods.h>

//	the # of frames to process on each render operation
#define RENDER_FRAMES	(512)

//	[thread] save audio stream through a subclass of MIKRecorder
OSStatus recordCallback(void							*extFileRef,
						AudioUnitRenderActionFlags	*ioActionFlags,
						const AudioTimeStamp			*inTimeStamp,
						UInt32						inBusNumber,
						UInt32						inNumberFrames,
						AudioBufferList				*ioData)
{
	ExtAudioFileRef cafFile = (ExtAudioFileRef)extFileRef;
	if (!cafFile) {
		NSLog(@"No audio file to record to! %s", __PRETTY_FUNCTION__);
		return paramErr;
	}
	if ( (*ioActionFlags & kAudioUnitRenderAction_OutputIsSilence) != 0 ) {
		return noErr;	// silence, end of input
	}
	if ( (*ioActionFlags & kAudioUnitRenderAction_PostRender) == 0 ) {
		return noErr;	// record only after rendering
	}
	if ( ioData->mBuffers[0].mData == NULL ) {
		NSLog(@"Invalid recording data");
		return paramErr;
	}
	
	return ExtAudioFileWrite(cafFile, inNumberFrames, ioData);
}

//	the stream format at the end of the graph
AudioStreamBasicDescription LPCMASBD(void)
{
	UInt32 nChannels = 2;  /* always process stereo */
	AudioStreamBasicDescription asbd = { 0 };
	asbd.mSampleRate       = 44100.0;
	asbd.mFormatID         = kAudioFormatLinearPCM;
	asbd.mFormatFlags      = kAudioFormatFlagsNativeFloatPacked;
	asbd.mBytesPerPacket   = nChannels * sizeof (float);
	asbd.mFramesPerPacket  = 1;
	asbd.mBytesPerFrame    = nChannels * sizeof (float);
	asbd.mChannelsPerFrame = nChannels;
	asbd.mBitsPerChannel   = 8 * sizeof (float);
	return asbd;
}

@interface MIKOfflineMIDISynthesizer ()

@property (nonatomic, strong, readwrite) NSURL *outputFileURL;

@property (nonatomic) ExtAudioFileRef cafFile;
@property (nonatomic) AudioUnit outputUnit;
@property (nonatomic, strong) MIKMIDIClock *midiClock;

@property (nonatomic, copy) NSArray *allNoteMessages;
@property (nonatomic) MusicTimeStamp maxTrackLength;

@end

@implementation MIKOfflineMIDISynthesizer
{
	BOOL _doneRendering;
	
	MIKMIDITrack *__unsafe_unretained *_rawTracks;
	NSUInteger _numTracks;
}

- (instancetype)initWithAudioUnitDescription:(AudioComponentDescription)componentDescription
{
	self = [super initWithAudioUnitDescription:componentDescription];
	if (self) {
		_midiClock = [MIKMIDIClock clock];
	}
	return self;
}

- (BOOL)setupAUGraph
{
	AUGraph graph;
	OSStatus err = 0;
	if ((err = NewAUGraph(&graph))) {
		NSLog(@"Unable to create AU graph: %i", err);
		return NO;
	}
	
	AudioComponentDescription outputcd = {0};
	outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
	outputcd.componentType = kAudioUnitType_Output;
	outputcd.componentSubType = kAudioUnitSubType_GenericOutput;
	
	AUNode outputNode;
	if ((err = AUGraphAddNode(graph, &outputcd, &outputNode))) {
		NSLog(@"Unable to add ouptput node to graph: %i", err);
		return NO;
	}
	
	AudioComponentDescription instrumentcd = self.componentDescription;
	
	AUNode instrumentNode;
	if ((err = AUGraphAddNode(graph, &instrumentcd, &instrumentNode))) {
		NSLog(@"Unable to add instrument node to AU graph: %i", err);
		return NO;
	}
	
	if ((err = AUGraphOpen(graph))) {
		NSLog(@"Unable to open AU graph: %i", err);
		return NO;
	}
	
	AudioUnit outputUnit;
	if ((err = AUGraphNodeInfo(graph, outputNode, NULL, &outputUnit))) {
		NSLog(@"Unable to get output unit: %i", err);
		return NO;
	}
	
	AudioUnit instrumentUnit;
	if ((err = AUGraphNodeInfo(graph, instrumentNode, NULL, &instrumentUnit))) {
		NSLog(@"Unable to get instrument AU unit: %i", err);
		return NO;
	}
	
	if ((err = AUGraphConnectNodeInput(graph, instrumentNode, 0, outputNode, 0))) {
		NSLog(@"Unable to connect instrument to output: %i", err);
		return NO;
	}
	
	NSString *fileName = [[NSProcessInfo processInfo] globallyUniqueString];
	fileName = [fileName stringByAppendingPathExtension:@"caf"];
	NSString *tempDir = NSTemporaryDirectory();
	NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:tempDir]) {
		[fm createDirectoryAtPath:tempDir withIntermediateDirectories:NO attributes:nil error:NULL];
	}
	self.outputFileURL = [NSURL fileURLWithPath:filePath];
	
	ExtAudioFileRef cafFile;
	AudioStreamBasicDescription asbd = LPCMASBD();
	err = ExtAudioFileCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath],
											   kAudioFileCAFType,
											   &asbd,
											   NULL,
											   kAudioFileFlags_EraseFile,
											   &cafFile);
	if (err) {
		NSLog(@"Unable to create CAF file: %i", err);
		return NO;
	}
	self.cafFile = cafFile;
	
	if ((err = AudioUnitAddRenderNotify(outputUnit, recordCallback, (void *)self.cafFile))) {
		NSLog(@"Unable to add record callback: %i", err);
		return NO;
	}
	
	if ((err = AUGraphInitialize(graph))) {
		NSLog(@"Unable to initialize AU graph: %i", err);
		return NO;
	}
	
	err = AudioUnitAddRenderNotify(instrumentUnit, instrumentRenderCallback, (__bridge void *)self);
	if (err) {
		NSLog(@"Unable to set set render callback on instrument unit: %i", err);
		return NO;
	}
	
#if !TARGET_OS_IPHONE
	// Turn down reverb which is way too high by default
	if (instrumentcd.componentSubType == kAudioUnitSubType_DLSSynth) {
		if ((err = AudioUnitSetParameter(instrumentUnit, kMusicDeviceParam_ReverbVolume, kAudioUnitScope_Global, 0, -120, 0))) {
			NSLog(@"Unable to set reverb level to -120: %i", err);
		}
	}
#endif
	
	AudioStreamBasicDescription absd = LPCMASBD();
	if ((err = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &absd, sizeof(absd)))) {
		NSLog(@"Unable to set output unit's format: %i", err);
		return NO;
	}
	
	//	if ((err = AUGraphStart(graph))) {
	//		NSLog(@"Unable to start AU graph: %i", err);
	//		return NO;
	//	}
	
	self.graph = graph;
	self.outputUnit = outputUnit;
	self.instrumentUnit = instrumentUnit;
	
	return YES;
}

- (void)storeAllEvents
{
	NSPredicate *notePredicate = [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *b) {
		return [obj isKindOfClass:[MIKMIDINoteEvent class]];
	}];
	self.maxTrackLength = 0;
	NSMutableArray *noteEvents = [NSMutableArray array];
	for (NSUInteger i=0; i<[self.tracks count]; i++) {
		MIKMIDITrack *track = self.tracks[i];
		self.maxTrackLength = MAX(self.maxTrackLength, track.length);
		NSArray *events = [[track events] filteredArrayUsingPredicate:notePredicate];
		for (MIKMIDINoteEvent *event in events) {
			MIKMutableMIDINoteEvent *eventScratch = [event mutableCopy];
			eventScratch.channel = i;
			[noteEvents addObject:[eventScratch copy]];
		}
		if (events) [noteEvents addObjectsFromArray:events];
	}
	
	[noteEvents filterUsingPredicate:notePredicate];
	NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"timeStamp" ascending:YES];
	[noteEvents sortUsingDescriptors:@[sortDescriptor]];
	
	NSMutableArray *noteCommands = [NSMutableArray array];
	for (MIKMIDINoteEvent *event in noteEvents) {
		[noteCommands addObjectsFromArray:[MIKMIDICommand commandsFromNoteEvent:event clock:self.midiClock]];
	}
	
	self.allNoteMessages = noteCommands;
}

- (void)export
{
	[self storeAllEvents];
	//	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	//	render settings
	
	CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
	
	AudioTimeStamp timestamp = (AudioTimeStamp) { 0, kAudioTimeStampSampleTimeValid };
	
	UInt32 channels = LPCMASBD().mChannelsPerFrame;
	AudioBufferList bufferList;
	bufferList.mNumberBuffers = 1;
	bufferList.mBuffers[0].mNumberChannels = channels;
	bufferList.mBuffers[0].mDataByteSize = RENDER_FRAMES * channels * sizeof (float);
	
	AudioUnitRenderActionFlags flags = 0;
	OSStatus err = 0;
	
	do {
		//	output unit provides its own buffer
		bufferList.mBuffers[0].mData = NULL;
		
		err = AudioUnitRender(self.outputUnit, &flags, &timestamp, 0, RENDER_FRAMES, &bufferList);
		if (err) {
			NSLog(@"Error rendering: %i", err);
			break;
		}
		
		//	update state
		timestamp.mSampleTime += RENDER_FRAMES;
		
	} while (!_doneRendering);
	
	AUGraphStop(self.graph);
	ExtAudioFileDispose(self.cafFile);
	self.cafFile = NULL;
	
	NSLog(@"rendering took %f (%fs file)", CFAbsoluteTimeGetCurrent() - startTime, [self.midiClock midiTimeStampForMusicTimeStamp:self.maxTrackLength] * MIKMIDIClockSecondsPerMIDITimeStamp());
	
	//	});
}

#pragma mark - Callbacks

OSStatus instrumentRenderCallback(void							*info,
								  AudioUnitRenderActionFlags	*ioActionFlags,
								  const AudioTimeStamp			*inTimeStamp,
								  UInt32						inBusNumber,
								  UInt32						inNumberFrames,
								  AudioBufferList				*ioData)
{
	@autoreleasepool {
		MIKOfflineMIDISynthesizer *self = (__bridge MIKOfflineMIDISynthesizer *)info;
		OSStatus error = noErr;
		
		if ( (*ioActionFlags & kAudioUnitRenderAction_PreRender) == 0 ) return noErr;
		
		NSTimeInterval startTimeInterval = inTimeStamp->mSampleTime / 44100.0;
		NSTimeInterval duration = inNumberFrames / 44100.0;
		
		static mach_timebase_info_data_t timebaseInfo = {0,0};
		if (timebaseInfo.denom == 0) mach_timebase_info(&timebaseInfo);
		uint64_t midiStartTime = startTimeInterval * NSEC_PER_SEC * timebaseInfo.denom / timebaseInfo.numer;
		uint64_t midiEndTime = midiStartTime + duration * NSEC_PER_SEC;
		
		NSMutableArray *commands = [NSMutableArray array];
		for (MIKMIDICommand *command in self.allNoteMessages) {
			if (midiStartTime > command.midiTimestamp) continue;
			if (midiEndTime <= command.midiTimestamp) break;
			
			[commands addObject:command];
		}
		
		if ([self.midiClock musicTimeStampForMIDITimeStamp:midiEndTime] >= self.maxTrackLength)
			self->_doneRendering = YES;
		
		for (MIKMIDINoteOnCommand *command in commands) {
			NSLog(@"channel: %i status: %x (%@)", command.channel, (unsigned int)command.statusByte, command.data);
			error = MusicDeviceMIDIEvent(self.instrumentUnit, command.statusByte, command.dataByte1, command.dataByte2, 0);
			if (error) return error;
		}
	}
	return noErr;
}

#pragma mark - Properties

- (void)setTracks:(NSArray *)tracks
{
	if (tracks != _tracks) {
		free(_rawTracks);
		_tracks = tracks;
		
		_numTracks = [_tracks count];
		_rawTracks = (MIKMIDITrack *__unsafe_unretained *)malloc(sizeof(MIKMIDITrack *) * _numTracks);
		[_tracks getObjects:_rawTracks];
	}
}

- (void)setTempo:(Float64)tempo
{
	if (tempo != _tempo) {
		_tempo = tempo;
		[self.midiClock syncMusicTimeStamp:0 withMIDITimeStamp:0 tempo:_tempo];
	}
}

@end
