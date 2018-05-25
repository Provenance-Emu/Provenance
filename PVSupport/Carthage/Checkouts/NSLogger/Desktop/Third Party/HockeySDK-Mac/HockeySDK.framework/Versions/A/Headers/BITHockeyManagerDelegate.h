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

#import <Foundation/Foundation.h>
#import "BITCrashManagerDelegate.h"

@class BITHockeyManager;
@class BITHockeyBaseManager;

/**
 The `BITHockeyManagerDelegate` formal protocol defines methods further configuring
 the behaviour of `BITHockeyManager`, as well as the delegate of the modules it manages.
 */

@protocol BITHockeyManagerDelegate <NSObject, BITCrashManagerDelegate>

@optional


///-----------------------------------------------------------------------------
/// @name Additional meta data
///-----------------------------------------------------------------------------


/** Return the userid that should used in the SDK components
 
 Right now this is used by the `BITCrashMananger` to attach to a crash report and `BITFeedbackManager`.
 
 You can find out the component requesting the user name like this:
    - (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITCrashManager *)componentManager {
       if (componentManager == crashManager) {
         return UserNameForFeedback;
       } else {
         return nil;
       }
    }
 
 
 
 @param hockeyManager The `BITHockeyManager` HockeyManager instance invoking this delegate
 @param componentManager The `BITCrashManager` component instance invoking this delegate
 @see [BITHockeyManager setUserID:]
 @see userNameForHockeyManager:componentManager:
 @see userEmailForHockeyManager:componentManager:
 */
- (NSString *)userIDForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;


/** Return the user name that should used in the SDK components
 
 Right now this is used by the `BITCrashMananger` to attach to a crash report and `BITFeedbackManager`.
 
 You can find out the component requesting the user name like this:
    - (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITCrashManager *)componentManager {
        if (componentManager == crashManager) {
         return UserNameForFeedback;
        } else {
         return nil;
        }
    }
 
 
 @param hockeyManager The `BITHockeyManager` HockeyManager instance invoking this delegate
 @param componentManager The `BITCrashManager` component instance invoking this delegate
 @see [BITHockeyManager setUserName:]
 @see userIDForHockeyManager:componentManager:
 @see userEmailForHockeyManager:componentManager:
 */
- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;


/** Return the users email address that should used in the SDK components
 
 Right now this is used by the `BITCrashMananger` to attach to a crash report and `BITFeedbackManager`.
 
 You can find out the component requesting the user name like this:
    - (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITCrashManager *)componentManager {
        if (componentManager == hockeyManager.crashManager) {
         return UserNameForCrashReports;
        } else {
         return nil;
        }
    }
 
 
 @param hockeyManager The `BITHockeyManager` HockeyManager instance invoking this delegate
 @param componentManager The `BITCrashManager` component instance invoking this delegate
 @see [BITHockeyManager setUserEmail:]
 @see userIDForHockeyManager:componentManager:
 @see userNameForHockeyManager:componentManager:
 */
- (NSString *)userEmailForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager;

@end
