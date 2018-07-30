#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

#import "BITAuthenticationViewController.h"

@class BITHockeyAppClient;

@interface BITAuthenticator ()<BITAuthenticationViewControllerDelegate>

/**
 Delegate that can be used to do any last minute configurations on the
 presented viewController.
 
 The delegate is automatically set by using `[BITHockeyManager setDelegate:]`. You
 should not need to set this delegate individually.
 
 @see `[BITHockeyManager setDelegate:]`
 @see BITAuthenticatorDelegate
 */
@property (nonatomic, weak) id<BITAuthenticatorDelegate> delegate;

/**
 * must be set
 */
@property (nonatomic, strong) BITHockeyAppClient *hockeyAppClient;

#pragma mark -
/**
 *  holds the identifier of the last version that was authenticated
 *  only used if validation is set BITAuthenticatorValidationTypeOnFirstLaunch
 */
@property (nonatomic, copy) NSString *lastAuthenticatedVersion;

/**
 *  returns the type of the string stored in installationIdentifierParameterString
 */
@property (nonatomic, copy, readonly) NSString *installationIdentifierParameterString;

/**
 *  returns the string used to identify this app against the HockeyApp backend.
 */
@property (nonatomic, copy, readonly) NSString *installationIdentifier;

/**
 * method registered as observer for applicationDidEnterBackground events
 *
 * @param note NSNotification
 */
- (void) applicationDidEnterBackground:(NSNotification*) note;

/**
 * method registered as observer for applicationsDidBecomeActive events
 *
 * @param note NSNotification
 */
- (void) applicationDidBecomeActive:(NSNotification*) note;

@property (nonatomic, copy) void(^identificationCompletion)(BOOL identified, NSError* error);

#pragma mark - Overrides
@property (nonatomic, assign, readwrite, getter = isIdentified) BOOL identified;
@property (nonatomic, assign, readwrite, getter = isValidated) BOOL validated;

#pragma mark - Testing
- (void) storeInstallationIdentifier:(NSString*) identifier withType:(BITAuthenticatorIdentificationType) type;
- (void)validateWithCompletion:(void (^)(BOOL validated, NSError *))completion;
- (void)authenticationViewController:(UIViewController *)viewController
       handleAuthenticationWithEmail:(NSString *)email
                             request:(NSURLRequest *)request
                          completion:(void (^)(BOOL, NSError *))completion;
- (BOOL) needsValidation;
- (void) authenticate;
@end

#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
