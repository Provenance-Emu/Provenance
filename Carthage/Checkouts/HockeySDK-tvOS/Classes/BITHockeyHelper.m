#import "BITHockeyHelper+Application.h"
#import "BITKeychainUtils.h"
#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import <sys/sysctl.h>

@implementation BITHockeyHelper

/**
 * @discussion
 * Workaround for exporting symbols from category object files.
 * See article https://medium.com/ios-os-x-development/categories-in-static-libraries-78e41f8ddb96#.aedfl1kl0
 */
__attribute__((used)) static void importCategories() {
  [NSString stringWithFormat:@"%@", BITHockeyHelperApplicationCategory];
}

@end

#pragma mark NSString helpers

NSString *bit_URLEncodedString(NSString *inputString) {
  return [inputString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"!*'();:@&=+$,/?%#[] {}"].invertedSet];
}

typedef struct {
  uint8_t       info_version;
  const char    bit_version[16];
  const char    bit_build[16];
} bit_info_t;

static bit_info_t hockeyapp_library_info __attribute__((section("__TEXT,__bit_tvOS,regular,no_dead_strip"))) = {
  .info_version = 1,
  .bit_version = BITHOCKEY_C_VERSION,
  .bit_build = BITHOCKEY_C_BUILD
};

NSString *bit_settingsDir(void) {
  static NSString *settingsDir = nil;
  static dispatch_once_t predSettingsDir;
  
  dispatch_once(&predSettingsDir, ^{
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    
    // temporary directory for crashes grabbed from PLCrashReporter
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    settingsDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:BITHOCKEY_IDENTIFIER];
    
    if (![fileManager fileExistsAtPath:settingsDir]) {
      NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
      NSError *theError = NULL;
      
      [fileManager createDirectoryAtPath:settingsDir withIntermediateDirectories: YES attributes: attributes error: &theError];
    }
  });
  
  return settingsDir;
}

BOOL bit_validateEmail(NSString *email) {
  NSString *emailRegex =
  @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
  @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
  @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
  @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
  @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
  @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
  @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";
  NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", emailRegex];
  
  return [emailTest evaluateWithObject:email];
}

NSString *bit_keychainHockeySDKServiceName(void) {
  static NSString *serviceName = nil;
  static dispatch_once_t predServiceName;
  
  dispatch_once(&predServiceName, ^{
    serviceName = [NSString stringWithFormat:@"%@.HockeySDK", bit_mainBundleIdentifier()];
  });
  
  return serviceName;
}

