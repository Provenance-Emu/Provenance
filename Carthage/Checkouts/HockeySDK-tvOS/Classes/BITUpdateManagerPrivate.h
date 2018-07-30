#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_UPDATES

/** TODO:
  * if during startup the auth-state is pending, we get never rid of the nag-alertview
 */
@interface BITUpdateManager () {
}

///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the `BITUpdateManagerDelegate` delegate.
 
 The delegate is automatically set by using `[BITHockeyManager setDelegate:]`. You
 should not need to set this delegate individually.
 
 @see `[BITHockeyManager setDelegate:]`
 */
@property (nonatomic, weak) id delegate;


// is an update available?
@property (nonatomic, assign, getter=isUpdateAvailable) BOOL updateAvailable;

// are we currently checking for updates?
@property (nonatomic, assign, getter=isCheckInProgress) BOOL checkInProgress;

@property (nonatomic, strong) NSMutableData *receivedData;

@property (nonatomic, copy) NSDate *lastCheck;

// get array of all available versions
@property (nonatomic, copy) NSArray *appVersions;

@property (nonatomic, strong) NSNumber *currentAppVersionUsageTime;

@property (nonatomic, copy) NSDate *usageStartTimestamp;

@property (nonatomic, strong) UIView *blockingView;

@property (nonatomic, copy) NSString *companyName;

@property (nonatomic, copy) NSString *installationIdentification;

@property (nonatomic, copy) NSString *installationIdentificationType;

@property (nonatomic) BOOL installationIdentified;

// used by BITHockeyManager if disable status is changed
@property (nonatomic, getter = isUpdateManagerDisabled) BOOL disableUpdateManager;

@property(nonatomic) BOOL sendUsageData;

// checks for update
- (void)sendCheckForUpdateRequest;

- (NSURLRequest *)requestForUpdateCheck;

// convenience method to get current running version string
- (NSString *)currentAppVersion;

// get newest app version
- (BITAppVersionMetaInfo *)newestAppVersion;

// check if there is any newer version mandatory
- (BOOL)hasNewerMandatoryVersion;

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
