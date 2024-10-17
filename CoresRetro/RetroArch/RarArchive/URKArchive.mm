//
//  URKArchive.mm
//  UnrarKit
//
//

#import "URKArchive.h"
#import "URKFileInfo.h"
#import "UnrarKitMacros.h"

#import "zlib.h"

RarHppIgnore
#import "rar.hpp"
#pragma clang diagnostic pop


NSString *URKErrorDomain = @"URKErrorDomain";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#if UNIFIED_LOGGING_SUPPORTED
os_log_t unrarkit_log;
BOOL unrarkitIsAtLeast10_13SDK;
#endif
#pragma clang diagnostic pop

static NSBundle *_resources = nil;

typedef enum : NSUInteger {
    URKReadHeaderLoopActionStopReading,
    URKReadHeaderLoopActionContinueReading,
} URKReadHeaderLoopAction;


@interface URKArchive ()

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError * __autoreleasing *)error
// iOS 7, macOS 10.9
#if (defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED > 70000) || (defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED > 1090)
NS_DESIGNATED_INITIALIZER
#endif
;

@property (assign) HANDLE rarFile;
@property (assign) struct RARHeaderDataEx *header;
@property (assign) struct RAROpenArchiveDataEx *flags;

@property (strong) NSData *fileBookmark;

@property (strong) NSObject *threadLock;

@property (copy) NSString *lastArchivePath;
@property (copy) NSString *lastFilepath;

@end


@implementation URKArchive



#pragma mark - Deprecated Convenience Methods


+ (URKArchive *)rarArchiveAtPath:(NSString *)filePath
{
    return [[URKArchive alloc] initWithPath:filePath error:nil];
}

+ (URKArchive *)rarArchiveAtURL:(NSURL *)fileURL
{
    return [[URKArchive alloc] initWithURL:fileURL error:nil];
}

+ (URKArchive *)rarArchiveAtPath:(NSString *)filePath password:(NSString *)password
{
    return [[URKArchive alloc] initWithPath:filePath password:password error:nil];
}

+ (URKArchive *)rarArchiveAtURL:(NSURL *)fileURL password:(NSString *)password
{
    return [[URKArchive alloc] initWithURL:fileURL password:password error:nil];
}



#pragma mark - Initializers


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSURL *resourcesURL = [mainBundle URLForResource:@"UnrarKitResources" withExtension:@"bundle"];
        
        _resources = (resourcesURL
                      ? [NSBundle bundleWithURL:resourcesURL]
                      : mainBundle);
        
        URKLogInit();
    });
}

- (instancetype)init {
    URKLogError("Attempted to use -init method, which is no longer supported");
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class URKArchive"
                                 userInfo:nil];
    return nil;
}

- (instancetype)initWithPath:(NSString *)filePath error:(NSError * __autoreleasing *)error
{
    return [self initWithFile:[NSURL fileURLWithPath:filePath] error:error];
}

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError * __autoreleasing *)error
{
    return [self initWithFile:fileURL error:error];
}

- (instancetype)initWithPath:(NSString *)filePath password:(NSString *)password error:(NSError * __autoreleasing *)error
{
    return [self initWithFile:[NSURL fileURLWithPath:filePath] password:password error:error];
}

- (instancetype)initWithURL:(NSURL *)fileURL password:(NSString *)password error:(NSError * __autoreleasing *)error
{
    return [self initWithFile:fileURL password:password error:error];
}

- (instancetype)initWithFile:(NSURL *)fileURL error:(NSError * __autoreleasing *)error
{
    return [self initWithFile:fileURL password:nil error:error];
}

- (instancetype)initWithFile:(NSURL *)fileURL password:(NSString*)password error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Init Archive");

    URKLogInfo("Initializing archive with URL %{public}@, path %{public}@, password %{public}@", fileURL, fileURL.path, [password length] != 0 ? @"given" : @"not given");
    
    if (!fileURL) {
        URKLogError("Cannot initialize archive with nil URL");
        return nil;
    }

    if ((self = [super init])) {
        if (error) {
            *error = nil;
        }
        
        NSURL *firstVolumeURL = [URKArchive firstVolumeURL:fileURL];
        NSString * _Nonnull fileURLAbsoluteString = static_cast<NSString * _Nonnull>(fileURL.absoluteString);
        if (firstVolumeURL && ![firstVolumeURL.absoluteString isEqualToString:fileURLAbsoluteString]) {
            URKLogDebug("Overriding fileURL with first volume URL: %{public}@", firstVolumeURL);
            fileURL = firstVolumeURL;
        }
        
        URKLogDebug("Initializing private fields");

        NSError *bookmarkError = nil;
        _fileBookmark = [fileURL bookmarkDataWithOptions:0
                          includingResourceValuesForKeys:@[]
                                           relativeToURL:nil
                                                   error:&bookmarkError];
        _password = password;
        _threadLock = [[NSObject alloc] init];
        
        _lastArchivePath = nil;
        _lastFilepath = nil;
        _ignoreCRCMismatches = NO;

        if (bookmarkError) {
            URKLogFault("Error creating bookmark to RAR archive: %{public}@", bookmarkError);

            if (error) {
                *error = bookmarkError;
            }

            return nil;
        }
    }

    return self;
}


#pragma mark - Properties


- (NSURL *)fileURL
{
    URKCreateActivity("Read Archive URL");

    BOOL bookmarkIsStale = NO;
    NSError *error = nil;

    NSURL *result = [NSURL URLByResolvingBookmarkData:self.fileBookmark
                                              options:0
                                        relativeToURL:nil
                                  bookmarkDataIsStale:&bookmarkIsStale
                                                error:&error];

    if (error) {
        URKLogFault("Error resolving bookmark to RAR archive: %{public}@", error);
        return nil;
    }

    if (bookmarkIsStale) {
        URKLogDebug("Refreshing stale bookmark");
        self.fileBookmark = [result bookmarkDataWithOptions:0
                             includingResourceValuesForKeys:@[]
                                              relativeToURL:nil
                                                      error:&error];

        if (error) {
            URKLogFault("Error creating fresh bookmark to RAR archive: %{public}@", error);
        }
  }

    return result;
}

- (NSString *)filename
{
    URKCreateActivity("Read Archive Filename");
    
    NSURL *url = self.fileURL;

    if (!url) {
        return nil;
    }

    return url.path;
}

- (NSNumber *)uncompressedSize
{
    URKCreateActivity("Read Archive Uncompressed Size");

    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (!fileInfo) {
        URKLogError("Error getting uncompressed size: %{public}@", listError);
        return nil;
    }
    
    if (fileInfo.count == 0) {
        URKLogInfo("No files in archive. Size == 0");
        return 0;
    }
        
    return [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];
}

