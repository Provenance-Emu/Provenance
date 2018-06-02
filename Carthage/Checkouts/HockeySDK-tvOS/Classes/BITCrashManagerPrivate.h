#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_CRASH_REPORTER

#import <CrashReporter/CrashReporter.h>

@class BITHockeyAppClient;

@interface BITCrashManager () {
}


///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the optional `BITCrashManagerDelegate` delegate.
 
 The delegate is automatically set by using `[BITHockeyManager setDelegate:]`. You
 should not need to set this delegate individually.
 
 @see `[BITHockeyManager setDelegate:]`
 */
@property (nonatomic, weak) id delegate;

/**
 * must be set
 */
@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

@property (nonatomic) NSUncaughtExceptionHandler *exceptionHandler;

@property (nonatomic, strong) NSFileManager *fileManager;

@property (nonatomic, strong) BITPLCrashReporter *plCrashReporter;

@property (nonatomic, copy) NSString *lastCrashFilename;

@property (nonatomic, copy, setter = setAlertViewHandler:) BITCustomAlertViewHandler alertViewHandler __TVOS_PROHIBITED;

@property (nonatomic, copy) NSString *crashesDir;

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

// Only set via BITAuthenticator
@property (nonatomic, copy) NSString *installationIdentification;

// Only set via BITAuthenticator
@property (nonatomic) BITAuthenticatorIdentificationType installationIdentificationType;

// Only set via BITAuthenticator
@property (nonatomic) BOOL installationIdentified;

#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */

- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier appEnvironment:(BITEnvironment)environment hockeyAppClient:(BITHockeyAppClient *)hockeyAppClient NS_DESIGNATED_INITIALIZER;

- (void)cleanCrashReports;

- (NSString *)userIDForCrashReport;
- (NSString *)userEmailForCrashReport;
- (NSString *)userNameForCrashReport;

- (void)handleCrashReport;
- (BOOL)hasPendingCrashReport;
- (NSString *)firstNotApprovedCrashReport;

- (void)persistUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData;
- (BOOL)persistAttachment:(BITHockeyAttachment *)attachment withFilename:(NSString *)filename;

- (BITHockeyAttachment *)attachmentForCrashReport:(NSString *)filename;

- (void)invokeDelayedProcessing;
- (void)sendNextCrashReport;

- (void)setLastCrashFilename:(NSString *)lastCrashFilename;

- (void)leavingAppSafely;

@end


#endif /* HOCKEYSDK_FEATURE_CRASH_REPORTER */
