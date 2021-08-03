//
//  PVReicast+Audio.h
//  PVReicast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <PVReicast/PVReicast.h>

#define CALLBACK_VERSION_1  1 // Fill the ring buffer, if full, wait until has space
#define CALLBACK_VERSION_2  2 // samples_ptr > rb.bytesWritten then do next rb write
#define CALLBACK_VERSION_3  3 // Use a sample counter instead of filling the buffer
#define CALLBACK_VERSION_4  4 // Use a sample counter instead of filling the buffer
#define CALLBACK_VERSION_5  5 // Wait for each ringbuffer read to finish?
#define CALLBACK_VERSION_6  6 // Wait until ring buffer has space using availableBytes
#define CALLBACK_VERSION_7  7 // Hacking at time based ring buffer
#define CALLBACK_VERSION_8  8 // Stock copy to ORRingBuffer no wait

#define CALLBACK_VERSION        CALLBACK_VERSION_8
#define USE_DIRECTSOUND_THING   FALSE
#define EXTRA_LOGGING           TRUE

#if CALLBACK_VERSION <= 7
#define COREAUDIO_USE_DEFAULT 0
#else
#define COREAUDIO_USE_DEFAULT 1
#endif

#if EXTRA_LOGGING
#define CALOG(fmt, ...) \
printf(fmt, ##__VA_ARGS__);
#else
#define CALOG(...)
#endif
