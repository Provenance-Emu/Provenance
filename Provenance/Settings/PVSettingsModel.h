//
//  PVSettingsModel.h
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "kICadeControllerSetting.h"

extern NSString * const kAutoSaveKey;
extern NSString * const kAskToAutoLoadKey;
extern NSString * const kAutoLoadAutoSavesKey;
extern NSString * const kControllerOpacityKey;
extern NSString * const kDisableAutoLockKey;
extern NSString * const kButtonVibrationKey;
extern NSString * const kImageSmoothingKey;
extern NSString * const kShowRecentGamesKey;
extern NSString * const kiCadeControllerSettingKey;
extern NSString * const kVolumeSettingKey;
extern NSString * const kFPSCountKey;
extern NSString * const kShowGameTitlesKey;

@interface PVSettingsModel : NSObject

@property (nonatomic, assign) BOOL autoSave;
@property (nonatomic, assign) BOOL askToAutoLoad;
@property (nonatomic, assign) BOOL autoLoadAutoSaves;
@property (nonatomic, assign) BOOL disableAutoLock;
@property (nonatomic, assign) BOOL buttonVibration;
@property (nonatomic, assign) BOOL imageSmoothing;
@property (nonatomic, assign) BOOL showRecentGames;
@property (nonatomic, assign) BOOL showFPSCount;
@property (nonatomic, assign) BOOL showGameTitles;
@property (nonatomic, assign) kICadeControllerSetting iCadeControllerSetting;

@property (nonatomic, assign) CGFloat controllerOpacity;
@property (nonatomic, assign) float volume;

+ (PVSettingsModel *)sharedInstance;

@end
