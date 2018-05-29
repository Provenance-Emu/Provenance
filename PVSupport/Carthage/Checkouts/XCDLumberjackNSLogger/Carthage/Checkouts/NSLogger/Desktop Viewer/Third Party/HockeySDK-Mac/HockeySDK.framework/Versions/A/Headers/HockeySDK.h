// 
//  Author: Andreas Linde <mail@andreaslinde.de>
// 
//  Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH. All rights reserved.
//  See LICENSE.txt for author information.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <HockeySDK/BITHockeyManager.h>
#import <HockeySDK/BITHockeyManagerDelegate.h>

#import <HockeySDK/BITCrashManager.h>
#import <HockeySDK/BITCrashManagerDelegate.h>

#import <HockeySDK/BITSystemProfile.h>

#import <HockeySDK/BITFeedbackManager.h>
#import <HockeySDK/BITFeedbackWindowController.h>


// Notification message which HockeyManager is listening to, to retry requesting updated from the server
#define BITHockeyNetworkDidBecomeReachableNotification @"BITHockeyNetworkDidBecomeReachable"

extern NSString *const __attribute__((unused)) kBITDefaultUserID;
extern NSString *const __attribute__((unused)) kBITDefaultUserName;
extern NSString *const __attribute__((unused)) kBITDefaultUserEmail;

// hockey crash reporting api error domain
typedef enum {
  BITCrashErrorUnknown,
  BITCrashAPIAppVersionRejected,
  BITCrashAPIReceivedEmptyResponse,
  BITCrashAPIErrorWithStatusCode
} BITCrashErrorReason;
extern NSString *const __attribute__((unused)) kBITCrashErrorDomain;


// hockey feedback api error domain
typedef enum {
  BITFeedbackErrorUnknown,
  BITFeedbackAPIServerReturnedInvalidStatus,
  BITFeedbackAPIServerReturnedInvalidData,
  BITFeedbackAPIServerReturnedEmptyResponse,
  BITFeedbackAPIClientAuthorizationMissingSecret,
  BITFeedbackAPIClientCannotCreateConnection
} BITFeedbackErrorReason;
extern NSString *const __attribute__((unused)) kBITFeedbackErrorDomain;


// HockeySDK

typedef enum {
  BITHockeyErrorUnknown,
  HockeyAPIClientMissingJSONLibrary
} BITHockeyErrorReason;
extern NSString *const __attribute__((unused)) kBITHockeyErrorDomain;
