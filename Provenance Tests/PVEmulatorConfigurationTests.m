//
//  PVEmulatorConfigurationTests.m
//  Provenance
//
//  Created by Joseph Mattiello on 4/19/17.
//  Copyright © 2017 James Addyman. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PVEmulatorConfiguration.h"

@interface PVEmulatorConfigurationTests : XCTestCase

@end

@implementation PVEmulatorConfigurationTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testBIOSArrays {
    PVEmulatorConfiguration *config = [PVEmulatorConfiguration sharedInstance];
    XCTAssertNotNil(config);
    
    NSArray<BIOSEntry*>*biosEntries = [config biosEntries];
    XCTAssertEqual(biosEntries.count, 12);
    
    NSArray<BIOSEntry*>*psxBiosEntries = [config biosEntriesForSystemIdentifier:@"com.provenance.psx"];
    XCTAssertEqual(psxBiosEntries.count, 3);

    NSArray<BIOSEntry*>*bioses5200 = [config biosEntriesForSystemIdentifier:@"com.provenance.5200"];
    XCTAssertEqual(bioses5200.count, 1);

    BIOSEntry*bios5200 = bioses5200.firstObject;
    XCTAssertEqualObjects(bios5200.fileName, @"5200.rom");
    XCTAssertEqualObjects(bios5200.desc, @"Atari 5200 BIOS");
    XCTAssertEqualObjects(bios5200.expectedMD5, @"281f20ea4320404ec820fb7ec0693b38");
    XCTAssertEqual(bios5200.expectedFileSize.integerValue, 2048);
    XCTAssertEqualObjects(bios5200.fileName, @"5200.rom");
}

@end
