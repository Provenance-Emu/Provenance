//
//  URKArchiveTests.m
//  UnrarKit Tests
//
//

#import "URKArchiveTestCase.h"


@interface URKArchiveTests : URKArchiveTestCase @end


@implementation URKArchiveTests



#pragma mark - Test Cases


#pragma mark Archive File


#if !TARGET_OS_IPHONE
- (void)testFileURL {
    NSArray *testArchives = @[@"Large",
                              @"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing fileURL of archive %@", testArchiveName);
        NSURL *testArchiveURL = ([testArchiveName isEqualToString:@"Large"]
                                 ? [self largeArchiveURL]
                                 : self.testFileURLs[testArchiveName]);
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
        XCTAssertFalse(archive.ignoreCRCMismatches);

        NSURL *resolvedURL = archive.fileURL.URLByResolvingSymlinksInPath;
        XCTAssertNotNil(resolvedURL, @"Nil URL returned for valid archive");
        XCTAssertTrue([testArchiveURL isEqual:resolvedURL], @"Resolved URL doesn't match original");
    }
}
#endif

#if !TARGET_OS_IPHONE
- (void)testFilename {
    NSArray *testArchives = @[@"Large",
                              @"Test Archive.rar",
                              @"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        NSLog(@"Testing filename of archive %@", testArchiveName);
        NSURL *testArchiveURL = ([testArchiveName isEqualToString:@"Large"]
                                 ? [self largeArchiveURL]
                                 : self.testFileURLs[testArchiveName]);
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
        XCTAssertFalse(archive.ignoreCRCMismatches);

        NSString *resolvedFilename = archive.filename;
        XCTAssertNotNil(resolvedFilename, @"Nil filename returned for valid archive");
        
        // Testing by suffix, since the original points to /private/var, but the resolved one
        // points straight to /var. They're equivalent, but not character-for-character equal
        XCTAssertTrue([resolvedFilename hasSuffix:testArchiveURL.path],
                      @"Resolved filename doesn't match original");
    }
}
#endif

- (void)testUncompressedSize {
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    NSNumber *size = archive.uncompressedSize;
    
    XCTAssertNotNil(size, @"Nil size returned");
    XCTAssertEqual(size.integerValue, 104714, @"Wrong uncompressed size returned");
}

