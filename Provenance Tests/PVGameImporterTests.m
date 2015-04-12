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
#import "NSData+Hashing.h"


@interface PVGameImporter ()

// expose for testing
- (NSDictionary *)updateSystemToPathMap;
- (NSDictionary *)updateRomToSystemMap;
- (NSString *)romsPath;
- (NSString *)pathForSystemID:(NSString *)systemID;
- (NSArray *)systemIDsForRomAtPath:(NSString *)path;
- (BOOL)isCDROM:(NSString *)filePath;

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

- (void)testIsCDROM {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    BOOL isCDROM = [importer isCDROM:@"game.cue"];
    XCTAssertTrue(isCDROM == YES, @".cue should be a CDROM");
    
    isCDROM = [importer isCDROM:@"game.iso"];
    XCTAssertTrue(isCDROM == YES, @".iso should be a CDROM");
    
    isCDROM = [importer isCDROM:@"game.bin"];
    XCTAssertTrue(isCDROM == NO, @".bin should not be a CDROM");
}

- (void)testRomToSystemMap {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    NSArray *systemIDs = [importer systemIDsForRomAtPath:@"game.bin"];
    XCTAssertTrue(([systemIDs containsObject:@"com.provenance.genesis"]), @"System IDs should include Genesis, but does not.");
}

- (void)testSystemToPathMap {
    PVGameImporter *importer = [[PVGameImporter alloc] init];
    NSString *path = [importer pathForSystemID:@"com.provenance.gbc"];
    XCTAssertTrue(([path isEqualToString:[NSString stringWithFormat:@"%@/com.provenance.gbc", [importer romsPath]]]), @"Path should be documents/com.provenance.gbc, but it is not.");
}

- (void)testPerformanceUpdateSystemToPathMap {
    [self measureBlock:^{
        PVGameImporter *importer = [[PVGameImporter alloc] init];
        [importer updateSystemToPathMap];
    }];
}

- (void)testPerformanceUpdateRomToSystemMap {
    [self measureBlock:^{
        PVGameImporter *importer = [[PVGameImporter alloc] init];
        [importer updateRomToSystemMap];
    }];
}

- (void)testSha1 {
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"testdata" withExtension:@"txt"];
    NSData *data = [NSData dataWithContentsOfURL:fileURL];
    NSString *sha1 = [data sha1Hash];
    XCTAssertTrue([sha1 isEqualToString:@"AAF4C61DDCC5E8A2DABEDE0F3B482CD9AEA9434D"]);
}

@end