NSComparisonResult bit_versionCompare(NSString *stringA, NSString *stringB) {
  // Extract plain version number from self
  NSString *plainSelf = stringA;
  NSRange letterRange = [plainSelf rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainSelf = [plainSelf substringToIndex: letterRange.location];
	
  // Extract plain version number from other
  NSString *plainOther = stringB;
  letterRange = [plainOther rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainOther = [plainOther substringToIndex: letterRange.location];
	
  // Compare plain versions
  NSComparisonResult result = [plainSelf compare:plainOther options:NSNumericSearch];
	
  // If plain versions are equal, compare full versions
  if (result == NSOrderedSame)
    result = [stringA compare:stringB options:NSNumericSearch];
	
  // Done
  return result;
}

NSString *bit_mainBundleIdentifier(void) {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

NSString *bit_encodeAppIdentifier(NSString *inputString) {
  return (inputString ? bit_URLEncodedString(inputString) : bit_URLEncodedString(bit_mainBundleIdentifier()));
}

NSString *bit_appName(NSString *placeHolderString) {
  NSString *appName = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
  if (!appName)
    appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  if (!appName)
    appName = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleName"];
  if (!appName)
    appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: placeHolderString;
  
  return appName;
}

NSString *bit_appIdentifierToGuid(NSString *appIdentifier) {
  NSMutableString *guid;
  NSString *cleanAppId = [appIdentifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if(cleanAppId && cleanAppId.length == 32) {
    // Insert dashes so that DC will accept th appidentifier (as a replacement for iKey)
    guid = [NSMutableString stringWithString:cleanAppId];
    [guid insertString:@"-" atIndex:20];
    [guid insertString:@"-" atIndex:16];
    [guid insertString:@"-" atIndex:12];
    [guid insertString:@"-" atIndex:8];
  }
  return [guid copy];
}

NSString *bit_UUID(void) {
  return [[NSUUID UUID] UUIDString];
}

NSString *bit_appAnonID(BOOL forceNewAnonID) {
  static NSString *appAnonID = nil;
  static dispatch_once_t predAppAnonID;
  __block NSError *error = nil;
  NSString *appAnonIDKey = @"appAnonID";
  
  if (forceNewAnonID) {
    appAnonID = bit_UUID();
    // store this UUID in the keychain (on this device only) so we can be sure to always have the same ID upon app startups
    if (appAnonID) {
      // add to keychain in a background thread, since we got reports that storing to the keychain may take several seconds sometimes and cause the app to be killed
      // and we don't care about the result anyway
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [BITKeychainUtils storeUsername:appAnonIDKey
                            andPassword:appAnonID
                         forServiceName:bit_keychainHockeySDKServiceName()
                         updateExisting:YES
                          accessibility:kSecAttrAccessibleAlwaysThisDeviceOnly
                                  error:&error];
      });
    }
  } else {
    dispatch_once(&predAppAnonID, ^{
      // first check if we already have an install string in the keychain
      appAnonID = [BITKeychainUtils getPasswordForUsername:appAnonIDKey andServiceName:bit_keychainHockeySDKServiceName() error:&error];
      
      if (!appAnonID) {
        appAnonID = bit_UUID();
        // store this UUID in the keychain (on this device only) so we can be sure to always have the same ID upon app startups
        if (appAnonID) {
          // add to keychain in a background thread, since we got reports that storing to the keychain may take several seconds sometimes and cause the app to be killed
          // and we don't care about the result anyway
          dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [BITKeychainUtils storeUsername:appAnonIDKey
                                andPassword:appAnonID
                             forServiceName:bit_keychainHockeySDKServiceName()
                             updateExisting:YES
                              accessibility:kSecAttrAccessibleAlwaysThisDeviceOnly
                                      error:&error];
          });
        }
      }
    });
  }
  
  return appAnonID;
}

BOOL bit_isDebuggerAttached(void) {
  static BOOL debuggerIsAttached = NO;
  
  static dispatch_once_t debuggerPredicate;
  dispatch_once(&debuggerPredicate, ^{
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
    
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
      NSLog(@"[HockeySDK] ERROR: Checking for a running debugger via sysctl() failed.");
      debuggerIsAttached = false;
    }
    
    if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
      debuggerIsAttached = true;
  });
  
  return debuggerIsAttached;
}

BOOL bit_isAppStoreReceiptSandbox(void) {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  if (![NSBundle.mainBundle respondsToSelector:@selector(appStoreReceiptURL)]) {
    return NO;
  }
  NSURL *appStoreReceiptURL = NSBundle.mainBundle.appStoreReceiptURL;
  NSString *appStoreReceiptLastComponent = appStoreReceiptURL.lastPathComponent;
  
  BOOL isSandboxReceipt = [appStoreReceiptLastComponent isEqualToString:@"sandboxReceipt"];
  return isSandboxReceipt;
#endif
}

BOOL bit_hasEmbeddedMobileProvision(void) {
  BOOL hasEmbeddedMobileProvision = !![[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
  return hasEmbeddedMobileProvision;
}

BOOL bit_isRunningInTestFlightEnvironment(void) {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  if (bit_isAppStoreReceiptSandbox() && !bit_hasEmbeddedMobileProvision()) {
    return YES;
  }
  return NO;
#endif
}

BOOL bit_isRunningInAppStoreEnvironment(void) {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  if (bit_isAppStoreReceiptSandbox() || bit_hasEmbeddedMobileProvision()) {
    return NO;
  }
  return YES;
#endif
}

UIImage *bit_imageNamed(NSString *imageName, NSString *bundleName) {
  NSString *resourcePath = [[NSBundle bundleForClass:[BITHockeyManager class]] resourcePath];
  NSString *bundlePath = [resourcePath stringByAppendingPathComponent:bundleName];
  NSString *imagePath = [bundlePath stringByAppendingPathComponent:imageName];
  return bit_imageWithContentsOfResolutionIndependentFile(imagePath);
}

UIImage *bit_imageWithContentsOfResolutionIndependentFile(NSString *path) {
  return bit_newWithContentsOfResolutionIndependentFile(path);
}

UIImage *bit_newWithContentsOfResolutionIndependentFile(NSString * path) {
  if ([UIScreen instancesRespondToSelector:@selector(scale)] && (int)[[UIScreen mainScreen] scale] == 2.0) {
    NSString *path2x = [[path stringByDeletingLastPathComponent]
                        stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.%@",
                                                        [[path lastPathComponent] stringByDeletingPathExtension],
                                                        [path pathExtension]]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path2x]) {
      return [[UIImage alloc] initWithContentsOfFile:path2x];
    }
  }
  
  return [[UIImage alloc] initWithContentsOfFile:path];
}

