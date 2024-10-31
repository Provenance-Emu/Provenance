//
//  ProgressReportingTests.m
//  UnrarKit
//
//  Created by Dov Frankel on 9/19/17.
//
//

#import <XCTest/XCTest.h>
#import "URKArchiveTestCase.h"


@interface ProgressReportingTests : URKArchiveTestCase

@property (retain) NSMutableArray<NSNumber*> *fractionsCompletedReported;
@property (retain) NSMutableArray<NSString*> *descriptionsReported;
@property (retain) NSMutableArray<NSString*> *additionalDescriptionsReported;
@property (retain) NSMutableArray<URKFileInfo*> *fileInfosReported;

@end

static void *ExtractFilesContext = &ExtractFilesContext;
static void *OtherContext = &OtherContext;
static void *CancelContext = &CancelContext;

static NSUInteger observerCallCount;

@implementation ProgressReportingTests


- (void)setUp {
    [super setUp];

    self.fractionsCompletedReported = [NSMutableArray array];
    self.descriptionsReported = [NSMutableArray array];
    self.additionalDescriptionsReported = [NSMutableArray array];
    self.fileInfosReported = [NSMutableArray array];
    
    observerCallCount = 0;
}

- (void)testProgressReporting_ExtractFiles_FractionCompleted
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFilesProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFilesProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.000315,
                                                @0.533568,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.00001f, @"Incorrect progress reported at index %ld", (long)i);
    }
}

- (void)testProgressReporting_ExtractFiles_Description
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    archive.progress = extractFilesProgress;
    
    NSString *observedSelector = NSStringFromSelector(@selector(localizedDescription));
    
    [self.descriptionsReported removeAllObjects];
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];

    NSArray<NSString *>*expectedDescriptions = @[@"Processing “Test File A.txt”…",
                                                 @"Processing “Test File B.jpg”…",
                                                 @"Processing “Test File C.m4a”…"];
    
    for (NSString *expectedDescription in expectedDescriptions) {
        BOOL descriptionFound = [self.descriptionsReported containsObject:expectedDescription];
        XCTAssertTrue(descriptionFound, @"Expected progress updates to contain '%@', but they didn't", expectedDescription);
    }
}

- (void)testProgressReporting_ExtractFiles_AdditionalDescription
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    archive.progress = extractFilesProgress;
    
    NSString *observedSelector = NSStringFromSelector(@selector(localizedAdditionalDescription));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    NSArray<NSString *>*expectedAdditionalDescriptions = @[@"Zero KB of 105 KB",
                                                           @"33 bytes of 105 KB",
                                                           @"56 KB of 105 KB",
                                                           @"105 KB of 105 KB"];
    
    for (NSString *expectedDescription in expectedAdditionalDescriptions) {
        BOOL descriptionFound = [self.additionalDescriptionsReported containsObject:expectedDescription];
        XCTAssertTrue(descriptionFound, @"Expected progress updates to contain '%@', but they didn't", expectedDescription);
    }
}

- (void)testProgressReporting_ExtractFiles_FileInfo
{
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    archive.progress = extractFilesProgress;
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractFilesTo:overwrite:error:");
    XCTAssertTrue(success, @"Unrar failed to extract %@ to %@", testArchiveName, extractURL);
    
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    NSUInteger expectedFileInfos = 3;
    NSArray<NSString *> *expectedFileNames = @[@"Test File A.txt",
                                               @"Test File B.jpg",
                                               @"Test File C.m4a"];
    
    NSArray<NSString *> *actualFilenames = [self.fileInfosReported valueForKeyPath:NSStringFromSelector(@selector(filename))];
    
    XCTAssertEqual(self.fileInfosReported.count, expectedFileInfos, @"Incorrect number of progress updates");
    XCTAssertTrue([expectedFileNames isEqualToArray:actualFilenames], @"Incorrect filenames returned: %@", actualFilenames);
}

