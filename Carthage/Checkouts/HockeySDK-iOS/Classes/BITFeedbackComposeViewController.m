/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "HockeySDKPrivate.h"

#import "BITFeedbackManagerPrivate.h"
#import "BITFeedbackMessageAttachment.h"
#import "BITFeedbackComposeViewController.h"
#import "BITFeedbackUserDataViewController.h"

#import "BITHockeyBaseManagerPrivate.h"

#import "BITHockeyHelper.h"

#import "BITImageAnnotationViewController.h"
#import "BITHockeyAttachment.h"

@interface BITFeedbackComposeViewController () <BITFeedbackUserDataDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate, BITImageAnnotationDelegate> {
}

@property (nonatomic, weak) BITFeedbackManager *manager;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIView *contentViewContainer;
@property (nonatomic, strong) UIScrollView *attachmentScrollView;
@property (nonatomic, strong) NSMutableArray *attachmentScrollViewImageViews;

@property (nonatomic, strong) UIButton *addPhotoButton;

@property (nonatomic, copy) NSString *text;

@property (nonatomic, strong) NSMutableArray *attachments;
@property (nonatomic, strong) NSMutableArray *imageAttachments;

@property (nonatomic, strong) UIView *textAccessoryView;
@property (nonatomic) NSInteger selectedAttachmentIndex;
@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;

@property (nonatomic) BOOL blockUserDataScreen;
@property (nonatomic) BOOL actionSheetVisible;

/**
 * Workaround for UIImagePickerController bug.
 * The statusBar shows up when the UIImagePickerController opens.
 * The status bar does not disappear again when the UIImagePickerController is dismissed.
 * Therefore store the state when UIImagePickerController is shown and restore when viewWillAppear gets called.
 */
@property (nonatomic, strong) NSNumber *isStatusBarHiddenBeforeShowingPhotoPicker;

@end


@implementation BITFeedbackComposeViewController


#pragma mark - NSObject

- (instancetype)init {
  self = [super init];
  if (self) {
    _blockUserDataScreen = NO;
    _actionSheetVisible = NO;
    _delegate = nil;
    _manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    _attachments = [NSMutableArray new];
    _imageAttachments = [NSMutableArray new];
    _attachmentScrollViewImageViews = [NSMutableArray new];
    _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(scrollViewTapped:)];
    [_attachmentScrollView addGestureRecognizer:self.tapRecognizer];
    
    _text = nil;
  }
  
  return self;
}


#pragma mark - Public

- (void)prepareWithItems:(NSArray *)items {
  for (id item in items) {
    if ([item isKindOfClass:[NSString class]]) {
      self.text = [(self.text ? self.text : @"") stringByAppendingFormat:@"%@%@", (self.text ? @" " : @""), item];
    } else if ([item isKindOfClass:[NSURL class]]) {
      self.text = [(self.text ? self.text : @"") stringByAppendingFormat:@"%@%@", (self.text ? @" " : @""), [(NSURL *)item absoluteString]];
    } else if ([item isKindOfClass:[UIImage class]]) {
      UIImage *image = item;
      BITFeedbackMessageAttachment *attachment = [BITFeedbackMessageAttachment attachmentWithData:UIImageJPEGRepresentation(image, (CGFloat)0.7) contentType:@"image/jpeg"];
      attachment.originalFilename = [NSString stringWithFormat:@"Image_%li.jpg", (unsigned long)[self.attachments count]];
      [self.attachments addObject:attachment];
      [self.imageAttachments addObject:attachment];
    } else if ([item isKindOfClass:[NSData class]]) {
      BITFeedbackMessageAttachment *attachment = [BITFeedbackMessageAttachment attachmentWithData:item contentType:@"application/octet-stream"];
      attachment.originalFilename = [NSString stringWithFormat:@"Attachment_%li.data", (unsigned long)[self.attachments count]];
      [self.attachments addObject:attachment];
    } else if ([item isKindOfClass:[BITHockeyAttachment class]]) {
      BITHockeyAttachment *sourceAttachment = (BITHockeyAttachment *)item;
      
      if (!sourceAttachment.hockeyAttachmentData) {
        BITHockeyLogDebug(@"BITHockeyAttachment instance doesn't contain any data.");
        continue;
      }
      
      NSString *filename = [NSString stringWithFormat:@"Attachment_%li.data", (unsigned long)[self.attachments count]];
      if (sourceAttachment.filename) {
        filename = sourceAttachment.filename;
      }
      
      BITFeedbackMessageAttachment *attachment = [BITFeedbackMessageAttachment attachmentWithData:sourceAttachment.hockeyAttachmentData contentType:sourceAttachment.contentType];
      attachment.originalFilename = filename;
      [self.attachments addObject:attachment];
    } else {
      BITHockeyLogWarning(@"WARNING: Unknown item type %@", item);
    }
  }
}


