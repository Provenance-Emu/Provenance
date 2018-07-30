#import <Foundation/Foundation.h>

/**
 *  Provides details about the crash that occurred in the previous app session
 */
@interface BITCrashDetails : NSObject

/**
 *  UUID for the crash report
 */
@property (nonatomic, readonly, copy) NSString *incidentIdentifier;

/**
 *  UUID for the app installation on the device
 */
@property (nonatomic, readonly, copy) NSString *reporterKey;

/**
 *  Signal that caused the crash
 */
@property (nonatomic, readonly, copy) NSString *signal;

/**
 *  Exception name that triggered the crash, nil if the crash was not caused by an exception
 */
@property (nonatomic, readonly, copy) NSString *exceptionName;

/**
 *  Exception reason, nil if the crash was not caused by an exception
 */
@property (nonatomic, readonly, copy) NSString *exceptionReason;

/**
 *  Date and time the app started, nil if unknown
 */
@property (nonatomic, readonly, strong) NSDate *appStartTime;

/**
 *  Date and time the crash occurred, nil if unknown
 */
@property (nonatomic, readonly, strong) NSDate *crashTime;

/**
 *  Operation System version string the app was running on when it crashed.
 */
@property (nonatomic, readonly, copy) NSString *osVersion;

/**
 *  Operation System build string the app was running on when it crashed
 *
 *  This may be unavailable.
 */
@property (nonatomic, readonly, copy) NSString *osBuild;

/**
 *  CFBundleShortVersionString value of the app that crashed
 *
 *  Can be `nil` if the crash was captured with an older version of the SDK
 *  or if the app doesn't set the value.
 */
@property (nonatomic, readonly, copy) NSString *appVersion;

/**
 *  CFBundleVersion value of the app that crashed
 */
@property (nonatomic, readonly, copy) NSString *appBuild;

/**
 *  Identifier of the app process that crashed
 */
@property (nonatomic, readonly, assign) NSUInteger appProcessIdentifier;

/**
 Indicates if the app was killed while being in foreground from the tvOS
 
 If `[BITCrashManager enableAppNotTerminatingCleanlyDetection]` is enabled, use this on startup
 to check if the app starts the first time after it was killed by tvOS in the previous session.
 
 This can happen if it consumed too much memory or the watchdog killed the app because it
 took too long to startup or blocks the main thread for too long, or other reasons. See Apple
 documentation: https://developer.apple.com/library/ios/qa/qa1693/_index.html
 
 See `[BITCrashManager enableAppNotTerminatingCleanlyDetection]` for more details about which kind of kills can be detected.
 
 @warning This property only has a correct value, once `[BITHockeyManager startManager]` was
 invoked! In addition, it is automatically disabled while a debugger session is active!
 
 @see `[BITCrashManager enableAppNotTerminatingCleanlyDetection]`
 @see `[BITCrashManager didReceiveMemoryWarningInLastSession]`
 
 @return YES if the details represent an app kill instead of a crash
 */
- (BOOL)isAppKill;

@end