- (void)testProgressReporting_PerformOnFiles {
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *performProgress = [NSProgress progressWithTotalUnitCount:1];
    [performProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [performProgress addObserver:self
                      forKeyPath:observedSelector
                         options:NSKeyValueObservingOptionInitial
                         context:OtherContext];
    
    NSError *performError = nil;
    BOOL success = [archive performOnFilesInArchive:
                    ^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {} error:&performError];
    
    XCTAssertNil(performError, @"Error returned by performOnFilesInArchive:error:");
    XCTAssertTrue(success, @"Unrar failed to perform operation on files of archive");
    
    [performProgress resignCurrent];
    [performProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(performProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.333333,
                                                @0.666666,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", (long)i);
    }
}

- (void)testProgressReporting_PerformOnData {
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *performProgress = [NSProgress progressWithTotalUnitCount:1];
    [performProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [performProgress addObserver:self
                      forKeyPath:observedSelector
                         options:NSKeyValueObservingOptionInitial
                         context:OtherContext];
    
    NSError *performError = nil;
    BOOL success = [archive performOnDataInArchive:
                    ^(URKFileInfo * _Nonnull fileInfo, NSData * _Nonnull fileData, BOOL * _Nonnull stop) {}
                                             error:&performError];
    
    XCTAssertNil(performError, @"Error returned by performOnDataInArchive:error:");
    XCTAssertTrue(success, @"Unrar failed to perform operation on data of archive");
    
    [performProgress resignCurrent];
    [performProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(performProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSUInteger expectedProgressUpdates = 4;
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.000315,
                                                @0.533568,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgressUpdates; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", (long)i);
    }
}

- (void)testProgressCancellation_ExtractFiles {
    NSString *testArchiveName = @"Test Archive.rar";
    NSURL *testArchiveURL = self.testFileURLs[testArchiveName];
    NSString *extractDirectory = [self randomDirectoryWithPrefix:
                                  [testArchiveName stringByDeletingPathExtension]];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFilesProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:CancelContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    XCTAssertNotNil(extractError, @"Error not returned by extractFilesTo:overwrite:error:");
    XCTAssertEqual(extractError.code, URKErrorCodeUserCancelled, @"Incorrect error code returned from user cancellation");
    XCTAssertFalse(success, @"Unrar didn't cancel extraction");
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    
    NSUInteger expectedProgressUpdates = 2;
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    
    NSError *listContentsError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *extractedFiles = [fm contentsOfDirectoryAtPath:extractURL.path
                                                      error:&listContentsError];
    
    XCTAssertNil(listContentsError, @"Error listing contents of extraction directory");
    XCTAssertEqual(extractedFiles.count, 1, @"Cancellation didn't occur in as timely a fashion as expected");
}



#pragma mark - Mac-only tests


#if !TARGET_OS_IPHONE
- (void)testProgressReporting_ExtractData {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    NSString *firstFile = [[archive listFilenames:nil] firstObject];
    
    NSProgress *extractFileProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFileProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFileProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:OtherContext];
    
    NSError *extractError = nil;
    NSData *data = [archive extractDataFromFile:firstFile error:&extractError];
    
    XCTAssertNil(extractError, @"Error returned by extractDataFromFile:error:");
    XCTAssertNotNil(data, @"Unrar failed to extract large archive");
    
    [extractFileProgress resignCurrent];
    [extractFileProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFileProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.6983681,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgresses.count, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgresses.count; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", (long)i);
    }
}

- (void)testProgressReporting_ExtractBufferedData {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    NSString *firstFile = [[archive listFilenames:nil] firstObject];
    
    NSProgress *extractFileProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFileProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFileProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:OtherContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractBufferedDataFromFile:firstFile
                                                  error:&extractError
                                                 action:^(NSData * _Nonnull dataChunk, CGFloat percentDecompressed) {}];
    
    XCTAssertNil(extractError, @"Error returned by extractDataFromFile:error:");
    XCTAssertTrue(success, @"Unrar failed to extract large archive into buffer");
    
    [extractFileProgress resignCurrent];
    [extractFileProgress removeObserver:self forKeyPath:observedSelector];
    
    XCTAssertEqual(extractFileProgress.fractionCompleted, 1.00, @"Progress never reported as completed");
    
    NSArray<NSNumber *> *expectedProgresses = @[@0,
                                                @0.6983681,
                                                @1.0];
    
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgresses.count, @"Incorrect number of progress updates");
    for (NSInteger i = 0; i < expectedProgresses.count; i++) {
        float expectedProgress = expectedProgresses[i].floatValue;
        float actualProgress = self.fractionsCompletedReported[i].floatValue;
        
        XCTAssertEqualWithAccuracy(actualProgress, expectedProgress, 0.000001f, @"Incorrect progress reported at index %ld", (long)i);
    }
}

- (void)testProgressCancellation_ExtractData {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    NSString *firstFile = [[archive listFilenames:nil] firstObject];
    
    NSProgress *extractFileProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFileProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFileProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:CancelContext];
    
    NSError *extractError = nil;
    NSData *data = [archive extractDataFromFile:firstFile error:&extractError];
    
    XCTAssertNotNil(extractError, @"No error returned by cancelled extractDataFromFile:error:");
    XCTAssertEqual(extractError.code, URKErrorCodeUserCancelled, @"Incorrect error code returned from user cancellation");
    XCTAssertNil(data, @"extractData didn't return nil when cancelled");
    
    [extractFileProgress resignCurrent];
    [extractFileProgress removeObserver:self forKeyPath:observedSelector];
    
    NSUInteger expectedProgressUpdates = 2;
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
}

