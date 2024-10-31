//
//  ExtractFilesTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import "URKArchiveTestCase.h"

@interface ExtractFilesTests : URKArchiveTestCase

@end

@implementation ExtractFilesTests

- (void)testExtractFiles
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing extraction of archive %@", testArchiveName);
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                      [testArchiveName stringByDeletingPathExtension]];
        NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
        
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        NSError *error = nil;
        BOOL success = [archive extractFilesTo:extractURL.path
                                     overwrite:NO
                                         error:&error];
        
        XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
        XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
        
        error = nil;
        NSArray *extractedFiles = [[fm contentsOfDirectoryAtPath:extractURL.path
                                                           error:&error]
                                   sortedArrayUsingSelector:@selector(compare:)];
        
        XCTAssertNil(error, @"Failed to list contents of extract directory: %@", extractURL);
        
        XCTAssertNotNil(extractedFiles, @"No list of files returned");
        XCTAssertEqual(extractedFiles.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < extractedFiles.count; i++) {
            NSString *extractedFilename = extractedFiles[i];
            NSString *expectedFilename = expectedFiles[i];
            
            XCTAssertEqualObjects(extractedFilename, expectedFilename, @"Incorrect filename listed");
            
            NSURL *extractedFileURL = [extractURL URLByAppendingPathComponent:extractedFilename];
            NSURL *expectedFileURL = self.testFileURLs[expectedFilename];
            
            NSData *extractedFileData = [NSData dataWithContentsOfURL:extractedFileURL];
            NSData *expectedFileData = [NSData dataWithContentsOfURL:expectedFileURL];
            
            XCTAssertTrue([expectedFileData isEqualToData:extractedFileData], @"Data in file doesn't match source");
        }
    }
}

- (void)testExtractFiles_RAR5
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
#if !TARGET_OS_IPHONE
    NSURL *extractRootDirectory = self.tempDirectory;
#else
    NSURL *extractRootDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                          inDomains:NSUserDomainMask] firstObject];
    extractRootDirectory = [extractRootDirectory URLByAppendingPathComponent:@"testExtractFiles_RAR5"];
    NSLog(@"Documents directory: %@", extractRootDirectory.path);

    if ([fm fileExistsAtPath:extractRootDirectory.path]) {
        NSError *clearDirError = nil;
        XCTAssertTrue([fm removeItemAtURL:extractRootDirectory error:&clearDirError], @"Failed to clear out documents directory");
        XCTAssertNil(clearDirError, @"Error while clearing out documents directory");
    }

#endif
    NSArray *expectedFiles = @[@"nopw.txt",
                               @"yohoho_ws.txt"];
    
    NSString *testArchiveName = @"Test Archive (RAR5).rar";
    
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    for (NSInteger i = 0; i < 10; i++) {
        NSString *extractDir = [NSString stringWithFormat:@"%ld_%@", (long)i, testArchiveName.stringByDeletingPathExtension];
        NSURL *extractURL = [extractRootDirectory URLByAppendingPathComponent:extractDir];
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
        
        NSError *error = nil;
        BOOL success = [archive extractFilesTo:extractURL.path
                                     overwrite:NO
                                         error:&error];
        
        XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
        XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
        
        error = nil;
        NSArray *extractedFiles = [[fm contentsOfDirectoryAtPath:extractURL.path
                                                           error:&error]
                                   sortedArrayUsingSelector:@selector(compare:)];
        
        XCTAssertNil(error, @"Failed to list contents of extract directory: %@", extractURL);
        
        XCTAssertNotNil(extractedFiles, @"No list of files returned");
        XCTAssertEqual(extractedFiles.count, expectedFiles.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger x = 0; x < extractedFiles.count; x++) {
            NSString *extractedFilename = extractedFiles[x];
            NSString *expectedFilename = expectedFiles[x];
            
            XCTAssertEqualObjects(extractedFilename, expectedFilename, @"Incorrect filename listed");
            
            NSURL *extractedFileURL = [extractURL URLByAppendingPathComponent:extractedFilename];
            XCTAssertTrue([fm fileExistsAtPath:extractedFileURL.path], @"No file extracted");
        }
    }
}

