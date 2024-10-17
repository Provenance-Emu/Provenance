//
//  ListVolumesTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 12/9/16.
//
//

#import "URKArchiveTestCase.h"

@interface ListVolumesTests : URKArchiveTestCase

@end

@implementation ListVolumesTests

- (void)testSingleVolume {
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *listVolumesError = nil;
    NSArray<NSURL*> *volumeURLs = [archive listVolumeURLs:&listVolumesError];
    
    XCTAssertNil(listVolumesError, @"Error listing volume URLs");
    XCTAssertNotNil(volumeURLs, @"No URLs returned");
    XCTAssertEqual(volumeURLs.count, 1, @"Wrong number of volume URLs listed");
    
    XCTAssertEqualObjects(volumeURLs[0].lastPathComponent, testArchiveURL.path.lastPathComponent,
                          @"Wrong URL returned");
}

- (void)testSingleVolume_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *listVolumesError = nil;
    NSArray<NSURL*> *volumeURLs = [archive listVolumeURLs:&listVolumesError];
    
    XCTAssertNotNil(listVolumesError, @"Error listing volume URLs");
    XCTAssertNil(volumeURLs, @"No URLs returned");
    
}

- (void)testSingleVolume_ModifiedCRC_IgnoringMismatch {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    archive.ignoreCRCMismatches = YES;

    NSError *listVolumesError = nil;
    NSArray<NSURL*> *volumeURLs = [archive listVolumeURLs:&listVolumesError];
    
    XCTAssertNil(listVolumesError, @"Error listing volume URLs");
    XCTAssertNotNil(volumeURLs, @"No URLs returned");
    XCTAssertEqual(volumeURLs.count, 1, @"Wrong number of volume URLs listed");
    
    XCTAssertEqualObjects(volumeURLs[0].lastPathComponent, testArchiveURL.path.lastPathComponent,
                          @"Wrong URL returned");
}

#if !TARGET_OS_IPHONE
- (void)testMultipleVolume_UseFirstVolume {
    NSArray<NSURL*> *generatedVolumeURLs = [self multiPartArchiveWithName:@"ListVolumesTests-testMultipleVolume_UseFirstVolume.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:generatedVolumeURLs.firstObject error:nil];
    
    NSMutableArray<NSURL *> *expectedVolumeURLs = [NSMutableArray array];
    
    // NSTemporaryDirectory() returns '/var', which maps to '/private/var'
    for (NSURL *volumeURL in generatedVolumeURLs) {
        NSString *originalPath = volumeURL.path;
        NSString *privatePath = [@"/private" stringByAppendingString:originalPath];
        [expectedVolumeURLs addObject:[NSURL fileURLWithPath:privatePath]];
    }
    
    NSError *listVolumesError = nil;
    NSArray<NSURL*> *volumeURLs = [archive listVolumeURLs:&listVolumesError];
    
    XCTAssertNil(listVolumesError, @"Error listing volume URLs");
    XCTAssertNotNil(volumeURLs, @"No URLs returned");
    XCTAssertEqual(volumeURLs.count, 5, @"Wrong number of volume URLs listed");
    XCTAssertTrue([expectedVolumeURLs isEqualToArray:volumeURLs],
                  @"Expected these URL:\n%@\n\nGot these:\n%@", expectedVolumeURLs, volumeURLs);
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultipleVolume_UseMiddleVolume {
    NSArray<NSURL*> *generatedVolumeURLs = [self multiPartArchiveWithName:@"ListVolumesTests-testMultipleVolume_UseMiddleVolume.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:generatedVolumeURLs[2] error:nil];
    
    NSMutableArray<NSURL *> *expectedVolumeURLs = [NSMutableArray array];
    
    // NSTemporaryDirectory() returns '/var', which maps to '/private/var'
    for (NSURL *volumeURL in generatedVolumeURLs) {
        NSString *originalPath = volumeURL.path;
        NSString *privatePath = [@"/private" stringByAppendingString:originalPath];
        [expectedVolumeURLs addObject:[NSURL fileURLWithPath:privatePath]];
    }
    
    NSError *listVolumesError = nil;
    NSArray<NSURL*> *volumeURLs = [archive listVolumeURLs:&listVolumesError];
    
    XCTAssertNil(listVolumesError, @"Error listing volume URLs");
    XCTAssertNotNil(volumeURLs, @"No URLs returned");
    XCTAssertEqual(volumeURLs.count, 5, @"Wrong number of volume URLs listed");
    XCTAssertTrue([expectedVolumeURLs isEqualToArray:volumeURLs],
                  @"Expected these URL:\n%@\n\nGot these:\n%@", expectedVolumeURLs, volumeURLs);
}
#endif

@end
