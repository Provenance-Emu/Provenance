//
//  PVblueMSXCore.mm
//  PVblueMSX
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVblueMSXCore.h"
#include <stdatomic.h>
#include <PVCoreBridgeRetro/libretro.h>

#import <Foundation/Foundation.h>
@import GameController;
@import PVCoreBridge;
@import PVLoggingObjC;

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4

#pragma mark - Private
@interface PVblueMSXCore() {
}
@end

#pragma mark - PVblueMSXCore Begin

@implementation PVblueMSXCore
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

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
	// Get paths
	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
    NSString *biosPath = self.BIOSPath;

	// Create BIOS directory if it doesn't exist
	[[NSFileManager defaultManager] createDirectoryAtPath:biosPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

	// BIOS files required by blueMSX
	NSArray *biosFiles = @[
		@"CARTS.SHA", @"CYRILLIC.FNT", @"DEFAULT.FNT", @"DISK.ROM",
		@"FMPAC.ROM", @"FMPAC16.ROM", @"INTERNAT.FNT", @"ITALIC.FNT",
		@"JAPANESE.FNT", @"KANJI.ROM", @"KOREAN.FNT", @"MSX.ROM",
		@"MSX2.ROM", @"MSX2EXT.ROM", @"MSX2P.ROM", @"MSX2PEXT.ROM",
		@"MSXDOS2.ROM", @"PAINTER.ROM", @"RS232.ROM"
	];

	NSFileManager *fileManager = [NSFileManager defaultManager];

	for (NSString *filename in biosFiles) {
		NSString *sourcePath = [coreBundle pathForResource:[filename stringByDeletingPathExtension]
                                                   ofType:[filename pathExtension]];
		NSString *destPath = [biosPath stringByAppendingPathComponent:filename];

		if (sourcePath && ![fileManager fileExistsAtPath:destPath]) {
			ILOG(@"Copying BIOS file: %@", filename);
			NSError *copyError = nil;
			[fileManager copyItemAtPath:sourcePath toPath:destPath error:&copyError];
			if (copyError) {
				ELOG(@"Failed to copy BIOS file %@: %@", filename, copyError);
			}
		}
	}

	return [super loadFileAtPath:path error:error];
}

#pragma mark - Video

- (CGSize)aspectSize {
    return CGSizeMake(4, 3);
}

- (NSTimeInterval)frameInterval {
    return 60;
}

#pragma mark - Audio

- (double)audioSampleRate {
    return SAMPLERATE;
}

#pragma mark - Options

- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);

    #define V(x) strcmp(variable, x) == 0
    if (V("blueMSX_video_mode")) {
        return strdup("Dynamic");
    } else if (V("blueMSX_mode")) {
        return strdup("MSX2+");
    } else if (V("blueMSX_hires")) {
        return strdup("Progressive");
    } else if (V("blueMSX_overscan")) {
        return strdup("Yes");
    } else if (V("blueMSX_mapper_type_mode")) {
        return strdup("Guess");
    } else if (V("blueMSX_game_master")) {
        return strdup("Yes");
    } else if (V("blueMSX_simbdos")) {
        return strdup("No");
    } else if (V("blueMSX_autospace")) {
        return strdup("No");
    } else if (V("blueMSX_allsprites")) {
        return strdup("No");
    } else if (V("blueMSX_flush_disk")) {
        return strdup("Immediate");
    } else if (V("blueMSX_phantom_disk")) {
        return strdup("No");
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
    #undef V
    return NULL;
}

#pragma mark - Controls

