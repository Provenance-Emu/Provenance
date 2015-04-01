//
//  PVGameImporterTests.m
//  Provenance
//
//  Created by James Addyman on 01/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "PVGameImporter.h"

@interface PVGameImporter ()

// expose for testing
- (NSDictionary *)updateSystemToPathMap;
- (NSDictionary *)updateRomToSystemMap;
- (NSString *)documentsDirectoryPath;
- (NSString *)pathForSystemID:(NSString *)systemID;
- (NSArray *)systemIDsForRomAtPath:(NSString *)path;

@end

@interface PVGameImporterTests : XCTestCase

@end

@implementation PVGameImporterTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testRomToSystemMap {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    NSArray *systemIDs = [importer systemIDsForRomAtPath:@"fakerom.bin"];
    XCTAssertTrue(([systemIDs containsObject:@"com.provenance.genesis"] && [systemIDs containsObject:@"com.provenance.segacd"]), @"System IDs should include GBC, but does not.");
}

- (void)testSystemToPathMap {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    NSString *path = [importer pathForSystemID:@"com.provenance.gbc"];
    XCTAssertTrue(([path isEqualToString:[NSString stringWithFormat:@"%@/com.provenance.gbc", [importer documentsDirectoryPath]]]), @"Path should be documents/com.provenance.gbc, but it is not.");
}

- (void)testPerformanceUpdateSystemToPathMap {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    [self measureBlock:^{
        [importer updateSystemToPathMap];
    }];
}

- (void)testPerformanceUpdateRomToSystemMap {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    [self measureBlock:^{
        [importer updateRomToSystemMap];
    }];
}

@end
