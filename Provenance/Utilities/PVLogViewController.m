//
//  PVLogViewController.m
//  Provenance
//
//  Created by Joseph Mattiello on 8/11/15.
//  Copyright © 2015 Joe Mattiello. All rights reserved.
//

#import "PVLogViewController.h"
@import QuartzCore;
#import "Provenance-Swift.h"
#import <asl.h>
@import PVSupport;
@import CocoaLumberjack;

//#import <UIForLumberJack/UIForLumberJack.h>
@import CocoaLumberjack.DDFileLogger;

/* Subclass to get rid of the prominent header we don't need */
@interface UIForLumberjack ()
//@property (nonatomic, strong) id<DDLogFormatter> logFormatter;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSMutableSet *messagesExpanded;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@interface PVUIForLumberJack ()
@property (strong, nonatomic) NSMutableArray* filteredTableData;
@end

@implementation PVUIForLumberJack
+ (instancetype) sharedInstance {
    static PVUIForLumberJack* sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PVUIForLumberJack alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.messages         = [NSMutableArray arrayWithCapacity:400];
        self.messagesExpanded = [NSMutableSet setWithCapacity:20];

        UITableView *tableView    = [[UITableView alloc] init];
        tableView.delegate        = self;
        tableView.dataSource      = self;
        tableView.backgroundColor = [UIColor blackColor];
        tableView.opaque          = YES;
        tableView.separatorStyle  = UITableViewCellSeparatorStyleNone;
        tableView.indicatorStyle  = UIScrollViewIndicatorStyleWhite;
        [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];

        self.tableView = tableView;
        
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"HH:mm:ss:SSS"];
    }
    return self;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    __block CGFloat height;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        height = 20;//[@"lorum ipsum" sizeWithFont:[self fontOfMessage] constrainedToSize:CGSizeMake(self.tableView.bounds.size.width - 30, FLT_MAX)].height + kSPUILoggerMessageMargin;
//    });

    NSUInteger estimatedNumberOflines = 1;
    NSInteger row = indexPath.row;
    if (row < self.messages.count) {
        DDLogMessage *line = self.messages[row];
        estimatedNumberOflines = ceil(line->_message.length / 150);
    }

    return 20 * estimatedNumberOflines;
}

- (void)logMessage:(DDLogMessage *)logMessage {
    [self.messages addObject:logMessage];

    __weak typeof(self) weakself = self;

    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakself) strongself = weakself;

        BOOL isVisible = strongself.tableView.superview != nil;;
        if (isVisible) {
            [strongself _addRow];
         }
    });
}

-(void)_addRow {
    
    // Store the count. Message is type atomic so
    // this should be thread safe once stored
    NSInteger count = self.messages.count;
    if (count > 0) {
        // Due to thread racing on insert message the array gets larger than the tableview
        // row count and the insertion of the row is out of the range sinc the math
        // is simply messages.count - 1. Really need a way to insert more than 1 row
        // and keep an index of the last inserted row, and add from that to messages.count-1
        NSInteger numberOfRows = [self.tableView numberOfRowsInSection:0];
        NSMutableArray *indexes= [NSMutableArray arrayWithCapacity:count-numberOfRows+1];
        
        if (numberOfRows == count) {
            // Cells were already added in previous
            // batch
            return;
        }
        
        // Capture if at bottom of scrollview
        BOOL scroll = NO;
        if(self.tableView.contentOffset.y + self.tableView.bounds.size.height >= (self.tableView.contentSize.height - 20)) {
            scroll = YES;
        }

        // Calcuate index path(s) that need addign
        NSIndexPath *indexPath;
        
        for (NSInteger i=numberOfRows-1; i<count-1; i++) {
            indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [indexes addObject:indexPath];
        }
        
        // Add the paths
        @try {
            [self.tableView insertRowsAtIndexPaths:indexes
                                  withRowAnimation:UITableViewRowAnimationBottom];
        } @catch (NSException *e){
                // Sometimes my math is wrong and it crashes.
                // just catch and move on, no spilt milk crying. -jm
            ELOG(@"%@", e.description);
        }
        
        // Scroll to new end if was at end before
        if(scroll && indexPath) {
            [self.tableView scrollToRowAtIndexPath:indexPath
                                  atScrollPosition:UITableViewScrollPositionBottom
                                          animated:YES];
        }
    }
}