- (void)testUncompressedSize_InvalidArchive {
    NSURL *testArchiveURL = self.testFileURLs[@"Test File A.txt"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    NSNumber *size = archive.uncompressedSize;
    
    XCTAssertNil(size, @"Uncompressed size of invalid archive should be nil");
}

- (void)testCompressedSize {
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    NSNumber *size = archive.compressedSize;
    
    XCTAssertNotNil(size, @"Nil size returned");
    XCTAssertEqual(size.integerValue, 89069, @"Wrong uncompressed size returned");
}

- (void)testCompressedSize_ArchiveMissing {
    NSURL *testArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    [[NSFileManager defaultManager] removeItemAtURL:testArchiveURL error:nil];
    
    NSNumber *size = archive.compressedSize;
    
    XCTAssertNil(size, @"Compressed size of an archive with no path should be nil");
}


#pragma mark - RAR file Detection

#pragma By Path

- (void)testPathIsARAR
{
    NSURL *url = self.testFileURLs[@"Test Archive.rar"];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertTrue(pathIsRAR, @"RAR file is not reported as a RAR");
}

- (void)testPathIsARAR_NotARAR
{
    NSURL *url = self.testFileURLs[@"Test File B.jpg"];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertFalse(pathIsRAR, @"JPG file is reported as a RAR");
}

- (void)testPathIsARAR_SmallFile
{
    NSURL *url = [self randomTextFileOfLength:1];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertFalse(pathIsRAR, @"Small non-RAR file is reported as a RAR");
}

- (void)testPathIsARAR_MissingFile
{
    NSURL *url = [self.testFileURLs[@"Test Archive.rar"] URLByAppendingPathExtension:@"missing"];
    NSString *path = url.path;
    BOOL pathIsRAR = [URKArchive pathIsARAR:path];
    XCTAssertFalse(pathIsRAR, @"Missing file is reported as a RAR");
}

#if !TARGET_OS_IPHONE
- (void)testPathIsARAR_FileHandleLeaks
{
    NSURL *smallFileURL = [self randomTextFileOfLength:1];
    NSURL *jpgURL = self.testFileURLs[@"Test File B.jpg"];
    
    NSInteger initialFileCount = [self numberOfOpenFileHandles];
    
    for (NSInteger i = 0; i < 10000; i++) {
        BOOL smallFileIsZip = [URKArchive pathIsARAR:smallFileURL.path];
        XCTAssertFalse(smallFileIsZip, @"Small non-RAR file is reported as a RAR");
        
        BOOL jpgIsZip = [URKArchive pathIsARAR:jpgURL.path];
        XCTAssertFalse(jpgIsZip, @"JPG file is reported as a RAR");
        
        NSURL *zipURL = self.testFileURLs[@"Test Archive.rar"];
        BOOL zipFileIsZip = [URKArchive pathIsARAR:zipURL.path];
        XCTAssertTrue(zipFileIsZip, @"RAR file is not reported as a RAR");
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}
#endif

#pragma By URL

- (void)testurlIsARAR
{
    NSURL *url = self.testFileURLs[@"Test Archive.rar"];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertTrue(urlIsRAR, @"RAR file is not reported as a RAR");
}

- (void)testurlIsARAR_NotARAR
{
    NSURL *url = self.testFileURLs[@"Test File B.jpg"];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertFalse(urlIsRAR, @"JPG file is reported as a RAR");
}

- (void)testurlIsARAR_SmallFile
{
    NSURL *url = [self randomTextFileOfLength:1];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertFalse(urlIsRAR, @"Small non-RAR file is reported as a RAR");
}

- (void)testurlIsARAR_MissingFile
{
    NSURL *url = [self.testFileURLs[@"Test Archive.rar"] URLByAppendingPathExtension:@"missing"];
    BOOL urlIsRAR = [URKArchive urlIsARAR:url];
    XCTAssertFalse(urlIsRAR, @"Missing file is reported as a RAR");
}

#if !TARGET_OS_IPHONE
- (void)testurlIsARAR_FileHandleLeaks
{
    NSURL *smallFileURL = [self randomTextFileOfLength:1];
    NSURL *jpgURL = self.testFileURLs[@"Test File B.jpg"];
    
    NSInteger initialFileCount = [self numberOfOpenFileHandles];
    
    for (NSInteger i = 0; i < 10000; i++) {
        BOOL smallFileIsZip = [URKArchive urlIsARAR:smallFileURL];
        XCTAssertFalse(smallFileIsZip, @"Small non-RAR file is reported as a RAR");
        
        BOOL jpgIsZip = [URKArchive urlIsARAR:jpgURL];
        XCTAssertFalse(jpgIsZip, @"JPG file is reported as a RAR");
        
        NSURL *zipURL = self.testFileURLs[@"Test Archive.rar"];
        BOOL zipFileIsZip = [URKArchive urlIsARAR:zipURL];
        XCTAssertTrue(zipFileIsZip, @"RAR file is not reported as a RAR");
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}
#endif



#pragma mark Various


#if !TARGET_OS_IPHONE
- (void)testFileDescriptorUsage
{
    NSInteger initialFileCount = [self numberOfOpenFileHandles];
    
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveOriginalURL = self.testFileURLs[testArchiveName];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSInteger i = 0; i < 1000; i++) {
        NSString *tempDir = [self randomDirectoryName];
        NSURL *tempDirURL = [self.tempDirectory URLByAppendingPathComponent:tempDir];
        NSURL *testArchiveCopyURL = [tempDirURL URLByAppendingPathComponent:testArchiveName];
        
        NSError *error = nil;
        [fm createDirectoryAtURL:tempDirURL
     withIntermediateDirectories:YES
                      attributes:nil
                           error:&error];
        
        XCTAssertNil(error, @"Error creating temp directory: %@", tempDirURL);
        
        [fm copyItemAtURL:testArchiveOriginalURL toURL:testArchiveCopyURL error:&error];
        XCTAssertNil(error, @"Error copying test archive \n from: %@ \n\n   to: %@", testArchiveOriginalURL, testArchiveCopyURL);
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveCopyURL error:nil];
        
        NSArray *fileList = [archive listFilenames:&error];
        XCTAssertNotNil(fileList);
        
        for (NSString *fileName in fileList) {
            NSData *fileData = [archive extractDataFromFile:fileName error:&error];
            XCTAssertNotNil(fileData);
            XCTAssertNil(error);
        }
    }
    
    NSInteger finalFileCount = [self numberOfOpenFileHandles];
    
    XCTAssertEqualWithAccuracy(initialFileCount, finalFileCount, 5, @"File descriptors were left open");
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultiThreading {
    NSURL *largeArchiveURL_A = [self largeArchiveURL];
    NSURL *largeArchiveURL_B = [largeArchiveURL_A.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive 2.rar"];
    NSURL *largeArchiveURL_C = [largeArchiveURL_A.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive 3.rar"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *archiveBCopyError = nil;
    XCTAssertTrue([fm copyItemAtURL:largeArchiveURL_A toURL:largeArchiveURL_B error:&archiveBCopyError], @"Failed to copy archive B");
    XCTAssertNil(archiveBCopyError, @"Error copying archive B");
    
    NSError *archiveCCopyError = nil;
    XCTAssertTrue([fm copyItemAtURL:largeArchiveURL_A toURL:largeArchiveURL_C error:&archiveCCopyError], @"Failed to copy archive C");
    XCTAssertNil(archiveCCopyError, @"Error copying archive C");
    
    URKArchive *largeArchiveA = [[URKArchive alloc] initWithURL:largeArchiveURL_A error:nil];
    URKArchive *largeArchiveB = [[URKArchive alloc] initWithURL:largeArchiveURL_B error:nil];
    URKArchive *largeArchiveC = [[URKArchive alloc] initWithURL:largeArchiveURL_C error:nil];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"A finished"];
    XCTestExpectation *expectationB = [self expectationWithDescription:@"B finished"];
    XCTestExpectation *expectationC = [self expectationWithDescription:@"C finished"];
    
    NSBlockOperation *enumerateA = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveA performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    
    NSBlockOperation *enumerateB = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveB performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationB fulfill];
    }];
    
    NSBlockOperation *enumerateC = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveC performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationC fulfill];
    }];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    queue.suspended = YES;
    
    [queue addOperation:enumerateA];
    [queue addOperation:enumerateB];
    [queue addOperation:enumerateC];
    
    queue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error while waiting for expectations: %@", error);
        }
    }];
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultiThreading_SingleFile {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *largeArchiveA = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    URKArchive *largeArchiveB = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    URKArchive *largeArchiveC = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"A finished"];
    XCTestExpectation *expectationB = [self expectationWithDescription:@"B finished"];
    XCTestExpectation *expectationC = [self expectationWithDescription:@"C finished"];
    
    NSBlockOperation *enumerateA = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveA performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    
    NSBlockOperation *enumerateB = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveB performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationB fulfill];
    }];
    
    NSBlockOperation *enumerateC = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchiveC performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationC fulfill];
    }];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    queue.suspended = YES;
    
    [queue addOperation:enumerateA];
    [queue addOperation:enumerateB];
    [queue addOperation:enumerateC];
    
    queue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error while waiting for expectations: %@", error);
        }
    }];
}
#endif