- (NSNumber *)compressedSize
{
    URKCreateActivity("Read Archive Compressed Size");

    NSString *filePath = self.filename;
    
    if (!filePath) {
        URKLogError("Can't get compressed size, since a file path can't be resolved");
        return nil;
    }
    
    URKLogInfo("Reading archive file attributes...");
    NSError *attributesError = nil;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath
                                                                                error:&attributesError];
    
    if (!attributes) {
        URKLogError("Error getting compressed size of %{public}@: %{public}@", filePath, attributesError);
        return nil;
    }
    
    return [NSNumber numberWithUnsignedLongLong:attributes.fileSize];
}

- (BOOL)hasMultipleVolumes
{
    URKCreateActivity("Check If Multi-Volume Archive");
    
    NSError *listError = nil;
    NSArray<NSURL*> *volumeURLs = [self listVolumeURLs:&listError];
    
    if (!volumeURLs) {
        URKLogError("Error getting file volumes list: %{public}@", listError);
        return false;
    }
    
    return volumeURLs.count > 1;
}



#pragma mark - Zip file detection


+ (BOOL)pathIsARAR:(NSString *)filePath
{
    URKCreateActivity("Determining File Type (Path)");

    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];

    if (!handle) {
        URKLogError("No file handle returned for path: %{public}@", filePath);
        return NO;
    }

    @try {
        NSData *fileData = [handle readDataOfLength:8];

        if (fileData.length < 8) {
            URKLogDebug("No file handle returned for path: %{public}@", filePath);
            return NO;
        }

        const unsigned char *dataBytes = (const unsigned char *)fileData.bytes;

        // Check the magic numbers for all versions (Rar!..)
        if (dataBytes[0] != 0x52 ||
            dataBytes[1] != 0x61 ||
            dataBytes[2] != 0x72 ||
            dataBytes[3] != 0x21 ||
            dataBytes[4] != 0x1A ||
            dataBytes[5] != 0x07) {
            URKLogDebug("File is not a RAR. Magic numbers != 'Rar!..'");
            return NO;
        }

        // Check for v1.5 and on
        if (dataBytes[6] == 0x00) {
            URKLogDebug("File is a RAR >= v1.5");
            return YES;
        }

        // Check for v5.0
        if (dataBytes[6] == 0x01 &&
            dataBytes[7] == 0x00) {
            URKLogDebug("File is a RAR >= v5.0");
            return YES;
        }

        URKLogDebug("File is not a RAR. Unknown contents in 7th and 8th bytes (%02X %02X)", dataBytes[6], dataBytes[7]);
    }
    @catch (NSException *e) {
        URKLogError("Error checking if %{public}@ is a RAR archive: %{public}@", filePath, e);
    }
    @finally {
        [handle closeFile];
    }

    return NO;
}

+ (BOOL)urlIsARAR:(NSURL *)fileURL
{
    URKCreateActivity("Determining File Type (URL)");

    if (!fileURL || !fileURL.path) {
        URKLogDebug("File is not a RAR: nil URL or path");
        return NO;
    }

    NSString *_Nonnull path = static_cast<NSString *_Nonnull>(fileURL.path);
    return [URKArchive pathIsARAR:path];
}



#pragma mark - Public Methods


- (NSArray<NSString*> *)listFilenames:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Listing Filenames");

    NSArray *files = [self listFileInfo:error];
    return [files valueForKey:@"filename"];
}

- (NSArray<URKFileInfo*> *)listFileInfo:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Listing File Info");

    NSMutableSet<NSString*> *distinctFilenames = [NSMutableSet set];
    NSMutableArray<URKFileInfo*> *distinctFileInfo = [NSMutableArray array];
    NSError *innerError = nil;

    BOOL wasSuccessful = [self iterateFileInfo:^(URKFileInfo * _Nonnull fileInfo, BOOL * _Nonnull stop) {
        if (![distinctFilenames containsObject:fileInfo.filename]) {
            [distinctFileInfo addObject:fileInfo];
            [distinctFilenames addObject:fileInfo.filename];
        } else {
            URKLogDebug("Skipping %{public}@ from list of file info, since it's already represented (probably from another archive volume)", fileInfo.filename);
        }
    }
                    error:&innerError];
    
    if (!wasSuccessful) {
        URKLogError("Failed to iterate file info: %{public}@", innerError);
        
        if (error && innerError) {
            *error = innerError;
        }
        
        return nil;
    }
    
    URKLogDebug("Found %lu file info items", (unsigned long)distinctFileInfo.count);
    return [NSArray arrayWithArray:distinctFileInfo];
}

- (BOOL) iterateFileInfo:(void(^)(URKFileInfo *fileInfo, BOOL *stop))action
                   error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Iterating File Info");
    NSAssert(action != nil, @"'action' is a required argument");

    NSError *innerError = nil;

    URKLogDebug("Beginning to iterate through contents of %{public}@", self.filename);
    
    BOOL wasSuccessful = [self iterateAllFileInfo:action
                                            error:&innerError];
    
    if (!wasSuccessful) {
        URKLogError("Failed to iterate all file info: %{public}@", innerError);
        
        if (error && innerError) {
            *error = innerError;
        }
        
        return NO;
    }
    
    return YES;
}

- (nullable NSArray<NSURL*> *)listVolumeURLs:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Listing Volume URLs");

    NSArray<URKFileInfo*> *allFileInfo = [self allFileInfo:error];
    
    if (!allFileInfo) {
        return nil;
    }
    
    NSMutableSet<NSURL*> *volumeURLs = [[NSMutableSet alloc] init];
    
    for (URKFileInfo* info in allFileInfo) {
        NSURL *archiveURL = [NSURL fileURLWithPath:info.archiveName];
        
        if (archiveURL) {
            [volumeURLs addObject:archiveURL];
        }
    }

    SEL sortBySelector = @selector(path);
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(sortBySelector) ascending:YES];
    NSArray<NSURL*> *sortedVolumes = [volumeURLs sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    return sortedVolumes;
}

- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
                 error:(NSError * __autoreleasing *)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractFilesTo:filePath
                      overwrite:overwrite
                       progress:nil
                          error:error];
#pragma clang diagnostic pop
}

