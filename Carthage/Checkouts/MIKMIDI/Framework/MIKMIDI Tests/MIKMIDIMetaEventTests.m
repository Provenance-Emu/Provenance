//
//  MIKMIDIMetaEventTests.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 4/21/16.
//  Copyright © 2016 Mixed In Key. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>
#import <MIKMIDI/MIKMIDIEvent_SubclassMethods.h>
#import <MIKMIDI/MIKMIDIMetaEvent_SubclassMethods.h>

@interface MIKMIDIMetaEventTests : XCTestCase

@end

@implementation MIKMIDIMetaEventTests

- (void)testMetaEventInit
{
	NSString *text = @"Mixed In Key";
	MIKMIDIMetaTextEvent *textEvent =
	(MIKMIDIMetaTextEvent *)[[MIKMIDIMetaEvent alloc] initWithMetaData:[text dataUsingEncoding:NSUTF8StringEncoding]
														  metadataType:MIKMIDIMetaEventTypeTextEvent
															 timeStamp:10];
	XCTAssertTrue([textEvent isMemberOfClass:[MIKMIDIMetaTextEvent class]], @"MIKMIDIMetaEvent initializer didn't produce expected subclass (MIKMIDIMetaTextEvent)");
	XCTAssertEqualObjects(textEvent.string, text, @"MIKMIDIMetaTextEvent didn't have expected string value.");
	XCTAssertEqual(textEvent.metadataType, MIKMIDIMetaEventTypeTextEvent, "MIKMIDIMetaTextEvent didn't have expected metadataType.");
	XCTAssertEqual(textEvent.timeStamp, 10, "MIKMIDIMetaTextEvent didn't have expected timeStamp.");
	
	MIKMutableMIDIMetaTimeSignatureEvent *timeSignatureEvent = (MIKMutableMIDIMetaTimeSignatureEvent *)[[MIKMutableMIDIMetaEvent alloc] initWithTimeStamp:26 midiEventType:MIKMIDIEventTypeMetaTimeSignature data:nil];
	timeSignatureEvent.numerator = 6;
	timeSignatureEvent.denominator= 8;
	
	XCTAssertTrue([timeSignatureEvent isMemberOfClass:[MIKMutableMIDIMetaTimeSignatureEvent class]], @"MIKMutableMIDIMetaEvent initializer didn't produce expected subclass (MIKMutableMIDIMetaTimeSignatureEvent)");
	XCTAssertEqual(timeSignatureEvent.numerator, 6, "MIKMIDIMetaTimeSignatureEvent didn't have expected numerator.");
	XCTAssertEqual(timeSignatureEvent.denominator, 8, "MIKMIDIMetaTimeSignatureEvent didn't have expected denominator.");
	XCTAssertEqual(timeSignatureEvent.metronomePulse, 24, "MIKMIDIMetaTimeSignatureEvent didn't have expected metronomePulse.");
	XCTAssertEqual(timeSignatureEvent.thirtySecondsPerQuarterNote, 8, "MIKMIDIMetaTimeSignatureEvent didn't have expected thirtySecondsPerQuarterNote.");
	XCTAssertEqual(timeSignatureEvent.metadataType, MIKMIDIMetaEventTypeTimeSignature, "MIKMIDIMetaTimeSignatureEvent didn't have expected metadataType.");
	XCTAssertEqual(timeSignatureEvent.timeStamp, 26, "MIKMIDIMetaTimeSignatureEvent didn't have expected timeStamp.");
}

