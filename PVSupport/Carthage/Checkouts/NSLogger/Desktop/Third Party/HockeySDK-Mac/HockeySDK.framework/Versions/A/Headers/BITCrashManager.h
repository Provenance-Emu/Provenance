/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
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

#import <Foundation/Foundation.h>

#import "BITHockeyBaseManager.h"

// flags if the crashreporter is activated at all
// set this as bool in user defaults e.g. in the settings, if you want to let the user be able to deactivate it
#define kHockeySDKCrashReportActivated @"HockeySDKCrashReportActivated"

// flags if the crashreporter should automatically send crashes without asking the user again
// set this as bool in user defaults e.g. in the settings, if you want to let the user be able to set this on or off
// or set it on runtime using the `autoSubmitCrashReport property`
#define kHockeySDKAutomaticallySendCrashReports @"HockeySDKAutomaticallySendCrashReports"

@protocol BITCrashManagerDelegate;


@class BITCrashReportUI;
@class BITPLCrashReporter;

/**
 * The crash reporting module.
 *
 * This is the HockeySDK module for handling crash reports, including when distributed via the App Store.
 * As a foundation it is using the open source, reliable and async-safe crash reporting framework
 * [PLCrashReporter](https://www.plcrashreporter.org).
 *
 * This module works as a wrapper around the underlying crash reporting framework and provides functionality to
 * detect new crashes, queues them if networking is not available, present a user interface to approve sending
 * the reports to the HockeyApp servers and more.
 *
 * It also provides options to add additional meta information to each crash report, like `userName`, `userEmail`,
 * additional textual log information via `BITCrashanagerDelegate` protocol and a way to detect startup
 * crashes so you can adjust your startup process to get these crash reports too and delay your app initialization.
 *
 * Crashes are send the next time the app starts. If `autoSubmitCrashReport` is enabled, crashes will be send
 * without any user interaction, otherwise an alert will appear allowing the users to decide whether they want
 * to send the report or not. This module is not sending the reports right when the crash happens
 * deliberately, because if is not safe to implement such a mechanism while being async-safe (any Objective-C code
 * is _NOT_ async-safe!) and not causing more danger like a deadlock of the device, than helping. We found that users
 * do start the app again because most don't know what happened, and you will get by far most of the reports.
 *
 * Sending the reports on startup is done asynchronously (non-blocking) if the crash happened outside of the
 * time defined in `maxTimeIntervalOfCrashForReturnMainApplicationDelay`.
 *
 * More background information on this topic can be found in the following blog post by Landon Fuller, the
 * developer of [PLCrashReporter](https://www.plcrashreporter.org), about writing reliable and
 * safe crash reporting: [Reliable Crash Reporting](http://goo.gl/WvTBR)
 *
 * @warning If you start the app with the Xcode debugger attached, detecting crashes will _NOT_ be enabled!
 */
@interface BITCrashManager : BITHockeyBaseManager {
@private
  NSFileManager *_fileManager;
  
  BOOL _crashIdenticalCurrentVersion;
  BOOL _crashManagerActivated;
  
  NSTimeInterval _timeintervalCrashInLastSessionOccured;
  NSTimeInterval _maxTimeIntervalOfCrashForReturnMainApplicationDelay;
  
  NSInteger         _statusCode;
  NSURLConnection   *_urlConnection;
  NSMutableData     *_responseData;
  
  id<BITCrashManagerDelegate> _delegate;
  
  BOOL       _autoSubmitCrashReport;
  BOOL       _askUserDetails;
  
  NSMutableArray *_crashFiles;
  NSString       *_crashesDir;
  NSString       *_settingsFile;
  NSString       *_analyzerInProgressFile;
  
  BOOL                       _enableMachExceptionHandler;
  NSUncaughtExceptionHandler *_plcrExceptionHandler;
  BITPLCrashReporter         *_plCrashReporter;
  
  BITCrashReportUI *_crashReportUI;
  
  BOOL                _didCrashInLastSession;
  NSMutableDictionary *_approvedCrashReports;
  
  NSMutableDictionary *_dictOfLastSessionCrash;
  
  BOOL       _invokedReturnToMainApplication;
}

