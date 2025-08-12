//
//  PVRetroArchCoreBridge+Audio.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVRetroArch/PVRetroArch.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

NS_ASSUME_NONNULL_BEGIN
@protocol EmulatorCoreWaveformProvider;
@interface PVRetroArchCoreBridge (Audio) <EmulatorCoreWaveformProvider>

/// Install a PCM waveform tap inside RetroArch audio path
- (void)installWaveformTap;
/// Remove the PCM waveform tap
- (void)removeWaveformTap;
/// Fetch latest normalized amplitudes for visualization (size-limited)
- (NSArray<NSNumber *> *)dequeueWaveformAmplitudesWithMaxCount:(NSUInteger)maxCount;

@end

NS_ASSUME_NONNULL_END
