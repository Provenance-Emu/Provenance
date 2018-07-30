/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_CRASH_REPORTER

#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>

#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyHelper+Application.h"
#import "BITHockeyAppClient.h"

#import "BITCrashManager.h"
#import "BITCrashManagerPrivate.h"
#import "BITCrashAttachment.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITCrashReportTextFormatter.h"
#import "BITCrashDetailsPrivate.h"
#import "BITCrashCXXExceptionHandler.h"

#if HOCKEYSDK_FEATURE_METRICS
#import "BITMetricsManagerPrivate.h"
#import "BITChannel.h"
#import "BITPersistencePrivate.h"
#endif

#include <sys/sysctl.h>

// stores the set of crashreports that have been approved but aren't sent yet
#define kBITCrashApprovedReports @"HockeySDKCrashApprovedReports"

// keys for meta information associated to each crash
#define kBITCrashMetaUserName @"BITCrashMetaUserName"
#define kBITCrashMetaUserEmail @"BITCrashMetaUserEmail"
#define kBITCrashMetaUserID @"BITCrashMetaUserID"
#define kBITCrashMetaApplicationLog @"BITCrashMetaApplicationLog"
#define kBITCrashMetaAttachment @"BITCrashMetaAttachment"

// internal keys
static NSString *const KBITAttachmentDictIndex = @"index";
static NSString *const KBITAttachmentDictAttachment = @"attachment";

static NSString *const kBITCrashManagerStatus = @"BITCrashManagerStatus";

static NSString *const kBITAppWentIntoBackgroundSafely = @"BITAppWentIntoBackgroundSafely";
static NSString *const kBITAppDidReceiveLowMemoryNotification = @"BITAppDidReceiveLowMemoryNotification";
static NSString *const kBITAppMarketingVersion = @"BITAppMarketingVersion";
static NSString *const kBITAppVersion = @"BITAppVersion";
static NSString *const kBITAppOSVersion = @"BITAppOSVersion";
static NSString *const kBITAppOSBuild = @"BITAppOSBuild";
static NSString *const kBITAppUUIDs = @"BITAppUUIDs";

static NSString *const kBITFakeCrashUUID = @"BITFakeCrashUUID";
static NSString *const kBITFakeCrashAppMarketingVersion = @"BITFakeCrashAppMarketingVersion";
static NSString *const kBITFakeCrashAppVersion = @"BITFakeCrashAppVersion";
static NSString *const kBITFakeCrashAppBundleIdentifier = @"BITFakeCrashAppBundleIdentifier";
static NSString *const kBITFakeCrashOSVersion = @"BITFakeCrashOSVersion";
static NSString *const kBITFakeCrashDeviceModel = @"BITFakeCrashDeviceModel";
static NSString *const kBITFakeCrashAppBinaryUUID = @"BITFakeCrashAppBinaryUUID";
static NSString *const kBITFakeCrashReport = @"BITFakeCrashAppString";

// We need BIT_UNUSED macro to make sure there aren't any warnings when building
// HockeySDK Distribution scheme. Since several configurations are build in this scheme
// and different features can be turned on and off we can't just use __unused attribute.
#if HOCKEYSDK_FEATURE_METRICS
static char const *BITSaveEventsFilePath;
#define BIT_UNUSED
#else
#define BIT_UNUSED __unused
#endif

static BITCrashManagerCallbacks bitCrashCallbacks = {
  .context = NULL,
  .handleSignal = NULL
};

#if HOCKEYSDK_FEATURE_METRICS
static void bit_save_events_callback(siginfo_t __unused *info, ucontext_t __unused *uap, void __unused *context) {
  
  // Do not flush metrics queue if queue is empty (metrics module disabled) to not freeze the app
  if (!BITTelemetryEventBuffer) {
    return;
  }
  
  // Try to get a file descriptor with our pre-filled path
  int fd = open(BITSaveEventsFilePath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd < 0) {
    return;
  }
  
  size_t len = strlen(BITTelemetryEventBuffer);
  if (len > 0) {
    // Simply write the whole string to disk
    write(fd, BITTelemetryEventBuffer, len);
  }
  close(fd);
}
#endif

// Proxy implementation for PLCrashReporter to keep our interface stable while this can change
static void plcr_post_crash_callback (BIT_UNUSED siginfo_t *info, BIT_UNUSED ucontext_t *uap, void *context) {
#if HOCKEYSDK_FEATURE_METRICS
  bit_save_events_callback(info, uap, context);
#endif
  if (bitCrashCallbacks.handleSignal != NULL) {
    bitCrashCallbacks.handleSignal(context);
  }
}

static PLCrashReporterCallbacks plCrashCallbacks = {
  .version = 0,
  .context = NULL,
  .handleSignal = plcr_post_crash_callback
};

// Temporary class until PLCR catches up
// We trick PLCR with an Objective-C exception.
//
// This code provides us access to the C++ exception message, including a correct stack trace.
//
@interface BITCrashCXXExceptionWrapperException : NSException

- (instancetype)initWithCXXExceptionInfo:(const BITCrashUncaughtCXXExceptionInfo *)info;

@property (nonatomic, readonly) const BITCrashUncaughtCXXExceptionInfo *info;

@end

@implementation BITCrashCXXExceptionWrapperException

- (instancetype)initWithCXXExceptionInfo:(const BITCrashUncaughtCXXExceptionInfo *)info {
  extern char* __cxa_demangle(const char* mangled_name, char* output_buffer, size_t* length, int* status);
  char *demangled_name = &__cxa_demangle ? __cxa_demangle(info->exception_type_name ?: "", NULL, NULL, NULL) : NULL;
  
  if ((self = [super
               initWithName:(NSString *)[NSString stringWithUTF8String:demangled_name ?: info->exception_type_name ?: ""]
               reason:[NSString stringWithUTF8String:info->exception_message ?: ""]
               userInfo:nil])) {
    _info = info;
  }
  return self;
}

- (NSArray *)callStackReturnAddresses {
  NSMutableArray *cxxFrames = [NSMutableArray arrayWithCapacity:self.info->exception_frames_count];
  
  for (uint32_t i = 0; i < self.info->exception_frames_count; ++i) {
    [cxxFrames addObject:[NSNumber numberWithUnsignedLongLong:self.info->exception_frames[i]]];
  }
  return cxxFrames;
}

@end


// C++ Exception Handler
__attribute__((noreturn)) static void uncaught_cxx_exception_handler(const BITCrashUncaughtCXXExceptionInfo *info) {
  // This relies on a LOT of sneaky internal knowledge of how PLCR works and should not be considered a long-term solution.
  NSGetUncaughtExceptionHandler()([[BITCrashCXXExceptionWrapperException alloc] initWithCXXExceptionInfo:info]);
  abort();
}

@interface BITCrashManager ()

@property (nonatomic, strong) NSMutableDictionary *approvedCrashReports;
@property (nonatomic, strong) NSMutableArray *crashFiles;
@property (nonatomic, copy) NSString *settingsFile;
@property (nonatomic, copy) NSString *analyzerInProgressFile;
@property (nonatomic) BOOL crashIdenticalCurrentVersion;
@property (nonatomic) BOOL sendingInProgress;
@property (nonatomic) BOOL isSetup;
@property (nonatomic) BOOL didLogLowMemoryWarning;
@property (nonatomic, weak) id appDidBecomeActiveObserver;
@property (nonatomic, weak) id appWillTerminateObserver;
@property (nonatomic, weak) id appDidEnterBackgroundObserver;
@property (nonatomic, weak) id appWillEnterForegroundObserver;
@property (nonatomic, weak) id appDidReceiveLowMemoryWarningObserver;
@property (nonatomic, weak) id networkDidBecomeReachableObserver;

// Redeclare BITCrashManager properties with readwrite attribute
@property (nonatomic, readwrite) NSTimeInterval timeIntervalCrashInLastSessionOccurred;
@property (nonatomic, readwrite) BITCrashDetails *lastSessionCrashDetails;
@property (nonatomic, readwrite) BOOL didCrashInLastSession;
@property (nonatomic, readwrite) BOOL didReceiveMemoryWarningInLastSession;

@end

