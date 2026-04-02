//
//  PVHatariCore.m
//  PVHatari
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVHatariCore.h"
// Import the Swift-generated bridging header here (not in the public .h) to
// satisfy the MIDIResponder forward declaration and avoid circular includes.
#import <PVCoreBridge/PVCoreBridge-Swift.h>
#include <stdatomic.h>
//#import "PVHatariCore+Controls.h"
//#import "PVHatariCore+Audio.h"
//#import "PVHatariCore+Video.h"
//
//#import "PVHatariCore+Audio.h"

#import <Foundation/Foundation.h>
@import PVCoreBridge;

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVHatariCore() {

}

@end

#pragma mark - PVHatariCore Begin

@implementation PVHatariCore
{
}

- (instancetype)init {
	if (self = [super init]) {
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore

/// Validate that a TOS image file is present and has a plausible header before
/// the Hatari libretro core starts.  Without this check, an invalid or missing
/// TOS causes Hatari's Reset_Cold() to fail and trigger its built-in SDL GUI
/// dialog — which crashes because `input_poll_cb` is null in the libretro
/// coroutine context (EXC_BAD_ACCESS inside `input_gui`).
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    // Locate tos.img in the BIOS directory (same directory the thin/retro frontend uses).
    NSString *biosDir = self.BIOSPath;
    if (!biosDir) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVHatariCore" code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                @"Atari ST BIOS directory is not configured. "
                 "Cannot locate tos.img."}];
        }
        return NO;
    }

    NSString *tosPath = [self _findTOSImageInDirectory:biosDir];
    if (!tosPath) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVHatariCore" code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                @"TOS ROM image not found. Place a valid tos.img file in "
                 "the Atari ST BIOS folder (BIOS/com.provenance.atarist/)."}];
        }
        return NO;
    }

    NSError *validationError = nil;
    if (![self _validateTOSImage:tosPath error:&validationError]) {
        if (error) {
            *error = validationError;
        }
        return NO;
    }

    return [super loadFileAtPath:path error:error];
}

/// Search `directory` for the first file that looks like a TOS image.
/// Prefers files named "tos*" with .img/.rom extension, then falls back to any .img/.rom.
- (NSString *)_findTOSImageInDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *files = [[fm contentsOfDirectoryAtPath:directory error:nil] sortedArrayUsingSelector:@selector(compare:)];
    NSSet<NSString *> *tosExts = [NSSet setWithObjects:@"img", @"rom", nil];

    // Pass 1: files starting with "tos"
    for (NSString *file in files) {
        NSString *ext = file.pathExtension.lowercaseString;
        if ([tosExts containsObject:ext] && [file.lowercaseString hasPrefix:@"tos"]) {
            return [directory stringByAppendingPathComponent:file];
        }
    }
    // Pass 2: any .img or .rom
    for (NSString *file in files) {
        NSString *ext = file.pathExtension.lowercaseString;
        if ([tosExts containsObject:ext]) {
            return [directory stringByAppendingPathComponent:file];
        }
    }
    return nil;
}

/// Validate the TOS image header (mirrors hatari/src/tos.c logic).
/// Returns NO and sets `error` if the file is too small or has invalid version/address fields.
- (BOOL)_validateTOSImage:(NSString *)path error:(NSError **)error {
    NSData *header = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:error];
    if (!header) {
        return NO;
    }

    // TOS images must be at least 16KB (TOS 0.00 boot ROM is 16384 bytes)
    if (header.length < 16384) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVHatariCore" code:3
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"TOS ROM image is too small (%lu bytes). "
                 "Expected at least 16 KB. The file may be corrupt.",
                 (unsigned long)header.length]}];
        }
        return NO;
    }

    // TOS must be <= 1 MB
    if (header.length > 1024 * 1024) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVHatariCore" code:4
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"TOS ROM image is too large (%lu bytes). "
                 "Expected at most 1 MB. The file may not be a valid TOS image.",
                 (unsigned long)header.length]}];
        }
        return NO;
    }

    const uint8_t *bytes = (const uint8_t *)header.bytes;

    // Check for RAM TOS loader header (magic 0x46FC2700) — skip validation for these
    uint32_t firstWord = ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
                         ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
    if (firstWord == 0x46FC2700) {
        // RAM TOS — Hatari handles these specially; allow them through
        return YES;
    }

    // TOS version at offset 2 (big-endian uint16)
    uint16_t tosVersion = ((uint16_t)bytes[2] << 8) | (uint16_t)bytes[3];
    // TOS base address at offset 8 (big-endian uint32)
    uint32_t tosAddress = ((uint32_t)bytes[8] << 24) | ((uint32_t)bytes[9] << 16) |
                          ((uint32_t)bytes[10] << 8) | (uint32_t)bytes[11];

    // TOS 0.00 (16 KB boot ROM) is valid
    if (tosVersion == 0x000 && header.length == 16384) {
        return YES;
    }

    // Normal TOS: version 1.00-4.xx, address must be 0xE00000 or 0xFC0000
    if (tosVersion < 0x100 || tosVersion >= 0x500) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVHatariCore" code:5
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"Invalid TOS ROM: version 0x%03X is outside the "
                 "expected range (1.00–4.xx). The file may be corrupt or not a TOS image.",
                 tosVersion]}];
        }
        return NO;
    }

    if (tosAddress != 0xE00000 && tosAddress != 0xFC0000) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVHatariCore" code:6
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"Invalid TOS ROM: base address 0x%06X is not a "
                 "known TOS ROM address (expected 0xE00000 or 0xFC0000).",
                 tosAddress]}];
        }
        return NO;
    }

    return YES;
}