#pragma mark Context helpers

// Return ISO 8601 string representation of the date
NSString *bit_utcDateString(NSDate *date){
  static NSDateFormatter *dateFormatter;
  
  static dispatch_once_t dateFormatterToken;
  dispatch_once(&dateFormatterToken, ^{
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter = [NSDateFormatter new];
    dateFormatter.locale = enUSPOSIXLocale;
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
  });
  
  NSString *dateString = [dateFormatter stringFromDate:date];
  
  return dateString;
}

NSString *bit_devicePlatform(void) {
  
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *answer = (char*)malloc(size);
  if (answer == NULL)
    return @"";
  sysctlbyname("hw.machine", answer, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
  free(answer);
  return platform;
}

NSString *bit_deviceType(void){
  
  UIUserInterfaceIdiom idiom = [UIDevice currentDevice].userInterfaceIdiom;
  
  switch (idiom) {
    case UIUserInterfaceIdiomTV:
      return @"TV";
    default:
      return @"Unknown";
  }
}

NSString *bit_osVersionBuild(void) {
  void *result = NULL;
  size_t result_len = 0;
  int ret;
  
  /* If our buffer is too small after allocation, loop until it succeeds -- the requested destination size
   * may change after each iteration. */
  do {
    /* Fetch the expected length */
    if ((ret = sysctlbyname("kern.osversion", NULL, &result_len, NULL, 0)) == -1) {
      break;
    }
    
    /* Allocate the destination buffer */
    if (result != NULL) {
      free(result);
    }
    result = malloc(result_len);
    
    /* Fetch the value */
    ret = sysctlbyname("kern.osversion", result, &result_len, NULL, 0);
  } while (ret == -1 && errno == ENOMEM);
  
  /* Handle failure */
  if (ret == -1) {
    int saved_errno = errno;
    
    if (result != NULL) {
      free(result);
    }
    
    errno = saved_errno;
    return NULL;
  }
  
  NSString *osBuild = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
  free(result);
  
  NSString *osVersion = [[UIDevice currentDevice] systemVersion];
  
  return [NSString stringWithFormat:@"%@ (%@)", osVersion, osBuild];
}

NSString *bit_osName(void){
  return [[UIDevice currentDevice] systemName];
}

NSString *bit_deviceLocale(void) {
  NSLocale *locale = [NSLocale currentLocale];
  return [locale objectForKey:NSLocaleIdentifier];
}

NSString *bit_deviceLanguage(void) {
  return [[NSBundle mainBundle] preferredLocalizations][0];
}

NSString *bit_screenSize(void){
  CGFloat scale = [UIScreen mainScreen].scale;
  CGSize screenSize = [UIScreen mainScreen].bounds.size;
  return [NSString stringWithFormat:@"%dx%d",(int)(screenSize.height * scale), (int)(screenSize.width * scale)];
}

NSString *bit_sdkVersion(void){
  return [NSString stringWithFormat:@"tvOS:%@", [NSString stringWithUTF8String:hockeyapp_library_info.bit_version]];
}

NSString *bit_appVersion(void){
  NSString *build = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
  NSString *version = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
  
  if(version){
    return [NSString stringWithFormat:@"%@ (%@)", version, build];
  }else{
    return build;
  }
}