- (BOOL)extractFilesTo:(NSString *)filePath
             overwrite:(BOOL)overwrite
              progress:(void (^)(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed))progressBlock
                 error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Extracting Files to Directory");

    __block BOOL result = YES;

    NSError *listError = nil;
    NSArray *fileInfos = [self listFileInfo:&listError];

    if (!fileInfos || listError) {
        URKLogError("Error listing contents of archive: %{public}@", listError);

        if (error) {
            *error = listError;
        }

        return NO;
    }

    NSNumber *totalSize = [fileInfos valueForKeyPath:@"@sum.uncompressedSize"];
    __block long long bytesDecompressed = 0;

    NSProgress *progress = [self beginProgressOperation:totalSize.longLongValue];
    progress.kind = NSProgressKindFile;
    
    URKLogDebug("Archive has total size of %{iec-bytes}lld", totalSize.longLongValue);
	
    __weak URKArchive *welf = self;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing File Extraction");

        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;
        
        URKLogInfo("Extracting to %{public}@", filePath);

        URKLogDebug("Reading through RAR header looking for files...");
        while ([welf readHeader:&RHCode info:&fileInfo] == URKReadHeaderLoopActionContinueReading) {
            URKLogDebug("Extracting %{public}@ (%{iec-bytes}lld)", fileInfo.filename, fileInfo.uncompressedSize);
            NSURL *extractedURL = [[NSURL fileURLWithPath:filePath] URLByAppendingPathComponent:fileInfo.filename];
            [progress setUserInfoObject:extractedURL
                                 forKey:NSProgressFileURLKey];
            [progress setUserInfoObject:fileInfo
                                 forKey:URKProgressInfoKeyFileInfoExtracting];
            
            if ([welf headerContainsErrors:innerError]) {
                URKLogError("Header contains an error")
                result = NO;
                return;
            }
            
            if (progress.isCancelled) {
                NSString *errorName = nil;
                [welf assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
                URKLogInfo("Halted file extraction due to user cancellation: %{public}@", errorName);
                result = NO;
                return;
            }

            char cFilePath[2048];
            BOOL utf8ConversionSucceeded = [filePath getCString:cFilePath
                                                      maxLength:sizeof(cFilePath)
                                                       encoding:NSUTF8StringEncoding];
            if (!utf8ConversionSucceeded) {
                NSString *errorName = nil;
                [welf assignError:innerError code:URKErrorCodeStringConversion errorName:&errorName];
                URKLogError("Error converting file to UTF-8 (buffer too short?)");
                result = NO;
                return;
            }
            
            BOOL (^shouldCancelBlock)() = ^BOOL {
                URKCreateActivity("shouldCancelBlock");
                URKLogDebug("Progress.isCancelled: %{public}@", progress.isCancelled ? @"YES" : @"NO")
                return progress.isCancelled;
            };
            RARSetCallback(welf.rarFile, AllowCancellationCallbackProc, (long)shouldCancelBlock);

            PFCode = RARProcessFile(welf.rarFile, RAR_EXTRACT, cFilePath, NULL);
            if (![welf didReturnSuccessfully:PFCode]) {
                RARSetCallback(welf.rarFile, NULL, NULL);
                
                NSString *errorName = nil;
                NSInteger errorCode = progress.isCancelled ? URKErrorCodeUserCancelled : PFCode;
                [welf assignError:innerError code:errorCode errorName:&errorName];
                URKLogError("Error extracting file: %{public}@ (%ld)", errorName, (long)errorCode);
                result = NO;
                return;
            }

            progress.completedUnitCount += fileInfo.uncompressedSize;
            URKLogDebug("Finished extracting %{public}@. Extraction %f complete", fileInfo.filename, progress.fractionCompleted);
            
            if (progressBlock) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdouble-promotion"
                // I would change the signature of this block, but it's been deprecated already,
                // so it'll just get dropped eventually, and it made sense to silence the warning
                progressBlock(fileInfo, bytesDecompressed / totalSize.floatValue);
#pragma clang diagnostic pop
            }

            bytesDecompressed += fileInfo.uncompressedSize;
        }
        
        RARSetCallback(welf.rarFile, NULL, NULL);
        
        if (![welf didReturnSuccessfully:RHCode]) {
            NSString *errorName = nil;
            [welf assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading file header: %{public}@ (%d)", errorName, RHCode);
            result = NO;
        }
        
        if (progressBlock) {
            progressBlock(fileInfo, 1.0);
        }

    } inMode:RAR_OM_EXTRACT error:error];

    return success && result;
}

- (NSData *)extractData:(URKFileInfo *)fileInfo
                  error:(NSError * __autoreleasing *)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractDataFromFile:fileInfo.filename progress:nil error:error];
#pragma clang diagnostic pop
}

- (NSData *)extractData:(URKFileInfo *)fileInfo
               progress:(void (^)(CGFloat percentDecompressed))progressBlock
                  error:(NSError * __autoreleasing *)error
{
    return [self extractDataFromFile:fileInfo.filename progress:progressBlock error:error];
}

- (NSData *)extractDataFromFile:(NSString *)filePath
                          error:(NSError * __autoreleasing *)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self extractDataFromFile:filePath progress:nil error:error];
#pragma clang diagnostic pop
}

- (NSData *)extractDataFromFile:(NSString *)filePath
                       progress:(void (^)(CGFloat percentDecompressed))progressBlock
                          error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Extracting Data from File");
    
    NSProgress *progress = [self beginProgressOperation:0];

    __block NSData *result = nil;
    __weak URKArchive *welf = self;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing Extraction");

        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        URKLogDebug("Reading through RAR header looking for files...");
        while ([welf readHeader:&RHCode info:&fileInfo] == URKReadHeaderLoopActionContinueReading) {
            if ([welf headerContainsErrors:innerError]) {
                URKLogError("Header contains an error")
                return;
            }

            if ([fileInfo.filename isEqualToString:filePath]) {
                URKLogDebug("Extracting %{public}@", fileInfo.filename);
                break;
            }
            else {
                URKLogDebug("Skipping %{public}@", fileInfo.filename);
                if ((PFCode = RARProcessFileW(welf.rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                    NSString *errorName = nil;
                    [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                    URKLogError("Error skipping file: %{public}@ (%d)", errorName, PFCode);
                    return;
                }
            }
        }

        if (RHCode != ERAR_SUCCESS) {
            NSString *errorName = nil;
            [welf assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading file header: %{public}@ (%d)", errorName, RHCode);
            return;
        }

        // Empty file, or a directory
        if (fileInfo.uncompressedSize == 0) {
            URKLogDebug("%{public}@ is empty or a directory", fileInfo.filename);
            result = [NSData data];
            return;
        }

        NSMutableData *fileData = [NSMutableData dataWithCapacity:(NSUInteger)fileInfo.uncompressedSize];
        CGFloat totalBytes = fileInfo.uncompressedSize;
        progress.totalUnitCount = totalBytes;
        __block long long bytesRead = 0;

        if (progressBlock) {
            progressBlock(0.0);
        }

        BOOL (^bufferedReadBlock)(NSData*) = ^BOOL(NSData *dataChunk) {
            URKLogDebug("Appending buffered data (%lu bytes)", (unsigned long)dataChunk.length);
            [fileData appendData:dataChunk];
            progress.completedUnitCount += dataChunk.length;

            bytesRead += dataChunk.length;

            if (progressBlock) {
                progressBlock(bytesRead / totalBytes);
            }
            
            if (progress.isCancelled) {
                URKLogInfo("Cancellation initiated");
                return NO;
            }
            
            return YES;
        };
        RARSetCallback(welf.rarFile, BufferedReadCallbackProc, (long)bufferedReadBlock);

        URKLogInfo("Processing file...");
        PFCode = RARProcessFile(welf.rarFile, RAR_TEST, NULL, NULL);
        
        RARSetCallback(welf.rarFile, NULL, NULL);
        
        if (progress.isCancelled) {
            NSString *errorName = nil;
            [welf assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
            URKLogInfo("Returning nil data from extraction due to user cancellation: %{public}@", errorName);
            return;
        }

        if (![welf didReturnSuccessfully:PFCode]) {
            NSString *errorName = nil;
            [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
            URKLogError("Error extracting file data: %{public}@ (%d)", errorName, PFCode);
            return;
        }

        result = [NSData dataWithData:fileData];
    } inMode:RAR_OM_EXTRACT error:error];

    if (!success) {
        return nil;
    }

    return result;
}

- (BOOL)performOnFilesInArchive:(void(^)(URKFileInfo *fileInfo, BOOL *stop))action
                          error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Performing Action on Each File");

    URKLogInfo("Listing file info");
    
    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];

    if (listError || !fileInfo) {
        URKLogError("Failed to list the files in the archive: %{public}@", listError);

        if (error) {
            *error = listError;
        }

        return NO;
    }
    
    
    NSProgress *progress = [self beginProgressOperation:fileInfo.count];

    URKLogInfo("Sorting file info by name/path");
    
    NSArray *sortedFileInfo = [fileInfo sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"filename" ascending:YES]]];

    {
        URKCreateActivity("Iterating Each File Info");
        
        [sortedFileInfo enumerateObjectsUsingBlock:^(URKFileInfo *info, NSUInteger idx, BOOL *stop) {
            if (progress.isCancelled) {
                URKLogInfo("PerformOnFiles iteration was cancelled");
                *stop = YES;
            }

            URKLogDebug("Performing action on %{public}@", info.filename);
            action(info, stop);
            progress.completedUnitCount += 1;
            
            if (*stop) {
                URKLogInfo("Action dictated an early stop");
                progress.completedUnitCount = progress.totalUnitCount;
            }
        }];
    }

    return YES;
}

