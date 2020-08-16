// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import <Foundation/Foundation.h>

@class MSDistributionGroup;

/**
 * Details of an uploaded release.
 */
@interface MSReleaseDetails : NSObject

/**
 * ID identifying this unique release.
 */
@property(nonatomic, copy) NSNumber *id;

/**
 * The release's version
 * For iOS: CFBundleVersion from info.plist
 * For Android: android:versionCode from AndroidManifest.xml
 */
@property(nonatomic, copy) NSString *version;

/**
 * The release's short version.
 * For iOS: CFBundleShortVersionString from info.plist
 * For Android: android:versionName from AndroidManifest.xml
 */
@property(nonatomic, copy) NSString *shortVersion;

/**
 * The release's release notes.
 */
@property(nonatomic, copy) NSString *releaseNotes;

/**
 * The flag that indicates whether the release is a mandatory update or not.
 */
@property(nonatomic, getter=isMandatoryUpdate, assign) BOOL mandatoryUpdate;

/**
 * The URL that hosts the release notes for this release.
 */
@property(nonatomic, strong) NSURL *releaseNotesUrl;

@end