@implementation BITCrashManager

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier appEnvironment:(BITEnvironment)environment hockeyAppClient:(BITHockeyAppClient *)hockeyAppClient {
  if ((self = [super initWithAppIdentifier:appIdentifier appEnvironment:environment])) {
    _delegate = nil;
    _isSetup = NO;
    
    _hockeyAppClient = hockeyAppClient;
    
    _showAlwaysButton = YES;
    _alertViewHandler = nil;
    
    _plCrashReporter = nil;
    _exceptionHandler = nil;
    
    _crashIdenticalCurrentVersion = YES;
    
    _didCrashInLastSession = NO;
    _timeIntervalCrashInLastSessionOccurred = -1;
    _didLogLowMemoryWarning = NO;
    
    _approvedCrashReports = [[NSMutableDictionary alloc] init];
    
    _fileManager = [[NSFileManager alloc] init];
    _crashFiles = [[NSMutableArray alloc] init];
    
    _crashManagerStatus = BITCrashManagerStatusAlwaysAsk;
    
    if ([[NSUserDefaults standardUserDefaults] stringForKey:kBITCrashManagerStatus]) {
      _crashManagerStatus = (BITCrashManagerStatus)[[NSUserDefaults standardUserDefaults] integerForKey:kBITCrashManagerStatus];
    } else {
      // migrate previous setting if available
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"BITCrashAutomaticallySendReports"]) {
        _crashManagerStatus = BITCrashManagerStatusAutoSend;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BITCrashAutomaticallySendReports"];
      }
      [[NSUserDefaults standardUserDefaults] setInteger:_crashManagerStatus forKey:kBITCrashManagerStatus];
    }
    
    _crashesDir = bit_settingsDir();
    _settingsFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_SETTINGS];
    _analyzerInProgressFile = [_crashesDir stringByAppendingPathComponent:BITHOCKEY_CRASH_ANALYZER];
    
    
    if (!BITHockeyBundle() && !bit_isRunningInAppExtension()) {
      BITHockeyLogWarning(@"[HockeySDK] WARNING: %@ is missing, will send reports automatically!", BITHOCKEYSDK_BUNDLE);
    }
  }
  return self;
}


- (void) dealloc {
  [self unregisterObservers];
}


- (void)setCrashManagerStatus:(BITCrashManagerStatus)crashManagerStatus {
  _crashManagerStatus = crashManagerStatus;
  
  [[NSUserDefaults standardUserDefaults] setInteger:crashManagerStatus forKey:kBITCrashManagerStatus];
}

- (void)setServerURL:(NSString *)serverURL {
  if ([serverURL isEqualToString:super.serverURL]) { return; }
  
  super.serverURL = serverURL;
  self.hockeyAppClient = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:serverURL]];
}

#pragma mark - Private

/**
 * Save all settings
 *
 * This saves the list of approved crash reports
 */
- (void)saveSettings {
  NSError *error = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  if (self.approvedCrashReports && [self.approvedCrashReports count] > 0) {
    [rootObj setObject:self.approvedCrashReports forKey:kBITCrashApprovedReports];
  }
  
  NSData *plist = [NSPropertyListSerialization dataWithPropertyList:(id)rootObj format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
  
  if (plist) {
    [plist writeToFile:self.settingsFile atomically:YES];
  } else {
    BITHockeyLogError(@"ERROR: Writing settings. %@", [error description]);
  }
}

/**
 * Load all settings
 *
 * This contains the list of approved crash reports
 */
- (void)loadSettings {
  NSError *error = nil;
  NSPropertyListFormat format;
  
  if (![self.fileManager fileExistsAtPath:self.settingsFile])
    return;
  
  NSData *plist = [NSData dataWithContentsOfFile:self.settingsFile];
  if (plist) {
    NSDictionary *rootObj = (NSDictionary *)[NSPropertyListSerialization
                                             propertyListWithData:plist
                                             options:NSPropertyListMutableContainersAndLeaves
                                             format:&format
                                             error:&error];
    
    if ([rootObj objectForKey:kBITCrashApprovedReports])
      [self.approvedCrashReports setDictionary:(NSDictionary *)[rootObj objectForKey:kBITCrashApprovedReports]];
  } else {
    BITHockeyLogError(@"ERROR: Reading crash manager settings.");
  }
}


/**
 * Remove a cached crash report
 *
 *  @param filename The base filename of the crash report
 */
- (void)cleanCrashReportWithFilename:(NSString *)filename {
  if (!filename) return;
  
  NSError *error = NULL;
  
  [self.fileManager removeItemAtPath:filename error:&error];
  [self.fileManager removeItemAtPath:[filename stringByAppendingString:@".data"] error:&error];
  [self.fileManager removeItemAtPath:[filename stringByAppendingString:@".meta"] error:&error];
  [self.fileManager removeItemAtPath:[filename stringByAppendingString:@".desc"] error:&error];
  
  NSString *cacheFilename = [filename lastPathComponent];
  [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserName]];
  [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserEmail]];
  [self removeKeyFromKeychain:[NSString stringWithFormat:@"%@.%@", cacheFilename, kBITCrashMetaUserID]];
  
  [self.crashFiles removeObject:filename];
  [self.approvedCrashReports removeObjectForKey:filename];
  
  [self saveSettings];
}

/**
 *	 Remove all crash reports and stored meta data for each from the file system and keychain
 *
 * This is currently only used as a helper method for tests
 */
- (void)cleanCrashReports {
  for (NSUInteger i=0; i < [self.crashFiles count]; i++) {
    [self cleanCrashReportWithFilename:[self.crashFiles objectAtIndex:i]];
  }
}

- (BOOL)persistAttachment:(BITHockeyAttachment *)attachment withFilename:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
  
  [archiver encodeObject:attachment forKey:kBITCrashMetaAttachment];
  
  [archiver finishEncoding];
  
  return [data writeToFile:attachmentFilename atomically:YES];
}

- (void)persistUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  if (!userProvidedMetaData) return;
  
  if (userProvidedMetaData.userProvidedDescription && [userProvidedMetaData.userProvidedDescription length] > 0) {
    NSError *error;
    [userProvidedMetaData.userProvidedDescription writeToFile:[NSString stringWithFormat:@"%@.desc", [self.crashesDir stringByAppendingPathComponent: self.lastCrashFilename]] atomically:YES encoding:NSUTF8StringEncoding error:&error];
  }
  
  if (userProvidedMetaData.userName && [userProvidedMetaData.userName length] > 0) {
    [self addStringValueToKeychain:userProvidedMetaData.userName forKey:[NSString stringWithFormat:@"%@.%@", self.lastCrashFilename, kBITCrashMetaUserName]];
    
  }
  
  if (userProvidedMetaData.userEmail && [userProvidedMetaData.userEmail length] > 0) {
    [self addStringValueToKeychain:userProvidedMetaData.userEmail forKey:[NSString stringWithFormat:@"%@.%@", self.lastCrashFilename, kBITCrashMetaUserEmail]];
  }
  
  if (userProvidedMetaData.userID && [userProvidedMetaData.userID length] > 0) {
    [self addStringValueToKeychain:userProvidedMetaData.userID forKey:[NSString stringWithFormat:@"%@.%@", self.lastCrashFilename, kBITCrashMetaUserID]];
    
  }
}

/**
 *  Read the attachment data from the stored file
 *
 *  @param filename The crash report file path
 *
 *  @return an BITHockeyAttachment instance or nil
 */
- (BITHockeyAttachment *)attachmentForCrashReport:(NSString *)filename {
  NSString *attachmentFilename = [filename stringByAppendingString:@".data"];
  
  if (![self.fileManager fileExistsAtPath:attachmentFilename])
    return nil;
  
  
  NSData *codedData = [[NSData alloc] initWithContentsOfFile:attachmentFilename];
  if (!codedData)
    return nil;
  
  NSKeyedUnarchiver *unarchiver = nil;
  
  @try {
    unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:codedData];
  }
  @catch (NSException __unused *exception) {
    return nil;
  }
  
  if ([unarchiver containsValueForKey:kBITCrashMetaAttachment]) {
    BITHockeyAttachment *attachment = [unarchiver decodeObjectForKey:kBITCrashMetaAttachment];
    return attachment;
  }
  
  return nil;
}

/**
 *	 Extract all app specific UUIDs from the crash reports
 *
 * This allows us to send the UUIDs in the XML construct to the server, so the server does not need to parse the crash report for this data.
 * The app specific UUIDs help to identify which dSYMs are needed to symbolicate this crash report.
 *
 *	@param	report The crash report from PLCrashReporter
 *
 *	@return XML structure with the app specific UUIDs
 */