- (BOOL)performOnDataInArchive:(void (^)(URKFileInfo *, NSData *, BOOL *))action
                         error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("Performing Action on Each File's Data");

    NSError *listError = nil;
    NSArray *fileInfo = [self listFileInfo:&listError];
    
    if (!fileInfo || listError) {
        URKLogError("Error listing contents of archive: %{public}@", listError);
        
        if (error) {
            *error = listError;
        }
        
        return NO;
    }
    
    NSNumber *totalSize = [fileInfo valueForKeyPath:@"@sum.uncompressedSize"];
    __weak URKArchive *welf = self;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        int RHCode = 0, PFCode = 0;

        BOOL stop = NO;

        NSProgress *progress = [welf beginProgressOperation:totalSize.longLongValue];
        
        URKLogDebug("Reading through RAR header looking for files...");

        URKFileInfo *info = nil;
        while ([welf readHeader:&RHCode info:&info] == URKReadHeaderLoopActionContinueReading) {
            if (stop || progress.isCancelled) {
                URKLogDebug("Action dictated an early stop");
                return;
            }
            
            if ([welf headerContainsErrors:innerError]) {
                URKLogError("Header contains an error")
                return;
            }
            
            URKLogDebug("Performing action on %{public}@", info.filename);

            // Empty file, or a directory
            if (info.isDirectory || info.uncompressedSize == 0) {
                URKLogDebug("%{public}@ is an empty file, or a directory", info.filename);
                action(info, [NSData data], &stop);
                PFCode = RARProcessFile(welf.rarFile, RAR_SKIP, NULL, NULL);
                if (PFCode != 0) {
                    NSString *errorName = nil;
                    [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                    URKLogError("Error skipping directory: %{public}@ (%d)", errorName, PFCode);
                    return;
                }
                
                continue;
            }

            UInt8 *buffer = (UInt8 *)malloc((size_t)info.uncompressedSize * sizeof(UInt8));
            UInt8 *callBackBuffer = buffer;

            RARSetCallback(welf.rarFile, CallbackProc, (long) &callBackBuffer);

            URKLogInfo("Processing file...");
            PFCode = RARProcessFile(welf.rarFile, RAR_TEST, NULL, NULL);

            if (![welf didReturnSuccessfully:PFCode]) {
                NSString *errorName = nil;
                [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                URKLogError("Error processing file: %{public}@ (%d)", errorName, PFCode);
                return;
            }

            URKLogDebug("Performing action on data (%lld bytes)", info.uncompressedSize);
            NSData *data = [NSData dataWithBytesNoCopy:buffer length:(NSUInteger)info.uncompressedSize freeWhenDone:YES];
            action(info, data, &stop);
            
            progress.completedUnitCount += data.length;
        }
        
        if (progress.isCancelled) {
            NSString *errorName = nil;
            [welf assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
            URKLogInfo("Returning NO from performOnData:error: due to user cancellation: %{public}@", errorName);
            return;
        }

        if (![welf didReturnSuccessfully:RHCode]) {
            NSString *errorName = nil;
            [welf assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading file header: %{public}@ (%d)", errorName, RHCode);
            return;
        }
    } inMode:RAR_OM_EXTRACT error:error];

    return success;
}

- (BOOL)extractBufferedDataFromFile:(NSString *)filePath
                              error:(NSError * __autoreleasing *)error
                             action:(void(^)(NSData *dataChunk, CGFloat percentDecompressed))action
{
    URKCreateActivity("Extracting Buffered Data");

    NSError *actionError = nil;

    NSProgress *progress = [self beginProgressOperation:0];

    __weak URKArchive *welf = self;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing action");

        int RHCode = 0, PFCode = 0;
        URKFileInfo *fileInfo;

        URKLogInfo("Looping through files, looking for %{public}@...", filePath);
        
        while ([welf readHeader:&RHCode info:&fileInfo] == URKReadHeaderLoopActionContinueReading) {
            if ([welf headerContainsErrors:innerError]) {
                URKLogDebug("Header contains error")
                return;
            }

            if ([fileInfo.filename isEqualToString:filePath]) {
                URKLogDebug("Found desired file");
                break;
            }
            else {
                URKLogDebug("Skipping file...");
                PFCode = RARProcessFile(welf.rarFile, RAR_SKIP, NULL, NULL);
                if (![welf didReturnSuccessfully:PFCode]) {
                    NSString *errorName = nil;
                    [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                    URKLogError("Failed to skip file: %{public}@ (%d)", errorName, PFCode);
                    return;
                }
            }
        }
        
        long long totalBytes = fileInfo.uncompressedSize;
        progress.totalUnitCount = totalBytes;
        
        if (![welf didReturnSuccessfully:RHCode]) {
            NSString *errorName = nil;
            [welf assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Header read yielded error: %{public}@ (%d)", errorName, RHCode);
            return;
        }

        // Empty file, or a directory
        if (totalBytes == 0) {
            URKLogInfo("File is empty or a directory");
            return;
        }

        __block long long bytesRead = 0;

        // Repeating the argument instead of using positional specifiers, because they don't work with the {} formatters
        URKLogDebug("Uncompressed size: %{iec-bytes}lld (%lld bytes) in file", totalBytes, totalBytes);

        BOOL (^bufferedReadBlock)(NSData*) = ^BOOL(NSData *dataChunk) {
            if (progress.isCancelled) {
                URKLogInfo("Buffered data read cancelled");
                return NO;
            }
            
            bytesRead += dataChunk.length;
            progress.completedUnitCount += dataChunk.length;

            double progressPercent = bytesRead / static_cast<double>(totalBytes);
            URKLogDebug("Read data chunk of size %lu (%.3f%% complete). Calling handler...", (unsigned long)dataChunk.length, progressPercent * 100);
            action(dataChunk, progressPercent);
            return YES;
        };
        RARSetCallback(welf.rarFile, BufferedReadCallbackProc, (long)bufferedReadBlock);

        URKLogDebug("Processing file...");
        PFCode = RARProcessFile(welf.rarFile, RAR_TEST, NULL, NULL);
        
        RARSetCallback(welf.rarFile, NULL, NULL);

        if (progress.isCancelled) {
            NSString *errorName = nil;
            [welf assignError:innerError code:URKErrorCodeUserCancelled errorName:&errorName];
            URKLogError("Buffered data extraction has been cancelled: %{public}@", errorName);
            return;
        }
        
        if (![welf didReturnSuccessfully:PFCode]) {
            NSString *errorName = nil;
            [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
            URKLogError("Error processing file: %{public}@ (%d)", errorName, PFCode);
        }
    } inMode:RAR_OM_EXTRACT error:&actionError];

    if (error) {
        *error = actionError;

        if (actionError) {
            URKLogError("Error reading buffered data from file\nfilePath: %{public}@\nerror: %{public}@", filePath, actionError);
        }
    }

    return success && !actionError;
}

- (BOOL)isPasswordProtected
{
    URKCreateActivity("Checking Password Protection");

    @try {
        URKLogDebug("Opening archive");
        
        NSError *error = nil;
        if (![self _unrarOpenFile:self.filename
                           inMode:RAR_OM_EXTRACT
                     withPassword:nil
                            error:&error])
        {
            URKLogError("Failed to open archive while checking for password: %{public}@", error);
            return NO;
        }

        URKLogDebug("Reading header and starting processing...");
        
        int RHCode = RARReadHeaderEx(self.rarFile, self.header);
        int PFCode = RARProcessFile(self.rarFile, RAR_SKIP, NULL, NULL);

        URKLogDebug("Checking header");
        if ([self headerContainsErrors:&error]) {
            if (error.code == ERAR_MISSING_PASSWORD) {
                URKLogDebug("Password is missing");
                return YES;
            }

            URKLogError("Errors in header while checking for password: %{public}@", error);
        }

        if (RHCode == ERAR_MISSING_PASSWORD || PFCode == ERAR_MISSING_PASSWORD) {
            URKLogDebug("Missing password indicated by RHCode (%d) or PFCode (%d)", RHCode, PFCode);
            return YES;
        }
    }
    @finally {
        [self closeFile];
    }

    URKLogDebug("Archive is not password protected");
    return NO;
}

- (BOOL)validatePassword
{
    URKCreateActivity("Validating Password");

    __block NSError *error = nil;
    __block BOOL passwordIsGood = YES;
    __weak URKArchive *welf = self;

    BOOL success = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing action");

        URKLogDebug("Opening and processing archive...");
        
        int RHCode = RARReadHeaderEx(welf.rarFile, welf.header);
        int PFCode = RARProcessFile(welf.rarFile, RAR_TEST, NULL, NULL);

        if ([welf headerContainsErrors:innerError]) {
            if (error.code == ERAR_MISSING_PASSWORD) {
                URKLogDebug("Password invalidated by header");
                passwordIsGood = NO;
            }
            else {
                URKLogError("Errors in header while validating password: %{public}@", error);
            }

            return;
        }

        if (RHCode == ERAR_MISSING_PASSWORD || PFCode == ERAR_MISSING_PASSWORD
            || RHCode == ERAR_BAD_PASSWORD || PFCode == ERAR_BAD_PASSWORD)
        {
            URKLogDebug("Missing/bad password indicated by RHCode (%d) or PFCode (%d)", RHCode, PFCode);
            passwordIsGood = NO;
            return;
        }
        
        if ([welf hasBadCRC:RHCode] || [welf hasBadCRC:PFCode]) {
            URKLogDebug("Missing/bad password indicated via CRC mismatch by RHCode (%d) or PFCode (%d)", RHCode, PFCode);
            passwordIsGood = NO;
            return;
        }
    } inMode:RAR_OM_EXTRACT error:&error];

    if (!success) {
        URKLogError("Error validating password: %{public}@", error);
        return NO;
    }
    
    return passwordIsGood;
}

