//
//  PVSettingsModel.h
//  Provenance
//
//  Created by James Addyman on 21/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const kAutoSaveKey;
extern NSString * const kAskToAutoLoadKey;
extern NSString * const kAutoLoadAutoSavesKey;
extern NSString * const kControllerOpacityKey;

@interface PVSettingsModel : NSObject

@property (nonatomic, assign) BOOL autoSave;
@property (nonatomic, assign) BOOL askToAutoLoad;
@property (nonatomic, assign) BOOL autoLoadAutoSaves;

@property (nonatomic, assign) CGFloat controllerOpacity;

+ (PVSettingsModel *)sharedInstance;

@end
