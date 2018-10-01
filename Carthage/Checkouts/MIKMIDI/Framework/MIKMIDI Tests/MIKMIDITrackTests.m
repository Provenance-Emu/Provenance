//
//  MIKMIDITrackTests.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 3/7/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMIDITrackTests : XCTestCase

@property BOOL eventsChangeNotificationReceived;
@property BOOL notesChangeNotificationReceived;

@property (nonatomic, strong) MIKMIDISequence *defaultSequence;
@property (nonatomic, strong) MIKMIDITrack *defaultTrack;
@property (copy) NSString *receivedKVONotificationKeyPath;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation MIKMIDITrackTests

- (void)setUp
{
	[super setUp];
	
	self.defaultSequence = [MIKMIDISequence sequence];
	self.defaultTrack = [self.defaultSequence addTrack];
	
	[self.defaultTrack addObserver:self forKeyPath:@"events" options:0 context:NULL];
	[self.defaultTrack addObserver:self forKeyPath:@"notes" options:0 context:NULL];
}

- (void)tearDown
{
	self.receivedKVONotificationKeyPath = nil;
	self.eventsChangeNotificationReceived = NO;
	self.notesChangeNotificationReceived = NO;
	
	[self.defaultTrack removeObserver:self forKeyPath:@"events"];
	[self.defaultTrack removeObserver:self forKeyPath:@"notes"];
	
	self.defaultSequence = nil;
	self.defaultTrack = nil;
	
	[super tearDown];
}

- (void)testBasicEventsAddRemove
{
	// Test adding an event
	MIKMIDIEvent *event = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvent:event];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Adding an event to MIKMIDITrack did not produce a KVO notification.");
	XCTAssertTrue([self.defaultTrack.events containsObject:event], @"Adding an event to MIKMIDITrack failed.");
	XCTAssertEqual([self.defaultTrack.events count], 1, @"Adding an event to MIKMIDITrack failed.");
	self.eventsChangeNotificationReceived = NO;
	
	// Test removing an event
	[self.defaultTrack removeEvent:event];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Removing an event from MIKMIDITrack did not produce a KVO notification.");
	XCTAssertFalse([self.defaultTrack.events containsObject:event], @"Removing an event from MIKMIDITrack failed.");
	self.eventsChangeNotificationReceived = NO;
	
	// Test removing some events
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:63 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvent:event];
	[self.defaultTrack addEvent:event2];
	[self.defaultTrack addEvent:event3];
	[self.defaultTrack addEvent:event4];
	XCTAssertEqual([self.defaultTrack.events count], 4, @"Adding 4 events to MIKMIDITrack failed.");
	[self.defaultTrack removeEvents:@[event2, event3]];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Removing some events from MIKMIDITrack did not produce a KVO notification.");
	XCTAssertEqual([self.defaultTrack.events count], 2, @"Removing some events from MIKMIDITrack failed.");
	NSArray *remainingEvents = @[event, event4];
	XCTAssertEqualObjects(remainingEvents, self.defaultTrack.events , @"Removing some events from MIKMIDITrack failed.");
	self.eventsChangeNotificationReceived = NO;
	
	// Test removing all events
	[self.defaultTrack addEvent:event];
	[self.defaultTrack addEvent:event2];
	[self.defaultTrack addEvent:event3];
	[self.defaultTrack removeAllEvents];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Removing all events from MIKMIDITrack did not produce a KVO notification.");
	XCTAssertEqual([self.defaultTrack.events count], 0, @"Removing all events from MIKMIDITrack failed.");
	self.eventsChangeNotificationReceived = NO;
	
}

- (void)testLoadFromFile
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *testMIDIFileURL = [bundle URLForResource:@"bach" withExtension:@"mid"];
	NSError *error = nil;
	MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:testMIDIFileURL convertMIDIChannelsToTracks:NO error:&error];
	XCTAssertNotNil(sequence);
	XCTAssertEqual([sequence.tracks count], 3, @"Sequence loaded from file doesn't have expected number of tracks.");
	
	MIKMIDITrack *firstNotesTrack = sequence.tracks[1];
	XCTAssertTrue([firstNotesTrack.notes count] > 0, @"Notes track loaded from file is empty.");
}

#pragma mark - Moving Events

