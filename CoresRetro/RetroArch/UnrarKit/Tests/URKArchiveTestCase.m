//
//  URKArchiveTestCase.m
//  UnrarKit
//
//  Created by Dov Frankel on 6/22/15.
//
//

#import "URKArchiveTestCase.h"
#import "UnrarKit_Tests-Swift.h"

#import <zlib.h>



static NSURL *originalLargeArchiveURL;


@implementation URKArchiveTestCase


#pragma mark - Test Management


- (void)setUp
{
    [super setUp];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *uniqueName = [self randomDirectoryName];
    NSError *error = nil;
    
    NSArray *testFiles = @[@"Test Archive.rar",
                           @"Test Archive (Password).rar",
                           @"Test Archive (Header Password).rar",
                           @"Test Archive (RAR5, Password).rar",
                           @"Test Archive (RAR5).rar",
                           @"Folder Archive.rar",
                           @"Modified CRC Archive.rar",
                           @"README.md",
                           @"Test File A.txt",
                           @"Test File B.jpg",
                           @"Test File C.m4a",
                           @"bin/arm/rar",
                           @"bin/x64/rar"];
    
    NSArray *unicodeFiles = @[@"Ⓣest Ⓐrchive.rar",
                              @"Test File Ⓐ.txt",
                              @"Test File Ⓑ.jpg",
                              @"Test File Ⓒ.m4a"];
    
    NSString *tempDirSubtree = [@"UnrarKitTest" stringByAppendingPathComponent:uniqueName];
    
    self.testFailed = NO;
    self.testFileURLs = [[NSMutableDictionary alloc] init];
    self.unicodeFileURLs = [[NSMutableDictionary alloc] init];
    self.tempDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:tempDirSubtree]
                                    isDirectory:YES];
    
    NSLog(@"Temp directory: %@", self.tempDirectory);
    
    [fm createDirectoryAtURL:self.tempDirectory
 withIntermediateDirectories:YES
                  attributes:nil
                       error:&error];
    
    XCTAssertNil(error, @"Failed to create temp directory: %@", self.tempDirectory);
    
    NSMutableArray *filesToCopy = [NSMutableArray arrayWithArray:testFiles];
    [filesToCopy addObjectsFromArray:unicodeFiles];
    
    for (NSString *file in filesToCopy) {
        NSURL *testFileURL = [self urlOfTestFile:file];
        BOOL testFileExists = [fm fileExistsAtPath:testFileURL.path];
        XCTAssertTrue(testFileExists, @"%@ not found", file);
        
        NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:file isDirectory:NO];
        
        NSError *error = nil;
        if (file.pathComponents.count > 1) {
            [fm createDirectoryAtPath:destinationURL.URLByDeletingLastPathComponent.path
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            XCTAssertNil(error, @"Failed to create directories for file %@", file);
        }
        
        [fm copyItemAtURL:testFileURL
                    toURL:destinationURL
                    error:&error];
        
        XCTAssertNil(error, @"Failed to copy temp file %@ from %@ to %@",
                     file, testFileURL, destinationURL);
        
        if ([testFiles containsObject:file]) {
            [self.testFileURLs setObject:destinationURL forKey:file];
        }
        else if ([unicodeFiles containsObject:file]) {
            [self.unicodeFileURLs setObject:destinationURL forKey:file];
        }
    }
    
    
    // Make a "corrupt" rar file
    NSURL *m4aFileURL = [self urlOfTestFile:@"Test File C.m4a"];
    self.corruptArchive = [self.tempDirectory URLByAppendingPathComponent:@"corrupt.rar"];
    [fm copyItemAtURL:m4aFileURL
                toURL:self.corruptArchive
                error:&error];
    
    XCTAssertNil(error, @"Failed to create corrupt archive (copy from %@ to %@)", m4aFileURL, self.corruptArchive);
}

- (void)tearDown
{
    NSString *largeArchiveDirectory = originalLargeArchiveURL.path.stringByDeletingLastPathComponent;
    BOOL tempDirContainsLargeArchive = [largeArchiveDirectory isEqualToString:self.tempDirectory.path];
    if (!self.testFailed && !tempDirContainsLargeArchive) {
        __block NSError *error = nil;
        
        dispatch_semaphore_t sem = dispatch_semaphore_create(1);

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSFileManager defaultManager] removeItemAtURL:self.tempDirectory error:&error];
            dispatch_semaphore_signal(sem);
        });

        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5000));
        XCTAssertNil(error, @"Error deleting temp directory");
    }
    
    [super tearDown];
}

- (void)recordIssue:(XCTIssue *)issue {
    self.testFailed = YES;
    [super recordIssue:issue];
}



#pragma mark - Helper Methods


