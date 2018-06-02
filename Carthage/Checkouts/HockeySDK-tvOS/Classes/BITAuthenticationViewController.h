#import <UIKit/UIKit.h>

@protocol BITAuthenticationViewControllerDelegate;
@class BITAuthenticator;
@class BITHockeyAppClient;

/**
 *  View controller handling user interaction for `BITAuthenticator`
 */
@interface BITAuthenticationViewController : UIViewController <UITextFieldDelegate>

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>) delegate;

/**
 *  Description shown on top of view. Should tell why this view 
 *  was presented and what's next.
 */
@property (nonatomic, copy) NSString* viewTitle;

/**
 *	can be set to YES to also require the users password
 *
 *  defaults to NO
 */
@property (nonatomic, assign) BOOL requirePassword;

@property (nonatomic, weak) id<BITAuthenticationViewControllerDelegate> delegate;

/**
 *  allows to pre-fill the email-addy
 */
@property (nonatomic, copy) NSString* email;
@end

/**
 *  BITAuthenticationViewController protocol
 */
@protocol BITAuthenticationViewControllerDelegate<NSObject>

/**
 *	called when the user wants to login
 *
 *	@param	viewController	the delegating view controller
 *	@param	email	the content of the email-field
 *	@param	password	the content of the password-field (if existent)
 *  @param  completion Must be called by the delegate once the auth-task completed
 *                     This view controller shows an activity-indicator in between and blocks
 *                     the UI. if succeeded is NO, it shows an alertView presenting the error
 *                     given by the completion block
 */
- (void) authenticationViewController:(UIViewController*) viewController
        handleAuthenticationWithEmail:(NSString*) email
                             password:(NSString*) password
                           completion:(void(^)(BOOL succeeded, NSError *error)) completion;

@end