- (void)showLogInView:(UIView*)view {
    [super showLogInView:view];
    [self.tableView reloadData];
}

#pragma mark Content Filtering
// TODO :: Filtering  - just need to swap out _filteredTableData for _messages in the tableview delegeate
// probably best to fork UIForLumberJack.
-(void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope {
    // Update the filtered array based on the search text and scope.
    // Remove all objects from the filtered search array
    [_filteredTableData removeAllObjects];
    // Filter the array using NSPredicate
    // Filte on log contents. Could use error type as well in the future
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.logMsg contains[c] %@",searchText];
    _filteredTableData = [NSMutableArray arrayWithArray:[self.messages filteredArrayUsingPredicate:predicate]];
}

@end

@interface PVLogViewController ()
@property (strong, nonatomic) IBOutlet UIBarButtonItem *logListButton;
- (IBAction)logListButtonClicked:(id)sender;
- (NSString*)systemLogAsString;
@end

@implementation PVLogViewController

- (void)dealloc {
    [[PVLogging sharedInstance] removeListner:self];
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (BOOL)automaticallyAdjustsScrollViewInsets {
    return YES;
}

- (void)viewDidLoad {
    _textView.editable = NO;
    _textView.userInteractionEnabled = YES;
    _textView.scrollEnabled = YES;


    self.doneButton.target = self;
    self.doneButton.action = @selector(doneButtonClicked:);
    
    self.view.layer.cornerRadius = 9.0f;

        // Force a refesh of the tet view
    [self segmentedControlValueChanged:self.segmentedControl];

	if (self.navigationController) {
		[self hideDoneButton];
	}

    [super viewDidLoad];
}

- (IBAction)doneButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (void)showLuberJackUI {
    self.textView.hidden = YES;
    [[PVUIForLumberJack sharedInstance] showLogInView:self.contentView];
}

- (void)hideLumberJackUI {
    self.textView.hidden = NO;
    [[PVUIForLumberJack sharedInstance] hideLog];
}

    // override the showAnimated - place holder of text
- (IBAction)actionButtonPressed:(id)sender {
	[self createAndShareZip];
}

- (void)updateText:(NSString *)newText {
    if (newText) {
        self.textView.text = newText;
    }
}

- (void)hideDoneButton {
	NSMutableArray *items = [self.toolbar.items mutableCopy];
	[items removeObject:self.doneButton];
	[self.toolbar setItems:items];
}


- (IBAction)segmentedControlValueChanged:(id)sender {

    if(_systemLogOperation){
        [_systemLogOperation cancel];
        _systemLogOperation = nil;
    }

    NSMutableArray *items = [self.toolbar.items mutableCopy];
    if (self.segmentedControl.selectedSegmentIndex == 2 && ![items containsObject:self.logListButton]) {
        self.logListButton.enabled = YES;
        [items insertObject:self.logListButton atIndex:0];
        [self.toolbar setItems:items];
    } else if ([items containsObject:self.logListButton]){
        [items removeObject:self.logListButton];
        [self.toolbar setItems:items];
    }

    switch(self.segmentedControl.selectedSegmentIndex){

        case 0: {
            [self showLuberJackUI];

            break;
        }
        case 1: {
            [self hideLumberJackUI];
                // Register for updates
            [[PVLogging sharedInstance] removeListner:self];
            [self updateText:@"Loading..."];

            __weak PVLogViewController *weakSelf = self;
            
                // TODO :: This should be in a backgroudn thread
                // because it take a while to build the string
            _systemLogOperation =
            [NSBlockOperation blockOperationWithBlock:^{
                NSString *log;
                if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
                   log = [weakSelf systemLogAsString];
                } else {
                    log = @"not supported on this ios version";
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf updateText:log];
                });
            }];

            [_systemLogOperation start];


            break;
        }
        case 2:{
            [self hideLumberJackUI];

                // Fill in text
            [self updateText:[self logTextForIndex:0]];
                // Register for updates
            [[PVLogging sharedInstance] registerListner:self];

            break;
        }
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskAll;
}

/**
 *  GEts log files and zips them together
 *
 *  @return Path of zip file
 */