- (NSURL *)urlOfTestFile:(NSString *)filename
{
    NSString *baseDirectory = @"Test Data";
    NSString *subPath = filename.stringByDeletingLastPathComponent;
    NSString *bundleSubdir = [baseDirectory stringByAppendingPathComponent:subPath];
    
    return [[NSBundle bundleForClass:[self class]] URLForResource:filename.lastPathComponent
                                                    withExtension:nil
                                                     subdirectory:bundleSubdir];
}

- (NSString *)randomDirectoryName
{
    NSString *globallyUnique = [[NSProcessInfo processInfo] globallyUniqueString];
    NSRange firstHyphen = [globallyUnique rangeOfString:@"-"];
    return [globallyUnique substringToIndex:firstHyphen.location];
}

- (NSString *)randomDirectoryWithPrefix:(NSString *)prefix
{
    return [NSString stringWithFormat:@"%@ %@", prefix, [self randomDirectoryName]];
}

- (NSURL *)randomTextFileOfLength:(NSUInteger)numberOfCharacters {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,?!\n";
    NSUInteger letterCount = letters.length;
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:numberOfCharacters];
    
    for (NSUInteger i = 0; i < numberOfCharacters; i++) {
        uint32_t charIndex = arc4random_uniform((uint32_t)letterCount);
        [randomString appendFormat:@"%C", [letters characterAtIndex:charIndex]];
    }
    
    NSURL *resultURL = [self.tempDirectory URLByAppendingPathComponent:
                        [NSString stringWithFormat:@"%@.txt", [[NSProcessInfo processInfo] globallyUniqueString]]];
    
    NSError *error = nil;
    [randomString writeToURL:resultURL atomically:YES encoding:NSUTF16StringEncoding error:&error];
    XCTAssertNil(error, @"Error opening file handle for text file creation: %@", error);
    
    return resultURL;
}

- (NSUInteger)crcOfTestFile:(NSString *)filename {
    NSURL *fileURL = [self urlOfTestFile:filename];
    NSData *fileContents = [[NSFileManager defaultManager] contentsAtPath:[fileURL path]];
    return crc32(0, fileContents.bytes, (uint)fileContents.length);
}



#pragma mark - Mac Only


#if !TARGET_OS_IPHONE
- (NSURL *)largeArchiveURL {
    NSFileManager *fm = [NSFileManager defaultManager];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *largeTextFiles = [NSMutableArray array];
        for (NSInteger i = 0; i < 20; i++) {
            [largeTextFiles addObject:[self randomTextFileOfLength:3000000]];
        }
        
        NSError *largeArchiveError = nil;
        
        NSURL *largeArchiveURLRandomName = [self archiveWithFiles:largeTextFiles];
        originalLargeArchiveURL = [largeArchiveURLRandomName.URLByDeletingLastPathComponent URLByAppendingPathComponent:@"Large Archive (Original).rar"];
        [fm moveItemAtURL:largeArchiveURLRandomName toURL:originalLargeArchiveURL error:&largeArchiveError];
        
        XCTAssertNil(largeArchiveError, @"Error renaming original large archive: %@", largeArchiveError);
    });
    
    NSString *largeArchiveName = @"Large Archive.rar";
    NSURL *destinationURL = [self.tempDirectory URLByAppendingPathComponent:largeArchiveName isDirectory:NO];
    NSError *fileCopyError = nil;
    [fm copyItemAtURL:originalLargeArchiveURL toURL:destinationURL error:&fileCopyError];
    XCTAssertNil(fileCopyError, @"Failed to copy the Large Archive");
    
    return destinationURL;
}