#pragma mark - Running
//- (void)startEmulation {
//	if (!_isInitialized)
//	{
//		[self.renderDelegate willRenderFrameOnAlternateThread];
//        _isInitialized = true;
//		_frameInterval = dol_host->GetFrameInterval();
//	}
//	[super startEmulation];
//
	//Disable the OE framelimiting
//	[self.renderDelegate suspendFPSLimiting];
//	if(!self.isRunning) {
//		[super startEmulation];
////        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
//	}
//}

//- (void)setPauseEmulation:(BOOL)flag {
//	[super setPauseEmulation:flag];
//}
//
//- (void)stopEmulation {
//	_isInitialized = false;
//
//	self->shouldStop = YES;
////	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
////    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//
//	[super stopEmulation];
//}
//
//- (void)resetEmulation {
//	//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//}

//# pragma mark - Cheats
//- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
//}
//
//- (BOOL)supportsRumble { return NO; }
//- (BOOL)supportsCheatCode { return NO; }

- (NSTimeInterval)frameInterval {
    return 13.63;
}

//- (CGSize)aspectSize {
//    return CGSizeMake(4, 3);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(1440, 1080);
//}
//
//- (GLenum)pixelFormat {
//    return GL_BGRA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_BYTE;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGBA;
//}

# pragma mark - Audio

- (double)audioSampleRate {
    return 22255;
}

#pragma mark - MIDIResponder

/// Atari ST has built-in MIDI In/Out/Thru ports on all models since 1985.
/// The Hatari libretro core routes MIDI through retro_midi_interface,
/// which is wired to CoreMIDI via pv_libretro_midi_inject_byte().
- (BOOL)gameSupportsMIDI {
    return YES;
}

/// MIDI is optional — the Atari ST can run without any MIDI device connected.
- (BOOL)requiresMIDI {
    return NO;
}

/// Encode a Note On message and inject the three raw bytes into the
/// libretro MIDI input ring buffer for the Hatari core to read via
/// retro_midi_interface.read().
- (void)midiNoteOnWithChannel:(uint8_t)channel note:(uint8_t)note velocity:(uint8_t)velocity {
    [self injectMIDIByte:0x90 | (channel & 0x0F)];
    [self injectMIDIByte:note & 0x7F];
    [self injectMIDIByte:velocity & 0x7F];
}

/// Encode a Note Off message and inject the three raw bytes.
- (void)midiNoteOffWithChannel:(uint8_t)channel note:(uint8_t)note velocity:(uint8_t)velocity {
    [self injectMIDIByte:0x80 | (channel & 0x0F)];
    [self injectMIDIByte:note & 0x7F];
    [self injectMIDIByte:velocity & 0x7F];
}

/// Forward Control Change messages (mod wheel, sustain pedal, volume, etc.).
- (void)midiControlChangeWithChannel:(uint8_t)channel controller:(uint8_t)controller value:(uint8_t)value {
    [self injectMIDIByte:0xB0 | (channel & 0x0F)];
    [self injectMIDIByte:controller & 0x7F];
    [self injectMIDIByte:value & 0x7F];
}

/// Forward Program Change messages (patch/instrument selection).
- (void)midiProgramChangeWithChannel:(uint8_t)channel program:(uint8_t)program {
    [self injectMIDIByte:0xC0 | (channel & 0x0F)];
    [self injectMIDIByte:program & 0x7F];
}

/// Forward Pitch Bend messages (14-bit value split into two 7-bit bytes).
- (void)midiPitchBendWithChannel:(uint8_t)channel value:(int16_t)value {
    // MIDI pitch bend: centre = 0x2000, range -8192..+8191.
    // Clamp to valid range before arithmetic to prevent underflow/overflow
    // when the caller passes an out-of-range value.
    int16_t clamped = value < -8192 ? -8192 : (value > 8191 ? 8191 : value);
    uint16_t normalized = (uint16_t)(clamped + 8192);
    [self injectMIDIByte:0xE0 | (channel & 0x0F)];
    [self injectMIDIByte:normalized & 0x7F];          // LSB
    [self injectMIDIByte:(normalized >> 7) & 0x7F];   // MSB
}

@end
