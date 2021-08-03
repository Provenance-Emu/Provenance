//
//  UIDevice+Hardware.h
//  Provenance
//
//  Created by James Addyman on 24/09/2016.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

// These are private/undocumented API, so we need to expose them here
// Based on GBA4iOS 2.0 by Riley Testut
// https://bitbucket.org/rileytestut/gba4ios/src/6c363f7503ecc1e29a32f6869499113c3a3a6297/GBA4iOS/GBAControllerView.m?at=master#cl-245

void AudioServicesStopSystemSound(int);
void AudioServicesPlaySystemSoundWithVibration(int, id _Nullable , NSDictionary * _Nonnull);

@interface UIDevice (Hardware)

@property (nonatomic, readonly, strong, nonnull) NSString *modelIdentifier;
@property (class, readonly, assign) BOOL hasTapticMotor;

@end
