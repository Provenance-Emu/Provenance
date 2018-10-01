//
//  MIKMIDISequenceTests.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/7/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMIDISequenceTests : XCTestCase

@property (nonatomic, strong) MIKMIDISequence *sequence;
@property (nonatomic, strong) NSMutableSet *receivedNotificationKeyPaths;

@end

static void *MIKMIDISequenceTestsKVOContext = &MIKMIDISequenceTestsKVOContext;

@implementation MIKMIDISequenceTests

- (void)setUp
{
    [super setUp];
	
	self.receivedNotificationKeyPaths = [NSMutableSet set];
	self.sequence = [MIKMIDISequence sequence];
	[self.sequence addObserver:self forKeyPath:@"tracks" options:0 context:MIKMIDISequenceTestsKVOContext];
	[self.sequence addObserver:self forKeyPath:@"durationInSeconds" options:0 context:MIKMIDISequenceTestsKVOContext];
	[self.sequence addObserver:self forKeyPath:@"length" options:0 context:MIKMIDISequenceTestsKVOContext];
}

- (void)tearDown
{
	[self.sequence removeObserver:self forKeyPath:@"tracks" context:MIKMIDISequenceTestsKVOContext];
	[self.sequence removeObserver:self forKeyPath:@"durationInSeconds" context:MIKMIDISequenceTestsKVOContext];
	[self.sequence removeObserver:self forKeyPath:@"length" context:MIKMIDISequenceTestsKVOContext];
	
	self.sequence = nil;
	
    [super tearDown];
}

- (void)testMIDIFileRead
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *testMIDIFileURL = [bundle URLForResource:@"bach" withExtension:@"mid"];
	NSError *error = nil;
	MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:testMIDIFileURL convertMIDIChannelsToTracks:NO error:&error];
	XCTAssertNotNil(sequence);
	
	// Make sure number of tracks is correct
	XCTAssertEqual([sequence.tracks count], 3);
	XCTAssertNotNil(sequence.tempoTrack);
	
	// Check that the number of events in each track is correct
	XCTAssertEqual([[sequence.tracks[1] events] count], 242);
	XCTAssertEqual([[sequence.tracks[2] events] count], 220);
}

- (void)testMIDIFileReadPerformance
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *testMIDIFileURL = [bundle URLForResource:@"Parallax-Loader" withExtension:@"mid"];
	[self measureBlock:^{
		[MIKMIDISequence sequenceWithFileAtURL:testMIDIFileURL convertMIDIChannelsToTracks:NO error:NULL];
	}];
}

- (void)testKVOForAddingATrack
{
	XCTAssertNotNil(self.sequence);
	
	[self keyValueObservingExpectationForObject:self.sequence keyPath:@"tracks" handler:^BOOL(MIKMIDISequence *sequence, NSDictionary *change) {
		if ([change[NSKeyValueChangeKindKey] integerValue] != NSKeyValueChangeInsertion) return NO;
		if ([change[NSKeyValueChangeOldKey] count] != 0) return NO;
		if ([change[NSKeyValueChangeNewKey] count] != 1) return NO;
		return YES;
	}];
	MIKMIDITrack *firstTrack = [self.sequence addTrackWithError:NULL];
	XCTAssertNotNil(firstTrack, @"Creating an MIKMIDITrack failed.");
	XCTAssertEqual(self.sequence.tracks.count, 1, @"MIKMIDISequence's tracks count was incorrect after adding a track.");
	[self waitForExpectationsWithTimeout:0.1 handler:^(NSError *error) {
		NSLog(@"%@ expectation failed: %@", NSStringFromSelector(_cmd), error);
	}];
}

- (void)testKVOForRemovingATrack
{
	MIKMIDITrack *firstTrack = [self.sequence addTrackWithError:NULL];
	XCTAssertNotNil(firstTrack, @"Creating an MIKMIDITrack failed.");
	MIKMIDITrack *secondTrack = [self.sequence addTrackWithError:NULL];
	XCTAssertNotNil(secondTrack, @"Creating an MIKMIDITrack failed.");

	[self keyValueObservingExpectationForObject:self.sequence keyPath:@"tracks" handler:^BOOL(MIKMIDISequence *sequence, NSDictionary *change) {
		if ([change[NSKeyValueChangeKindKey] integerValue] != NSKeyValueChangeRemoval) return NO;
		NSArray *oldTracks = change[NSKeyValueChangeOldKey];
		NSArray *newTracks = change[NSKeyValueChangeNewKey];
		if ([oldTracks count] != 1) return NO;
		if ([newTracks count] != 0) return NO;
		if (oldTracks.firstObject != firstTrack) return NO;
		return YES;
	}];
	[self.sequence removeTrack:firstTrack];
	XCTAssertEqual(self.sequence.tracks.count, 1, @"Removing a track from MIKMIDISequence failed");
	
	[self waitForExpectationsWithTimeout:0.1 handler:^(NSError *error) {
		NSLog(@"%@ expectation failed: %@", NSStringFromSelector(_cmd), error);
	}];
}

- (void)testLength
{
	MIKMIDITrack *firstTrack = [self.sequence addTrackWithError:NULL];
	XCTAssertNotNil(firstTrack, @"Creating an MIKMIDITrack failed.");
	MIKMIDITrack *secondTrack = [self.sequence addTrackWithError:NULL];
	XCTAssertNotNil(secondTrack, @"Creating an MIKMIDITrack failed.");
	MIKMIDITrack *thirdTrack = [self.sequence addTrackWithError:NULL];
	XCTAssertNotNil(thirdTrack, @"Creating an MIKMIDITrack failed.");

	self.sequence.length = MIKMIDISequenceLongestTrackLength;
	
	[self.receivedNotificationKeyPaths removeAllObjects];
	[thirdTrack addEvent:[MIKMIDINoteEvent noteEventWithTimeStamp:100 note:60 velocity:127 duration:1 channel:0]];
	XCTAssertTrue([self.receivedNotificationKeyPaths containsObject:@"length"], @"KVO notification for length failed after adding event to child track.");
	XCTAssertTrue([self.receivedNotificationKeyPaths containsObject:@"durationInSeconds"], @"KVO notification for durationInSeconds failed after adding event to child track.");
	
	[self.receivedNotificationKeyPaths removeAllObjects];
	[thirdTrack removeAllEvents];
	XCTAssertTrue([self.receivedNotificationKeyPaths containsObject:@"length"], @"KVO notification for length failed after removing events from child track.");
	XCTAssertTrue([self.receivedNotificationKeyPaths containsObject:@"durationInSeconds"], @"KVO notification for durationInSeconds failed after removing events from child track.");
	
	[thirdTrack addEvent:[MIKMIDINoteEvent noteEventWithTimeStamp:100 note:60 velocity:127 duration:1 channel:0]];
	[self.receivedNotificationKeyPaths removeAllObjects];
	[self.sequence removeTrack:thirdTrack];
	XCTAssertTrue([self.receivedNotificationKeyPaths containsObject:@"length"], @"KVO notification for length failed after removing longest child track.");
	XCTAssertTrue([self.receivedNotificationKeyPaths containsObject:@"durationInSeconds"], @"KVO notification for durationInSeconds failed after removing longest child track.");
}

- (void)testSetTimeSignature
{
	[self.sequence setTimeSignature:MIKMIDITimeSignatureMake(2, 4) atTimeStamp:0];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context != MIKMIDISequenceTestsKVOContext) {
		return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
	
	if (object == self.sequence) {
		[self.receivedNotificationKeyPaths addObject:keyPath];
	}
}

@end
