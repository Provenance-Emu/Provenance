//
//  PVSettingsModel.m
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVSettingsModel.h"

NSString * const kAutoSaveKey = @"kAutoSaveKey";
NSString * const kAutoLoadAutoSavesKey = @"kAutoLoadAutoSavesKey";
NSString * const kControllerOpacityKey = @"kControllerOpacityKey";
NSString * const kAskToAutoLoadKey = @"kAskToAutoLoadKey";
NSString * const kDisableAutoLockKey = @"kDisableAutoLockKey";
NSString * const kButtonVibrationKey = @"kButtonVibrationKey";
NSString * const kICadeControllerSettingKey = @"kiCadeControllerSettingKey";
NSString * const kVolumeSettingKey = @"kVolumeSettingKey";

@implementation PVSettingsModel

+ (PVSettingsModel *)sharedInstance
{
	static PVSettingsModel *_sharedInstance;
	
	if (!_sharedInstance)
	{
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			_sharedInstance = [[super allocWithZone:nil] init];
		});
	}
	
	return _sharedInstance;
}

- (id)init
{
	if ((self = [super init]))
	{
		[[NSUserDefaults standardUserDefaults] registerDefaults:@{kAutoSaveKey : @(YES), kAskToAutoLoadKey: @(YES),
                                                                  kAutoLoadAutoSavesKey : @(NO),
                                                                  kControllerOpacityKey : @(0.2),
                                                                  kDisableAutoLockKey : @(NO),
                                                                  kButtonVibrationKey : @(YES),
                                                                  kICadeControllerSettingKey : @(kICadeControllerSettingDisabled),
                                                                  kVolumeSettingKey : @(1.0)}];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
		_autoSave = [[NSUserDefaults standardUserDefaults] boolForKey:kAutoSaveKey];
		_autoLoadAutoSaves = [[NSUserDefaults standardUserDefaults] boolForKey:kAutoLoadAutoSavesKey];
		_controllerOpacity = [[NSUserDefaults standardUserDefaults] floatForKey:kControllerOpacityKey];
		_disableAutoLock = [[NSUserDefaults standardUserDefaults] boolForKey:kDisableAutoLockKey];
        _buttonVibration = [[NSUserDefaults standardUserDefaults] boolForKey:kButtonVibrationKey];
        _iCadeControllerSetting = [[NSUserDefaults standardUserDefaults] integerForKey:kICadeControllerSettingKey];
        _volume = [[NSUserDefaults standardUserDefaults] floatForKey:kVolumeSettingKey];
	}
	
	return self;
}

- (void)setAutoSave:(BOOL)autoSave
{
	_autoSave = autoSave;
	
	[[NSUserDefaults standardUserDefaults] setBool:_autoSave forKey:kAutoSaveKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAskToAutoLoad:(BOOL)askToAutoLoad
{
	_askToAutoLoad = askToAutoLoad;
	[[NSUserDefaults standardUserDefaults] setBool:_askToAutoLoad forKey:kAskToAutoLoadKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAutoLoadAutoSaves:(BOOL)autoLoadAutoSaves
{
	_autoLoadAutoSaves = autoLoadAutoSaves;
	[[NSUserDefaults standardUserDefaults] setBool:_autoLoadAutoSaves forKey:kAutoLoadAutoSavesKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setControllerOpacity:(CGFloat)controllerOpacity
{
	_controllerOpacity = controllerOpacity;
	[[NSUserDefaults standardUserDefaults] setFloat:_controllerOpacity forKey:kControllerOpacityKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setDisableAutoLock:(BOOL)disableAutoLock
{
	_disableAutoLock = disableAutoLock;
	[[NSUserDefaults standardUserDefaults] setBool:_disableAutoLock forKey:kDisableAutoLockKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[[UIApplication sharedApplication] setIdleTimerDisabled:_disableAutoLock];
}

- (void)setButtonVibration:(BOOL)buttonVibration
{
    _buttonVibration = buttonVibration;
    [[NSUserDefaults standardUserDefaults] setBool:_buttonVibration forKey:kButtonVibrationKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void) setICadeControllerSetting:(kICadeControllerSetting)iCadeControllerSetting
{
    _iCadeControllerSetting = iCadeControllerSetting;
    [[NSUserDefaults standardUserDefaults] setInteger:iCadeControllerSetting forKey:kICadeControllerSettingKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setVolume:(float)volume
{
    _volume = volume;
    [[NSUserDefaults standardUserDefaults] setFloat:volume forKey:kVolumeSettingKey];
}

@end
