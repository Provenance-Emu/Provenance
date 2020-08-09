// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSReleaseDetails.h"

@class MSDistribute;

@protocol MSDistributeDelegate <NSObject>

@optional

/**
 * Callback method that will be called whenever a new release is available for update.
 *
 * @param distribute The instance of MSDistribute.
 * @param details Release details for the update.
 *
 * @return Return YES if you want to take update control by overriding default update dialog, NO otherwise.
 *
 * @see [MSDistribute notifyUpdateAction:]
 */
- (BOOL)distribute:(MSDistribute *)distribute releaseAvailableWithDetails:(MSReleaseDetails *)details;

@end