- (BOOL)checkDataIntegrity
{
    return [self checkDataIntegrityOfFile:(NSString *_Nonnull)nil];
}

- (BOOL)checkDataIntegrityIgnoringCRCMismatches:(BOOL(^)())ignoreCRCMismatches
{
    int rhCode = [self dataIntegrityCodeOfFile:nil];
    if (rhCode == ERAR_SUCCESS) {
        return YES;
    }
    
    if (rhCode == ERAR_BAD_DATA) {
        NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
        
        __block BOOL blockResult;
        
        if ([NSOperationQueue currentQueue] == mainQueue) {
            blockResult = ignoreCRCMismatches();
        } else {
            [mainQueue addOperations:@[[NSBlockOperation blockOperationWithBlock:^{
                blockResult = ignoreCRCMismatches();
            }]]
                   waitUntilFinished:YES];
        }

        self.ignoreCRCMismatches = blockResult;
        return self.ignoreCRCMismatches;
    }
    
    return NO;
}

- (BOOL)checkDataIntegrityOfFile:(NSString *)filePath {
    return [self dataIntegrityCodeOfFile:filePath] == ERAR_SUCCESS;
}

- (int)dataIntegrityCodeOfFile:(NSString *)filePath
{
    URKCreateActivity("Checking Data Integrity");

    URKLogInfo("Checking integrity of %{public}@", filePath ? filePath : @"whole archive");

    __block int RHCode = 0;
    __block int PFCode = 0;

    __weak URKArchive *welf = self;

    NSError *performOnFilesError = nil;
    BOOL wasSuccessful = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Iterating through each file");
        while (true) {
            URKFileInfo *fileInfo = nil;
            [welf readHeader:&RHCode info:&fileInfo];
            welf.lastFilepath = nil;
            welf.lastArchivePath = nil;
            
            if (RHCode == ERAR_END_ARCHIVE) {
                RHCode = ERAR_SUCCESS;
                break;
            }
            
            if (filePath && ![fileInfo.filename isEqualToString:filePath]) continue;
            
            if (RHCode != ERAR_SUCCESS) {
                break;
            }
            
            if ((PFCode = RARProcessFile(welf.rarFile, RAR_TEST, NULL, NULL)) != ERAR_SUCCESS) {
                RHCode = PFCode;
                break;
            }

            if (filePath) {
                break;
            }
        }
    } inMode:RAR_OM_EXTRACT error:&performOnFilesError];
    
    if (RHCode == ERAR_END_ARCHIVE) {
        RHCode = ERAR_SUCCESS;
    }
    
    if (performOnFilesError) {
        URKLogError("Error checking data integrity: %{public}@", performOnFilesError);
    }
    
    if (!wasSuccessful) {
        URKLogError("Error checking data integrity");
        if (RHCode == ERAR_SUCCESS) {
            RHCode = ERAR_UNKNOWN;
        }
    }
    
    return RHCode;
}


