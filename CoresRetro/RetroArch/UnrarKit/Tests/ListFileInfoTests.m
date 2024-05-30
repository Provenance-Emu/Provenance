//
//  ListFileInfoTests.m
//  UnrarKit
//
//

#import "URKArchiveTestCase.h"

@interface ListFileInfoTests : URKArchiveTestCase

@end

@implementation ListFileInfoTests

- (void)testListFileInfo {
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test Archive.rar"] error:nil];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    static NSDateFormatter *testFileInfoDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        testFileInfoDateFormatter = [[NSDateFormatter alloc] init];
        testFileInfoDateFormatter.dateFormat = @"M/dd/yyyy h:mm a";
        testFileInfoDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    });
    
    NSDictionary *expectedTimestamps = @{@"Test File A.txt": [testFileInfoDateFormatter dateFromString:@"3/13/2014 8:02 PM"],
                                         @"Test File B.jpg": [testFileInfoDateFormatter dateFromString:@"3/13/2014 8:04 PM"],
                                         @"Test File C.m4a": [testFileInfoDateFormatter dateFromString:@"3/13/2014 8:05 PM"],};
    
    NSError *error = nil;
    NSArray *filesInArchive = [archive listFileInfo:&error];
    
    XCTAssertNil(error, @"Error returned by listFileInfo");
    XCTAssertNotNil(filesInArchive, @"No list of files returned");
    XCTAssertEqual(filesInArchive.count, expectedFileSet.count, @"Incorrect number of files listed in archive");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSInteger i = 0; i < filesInArchive.count; i++) {
        URKFileInfo *fileInfo = filesInArchive[i];
        
        // Test Archive Name
        NSString *expectedArchiveName = archive.filename;
        XCTAssertEqualObjects(fileInfo.archiveName, expectedArchiveName, @"Incorrect archive name");
        
        // Test Filename
        NSString *expectedFilename = expectedFiles[i];
        XCTAssertEqualObjects(fileInfo.filename, expectedFilename, @"Incorrect filename");
        
        // Test CRC
        NSUInteger expectedFileCRC = [self crcOfTestFile:expectedFilename];
        XCTAssertEqual(fileInfo.CRC, expectedFileCRC, @"Incorrect CRC checksum");
        
        // Test Last Modify Date
        NSTimeInterval archiveFileTimeInterval = [fileInfo.timestamp timeIntervalSinceReferenceDate];
        NSTimeInterval expectedFileTimeInterval = [expectedTimestamps[fileInfo.filename] timeIntervalSinceReferenceDate];
        XCTAssertEqualWithAccuracy(archiveFileTimeInterval, expectedFileTimeInterval, 60, @"Incorrect file timestamp (more than 60 seconds off)");
        
        // Test Uncompressed Size
        NSError *attributesError = nil;
        NSString *expectedFilePath = [[self urlOfTestFile:expectedFilename] path];
        NSDictionary *expectedFileAttributes = [fm attributesOfItemAtPath:expectedFilePath
                                                                    error:&attributesError];
        XCTAssertNil(attributesError, @"Error getting file attributes of %@", expectedFilename);
        
        long long expectedFileSize = expectedFileAttributes.fileSize;
        XCTAssertEqual(fileInfo.uncompressedSize, expectedFileSize, @"Incorrect uncompressed file size");
        
        // Test Compression method
        XCTAssertEqual(fileInfo.compressionMethod, URKCompressionMethodNormal, @"Incorrect compression method");
        
        // Test Host OS
        XCTAssertEqual(fileInfo.hostOS, URKHostOSUnix, @"Incorrect host OS");
    }
}

