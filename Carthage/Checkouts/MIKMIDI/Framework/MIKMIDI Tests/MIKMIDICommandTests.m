//
//  MIKMIDICommandTests.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 11/12/15.
//  Copyright © 2015 Mixed In Key. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMIDICommandTests : XCTestCase

@end

@implementation MIKMIDICommandTests

- (void)testPolyphonicKeyPressureCommand
{
	Class immutableClass = [MIKMIDIPolyphonicKeyPressureCommand class];
	Class mutableClass = [MIKMutableMIDIPolyphonicKeyPressureCommand class];
	
	MIKMIDIPolyphonicKeyPressureCommand *command = [[immutableClass alloc] init];
	XCTAssert([command isMemberOfClass:[immutableClass class]], @"[[MIKMIDIPolyphonicKeyPressureCommand alloc] init] did not return an MIKMIDIPolyphonicKeyPressureCommand instance.");
	XCTAssert([[MIKMIDICommand commandForCommandType:MIKMIDICommandTypePolyphonicKeyPressure] isMemberOfClass:[immutableClass class]], @"[MIKMIDICommand commandForCommandType:MIKMIDICommandTypePolyphonicKeyPressure] did not return an MIKMIDIPolyphonicKeyPressureCommand instance.");
	XCTAssert([[command copy] isMemberOfClass:[immutableClass class]], @"[MIKMIDIPolyphonicKeyPressureCommand copy] did not return an MIKMIDIPolyphonicKeyPressureCommand instance.");
	XCTAssertEqual(command.commandType, MIKMIDICommandTypePolyphonicKeyPressure, @"[[MIKMIDIPolyphonicKeyPressureCommand alloc] init] produced a command instance with the wrong command type.");
	
	MIKMutableMIDIPolyphonicKeyPressureCommand *mutableCommand = [command mutableCopy];
	XCTAssert([mutableCommand isMemberOfClass:[mutableClass class]], @"-[MIKMIDIPolyphonicKeyPressureCommand mutableCopy] did not return an mutableClass instance.");
	XCTAssert([[mutableCommand copy] isMemberOfClass:[immutableClass class]], @"-[mutableClass mutableCopy] did not return an MIKMIDIPolyphonicKeyPressureCommand instance.");
	
	XCTAssertThrows([(MIKMutableMIDIPolyphonicKeyPressureCommand *)command setNote:64], @"-[MIKMIDIPolyphonicKeyPressureCommand setNote:] was allowed on immutable instance.");
	XCTAssertThrows([(MIKMutableMIDIPolyphonicKeyPressureCommand *)command setPressure:64], @"-[MIKMIDIPolyphonicKeyPressureCommand setPressure:] was allowed on immutable instance.");
	
	XCTAssertNoThrow([mutableCommand setNote:64], @"-[MIKMIDIPolyphonicKeyPressureCommand setNote:] was not allowed on mutable instance.");
	XCTAssertNoThrow([mutableCommand setPressure:64], @"-[MIKMIDIPolyphonicKeyPressureCommand setNote:] was not allowed on mutable instance.");
	
	mutableCommand.note = 42;
	XCTAssertEqual(mutableCommand.note, 42, @"Setting the note on a MIKMutableMIDIPolyphonicKeyPressureCommand instance failed.");
	mutableCommand.pressure = 27;
	XCTAssertEqual(mutableCommand.pressure, 27, @"Setting the pressure on a MIKMutableMIDIPolyphonicKeyPressureCommand instance failed.");
}

