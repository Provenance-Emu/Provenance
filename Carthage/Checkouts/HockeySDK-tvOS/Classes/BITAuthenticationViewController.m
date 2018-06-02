#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_AUTHENTICATOR

#import "BITAuthenticationViewController.h"
#import "BITAuthenticator_Private.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"
#import "BITHockeyAppClient.h"
#import "BITAlertController.h"

@interface BITAuthenticationViewController ()
@property (nonatomic, strong) UITextField *emailTextField;
@property (nonatomic, strong) UITextField *passwordTextField;
@property (nonatomic, strong) UIButton *signInButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, copy) NSString *password;

@end

@implementation BITAuthenticationViewController

- (instancetype) initWithDelegate:(id<BITAuthenticationViewControllerDelegate>)delegate {
  self = [super init];
  if (self) {
    _delegate = delegate;
  }
  return self;
}

#pragma mark - view lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setupView];
  [self setupConstraints];
  [self blockMenuButton];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
}

#pragma mark - Property overrides

- (void) blockMenuButton {
  UITapGestureRecognizer *tapGestureRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(signInButtonTapped:)];
  tapGestureRec.allowedPressTypes = @[@(UIPressTypeMenu)];
  [self.view addGestureRecognizer:tapGestureRec];
}

- (void) signInButtonTapped:(id)sender {
  if ([self allRequiredFieldsEntered]) {
    [self saveAction:sender];
  } else {
    NSString *message = BITHockeyLocalizedString(@"HockeyAuthenticationWrongEmailPassword");
    
    BITAlertController *alertController = [BITAlertController alertControllerWithTitle:nil message:message];
    
    [alertController addCancelActionWithTitle:BITHockeyLocalizedString(@"OK")
                                      handler:nil];
    [alertController show];
  }
}

- (void)setEmail:(NSString *)email {
  _email = email;
  if(self.isViewLoaded) {
    self.emailTextField.text = email;
  }
}

- (void)setViewTitle:(NSString *)viewDescription {
  _viewTitle = [viewDescription copy];
}

#pragma mark - Private methods
- (BOOL)allRequiredFieldsEntered {
  if (self.requirePassword && [self.password length] == 0)
    return NO;
  
  if (![self.email length] || !bit_validateEmail(self.email))
    return NO;
  
  return YES;
}

- (void)userEmailEntered:(id)sender {
  self.email = [(UITextField *)sender text];
}

- (void)userPasswordEntered:(id)sender {
  self.password = [(UITextField *)sender text];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  if((textField == self.emailTextField) || (textField == self.passwordTextField)) {
    return YES;
  }
  return NO;
}

#pragma mark - Actions

- (void)saveAction:(id)sender {
  [self setLoginUIEnabled:NO];
  [self.delegate authenticationViewController:self
                handleAuthenticationWithEmail:self.email
                                     password:self.password
                                   completion:^(BOOL succeeded, NSError *error) {
                                     if(succeeded) {
                                       //controller should dismiss us shortly..
                                     } else {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                         
                                         BITAlertController *alertController = [BITAlertController alertControllerWithTitle:nil
                                                                                                                    message:error.localizedDescription];
                                         [alertController addCancelActionWithTitle:BITHockeyLocalizedString(@"OK")
                                                                           handler:nil];
                                         [alertController show];
                                         [self setLoginUIEnabled:YES];
                                       });
                                     }
                                   }];
}

#pragma mark - UI Setup

- (void) setLoginUIEnabled:(BOOL) enabled {
  [self.emailTextField setEnabled:enabled];
  [self.passwordTextField setEnabled:enabled];
  [self.signInButton setEnabled:enabled];
}