- (NSString *) extractAppUUIDs:(BITPLCrashReport *)report {
  NSMutableString *uuidString = [NSMutableString string];
  NSArray *uuidArray = [BITCrashReportTextFormatter arrayOfAppUUIDsForCrashReport:report];
  
  for (NSDictionary *element in uuidArray) {
    if ([element objectForKey:kBITBinaryImageKeyType] && [element objectForKey:kBITBinaryImageKeyArch] && [element objectForKey:kBITBinaryImageKeyUUID]) {
      [uuidString appendFormat:@"<uuid type=\"%@\" arch=\"%@\">%@</uuid>",
       [element objectForKey:kBITBinaryImageKeyType],
       [element objectForKey:kBITBinaryImageKeyArch],
       [element objectForKey:kBITBinaryImageKeyUUID]
       ];
    }
  }
  
  return uuidString;
}

- (void) registerObservers {
  __weak typeof(self) weakSelf = self;
  
  if(nil == self.appDidBecomeActiveObserver) {
    NSNotificationName name = UIApplicationDidBecomeActiveNotification;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (bit_isRunningInAppExtension() && &NSExtensionHostDidBecomeActiveNotification != NULL) {
      name = NSExtensionHostDidBecomeActiveNotification;
    }
#pragma clang diagnostic pop
    self.appDidBecomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                                                        object:nil
                                                                                         queue:NSOperationQueue.mainQueue
                                                                                    usingBlock:^(NSNotification __unused *note) {
                                                                                      typeof(self) strongSelf = weakSelf;
                                                                                      [strongSelf triggerDelayedProcessing];
                                                                                    }];
  }
  
  if(nil == self.networkDidBecomeReachableObserver) {
    self.networkDidBecomeReachableObserver = [[NSNotificationCenter defaultCenter] addObserverForName:BITHockeyNetworkDidBecomeReachableNotification
                                                                                               object:nil
                                                                                                queue:NSOperationQueue.mainQueue
                                                                                           usingBlock:^(NSNotification __unused *note) {
                                                                                             typeof(self) strongSelf = weakSelf;
                                                                                             [strongSelf triggerDelayedProcessing];
                                                                                           }];
  }
  
  if (nil ==  self.appWillTerminateObserver) {
    self.appWillTerminateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                                                      object:nil
                                                                                       queue:NSOperationQueue.mainQueue
                                                                                  usingBlock:^(NSNotification __unused *note) {
                                                                                    typeof(self) strongSelf = weakSelf;
                                                                                    [strongSelf leavingAppSafely];
                                                                                  }];
  }
  
  if (nil ==  self.appDidEnterBackgroundObserver) {
    NSNotificationName name = UIApplicationDidEnterBackgroundNotification;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (bit_isRunningInAppExtension() && &NSExtensionHostDidEnterBackgroundNotification != NULL) {
      name = NSExtensionHostDidEnterBackgroundNotification;
    }
#pragma clang diagnostic pop
    self.appDidEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                                                           object:nil
                                                                                            queue:NSOperationQueue.mainQueue
                                                                                       usingBlock:^(NSNotification __unused *note) {
                                                                                         typeof(self) strongSelf = weakSelf;
                                                                                         [strongSelf leavingAppSafely];
                                                                                       }];
  }
  
  if (nil == self.appWillEnterForegroundObserver) {
    NSNotificationName name = UIApplicationWillEnterForegroundNotification;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (bit_isRunningInAppExtension() && &NSExtensionHostWillEnterForegroundNotification != NULL) {
      name = NSExtensionHostWillEnterForegroundNotification;
    }
#pragma clang diagnostic pop
    self.appWillEnterForegroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                                                            object:nil
                                                                                             queue:NSOperationQueue.mainQueue
                                                                                        usingBlock:^(NSNotification __unused *note) {
                                                                                          typeof(self) strongSelf = weakSelf;
                                                                                          [strongSelf appEnteredForeground];
                                                                                        }];
  }
  
  if (nil == self.appDidReceiveLowMemoryWarningObserver) {
    if (bit_isRunningInAppExtension()) {
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, DISPATCH_MEMORYPRESSURE_WARN|DISPATCH_MEMORYPRESSURE_CRITICAL, dispatch_get_main_queue());
        dispatch_source_set_event_handler(source, ^{
          if (!self.didLogLowMemoryWarning) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppDidReceiveLowMemoryNotification];
            self.didLogLowMemoryWarning = YES;
          }
        });
        dispatch_resume(source);
      });
    } else {
      self.appDidReceiveLowMemoryWarningObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
                                                                                                     object:nil
                                                                                                      queue:NSOperationQueue.mainQueue
                                                                                                 usingBlock:^(NSNotification __unused *note) {
                                                                                                   // we only need to log this once
                                                                                                   if (!self.didLogLowMemoryWarning) {
                                                                                                     [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppDidReceiveLowMemoryNotification];
                                                                                                     self.didLogLowMemoryWarning = YES;

                                                                                                   }
                                                                                                 }];
    }
  }
}

- (void) unregisterObservers {
  [self unregisterObserver:self.appDidBecomeActiveObserver];
  [self unregisterObserver:self.appWillTerminateObserver];
  [self unregisterObserver:self.appDidEnterBackgroundObserver];
  [self unregisterObserver:self.appWillEnterForegroundObserver];
  [self unregisterObserver:self.appDidReceiveLowMemoryWarningObserver];
  
  [self unregisterObserver:self.networkDidBecomeReachableObserver];
}

- (void) unregisterObserver:(id)observer {
  if (observer) {
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    observer = nil;
  }
}

- (void)leavingAppSafely {
  if (self.isAppNotTerminatingCleanlyDetectionEnabled) {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppWentIntoBackgroundSafely];
  }
}

- (void)appEnteredForeground {
  // we disable kill detection while the debugger is running, since we'd get only false positives if the app is terminated by the user using the debugger
  if (self.isDebuggerAttached) {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBITAppWentIntoBackgroundSafely];
  } else if (self.isAppNotTerminatingCleanlyDetectionEnabled) {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kBITAppWentIntoBackgroundSafely];
    
    static dispatch_once_t predAppData;
    
    dispatch_once(&predAppData, ^{
      id marketingVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
      if (marketingVersion && [marketingVersion isKindOfClass:[NSString class]])
        [[NSUserDefaults standardUserDefaults] setObject:marketingVersion forKey:kBITAppMarketingVersion];
      
      id bundleVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
      if (bundleVersion && [bundleVersion isKindOfClass:[NSString class]])
        [[NSUserDefaults standardUserDefaults] setObject:bundleVersion forKey:kBITAppVersion];
      
      [[NSUserDefaults standardUserDefaults] setObject:[[UIDevice currentDevice] systemVersion] forKey:kBITAppOSVersion];
      [[NSUserDefaults standardUserDefaults] setObject:[self osBuild] forKey:kBITAppOSBuild];
      
      NSString *uuidString =[NSString stringWithFormat:@"<uuid type=\"app\" arch=\"%@\">%@</uuid>",
                             [self deviceArchitecture],
                             [self executableUUID]
                             ];
      
      [[NSUserDefaults standardUserDefaults] setObject:uuidString forKey:kBITAppUUIDs];
    });
  }
}

- (NSString *)deviceArchitecture {
  NSString *archName = @"???";
  
  size_t size;
  cpu_type_t type;
  cpu_subtype_t subtype;
  size = sizeof(type);
  if (sysctlbyname("hw.cputype", &type, &size, NULL, 0))
    return archName;
  
  size = sizeof(subtype);
  if (sysctlbyname("hw.cpusubtype", &subtype, &size, NULL, 0))
    return archName;
  
  archName = [BITCrashReportTextFormatter bit_archNameFromCPUType:type subType:subtype] ?: @"???";
  
  return archName;
}