- (void)testBareInits
{
	NSArray *classNames = @[
							@"MIKMIDIMetaCuePointEvent",
							@"MIKMIDIMetaLyricEvent",
							@"MIKMIDIMetaTrackSequenceNameEvent",
							@"MIKMIDIMetaTextEvent",
							@"MIKMIDIMetaTimeSignatureEvent",
							@"MIKMIDIMetaEvent",
							@"MIKMIDIMetaMarkerTextEvent",
							@"MIKMIDIMetaInstrumentNameEvent",
							@"MIKMIDIMetaCopyrightEvent",
							@"MIKMIDIMetaKeySignatureEvent",
							];
	for (NSString *className in classNames) {
		Class subclass = NSClassFromString(className);
		Class mutableSubclass = [subclass mutableCounterpartClass];
		XCTAssertFalse([subclass isMutable], "%@ should not be mutable.", NSStringFromClass(subclass));
		XCTAssertTrue([mutableSubclass isMutable], "%@ should be mutable.", NSStringFromClass(mutableSubclass));
		
		MIKMIDIMetaEvent *event = [[subclass alloc] init];
		MIKMutableMIDIMetaEvent *mutableEvent = [[mutableSubclass alloc] init];
		XCTAssertTrue([event isMemberOfClass:subclass], "-[[%@ alloc] init] did not produce instance of expected class (%@)", NSStringFromClass(subclass), NSStringFromClass([event class]));
		XCTAssertTrue([mutableEvent isMemberOfClass:mutableSubclass], "-[[%@ alloc] init] did not produce instance of expected class (%@)", NSStringFromClass(mutableSubclass), NSStringFromClass([mutableEvent class]));
		
		MIKMIDIEventType eventType = [[[subclass supportedMIDIEventTypes] firstObject] unsignedIntegerValue];
		XCTAssertEqual(event.eventType, eventType, "-[[%@ alloc] init] did not produce instance with expected event type (%@)", NSStringFromClass(subclass), @(eventType));
		XCTAssertEqual(mutableEvent.eventType, eventType, "-[[%@ alloc] init] did not produce instance with expected event type (%@)", NSStringFromClass(mutableSubclass), @(eventType));

		// FIXME: See Issue #151
		MIKMIDIMetaEventType metadataType = [MIKMIDIMetaEvent metaSubtypeForEventType:eventType];
		XCTAssertEqual(event.metadataType, metadataType, "-[[%@ alloc] init] did not produce instance with expected metadata type (%@)", NSStringFromClass(subclass), @(metadataType));
		XCTAssertEqual(mutableEvent.metadataType, metadataType, "-[[%@ alloc] init] did not produce instance with expected metadata type (%@)", NSStringFromClass(mutableSubclass), @(metadataType));
	}
	
}

- (void)testMetaTextEventInit
{
	NSString *text = @"Mixed In Key";
	MIKMIDIMetaTextEvent *event = [[MIKMIDIMetaTextEvent alloc] initWithString:text timeStamp:27];
	XCTAssertTrue([event isMemberOfClass:[MIKMIDIMetaTextEvent class]], @"MIKMIDIMetaTextEvent initializer didn't produce expected subclass (MIKMIDIMetaTextEvent)");
	XCTAssertEqualObjects(event.string, text, @"MIKMIDIMetaTextEvent didn't have expected string value.");
	XCTAssertEqual(event.metadataType, MIKMIDIMetaEventTypeTextEvent, "MIKMIDIMetaTextEvent didn't have expected metadataType.");
	XCTAssertEqual(event.timeStamp, 27, "MIKMIDIMetaTextEvent didn't have expected timeStamp.");
}

- (void)testMetaTrackSequenceNameEventInit
{
	NSString *name = @"Have You Heard?";
	MIKMIDIMetaTrackSequenceNameEvent *event =
	[[MIKMIDIMetaTrackSequenceNameEvent alloc] initWithName:name timeStamp:42];
	
	XCTAssertTrue([event isMemberOfClass:[MIKMIDIMetaTrackSequenceNameEvent class]], @"MIKMIDIMetaTrackSequenceNameEvent initializer didn't produce expected subclass (MIKMIDIMetaTrackSequenceNameEvent)");
	XCTAssertEqualObjects(event.name, name, @"MIKMIDIMetaTrackSequenceNameEvent didn't have expected string value.");
	XCTAssertEqual(event.metadataType, MIKMIDIMetaEventTypeTrackSequenceName, "MIKMIDIMetaTrackSequenceNameEvent didn't have expected metadataType.");
	XCTAssertEqual(event.timeStamp, 42, "MIKMIDIMetaTrackSequenceNameEvent didn't have expected timeStamp.");
}

