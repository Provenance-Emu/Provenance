#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITPersistence.h"
#import "BITPersistencePrivate.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

NSString *const BITPersistenceSuccessNotification = @"BITHockeyPersistenceSuccessNotification";

static NSString *const kBITTelemetry = @"Telemetry";
static NSString *const kBITMetaData = @"MetaData";
static NSString *const kBITFileBaseString = @"hockey-app-bundle-";
static NSString *const kBITFileBaseStringMeta = @"metadata";
static NSString *const kBITTelemetryDirectoryPath = @"com.microsoft.HockeyApp/Telemetry/";
static NSString *const kBITMetaDataDirectoryPath = @"com.microsoft.HockeyApp/MetaData/";

static char const *kBITPersistenceQueueString = "com.microsoft.HockeyApp.persistenceQueue";
static NSUInteger const BITDefaultFileCount = 50;

@interface BITPersistence ()

@property (nonatomic) BOOL directorySetupComplete;

@end

@implementation BITPersistence

#pragma mark - Public

- (instancetype)init {
  self = [super init];
  if (self) {
    _persistenceQueue = dispatch_queue_create(kBITPersistenceQueueString, DISPATCH_QUEUE_SERIAL); //TODO several queues?
    _requestedBundlePaths = [NSMutableArray new];
    _maxFileCount = BITDefaultFileCount;
    
    // Evantually, there will be old files on disk, the flag will be updated before the first event gets created
    _directorySetupComplete = NO; //will be set to true in createDirectoryStructureIfNeeded
    
    [self createDirectoryStructureIfNeeded];
  }
  return self;
}

/**
 * Saves the Bundle using NSKeyedArchiver and NSData's writeToFile:atomically
 * Sends out a BITHockeyPersistenceSuccessNotification in case of success
 */
- (void)persistBundle:(NSData *)bundle {
  //TODO send out a fail notification?
  NSString *fileURL = [self fileURLForType:BITPersistenceTypeTelemetry];
  
  if (bundle) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.persistenceQueue, ^{
      typeof(self) strongSelf = weakSelf;
      BOOL success = [bundle writeToFile:fileURL atomically:YES];
      if (success) {
        BITHockeyLogDebug(@"Wrote bundle to %@", fileURL);
        [strongSelf sendBundleSavedNotification];
      }
      else {
        BITHockeyLogError(@"Error writing bundle to %@", fileURL);
      }
    });
  }
  else {
    BITHockeyLogWarning(@"Unable to write %@ as provided bundle was null", fileURL);
  }
}

- (void)persistMetaData:(NSDictionary *)metaData {
  NSString *fileURL = [self fileURLForType:BITPersistenceTypeMetaData];
  //TODO send out a notification, too?!
  dispatch_async(self.persistenceQueue, ^{
    [NSKeyedArchiver archiveRootObject:metaData toFile:fileURL];
  });
}

- (BOOL)isFreeSpaceAvailable {
  NSArray *files = [self persistedFilesForType:BITPersistenceTypeTelemetry];
  return files.count < self.maxFileCount;
}

- (NSString *)requestNextFilePath {
  __block NSString *path = nil;
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;
    
    path = [strongSelf nextURLOfType:BITPersistenceTypeTelemetry];
    
    if (path) {
      [self.requestedBundlePaths addObject:path];
    }
  });
  return path;
}

- (NSDictionary *)metaData {
  NSString *filePath = [self fileURLForType:BITPersistenceTypeMetaData];
  NSObject *bundle = [self bundleAtFilePath:filePath withFileBaseString:kBITFileBaseStringMeta];
  if ([bundle isMemberOfClass:NSDictionary.class]) {
    return (NSDictionary *) bundle;
  }
  BITHockeyLogDebug(@"INFO: The context meta data file could not be loaded.");
  return [NSDictionary dictionary];
}

- (NSObject *)bundleAtFilePath:(NSString *)filePath withFileBaseString:(NSString *)filebaseString {
  id bundle = nil;
  if (filePath && [filePath rangeOfString:filebaseString].location != NSNotFound) {
    bundle = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
  }
  return bundle;
}

- (NSData *)dataAtFilePath:(NSString *)path {
  NSData *data = nil;
  if (path && [path rangeOfString:kBITFileBaseString].location != NSNotFound) {
    data = [NSData dataWithContentsOfFile:path];
  }
  return data;
}

/**
 * Deletes a file at the given path.
 *
 * @param path to look for a file and delete it.
 */