- (NSInteger)numberOfOpenFileHandles {
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/lsof";
    task.arguments = @[@"-P", @"-n", @"-p", [NSString stringWithFormat:@"%d", pid]];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *lsofOutput = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    //    NSLog(@"LSOF:\n%@", lsofOutput);
    
    return [lsofOutput componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]].count;
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs {
    return [self archiveWithFiles:fileURLs arguments:nil];
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs arguments:(NSArray *)customArgs {
    return [self archiveWithFiles:fileURLs arguments:customArgs commandOutput:NULL];
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs arguments:(NSArray *)customArgs commandOutput:(NSString **)commandOutput {
    return [self archiveWithFiles:fileURLs name:nil arguments:customArgs commandOutput:commandOutput];
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs name:(NSString *)archiveName {
    return [self archiveWithFiles:fileURLs name:archiveName arguments:nil];
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs name:(NSString *)archiveName arguments:(NSArray *)customArgs {
    return [self archiveWithFiles:fileURLs name:archiveName arguments:customArgs commandOutput:NULL];
}

- (NSURL *)archiveWithFiles:(NSArray *)fileURLs name:(NSString *)archiveName arguments:(NSArray *)customArgs commandOutput:(NSString **)commandOutput {
    NSString *archiveFileName = archiveName;
    if (![archiveFileName length]) {
        NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
        archiveFileName = [uniqueString stringByAppendingPathExtension:@"rar"];
    }
    
    NSString *binPath;
    
    if ([self.machineHardwareName isEqualTo:@"arm64"]) {
        binPath = @"Test Data/bin/arm";
    } else {
        binPath = @"Test Data/bin/x64";
    }
    
    NSURL *rarExec = [[NSBundle bundleForClass:[self class]] URLForResource:@"rar"
                                                              withExtension:nil
                                                               subdirectory:binPath];
    NSURL *archiveURL = [self.tempDirectory URLByAppendingPathComponent:archiveFileName];
    
    NSMutableArray *rarArguments = [NSMutableArray arrayWithArray:@[@"a", @"-ep", archiveURL.path]];
    if (customArgs) {
        [rarArguments addObjectsFromArray:customArgs];
    }
    [rarArguments addObjectsFromArray:[fileURLs valueForKeyPath:@"path"]];
    
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = rarExec;
    task.arguments = rarArguments;
    task.standardOutput = pipe;
    
    NSError *launchError = nil;
    [task launchAndReturnError:&launchError];
    XCTAssertNil(launchError);
    
    [task waitUntilExit];

    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    if (commandOutput) {
        *commandOutput = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    if (task.terminationStatus != 0) {
        NSLog(@"Failed to create RAR archive");
        return nil;
    }
    
    return archiveURL;
}

- (NSArray<NSURL *> *)multiPartArchiveWithName:(NSString *)baseName
{
    return [self multiPartArchiveWithName:baseName fileSize:100000];
}

- (NSArray<NSURL *> *)multiPartArchiveWithName:(NSString *)baseName fileSize:(NSUInteger)fileSize
{
    NSURL *textFile = [self randomTextFileOfLength:fileSize];
    
    // Generate multi-volume archive, with parts no larger than 20 KB in size
    NSString *commandOutputString = nil;
    [self archiveWithFiles:@[textFile]
                      name:baseName
                 arguments:@[@"-v20k"]
             commandOutput:&commandOutputString];
    
    NSMutableArray<NSString*> *volumePaths = [NSMutableArray arrayWithArray:
                                              [commandOutputString regexMatches:@"Creating archive (.+)"]];
    NSString *intendedFirstVolumePath = volumePaths.firstObject;
    
    // Fill in leading zeroes according to number of parts (no fewer than 2 digits)
    int numDigits = MAX(2, floor(log10(volumePaths.count)) + 1);
    NSString *zeroPadding = [@"" stringByPaddingToLength:numDigits - 1 withString:@"0" startingAtIndex:0];
    NSString *actualExtension = [NSString stringWithFormat:@"part%@1.rar", zeroPadding];
    
    NSString *firstVolumeDir = [intendedFirstVolumePath stringByDeletingLastPathComponent];
    NSString *actualFirstVolumePath = [firstVolumeDir stringByAppendingPathComponent:
                                       [baseName stringByReplacingOccurrencesOfString:@"rar"
                                                                           withString:actualExtension]];
    [volumePaths replaceObjectAtIndex:0 withObject:actualFirstVolumePath];
    
    NSMutableArray<NSURL*> *result = [NSMutableArray array];
    for (NSString *path in volumePaths) {
        [result addObject:[NSURL fileURLWithPath:path]];
    }
    
    return result;
}

- (NSArray<NSURL *> *)multiPartArchiveOldSchemeWithName:(NSString *)baseName
{
    NSURL *textFile = [self randomTextFileOfLength:100000];
    
    // Generate multi-volume archive, with parts no larger than 20 KB in size
    NSString *commandOutputString = nil;
    [self archiveWithFiles:@[textFile]
                      name:baseName
                 arguments:@[@"-v20k", // Volume size
                             @"-vn",   // Legacy naming
                             @"-ma4"]  // v4 archive format
             commandOutput:&commandOutputString];
    
    NSArray<NSString*> *volumePaths = [commandOutputString regexMatches:@"Creating archive (.+)"];

    NSMutableArray<NSURL*> *result = [NSMutableArray array];
    for (NSString *path in volumePaths) {
        [result addObject:[NSURL fileURLWithPath:path]];
    }
    
    return result;
}
#endif



@end


@implementation NSString (URKArchiveTestCaseExtensions)

- (NSArray<NSString*> *)regexMatches:(NSString *)expression
{
    NSError *regexCreationError = nil;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:expression
                                                                           options:0
                                                                             error:&regexCreationError];
    
    if (!regex) {
        NSLog(@"Failed to create regex with pattern '%@': %@", expression, regexCreationError);
        return @[];
    }
    
    NSMutableArray<NSString*> *results = [NSMutableArray array];

    [regex enumerateMatchesInString:self
                            options:0
                              range:NSMakeRange(0, self.length)
                         usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
                             [results addObject:[self substringWithRange:[result rangeAtIndex:1]]];
                         }];
    
    return results;
}

@end