#pragma mark - Callback Functions


int CALLBACK CallbackProc(UINT msg, long UserData, long P1, long P2) {
    URKCreateActivity("CallbackProc");

    UInt8 **buffer;

    switch(msg) {
        case UCM_CHANGEVOLUME:
            URKLogDebug("msg: UCM_CHANGEVOLUME");
            break;

        case UCM_PROCESSDATA:
            URKLogDebug("msg: UCM_PROCESSDATA; Copying data");
            buffer = (UInt8 **) UserData;
            memcpy(*buffer, (UInt8 *)P1, P2);
            // advance the buffer ptr, original m_buffer ptr is untouched
            *buffer += P2;
            break;

        case UCM_NEEDPASSWORD:
            URKLogDebug("msg: UCM_NEEDPASSWORD");
            break;
    }

    return 0;
}

int CALLBACK BufferedReadCallbackProc(UINT msg, long UserData, long P1, long P2) {
    URKCreateActivity("BufferedReadCallbackProc");
    BOOL (^bufferedReadBlock)(NSData*) = (__bridge BOOL(^)(NSData*))(void *)UserData;

    if (msg == UCM_PROCESSDATA) {
        @autoreleasepool {
            URKLogDebug("msg: UCM_PROCESSDATA; Copying data chunk and calling read block");
            NSData *dataChunk = [NSData dataWithBytes:(UInt8 *)P1 length:P2];
            BOOL cancelRequested = !bufferedReadBlock(dataChunk);
            
            if (cancelRequested) {
                return -1;
            }
        }
    }

    return 0;
}

int CALLBACK AllowCancellationCallbackProc(UINT msg, long UserData, long P1, long P2) {
    URKCreateActivity("AllowCancellationCallbackProc");
    BOOL (^shouldCancelBlock)() = (__bridge BOOL(^)())(void *)UserData;

    if (!shouldCancelBlock) {
        return 0;
    }
    
    BOOL shouldCancel = shouldCancelBlock();
    if (shouldCancel) {
        URKLogDebug("Operation cancelled in shouldCancelBlock()");
    }
    
    return shouldCancel ? -1 : 0;
}



#pragma mark - Private Methods


- (BOOL)performActionWithArchiveOpen:(void(^)(NSError **innerError))action
                              inMode:(NSInteger)mode
                               error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("-performActionWithArchiveOpen:inMode:error:");

    @synchronized(self.threadLock) {
        URKLogDebug("Entered lock");
        
        if (error) {
            URKLogDebug("Error pointer passed in");
            *error = nil;
        }

        URKLogDebug("Opening archive");
        NSError *openFileError = nil;
        
        if (![self _unrarOpenFile:self.filename
                           inMode:mode
                     withPassword:self.password
                            error:&openFileError]) {
            URKLogError("Failed to open archive: %{public}@", openFileError);
            
            if (error) {
                *error = openFileError;
            }
            
            return NO;
        }

        NSError *actionError = nil;
        
        @try {
            URKLogDebug("Calling action block");
            action(&actionError);
        }
        @finally {
            [self closeFile];
        }

        if (actionError) {
            URKLogError("Action block returned error: %{public}@", actionError);
            
            if (error){
                *error = actionError;
            }
        }
        
        return !actionError;
    }
}

- (BOOL)_unrarOpenFile:(NSString *)rarFile inMode:(NSInteger)mode withPassword:(NSString *)aPassword error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("-_unrarOpenFile:inMode:withPassword:error:");

    if (error) {
        URKLogDebug("Error pointer passed in");
        *error = nil;
    }

    URKLogDebug("Zeroing out fields...");
    
    ErrHandler.Clean();

    self.header = new RARHeaderDataEx;
    bzero(self.header, sizeof(RARHeaderDataEx));
	self.flags = new RAROpenArchiveDataEx;
    bzero(self.flags, sizeof(RAROpenArchiveDataEx));

    URKLogDebug("Setting archive name...");
    
    self.flags->ArcName = strdup(rarFile.UTF8String);
    self.flags->OpenMode = (uint)mode;
    self.flags->OpFlags = self.ignoreCRCMismatches ? ROADOF_KEEPBROKEN : 0;

    URKLogDebug("Opening archive %{public}@...", rarFile);
    
    self.rarFile = RAROpenArchiveEx(self.flags);
    if (self.rarFile == 0 || self.flags->OpenResult != 0) {
        NSString *errorName = nil;
        [self assignError:error code:(NSInteger)self.flags->OpenResult errorName:&errorName];
        URKLogError("Error opening archive: %{public}@ (%d)", errorName, self.flags->OpenResult);
        return NO;
    }

    self.lastFilepath = nil;
    self.lastArchivePath = nil;

    if (aPassword != nil) {
        URKLogDebug("Setting password...");
        
        char cPassword[2048];
        BOOL utf8ConversionSucceeded = [aPassword getCString:cPassword
                                                   maxLength:sizeof(cPassword)
                                                    encoding:NSUTF8StringEncoding];
        if (!utf8ConversionSucceeded) {
            NSString *errorName = nil;
            [self assignError:error code:URKErrorCodeStringConversion errorName:&errorName];
            URKLogError("Error converting password to UTF-8 (buffer too short?)");
            return NO;
        }
        
        RARSetPassword(self.rarFile, cPassword);
    }

	return YES;
}

- (BOOL)closeFile
{
    URKCreateActivity("-closeFile");

    if (self.rarFile) {
        URKLogDebug("Closing archive %{public}@...", self.filename);
        RARCloseArchive(self.rarFile);
    }
    
    URKLogDebug("Cleaning up fields...");
    
    self.rarFile = 0;

    if (self.flags)
        delete self.flags->ArcName;
    delete self.flags; self.flags = 0;
    delete self.header; self.header = 0;
    return YES;
}

