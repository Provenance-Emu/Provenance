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
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
//	const char *dataPath;
//
//    [self initControllBuffers];
//
//	// TODO: Proper path
//	NSString *configPath = self.saveStatesPath;
//	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];
//
//	[[NSFileManager defaultManager] createDirectoryAtPath:configPath
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:nil];
//
//	NSString *batterySavesDirectory = self.batterySavesPath;
//	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:NULL];
//
//    return YES;
//}

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
