//
//  IterateFileInfoTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 5/22/18.
//
//

#import "URKArchiveTestCase.h"

@interface IterateFileInfoTests : URKArchiveTestCase

@end

@implementation IterateFileInfoTests


- (void)testIterateFileInfo
{
    NSArray *testArchives = @[@"Test Archive.rar", @"Test Archive (Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing list files of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
        
        NSError *error = nil;
        NSMutableArray *iteratedFiles = [NSMutableArray array];
        BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
            [iteratedFiles addObject:fileInfo.filename];
        }
                                          error:&error];
        
        XCTAssertTrue(success, @"Error returned by iterateFileInfo");
        XCTAssertNil(error, @"Error returned by iterateFileInfo");
        XCTAssertEqual(iteratedFiles.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < iteratedFiles.count; i++) {
            NSString *archiveFilename = iteratedFiles[i];
            NSString *expectedFilename = expectedFiles[i];
            
            NSLog(@"Testing for file %@", expectedFilename);
            
            XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
        }
    }
}

- (void)testIterateFileInfo_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *error = nil;
    NSMutableArray *iteratedFiles = [NSMutableArray array];
    BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        [iteratedFiles addObject:fileInfo.filename];
    }
                                      error:&error];
    
    XCTAssertTrue(success, @"Error returned by iterateFileInfo");
    XCTAssertNil(error, @"Error returned by iterateFileInfo");
    XCTAssertEqual(iteratedFiles.count, expectedFileSet.count,
                   @"Incorrect number of files listed in archive");

    for (NSInteger i = 0; i < iteratedFiles.count; i++) {
        NSString *archiveFilename = iteratedFiles[i];
        NSString *expectedFilename = expectedFiles[i];
        
        XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
    }
}

- (void)testIterateFileInfo_RAR5
{
    NSArray *expectedFiles = @[@"yohoho_ws.txt",
                               @"nopw.txt"];
    
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive (RAR5).rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *error = nil;
    NSMutableArray *iteratedFiles = [NSMutableArray array];
    BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        [iteratedFiles addObject:fileInfo.filename];
    }
                                      error:&error];
    
    XCTAssertTrue(success, @"Error returned by iterateFileInfo");
    XCTAssertNil(error, @"Error returned by iterateFileInfo");
    XCTAssertEqual(iteratedFiles.count, expectedFiles.count,
                   @"Incorrect number of files listed in archive");

    for (NSInteger i = 0; i < iteratedFiles.count; i++) {
        NSString *archiveFilename = iteratedFiles[i];
        NSString *expectedFilename = expectedFiles[i];
        
        XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
    }
}

- (void)testIterateFileInfo_HeaderPassword
{
    NSArray *testArchives = @[@"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing list files of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        
        URKArchive *archiveNoPassword = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
        
        NSError *passwordError = nil;
        NSArray *filesInArchive = [archiveNoPassword listFilenames:&passwordError];
        
        XCTAssertNotNil(passwordError, @"No error returned by listFilenames (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"password" error:nil];
        
        NSError *error = nil;
        NSMutableArray *iteratedFiles = [NSMutableArray array];
        BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
            [iteratedFiles addObject:fileInfo.filename];
        }
                                          error:&error];
        
        XCTAssertTrue(success, @"Error returned by iterateFileInfo");
        XCTAssertNil(error, @"Error returned by iterateFileInfo");
        XCTAssertEqual(iteratedFiles.count, expectedFiles.count,
                       @"Incorrect number of files listed in archive");

        for (NSInteger i = 0; i < iteratedFiles.count; i++) {
            NSString *archiveFilename = iteratedFiles[i];
            NSString *expectedFilename = expectedFiles[i];
            
            NSLog(@"Testing for file %@", expectedFilename);
            
            XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
        }
    }
}

- (void)testIterateFileInfo_NoHeaderPasswordGiven
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test Archive (Header Password).rar"] error:nil];
    
    NSError *error = nil;
    __block BOOL called = NO;
    BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        called = YES;
    }
                                      error:&error];

    XCTAssertNotNil(error, @"Iteration without password returned no error");
    XCTAssertFalse(success, @"Iteration without password succeeded");
    XCTAssertFalse(called, @"Iteration without password called action block");
    XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
}

- (void)testIterateFileInfo_NoFilePasswordGiven
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test Archive (Password).rar"] error:nil];
    
    NSError *error = nil;
    __block BOOL called = NO;
    BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        called = YES;
    }
                                      error:&error];

    XCTAssertNil(error, @"Iteration without file password failed");
    XCTAssertTrue(success, @"Iteration without file password failed");
    XCTAssertTrue(called, @"Iteration without file password didn't call action block");
}

- (void)testIterateFileInfo_InvalidArchive
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test File A.txt"] error:nil];
    
    NSError *error = nil;
    __block BOOL called = NO;
    BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        called = YES;
    }
                                      error:&error];

    XCTAssertNotNil(error, @"Iteration of invalid archive succeeded");
    XCTAssertFalse(success, @"Iteration for invalid archive succeeded");
    XCTAssertFalse(called, @"Iteration for invalid archive called action block");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}

- (void)testIterateFileInfo_ModifiedCRC
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    
    NSError *error = nil;
    __block BOOL called = NO;
    BOOL success = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        called = YES;
    }
                                      error:&error];
    
    XCTAssertNotNil(error, @"Iteration of invalid archive succeeded");
    XCTAssertFalse(success, @"Iteration for invalid archive succeeded");
    XCTAssertTrue(called, @"Iteration for invalid archive called action block");
    XCTAssertEqual(error.code, URKErrorCodeBadData, @"Unexpected error code returned");
}

- (void)testIterateFileInfo_ModifiedCRC_IgnoringMismatches
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    archive.ignoreCRCMismatches = YES;

    NSError *error = nil;
    __block int calledCount = 0;
    BOOL iterateSuccess = [archive iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        calledCount = 1;
    }
                                      error:&error];
    
    XCTAssertNil(error, @"Modified CRC not ignored");
    XCTAssertTrue(iterateSuccess, @"Iteration for invalid archive succeeded");
    XCTAssertEqual(1, calledCount, @"Iterated too many times for archive with modified CRC");
}


@end