- (NSString*)zipLogFiles {
    PVLogging *logging = [PVLogging sharedInstance];

    [logging flushLogs];
    NSArray *files = [logging logFilePaths];

    
    NSError *error = nil;

    NSString *tempDir = NSTemporaryDirectory();
    BOOL success =
    [[NSFileManager defaultManager] createDirectoryAtPath:tempDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (!success) {
        ELOG(@"%@", error.localizedDescription);
    }
    
    NSString *zipPath = [tempDir stringByAppendingPathComponent:@"logs.zip"];


	[SSZipArchive createZipFileAtPath:zipPath
					 withFilesAtPaths:files];

	return zipPath;
}

- (IBAction)logListButtonClicked:(id)sender {

        // Create popover if never created

	UITableViewController *logsTableViewController = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];

	logsTableViewController.tableView.dataSource = self;
	logsTableViewController.tableView.delegate = self;

	logsTableViewController.modalPresentationStyle = UIModalPresentationPopover;
	logsTableViewController.popoverPresentationController.barButtonItem = self.logListButton;

	[self presentViewController:logsTableViewController
					   animated:YES
					 completion:nil];
}
#define ADD_FLOG_ATTACHMENTS_TO_SUPPORT_EMAILS 1

- (void)createAndShareZip {
	//add attachments
	NSArray *logFilePaths = [[PVLogging sharedInstance] logFilePaths];

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"yyyyMMMd-hh:mm"
														   options:0
															locale:[NSLocale currentLocale]];

	NSString *fileName = [NSString stringWithFormat:@"Provenance %@ Logs", [formatter stringFromDate:[NSDate date]]];

	NSString *zipDestination = [self tmpFileWithName:fileName
										   extension:@".zip"];

	// Add system logs (ASL)
//#if !TARGET_IPHONE_SIMULATOR
//	// Add system log Don't do it on SIM bcs it takes forever. Logs are
//	// much larger - JOe M
//	if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
//		NSError *error;
//		NSString *systemLogDestination = [self tmpFileWithName:[NSString stringWithFormat:@"Provenance System"]
//													 extension:@".log"];
//		NSString *systemLog = [self systemLogAsString];
//		BOOL success =
//		[systemLog writeToFile:systemLogDestination
//					atomically:YES
//					  encoding:NSUTF8StringEncoding
//						 error:&error];
//		if (!success) {
//			ELOG(@"Could not bundle system log. %@", [error localizedDescription]);
//		} else {
//			logFilePaths = [logFilePaths arrayByAddingObject:systemLogDestination];
//		}
//	}
//#endif

	BOOL zipSuccess =
	[SSZipArchive createZipFileAtPath:zipDestination
					 withFilesAtPaths:logFilePaths];

	if (zipSuccess) {
		NSURL *zipURL = [NSURL fileURLWithPath:zipDestination];


		UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[zipURL] applicationActivities:nil];
		activityVC.popoverPresentationController.barButtonItem = self.actionButton;
		[self presentViewController:activityVC
						   animated:true
						 completion:nil];
	}
}

- (NSString *) tmpFileWithName:(nonnull NSString*)name
                     extension:(nonnull NSString*)extension {

        // We use mkstemps() which needs 6 X's as a 'template' filename
        // it replaces those X's with random chars.
        // https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/man3/mkstemps.3.html
    NSString *fileName = [NSString stringWithFormat:@"%@-XXXXXX.%@", name, extension];
    NSString *temporaryDirectory = NSTemporaryDirectory();
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:temporaryDirectory
                                              isDirectory:&isDirectory]) {
        ILOG(@"Not temporay directory at path <%@>. Creating.", temporaryDirectory);
        NSError *error;
        if ([[NSFileManager defaultManager] createDirectoryAtPath:temporaryDirectory
                                      withIntermediateDirectories:YES
                                                       attributes:@{}
                                                            error:&error]) {
            ILOG(@"Created temporay directory");
        } else {
            ELOG(@"Couldn't create temp directory: %@", error.localizedDescription);
        }
    }

    NSString *tempFileTemplate = [NSTemporaryDirectory()
                                  stringByAppendingPathComponent:fileName];

        // Erase if exists
    [[NSFileManager defaultManager] removeItemAtPath:fileName
                                               error:nil];

    const char *tempFileTemplateCString =
    [tempFileTemplate fileSystemRepresentation];

    size_t strln = strlen(tempFileTemplateCString);
    char *tempFileNameCString = (char *)malloc(strln + 1);
    strncpy(tempFileNameCString, tempFileTemplateCString, strln);
    int fileDescriptor = mkstemps(tempFileNameCString, 4);

        // no need to keep it open
    close(fileDescriptor);

    if (fileDescriptor == -1) {
        ELOG(@"Error while creating tmp file %s", tempFileNameCString);
        free(tempFileNameCString);
        return nil;
    }

    NSString *tempFileName = [[NSFileManager defaultManager]
                              stringWithFileSystemRepresentation:tempFileNameCString
                              length:strlen(tempFileNameCString)];
    
    free(tempFileNameCString);
    
    return tempFileName;
}