- (void)testChannelPressureCommand
{
	Class immutableClass = [MIKMIDIChannelPressureCommand class];
	Class mutableClass = [MIKMutableMIDIChannelPressureCommand class];
	
	MIKMIDIChannelPressureCommand *command = [[immutableClass alloc] init];
	XCTAssert([command isMemberOfClass:[immutableClass class]], @"[[MIKMIDIChannelPressureCommand alloc] init] did not return an MIKMIDIChannelPressureCommand instance.");
	XCTAssert([[MIKMIDICommand commandForCommandType:MIKMIDICommandTypeChannelPressure] isMemberOfClass:[immutableClass class]], @"[MIKMIDICommand commandForCommandType:MIKMIDICommandTypePolyphonicKeyPressure] did not return an MIKMIDIChannelPressureCommand instance.");
	XCTAssert([[command copy] isMemberOfClass:[immutableClass class]], @"[MIKMIDIChannelPressureCommand copy] did not return an MIKMIDIChannelPressureCommand instance.");
	XCTAssertEqual(command.commandType, MIKMIDICommandTypeChannelPressure, @"[[MIKMIDIChannelPressureCommand alloc] init] produced a command instance with the wrong command type.");
	XCTAssertEqual(command.data.length, 2, "MIKMIDIChannelPressureCommand had an incorrect data length %@ (should be 2)", @(command.data.length));
	
	MIKMutableMIDIChannelPressureCommand *mutableCommand = [command mutableCopy];
	XCTAssert([mutableCommand isMemberOfClass:[mutableClass class]], @"-[MIKMIDIChannelPressureCommand mutableCopy] did not return an mutableClass instance.");
	XCTAssert([[mutableCommand copy] isMemberOfClass:[immutableClass class]], @"-[mutableClass mutableCopy] did not return an MIKMIDIChannelPressureCommand instance.");
	
	XCTAssertThrows([(MIKMutableMIDIChannelPressureCommand *)command setPressure:64], @"-[MIKMIDIChannelPressureCommand setPressure:] was allowed on immutable instance.");
	
	XCTAssertNoThrow([mutableCommand setPressure:64], @"-[MIKMIDIChannelPressureCommand setPressure:] was not allowed on mutable instance.");
	
	mutableCommand.pressure = 27;
	XCTAssertEqual(mutableCommand.pressure, 27, @"Setting the pressure on a MIKMutableMIDIChannelPressureCommand instance failed.");
}

- (void)testKeepAliveCommand
{
	MIDIPacket packet = MIKMIDIPacketCreate(0, 1, @[@0xfe]);
	XCTAssertTrue([[MIKMIDICommand commandWithMIDIPacket:&packet] isKindOfClass:[MIKMIDISystemKeepAliveCommand class]]);
	
	Class immutableClass = [MIKMIDISystemKeepAliveCommand class];
	Class mutableClass = [MIKMutableMIDISystemKeepAliveCommand class];
	
	MIKMIDISystemKeepAliveCommand *command = [[immutableClass alloc] init];
	XCTAssert([command isMemberOfClass:[immutableClass class]], @"[[MIKMIDISystemKeepAliveCommand alloc] init] did not return an MIKMIDISystemKeepAliveCommand instance.");
	XCTAssert([[MIKMIDICommand commandForCommandType:MIKMIDICommandTypeSystemKeepAlive] isMemberOfClass:[immutableClass class]], @"[MIKMIDICommand commandForCommandType:MIKMIDICommandTypeSystemExclusive] did not return an MIKMIDISystemKeepAliveCommand instance.");
	XCTAssert([[command copy] isMemberOfClass:[immutableClass class]], @"[MIKMIDISystemKeepAliveCommand copy] did not return an MIKMIDISystemKeepAliveCommand instance.");
	XCTAssertEqual(command.commandType, MIKMIDICommandTypeSystemKeepAlive, @"[[MIKMIDISystemKeepAliveCommand alloc] init] produced a command instance with the wrong command type.");
	XCTAssertEqual(command.data.length, 1, "MIKMIDISystemKeepAliveCommand had an incorrect data length %@ (should be 1)", @(command.data.length));
	
	MIKMutableMIDISystemKeepAliveCommand *mutableCommand = [command mutableCopy];
	XCTAssert([mutableCommand isMemberOfClass:[mutableClass class]], @"-[MIKMIDISystemKeepAliveCommand mutableCopy] did not return an mutableClass instance.");
	XCTAssert([[mutableCommand copy] isMemberOfClass:[immutableClass class]], @"-[mutableClass mutableCopy] did not return an MIKMIDISystemKeepAliveCommand instance.");	
}