- (void)testExtractFiles_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *testArchiveName = @"Ⓣest Ⓐrchive.rar";
    NSURL *testArchiveURL = self.unicodeFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&error];
    
    XCTAssertNil(error, @"Error returned by unrarFileTo:overWrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    error = nil;
    NSArray *extractedFiles = [[fm contentsOfDirectoryAtPath:extractURL.path
                                                       error:&error]
                               sortedArrayUsingSelector:@selector(compare:)];
    
    XCTAssertNil(error, @"Failed to list contents of extract directory: %@", extractURL);
    
    XCTAssertNotNil(extractedFiles, @"No list of files returned");
    XCTAssertEqual(extractedFiles.count, expectedFileSet.count,
                   @"Incorrect number of files listed in archive");
    
    for (NSInteger i = 0; i < extractedFiles.count; i++) {
        NSString *extractedFilename = extractedFiles[i];
        NSString *expectedFilename = expectedFiles[i];
        
        XCTAssertEqualObjects(extractedFilename, expectedFilename, @"Incorrect filename listed");
        
        NSURL *extractedFileURL = [extractURL URLByAppendingPathComponent:extractedFilename];
        NSURL *expectedFileURL = self.unicodeFileURLs[expectedFilename];
        
        NSData *extractedFileData = [NSData dataWithContentsOfURL:extractedFileURL];
        NSData *expectedFileData = [NSData dataWithContentsOfURL:expectedFileURL];
        
        XCTAssertTrue([expectedFileData isEqualToData:extractedFileData], @"Data in file doesn't match source");
    }
}

- (void)testExtractFiles_NoPassword
{
    NSArray *testArchives = @[@"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing extraction archive (no password given): %@", testArchiveName);
        URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[testArchiveName] error:nil];
        
        NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                      [testArchiveName stringByDeletingPathExtension]];
        NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
        
        
        NSError *error = nil;
        BOOL success = [archive extractFilesTo:extractURL.path
                                     overwrite:NO
                                         error:&error];
        BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
        
        XCTAssertFalse(success, @"Extract without password succeeded");
        XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
        XCTAssertFalse(dirExists, @"Directory successfully created without password");
    }
}

- (void)testExtractFiles_IncorrectPassword
{
    NSString *testArchiveName = @"Test Archive (RAR5, Password).rar";
    NSLog(@"Testing extraction of archive %@", testArchiveName);
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password: @"wrong password" error: nil];
    NSError *error = nil;
    [archive extractFilesTo:extractURL.path
                  overwrite:NO
                      error:&error];
    
    XCTAssertEqual(error.code, URKErrorCodeBadPassword, @"Unexpected error code returned");
}

- (void)testExtractFiles_InvalidArchive
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test File A.txt"] error:nil];
    
    NSString *extractDirectory = [self randomDirectoryWithPrefix:@"ExtractInvalidArchive"];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&error];
    BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
    
    XCTAssertFalse(success, @"Extract invalid archive succeeded");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
    XCTAssertFalse(dirExists, @"Directory successfully created for invalid archive");
}

- (void)testExtractFiles_ModifiedCRC
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    
    NSString *extractDirectory = [self randomDirectoryWithPrefix:@"ExtractInvalidArchive"];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&error];
    BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
    
    XCTAssertFalse(success, @"Extract invalid archive succeeded");
    XCTAssertEqual(error.code, URKErrorCodeBadData, @"Unexpected error code returned");
    XCTAssertFalse(dirExists, @"Directory successfully created for invalid archive");
}

- (void)testExtractFiles_ModifiedCRC_IgnoreCRCMismatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    archive.ignoreCRCMismatches = YES;

    NSString *extractDirectory = [self randomDirectoryWithPrefix:@"ExtractInvalidArchive"];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&error];
    
    XCTAssertTrue(success, @"CRC mismatch not ignored");
    XCTAssertNil(error, @"Unexpected error code returned");
    
    BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
    XCTAssertTrue(dirExists, @"Directory successfully created for invalid archive");
    
    NSURL *extractedFileURL = [extractURL URLByAppendingPathComponent:@"README.md"];
    XCTAssertTrue([extractedFileURL checkResourceIsReachableAndReturnError:NULL]);
}

- (void)testExtractFiles_ModifiedCRC_DontIgnoreCRCMismatches
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:@"ExtractInvalidArchive"];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    NSError *error = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&error];
    
    XCTAssertFalse(success, @"CRC mismatch not ignored");
    XCTAssertNotNil(error, @"Unexpected error code returned");
    
    BOOL dirExists = [fm fileExistsAtPath:extractURL.path];
    XCTAssertFalse(dirExists, @"Directory successfully created for invalid archive");
}

@end