-(NSString*)systemLogAsString{
    aslmsg q, m;
    int i;
    const char *key, *val;

    q = asl_new(ASL_TYPE_QUERY);

        // Search exampls
        //    asl_set_query(q, ASL_KEY_SENDER, "Logger", ASL_QUERY_OP_EQUAL);

    aslresponse r = asl_search(NULL, q);

    NSMutableString *logString = [NSMutableString new];

    while (NULL != (m = asl_next(r)))
    {
        for (i = 0; (NULL != (key = asl_key(m, i))); i++)
        {
            val = asl_get(m, key);
            [logString appendFormat:@"%s:%s\n",(char*)key,val];
        }
    }
    asl_release(r);

    return logString;
}

- (NSString*)logTextForIndex:(NSInteger)index {

    NSArray *logs = [[PVLogging sharedInstance] logFilePaths];

    if (index >= logs.count) {
        return @"Log index too large";
    }

    NSString *logPath = logs[index];
    NSError *error;

    NSString *logText = [NSString stringWithContentsOfFile:logPath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];

    if (!logText) {
        logText = [error localizedDescription];
    }

    return logText;
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error sending e-mail"
                                                                       message:error.localizedDescription
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                              }];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        ELOG(@"%@", error.localizedDescription);
    } else {
        ILOG(@"Support e-mail sent");
    }
    
    [controller dismissViewControllerAnimated:YES
                                   completion:nil];
}

#pragma mark - BootupHistory Protocol
- (void)updateHistory:(PVLogging *)sender {
    if (self.segmentedControl.selectedSegmentIndex == 0){
        [self updateText:[sender historyString]];
    }
}

#pragma mark - Table View Delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[PVLogging sharedInstance] flushLogs];

    [self updateText:[self logTextForIndex:indexPath.row]];
	[self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table View Data Source
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"cell"];
    }
    NSArray *infos = [[PVLogging sharedInstance] logFileInfos];

    if (indexPath.row < infos.count) {
        DDLogFileInfo *info = infos[indexPath.row];

        cell.textLabel.textColor = info.isArchived ?
        [UIColor colorWithRed:.6
                        green:.88
                         blue:.6
                        alpha:1] :
        [UIColor colorWithRed:.88
                        green:.6
                         blue:.6
                        alpha:1];

        cell.textLabel.text = [NSDateFormatter localizedStringFromDate:info.creationDate
                                                             dateStyle:NSDateFormatterShortStyle
                                                             timeStyle:NSDateFormatterShortStyle];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Size: %.2fkb", info.fileSize/1024.];
    } else {
        cell.textLabel.text = @"Error";
    }

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; };

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger num = 0;
    if (section == 0) {
        num = [[[PVLogging sharedInstance] logFilePaths] count];
    }
    
    return num;
}
@end

// Copy/pasting code here because their cocoapod has never been updated for newer lumberjack 2.0. Need to just fork this project and sumbit our great updates.

@implementation UIForLumberjack
@synthesize logFormatter;

