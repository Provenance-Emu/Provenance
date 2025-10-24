//
//  PVRetroArchCoreBridge+Audio.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Audio.h"
#import <stdatomic.h>
#import <PVLogging/PVLoggingObjC.h>
@import PVCoreBridge;

// Atomic enable flag toggled by install/remove
static _Atomic BOOL s_raWaveformEnabled = NO;
// Gain multiplier for visualizer amplitudes (does not affect audio)
static _Atomic float s_raGain = 4.0f;

// Simple ring buffer for amplitudes
static atomic_int_fast64_t s_raWriteIndex = 0;
static const NSUInteger kPVRAWaveformMax = 8192;
static float s_raAmpBuffer[8192];

static inline float pv_abs16_to_norm(int16_t s) { return (float)labs((long)s) / 32768.0f; }

// C-callable forwarder used by RA audio_driver.c (extern C to avoid C++ mangling)
#ifdef __cplusplus
extern "C" {
#endif
void pv_ra_waveform_forward(const int16_t *data, size_t frames) {
    if (!atomic_load_explicit(&s_raWaveformEnabled, memory_order_relaxed)) return;
    if (!data || frames == 0) return;
    const float gain = atomic_load_explicit(&s_raGain, memory_order_relaxed);
    // Decimate: compute one peak per window to reduce work on RA audio thread
    static const size_t kWindow = 64; // tuneable; ~0.7ms at 44.1kHz per point
    int64_t idx = atomic_load_explicit(&s_raWriteIndex, memory_order_relaxed);
    size_t i = 0;
    while (i < frames) {
        size_t stop = i + kWindow;
        if (stop > frames) stop = frames;
        float peak = 0.0f;
        for (; i < stop; i++) {
            int16_t l = data[(i<<1)+0];
            int16_t r = data[(i<<1)+1];
            float la = pv_abs16_to_norm(l);
            float ra = pv_abs16_to_norm(r);
            float p = la > ra ? la : ra;
            if (p > peak) peak = p;
        }
        // Apply visualizer-only gain and clamp
        peak *= gain;
        if (peak > 1.0f) peak = 1.0f;
        // Write one decimated sample and advance
        s_raAmpBuffer[(NSUInteger)(idx % kPVRAWaveformMax)] = peak;
        idx++;
    }
    // Commit updated write index once per batch
    atomic_store_explicit(&s_raWriteIndex, idx, memory_order_release);
}
#ifdef __cplusplus
}
#endif

@implementation PVRetroArchCoreBridge (Audio)

- (void)installWaveformTap {
    atomic_store_explicit(&s_raWaveformEnabled, YES, memory_order_relaxed);
    // Optional override from defaults
    id val = [[NSUserDefaults standardUserDefaults] objectForKey:@"PVRAVisualizerGain"];
    if ([val isKindOfClass:[NSNumber class]]) {
        float g = [(NSNumber *)val floatValue];
        if (g < 0.1f) g = 0.1f;
        if (g > 20.0f) g = 20.0f;
        atomic_store_explicit(&s_raGain, g, memory_order_relaxed);
    }
    DLOG(@"[RA] installWaveformTap enabled gain=%.2f", atomic_load_explicit(&s_raGain, memory_order_relaxed));
}

- (void)removeWaveformTap {
    atomic_store_explicit(&s_raWaveformEnabled, NO, memory_order_relaxed);
    DLOG(@"[RA] removeWaveformTap disabled");
}

- (NSArray<NSNumber *> *)dequeueWaveformAmplitudesWithMaxCount:(NSUInteger)maxCount {
    int64_t end = atomic_load_explicit(&s_raWriteIndex, memory_order_relaxed);
    if (end <= 0 || maxCount == 0) return @[];
    // Clamp request to buffer capacity and non-negative bounds
    NSUInteger safeMax = kPVRAWaveformMax;
    NSUInteger requested = maxCount;
    if (requested == 0) requested = 1;
    if (requested > safeMax) requested = safeMax;

    // Compute available sample count without overflow
    int64_t available = end < (int64_t)kPVRAWaveformMax ? end : (int64_t)kPVRAWaveformMax;
    if (available <= 0) return @[];
    NSUInteger count = (NSUInteger)MIN((int64_t)requested, available);

    @autoreleasepool {
        NSMutableArray<NSNumber *> *out = [NSMutableArray arrayWithCapacity:count];
        int64_t start = end - (int64_t)count;
        for (NSUInteger i = 0; i < count; i++) {
            int64_t idx = (start + (int64_t)i);
            float v = s_raAmpBuffer[(NSUInteger)((idx % kPVRAWaveformMax + kPVRAWaveformMax) % kPVRAWaveformMax)];
            [out addObject:@(v)];
        }
        return out;
    }
}

- (NSUInteger)copyWaveformAmplitudesTo:(float *_Nonnull)outBuffer maxCount:(NSUInteger)maxCount {
    if (!outBuffer || maxCount == 0) return 0;
    int64_t end = atomic_load_explicit(&s_raWriteIndex, memory_order_relaxed);
    if (end <= 0) return 0;
    NSUInteger safeMax = kPVRAWaveformMax;
    NSUInteger requested = maxCount > safeMax ? safeMax : maxCount;
    int64_t available = end < (int64_t)kPVRAWaveformMax ? end : (int64_t)kPVRAWaveformMax;
    if (available <= 0) return 0;
    NSUInteger count = (NSUInteger)MIN((int64_t)requested, available);
    int64_t start = end - (int64_t)count;
    for (NSUInteger i = 0; i < count; i++) {
        int64_t idx = (start + (int64_t)i);
        outBuffer[i] = s_raAmpBuffer[(NSUInteger)((idx % kPVRAWaveformMax + kPVRAWaveformMax) % kPVRAWaveformMax)];
    }
    return count;
}

// Keep existing getters for sample rate / channels if needed by other paths
- (NSTimeInterval)frameInterval {
	return isNTSC ? 60 : 50;
}

- (NSUInteger)channelCount {
	return 2;
}

- (double)audioSampleRate {
	return sampleRate;
}

@end