- (void)testMovingSingleEvent
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:63 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack moveEventsFromStartingTimeStamp:2 toEndingTimeStamp:2 byAmount:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Moving an event in MIKMIDITrack did not produce a KVO notification.");
	MIKMIDIEvent *expectedEvent2AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:61 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[event1, event3, expectedEvent2AfterMove, event4];
	XCTAssertEqualObjects(self.defaultTrack.events, expectedNewEvents, @"Moving an event in MIKMIDITrack failed.");
}

- (void)testMovingMultipleEventsAtSameTimestamp
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack moveEventsFromStartingTimeStamp:2 toEndingTimeStamp:2 byAmount:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Moving events in MIKMIDITrack did not produce a KVO notification.");
	MIKMIDIEvent *expectedEvent2AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent3AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:62 velocity:127 duration:1 channel:0];
	
	// Use sets, because order of events with the same timestamp is (acceptably) unpredictable
	NSSet *expectedNewEvents = [NSSet setWithArray:@[event1, event4, expectedEvent2AfterMove, expectedEvent3AfterMove, event5]];
	NSSet *eventsAfterMoving = [NSSet setWithArray:self.defaultTrack.events];
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Moving an event in MIKMIDITrack failed.");
	
}

- (void)testMovingEventsInARange
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack moveEventsFromStartingTimeStamp:2 toEndingTimeStamp:3 byAmount:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Moving events in MIKMIDITrack did not produce a KVO notification.");
	MIKMIDIEvent *expectedEvent2AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent3AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:62 velocity:127 duration:1 channel:0];
	
	// Use sets, because order of events with the same timestamp is (acceptably) unpredictable
	NSSet *expectedNewEvents = [NSSet setWithArray:@[event1, event4, expectedEvent2AfterMove, expectedEvent3AfterMove, event5]];
	NSSet *eventsAfterMoving = [NSSet setWithArray:self.defaultTrack.events];
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Moving an event in MIKMIDITrack failed.");
}

- (void)testMovingEventsPastTheEnd
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack moveEventsFromStartingTimeStamp:5 toEndingTimeStamp:7 byAmount:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Moving events in MIKMIDITrack did not produce a KVO notification.");
	MIKMIDIEvent *expectedEvent5AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:9 note:64 velocity:127 duration:1 channel:0];
	
	NSArray *expectedNewEvents = @[event1, event2, event3, event4, expectedEvent5AfterMove];
	NSArray *eventsAfterMoving = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Moving an event in MIKMIDITrack failed.");
	
	XCTAssertGreaterThanOrEqual(self.defaultTrack.length, expectedEvent5AfterMove.timeStamp, @"Moving last event in track didn't properly update its length.");
	
}

- (void)testMovingEventBackwards
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:63 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack moveEventsFromStartingTimeStamp:4 toEndingTimeStamp:4 byAmount:-2];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Moving an event in MIKMIDITrack did not produce a KVO notification.");
	MIKMIDIEvent *expectedEvent3AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:62 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[event1, expectedEvent3AfterMove, event2, event4];
	XCTAssertEqualObjects(self.defaultTrack.events, expectedNewEvents, @"Moving an event in MIKMIDITrack failed.");
	
}

- (void)testMovingEventsInARangeBackwards
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:8 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:10 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack moveEventsFromStartingTimeStamp:5.5 toEndingTimeStamp:8.5 byAmount:-4];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Moving events in MIKMIDITrack did not produce a KVO notification.");
	MIKMIDIEvent *expectedEvent3AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4AfterMove = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	
	// Use sets, because order of events with the same timestamp is (acceptably) unpredictable
	NSArray *expectedNewEvents = @[event1, expectedEvent3AfterMove, expectedEvent4AfterMove, event2, event5];
	NSArray *eventsAfterMoving = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Moving an event in MIKMIDITrack failed.");
	
}

#pragma mark - Clearing Events

- (void)testClearingSingleEvent
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack clearEventsFromStartingTimeStamp:2 toEndingTimeStamp:2];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Clearing events in MIKMIDITrack did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event3, event4, event5];
	NSArray *eventsAfterMoving = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Clearing an event in MIKMIDITrack failed.");
	
}

