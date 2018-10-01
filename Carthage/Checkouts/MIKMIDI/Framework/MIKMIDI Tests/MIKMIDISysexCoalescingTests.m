//
//  MIKMIDISysexCoalescingTests.m
//  MIKMIDI
//
//  Created by Benjamin Jaeger on 15.06.2017.
//  Copyright © 2017 Mixed In Key. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMIDIDeviceManager ()
@property (nonatomic, strong) MIKMIDIInputPort *inputPort;
@end

@interface MIKMIDIInputPort ()
- (void)interpretPacketList:(const MIDIPacketList *)pktList handleResultingCommands:(void (^_Nonnull)(NSArray <MIKMIDICommand*> *receivedCommands))completionBlock;
- (BOOL)coalesceSysexFromMIDIPacket:(const MIDIPacket *)packet toCommandInArray:(NSMutableArray **)commandsArray;
@end

@interface MIKMIDISysexCoalescingTests : XCTestCase
@property (strong) MIKMIDIInputPort *debugInputPort;
@property (strong) NSData *validSysexData;
@end

@implementation MIKMIDISysexCoalescingTests

- (void)setUp
{
	[super setUp];
	_debugInputPort = [MIKMIDIDeviceManager sharedDeviceManager].inputPort;
	_validSysexData = [NSData dataWithBytes:"\xF0\x41\x30\x00\x60\x00\x00\x00\x00\x00\x7f\x00\x00\x00\x00\x7f\x00\x00\x00\x00\x00\x2a\x1d\xF7" length:24];
}

- (void)tearDown
{
	[super tearDown];
	_debugInputPort = nil;
	_validSysexData = nil;
}

#pragma mark - Helpers

- (MIDIPacket)packetWithData:(NSData *)byteArray
{
	NSParameterAssert(byteArray.length < 256);
	
	MIDIPacket packet = {0};
	packet.timeStamp = mach_absolute_time();
	packet.length = byteArray.length;
	
	Byte *bytes = (Byte *)byteArray.bytes;
	for (NSUInteger i=0; i<byteArray.length; i++) {
		packet.data[i] = bytes[i];
	}
	
	return packet;
}

#pragma mark - Tests

- (void)testReadingSinglePacketSysex
{
	NSMutableArray <MIKMIDICommand*> *cmdArray = [NSMutableArray new];
	
	MIDIPacket testPacket = [self packetWithData:_validSysexData];
	
	[_debugInputPort coalesceSysexFromMIDIPacket:&testPacket toCommandInArray:&cmdArray];
	
	XCTAssert([_validSysexData isEqualToData:cmdArray.firstObject.data], @"Single-packet sysex message failed coalescing properly");
}
		
- (void)testReadingChunkedSysex
{
	NSMutableArray <MIKMIDICommand*> *cmdArray = [NSMutableArray new];
	
	// Split into 6 chunks
	for (NSUInteger i=0; i<6; i++) {
		MIDIPacket chunk = [self packetWithData:[_validSysexData subdataWithRange:NSMakeRange(i*4, 4)]];
		[_debugInputPort coalesceSysexFromMIDIPacket:&chunk toCommandInArray:&cmdArray];
	}
	
	XCTAssert([_validSysexData isEqualToData:cmdArray.firstObject.data], @"Chunked sysex message failed coalescing properly");
}

- (void)testReadingNonTerminatedSysexFollowedByCommand
{
	NSMutableArray <MIKMIDICommand*> *cmdArray = [NSMutableArray new];
	
	// Simulate non terminated sysex packet
	NSRange rangeBeforeEOT = NSMakeRange(0, _validSysexData.length - 1);
	MIDIPacket testPacket = [self packetWithData:[_validSysexData subdataWithRange:rangeBeforeEOT]];
	
	[_debugInputPort coalesceSysexFromMIDIPacket:&testPacket toCommandInArray:&cmdArray];
	
	// Simulate following note-on command
	MIDIPacket noteOnPacket = [self packetWithData:[MIKMIDINoteOnCommand noteOnCommandWithNote:0 velocity:0 channel:0 timestamp:nil].data];
	
	XCTAssertFalse([_debugInputPort coalesceSysexFromMIDIPacket:&noteOnPacket toCommandInArray:&cmdArray], @"Sysex coalescing should have failed because of an invalid start byte in noteOnPacket");
	XCTAssert([_validSysexData isEqualToData:cmdArray.firstObject.data], @"Sysex coalescing should have ended because of an invalid start byte in noteOnPacket");
}

- (void)testReadingNonTerminatedSysexUntilTimeout
{
	XCTestExpectation *expectation = [self expectationWithDescription:@"Non 0xF7 terminated sysex message is received after time-out."];
	
	// Simulate non terminated sysex packet
	NSRange rangeBeforeEOT = NSMakeRange(0, _validSysexData.length - 1);
	MIDIPacket testPacket = [self packetWithData:[_validSysexData subdataWithRange:rangeBeforeEOT]];
	
	MIDIPacketList pktList = {0};
	pktList.numPackets = 1;
	pktList.packet[0] = testPacket;
	
	[_debugInputPort interpretPacketList:&pktList handleResultingCommands:^(NSArray<MIKMIDICommand *> *receivedCommands) {
		XCTAssert([_validSysexData isEqualToData:receivedCommands.firstObject.data], @"Coalescing of non-terminated sysex message should have ended after time-out");
		[expectation fulfill];
	}];
				  
	[self waitForExpectationsWithTimeout:(_debugInputPort.sysexTimeOut + 0.1) handler:^(NSError * _Nullable error) {
		if (error) {
		  NSLog(@"Error: %@", error);
		}
	}];
}

@end