- (void)setupView {
  
  // Title Text
  self.title = BITHockeyLocalizedString(@"HockeyAuthenticatorViewControllerTitle");
  
  // Container View
  self.containerView = [UIView new];
  
  // E-Mail Input
  self.emailTextField = [UITextField new];
  self.emailTextField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerEmailDescription");
  self.emailTextField.text = self.email;
  self.emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
  self.emailTextField.delegate = self;
  self.emailTextField.returnKeyType = UIReturnKeyDone;
  [self.emailTextField addTarget:self action:@selector(userEmailEntered:) forControlEvents:UIControlEventEditingChanged];
  [self.containerView addSubview:self.emailTextField];
  
  // Password Input
  if (self.requirePassword) {
    self.passwordTextField = [UITextField new];
    self.passwordTextField.placeholder = BITHockeyLocalizedString(@"HockeyAuthenticationViewControllerPasswordDescription");
    self.passwordTextField.text = self.password;
    self.passwordTextField.keyboardType = UIKeyboardTypeAlphabet;
    self.passwordTextField.returnKeyType = UIReturnKeyDone;
    self.passwordTextField.secureTextEntry = YES;
    self.passwordTextField.delegate = self;
    [self.passwordTextField addTarget:self action:@selector(userPasswordEntered:) forControlEvents:UIControlEventEditingChanged];
    [self.containerView addSubview:self.passwordTextField];
  }
  
  // Sign Button
  self.signInButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [self.signInButton setTitle:BITHockeyLocalizedString(@"HockeyOK") forState:UIControlStateNormal];
  [self.signInButton addTarget:self action:@selector(signInButtonTapped:) forControlEvents:UIControlEventPrimaryActionTriggered];
  [self.containerView addSubview:self.signInButton];
  
  [self.view addSubview:self.containerView];
}

- (void)setupConstraints {
  
  // Preparing views for Auto Layout
  [self.emailTextField setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.passwordTextField setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.signInButton setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.containerView setTranslatesAutoresizingMaskIntoConstraints:NO];
  
  NSMutableDictionary *views = [NSMutableDictionary dictionaryWithObjectsAndKeys:self.emailTextField, @"email", self.signInButton, @"button", nil];
  if (self.requirePassword && self.passwordTextField) {
    [views addEntriesFromDictionary:@{@"password": self.passwordTextField}];
  }
  
  NSLayoutConstraint *centerVerticallyConstraint = [NSLayoutConstraint
                                                    constraintWithItem:self.containerView
                                                    attribute:NSLayoutAttributeCenterY
                                                    relatedBy:NSLayoutRelationEqual
                                                    toItem:self.view
                                                    attribute:NSLayoutAttributeCenterY
                                                    multiplier:1.0
                                                    constant:0];
  [self.view addConstraint:centerVerticallyConstraint];
  
  // Vertical Constraints
  NSString *verticalFormat = nil;
  if (self.requirePassword) {
    verticalFormat = @"V:|[email]-[password]-[button]|";
  } else {
    verticalFormat = @"V:|[email]-[button]|";
  }
  [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:verticalFormat options:0 metrics:nil views:views]];
  
  // Horizonatal Constraints
  NSString *horizontalFormat = @"H:|[email(500)]|";
  [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalFormat options:0 metrics:nil views:views]];
  
  if (self.requirePassword) {
    horizontalFormat = @"H:|[password(500)]|";
    [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalFormat options:0 metrics:nil views:views]];
  }
  
  horizontalFormat = @"H:[button(260)]";
  [self.containerView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:horizontalFormat options:0 metrics:nil views:views]];
  
  NSLayoutConstraint *centerXButtonConstraints = [NSLayoutConstraint
                                                  constraintWithItem:self.signInButton
                                                  attribute:NSLayoutAttributeCenterX
                                                  relatedBy:NSLayoutRelationEqual
                                                  toItem:self.containerView
                                                  attribute:NSLayoutAttributeCenterX
                                                  multiplier:1.0
                                                  constant:0];
  [self.containerView addConstraint:centerXButtonConstraints];
  
  NSLayoutConstraint *centerHorizontallyConstraint = [NSLayoutConstraint
                                                      constraintWithItem:self.containerView
                                                      attribute:NSLayoutAttributeCenterX
                                                      relatedBy:NSLayoutRelationEqual
                                                      toItem:self.view
                                                      attribute:NSLayoutAttributeCenterX
                                                      multiplier:1.0
                                                      constant:0];
  [self.view addConstraint:centerHorizontallyConstraint];
}

@end

#endif  /* HOCKEYSDK_FEATURE_AUTHENTICATOR */