- (void)testSystemExclusiveCommand
{
	Class immutableClass = [MIKMIDISystemExclusiveCommand class];
	Class mutableClass = [MIKMutableMIDISystemExclusiveCommand class];
	
	MIKMIDISystemExclusiveCommand *command = [[immutableClass alloc] init];
	XCTAssert([command isMemberOfClass:[immutableClass class]], @"[[MIKMIDISystemExclusiveCommand alloc] init] did not return an MIKMIDISystemExclusiveCommand instance.");
	XCTAssert([[MIKMIDICommand commandForCommandType:MIKMIDICommandTypeSystemExclusive] isMemberOfClass:[immutableClass class]], @"[MIKMIDICommand commandForCommandType:MIKMIDICommandTypeSystemExclusive] did not return an MIKMIDISystemExclusiveCommand instance.");
	XCTAssert([[command copy] isMemberOfClass:[immutableClass class]], @"[MIKMIDISystemExclusiveCommand copy] did not return an MIKMIDISystemExclusiveCommand instance.");
	XCTAssertEqual(command.commandType, MIKMIDICommandTypeSystemExclusive, @"[[MIKMIDISystemExclusiveCommand alloc] init] produced a command instance with the wrong command type.");
	XCTAssertEqual(command.data.length, 4, "MIKMIDISystemExclusiveCommand had an incorrect data length %@ (should be 4)", @(command.data.length));

	MIKMutableMIDISystemExclusiveCommand *mutableCommand = [command mutableCopy];
	XCTAssert([mutableCommand isMemberOfClass:[mutableClass class]], @"-[MIKMIDISystemExclusiveCommand mutableCopy] did not return an mutableClass instance.");
	XCTAssert([[mutableCommand copy] isMemberOfClass:[immutableClass class]], @"-[mutableClass mutableCopy] did not return an MIKMIDISystemExclusiveCommand instance.");
	
	XCTAssertThrows([(MIKMutableMIDISystemExclusiveCommand *)command setSysexData:[NSData data]], @"-[MIKMIDISystemExclusiveCommand setSysexData:] was allowed on immutable instance.");
	XCTAssertThrows([(MIKMutableMIDISystemExclusiveCommand *)command setSysexChannel:10], @"-[MIKMIDISystemExclusiveCommand setSysexChannel:] was allowed on immutable instance.");
	
	XCTAssertNoThrow([mutableCommand setSysexData:[NSData data]], @"-[MIKMIDISystemExclusiveCommand setSysexData:] was not allowed on mutable instance.");
	XCTAssertNoThrow([mutableCommand setSysexChannel:10], @"-[MIKMIDISystemExclusiveCommand setSysexChannel:] was not allowed on mutable instance.");
	
	mutableCommand.sysexChannel = 27;
	XCTAssertEqual(mutableCommand.sysexChannel, 27, @"Setting the sysexChannel on a MIKMutableMIDISystemExclusiveCommand instance failed.");
}

- (void)testManufacturerSpecificSystemExclusiveCommand
{
	MIKMutableMIDISystemExclusiveCommand *command = [[MIKMutableMIDISystemExclusiveCommand alloc] init];
	command.manufacturerID = 0x41; // Roland
	XCTAssertEqual(command.manufacturerID, 0x41, @"Setting the manufacturerID on a MIKMutableMIDISystemExclusiveCommand instance failed.");
	
	XCTAssertEqual(command.sysexChannel, 0, @"Sysex channel for a manufacturer specific sysex command should be 0");
	
	command.manufacturerID = 0x002076;
	XCTAssertEqual(command.manufacturerID, 0x002076, @"Setting a 3-byte manufacturerID on a MIKMutableMIDISystemExclusiveCommand instance failed.");
}

- (void)testMultipleCommandTypesInOnePacket
{
	MIKMIDINoteOnCommand *noteOn = [MIKMIDINoteOnCommand noteOnCommandWithNote:60 velocity:64 channel:0 timestamp:nil];
	MIKMutableMIDIControlChangeCommand *cc = [MIKMutableMIDIControlChangeCommand controlChangeCommandWithControllerNumber:27 value:63];
	cc.midiTimestamp = noteOn.midiTimestamp; // Messages in a MIDIPacket all have the same timestamp.
	NSArray *commands = @[noteOn, cc];
	
	MIDIPacket *packet = MIKMIDIPacketCreateFromCommands(cc.midiTimestamp, commands);
	NSArray *parsedCommands = [MIKMIDICommand commandsWithMIDIPacket:packet];
	XCTAssertEqualObjects(commands, parsedCommands, @"Parsing multiple commands from MIDI packet failed to produce original commands.");
	
	MIKMIDIPacketFree(packet);
}

@end
