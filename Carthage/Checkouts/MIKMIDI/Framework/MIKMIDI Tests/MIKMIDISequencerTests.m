//
//  MIKMIDISequencerTests.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/13/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMIDISequencerTests : XCTestCase

@property (nonatomic, strong) MIKMIDISequencer *sequencer;

@end

@implementation MIKMIDISequencerTests

- (void)setUp
{
    [super setUp];
	
	self.sequencer = [MIKMIDISequencer sequencer];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testBuiltinSynthesizers
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *testMIDIFileURL = [bundle URLForResource:@"bach" withExtension:@"mid"];
	NSError *error = nil;
	MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:testMIDIFileURL convertMIDIChannelsToTracks:NO error:&error];
	XCTAssertNotNil(sequence);
	
	self.sequencer.sequence = sequence;
	for (MIKMIDITrack *track in sequence.tracks) {
		MIKMIDISynthesizer *synth = [self.sequencer builtinSynthesizerForTrack:track];
		XCTAssertNotNil(synth, @"-builtinSynthesizerForTrack: test failed, because it returned nil.");
	}
}

@end
