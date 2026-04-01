//
//  PVRetroArchCoreBridge+Audio.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVRetroArch/PVRetroArchCoreBridge.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

@protocol EmulatorCoreWaveformProvider;

NS_ASSUME_NONNULL_BEGIN
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVRetroArchCoreBridge (Audio) <EmulatorCoreWaveformProvider>
#pragma clang diagnostic pop

/// Install a PCM waveform tap inside RetroArch audio path
- (void)installWaveformTap;
/// Remove the PCM waveform tap
- (void)removeWaveformTap;
/// Fetch latest normalized amplitudes for visualization (size-limited)
- (NSArray<NSNumber *> *)dequeueWaveformAmplitudesWithMaxCount:(NSUInteger)maxCount;

@end

NS_ASSUME_NONNULL_END