- (void)deleteFileAtPath:(NSString *)path {
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;
    if ([path rangeOfString:kBITFileBaseString].location != NSNotFound) {
      NSError *error = nil;
      if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
        BITHockeyLogError(@"Error deleting file at path %@", path);
      }
      else {
        BITHockeyLogDebug(@"Successfully deleted file at path %@", path);
        [strongSelf.requestedBundlePaths removeObject:path];
      }
    } else {
      BITHockeyLogDebug(@"Empty path, nothing to delete");
    }
  });
  
}

- (void)giveBackRequestedFilePath:(NSString *)filePath {
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;
    
    [strongSelf.requestedBundlePaths removeObject:filePath];
  });
}

#pragma mark - Private

- (NSString *)fileURLForType:(BITPersistenceType)type {
  NSArray<NSString *> *searchPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *appCachesPath = searchPaths.lastObject;

  NSString *fileName = nil;
  NSString *filePath;
  
  switch (type) {
    case BITPersistenceTypeMetaData: {
      fileName = kBITFileBaseStringMeta;
      filePath = [appCachesPath stringByAppendingPathComponent:kBITMetaDataDirectoryPath];
      break;
    };
    default: {
      NSString *uuid = bit_UUID();
      fileName = [NSString stringWithFormat:@"%@%@", kBITFileBaseString, uuid];
      filePath = [appCachesPath stringByAppendingPathComponent:kBITTelemetryDirectoryPath];
      break;
    };
  }
  
  filePath = [filePath stringByAppendingPathComponent:fileName];
  
  return filePath;
}

/**
 * Create directory structure if necessary and exclude it from iCloud backup
 */
- (void)createDirectoryStructureIfNeeded {
  //Caches Dir
  
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *appCachesURL = [[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
  if (appCachesURL) {
    NSError *error = nil;
    //Caches and Telemetry Directory
    NSURL *folderURL = [appCachesURL URLByAppendingPathComponent:kBITTelemetryDirectoryPath];
    //NOTE: createDirectoryAtURL:withIntermediateDirectories:attributes:error
    //will return YES if the directory already exists and won't override anything.
    //No need to check if the directory already exists.
    if (![fileManager createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:&error]) {
      BITHockeyLogError(@"%@", error.localizedDescription);
      return; //TODO we can't use persistence at all in this case, what do we want to do now? Notify the user?
    }
    
    //MetaData Directory
    folderURL = [appCachesURL URLByAppendingPathComponent:kBITMetaDataDirectoryPath];
    if (![fileManager createDirectoryAtURL:folderURL withIntermediateDirectories:NO attributes:nil error:&error]) {
      BITHockeyLogError(@"%@", error.localizedDescription);
      return; //TODO we can't use persistence at all in this case, what do we want to do now? Notify the user?
    }
    
    self.directorySetupComplete = YES;
  }
}

/**
 * @returns the URL to the next file depending on the specified type. If there's no file, return nil.
 */
- (NSString *)nextURLOfType:(BITPersistenceType)type {
  NSArray<NSURL *> *fileNames = [self persistedFilesForType:type];
  if (fileNames && fileNames.count > 0) {
    for (NSURL *filename in fileNames) {
      NSString *absolutePath = filename.path;
      if (![self.requestedBundlePaths containsObject:absolutePath]) {
        return absolutePath;
      }
    }
  }
  return nil;
}

- (NSArray *)persistedFilesForType: (BITPersistenceType)type {
  NSString *directoryPath = [self folderPathForType:type];
  NSError *error = nil;
  NSArray<NSURL *> *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directoryPath]
                                                              includingPropertiesForKeys:@[NSURLNameKey]
                                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   error:&error];
  return fileNames;
}

- (NSString *)folderPathForType:(BITPersistenceType)type {
  NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
  NSString *subFolder = @"";
  switch (type) {
    case BITPersistenceTypeTelemetry: {
      subFolder = kBITTelemetryDirectoryPath;
      break;
    }
    case BITPersistenceTypeMetaData: {
      subFolder = kBITMetaDataDirectoryPath;
      break;
    }
  }
  path = [path stringByAppendingPathComponent:subFolder];
  
  return path;
}

/**
 * Send a BITHockeyPersistenceSuccessNotification to the main thread to notify observers that we have successfully saved a file
 * This is typically used to trigger sending.
 */
- (void)sendBundleSavedNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    BITHockeyLogDebug(@"Sending notification: %@", BITPersistenceSuccessNotification);
    [[NSNotificationCenter defaultCenter] postNotificationName:BITPersistenceSuccessNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}

@end

#endif /* HOCKEYSDK_FEATURE_METRICS */

