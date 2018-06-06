#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES || HOCKEYSDK_FEATURE_FEEDBACK

#import "BITHockeyBaseViewController.h"
#import "HockeySDKPrivate.h"

@interface BITHockeyBaseViewController ()

@property (nonatomic) BOOL modal;

@end

@implementation BITHockeyBaseViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    _modalAnimated = YES;
    _modal = NO;
  }
  return self;
}

- (instancetype)initWithStyle:(UITableViewStyle)style modal:(BOOL)modal {
  self = [self initWithStyle:style];
  if (self) {
    _modal = modal;
    
    //might be better in viewDidLoad, but to workaround rdar://12214613 and as it doesn't
    //hurt, we do it here
    if (_modal) {
      self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                            target:self
                                                                                            action:@selector(onDismissModal:)];
    }
  }
  return self;
}

- (instancetype)initWithModalStyle:(BOOL)modal {
  self = [self initWithStyle:UITableViewStylePlain modal:modal];
  return self;
}


#pragma mark - View lifecycle

- (void)onDismissModal:(id)sender {
  if (self.modal) {
    UIViewController *presentingViewController = [self presentingViewController];
    
    // If there is no presenting view controller just remove view
    if (presentingViewController && self.modalAnimated) {
      [presentingViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
      [self.navigationController.view removeFromSuperview];
    }
  } else {
    [self.navigationController popViewControllerAnimated:YES];
  }
}

#pragma mark - Modal presentation


@end

#endif /* HOCKEYSDK_FEATURE_AUTHENTICATOR || HOCKEYSDK_FEATURE_UPDATES */