- (void)testClearingMultipleEventsAtSameTimestamp
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack clearEventsFromStartingTimeStamp:2 toEndingTimeStamp:2];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Clearing events in MIKMIDITrack did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event4, event5];
	NSArray *eventsAfterMoving = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Clearing an event in MIKMIDITrack failed.");
	
}

- (void)testClearingEventsInARange
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack clearEventsFromStartingTimeStamp:3 toEndingTimeStamp:4];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Clearing events in MIKMIDITrack did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event2, event5];
	NSArray *eventsAfterMoving = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Clearing an event in MIKMIDITrack failed.");
	
}

- (void)testClearingEventsInAWiderRange
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack clearEventsFromStartingTimeStamp:2.5 toEndingTimeStamp:4.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Clearing events in MIKMIDITrack did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event2, event5];
	NSArray *eventsAfterMoving = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMoving, expectedNewEvents, @"Clearing an event in MIKMIDITrack failed.");
	
}

#pragma mark - Cutting Events

- (void)testCuttingSingleEvent
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack cutEventsFromStartingTimeStamp:3 toEndingTimeStamp:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Cutting events in MIKMIDITrack did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event2, event4, event5];
	NSArray *eventsAfterCutting = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCutting, expectedNewEvents, @"Cutting an event in MIKMIDITrack failed.");
	
}

- (void)testCuttingSingleEventInWiderRange
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack cutEventsFromStartingTimeStamp:2.5 toEndingTimeStamp:3.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Cutting events in MIKMIDITrack did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent4AfterCut = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent5AfterCut = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[event1, event2, expectedEvent4AfterCut, expectedEvent5AfterCut];
	NSArray *eventsAfterCutting = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCutting, expectedNewEvents, @"Cutting an event in MIKMIDITrack failed.");
	
}

- (void)testCuttingMultipleEventsAtSameTimestamp
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack cutEventsFromStartingTimeStamp:2 toEndingTimeStamp:2];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Cutting events in MIKMIDITrack did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event4, event5];
	NSArray *eventsAfterCutting = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCutting, expectedNewEvents, @"Cutting an event in MIKMIDITrack failed.");
	
}

- (void)testCuttingEventsInARange
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack cutEventsFromStartingTimeStamp:3 toEndingTimeStamp:4];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Cutting events in MIKMIDITrack did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent5AfterCut = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[event1, event2, expectedEvent5AfterCut];
	NSArray *eventsAfterCut = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCut, expectedNewEvents, @"Cutting an event in MIKMIDITrack failed.");
	
}

- (void)testCuttingEventsInAWiderRange
{
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	NSArray *allEvents = @[event1, event2, event3, event4, event5];
	[self.defaultTrack addEvents:allEvents];
	
	self.eventsChangeNotificationReceived = NO;
	
	// Move event 2 to timestamp 5
	[self.defaultTrack cutEventsFromStartingTimeStamp:2.5 toEndingTimeStamp:4.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Cutting events in MIKMIDITrack did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent5AfterCut = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:64 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[event1, event2, expectedEvent5AfterCut];
	NSArray *eventsAfterCut = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCut, expectedNewEvents, @"Cutting an event in MIKMIDITrack failed.");
}

#pragma mark - Copying Events

- (void)testCopyingSingleEvent
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3.5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[event1, event2, event4, event5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack copyEventsFromMIDITrack:sourceTrack fromTimeStamp:3 toTimeStamp:3 andInsertAtTimeStamp:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Copying events between MIKMIDITracks did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event2, event3, event4, event5];
	NSArray *eventsAfterCopy = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCopy, expectedNewEvents, @"Copying events between MIKMIDITracks failed.");
	
}

- (void)testCopyingSingleEventInWiderRange
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[event1, event2, event4, event5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack copyEventsFromMIDITrack:sourceTrack fromTimeStamp:2.5 toTimeStamp:3.5 andInsertAtTimeStamp:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Copying events between MIKMIDITracks did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent4AfterCopy = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent5AfterCopy = [MIKMIDINoteEvent noteEventWithTimeStamp:7 note:64 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[event1, event2, event3, expectedEvent4AfterCopy, expectedEvent5AfterCopy];
	NSArray *eventsAfterCopy = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCopy, expectedNewEvents, @"Copying events between MIKMIDITracks failed.");
	
}