#pragma mark - Keyboard

- (void)keyboardWasShown:(NSNotification*)aNotification {
  NSDictionary* info = [aNotification userInfo];
  CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
  
  BOOL isPortraitOrientation = UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]);
  
  CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
  if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
    frame.size.height -= kbSize.height;
  } else {
    CGSize windowSize = [[UIScreen mainScreen] bounds].size;
    CGFloat windowHeight = windowSize.height - 20;
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    
    if (isPortraitOrientation) {
      frame.size.height = windowHeight - navBarHeight - kbSize.height;
    } else {
      windowHeight = windowSize.height - 20;
      CGFloat modalGap = 0.0;
      if (windowHeight - kbSize.height < self.view.bounds.size.height) {
        modalGap = 30;
      } else {
        modalGap = (windowHeight - self.view.bounds.size.height) / 2;
      }
      frame.size.height = windowSize.height - navBarHeight - modalGap - kbSize.height;
    }
  }
  [self.contentViewContainer setFrame:frame];
  
  [self performSelector:@selector(refreshAttachmentScrollview) withObject:nil afterDelay:0.0];
}

- (void)keyboardWillBeHidden:(NSNotification*) __unused aNotification {
  CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
  [self.contentViewContainer setFrame:frame];
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.title = BITHockeyLocalizedString(@"HockeyFeedbackComposeTitle");
  self.view.backgroundColor = [UIColor whiteColor];
  
  // Do any additional setup after loading the view.
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                        target:self
                                                                                        action:@selector(dismissAction:)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeSend")
                                                                            style:UIBarButtonItemStyleDone
                                                                           target:self
                                                                           action:@selector(sendAction:)];

  // Container that contains both the textfield and eventually the photo scroll view on the right side
  self.contentViewContainer = [[UIView alloc] initWithFrame:self.view.bounds];
  self.contentViewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  
  [self.view addSubview:self.contentViewContainer];
  
  // message input textfield
  self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
  self.textView.font = [UIFont systemFontOfSize:17];
  self.textView.delegate = self;
  self.textView.backgroundColor = [UIColor whiteColor];
  self.textView.returnKeyType = UIReturnKeyDefault;
  self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  self.textView.accessibilityHint = BITHockeyLocalizedString(@"HockeyAccessibilityHintRequired");
  
  [self.contentViewContainer addSubview:self.textView];
  
  // Add Photo Button + Container that's displayed above the keyboard.
  if([BITHockeyHelper isPhotoAccessPossible]) {
    self.textAccessoryView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 44)];
    self.textAccessoryView.backgroundColor = [UIColor colorWithRed:(CGFloat)0.9 green:(CGFloat)0.9 blue:(CGFloat)0.9 alpha:(CGFloat)1.0];
    
    self.addPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.addPhotoButton setTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeAttachmentAddImage") forState:UIControlStateNormal];
    [self.addPhotoButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self.addPhotoButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    self.addPhotoButton.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 44);
    [self.addPhotoButton addTarget:self action:@selector(addPhotoAction:) forControlEvents:UIControlEventTouchUpInside];
    self.addPhotoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    [self.textAccessoryView addSubview:self.addPhotoButton];
  }
  
  
  
  if (!self.hideImageAttachmentButton) {
    self.textView.inputAccessoryView = self.textAccessoryView;
  }
  
  // This could be a subclass, yet
  self.attachmentScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
  self.attachmentScrollView.scrollEnabled = YES;
  self.attachmentScrollView.bounces = YES;
  self.attachmentScrollView.autoresizesSubviews = NO;
  self.attachmentScrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleRightMargin;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0
  if (@available(iOS 11.0, *)) {
    self.attachmentScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAlways;
  }
#endif
  [self.contentViewContainer addSubview:self.attachmentScrollView];
}

