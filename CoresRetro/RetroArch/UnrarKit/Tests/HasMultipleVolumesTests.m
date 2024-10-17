//
//  HasMultipleVolumesTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 2/9/17.
//
//

#import "URKArchiveTestCase.h"

@interface HasMultipleVolumesTests : URKArchiveTestCase

@end

@implementation HasMultipleVolumesTests

- (void)testSingleVolume {
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL hasMultipleParts = archive.hasMultipleVolumes;
    
    XCTAssertFalse(hasMultipleParts, @"Single-volume archive reported to have multiple parts");
}

#if !TARGET_OS_IPHONE
- (void)testMultipleVolume_UseFirstVolume {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"HasMultipleVolumesTests-testMultipleVolume_UseFirstVolume.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs.firstObject error:nil];
    
    BOOL hasMultipleParts = archive.hasMultipleVolumes;
    XCTAssertTrue(hasMultipleParts, @"Multi-volume archive's first part not reported to have multiple volumes");
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultipleVolume_UseMiddleVolume {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveWithName:@"HasMultipleVolumesTests-testMultipleVolume_UseMiddleVolume.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs[2] error:nil];
    
    BOOL hasMultipleParts = archive.hasMultipleVolumes;
    XCTAssertTrue(hasMultipleParts, @"Multi-volume archive's middle part not reported to have multiple volumes");
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultipleVolume_UseFirstVolume_OldNamingScheme {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveOldSchemeWithName:@"HasMultipleVolumesTests-testMultipleVolume_UseFirstVolume_OldNamingScheme.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs.firstObject error:nil];
    
    BOOL hasMultipleParts = archive.hasMultipleVolumes;
    XCTAssertTrue(hasMultipleParts, @"Multi-volume archive's first part not reported to have multiple volumes");
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultipleVolume_UseMiddleVolume_OldNamingScheme {
    NSArray<NSURL*> *volumeURLs = [self multiPartArchiveOldSchemeWithName:@"HasMultipleVolumesTests-testMultipleVolume_UseMiddleVolume_OldNamingScheme.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:volumeURLs[2] error:nil];
    
    BOOL hasMultipleParts = archive.hasMultipleVolumes;
    XCTAssertTrue(hasMultipleParts, @"Multi-volume archive's middle part not reported to have multiple volumes");
}
#endif

- (void)testInvalidArchive {
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test File A.txt"] error:nil];
    
    BOOL hasMultipleParts = archive.hasMultipleVolumes;
    XCTAssertFalse(hasMultipleParts, @"Invalid archive reported to have multiple volumes");
}

@end
