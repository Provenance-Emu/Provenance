/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
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

#import <Cocoa/Cocoa.h>

@class BITFeedbackManager;

@interface BITFeedbackWindowController : NSWindowController {
@private
  BITFeedbackManager *_manager;
  NSDateFormatter *_lastUpdateDateFormatter;

  NSView *_userDataView;
  NSTextField *_userNameTextField;
  NSTextField *_userEmailTextField;
  NSButton *_userDataContinueButton;
  
  NSString *_userName;
  NSString *_userEmail;
  
  NSView *_feedbackView;
  NSView *_feedbackEmptyView;
  NSScrollView *_feedbackScrollView;
  NSTableView *_feedbackTableView;

  NSTextView *_messageTextField;
  NSAttributedString *_messageText;

  NSView *_statusBarComposeView;
  NSButton *_sendMessageButton;
  
  NSView *_statusBarDefaultView;
  NSProgressIndicator *_statusBarLoadingIndicator;
  NSTextField *_statusBarTextField;
  NSButton *_statusBarRefreshButton;
}

- (id)initWithManager:(BITFeedbackManager *)feedbackManager;

@end