#if !TARGET_OS_IPHONE
- (void)testMultiThreading_SingleArchiveObject {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *largeArchive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    
    XCTestExpectation *expectationA = [self expectationWithDescription:@"A finished"];
    XCTestExpectation *expectationB = [self expectationWithDescription:@"B finished"];
    XCTestExpectation *expectationC = [self expectationWithDescription:@"C finished"];
    
    NSBlockOperation *enumerateA = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationA fulfill];
    }];
    
    NSBlockOperation *enumerateB = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationB fulfill];
    }];
    
    NSBlockOperation *enumerateC = [NSBlockOperation blockOperationWithBlock:^{
        NSError *error = nil;
        [largeArchive performOnDataInArchive:^(URKFileInfo *fileInfo, NSData *fileData, BOOL *stop) {
            NSLog(@"File name: %@", fileInfo.filename);
        } error:&error];
        
        XCTAssertNil(error);
        [expectationC fulfill];
    }];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 3;
    queue.suspended = YES;
    
    [queue addOperation:enumerateA];
    [queue addOperation:enumerateB];
    [queue addOperation:enumerateC];
    
    queue.suspended = NO;
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Error while waiting for expectations: %@", error);
        }
    }];
}
#endif

- (void)testErrorIsCorrect
{
    NSError *error = nil;
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.corruptArchive error:nil];
    XCTAssertNil([archive listFilenames:&error], "Listing filenames in corrupt archive should return nil");
    XCTAssertNotNil(error, @"An error should be returned when listing filenames in a corrupt archive");
    XCTAssertNotNil(error.description, @"Error's description is nil");
}

- (void)testUnicodeArchiveName
{
    NSURL *originalArchiveURL = self.testFileURLs[@"Test Archive.rar"];
    
    NSString *newArchiveName = @" ♔ ♕ ♖ ♗ ♘ ♙ ♚ ♛ ♜ ♝ ♞ ♟.rar";
    
    NSURL *newArchiveURL = [[originalArchiveURL URLByDeletingLastPathComponent]
                            URLByAppendingPathComponent:newArchiveName];
    
    NSError *error = nil;
    BOOL moveSuccess = [[NSFileManager defaultManager] moveItemAtURL:originalArchiveURL
                                                               toURL:newArchiveURL
                                                               error:&error];
    XCTAssertTrue(moveSuccess, @"Failed to rename Test Archive to unicode name");
    XCTAssertNil(error, @"Error renaming Test Archive to unicode name: %@", error);
    
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [@"Unicode contents" stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];

    NSError *extractFilesError = nil;
    URKArchive *unicodeNamedArchive = [[URKArchive alloc] initWithURL:newArchiveURL error:nil];
    BOOL extractSuccess = [unicodeNamedArchive extractFilesTo:extractURL.path
                                                    overwrite:NO
                                                        error:&error];

    XCTAssertTrue(extractSuccess, @"Failed to extract archive");
    XCTAssertNil(extractFilesError, @"Error extracting archive: %@", extractFilesError);
}



@end
