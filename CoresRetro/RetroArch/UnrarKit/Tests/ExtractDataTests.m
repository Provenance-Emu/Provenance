//
//  ExtractDataTests.m
//  UnrarKit
//
//

#import "URKArchiveTestCase.h"

@interface ExtractDataTests : URKArchiveTestCase

@end

@implementation ExtractDataTests

- (void)testExtractData
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
        
        NSError *error = nil;
        NSArray *fileInfos = [archive listFileInfo:&error];
        XCTAssertNil(error, @"Error reading file info");
        
        for (NSInteger i = 0; i < expectedFiles.count; i++) {
            NSString *expectedFilename = expectedFiles[i];
            
            NSError *error = nil;
            NSData *extractedData = [archive extractDataFromFile:expectedFilename error:&error];
            
            XCTAssertNil(error, @"Error in extractData:error:");
            
            NSData *expectedFileData = [NSData dataWithContentsOfURL:self.testFileURLs[expectedFilename]];
            
            XCTAssertNotNil(extractedData, @"No data extracted");
            XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
            
            error = nil;
            NSData *dataFromFileInfo = [archive extractData:fileInfos[i] error:&error];
            XCTAssertNil(error, @"Error extracting data by file info");
            XCTAssertTrue([expectedFileData isEqualToData:dataFromFileInfo], @"Extracted data from file info doesn't match original file");
        }
    }
}

- (void)testExtractData_Unicode
{
    NSSet *expectedFileSet = [self.unicodeFileURLs keysOfEntriesPassingTest:^BOOL(NSString *key, id obj, BOOL *stop) {
        return ![key hasSuffix:@"rar"] && ![key hasSuffix:@"md"];
    }];
    
    NSArray *expectedFiles = [[expectedFileSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    
    NSURL *testArchiveURL = self.unicodeFileURLs[@"Ⓣest Ⓐrchive.rar"];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSError *error = nil;
    NSArray *fileInfos = [archive listFileInfo:&error];
    XCTAssertNil(error, @"Error reading file info");
    
    for (NSInteger i = 0; i < expectedFiles.count; i++) {
        NSString *expectedFilename = expectedFiles[i];
        
        NSError *error = nil;
        NSData *extractedData = [archive extractDataFromFile:expectedFilename error:&error];
        
        XCTAssertNil(error, @"Error in extractData:error:");
        
        NSData *expectedFileData = [NSData dataWithContentsOfURL:self.unicodeFileURLs[expectedFilename]];
        
        XCTAssertNotNil(extractedData, @"No data extracted");
        XCTAssertTrue([expectedFileData isEqualToData:extractedData], @"Extracted data doesn't match original file");
        
        error = nil;
        NSData *dataFromFileInfo = [archive extractData:fileInfos[i] error:&error];
        XCTAssertNil(error, @"Error extracting data by file info");
        XCTAssertTrue([expectedFileData isEqualToData:dataFromFileInfo], @"Extracted data from file info doesn't match original file");
    }
}

- (void)testExtractData_NoPassword
{
    NSArray *testArchives = @[@"Test Archive (Password).rar",
                              @"Test Archive (Header Password).rar"];
    
    for (NSString *testArchiveName in testArchives) {
        URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[testArchiveName] error:nil];
        
        NSError *error = nil;
        NSData *data = [archive extractDataFromFile:@"Test File A.txt" error:&error];
        
        XCTAssertNotNil(error, @"Extract data without password succeeded");
        XCTAssertNil(data, @"Data returned without password");
        XCTAssertEqual(error.code, URKErrorCodeMissingPassword, @"Unexpected error code returned");
    }
}

- (void)testExtractData_IncorrectPassword
{
    NSString *testArchiveName = @"Test Archive (RAR5, Password).rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL password: @"wrong password" error: nil];
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"wtf.txt" error:&error];
    
    XCTAssertNil(data, @"Data returned with bad password");
    XCTAssertEqual(error.code, URKErrorCodeBadPassword, @"Unexpected error code returned");
}

- (void)testExtractData_InvalidArchive
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Test File A.txt"] error:nil];
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"Any file.txt" error:&error];
    
    XCTAssertNotNil(error, @"Extract data for invalid archive succeeded");
    XCTAssertNil(data, @"Data returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadArchive, @"Unexpected error code returned");
}

- (void)testExtractData_ModifiedCRC
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"README.md" error:&error];
    
    XCTAssertNotNil(error, @"Extract data for invalid archive succeeded");
    XCTAssertNil(data, @"Data returned for invalid archive");
    XCTAssertEqual(error.code, URKErrorCodeBadData, @"Unexpected error code returned");
}

- (void)testExtractData_ModifiedCRC_IgnoringMismatches
{
    URKArchive *archive = [[URKArchive alloc] initWithURL:self.testFileURLs[@"Modified CRC Archive.rar"] error:nil];
    archive.ignoreCRCMismatches = YES;
    
    NSError *error = nil;
    NSData *data = [archive extractDataFromFile:@"README.md" error:&error];
    NSData *expectedData = [NSData dataWithContentsOfURL:self.testFileURLs[@"README.md"]];
    
    XCTAssertNil(error, @"Extract data for invalid archive succeeded");
    XCTAssertNotNil(data, @"Data returned for invalid archive");
    XCTAssertEqualObjects(data, expectedData);
}

@end