- (NSString *)osBuild {
  size_t size;
  sysctlbyname("kern.osversion", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  if (answer == NULL)
    return nil;
  sysctlbyname("kern.osversion", answer, &size, NULL, 0);
  NSString *osBuild = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return osBuild;
}

/**
 *	 Get the userID from the delegate which should be stored with the crash report
 *
 *	@return The userID value
 */
- (NSString *)userIDForCrashReport {
  NSString *userID;
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // if we have an identification from BITAuthenticator, use this as a default.
  if ((
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeAnonymous ||
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeDevice
       ) &&
      self.installationIdentification) {
    userID = self.installationIdentification;
  }
#endif
  
  // first check the global keychain storage
  NSString *userIdFromKeychain = [self stringValueFromKeychainForKey:kBITHockeyMetaUserID];
  if (userIdFromKeychain) {
    userID = userIdFromKeychain;
  }
  id strongDelegate = [BITHockeyManager sharedHockeyManager].delegate;
  if ([strongDelegate respondsToSelector:@selector(userIDForHockeyManager:componentManager:)]) {
    userID = [strongDelegate userIDForHockeyManager:[BITHockeyManager sharedHockeyManager] componentManager:self];
  }
  return userID  ?: @"";
}

/**
 *	 Get the userName from the delegate which should be stored with the crash report
 *
 *	@return The userName value
 */
- (NSString *)userNameForCrashReport {
  // first check the global keychain storage
  NSString *username = [self stringValueFromKeychainForKey:kBITHockeyMetaUserName] ?: @"";
  id strongDelegate = [BITHockeyManager sharedHockeyManager].delegate;
  if ([strongDelegate respondsToSelector:@selector(userNameForHockeyManager:componentManager:)]) {
    username = [strongDelegate userNameForHockeyManager:[BITHockeyManager sharedHockeyManager] componentManager:self] ?: @"";
  }
  return username;
}

/**
 *	 Get the userEmail from the delegate which should be stored with the crash report
 *
 *	@return The userEmail value
 */
- (NSString *)userEmailForCrashReport {
  // first check the global keychain storage
  NSString *useremail = [self stringValueFromKeychainForKey:kBITHockeyMetaUserEmail] ?: @"";
  
#if HOCKEYSDK_FEATURE_AUTHENTICATOR
  // if we have an identification from BITAuthenticator, use this as a default.
  if ((
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeHockeyAppEmail ||
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeHockeyAppUser ||
       self.installationIdentificationType == BITAuthenticatorIdentificationTypeWebAuth
       ) &&
      self.installationIdentification) {
    useremail = self.installationIdentification;
  }
#endif
  id strongDelegate = [BITHockeyManager sharedHockeyManager].delegate;
  if ([strongDelegate respondsToSelector:@selector(userEmailForHockeyManager:componentManager:)]) {
    useremail = [strongDelegate userEmailForHockeyManager:[BITHockeyManager sharedHockeyManager] componentManager:self] ?: @"";
  }
  return useremail;
}

#pragma mark - CrashCallbacks

/**
 *  Set the callback for PLCrashReporter
 *
 *  @param callbacks BITCrashManagerCallbacks instance
 */
- (void)setCrashCallbacks:(BITCrashManagerCallbacks *)callbacks {
  if (!callbacks) return;
  if (self.isSetup) {
    BITHockeyLogWarning(@"WARNING: CrashCallbacks need to be configured before calling startManager!");
  }
  
  // set our proxy callback struct
  bitCrashCallbacks.context = callbacks->context;
  bitCrashCallbacks.handleSignal = callbacks->handleSignal;
  
  // set the PLCrashReporterCallbacks struct
  plCrashCallbacks.context = callbacks->context;
}

#if HOCKEYSDK_FEATURE_METRICS
- (void)configDefaultCrashCallback {
  BITMetricsManager *metricsManager = [BITHockeyManager sharedHockeyManager].metricsManager;
  BITPersistence *persistence = metricsManager.persistence;
  BITSaveEventsFilePath = strdup([persistence fileURLForType:BITPersistenceTypeTelemetry].UTF8String);
}
#endif

#pragma mark - Public

- (void)setAlertViewHandler:(BITCustomAlertViewHandler)alertViewHandler{
  _alertViewHandler = alertViewHandler;
}


- (BOOL)isDebuggerAttached {
  return bit_isDebuggerAttached();
}


- (void)generateTestCrash {
  if (self.appEnvironment != BITEnvironmentAppStore) {
    
    if ([self isDebuggerAttached]) {
      BITHockeyLogWarning(@"[HockeySDK] WARNING: The debugger is attached. The following crash cannot be detected by the SDK!");
    }
    
    __builtin_trap();
  }
}

/**
 *  Write a meta file for a new crash report
 *
 *  @param filename the crash reports temp filename
 */
- (void)storeMetaDataForCrashReportFilename:(NSString *)filename {
  BITHockeyLogVerbose(@"VERBOSE: Storing meta data for crash report with filename %@", filename);
  NSError *error = NULL;
  NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithCapacity:4];
  NSString *applicationLog = @"";
  
  [self addStringValueToKeychain:[self userNameForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserName]];
  [self addStringValueToKeychain:[self userEmailForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserEmail]];
  [self addStringValueToKeychain:[self userIDForCrashReport] forKey:[NSString stringWithFormat:@"%@.%@", filename, kBITCrashMetaUserID]];
  id strongDelegate = self.delegate;
  if ([strongDelegate respondsToSelector:@selector(applicationLogForCrashManager:)]) {
    applicationLog = [strongDelegate applicationLogForCrashManager:self] ?: @"";
  }
  [metaDict setObject:applicationLog forKey:kBITCrashMetaApplicationLog];
  
  if ([strongDelegate respondsToSelector:@selector(attachmentForCrashManager:)]) {
    BITHockeyLogVerbose(@"VERBOSE: Processing attachment for crash report with filename %@", filename);
    BITHockeyAttachment *attachment = [strongDelegate attachmentForCrashManager:self];
    
    if (attachment && attachment.hockeyAttachmentData) {
      BOOL success = [self persistAttachment:attachment withFilename:[self.crashesDir stringByAppendingPathComponent: filename]];
      if (!success) {
        BITHockeyLogError(@"ERROR: Persisting the crash attachment failed");
      } else {
        BITHockeyLogVerbose(@"VERBOSE: Crash attachment successfully persisted.");
      }
    } else {
      BITHockeyLogDebug(@"INFO: Crash attachment was nil");
    }
  }
  
  NSData *plist = [NSPropertyListSerialization dataWithPropertyList:(id)metaDict
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                            options:0
                                                              error:&error];
  if (plist) {
    BOOL success = [plist writeToFile:[self.crashesDir stringByAppendingPathComponent:(NSString *)[filename stringByAppendingPathExtension:@"meta"]] atomically:YES];
    if (!success) {
      BITHockeyLogError(@"ERROR: Writing crash meta data failed.");
    }
  } else {
    BITHockeyLogError(@"ERROR: Writing crash meta data failed. %@", error);
  }
  BITHockeyLogVerbose(@"VERBOSE: Storing crash meta data finished.");
}