+ (UIForLumberjack*) sharedInstance {
    static UIForLumberjack *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UIForLumberjack alloc] init];
        sharedInstance.messages = [NSMutableArray array];
        sharedInstance.messagesExpanded = [NSMutableSet set];
        
        sharedInstance.tableView = [[UITableView alloc] init];
        sharedInstance.tableView.delegate = sharedInstance;
        sharedInstance.tableView.dataSource = sharedInstance;
        [sharedInstance.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];
        sharedInstance.tableView.backgroundColor = [UIColor blackColor];
        sharedInstance.tableView.alpha = 0.8f;
        sharedInstance.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        sharedInstance.dateFormatter = [[NSDateFormatter alloc] init];
        [sharedInstance.dateFormatter setDateFormat:@"HH:mm:ss:SSS"];
    });
    return sharedInstance;
}

#pragma mark - DDLogger
- (void)logMessage:(DDLogMessage *)logMessage
{
	MAKEWEAK(self);
    dispatch_async(dispatch_get_main_queue(), ^{
		MAKESTRONG(self);
        [strongself.messages addObject:logMessage];
        
        BOOL scroll = NO;
		UITableView *tableView = strongself.tableView;
		if(tableView.contentOffset.y + tableView.bounds.size.height >= tableView.contentSize.height) {
            scroll = YES;
		}
        
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:strongself.messages.count-1
													inSection:0];
        [tableView insertRowsAtIndexPaths:@[indexPath]
						 withRowAnimation:UITableViewRowAnimationBottom];
        
        if(scroll) {
            [strongself.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    });
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"LogCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forRowAtIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    DDLogMessage *message = _messages[indexPath.row];
    
    switch (message->_flag) {
        case DDLogFlagError:
            cell.textLabel.textColor = [UIColor redColor];
            break;
            
        case DDLogFlagWarning:
            cell.textLabel.textColor = [UIColor orangeColor];
            break;
            
        case DDLogFlagDebug:
            cell.textLabel.textColor = [UIColor greenColor];
            break;
            
        case DDLogFlagVerbose:
            cell.textLabel.textColor = [UIColor blueColor];
            break;
        case DDLogFlagInfo:
        default:
            cell.textLabel.textColor = [UIColor whiteColor];
            break;
    }
    
    cell.textLabel.text = [self textOfMessageForIndexPath:indexPath];
    cell.textLabel.font = [self fontOfMessage];
    cell.textLabel.numberOfLines = 0;
    cell.backgroundColor = [UIColor clearColor];
}

- (NSString*)textOfMessageForIndexPath:(NSIndexPath*)indexPath
{
    DDLogMessage *message = _messages[indexPath.row];
    if ([_messagesExpanded containsObject:@(indexPath.row)]) {
        return [NSString stringWithFormat:@"[%@] %@:%lu [%@]", [_dateFormatter stringFromDate:message->_timestamp], message->_fileName, (unsigned long)message->_line, message->_function];
    } else {
        return [NSString stringWithFormat:@"[%@] %@", [_dateFormatter stringFromDate:message->_timestamp], message->_message];
    }
}

- (UIFont*)fontOfMessage
{
    return [UIFont boldSystemFontOfSize:9];
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *messageText = [self textOfMessageForIndexPath:indexPath];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    return [messageText sizeWithFont:[self fontOfMessage] constrainedToSize:CGSizeMake(self.tableView.bounds.size.width - 30, FLT_MAX)].height + kSPUILoggerMessageMargin;
#else
    return ceil([messageText boundingRectWithSize:CGSizeMake(self.tableView.bounds.size.width - 30, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:[self fontOfMessage]} context:nil].size.height + kSPUILoggerMessageMargin);
#endif
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton setTitle:@"Hide Log" forState:UIControlStateNormal];
    closeButton.backgroundColor = [UIColor colorWithRed:59/255.0 green:209/255.0 blue:65/255.0 alpha:1];
    [closeButton addTarget:self action:@selector(hideLog) forControlEvents:UIControlEventTouchUpInside];
    return closeButton;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSNumber *index = @(indexPath.row);
    if ([_messagesExpanded containsObject:index]) {
        [_messagesExpanded removeObject:index];
    } else {
        [_messagesExpanded addObject:index];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - public methods
- (void)showLogInView:(UIView*)view
{
    [view addSubview:self.tableView];
    UITableView *tv = self.tableView;
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tv]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(tv)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(tv)]];
}

- (void)hideLog
{
    [self.tableView removeFromSuperview];
}

@end