- (void)testProgressCancellation_ExtractBufferedData {
    NSURL *largeArchiveURL = [self largeArchiveURL];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:largeArchiveURL error:nil];
    NSString *firstFile = [[archive listFilenames:nil] firstObject];
    
    NSProgress *extractFileProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFileProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFileProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:CancelContext];
    
    __block NSUInteger blockCallCount = 0;
    
    NSError *extractError = nil;
    BOOL success = [archive extractBufferedDataFromFile:firstFile
                                                  error:&extractError
                                                 action:^(NSData * _Nonnull dataChunk, CGFloat percentDecompressed) {
                                                     blockCallCount++;
                                                 }];
    
    XCTAssertNotNil(extractError, @"No error returned by cancelled extractDataFromFile:error:");
    XCTAssertEqual(extractError.code, URKErrorCodeUserCancelled, @"Incorrect error code returned from user cancellation");
    XCTAssertFalse(success, @"extractBufferedData didn't return false when cancelled");
    
    [extractFileProgress resignCurrent];
    [extractFileProgress removeObserver:self forKeyPath:observedSelector];
    
    NSUInteger expectedProgressUpdates = 2;
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");
    XCTAssertEqual(blockCallCount, 1, @"Action block called incorrect number of times after cancellation");
}

- (void)testProgressCancellation_ExtractFiles_MiddleOfFile {
    NSURL *largeTextFile = [self randomTextFileOfLength:50000000]; // Increase for a more dramatic test
    XCTAssertNotNil(largeTextFile, @"No large text file URL returned");
    NSURL *testArchiveURL = [self archiveWithFiles:@[largeTextFile]];
    
    NSString *extractDirectory = [self randomDirectoryWithPrefix:@"CancelExtractInMiddle"];
    NSURL *extractURL = [self.tempDirectory URLByAppendingPathComponent:extractDirectory];
    
    URKArchive *archive = [[URKArchive alloc] initWithURL:testArchiveURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractFilesProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    // Half a second later, cancel progress
    dispatch_queue_t cancellationQueue = dispatch_queue_create("Extract Files Cancellation", 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), cancellationQueue, ^{
        URKLogInfo("Cancelling extraction in progress");
        [extractFilesProgress cancel];
    });
    
    NSDate *extractStart = [NSDate date];

    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    NSDate *extractFinish = [NSDate date];

    NSTimeInterval executionTime = [extractFinish timeIntervalSinceDate:extractStart];
    XCTAssertLessThan(executionTime, 1.0, @"Asynchronous file extraction cancel didn't stop in the middle of a file");

    XCTAssertNotNil(extractError, @"Error not returned by extractFilesTo:overwrite:error:");
    XCTAssertEqual(extractError.code, URKErrorCodeUserCancelled, @"Incorrect error code returned from user cancellation");
    XCTAssertFalse(success, @"Unrar didn't cancel extraction");
    
    [extractFilesProgress resignCurrent];
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
    
    
    NSUInteger expectedProgressUpdates = 1;
    XCTAssertEqual(self.fractionsCompletedReported.count, expectedProgressUpdates, @"Incorrect number of progress updates");

    NSError *listContentsError = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *extractedFiles = [fm contentsOfDirectoryAtPath:extractURL.path
                                                      error:&listContentsError];

    XCTAssertNil(listContentsError, @"Error listing contents of extraction directory");
    XCTAssertEqual(extractedFiles.count, 0, @"Partial file produced in spite of cancellation");
}
#endif


#pragma mark - Private methods


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    observerCallCount++;
    
    NSProgress *progress;
   
    if ([object isKindOfClass:[NSProgress class]]) {
        progress = object;
        [self.fractionsCompletedReported addObject:@(progress.fractionCompleted)];
    } else {
        return;
    }
    
    if (context == ExtractFilesContext) {
        [self.descriptionsReported addObject:progress.localizedDescription];
        [self.additionalDescriptionsReported addObject:progress.localizedAdditionalDescription];
        
        URKFileInfo *fileInfo = progress.userInfo[URKProgressInfoKeyFileInfoExtracting];
        if (fileInfo) [self.fileInfosReported addObject:fileInfo];
    }
    
    if (context == CancelContext && observerCallCount == 2) {
        NSLog(@"Cancelling progress in -[ProgressReportingTests observeValueForKeyPath:ofObject:change:context:]");
        [progress cancel];
    }
}

@end