- (BOOL)handleUserInput:(BITCrashManagerUserInput)userInput withUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData {
  id strongDelegate = self.delegate;
  switch (userInput) {
    case BITCrashManagerUserInputDontSend:
      if ([strongDelegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [strongDelegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      if (self.lastCrashFilename)
        [self cleanCrashReportWithFilename:[self.crashesDir stringByAppendingPathComponent: self.lastCrashFilename]];
      
      return YES;
      
    case BITCrashManagerUserInputSend:
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
      return YES;
      
    case BITCrashManagerUserInputAlwaysSend:
      self.crashManagerStatus = BITCrashManagerStatusAutoSend;
      [[NSUserDefaults standardUserDefaults] setInteger:self.crashManagerStatus forKey:kBITCrashManagerStatus];
      
      if ([strongDelegate respondsToSelector:@selector(crashManagerWillSendCrashReportsAlways:)]) {
        [strongDelegate crashManagerWillSendCrashReportsAlways:self];
      }
      
      if (userProvidedMetaData)
        [self persistUserProvidedMetaData:userProvidedMetaData];
      
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
      return YES;
      
    default:
      return NO;
  }
  
}

#pragma mark - PLCrashReporter

/**
 *	 Process new crash reports provided by PLCrashReporter
 *
 * Parse the new crash report and gather additional meta data from the app which will be stored along the crash report
 */
- (void) handleCrashReport {
  BITHockeyLogVerbose(@"VERBOSE: Handling crash report");
  NSError *error = NULL;
  
  if (!self.plCrashReporter) return;
  
  // check if the next call ran successfully the last time
  if (![self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {
    // mark the start of the routine
    [self.fileManager createFileAtPath:self.analyzerInProgressFile contents:nil attributes:nil];
    BITHockeyLogVerbose(@"VERBOSE: AnalyzerInProgress file created");
    
    [self saveSettings];
    
    // Try loading the crash report
    NSData *crashData = [[NSData alloc] initWithData:[self.plCrashReporter loadPendingCrashReportDataAndReturnError: &error]];
    
    NSString *cacheFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
    self.lastCrashFilename = cacheFilename;
    
    if (crashData == nil) {
      BITHockeyLogError(@"ERROR: Could not load crash report: %@", error);
    } else {
      // get the startup timestamp from the crash report, and the file timestamp to calculate the timeinterval when the crash happened after startup
      BITPLCrashReport *report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
      
      if (report == nil) {
        BITHockeyLogWarning(@"WARNING: Could not parse crash report");
      } else {
        NSDate *appStartTime = nil;
        NSDate *appCrashTime = nil;
        if ([report.processInfo respondsToSelector:@selector(processStartTime)]) {
          if (report.systemInfo.timestamp && report.processInfo.processStartTime) {
            appStartTime = report.processInfo.processStartTime;
            appCrashTime =report.systemInfo.timestamp;
            self.timeIntervalCrashInLastSessionOccurred = [report.systemInfo.timestamp timeIntervalSinceDate:report.processInfo.processStartTime];
          }
        }
        
        [crashData writeToFile:[self.crashesDir stringByAppendingPathComponent: cacheFilename] atomically:YES];
        
        NSString *incidentIdentifier = @"???";
        if (report.uuidRef != NULL) {
          incidentIdentifier = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
        }
        
        NSString *reporterKey = bit_appAnonID(NO) ?: @"";
        
        self.lastSessionCrashDetails = [[BITCrashDetails alloc] initWithIncidentIdentifier:incidentIdentifier
                                                                               reporterKey:reporterKey
                                                                                    signal:report.signalInfo.name
                                                                             exceptionName:report.exceptionInfo.exceptionName
                                                                           exceptionReason:report.exceptionInfo.exceptionReason
                                                                              appStartTime:appStartTime
                                                                                 crashTime:appCrashTime
                                                                                 osVersion:report.systemInfo.operatingSystemVersion
                                                                                   osBuild:report.systemInfo.operatingSystemBuild
                                                                                appVersion:report.applicationInfo.applicationMarketingVersion
                                                                                  appBuild:report.applicationInfo.applicationVersion
                                                                      appProcessIdentifier:report.processInfo.processID
                                        ];
        
        // fetch and store the meta data after setting _lastSessionCrashDetails, so the property can be used in the protocol methods
        [self storeMetaDataForCrashReportFilename:cacheFilename];
      }
    }
  } else {
    BITHockeyLogWarning(@"WARNING: AnalyzerInProgress file found, handling crash report skipped");
  }
  
  // Purge the report
  // mark the end of the routine
  if ([self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {
    [self.fileManager removeItemAtPath:self.analyzerInProgressFile error:&error];
  }
  
  [self saveSettings];
  
  [self.plCrashReporter purgePendingCrashReport];
}

/**
 Get the filename of the first not approved crash report
 
 @return NSString Filename of the first found not approved crash report
 */
- (NSString *)firstNotApprovedCrashReport {
  if ((!self.approvedCrashReports || [self.approvedCrashReports count] == 0) && [self.crashFiles count] > 0) {
    return [self.crashFiles objectAtIndex:0];
  }
  
  for (NSUInteger i=0; i < [self.crashFiles count]; i++) {
    NSString *filename = [self.crashFiles objectAtIndex:i];
    
    if (![self.approvedCrashReports objectForKey:filename]) return filename;
  }
  
  return nil;
}

/**
 *	Check if there are any new crash reports that are not yet processed
 *
 *	@return	`YES` if there is at least one new crash report found, `NO` otherwise
 */
- (BOOL)hasPendingCrashReport {
  if (self.crashManagerStatus == BITCrashManagerStatusDisabled) return NO;
  
  if ([self.fileManager fileExistsAtPath:self.crashesDir]) {
    NSError *error = NULL;
    
    NSArray *dirArray = [self.fileManager contentsOfDirectoryAtPath:self.crashesDir error:&error];
    
    for (NSString *file in dirArray) {
      NSString *filePath = [self.crashesDir stringByAppendingPathComponent:file];
      
      NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:filePath error:&error];
      if ([[fileAttributes objectForKey:NSFileType] isEqualToString:NSFileTypeRegular] &&
          [[fileAttributes objectForKey:NSFileSize] intValue] > 0 &&
          ![file hasSuffix:@".DS_Store"] &&
          ![file hasSuffix:@".analyzer"] &&
          ![file hasSuffix:@".plist"] &&
          ![file hasSuffix:@".data"] &&
          ![file hasSuffix:@".meta"] &&
          ![file hasSuffix:@".desc"]) {
        [self.crashFiles addObject:filePath];
      }
    }
  }
  
  if ([self.crashFiles count] > 0) {
    BITHockeyLogDebug(@"INFO: %lu pending crash reports found.", (unsigned long)[self.crashFiles count]);
    return YES;
  } else {
    if (self.didCrashInLastSession) {
      id strongDelegate = self.delegate;
      if ([strongDelegate respondsToSelector:@selector(crashManagerWillCancelSendingCrashReport:)]) {
        [strongDelegate crashManagerWillCancelSendingCrashReport:self];
      }
      
      self.didCrashInLastSession = NO;
    }
    
    return NO;
  }
}


#pragma mark - Crash Report Processing

// store the latest crash report as user approved, so if it fails it will retry automatically
- (void)approveLatestCrashReport {
  [self.approvedCrashReports setObject:[NSNumber numberWithBool:YES] forKey:[self.crashesDir stringByAppendingPathComponent: self.lastCrashFilename]];
  [self saveSettings];
}

- (void)triggerDelayedProcessing {
  BITHockeyLogVerbose(@"VERBOSE: Triggering delayed crash processing.");
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invokeDelayedProcessing) object:nil];
  [self performSelector:@selector(invokeDelayedProcessing) withObject:nil afterDelay:0.5];
}

/**
 * Delayed startup processing for everything that does not to be done in the app startup runloop
 *
 * - Checks if there is another exception handler installed that may block ours
 * - Present UI if the user has to approve new crash reports
 * - Send pending approved crash reports
 */
- (void)invokeDelayedProcessing {
#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
  if (!bit_isRunningInAppExtension() && [BITHockeyHelper applicationState] != BITApplicationStateActive) {
    return;
  }
#endif
  
  BITHockeyLogDebug(@"INFO: Start delayed CrashManager processing");
  
  // was our own exception handler successfully added?
  if (self.exceptionHandler) {
    // get the current top level error handler
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
    
    // If the top level error handler differs from our own, then at least another one was added.
    // This could cause exception crashes not to be reported to HockeyApp. See log message for details.
    if (self.exceptionHandler != currentHandler) {
      BITHockeyLogWarning(@"[HockeySDK] WARNING: Another exception handler was added. If this invokes any kind of exit() after processing the exception, which causes any subsequent error handler not to be invoked, these crashes will NOT be reported to HockeyApp!");
    }
  }
  
  if (!self.sendingInProgress && [self hasPendingCrashReport]) {
    self.sendingInProgress = YES;
    
    NSString *notApprovedReportFilename = [self firstNotApprovedCrashReport];
    
    // this can happen in case there is a non approved crash report but it didn't happen in the previous app session
    if (notApprovedReportFilename && !self.lastCrashFilename) {
      self.lastCrashFilename = [notApprovedReportFilename lastPathComponent];
    }
    
    if (!BITHockeyBundle() || bit_isRunningInAppExtension()) {
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
      
#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
      
    } else if (self.crashManagerStatus != BITCrashManagerStatusAutoSend && notApprovedReportFilename) {
      id strongDelegate = self.delegate;
      if ([strongDelegate respondsToSelector:@selector(crashManagerWillShowSubmitCrashReportAlert:)]) {
        [strongDelegate crashManagerWillShowSubmitCrashReportAlert:self];
      }
      
      NSString *appName = bit_appName(BITHockeyLocalizedString(@"HockeyAppNamePlaceholder"));
      NSString *alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundAnonymousDescription"), appName];
      
      // the crash report is not anonymous any more if username or useremail are not nil
      NSString *userid = [self userIDForCrashReport];
      NSString *username = [self userNameForCrashReport];
      NSString *useremail = [self userEmailForCrashReport];
      
      if ((userid && [userid length] > 0) ||
          (username && [username length] > 0) ||
          (useremail && [useremail length] > 0)) {
        alertDescription = [NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundDescription"), appName];
      }
      
      if (self.alertViewHandler) {
        self.alertViewHandler();
      } else {
        __weak typeof(self) weakSelf = self;
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:BITHockeyLocalizedString(@"CrashDataFoundTitle"), appName]
                                                                                 message:alertDescription
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"CrashDontSendReport")
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction __unused *action) {
                                                               typeof(self) strongSelf = weakSelf;
                                                               [strongSelf handleUserInput:BITCrashManagerUserInputDontSend withUserProvidedMetaData:nil];
                                                             }];
        [alertController addAction:cancelAction];
        UIAlertAction *sendAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"CrashSendReport")
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction __unused *action) {
                                                             typeof(self) strongSelf = weakSelf;
                                                             [strongSelf handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:nil];
                                                           }];
        [alertController addAction:sendAction];
        if (self.shouldShowAlwaysButton) {
          UIAlertAction *alwaysSendAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"CrashSendReportAlways")
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction __unused *action) {
                                                                     typeof(self) strongSelf = weakSelf;
                                                                     [strongSelf handleUserInput:BITCrashManagerUserInputAlwaysSend withUserProvidedMetaData:nil];
                                                                   }];
          
          [alertController addAction:alwaysSendAction];
        }
        
        [self showAlertController:alertController];
      }
