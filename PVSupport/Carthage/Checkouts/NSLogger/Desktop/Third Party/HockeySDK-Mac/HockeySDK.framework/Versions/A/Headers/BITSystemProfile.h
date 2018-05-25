//
//  Author: Thomas Dohmke <thomas@dohmke.de>
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

#import <Foundation/Foundation.h>

/**
 * Helper class for accessing system information and measuring usage time
 */
@interface BITSystemProfile : NSObject {
@private
  NSDate *_usageStartTimestamp;
  NSInteger _startCounter;
}

///-----------------------------------------------------------------------------
/// @name Initialization
///-----------------------------------------------------------------------------

/**
 * Returns a shared BITSystemProfile object
 *
 * @return A singleton BITSystemProfile instance ready use
 */
+ (BITSystemProfile *)sharedSystemProfile;


///-----------------------------------------------------------------------------
/// @name Generic
///-----------------------------------------------------------------------------

/**
 *  Return the current devices identifier
 *
 *  @return NSString with the device identifier
 */
+ (NSString *)deviceIdentifier;

/**
 *  Return the current device model
 *
 *  @return NSString with the repesentation of the device model
 */
+ (NSString *)deviceModel;

/**
 *  Return the system version of the current device
 *
 *  @return NSString with the system version
 */
+ (NSString *)systemVersionString;

/**
 *  Return an array with system data for a specific bundle
 *
 *  @param bundle The app or framework bundle to get the system data from
 *
 *  @return NSMutableArrray with system data
 */
- (NSMutableArray *)systemDataForBundle:(NSBundle *)bundle;

/**
 *  Return an array with system data
 *
 *  @return NSMutableArray with system data
 */
- (NSMutableArray *)systemData;

/**
 *  Return an array with system usage data for a specific bundle
 *
 *  @param bundle The app or framework bundle to get the usage data from
 *
 *  @return NSMutableArray with system and bundle usage data
 */
- (NSMutableArray *)systemUsageDataForBundle:(NSBundle *)bundle;

/**
 *  Return an array with system usage data that can be used with Sparkle
 *
 *  Call this method in the Sparkle delegate `feedParametersForUpdater:sendingSystemProfile:`
 *  to attach system and app data to each Sparkle request
 *
 *  @return NSMutableArray with system and app usage data
 */
- (NSMutableArray *)systemUsageData;


///-----------------------------------------------------------------------------
/// @name Usage time
///-----------------------------------------------------------------------------

/**
 *  Start recording usage time for a specific app or framework bundle
 *
 *  @param bundle The app or framework bundle to measure the usage time for
 */
- (void)startUsageForBundle:(NSBundle *)bundle;

/**
 *  Start recording usage time for the current app
 */
- (void)startUsage;

/**
 *  stop recording usage time
 */
- (void)stopUsage;

@end
