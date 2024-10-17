//
//  ExtractBufferedDataTests.m
//  UnrarKit
//
//

#import "URKArchiveTestCase.h"

@import os.log;
@import os.signpost;


@interface ExtractBufferedDataTests : URKArchiveTestCase @end

@implementation ExtractBufferedDataTests

- (void)testExtractBufferedData
{
    NSURL *archiveURL = self.testFileURLs[@"Test Archive.rar"];
    NSString *extractedFile = @"Test File B.jpg";
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    NSError *error = nil;
    NSMutableData *reconstructedFile = [NSMutableData data];
    BOOL success = [archive extractBufferedDataFromFile:extractedFile
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [reconstructedFile appendBytes:dataChunk.bytes
                                                length:dataChunk.length];
                    }];
    
    XCTAssertTrue(success, @"Failed to read buffered data");
    XCTAssertNil(error, @"Error reading buffered data");
    XCTAssertGreaterThan(reconstructedFile.length, 0, @"No data returned");
    
    NSData *originalFile = [NSData dataWithContentsOfURL:self.testFileURLs[extractedFile]];
    XCTAssertTrue([originalFile isEqualToData:reconstructedFile],
                  @"File extracted in buffer not returned correctly");
}

- (void)testExtractBufferedData_ModifiedCRC
{
    NSURL *archiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    NSString *extractedFile = @"README.md";
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    NSError *error = nil;
    NSMutableData *reconstructedFile = [NSMutableData data];
    BOOL success = [archive extractBufferedDataFromFile:extractedFile
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [reconstructedFile appendBytes:dataChunk.bytes
                                                length:dataChunk.length];
                    }];
    
    XCTAssertFalse(success, @"Failed to read buffered data");
    XCTAssertNotNil(error, @"Error reading buffered data");
    
    NSData *originalFile = [NSData dataWithContentsOfURL:self.testFileURLs[extractedFile]];
    XCTAssertTrue([originalFile isEqualToData:reconstructedFile],
                  @"File extracted in buffer not returned correctly");
}

- (void)testExtractBufferedData_ModifiedCRC_IgnoringMismatches
{
    NSURL *archiveURL = self.testFileURLs[@"Modified CRC Archive.rar"];
    NSString *extractedFile = @"README.md";
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    archive.ignoreCRCMismatches = YES;
    
    NSError *error = nil;
    NSMutableData *reconstructedFile = [NSMutableData data];
    BOOL success = [archive extractBufferedDataFromFile:extractedFile
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [reconstructedFile appendBytes:dataChunk.bytes
                                                length:dataChunk.length];
                    }];
    
    XCTAssertTrue(success, @"Failed to read buffered data");
    XCTAssertNil(error, @"Error reading buffered data");
    XCTAssertGreaterThan(reconstructedFile.length, 0, @"No data returned");
    
    NSData *originalFile = [NSData dataWithContentsOfURL:self.testFileURLs[extractedFile]];
    XCTAssertTrue([originalFile isEqualToData:reconstructedFile],
                  @"File extracted in buffer not returned correctly");
}

#if !TARGET_OS_IPHONE && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200
- (void)testExtractBufferedData_VeryLarge
{
    os_log_t log = os_log_create("UnrarKit-testExtractBufferedData_VeryLarge", OS_LOG_CATEGORY_POINTS_OF_INTEREST);

    os_signpost_id_t createTextFileID;
    
    if (@available(macOS 10.14, *)) {
        createTextFileID = os_signpost_id_generate(log);
        os_signpost_interval_begin(log, createTextFileID, "Create Text File");
    }
    
    NSURL *largeTextFile = [self randomTextFileOfLength:1000000]; // Increase for a more dramatic test

    if (@available(macOS 10.14, *)) {
        XCTAssertNotNil(largeTextFile, @"No large text file URL returned");
        os_signpost_interval_end(log, createTextFileID, "Create Text File");
    }

    os_signpost_id_t archiveDataID;

    if (@available(macOS 10.14, *)) {
        archiveDataID = os_signpost_id_generate(log);
        os_signpost_interval_begin(log, archiveDataID, "Archive Data");
    }
    
    NSURL *archiveURL = [self archiveWithFiles:@[largeTextFile]];
    
    XCTAssertNotNil(archiveURL, @"No archived large text file URL returned");
    
    if (@available(macOS 10.14, *)) {
        os_signpost_interval_end(log, archiveDataID, "Archive Data");
    }

    NSURL *deflatedFileURL = [self.tempDirectory URLByAppendingPathComponent:@"DeflatedTextFile.txt"];
    BOOL createSuccess = [[NSFileManager defaultManager] createFileAtPath:deflatedFileURL.path
                                                                 contents:nil
                                                               attributes:nil];
    XCTAssertTrue(createSuccess, @"Failed to create empty deflate file");
    
    NSError *handleError = nil;
    NSFileHandle *deflated = [NSFileHandle fileHandleForWritingToURL:deflatedFileURL
                                                               error:&handleError];
    XCTAssertNil(handleError, @"Error creating a file handle");
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL error:nil];
    
    os_signpost_id_t extractDataID;

    if (@available(macOS 10.14, *)) {
        extractDataID = os_signpost_id_generate(log);
        os_signpost_interval_begin(log, extractDataID, "Extract Data");
    }

    NSError *error = nil;
    BOOL success = [archive extractBufferedDataFromFile:largeTextFile.lastPathComponent
                                                  error:&error
                                                 action:
                    ^(NSData *dataChunk, CGFloat percentDecompressed) {
                        NSLog(@"Decompressed: %f%%", percentDecompressed);
                        [deflated writeData:dataChunk];
                    }];
    
    if (@available(macOS 10.14, *)) {
        os_signpost_interval_end(log, extractDataID, "Extract Data");
    }
    
    XCTAssertTrue(success, @"Failed to read buffered data");
    XCTAssertNil(error, @"Error reading buffered data");
    
    [deflated closeFile];
    
    NSData *deflatedData = [NSData dataWithContentsOfURL:deflatedFileURL];
    NSData *fileData = [NSData dataWithContentsOfURL:largeTextFile];
    
    XCTAssertTrue([fileData isEqualToData:deflatedData], @"Data didn't restore correctly");
}
#endif

@end
