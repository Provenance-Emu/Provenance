//
//  MIKMainWindowController.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 2/20/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import "MIKMainWindowController.h"
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMainWindowController ()

@property (nonatomic, strong) MIKMIDISequencer *sequencer;
@property (nonatomic, strong) MIKMIDIEndpointSynthesizer *endpointSynth;

@property (nonatomic, strong) id deviceConnectionToken;

@end

@implementation MIKMainWindowController

+ (instancetype)windowController
{
	return [[self alloc] initWithWindowNibName:@"MainWindow"];
}

- (void)dealloc
{
	self.device = nil;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	self.sequencer = [MIKMIDISequencer sequencer];
	self.sequencer.preRoll = 0;
	self.sequencer.clickTrackStatus = MIKMIDISequencerClickTrackStatusDisabled;
	
	NSPredicate *nonBluetoothNetworkPredicate = [NSPredicate predicateWithBlock:^BOOL(MIKMIDIDevice *device, NSDictionary *b) {
		return ![device.name isEqualToString:@"Bluetooth"] && ![device.name isEqualToString:@"Network"];
	}];
	NSArray *devices = [self.deviceManager.availableDevices filteredArrayUsingPredicate:nonBluetoothNetworkPredicate];
	if (!self.device) self.device = [devices firstObject];
}

#pragma mark - Actions

- (IBAction)loadFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowedFileTypes:@[@"mid", @"midi"]];
	[openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) return;
		[self loadMIDIFile:[[openPanel URL] path]];
	}];
}

- (IBAction)toggleRecording:(id)sender
{
	if (self.isRecording) {
		[self.sequencer stop];
		[self.trackView setNeedsDisplay:YES];
		return;
	} else {
		if (!self.sequence) self.sequence = [MIKMIDISequence sequence];
		NSError *error = nil;
		MIKMIDITrack *newTrack = [self.sequence addTrackWithError:&error];
		if (!newTrack) {
			[self presentError:error];
			return;
		}
		self.sequencer.recordEnabledTracks = [NSSet setWithObject:newTrack];
		[self.sequencer startRecording];
	}
}

- (IBAction)togglePlayback:(id)sender
{
	self.isPlaying ? [self.sequencer stop] : [self.sequencer startPlayback];
}

#pragma mark - MIKMIDISequenceViewDelegate

- (void)midiSequenceView:(MIKMIDISequenceView *)sequenceView receivedDroppedMIDIFiles:(NSArray *)midiFiles
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self loadMIDIFile:[midiFiles firstObject]];
	});
}

#pragma mark - Private

- (void)loadMIDIFile:(NSString *)path
{
	NSError *error = nil;
	MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:[NSURL fileURLWithPath:path] error:&error];
	if (!sequence) {
		NSLog(@"Error loading MIDI file: %@", error);
		return;
	}
	self.sequence = sequence;
}

#pragma mark Device Connection/Disconnection

- (BOOL)connectToDevice:(MIKMIDIDevice *)device error:(NSError **)error
{
	error = error ? error : &(NSError *__autoreleasing){ nil };
	MIKMIDISourceEndpoint *source = [[[device.entities firstObject] sources] firstObject];
	if (!source) {
		*error = [NSError MIKMIDIErrorWithCode:MIKMIDIUnknownErrorCode userInfo:nil];
		return NO;
	}
	
	MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
	self.deviceConnectionToken = [manager connectInput:source error:error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
		for (MIKMIDICommand *command in commands) {
			if (self.isRecording) [self.sequencer recordMIDICommand:command];
		}
	}];
	if (!self.deviceConnectionToken) return NO;
	
	// So audio can be heard
	self.endpointSynth = [[MIKMIDIEndpointSynthesizer alloc] initWithMIDISource:source];
	
	return YES;
}

- (void)disconnectFromDevice
{
	if (!self.deviceConnectionToken) return;
	
	[[MIKMIDIDeviceManager sharedDeviceManager] disconnectConnectionForToken:self.deviceConnectionToken];
	self.deviceConnectionToken = nil;
}

#pragma mark - Properties

- (MIKMIDIDeviceManager *)deviceManager { return [MIKMIDIDeviceManager sharedDeviceManager]; }

- (void)setSequence:(MIKMIDISequence *)sequence
{
	if (sequence != _sequence) {
		_sequence = sequence;
		self.trackView.sequence = sequence;
		self.sequencer.sequence = sequence;
	}
}

- (void)setDevice:(MIKMIDIDevice *)device
{
	if (device != _device) {
		[self disconnectFromDevice];
		
		NSError *error = nil;
		if (![self connectToDevice:device error:&error]) {
			[self presentError:error];
			_device = nil;
		} else {
			_device = device;
		}
	}
}

+ (NSSet *)keyPathsForValuesAffectingPlaying
{
	return [NSSet setWithObjects:@"sequencer.playing", nil];
}

- (BOOL)isPlaying
{
	return self.sequencer.isPlaying;
}

+ (NSSet *)keyPathsForValuesAffectingRecording
{
	return [NSSet setWithObjects:@"sequencer.recording", nil];
}

- (BOOL)isRecording
{
	return self.sequencer.isRecording;
}

+ (NSSet *)keyPathsForValuesAffectingRecordButtonLabel
{
	return [NSSet setWithObjects:@"recording", nil];
}

- (NSString *)recordButtonLabel
{
	return self.isRecording ? @"Stop" : @"Record";
}

+ (NSSet *)keyPathsForValuesAffectingPlayButtonLabel
{
	return [NSSet setWithObjects:@"playing", nil];
}

- (NSString *)playButtonLabel
{
	return self.isPlaying ? @"Stop" : @"Play";
}

@end