static int blueMSXButtonToRetroID(PVMSXButton button) {
    switch (button) {
        case PVMSXButtonUp:        return RETRO_DEVICE_ID_JOYPAD_UP;
        case PVMSXButtonDown:      return RETRO_DEVICE_ID_JOYPAD_DOWN;
        case PVMSXButtonLeft:      return RETRO_DEVICE_ID_JOYPAD_LEFT;
        case PVMSXButtonRight:     return RETRO_DEVICE_ID_JOYPAD_RIGHT;
        case PVMSXButtonFire1:     return RETRO_DEVICE_ID_JOYPAD_B;
        case PVMSXButtonFire2:     return RETRO_DEVICE_ID_JOYPAD_A;
        case PVMSXButtonSelect:    return RETRO_DEVICE_ID_JOYPAD_SELECT;
        case PVMSXButtonPause:     return RETRO_DEVICE_ID_JOYPAD_START;
        case PVMSXButtonLeftDiff:  return RETRO_DEVICE_ID_JOYPAD_L;
        case PVMSXButtonRightDiff: return RETRO_DEVICE_ID_JOYPAD_R;
        default:                   return -1;
    }
}

- (void)didPushMSXButton:(PVMSXButton)button forPlayer:(NSInteger)player {
    if (player >= 2) return;
    int retroID = blueMSXButtonToRetroID(button);
    if (retroID >= 0) {
        _pad[player][retroID] = 1;
    }
}

- (void)didReleaseMSXButton:(enum PVMSXButton)button forPlayer:(NSInteger)player {
    if (player >= 2) return;
    int retroID = blueMSXButtonToRetroID(button);
    if (retroID >= 0) {
        _pad[player][retroID] = 0;
    }
}

- (void)didMoveMSXJoystickDirection:(enum PVMSXButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    if (player >= 2) return;
    const float threshold = 0.5f;
    int retroID = blueMSXButtonToRetroID(button);
    if (retroID >= 0) {
        _pad[player][retroID] = (value > threshold) ? 1 : 0;
    }
}

- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
    [self didMoveMSXJoystickDirection:(enum PVMSXButton)button withValue:value forPlayer:player];
}

- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
    [self didPushMSXButton:(PVMSXButton)button forPlayer:player];
}

- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
    [self didReleaseMSXButton:(enum PVMSXButton)button forPlayer:player];
}

#pragma mark - Keyboard Support

// Keyboard pipeline: keyDown/keyUp → PVLibRetroCoreBridge -sendKeyboardEvent:hidCode:character:
// → input_keymaps_translate_keysym_to_rk → runloop_key_event (libretro callback).
// GCKeyCode.rawValue == HID USB key code; key-up events prevent stuck keys.

- (BOOL)gameSupportsKeyboard { return YES; }
- (BOOL)requiresKeyboard { return NO; }

- (void)keyDown:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    [self sendKeyboardEvent:YES hidCode:(unsigned)key character:0];
}

- (void)keyUp:(GCKeyCode)key API_AVAILABLE(ios(14.0), tvos(14.0)) {
    [self sendKeyboardEvent:NO hidCode:(unsigned)key character:0];
}

#pragma mark - Mouse Support

- (BOOL)gameSupportsMouse { return YES; }
- (BOOL)requiresMouse { return NO; }

- (GCMouseMoved)mouseMovedHandler { return nil; }

- (void)didScroll:(GCDeviceCursor *)cursor API_AVAILABLE(ios(14.0), tvos(14.0)) {
}

- (void)mouseMovedAt:(CGPoint)point {
    [self setMousePosition:point];
}

- (void)mouseMovedAtPoint:(CGPoint)point {
    [self mouseMovedAt:point];
}

- (void)leftMouseDownAt:(CGPoint)point {
    [self setMousePosition:point];
    [self setLeftMouseButtonPressed:YES];
}

- (void)leftMouseDownAtPoint:(CGPoint)point {
    [self leftMouseDownAt:point];
}

- (void)leftMouseUp {
    [self setLeftMouseButtonPressed:NO];
}

- (void)rightMouseDownAtPoint:(CGPoint)point {
    [self setMousePosition:point];
    [self setRightMouseButtonPressed:YES];
}

- (void)rightMouseUp {
    [self setRightMouseButtonPressed:NO];
}

@end