- (void)testCopyingMultipleEvents
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	MIKMIDIEvent *destEvent1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[destEvent1, destEvent2, destEvent4, destEvent5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack copyEventsFromMIDITrack:sourceTrack fromTimeStamp:3 toTimeStamp:4 andInsertAtTimeStamp:2.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Copying events between MIKMIDITracks did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3.5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent6 = [MIKMIDINoteEvent noteEventWithTimeStamp:7 note:64 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[destEvent1, destEvent2, expectedEvent3, expectedEvent4, expectedEvent5, expectedEvent6];
	NSArray *eventsAfterCopy = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCopy, expectedNewEvents, @"Copying events between MIKMIDITracks failed.");
	
}

- (void)testCopyingMultipleEventsAtSameTimestamp
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	MIKMIDIEvent *destEvent1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[destEvent1, destEvent2, destEvent4, destEvent5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack copyEventsFromMIDITrack:sourceTrack fromTimeStamp:3 toTimeStamp:3 andInsertAtTimeStamp:2.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Copying events between MIKMIDITracks did not produce a KVO notification.");
	
	// Use sets, because order of events with the same timestamp is (acceptably) unpredictable
	MIKMIDIEvent *expectedEvent3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:63 velocity:127 duration:1 channel:0];
	NSSet *expectedNewEvents = [NSSet setWithArray:@[destEvent1, destEvent2, expectedEvent3, expectedEvent4, destEvent4, destEvent5]];
	NSSet *eventsAfterCopy = [NSSet setWithArray:self.defaultTrack.events];
	XCTAssertEqualObjects(eventsAfterCopy, expectedNewEvents, @"Copying events between MIKMIDITracks failed.");
}

- (void)testCopyingMultipleEventsInAWiderRange
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	MIKMIDIEvent *destEvent1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[destEvent1, destEvent2, destEvent4, destEvent5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack copyEventsFromMIDITrack:sourceTrack fromTimeStamp:2.5 toTimeStamp:4.5 andInsertAtTimeStamp:2.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Copying events between MIKMIDITracks did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3.5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:7 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent6 = [MIKMIDINoteEvent noteEventWithTimeStamp:8 note:64 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[destEvent1, destEvent2, expectedEvent3, expectedEvent4, expectedEvent5, expectedEvent6];
	NSArray *eventsAfterCopy = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterCopy, expectedNewEvents, @"Copying events between MIKMIDITracks failed.");
	
}

#pragma mark - Merging Events

- (void)testMergingSingleEvent
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3.5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[event1, event2, event4, event5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack mergeEventsFromMIDITrack:sourceTrack fromTimeStamp:3 toTimeStamp:3 atTimeStamp:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Merging events between MIKMIDITracks did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event2, event3, event4, event5];
	NSArray *eventsAfterMerge = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMerge, expectedNewEvents, @"Merging events between MIKMIDITracks failed.");
	
}

- (void)testMergingSingleEventInWiderRange
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[event1, event2, event4, event5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack mergeEventsFromMIDITrack:sourceTrack fromTimeStamp:2.5 toTimeStamp:3.5 atTimeStamp:3];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Merging events between MIKMIDITracks did not produce a KVO notification.");
	
	NSArray *expectedNewEvents = @[event1, event2, event3, event4, event5];
	NSArray *eventsAfterMerge = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMerge, expectedNewEvents, @"Merging events between MIKMIDITracks failed.");
	
}

- (void)testMergingMultipleEvents
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	MIKMIDIEvent *destEvent1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[destEvent1, destEvent2, destEvent4, destEvent5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack mergeEventsFromMIDITrack:sourceTrack fromTimeStamp:3 toTimeStamp:4 atTimeStamp:2.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Merging events between MIKMIDITracks did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3.5 note:63 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[destEvent1, destEvent2, expectedEvent3, expectedEvent4, destEvent4, destEvent5];
	NSArray *eventsAfterMerge = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMerge, expectedNewEvents, @"Merging events between MIKMIDITracks failed.");
	
}

