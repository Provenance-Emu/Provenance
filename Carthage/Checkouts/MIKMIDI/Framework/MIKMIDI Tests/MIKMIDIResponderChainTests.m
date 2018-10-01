//
//  MIKMIDIResponderChainTests.m
//  MIKMIDI
//
//  Created by Andrew Madsen on 5/7/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <MIKMIDI/MIKMIDI.h>

@interface MIKMIDIDummyResponder : NSObject <MIKMIDIResponder>

- (instancetype)initWithMIDIIdentifier:(NSString *)identifier subresponders:(NSArray *)subresponders;

@property (nonatomic, strong, readonly) NSString *MIDIIdentifier;
@property (nonatomic, strong, readonly) NSArray *subresponders;

@end

@implementation MIKMIDIDummyResponder

- (instancetype)initWithMIDIIdentifier:(NSString *)identifier subresponders:(NSArray *)subresponders;
{
	self = [super init];
	if (self) {
		_MIDIIdentifier = identifier;
		_subresponders = subresponders;
	}
	return self;
}

- (BOOL)respondsToMIDICommand:(MIKMIDICommand *)command { return NO; }
- (void)handleMIDICommand:(MIKMIDICommand *)command { }

@end

@interface MIKMIDIResponderChainTests : XCTestCase

@property (nonatomic, strong) MIKMIDIDummyResponder *dummyResponder;

@end

@implementation MIKMIDIResponderChainTests

- (void)setUp
{
    [super setUp];
	
	MIKMIDIDummyResponder *sub1 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub1" subresponders:nil];
	
	MIKMIDIDummyResponder *sub2sub1 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub2Sub1" subresponders:nil];
	MIKMIDIDummyResponder *sub2sub2 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub2Sub2" subresponders:nil];
	MIKMIDIDummyResponder *sub2sub3sub1 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub2Sub3Sub1" subresponders:nil];
	MIKMIDIDummyResponder *sub2sub3 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub2Sub3" subresponders:@[sub2sub3sub1]];
	MIKMIDIDummyResponder *sub2sub4 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub2Sub4" subresponders:nil];
	MIKMIDIDummyResponder *sub2 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub2" subresponders:@[sub2sub1, sub2sub2, sub2sub3, sub2sub4]];
	
	MIKMIDIDummyResponder *sub3 = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Sub3" subresponders:nil];
	
	self.dummyResponder = [[MIKMIDIDummyResponder alloc] initWithMIDIIdentifier:@"Dummy" subresponders:@[sub1, sub2, sub3]];
}

- (void)testRegistration
{
	NSApplication *app = [NSApplication sharedApplication];
	[app registerMIDIResponder:self.dummyResponder];
	
	XCTAssertNotNil([app MIDIResponderWithIdentifier:@"Dummy"], @"Top level dummy responder not found.");
	XCTAssertNotNil([app MIDIResponderWithIdentifier:@"Sub1"], @"First level dummy subresponder not found.");
	XCTAssertNotNil([app MIDIResponderWithIdentifier:@"Sub2Sub2"], @"First level dummy subresponder not found.");
}

- (void)testUncachedResponderSearchPerformance
{
    NSApplication *app = [NSApplication sharedApplication];
	app.shouldCacheMIKMIDISubresponders = NO;
    [self measureBlock:^{
		for (NSUInteger i=0; i<50000; i++) {
			[app MIDIResponderWithIdentifier:@"Sub2Sub1"];
		}
    }];
}

- (void)testCachedResponderSearchPerformance
{
	NSApplication *app = [NSApplication sharedApplication];
	app.shouldCacheMIKMIDISubresponders = YES;
	[self measureBlock:^{
		for (NSUInteger i=0; i<50000; i++) {
			[app MIDIResponderWithIdentifier:@"Sub2Sub1"];
		}
	}];
}

@end