- (void)viewWillAppear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWasShown:)
                                               name:UIKeyboardDidShowNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWillBeHidden:)
                                               name:UIKeyboardWillHideNotification object:nil];
  
  self.manager.currentFeedbackComposeViewController = self;
  
  [super viewWillAppear:animated];
  
  if (self.text && self.textView.text.length == 0) {
    self.textView.text = self.text;
  }
  
  if (self.isStatusBarHiddenBeforeShowingPhotoPicker) {
      [self setNeedsStatusBarAppearanceUpdate];
  }
  
  self.isStatusBarHiddenBeforeShowingPhotoPicker = nil;
  
  [self updateBarButtonState];
}

- (BOOL)prefersStatusBarHidden {
  if (self.isStatusBarHiddenBeforeShowingPhotoPicker) {
    return self.isStatusBarHiddenBeforeShowingPhotoPicker.boolValue;
  }
  
  return [super prefersStatusBarHidden];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  BITFeedbackManager *strongManager = self.manager;
  if ([strongManager askManualUserDataAvailable] &&
      ([strongManager requireManualUserDataMissing] ||
       ![strongManager didAskUserData])
      ) {
    if (!self.blockUserDataScreen)
      [self setUserDataAction];
  } else {
    // Invoke delayed to fix iOS 7 iPad landscape bug, where this view will be moved if not called delayed
    [self.textView performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.0];
    [self refreshAttachmentScrollview];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
  
  self.manager.currentFeedbackComposeViewController = nil;
  
  [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
}

- (void)refreshAttachmentScrollview {
  CGFloat scrollViewWidth = 0;
  
  if (self.imageAttachments.count){
    scrollViewWidth = 100;
  }
  
  CGRect textViewFrame = self.textView.frame;
  
  CGRect scrollViewFrame = self.attachmentScrollView.frame;
  
  BOOL alreadySetup = CGRectGetWidth(scrollViewFrame) > 0;
  
  if (alreadySetup && self.imageAttachments.count == 0) {
    textViewFrame.size.width += 100;
    self.textView.frame = textViewFrame;
    scrollViewFrame.size.width = 0;
    self.attachmentScrollView.frame = scrollViewFrame;
    return;
  }
  
  if (!alreadySetup) {
    CGSize tempTextViewSize = CGSizeMake(self.contentViewContainer.frame.size.width, self.contentViewContainer.frame.size.height);
    textViewFrame.size = tempTextViewSize;
    textViewFrame.size.width -= scrollViewWidth;
    // height has to be identical to the textview!
    scrollViewFrame = CGRectMake(CGRectGetMaxX(textViewFrame), self.view.frame.origin.y, scrollViewWidth, CGRectGetHeight(self.textView.bounds));
    self.textView.frame = textViewFrame;
    self.attachmentScrollView.frame = scrollViewFrame;
    self.attachmentScrollView.contentInset = self.textView.contentInset;
  }
  
  if (self.imageAttachments.count > self.attachmentScrollViewImageViews.count){
    NSInteger numberOfViewsToCreate = self.imageAttachments.count - self.attachmentScrollViewImageViews.count;
    for (int i = 0; i <numberOfViewsToCreate; i++) {
      UIButton *newImageButton = [UIButton buttonWithType:UIButtonTypeCustom];
      [newImageButton addTarget:self action:@selector(imageButtonAction:) forControlEvents:UIControlEventTouchUpInside];
      [self.attachmentScrollViewImageViews addObject:newImageButton];
      [self.attachmentScrollView addSubview:newImageButton];
    }
  }
  
  int index = 0;
  
  CGFloat currentYOffset = 0.0;
  
  NSEnumerator *reverseAttachments = self.imageAttachments.reverseObjectEnumerator;
  
  for (BITFeedbackMessageAttachment *attachment in reverseAttachments.allObjects){
    UIButton *imageButton = self.attachmentScrollViewImageViews[index];
    
    UIImage *image = [attachment thumbnailWithSize:CGSizeMake(100, 100)];
    
    // determine the factor by which we scale..
    CGFloat scaleFactor = CGRectGetWidth(self.attachmentScrollView.frame) / image.size.width;
    
    CGFloat height = image.size.height * scaleFactor;
    
    imageButton.frame = CGRectInset(CGRectMake(0, currentYOffset, scaleFactor * image.size.width, height), 10, 10);
    
    currentYOffset += height;
    
    [imageButton setImage:image forState:UIControlStateNormal];
    index++;
  }
  
  [self.attachmentScrollView setContentSize:CGSizeMake(CGRectGetWidth(self.attachmentScrollView.frame), currentYOffset)];
  
  [self updateBarButtonState];
}

- (void)updateBarButtonState {
  if (self.textView.text.length > 0 ) {
    self.navigationItem.rightBarButtonItem.enabled = YES;
  } else {
    self.navigationItem.rightBarButtonItem.enabled = NO;
  }
  
  if(self.addPhotoButton) {
    if (self.imageAttachments.count > 2){
      [self.addPhotoButton setEnabled:NO];
    } else {
      [self.addPhotoButton setEnabled:YES];
    }
  }
}

- (void)removeAttachmentScrollView {
  CGRect frame = self.attachmentScrollView.frame;
  frame.size.width = 0;
  self.attachmentScrollView.frame = frame;
  
  frame = self.textView.frame;
  frame.size.width += 100;
  self.textView.frame = frame;
}


#pragma mark - UIViewController Rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
  return UIInterfaceOrientationMaskAll;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation) __unused fromInterfaceOrientation {
  [self removeAttachmentScrollView];
  
  [self refreshAttachmentScrollview];
}
#pragma clang diagnostic pop

#pragma mark - Private methods

- (void)setUserDataAction {
  BITFeedbackUserDataViewController *userController = [[BITFeedbackUserDataViewController alloc] initWithStyle:UITableViewStyleGrouped];
  userController.delegate = self;
  
  UINavigationController *navController = [self.manager customNavigationControllerWithRootViewController:userController
                                                                                       presentationStyle:UIModalPresentationFormSheet];
  
  [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - Actions

- (void)dismissAction:(id) __unused sender {
  for (BITFeedbackMessageAttachment *attachment in self.attachments){
    [attachment deleteContents];
  }
  
  [self dismissWithResult:BITFeedbackComposeResultCancelled];
}

- (void)sendAction:(id) __unused sender {
  if ([self.textView isFirstResponder])
    [self.textView resignFirstResponder];
  
  NSString *text = self.textView.text;
  
  [self.manager submitMessageWithText:text andAttachments:self.attachments];
  
  [self dismissWithResult:BITFeedbackComposeResultSubmitted];
}

- (void)dismissWithResult:(BITFeedbackComposeResult) result {
  id strongDelegate = self.delegate;
  if([strongDelegate respondsToSelector:@selector(feedbackComposeViewController:didFinishWithResult:)]) {
    [strongDelegate feedbackComposeViewController:self didFinishWithResult:result];
  } else {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)addPhotoAction:(id) __unused sender {
  if (self.actionSheetVisible) return;
  
  self.isStatusBarHiddenBeforeShowingPhotoPicker = @([[UIApplication sharedApplication] isStatusBarHidden]);
  
  // add photo.
  UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
  pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  pickerController.delegate = self;
  pickerController.editing = NO;
  pickerController.navigationBar.barStyle = self.manager.barStyle;
  [self presentViewController:pickerController animated:YES completion:nil];
}

- (void)scrollViewTapped:(id) __unused unused {
  UIMenuController *menuController = [UIMenuController sharedMenuController];
  [menuController setTargetRect:CGRectMake([self.tapRecognizer locationInView:self.view].x, [self.tapRecognizer locationInView:self.view].x, 1, 1) inView:self.view];
  [menuController setMenuVisible:YES animated:YES];
}

- (void)paste:(id) __unused sender {
  
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
  UIImage *pickedImage = info[UIImagePickerControllerOriginalImage];
  
  if (pickedImage){
    NSData *imageData = UIImageJPEGRepresentation(pickedImage, (CGFloat)0.7);
    BITFeedbackMessageAttachment *newAttachment = [BITFeedbackMessageAttachment attachmentWithData:imageData contentType:@"image/jpeg"];
    NSURL *imagePath = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
    NSString *imageName = [imagePath lastPathComponent];
    newAttachment.originalFilename = imageName;
    [self.attachments addObject:newAttachment];
    [self.imageAttachments addObject:newAttachment];
  }
  
  [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imageButtonAction:(UIButton *)sender {
  // determine the index of the feedback
  NSInteger index = [self.attachmentScrollViewImageViews indexOfObject:sender];
  
  self.selectedAttachmentIndex = (self.attachmentScrollViewImageViews.count - index - 1);
  
  __weak typeof(self) weakSelf = self;
  
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];
  
  
  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeAttachmentCancel")
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction __unused *action) {
                                                         typeof(self) strongSelf = weakSelf;
                                                         [strongSelf cancelAction];
                                                         strongSelf.actionSheetVisible = NO;
                                                       }];
  
  [alertController addAction:cancelAction];
  
  UIAlertAction *editAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeAttachmentEdit")
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction __unused *action) {
                                                       typeof(self) strongSelf = weakSelf;
                                                       [strongSelf editAction];
                                                       strongSelf.actionSheetVisible = NO;
                                                     }];
  
  [alertController addAction:editAction];
  
  UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:BITHockeyLocalizedString(@"HockeyFeedbackComposeAttachmentDelete")
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction __unused *action) {
                                                         typeof(self) strongSelf = weakSelf;
                                                         [strongSelf deleteAction];
                                                         strongSelf.actionSheetVisible = NO;
                                                       }];
  
  [alertController addAction:deleteAction];
  
  [self presentViewController:alertController animated:YES completion:nil];
  
  self.actionSheetVisible = YES;
  if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9,0,0}])) {
    [self.textView resignFirstResponder];
  }
}