///-----------------------------------------------------------------------------
/// @name Delegate
///-----------------------------------------------------------------------------

// delegate is required
@property (nonatomic, assign) id <BITCrashManagerDelegate> delegate;


///-----------------------------------------------------------------------------
/// @name Configuration
///-----------------------------------------------------------------------------

/**
 *  Defines if the user interface should ask for name and email
 *
 *  Default: _YES_
 */
@property (nonatomic, assign) BOOL askUserDetails;


/**
 *  Trap fatal signals via a Mach exception server.
 *
 *  By default the SDK is using the safe and proven in-process BSD Signals for catching crashes.
 *  This option provides an option to enable catching fatal signals via a Mach exception server
 *  instead.
 *
 *  We strongly advice _NOT_ to enable Mach exception handler in release versions of your apps!
 *
 *  Default: _NO_
 *
 * @warning The Mach exception handler executes in-process, and will interfere with debuggers when
 *  they attempt to suspend all active threads (which will include the Mach exception handler).
 *  Mach-based handling should _NOT_ be used when a debugger is attached. The SDK will not
 *  enabled catching exceptions if the app is started with the debugger running. If you attach
 *  the debugger during runtime, this may cause issues the Mach exception handler is enabled!
 */
@property (nonatomic, assign, getter=isMachExceptionHandlerEnabled) BOOL enableMachExceptionHandler;

/**
 *  Submit crash reports without asking the user
 *
 *  _YES_: The crash report will be submitted without asking the user
 *  _NO_: The user will be asked if the crash report can be submitted (default)
 *
 *  Default: _NO_
 */
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

/**
 *  Time between startup and a crash within which sending a crash will be send synchronously
 *
 *  By default crash reports are being send asynchronously, since otherwise it may block the
 *  app from startup, e.g. while the network is down and the crash report can not be send until
 *  the timeout occurs.
 *
 *  But especially crashes during app startup could be frequent to the affected user and if the app
 *  would continue to startup normally it might crash right away again, resulting in the crash reports
 *  never to arrive.
 *
 *  This property allows to specify the time between app start and crash within which the crash report
 *  should be send synchronously instead to improve the probability of the crash report being send successfully.
 *
 *  Default: _5_
 */
@property (nonatomic, readwrite) NSTimeInterval maxTimeIntervalOfCrashForReturnMainApplicationDelay;


///-----------------------------------------------------------------------------
/// @name Crash Meta Information
///-----------------------------------------------------------------------------

/**
 * Indicates if the app crash in the previous session
 *
 * Use this on startup, to check if the app starts the first time after it crashed
 * previously. You can use this also to disable specific events, like asking
 * the user to rate your app.
 *
 * @warning This property only has a correct value, once `[BITHockeyManager startManager]` was
 * invoked!
 */
@property (nonatomic, readonly) BOOL didCrashInLastSession;


/**
 * Provides the time between startup and crash in seconds
 *
 * Use this in together with `didCrashInLastSession` to detect if the app crashed very
 * early after startup. This can be used to delay app initialization until the crash
 * report has been sent to the server or if you want to do any other actions like
 * cleaning up some cache data etc.
 *
 * The `BITCrashManagerDelegate` protocol provides some delegates to inform if sending
 * a crash report was finished successfully, ended in error or was cancelled by the user.
 *
 * *Default*: _-1_
 * @see didCrashInLastSession
 * @see BITCrashManagerDelegate
 */
@property (nonatomic, readonly) NSTimeInterval timeintervalCrashInLastSessionOccured;


///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  Detect if a debugger is attached to the app process
 *
 *  This is only invoked once on app startup and can not detect if the debugger is being
 *  attached during runtime!
 *
 *  @return BOOL if the debugger is attached on app startup
 */
- (BOOL)isDebuggerAttached;


/**
 * Lets the app crash for easy testing of the SDK
 *
 * The best way to use this is to trigger the crash with a button action.
 *
 * Make sure not to let the app crash in `applicationDidFinishLaunching` or any other
 * startup method! Since otherwise the app would crash before the SDK could process it.
 *
 * Note that our SDK provides support for handling crashes that happen early on startup.
 * Check the documentation for more information on how to use this.
 */
- (void)generateTestCrash;


@end
