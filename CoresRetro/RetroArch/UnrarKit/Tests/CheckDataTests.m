//
//  CheckDataTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 10/6/17.
//

#import "URKArchiveTestCase.h"

@interface CheckDataTests : URKArchiveTestCase @end

@implementation CheckDataTests

#pragma mark - checkDataIntegrity

- (void)testCheckDataIntegrity {
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing data integrity of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        BOOL success = [archive checkDataIntegrity];
        XCTAssertTrue(success, @"Data integrity check failed for %@", testArchiveName);
    }
}

- (void)testCheckDataIntegrity_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrity];
    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
}

- (void)testCheckDataIntegrity_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrity];
    XCTAssertFalse(success, @"Data integrity check passed for archive with a modified CRC");
}

- (void)testCheckDataIntegrity_ModifiedCRC_IgnoringMismatches {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    archive.ignoreCRCMismatches = YES;
    
    // Still expect failure, so a consumer can still tell that data is mismatched
    BOOL success = [archive checkDataIntegrity];
    XCTAssertFalse(success, @"Data integrity check passed for archive with a modified CRC");
}

#pragma mark - checkDataIntegrityOfFile

- (void)testCheckDataIntegrityForFile {
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing data integrity of file in archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        NSError *listFilenamesError = nil;
        NSArray <NSString*> *filenames = [archive listFilenames:&listFilenamesError];
        
        XCTAssertNotNil(filenames, @"No file info returned for %@", testArchiveName);
        XCTAssertNil(listFilenamesError, @"Error returned for %@: %@", testArchiveName, listFilenamesError);
        
        NSString *firstFilename = filenames.firstObject;
        BOOL success = [archive checkDataIntegrityOfFile:firstFilename];
        
        XCTAssertTrue(success, @"Data integrity check failed for %@ in %@", firstFilename, testArchiveName);
    }
}

- (void)testCheckDataIntegrityForFile_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrityOfFile:@"README.md"];
    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
}

- (void)testCheckDataIntegrityForFile_ModifiedCRC {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    BOOL success = [archive checkDataIntegrityOfFile:@"README.md"];
    XCTAssertFalse(success, @"Data integrity check passed for archive with modified CRC");
}

- (void)testCheckDataIntegrityForFile_ModifiedCRC_IgnoringMismatches {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    archive.ignoreCRCMismatches = YES;
    
    // Still expect failure, so a consumer can still tell that data is mismatched
    BOOL success = [archive checkDataIntegrityOfFile:@"README.md"];
    XCTAssertFalse(success, @"Data integrity check passed for archive with modified CRC");
}

- (void)testCheckDataIntegrityIgnoringCRCMismatches {
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing data integrity of file in archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        __block BOOL blockInvoked = NO;
        BOOL success = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
            blockInvoked = YES;
            return NO;
        }];
        
        XCTAssertTrue(success, @"Data integrity check failed for %@", testArchiveName);
        XCTAssertFalse(blockInvoked, @"Block prompting whether to ignore CRC mismatches should not have been called");
        XCTAssertFalse(archive.ignoreCRCMismatches);
    }
}

- (void)testCheckDataIntegrityIgnoringCRCMismatches_InBackground {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    __block BOOL blockInvoked = NO;
    __block NSThread *blockThread = nil;
    
    XCTestExpectation *exp = [self expectationWithDescription:@"data check block invoked"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
            blockInvoked = YES;
            blockThread = [NSThread currentThread];
            return YES;
        }];
        
        XCTAssertTrue(success, @"Data integrity check failed for archive with modified CRC, when instructed to ignore");
        [exp fulfill];
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    XCTAssertTrue(blockInvoked, @"Block prompting whether to ignore CRC mismatches should have been called");
    XCTAssertEqualObjects(blockThread, [NSThread mainThread]);
    XCTAssertTrue(archive.ignoreCRCMismatches);
}

- (void)testCheckDataIntegrityIgnoringCRCMismatches_NotAnArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File B.jpg"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    __block BOOL blockInvoked = NO;
    BOOL success = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
        blockInvoked = YES;
        return NO;
    }];
    
    XCTAssertFalse(success, @"Data integrity check passed for non-archive");
    XCTAssertFalse(blockInvoked, @"Block prompting whether to ignore CRC mismatches should not have been called");
    XCTAssertFalse(archive.ignoreCRCMismatches);
}

- (void)testCheckDataIntegrityIgnoringCRCMismatches_ModifiedCRC_Ignore {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    __block BOOL blockInvoked = NO;
    BOOL success = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
        blockInvoked = YES;
        return YES;
    }];
    
    XCTAssertTrue(success, @"Data integrity check failed for archive with modified CRC, when instructed to ignore");
    XCTAssertTrue(blockInvoked, @"Block prompting whether to ignore CRC mismatches should have been called");
    XCTAssertTrue(archive.ignoreCRCMismatches);
}

- (void)testCheckDataIntegrityIgnoringCRCMismatches_ModifiedCRC_DontIgnore {
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    __block BOOL blockInvoked = NO;
    BOOL success = [archive checkDataIntegrityIgnoringCRCMismatches:^BOOL{
        blockInvoked = YES;
        return NO;
    }];
    
    XCTAssertFalse(success, @"Data integrity check passed for archive with modified CRC");
    XCTAssertTrue(blockInvoked, @"Block prompting whether to ignore CRC mismatches should have been called");
    XCTAssertFalse(archive.ignoreCRCMismatches);
}

@end