- (void)testMetaTimeSignatureEventInit
{
	MIKMIDIMetaTimeSignatureEvent *event =
	[[MIKMIDIMetaTimeSignatureEvent alloc] initWithNumerator:9 denominator:8 timeStamp:63];
	
	XCTAssertTrue([event isMemberOfClass:[MIKMIDIMetaTimeSignatureEvent class]], @"MIKMIDIMetaTimeSignatureEvent initializer didn't produce expected subclass (MIKMIDIMetaTimeSignatureEvent)");
	XCTAssertEqual(event.numerator, 9, "MIKMIDIMetaTimeSignatureEvent didn't have expected numerator.");
	XCTAssertEqual(event.denominator, 8, "MIKMIDIMetaTimeSignatureEvent didn't have expected denominator.");
	XCTAssertEqual(event.metronomePulse, 24, "MIKMIDIMetaTimeSignatureEvent didn't have expected metronomePulse.");
	XCTAssertEqual(event.thirtySecondsPerQuarterNote, 8, "MIKMIDIMetaTimeSignatureEvent didn't have expected thirtySecondsPerQuarterNote.");
	XCTAssertEqual(event.metadataType, MIKMIDIMetaEventTypeTimeSignature, "MIKMIDIMetaTimeSignatureEvent didn't have expected metadataType.");
	XCTAssertEqual(event.timeStamp, 63, "MIKMIDIMetaTimeSignatureEvent didn't have expected timeStamp.");
	
	MIKMIDIMetaTimeSignatureEvent *event2 =
	[[MIKMIDIMetaTimeSignatureEvent alloc] initWithTimeSignature:MIKMIDITimeSignatureMake(3, 4) timeStamp:127];
	
	XCTAssertTrue([event2 isMemberOfClass:[MIKMIDIMetaTimeSignatureEvent class]], @"MIKMIDIMetaTimeSignatureEvent initializer didn't produce expected subclass (MIKMIDIMetaTimeSignatureEvent)");
	XCTAssertEqual(event2.numerator, 3, "MIKMIDIMetaTimeSignatureEvent didn't have expected numerator.");
	XCTAssertEqual(event2.denominator, 4, "MIKMIDIMetaTimeSignatureEvent didn't have expected denominator.");
	XCTAssertEqual(event2.metronomePulse, 24, "MIKMIDIMetaTimeSignatureEvent didn't have expected metronomePulse.");
	XCTAssertEqual(event2.thirtySecondsPerQuarterNote, 8, "MIKMIDIMetaTimeSignatureEvent didn't have expected thirtySecondsPerQuarterNote.");
	XCTAssertEqual(event2.metadataType, MIKMIDIMetaEventTypeTimeSignature, "MIKMIDIMetaTimeSignatureEvent didn't have expected metadataType.");
	XCTAssertEqual(event2.timeStamp, 127, "MIKMIDIMetaTimeSignatureEvent didn't have expected timeStamp.");
}

- (void)testMetaKeySignatureEventInit
{
	MIKMIDIMetaKeySignatureEvent *event =
	[[MIKMIDIMetaKeySignatureEvent alloc] initWithMusicalKey:MIKMIDIMusicalKeyFMinor timeStamp:127];
	
	XCTAssertTrue([event isMemberOfClass:[MIKMIDIMetaKeySignatureEvent class]], @"MIKMIDIMetaKeySignatureEvent initializer didn't produce expected subclass (MIKMIDIMetaKeySignatureEvent)");
	XCTAssertEqual(event.numberOfFlatsAndSharps, -4, "MIKMIDIMetaKeySignatureEvent didn't have expected numerator.");
	XCTAssertEqual(event.scale, MIKMIDIMusicalScaleMinor, "MIKMIDIMetaKeySignatureEvent didn't have expected denominator.");
	XCTAssertEqual(event.metadataType, MIKMIDIMetaEventTypeKeySignature, "MIKMIDIMetaKeySignatureEvent didn't have expected metadataType.");
	XCTAssertEqual(event.timeStamp, 127, "MIKMIDIMetaKeySignatureEvent didn't have expected timeStamp.");
}

@end
