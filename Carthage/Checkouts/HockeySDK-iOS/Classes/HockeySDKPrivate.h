/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
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
#import "BITHockeyLogger.h"

#ifndef HockeySDK_HockeySDKPrivate_h
#define HockeySDK_HockeySDKPrivate_h

#define BITHOCKEY_NAME @"HockeySDK"
#define BITHOCKEY_IDENTIFIER @"net.hockeyapp.sdk.ios"
#define BITHOCKEY_CRASH_SETTINGS @"BITCrashManager.plist"
#define BITHOCKEY_CRASH_ANALYZER @"BITCrashManager.analyzer"

#define BITHOCKEY_FEEDBACK_SETTINGS @"BITFeedbackManager.plist"

#define BITHOCKEY_USAGE_DATA @"BITUpdateManager.plist"

#define kBITHockeyMetaUserName  @"BITHockeyMetaUserName"
#define kBITHockeyMetaUserEmail @"BITHockeyMetaUserEmail"
#define kBITHockeyMetaUserID    @"BITHockeyMetaUserID"

#define kBITUpdateInstalledUUID              @"BITUpdateInstalledUUID"
#define kBITUpdateInstalledVersionID         @"BITUpdateInstalledVersionID"
#define kBITUpdateCurrentCompanyName         @"BITUpdateCurrentCompanyName"
#define kBITUpdateArrayOfLastCheck           @"BITUpdateArrayOfLastCheck"
#define kBITUpdateDateOfLastCheck            @"BITUpdateDateOfLastCheck"
#define kBITUpdateDateOfVersionInstallation  @"BITUpdateDateOfVersionInstallation"
#define kBITUpdateUsageTimeOfCurrentVersion  @"BITUpdateUsageTimeOfCurrentVersion"
#define kBITUpdateUsageTimeForUUID           @"BITUpdateUsageTimeForUUID"
#define kBITUpdateInstallationIdentification @"BITUpdateInstallationIdentification"

#define kBITStoreUpdateDateOfLastCheck       @"BITStoreUpdateDateOfLastCheck"
#define kBITStoreUpdateLastStoreVersion      @"BITStoreUpdateLastStoreVersion"
#define kBITStoreUpdateLastUUID              @"BITStoreUpdateLastUUID"
#define kBITStoreUpdateIgnoreVersion         @"BITStoreUpdateIgnoredVersion"

#define BITHOCKEY_INTEGRATIONFLOW_TIMESTAMP  @"BITIntegrationFlowStartTimestamp"

#define BITHOCKEYSDK_BUNDLE @"HockeySDKResources.bundle"
#define BITHOCKEYSDK_URL @"https://sdk.hockeyapp.net/"

#define BIT_RGBCOLOR(r,g,b) [UIColor colorWithRed:(CGFloat)((r)/255.0) green:(CGFloat)((g)/255.0) blue:(CGFloat)((b)/255.0) alpha:(CGFloat)1]

NSBundle *BITHockeyBundle(void);
NSString *BITHockeyLocalizedString(NSString *stringToken);
NSString *BITHockeyMD5(NSString *str);

#ifndef __IPHONE_11_0
#define __IPHONE_11_0    110000
#endif

#ifndef TARGET_OS_SIMULATOR

  #ifdef TARGET_IPHONE_SIMULATOR

    #define TARGET_OS_SIMULATOR TARGET_IPHONE_SIMULATOR

  #else

    #define TARGET_OS_SIMULATOR 0

  #endif /* TARGET_IPHONE_SIMULATOR */

#endif /* TARGET_OS_SIMULATOR */

#define kBITButtonTypeSystem                UIButtonTypeSystem

#endif /* HockeySDK_HockeySDKPrivate_h */