- (void)testMergingMultipleEventsAtSameTimestamp
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	MIKMIDIEvent *destEvent1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[destEvent1, destEvent2, destEvent4, destEvent5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack mergeEventsFromMIDITrack:sourceTrack fromTimeStamp:3 toTimeStamp:3 atTimeStamp:2.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Merging events between MIKMIDITracks did not produce a KVO notification.");
	
	// Use sets, because order of events with the same timestamp is (acceptably) unpredictable
	MIKMIDIEvent *expectedEvent3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:63 velocity:127 duration:1 channel:0];
	NSSet *expectedNewEvents = [NSSet setWithArray:@[destEvent1, destEvent2, expectedEvent3, expectedEvent4, destEvent4, destEvent5]];
	NSSet *eventsAfterMerge = [NSSet setWithArray:self.defaultTrack.events];
	XCTAssertEqualObjects(eventsAfterMerge, expectedNewEvents, @"Merging events between MIKMIDITracks failed.");
}

- (void)testMergingMultipleEventsInAWiderRange
{
	MIKMIDITrack *sourceTrack = [self.defaultSequence addTrack];
	MIKMIDIEvent *event1 = [MIKMIDINoteEvent noteEventWithTimeStamp:0.5 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event3 = [MIKMIDINoteEvent noteEventWithTimeStamp:3 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event4 = [MIKMIDINoteEvent noteEventWithTimeStamp:4 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *event5 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:64 velocity:127 duration:1 channel:0];
	[sourceTrack addEvents:@[event1, event2, event3, event4, event5]];
	
	
	MIKMIDIEvent *destEvent1 = [MIKMIDINoteEvent noteEventWithTimeStamp:1 note:60 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent2 = [MIKMIDINoteEvent noteEventWithTimeStamp:2 note:61 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:5 note:63 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *destEvent5 = [MIKMIDINoteEvent noteEventWithTimeStamp:6 note:64 velocity:127 duration:1 channel:0];
	[self.defaultTrack addEvents:@[destEvent1, destEvent2, destEvent4, destEvent5]];
	
	self.eventsChangeNotificationReceived = NO;
	
	[self.defaultTrack mergeEventsFromMIDITrack:sourceTrack fromTimeStamp:2.5 toTimeStamp:4.5 atTimeStamp:2.5];
	XCTAssertTrue(self.eventsChangeNotificationReceived && self.notesChangeNotificationReceived, @"Merging events between MIKMIDITracks did not produce a KVO notification.");
	
	MIKMIDIEvent *expectedEvent3 = [MIKMIDINoteEvent noteEventWithTimeStamp:2.5 note:62 velocity:127 duration:1 channel:0];
	MIKMIDIEvent *expectedEvent4 = [MIKMIDINoteEvent noteEventWithTimeStamp:3.5 note:63 velocity:127 duration:1 channel:0];
	NSArray *expectedNewEvents = @[destEvent1, destEvent2, expectedEvent3, expectedEvent4, destEvent4, destEvent5];
	NSArray *eventsAfterMerge = self.defaultTrack.events;
	XCTAssertEqualObjects(eventsAfterMerge, expectedNewEvents, @"Merging events between MIKMIDITracks failed.");
	
}

#pragma mark - Other Properties

- (void)testSettingNumberOfLoops
{
	[self.defaultTrack addObserver:self forKeyPath:@"numberOfLoops" options:0 context:NULL];
	{
		self.defaultTrack.numberOfLoops = 42;
		XCTAssertEqual(self.defaultTrack.numberOfLoops, 42, @"Setting numberOfLoops failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"numberOfLoops", @"Setting numberOfLoops did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"numberOfLoops"];
}

- (void)testSettingLoopDuration
{
	[self.defaultTrack addObserver:self forKeyPath:@"loopDuration" options:0 context:NULL];
	{
		self.defaultTrack.loopDuration = 42;
		XCTAssertEqual(self.defaultTrack.loopDuration, 42, @"Setting loopDuration failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"loopDuration", @"Setting loopDuration did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"loopDuration"];
}

- (void)testSettingLoopInfo
{
	[self.defaultTrack addObserver:self forKeyPath:@"loopInfo" options:0 context:NULL];
	{
		MusicTrackLoopInfo info = {
			.loopDuration = 42,
			.numberOfLoops = 27,
		};
		self.defaultTrack.loopInfo = info;
		XCTAssertEqual(self.defaultTrack.loopInfo.loopDuration, info.loopDuration, @"Setting loopInfo failed.");
		XCTAssertEqual(self.defaultTrack.loopInfo.numberOfLoops, info.numberOfLoops, @"Setting loopInfo failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"loopInfo", @"Setting loopInfo did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"loopInfo"];
}

- (void)testSettingOffset
{
	[self.defaultTrack addObserver:self forKeyPath:@"offset" options:0 context:NULL];
	{
		self.defaultTrack.offset = 42;
		XCTAssertEqual(self.defaultTrack.offset, 42, @"Setting offset failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"offset", @"Setting offset did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"offset"];
}

- (void)testSettingMuted
{
	[self.defaultTrack addObserver:self forKeyPath:@"muted" options:0 context:NULL];
	{
		self.defaultTrack.muted = YES;
		XCTAssertEqual(self.defaultTrack.muted, YES, @"Setting muted failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"muted", @"Setting muted did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"muted"];
}

- (void)testSettingSolo
{
	[self.defaultTrack addObserver:self forKeyPath:@"solo" options:0 context:NULL];
	{
		self.defaultTrack.solo = YES;
		XCTAssertEqual(self.defaultTrack.solo, YES, @"Setting solo failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"solo", @"Setting solo did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"solo"];
}

- (void)testSettingLength
{
	[self.defaultTrack addObserver:self forKeyPath:@"length" options:0 context:NULL];
	{
		self.defaultTrack.length = 42;
		XCTAssertEqual(self.defaultTrack.length, 42, @"Setting length failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"length", @"Setting length did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"length"];
}

- (void)testSettingLengthByAddingEvents
{
	[self.defaultTrack addObserver:self forKeyPath:@"length" options:0 context:NULL];
	{
		MusicTimeStamp startingLength = self.defaultTrack.length;
		MIKMIDINoteEvent *event = [MIKMIDINoteEvent noteEventWithTimeStamp:startingLength+127 note:60 velocity:127 duration:1 channel:0];
		[self.defaultTrack addEvent:event];
		XCTAssertGreaterThanOrEqual(self.defaultTrack.length, event.timeStamp, @"Setting length failed.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"length", @"Setting length did not produce a KVO notification.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"length"];
}

- (void)testDoesLoopKVO
{
	self.defaultTrack.loopDuration = 0;
	XCTAssertFalse(self.defaultTrack.doesLoop, @"Setting loop duration to zero did not make doesLoop NO.");
	[self.defaultTrack addObserver:self forKeyPath:@"doesLoop" options:0 context:NULL];
	{
		self.defaultTrack.loopDuration = 42;
		XCTAssertEqual(self.defaultTrack.loopDuration, 42, @"Setting loopDuration failed.");
		XCTAssert(self.defaultTrack.doesLoop, @"Setting loop duration did not change doesLoop to YES.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"doesLoop", @"Setting loopDuration did not produce a KVO notification for doesLoop.");
		
		self.receivedKVONotificationKeyPath = nil;
		
		MusicTrackLoopInfo info = {
			.loopDuration = 0,
			.numberOfLoops = 1,
		};
		self.defaultTrack.loopInfo = info;
		XCTAssertEqual(self.defaultTrack.loopDuration, 0, @"Setting loopDuration via loop info failed.");
		XCTAssertFalse(self.defaultTrack.doesLoop, @"Clearing loop duration via loop info did not change doesLoop to NO.");
		XCTAssertEqualObjects(self.receivedKVONotificationKeyPath, @"doesLoop", @"Setting loop info did not produce a KVO notification for doesLoop.");
	}
	[self.defaultTrack removeObserver:self forKeyPath:@"doesLoop"];
}

#pragma mark - (KVO Test Helper)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (![object isKindOfClass:[MIKMIDITrack class]]) return;
	
	if ([keyPath isEqualToString:@"events"]) {
		self.eventsChangeNotificationReceived = YES;
		return;
	}
	
	if ([keyPath isEqualToString:@"notes"]) {
		self.notesChangeNotificationReceived = YES;
		return;
	}
	
	self.receivedKVONotificationKeyPath = keyPath;
}

@end


#pragma clang diagnostic pop