#pragma mark - BITFeedbackUserDataDelegate

- (void)userDataUpdateCancelled {
  self.blockUserDataScreen = YES;
  
  if ([self.manager requireManualUserDataMissing]) {
    if ([self.navigationController respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
      [self.navigationController dismissViewControllerAnimated:YES
                                                    completion:^(void) {
                                                      [self dismissViewControllerAnimated:YES completion:nil];
                                                    }];
    } else {
      [self dismissViewControllerAnimated:YES completion:nil];
      [self performSelector:@selector(dismissAction:) withObject:nil afterDelay:0.4];
    }
  } else {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)userDataUpdateFinished {
  [self.manager saveMessages];
  
  [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *) __unused textView {
  [self updateBarButtonState];
}


#pragma mark - UIActionSheet Delegate

- (void)deleteAction {
  if (self.selectedAttachmentIndex != NSNotFound){
    UIButton *imageButton = self.attachmentScrollViewImageViews[self.selectedAttachmentIndex];
    BITFeedbackMessageAttachment *attachment = self.imageAttachments[self.selectedAttachmentIndex];
    [attachment deleteContents]; // mandatory call to delete the files associated.
    [self.imageAttachments removeObject:attachment];
    [self.attachments removeObject:attachment];
    [imageButton removeFromSuperview];
    [self.attachmentScrollViewImageViews removeObject:imageButton];
  }
  self.selectedAttachmentIndex = NSNotFound;
  
  [self refreshAttachmentScrollview];
  
  if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || ([[NSProcessInfo processInfo] respondsToSelector:@selector(isOperatingSystemAtLeastVersion:)] && [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9,0,0}])) {
    [self.textView becomeFirstResponder];
  }
}

- (void)editAction {
  if (self.selectedAttachmentIndex != NSNotFound){
    BITFeedbackMessageAttachment *attachment = self.imageAttachments[self.selectedAttachmentIndex];
    BITImageAnnotationViewController *annotationEditor = [[BITImageAnnotationViewController alloc ] init];
    annotationEditor.delegate = self;
    UINavigationController *navController = [self.manager customNavigationControllerWithRootViewController:annotationEditor presentationStyle:UIModalPresentationFullScreen];
    annotationEditor.image = attachment.imageRepresentation;
    [self presentViewController:navController animated:YES completion:nil];
  }
}

- (void)cancelAction {
  if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) || ([[NSProcessInfo processInfo] respondsToSelector:@selector(isOperatingSystemAtLeastVersion:)] && [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){9,0,0}])) {
    [self.textView becomeFirstResponder];
  }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if (buttonIndex == [actionSheet destructiveButtonIndex]) {
    [self deleteAction];
  } else if (buttonIndex != [actionSheet cancelButtonIndex]) {
    [self editAction];
  } else {
    [self cancelAction];
  }
  self.actionSheetVisible = NO;
}


#pragma mark - Image Annotation Delegate

- (void)annotationController:(BITImageAnnotationViewController *) __unused annotationController didFinishWithImage:(UIImage *)image {
  if (self.selectedAttachmentIndex != NSNotFound){
    BITFeedbackMessageAttachment *attachment = self.imageAttachments[self.selectedAttachmentIndex];
    [attachment replaceData:UIImageJPEGRepresentation(image, (CGFloat)0.7)];
  }
  
  self.selectedAttachmentIndex = NSNotFound;
}

- (void)annotationControllerDidCancel:(BITImageAnnotationViewController *) __unused annotationController {
  self.selectedAttachmentIndex = NSNotFound;
}

@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