- (void)testListFileInfo_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *error = nil;
    NSArray *filesInArchive = [archive listFileInfo:&error];
    
    XCTAssertNil(error, @"Error returned by listFileInfo");
    XCTAssertNotNil(filesInArchive, @"No list of files returned");
    XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                   @"Incorrect number of files listed in archive");
    
    for (NSInteger i = 0; i < filesInArchive.count; i++) {
        URKFileInfo *fileInfo = (URKFileInfo *)filesInArchive[i];
        
        XCTAssertEqualObjects(fileInfo.filename, expectedFiles[i], @"Incorrect filename listed");
        XCTAssertEqualObjects(fileInfo.archiveName, archive.filename, @"Incorrect archiveName listed");
    }
}

#if !TARGET_OS_IPHONE
- (void)testListFileInfo_MultivolumeArchive {
    NSArray<NSURL*> *generatedVolumeURLs = [self multiPartArchiveWithName:@"ListFileInfoTests_MultivolumeArchive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:generatedVolumeURLs.firstObject error:nil];
    
    NSError *error = nil;
    NSArray *files = [archive listFileInfo:&error];
    
    XCTAssertNil(error, @"Error returned when listing file info for multivolume archive");
    XCTAssertEqual(files.count, 1, @"Incorrect number of file info items returned for multivolume archive");
}
#endif

- (void)testListFileInfo_HeaderPassword
{
    NSArray *testArchives = @[@"Test Archive (Header Password).rar"];
    
    NSSet *expectedFileSet = [self.testFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    for (NSString *testArchiveName in testArchives) {
        NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
        
        URKArchive *archiveNoPassword = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
        
        NSError *error = nil;
        NSArray *filesInArchive = [archiveNoPassword listFileInfo:&error];
        
        XCTAssertNotNil(error, @"No error returned by listFileInfo (no password given)");
        XCTAssertNil(filesInArchive, @"List of files returned (no password given)");
        
        URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password:@"password" error:nil];
        
        filesInArchive = nil;
        error = nil;
        filesInArchive = [archive listFileInfo:&error];
        
        XCTAssertNil(error, @"Error returned by listFileInfo");
        XCTAssertEqual(filesInArchive.count, expectedFileSet.count,
                       @"Incorrect number of files listed in archive");
        
        for (NSInteger i = 0; i < filesInArchive.count; i++) {
            URKFileInfo *archiveFileInfo = filesInArchive[i];
            NSString *archiveFilename = archiveFileInfo.filename;
            NSString *expectedFilename = expectedFiles[i];
            
            XCTAssertEqualObjects(archiveFilename, expectedFilename, @"Incorrect filename listed");
        }
    }
}

- (void)testListFileInfo_NoHeaderPasswordGiven {
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test Archive (Header Password).rar"] error:nil];
    
    NSError *error = nil;
    NSArray *files = [archive listFileInfo:&error];
    
    XCTAssertNotNil(error, @"List without password succeeded");
    XCTAssertNil(files, @"List returned without password");
    XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
}

- (void)testListFileInfo_InvalidArchive
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test File A.txt"] error:nil];
    
    NSError *error = nil;
    NSArray *files = [archive listFileInfo:&error];
    
    XCTAssertNotNil(error, @"List files of invalid archive succeeded");
    XCTAssertNil(files, @"List returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}

- (void)testListFileInfo_ModifiedCRC
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    
    NSError *error = nil;
    NSArray *files = [archive listFileInfo:&error];
    
    XCTAssertNotNil(error, @"List files of invalid archive succeeded");
    XCTAssertNil(files, @"List returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadData, @"Unexpected error code returned");
}

- (void)testListFileInfo_ModifiedCRC_IgnoringMismatches
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    archive.ignoreCRCMismatches = YES;

    NSError *error = nil;
    NSArray<URKFileInfo*> *files = [archive listFileInfo:&error];
    
    XCTAssertNil(error, @"List files of invalid archive succeeded");
    XCTAssertNotNil(files, @"List returned for invalid archive");
    XCTAssertEqual(files.count, 1);
    XCTAssertEqualObjects(files[0].filename, @"README.md");
}

@end