- (BOOL) iterateAllFileInfo:(void(^)(URKFileInfo *fileInfo, BOOL *stop))action
                      error:(NSError * __autoreleasing *)error
{
    URKCreateActivity("-allFileInfo:");
    NSAssert(action != nil, @"'action' is a required argument");
    
    __weak URKArchive *welf = self;
    
    BOOL wasSuccessful = [self performActionWithArchiveOpen:^(NSError **innerError) {
        URKCreateActivity("Performing List Action");
        
        int RHCode = 0, PFCode = 0;
        
        URKLogDebug("Reading through RAR header looking for files...");
        
        URKFileInfo *info = nil;
        while ([welf readHeader:&RHCode info:&info] == URKReadHeaderLoopActionContinueReading) {
            URKLogDebug("Calling iterateAllFileInfo handler");
            BOOL shouldStop = NO;
            action(info, &shouldStop);
            
            if (shouldStop) {
                URKLogDebug("iterateAllFileInfo got signal to stop");
                return;
            }
            
            URKLogDebug("Skipping to next file...");
            if ((PFCode = RARProcessFile(welf.rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                NSString *errorName = nil;
                [welf assignError:innerError code:(NSInteger)PFCode errorName:&errorName];
                URKLogError("Error skipping to next header file: %{public}@ (%d)", errorName, PFCode);
                return;
            }
        }
        
        if (![welf didReturnSuccessfully:RHCode]) {
            NSString *errorName = nil;
            [welf assignError:innerError code:RHCode errorName:&errorName];
            URKLogError("Error reading RAR header: %{public}@ (%d)", errorName, RHCode);
        }
    } inMode:RAR_OM_LIST_INCSPLIT error:error];
    
    return wasSuccessful;
}

- (NSArray<URKFileInfo *> *) allFileInfo:(NSError * __autoreleasing *)error {
    URKCreateActivity("-allFileInfo:");
    
    NSMutableArray *fileInfos = [NSMutableArray array];
    NSError *innerError = nil;
    
    URKLogDebug("Iterating all file info");
    BOOL wasSuccessful = [self iterateAllFileInfo:^(URKFileInfo *fileInfo, BOOL *stop) {
        [fileInfos addObject:fileInfo];
    }
                       error:&innerError];
    
    if (!wasSuccessful || !fileInfos) {
        URKLogError("File info iteration was not successful: %{public}@", innerError);

        if (error && innerError) {
            *error = innerError;
        }
        
        return nil;
    }
    
    URKLogDebug("Found %lu files", (unsigned long)fileInfos.count);
    return [NSArray arrayWithArray:fileInfos];
}

- (NSString *)errorNameForErrorCode:(NSInteger)errorCode detail:(NSString * __autoreleasing *)errorDetail
{
    NSAssert(errorDetail != NULL, @"errorDetail out parameter not given");
    
    NSString *errorName;
    NSString *detail = @"";

    switch (errorCode) {
        case URKErrorCodeEndOfArchive:
            errorName = @"ERAR_END_ARCHIVE";
            break;

        case URKErrorCodeNoMemory:
            errorName = @"ERAR_NO_MEMORY";
            detail = NSLocalizedStringFromTableInBundle(@"Ran out of memory while reading archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeBadData:
            errorName = @"ERAR_BAD_DATA";
            detail = NSLocalizedStringFromTableInBundle(@"Archive has a corrupt header", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeBadArchive:
            errorName = @"ERAR_BAD_ARCHIVE";
            detail = NSLocalizedStringFromTableInBundle(@"File is not a valid RAR archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeUnknownFormat:
            errorName = @"ERAR_UNKNOWN_FORMAT";
            detail = NSLocalizedStringFromTableInBundle(@"RAR headers encrypted in unknown format", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeOpen:
            errorName = @"ERAR_EOPEN";
            detail = NSLocalizedStringFromTableInBundle(@"Failed to open a reference to the file", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeCreate:
            errorName = @"ERAR_ECREATE";
            detail = NSLocalizedStringFromTableInBundle(@"Failed to create the target directory for extraction", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeClose:
            errorName = @"ERAR_ECLOSE";
            detail = NSLocalizedStringFromTableInBundle(@"Error encountered while closing the archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeRead:
            errorName = @"ERAR_EREAD";
            detail = NSLocalizedStringFromTableInBundle(@"Error encountered while reading the archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeWrite:
            errorName = @"ERAR_EWRITE";
            detail = NSLocalizedStringFromTableInBundle(@"Error encountered while writing a file to disk", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeSmall:
            errorName = @"ERAR_SMALL_BUF";
            detail = NSLocalizedStringFromTableInBundle(@"Buffer too small to contain entire comments", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeUnknown:
            errorName = @"ERAR_UNKNOWN";
            detail = NSLocalizedStringFromTableInBundle(@"An unknown error occurred", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeMissingPassword:
            errorName = @"ERAR_MISSING_PASSWORD";
            detail = NSLocalizedStringFromTableInBundle(@"No password given to unlock a protected archive", @"UnrarKit", _resources, @"Error detail string");
            break;

        case URKErrorCodeArchiveNotFound:
            errorName = @"ERAR_ARCHIVE_NOT_FOUND";
            detail = NSLocalizedStringFromTableInBundle(@"Unable to find the archive", @"UnrarKit", _resources, @"Error detail string");
            break;
            
        case URKErrorCodeUserCancelled:
            errorName = @"ERAR_USER_CANCELLED";
            detail = NSLocalizedStringFromTableInBundle(@"User cancelled the operation in progress", @"UnrarKit", _resources, @"Error detail string");
            break;
            

        case URKErrorCodeStringConversion:
            errorName = @"ERAR_UTF8_PATH_CONVERSION";
            detail = NSLocalizedStringFromTableInBundle(@"Error converting a string to UTF-8", @"UnrarKit", _resources, @"Error detail string");
            break;
        case URKErrorCodeBadPassword:
            URKLogError("If you're seeing this, you should be calling -[URKArchive validatePassword] before attempting to extract from a password-protected archive");
            errorName = @"ERAR_BAD_PASSWORD";
            detail = NSLocalizedStringFromTableInBundle(@"Provided password is incorrect", @"UnrarKit", _resources, @"Error detail string");
            break;

        default:
            errorName = [NSString stringWithFormat:@"Unknown (%ld)", (long)errorCode];
            detail = [NSString localizedStringWithFormat:NSLocalizedStringFromTableInBundle(@"Unknown error encountered (code %ld)", @"UnrarKit", _resources, @"Error detail string"), (long)errorCode];
            break;
    }

    *errorDetail = detail;
    return errorName;
}

- (BOOL)assignError:(NSError * __autoreleasing *)error code:(NSInteger)errorCode errorName:(NSString * __autoreleasing *)outErrorName
{
    return [self assignError:error code:errorCode underlyer:nil errorName:outErrorName];
}

- (BOOL)assignError:(NSError * __autoreleasing *)error code:(NSInteger)errorCode underlyer:(NSError *)underlyingError errorName:(NSString * __autoreleasing *)outErrorName
{
    NSAssert(outErrorName, @"An out variable for errorName must be provided");
    
    NSString *errorDetail = nil;
    *outErrorName = [self errorNameForErrorCode:errorCode detail:&errorDetail];

    if (error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:
                                         @{NSLocalizedFailureReasonErrorKey: *outErrorName,
                                           NSLocalizedDescriptionKey: errorDetail,
                                           NSLocalizedRecoverySuggestionErrorKey: errorDetail}];
        
        if (self.fileURL) {
            userInfo[NSURLErrorKey] = self.fileURL;
        }
        
        if (underlyingError) {
            userInfo[NSUnderlyingErrorKey] = underlyingError;
        }
        
        *error = [NSError errorWithDomain:URKErrorDomain
                                     code:errorCode
                                 userInfo:userInfo];
    }

    return NO;
}

- (BOOL)headerContainsErrors:(NSError * __autoreleasing *)error
{
    URKCreateActivity("-headerContainsErrors:");

    BOOL isPasswordProtected = self.header->Flags & 0x04;

    if (isPasswordProtected && !self.password) {
        NSString *errorName = nil;
        [self assignError:error code:ERAR_MISSING_PASSWORD errorName:&errorName];
        URKLogError("Password protected and no password specified: %{public}@ (%d)", errorName, ERAR_MISSING_PASSWORD);
        return YES;
    }

    return NO;
}

- (NSProgress *)beginProgressOperation:(unsigned long long)totalUnitCount
{
    URKCreateActivity("-beginProgressOperation:");
    
    NSProgress *progress;
    progress = self.progress;
    self.progress = nil;
    
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress]
                                             userInfo:nil];
    }
    
    if (totalUnitCount > 0) {
        progress.totalUnitCount = totalUnitCount;
    }
    
    progress.cancellable = YES;
    progress.pausable = NO;
    
    return progress;
}

+ (NSURL *)firstVolumeURL:(NSURL *)volumeURL {
    URKCreateActivity("+firstVolumeURL:");

    URKLogDebug("Checking if the file is part of a multi-volume archive...");
    
    if (!volumeURL) {
        URKLogError("+firstVolumeURL: nil volumeURL passed")
    }
    
    NSString *volumePath = volumeURL.path;

    NSError *regexError = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.part)([0-9]+)(.rar)$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&regexError];
    if (!regex) {
        URKLogError("Error constructing filename regex")
        return nil;
    }
    
    NSString *firstVolumePath = nil;
    
    // Check if it's following the current convention, like "Archive.part03.rar"
    NSTextCheckingResult *match = [regex firstMatchInString:volumePath options:0 range:NSMakeRange(0, volumePath.length)];
    if (match) {
        URKLogDebug("The file is part of a multi-volume archive");
        
        NSRange numberRange = [match rangeAtIndex:2];
        NSString * partOne = [[@"" stringByPaddingToLength:numberRange.length - 1
                                                withString:@"0"
                                           startingAtIndex:0]
                              stringByAppendingString:@"1"];
        
        NSString * regexTemplate = [NSString stringWithFormat:@"$1%@$3", partOne];
        firstVolumePath = [regex stringByReplacingMatchesInString:volumePath
                                                          options:0
                                                            range:NSMakeRange(0, volumePath.length)
                                                     withTemplate:regexTemplate];
    }

    // It still might be a multivolume archive. Check for the legacy naming convention, like "Archive.r03"
    else {
        // After rXX, rar uses r-z and symbols like {}|~... so accepting anything but a number
        NSError *legacyRegexError = nil;
        regex = [NSRegularExpression regularExpressionWithPattern:@"(\\.[^0-9])([0-9]+)$"
                                                          options:NSRegularExpressionCaseInsensitive
                                                            error:&legacyRegexError];
        
        if (!regex) {
            URKLogError("Error constructing legacy filename regex")
            return nil;
        }
        
        match = [regex firstMatchInString:volumePath options:0 range:NSMakeRange(0, volumePath.length)];
        if (match) {
            URKLogDebug("The archive is part of a legacy volume");
            firstVolumePath = [[volumePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"rar"];
        }
    }
    
    // If it's a volume of either naming convention, use it
    if (firstVolumePath) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:firstVolumePath]) {
            URKLogDebug("First volume part %{public}@ found. Using as the main archive", firstVolumePath);
            return [NSURL fileURLWithPath:firstVolumePath];
        }
        else {
            URKLogInfo("First volume part not found: %{public}@. Skipping first volume selection", firstVolumePath);
            return nil;
        }
    }
    
    return volumeURL;
}

- (URKReadHeaderLoopAction) readHeader:(int *)returnCode
                                  info:(URKFileInfo *__autoreleasing *)info
{
    NSAssert(returnCode != NULL, @"otherReturnCode argument is required");
    NSAssert(info != NULL, @"info argument is required");

    URKLogDebug("Reading RAR header");
    *returnCode = RARReadHeaderEx(self.rarFile, self.header);
    URKLogDebug("Reading file info from RAR header");
    *info = [URKFileInfo fileInfo:self.header];
    URKLogDebug("RARReadHeaderEx returned %d", *returnCode);

    URKReadHeaderLoopAction result;
    
    switch (*returnCode) {
        case ERAR_SUCCESS:
            result = URKReadHeaderLoopActionContinueReading;
            break;
            
        case ERAR_END_ARCHIVE:
            URKLogDebug("Successful return code from RARReadHeaderEx");
            result = URKReadHeaderLoopActionStopReading;
            break;
            
        case ERAR_BAD_DATA:
            if (self.ignoreCRCMismatches) {
                URKLogError("Ignoring CRC mismatch in %{public}@", (*info).filename);
                result = URKReadHeaderLoopActionContinueReading;
            } else {
                URKLogError("CRC mismatch when reading %{public}@. To read the archive and ignore CRC mismatches, use -checkDataIntegrityIgnoringCRCMismatches:", (*info).filename);
                result = URKReadHeaderLoopActionStopReading;
            }
            break;
            
        default:
            result = URKReadHeaderLoopActionStopReading;
            break;
    }
    
    if (result == URKReadHeaderLoopActionContinueReading
        && [self.lastFilepath isEqualToString:(*info).filename]
        && [self.lastArchivePath isEqualToString:(*info).archiveName])
    {
        URKLogInfo("Same header returned twice. Presuming archive done being read. Probably a bad CRC")
        result = URKReadHeaderLoopActionStopReading;
    }

    self.lastFilepath = (result == URKReadHeaderLoopActionStopReading
                         ? nil
                         : (*info).filename);
    self.lastArchivePath = (result == URKReadHeaderLoopActionStopReading
                            ? nil
                            : (*info).archiveName);

    return result;
}

- (BOOL)didReturnSuccessfully:(int)returnCode {
    return (returnCode == ERAR_SUCCESS
            || returnCode == ERAR_END_ARCHIVE
            || (returnCode == ERAR_BAD_DATA && self.ignoreCRCMismatches));
}

- (BOOL)hasBadCRC:(int)returnCode {
    return returnCode == ERAR_BAD_DATA && !self.ignoreCRCMismatches;
}

@end