#endif /* !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions) */
      
    } else {
      [self approveLatestCrashReport];
      [self sendNextCrashReport];
    }
  }
}

/**
 *	 Main startup sequence initializing PLCrashReporter if it wasn't disabled
 */
- (void)startManager {
  if (self.crashManagerStatus == BITCrashManagerStatusDisabled) return;
  
  [self registerObservers];
  
  [self loadSettings];
  
  if (!self.isSetup) {
    static dispatch_once_t plcrPredicate;
    dispatch_once(&plcrPredicate, ^{
      /* Configure our reporter */
      
      PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeBSD;
      if (self.isMachExceptionHandlerEnabled) {
        signalHandlerType = PLCrashReporterSignalHandlerTypeMach;
      }
      
      PLCrashReporterSymbolicationStrategy symbolicationStrategy = PLCrashReporterSymbolicationStrategyNone;
      if (self.isOnDeviceSymbolicationEnabled) {
        symbolicationStrategy = PLCrashReporterSymbolicationStrategyAll;
      }
      
      BITPLCrashReporterConfig *config = [[BITPLCrashReporterConfig alloc] initWithSignalHandlerType: signalHandlerType
                                                                               symbolicationStrategy: symbolicationStrategy];
      self.plCrashReporter = [[BITPLCrashReporter alloc] initWithConfiguration: config];
      
      // Check if we previously crashed
      if ([self.plCrashReporter hasPendingCrashReport]) {
        self.didCrashInLastSession = YES;
        [self handleCrashReport];
      }
      
      // The actual signal and mach handlers are only registered when invoking `enableCrashReporterAndReturnError`
      // So it is safe enough to only disable the following part when a debugger is attached no matter which
      // signal handler type is set
      // We only check for this if we are not in the App Store environment
      
      BOOL debuggerIsAttached = NO;
      if (self.appEnvironment != BITEnvironmentAppStore) {
        if ([self isDebuggerAttached]) {
          debuggerIsAttached = YES;
          BITHockeyLogWarning(@"[HockeySDK] WARNING: Detecting crashes is NOT enabled due to running the app with a debugger attached.");
        }
      }
      
      if (!debuggerIsAttached) {
        // Multiple exception handlers can be set, but we can only query the top level error handler (uncaught exception handler).
        //
        // To check if PLCrashReporter's error handler is successfully added, we compare the top
        // level one that is set before and the one after PLCrashReporter sets up its own.
        //
        // With delayed processing we can then check if another error handler was set up afterwards
        // and can show a debug warning log message, that the dev has to make sure the "newer" error handler
        // doesn't exit the process itself, because then all subsequent handlers would never be invoked.
        //
        // Note: ANY error handler setup BEFORE HockeySDK initialization will not be processed!
        
        // get the current top level error handler
        NSUncaughtExceptionHandler *initialHandler = NSGetUncaughtExceptionHandler();
        
        // PLCrashReporter may only be initialized once. So make sure the developer
        // can't break this
        NSError *error = NULL;
        
#if HOCKEYSDK_FEATURE_METRICS
        [self configDefaultCrashCallback];
#endif
        // Set plCrashReporter callback which contains our default callback and potentially user defined callbacks
        [self.plCrashReporter setCrashCallbacks:&plCrashCallbacks];
        
        // Enable the Crash Reporter
        if (![self.plCrashReporter enableCrashReporterAndReturnError: &error])
          BITHockeyLogError(@"[HockeySDK] ERROR: Could not enable crash reporter: %@", [error localizedDescription]);
        
        // get the new current top level error handler, which should now be the one from PLCrashReporter
        NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
        
        // do we have a new top level error handler? then we were successful
        if (currentHandler && currentHandler != initialHandler) {
          self.exceptionHandler = currentHandler;
          
          BITHockeyLogDebug(@"INFO: Exception handler successfully initialized.");
        } else {
          
          // If we're running in a Xamarin Environment, the exception handler will be the one by the xamarin runtime, not ours.
          // In other cases, this should never happen, theoretically only if NSSetUncaugtExceptionHandler() has some internal issues
          BITHockeyLogError(@"[HockeySDK] ERROR: Exception handler could not be set. Make sure there is no other exception handler set up!");
          BITHockeyLogError(@"[HockeySDK] ERROR: If you are using the HockeySDK-Xamarin, this is expected behavior and you can ignore this message");
        }
        
        // Add the C++ uncaught exception handler, which is currently not handled by PLCrashReporter internally
        [BITCrashUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:uncaught_cxx_exception_handler];
      }
      self.isSetup = YES;
    });
  }
  
  if ([[NSUserDefaults standardUserDefaults] valueForKey:kBITAppDidReceiveLowMemoryNotification])
    self.didReceiveMemoryWarningInLastSession = [[NSUserDefaults standardUserDefaults] boolForKey:kBITAppDidReceiveLowMemoryNotification];
  
  if (!self.didCrashInLastSession && self.isAppNotTerminatingCleanlyDetectionEnabled) {
    BOOL didAppSwitchToBackgroundSafely = YES;
    
    if ([[NSUserDefaults standardUserDefaults] valueForKey:kBITAppWentIntoBackgroundSafely])
      didAppSwitchToBackgroundSafely = [[NSUserDefaults standardUserDefaults] boolForKey:kBITAppWentIntoBackgroundSafely];
    
    if (!didAppSwitchToBackgroundSafely) {
      BOOL considerReport = YES;
      id strongDelegate = self.delegate;
      if ([strongDelegate respondsToSelector:@selector(considerAppNotTerminatedCleanlyReportForCrashManager:)]) {
        considerReport = [strongDelegate considerAppNotTerminatedCleanlyReportForCrashManager:self];
      }
      
      if (considerReport) {
        BITHockeyLogVerbose(@"INFO: App kill detected, creating crash report.");
        [self createCrashReportForAppKill];
        
        self.didCrashInLastSession = YES;
      }
    }
  }
  
#if !defined (HOCKEYSDK_CONFIGURATION_ReleaseCrashOnlyExtensions)
  if ([BITHockeyHelper applicationState] != BITApplicationStateActive) {
    [self appEnteredForeground];
  }
#else
  [self appEnteredForeground];
#endif
  
  [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kBITAppDidReceiveLowMemoryNotification];
  
  [self triggerDelayedProcessing];
  BITHockeyLogVerbose(@"VERBOSE: CrashManager startManager has finished.");
}

/**
 *  Creates a fake crash report because the app was killed while being in foreground
 */
