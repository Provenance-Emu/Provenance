//
//  PVLogViewController.h
//  Provenance
//
//  Created by Joseph Mattiello on 8/11/15.
//  Copyright © 2015 Joe Mattiello. All rights reserved.
//

@import UIKit;
@import PVSupport;
@import CocoaLumberjack;
//#import <UIForLumberJack/UIForLumberJack.h>
#define kSPUILoggerMessageMargin 10

@interface UIForLumberjack : NSObject <UITableViewDataSource, UITableViewDelegate, DDLogger>

@property (nonatomic, strong) UITableView *tableView;

+ (UIForLumberjack*) sharedInstance;

- (void)showLogInView:(UIView*)view;
- (void)hideLog;

@end

@interface PVUIForLumberJack : UIForLumberjack
@end

@interface PVLogViewController : UIViewController <PVLoggingEventProtocol, UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UITextView *textView;
#if TARGET_OS_IOS
@property (strong, nonatomic) IBOutlet UIToolbar *toolbar;
#endif
@property (strong, nonatomic) IBOutlet UIView *contentView;

@property (strong, nonatomic) IBOutlet UISegmentedControl *segmentedControl;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *actionButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *doneButton;

- (IBAction)actionButtonPressed:(id)sender;
- (void)updateText:(NSString *)newText;

- (IBAction)segmentedControlValueChanged:(id)sender;

- (void)hideDoneButton;

#pragma mark - BootupHistory Protocol
- (void)updateHistory:(PVLogging *)sender;

@end

#if TARGET_OS_IOS
#import <MessageUI/MessageUI.h>

@interface PVLogViewController() <MFMailComposeViewControllerDelegate>
@end
#endif
