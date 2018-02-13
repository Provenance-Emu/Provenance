//
//  PVSettingsModel.h
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "kICadeControllerSetting.h"

NS_ASSUME_NONNULL_BEGIN
extern NSString * _Nonnull const kAutoSaveKey;
extern NSString *  _Nonnull const kAskToAutoLoadKey;
extern NSString *  _Nonnull const kAutoLoadAutoSavesKey;
extern NSString *  _Nonnull const kControllerOpacityKey;
extern NSString *  _Nonnull const kDisableAutoLockKey;
extern NSString *  _Nonnull const kButtonVibrationKey;
extern NSString *  _Nonnull const kImageSmoothingKey;
extern NSString *  _Nonnull const kCRTFilterKey;
extern NSString *  _Nonnull const kShowRecentGamesKey;
extern NSString *  _Nonnull const kICadeControllerSettingKey;
extern NSString *  _Nonnull const kVolumeSettingKey;
extern NSString *  _Nonnull const kFPSCountKey;
extern NSString *  _Nonnull const kShowGameTitlesKey;
extern NSString *  _Nonnull const kWebDayAlwwaysOnKey;
NS_ASSUME_NONNULL_END

@interface PVSettingsModel : NSObject

@property (nonatomic, assign) BOOL autoSave;
@property (nonatomic, assign) BOOL askToAutoLoad;
@property (nonatomic, assign) BOOL autoLoadAutoSaves;
@property (nonatomic, assign) BOOL disableAutoLock;
@property (nonatomic, assign) BOOL buttonVibration;
@property (nonatomic, assign) BOOL imageSmoothing;
@property (nonatomic, assign) BOOL crtFilterEnabled;
@property (nonatomic, assign) BOOL showRecentGames;
@property (nonatomic, assign) BOOL showFPSCount;
@property (nonatomic, assign) BOOL showGameTitles;
@property (nonatomic, assign) BOOL webDavAlwaysOn;
@property (nonatomic, assign) kICadeControllerSetting iCadeControllerSetting;

@property (nonatomic, assign) CGFloat controllerOpacity;
@property (nonatomic, assign) float volume;

+ (instancetype _Nonnull)sharedInstance;

@end