- (void)createCrashReportForAppKill {
  NSString *fakeReportUUID = bit_UUID();
  NSString *fakeReporterKey = bit_appAnonID(NO) ?: @"???";
  
  NSString *fakeReportAppMarketingVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppMarketingVersion];
  
  NSString *fakeReportAppVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppVersion];
  if (!fakeReportAppVersion)
    return;
  
  NSString *fakeReportOSVersion = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppOSVersion] ?: [[UIDevice currentDevice] systemVersion];
  
  NSString *fakeReportOSVersionString = fakeReportOSVersion;
  NSString *fakeReportOSBuild = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppOSBuild] ?: [self osBuild];
  if (fakeReportOSBuild) {
    fakeReportOSVersionString = [NSString stringWithFormat:@"%@ (%@)", fakeReportOSVersion, fakeReportOSBuild];
  }
  
  NSString *fakeReportAppBundleIdentifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  NSString *fakeReportDeviceModel = [self getDevicePlatform] ?: @"Unknown";
  NSString *fakeReportAppUUIDs = [[NSUserDefaults standardUserDefaults] objectForKey:kBITAppUUIDs] ?: @"";
  
  NSString *fakeSignalName = kBITCrashKillSignal;
  
  NSMutableString *fakeReportString = [NSMutableString string];
  
  [fakeReportString appendFormat:@"Incident Identifier: %@\n", fakeReportUUID];
  [fakeReportString appendFormat:@"CrashReporter Key:   %@\n", fakeReporterKey];
  [fakeReportString appendFormat:@"Hardware Model:      %@\n", fakeReportDeviceModel];
  [fakeReportString appendFormat:@"Identifier:      %@\n", fakeReportAppBundleIdentifier];
  
  NSString *fakeReportAppVersionString = fakeReportAppMarketingVersion ? [NSString stringWithFormat:@"%@ (%@)", fakeReportAppMarketingVersion, fakeReportAppVersion] : fakeReportAppVersion;
  
  [fakeReportString appendFormat:@"Version:         %@\n", fakeReportAppVersionString];
  [fakeReportString appendString:@"Code Type:       ARM\n"];
  [fakeReportString appendString:@"\n"];
  
  NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
  NSDateFormatter *rfc3339Formatter = [[NSDateFormatter alloc] init];
  [rfc3339Formatter setLocale:enUSPOSIXLocale];
  [rfc3339Formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
  [rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  NSString *fakeCrashTimestamp = [rfc3339Formatter stringFromDate:[NSDate date]];
  
  // we use the current date, since we don't know when the kill actually happened
  [fakeReportString appendFormat:@"Date/Time:       %@\n", fakeCrashTimestamp];
  [fakeReportString appendFormat:@"OS Version:      %@\n", fakeReportOSVersionString];
  [fakeReportString appendString:@"Report Version:  104\n"];
  [fakeReportString appendString:@"\n"];
  [fakeReportString appendFormat:@"Exception Type:  %@\n", fakeSignalName];
  [fakeReportString appendString:@"Exception Codes: 00000020 at 0x8badf00d\n"];
  [fakeReportString appendString:@"\n"];
  [fakeReportString appendString:@"Application Specific Information:\n"];
  [fakeReportString appendString:@"The application did not terminate cleanly but no crash occured."];
  if (self.didReceiveMemoryWarningInLastSession) {
    [fakeReportString appendString:@" The app received at least one Low Memory Warning."];
  }
  [fakeReportString appendString:@"\n\n"];
  
  NSString *fakeReportFilename = [NSString stringWithFormat: @"%.0f", [NSDate timeIntervalSinceReferenceDate]];
  
  NSError *error = nil;
  
  NSMutableDictionary *rootObj = [NSMutableDictionary dictionaryWithCapacity:2];
  [rootObj setObject:fakeReportUUID forKey:kBITFakeCrashUUID];
  if (fakeReportAppMarketingVersion)
    [rootObj setObject:fakeReportAppMarketingVersion forKey:kBITFakeCrashAppMarketingVersion];
  [rootObj setObject:fakeReportAppVersion forKey:kBITFakeCrashAppVersion];
  [rootObj setObject:fakeReportAppBundleIdentifier forKey:kBITFakeCrashAppBundleIdentifier];
  [rootObj setObject:fakeReportOSVersion forKey:kBITFakeCrashOSVersion];
  [rootObj setObject:fakeReportDeviceModel forKey:kBITFakeCrashDeviceModel];
  [rootObj setObject:fakeReportAppUUIDs forKey:kBITFakeCrashAppBinaryUUID];
  [rootObj setObject:fakeReportString forKey:kBITFakeCrashReport];
  
  self.lastSessionCrashDetails = [[BITCrashDetails alloc] initWithIncidentIdentifier:fakeReportUUID
                                                                         reporterKey:fakeReporterKey
                                                                              signal:fakeSignalName
                                                                       exceptionName:nil
                                                                     exceptionReason:nil
                                                                        appStartTime:nil
                                                                           crashTime:nil
                                                                           osVersion:fakeReportOSVersion
                                                                             osBuild:fakeReportOSBuild
                                                                          appVersion:fakeReportAppMarketingVersion
                                                                            appBuild:fakeReportAppVersion
                                                                appProcessIdentifier:[[NSProcessInfo processInfo] processIdentifier]
                                  ];
  
  NSData *plist = [NSPropertyListSerialization dataWithPropertyList:(id)rootObj
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                            options:0
                                                              error:&error];
  if (plist) {
    if ([plist writeToFile:[self.crashesDir stringByAppendingPathComponent:(NSString *)[fakeReportFilename stringByAppendingPathExtension:@"fake"]] atomically:YES]) {
      [self storeMetaDataForCrashReportFilename:fakeReportFilename];
    }
  } else {
    BITHockeyLogError(@"ERROR: Writing fake crash report. %@", [error description]);
  }
}

/**
 *	 Send all approved crash reports
 *
 * Gathers all collected data and constructs the XML structure and starts the sending process
 */
- (void)sendNextCrashReport {
  NSError *error = NULL;
  
  self.crashIdenticalCurrentVersion = NO;
  
  if ([self.crashFiles count] == 0)
    return;
  
  NSString *crashXML = nil;
  BITHockeyAttachment *attachment = nil;
  
  // we start sending always with the oldest pending one
  NSString *filename = [self.crashFiles objectAtIndex:0];
  NSString *attachmentFilename = filename;
  NSString *cacheFilename = [filename lastPathComponent];
  NSData *crashData = [NSData dataWithContentsOfFile:filename];
  
  if ([crashData length] > 0) {
    BITPLCrashReport *report = nil;
    NSString *crashUUID = @"";
    NSString *installString = nil;
    NSString *crashLogString = nil;
    NSString *appBundleIdentifier = nil;
    NSString *appBundleMarketingVersion = nil;
    NSString *appBundleVersion = nil;
    NSString *osVersion = nil;
    NSString *deviceModel = nil;
    NSString *appBinaryUUIDs = nil;
    NSString *metaFilename = nil;
    
    NSPropertyListFormat format;
    
    if ([[cacheFilename pathExtension] isEqualToString:@"fake"]) {
      NSDictionary *fakeReportDict = (NSDictionary *)[NSPropertyListSerialization
                                                      propertyListWithData:crashData
                                                      options:NSPropertyListMutableContainersAndLeaves
                                                      format:&format
                                                      error:&error];
      
      crashLogString = [fakeReportDict objectForKey:kBITFakeCrashReport];
      crashUUID = [fakeReportDict objectForKey:kBITFakeCrashUUID];
      appBundleIdentifier = [fakeReportDict objectForKey:kBITFakeCrashAppBundleIdentifier];
      appBundleMarketingVersion = [fakeReportDict objectForKey:kBITFakeCrashAppMarketingVersion] ?: @"";
      appBundleVersion = [fakeReportDict objectForKey:kBITFakeCrashAppVersion];
      appBinaryUUIDs = [fakeReportDict objectForKey:kBITFakeCrashAppBinaryUUID];
      deviceModel = [fakeReportDict objectForKey:kBITFakeCrashDeviceModel];
      osVersion = [fakeReportDict objectForKey:kBITFakeCrashOSVersion];
      
      metaFilename = [cacheFilename stringByReplacingOccurrencesOfString:@".fake" withString:@".meta"];
      attachmentFilename = [attachmentFilename stringByReplacingOccurrencesOfString:@".fake" withString:@""];
      
      if ([appBundleVersion compare:(NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        self.crashIdenticalCurrentVersion = YES;
      }
      
    } else {
      report = [[BITPLCrashReport alloc] initWithData:crashData error:&error];
    }
    
    if (report == nil && crashLogString == nil) {
      BITHockeyLogWarning(@"WARNING: Could not parse crash report");
      // we cannot do anything with this report, so delete it
      [self cleanCrashReportWithFilename:filename];
      // we don't continue with the next report here, even if there are to prevent calling sendCrashReports from itself again
      // the next crash will be automatically send on the next app start/becoming active event
      return;
    }
    
    installString = bit_appAnonID(NO) ?: @"";
    
    if (report) {
      if (report.uuidRef != NULL) {
        crashUUID = (NSString *) CFBridgingRelease(CFUUIDCreateString(NULL, report.uuidRef));
      }
      metaFilename = [cacheFilename stringByAppendingPathExtension:@"meta"];
      crashLogString = [BITCrashReportTextFormatter stringValueForCrashReport:report crashReporterKey:installString];
      appBundleIdentifier = report.applicationInfo.applicationIdentifier;
      appBundleMarketingVersion = report.applicationInfo.applicationMarketingVersion ?: @"";
      appBundleVersion = report.applicationInfo.applicationVersion;
      osVersion = report.systemInfo.operatingSystemVersion;
      deviceModel = [self getDevicePlatform];
      appBinaryUUIDs = [self extractAppUUIDs:report];
      if ([report.applicationInfo.applicationVersion compare:(NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
        self.crashIdenticalCurrentVersion = YES;
      }
    }
    
    if ([report.applicationInfo.applicationVersion compare:(NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] == NSOrderedSame) {
      self.crashIdenticalCurrentVersion = YES;
    }
    
    NSString *username = @"";
    NSString *useremail = @"";
    NSString *userid = @"";
    NSString *applicationLog = @"";
    NSString *description = @"";
    
    NSData *plist = [NSData dataWithContentsOfFile:[self.crashesDir stringByAppendingPathComponent:metaFilename]];
    if (plist) {
      NSDictionary *metaDict = (NSDictionary *)[NSPropertyListSerialization
                                                propertyListWithData:plist
                                                options:NSPropertyListMutableContainersAndLeaves
                                                format:&format
                                                error:&error];
      
      username = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", attachmentFilename.lastPathComponent, kBITCrashMetaUserName]] ?: @"";
      useremail = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", attachmentFilename.lastPathComponent, kBITCrashMetaUserEmail]] ?: @"";
      userid = [self stringValueFromKeychainForKey:[NSString stringWithFormat:@"%@.%@", attachmentFilename.lastPathComponent, kBITCrashMetaUserID]] ?: @"";
      applicationLog = [metaDict objectForKey:kBITCrashMetaApplicationLog] ?: @"";
      description = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@.desc", [self.crashesDir stringByAppendingPathComponent: cacheFilename]] encoding:NSUTF8StringEncoding error:&error];
      attachment = [self attachmentForCrashReport:attachmentFilename];
    } else {
      BITHockeyLogError(@"ERROR: Reading crash meta data. %@", error);
    }
    
    if ([applicationLog length] > 0) {
      if ([description length] > 0) {
        description = [NSString stringWithFormat:@"%@\n\nLog:\n%@", description, applicationLog];
      } else {
        description = [NSString stringWithFormat:@"Log:\n%@", applicationLog];
      }
    }
    
    crashXML = [NSString stringWithFormat:@"<crashes><crash><applicationname><![CDATA[%@]]></applicationname><uuids>%@</uuids><bundleidentifier>%@</bundleidentifier><systemversion>%@</systemversion><platform>%@</platform><senderversion>%@</senderversion><versionstring>%@</versionstring><version>%@</version><uuid>%@</uuid><log><![CDATA[%@]]></log><userid>%@</userid><username>%@</username><contact>%@</contact><installstring>%@</installstring><description><![CDATA[%@]]></description></crash></crashes>",
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"],
                appBinaryUUIDs,
                appBundleIdentifier,
                osVersion,
                deviceModel,
                [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                appBundleMarketingVersion,
                appBundleVersion,
                crashUUID,
                [crashLogString stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,crashLogString.length)],
                userid,
                username,
                useremail,
                installString,
                [description stringByReplacingOccurrencesOfString:@"]]>" withString:@"]]" @"]]><![CDATA[" @">" options:NSLiteralSearch range:NSMakeRange(0,description.length)]];
    
    BITHockeyLogDebug(@"INFO: Sending crash reports:\n%@", crashXML);
    [self sendCrashReportWithFilename:filename xml:crashXML attachment:attachment];
  } else {
    // we cannot do anything with this report, so delete it
    [self cleanCrashReportWithFilename:filename];
  }
}

#pragma mark - Networking

- (NSData *)postBodyWithXML:(NSString *)xml attachment:(BITHockeyAttachment *)attachment boundary:(NSString *)boundary {
  NSMutableData *postBody =  [NSMutableData data];
  
  //  [postBody appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:BITHOCKEY_NAME
                                                      forKey:@"sdk"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:BITHOCKEY_VERSION
                                                      forKey:@"sdk_version"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:@"no"
                                                      forKey:@"feedbackEnabled"
                                                    boundary:boundary]];
  
  [postBody appendData:[BITHockeyAppClient dataWithPostValue:[xml dataUsingEncoding:NSUTF8StringEncoding]
                                                      forKey:@"xml"
                                                 contentType:@"text/xml"
                                                    boundary:boundary
                                                    filename:@"crash.xml"]];
  
  if (attachment && attachment.hockeyAttachmentData) {
    NSString *attachmentFilename = attachment.filename;
    if (!attachmentFilename) {
      attachmentFilename = @"Attachment_0";
    }
    [postBody appendData:[BITHockeyAppClient dataWithPostValue:attachment.hockeyAttachmentData
                                                        forKey:@"attachment0"
                                                   contentType:attachment.contentType
                                                      boundary:boundary
                                                      filename:attachmentFilename]];
  }
  
  [postBody appendData:(NSData *)[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  
  return postBody;
}

- (NSMutableURLRequest *)requestWithBoundary:(NSString *)boundary {
  NSString *postCrashPath = [NSString stringWithFormat:@"api/2/apps/%@/crashes", self.encodedAppIdentifier];
  
  NSMutableURLRequest *request = [self.hockeyAppClient requestWithMethod:@"POST"
                                                                    path:postCrashPath
                                                              parameters:nil];
  
  [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
  [request setValue:@"HockeySDK/iOS" forHTTPHeaderField:@"User-Agent"];
  [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
  
  NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
  [request setValue:contentType forHTTPHeaderField:@"Content-type"];
  
  return request;
}

// process upload response
- (void)processUploadResultWithFilename:(NSString *)filename responseData:(NSData *)responseData statusCode:(NSInteger)statusCode error:(NSError *)error {
  __block NSError *theError = error;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    self.sendingInProgress = NO;
    id strongDelegate = self.delegate;
    if (nil == theError) {
      if (nil == responseData || [responseData length] == 0) {
        theError = [NSError errorWithDomain:kBITCrashErrorDomain
                                       code:BITCrashAPIReceivedEmptyResponse
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: @"Sending failed with an empty response!"
                                              }
                    ];
      } else if (statusCode >= 200 && statusCode < 400) {
        [self cleanCrashReportWithFilename:filename];
        
        // HockeyApp uses PList XML format
        NSMutableDictionary *response = [NSPropertyListSerialization propertyListWithData:responseData
                                                                                  options:NSPropertyListMutableContainersAndLeaves
                                                                                   format:nil
                                                                                    error:&theError];
        BITHockeyLogDebug(@"INFO: Received API response: %@", response);
        if ([strongDelegate respondsToSelector:@selector(crashManagerDidFinishSendingCrashReport:)]) {
          [strongDelegate crashManagerDidFinishSendingCrashReport:self];
        }
        
        // only if sending the crash report went successfully, continue with the next one (if there are more)
        [self sendNextCrashReport];
      } else if (statusCode == 400) {
        [self cleanCrashReportWithFilename:filename];
        
        theError = [NSError errorWithDomain:kBITCrashErrorDomain
                                       code:BITCrashAPIAppVersionRejected
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: @"The server rejected receiving crash reports for this app version!"
                                              }
                    ];
      } else {
        theError = [NSError errorWithDomain:kBITCrashErrorDomain
                                       code:BITCrashAPIErrorWithStatusCode
                                   userInfo:@{
                                              NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Sending failed with status code: %li", (long)statusCode]
                                              }
                    ];
      }
    }
    
    if (theError) {
      if ([strongDelegate respondsToSelector:@selector(crashManager:didFailWithError:)]) {
        [strongDelegate crashManager:self didFailWithError:theError];
      }
      
      BITHockeyLogError(@"ERROR: %@", [theError localizedDescription]);
    }
  });
}

/**
 *	 Send the XML data to the server
 *
 * Wraps the XML structure into a POST body and starts sending the data asynchronously
 *
 *	@param	xml	The XML data that needs to be send to the server
 */
- (void)sendCrashReportWithFilename:(NSString *)filename xml:(NSString*)xml attachment:(BITHockeyAttachment *)attachment {
  NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
  __block NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
  
  NSURLRequest *request = [self requestWithBoundary:kBITHockeyAppClientBoundary];
  NSData *data = [self postBodyWithXML:xml attachment:attachment boundary:kBITHockeyAppClientBoundary];
  
  if (request && data) {
    __weak typeof (self) weakSelf = self;
    NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request
                                                               fromData:data
                                                      completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
                                                        typeof (self) strongSelf = weakSelf;
                                                        
                                                        [session finishTasksAndInvalidate];
                                                        
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
                                                        NSInteger statusCode = [httpResponse statusCode];
                                                        [strongSelf processUploadResultWithFilename:filename responseData:responseData statusCode:statusCode error:error];
                                                      }];
    
    [uploadTask resume];
  }
  id strongDelegate = self.delegate;
  if ([strongDelegate respondsToSelector:@selector(crashManagerWillSendCrashReport:)]) {
    [strongDelegate crashManagerWillSendCrashReport:self];
  }
  
  BITHockeyLogDebug(@"INFO: Sending crash reports started.");
}

- (NSTimeInterval)timeintervalCrashInLastSessionOccured {
  return self.timeIntervalCrashInLastSessionOccurred;
}

@end

#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */

