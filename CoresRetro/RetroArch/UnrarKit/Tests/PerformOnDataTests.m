//
//  PerformOnDataTests.m
//  UnrarKit
//
//

#import "URKArchiveTestCase.h"

@interface PerformOnDataTests : URKArchiveTestCase

@end

@implementation PerformOnDataTests

- (void)testPerformOnData
{
    NSArray *testArchives = @[@"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        NSString *password = ([testArchiveName rangeOfString:@"Password"].location != NSNotFound
                              ? @"password"
                              : nil);
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:password error:nil];
        
        __block NSUInteger fileIndex = 0;
        NSError *error = nil;
        
        [archive performOnDataInArchive:
         ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
             NSString *expectedFilename = expectedFiles[fileIndex++];
             XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
             
             NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
             
             XCTAssertNotNil(fileData, @"No data extracted");
             XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
         } error:&error];
        
        XCTAssertNil(error, @"Error iterating through files");
        XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
    }
}

- (void)testPerformOnData_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         NSString *expectedFilename = expectedFiles[fileIndex++];
         XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
         
         NSData *expectedFileData = [NSData dataWithContentsOfURL:self.unicodeFileURLs[expectedFilename]];
         
         XCTAssertNotNil(fileData, @"No data extracted");
         XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
    XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
}

- (void)testPerformOnData_ModifiedCRC
{
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    __block BOOL blockCalled = NO;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         blockCalled = YES;
     } error:&error];
    
    XCTAssertNotNil(error, @"Error iterating through files");
    XCTAssertFalse(blockCalled);
}

- (void)testPerformOnData_ModifiedCRC_IgnoringMismatches
{
    NSURL *testArchiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    archive.ignoreCRCMismatches = YES;

    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         XCTAssertEqual(fileIndex++, 0, @"performOnDataInArchive called too many times");
         XCTAssertEqualObjects(fileInfo.filename, @"README.md");
         NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[@"README.md"]];
         
         XCTAssertNotNil(fileData, @"No data extracted");
         XCTAssertTrue([expectedFileData isEqualToData:fileData], @"File data doesn't match original file");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
}

#if !TARGET_OS_IPHONE
- (void)testPerformOnData_FileMoved
{
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNotNil(archiveFiles, @"No filenames listed from test archive");
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"FileMoved"];
        
        NSError *renameError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
        XCTAssertNil(renameError, @"Error renaming file: %@", renameError);
    });
    
    __block NSUInteger fileCount = 0;
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 20, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}
#endif

#if !TARGET_OS_IPHONE
- (void)testPerformOnData_FileDeleted
{
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNotNil(archiveFiles, @"No filenames listed from test archive");
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:1];
        
        NSError *removeError = nil;
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtURL:largeArchiveURL error:&removeError];
        XCTAssertNil(removeError, @"Error removing file: %@", removeError);
    });
    
    __block NSUInteger fileCount = 0;
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 20, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}
#endif

#if !TARGET_OS_IPHONE
- (void)testPerformOnData_FileMovedBeforeBegin
{
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    
    NSError *error = nil;
    NSArray *archiveFiles = [archive listFilenames:&error];
    
    XCTAssertNotNil(archiveFiles, @"No filenames listed from test archive");
    XCTAssertNil(error, @"Error listing files in test archive: %@", error);
    
    NSURL *movedURL = [largeArchiveURL URLByAppendingPathExtension:@"FileMovedBeforeBegin"];
    
    NSError *renameError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm moveItemAtURL:largeArchiveURL toURL:movedURL error:&renameError];
    XCTAssertNil(renameError, @"Error renaming file: %@", renameError);
    
    __block NSUInteger fileCount = 0;
    
    error = nil;
    BOOL success = [archive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
        XCTAssertNotNil(fileData, @"Extracted file is nil: %@", fileInfo.filename);
        
        if (!fileInfo.isDirectory) {
            fileCount++;
            XCTAssertGreaterThan(fileData.length, 0, @"Extracted file is empty: %@", fileInfo.filename);
        }
    } error:&error];
    
    XCTAssertEqual(fileCount, 20, @"Not all files read");
    XCTAssertTrue(success, @"Failed to read files");
    XCTAssertNil(error, @"Error reading files: %@", error);
}
#endif

- (void)testPerformOnData_Folder
{
    NSURL *testArchiveURL = self.testFileURLs[@"Folder Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSArray *expectedFiles = @[@"G070-Cliff", @"G070-Cliff/image.jpg"];
    
    __block NSUInteger fileIndex = 0;
    NSError *error = nil;
    
    [archive performOnDataInArchive:
     ^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
         NSString *expectedFilename = expectedFiles[fileIndex++];
         XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Unexpected filename encountered");
     } error:&error];
    
    XCTAssertNil(error, @"Error iterating through files");
    XCTAssertEqual(fileIndex, expectedFiles.count, @"Incorrect number of files encountered");
}

@end
