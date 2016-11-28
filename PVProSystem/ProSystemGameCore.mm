/*
 Copyright (c) 2013, OpenEmu Team


 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ProSystemGameCore.h"
#import "OE7800SystemResponderClient.h"

#import <PVSupport/OERingBuffer.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#include "ProSystem.h"
#include "Database.h"
#include "Sound.h"
#include "Palette.h"
#include "Maria.h"
#include "Tia.h"
#include "Pokey.h"
#include "Cartridge.h"

@interface PVProSystemGameCore () <OE7800SystemResponderClient> {
    uint32_t *_videoBuffer;
    uint32_t _displayPalette[256];
    uint8_t  *_soundBuffer;
    uint8_t _inputState[17];
    int _videoWidth, _videoHeight;
    BOOL _isLightgunEnabled;
}
- (void)setPalette32;
@end

@implementation PVProSystemGameCore

- (id)init {
    if((self = [super init])) {
        _videoBuffer = (uint32_t *)malloc(320 * 292 * 4);
        _soundBuffer = (uint8_t *) malloc(8192);
    }

    return self;
}

- (void)dealloc {
    free(_videoBuffer);
    free(_soundBuffer);
}

// TODO: Make me work
-(NSString*)biosDirectoryPath {
    return [self BIOSPath];
}

#pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path {
    const int LEFT_DIFF_SWITCH  = 15;
    const int RIGHT_DIFF_SWITCH = 16;
    const int LEFT_POSITION  = 1; // also know as "B"
    const int RIGHT_POSITION = 0; // also know as "A"

    memset(_inputState, 0, sizeof(_inputState));

    // Difficulty switches: Left position = (B)eginner, Right position = (A)dvanced
    // Left difficulty switch defaults to left position, "(B)eginner"
    _inputState[LEFT_DIFF_SWITCH] = LEFT_POSITION;

    // Right difficulty switch defaults to right position, "(A)dvanced", which fixes Tower Toppler
    _inputState[RIGHT_DIFF_SWITCH] = RIGHT_POSITION;

    if(cartridge_Load([path UTF8String])) {
        NSString *databasePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"ProSystem.dat"];
        database_filename = [databasePath UTF8String];
        database_enabled = true;

        // BIOS is optional
        NSString *biosROM = [[self biosDirectoryPath] stringByAppendingPathComponent:@"7800 BIOS (U).rom"];
        if (bios_Load([biosROM UTF8String])) {
		    bios_enabled = true;
        }

        NSLog(@"Headerless MD5 hash: %s", cartridge_digest.c_str());
        NSLog(@"Header info (often wrong):\ntitle: %s\ntype: %d\nregion: %s\npokey: %s", cartridge_title.c_str(), cartridge_type, cartridge_region == REGION_NTSC ? "NTSC" : "PAL", cartridge_pokey ? "true" : "false");

	    database_Load(cartridge_digest);
	    prosystem_Reset();

        std::string title = common_Trim(cartridge_title);
        NSLog(@"Database info:\ntitle: %@\ntype: %d\nregion: %s\npokey: %s", [NSString stringWithUTF8String:title.c_str()], cartridge_type, cartridge_region == REGION_NTSC ? "NTSC" : "PAL", cartridge_pokey ? "true" : "false");

        sound_SetSampleRate([self audioSampleRate]);
        [self setPalette32];

        _isLightgunEnabled = (cartridge_controller[0] & CARTRIDGE_CONTROLLER_LIGHTGUN);
        // The light gun 'trigger' is a press on the 'up' button (0x3) and needs the bit toggled
        if(_isLightgunEnabled) {
            _inputState[3] = 1;
        }

        // Set defaults for Bentley Bear (homebrew) so button 1 = run/shoot and button 2 = jump
        if(cartridge_digest == "ad35a98040a2facb10ecb120bf83bcc3")
        {
            _inputState[LEFT_DIFF_SWITCH] = RIGHT_POSITION;
            _inputState[RIGHT_DIFF_SWITCH] = LEFT_POSITION;
        }

        return YES;
    }

    return NO;
}

- (void)executeFrame {
    
    if (self.controller1 || self.controller2) {
        [self pollControllers];
    }
    
	prosystem_ExecuteFrame(_inputState);

    _videoWidth  = maria_visibleArea.GetLength();
    _videoHeight = maria_visibleArea.GetHeight();

    uint8_t *buffer = maria_surface + ((maria_visibleArea.top - maria_displayArea.top) * maria_visibleArea.GetLength());
    uint32_t *surface = (uint32_t *)_videoBuffer;
    int pitch = 320;

    for(int indexY = 0; indexY < _videoHeight; indexY++) {
        for(int indexX = 0; indexX < _videoWidth; indexX += 4) {
            surface[indexX + 0] = _displayPalette[buffer[indexX + 0]];
            surface[indexX + 1] = _displayPalette[buffer[indexX + 1]];
            surface[indexX + 2] = _displayPalette[buffer[indexX + 2]];
            surface[indexX + 3] = _displayPalette[buffer[indexX + 3]];
        }
        surface += pitch;
        buffer += _videoWidth;
    }

    int length = sound_Store(_soundBuffer);
    [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:length];
}

- (void)resetEmulation {
    prosystem_Reset();
}

- (NSTimeInterval)frameInterval {
    return cartridge_region == REGION_NTSC ? 60 : 50;
}

#pragma mark - Video

- (const void *)videoBuffer {
    return _videoBuffer;
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, maria_visibleArea.GetLength(), maria_visibleArea.GetHeight());
}

- (CGSize)aspectSize {
    return CGSizeMake(maria_visibleArea.GetLength(), maria_visibleArea.GetHeight());
}

- (CGSize)bufferSize {
    return CGSizeMake(320, 292);
}

- (GLenum)pixelFormat {
    return GL_BGRA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

#pragma mark - Audio

- (double)audioSampleRate {
    return 48000;
}

- (NSUInteger)channelCount {
    return 1;
}

- (NSUInteger)audioBitDepth {
    return 8;
}

#pragma mark - Save States

- (void)saveStateToFileAtPath:(NSString *)fileName {
    prosystem_Save(fileName.fileSystemRepresentation, false);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName  {
    prosystem_Load(fileName.fileSystemRepresentation);
}

- (NSData *)serializeStateWithError:(NSError **)outError {
    size_t length = cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM ? 32837 : 16453;
    void *bytes = malloc(length);

    if(prosystem_Save_buffer((uint8_t *)bytes))
        return [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:YES];

    if(outError) {
        *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotSaveState userInfo:@{
            NSLocalizedDescriptionKey : @"Save state data could not be written",
            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
        }];
    }

    return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError {
    size_t serial_size = cartridge_type == CARTRIDGE_TYPE_SUPERCART_RAM ? 32837 : 16453;
    if(serial_size != [state length]) {
        if(outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeStateHasWrongSize userInfo:@{
                NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The save state does not have the right size, %ld expected, got: %ld.", serial_size, [state length]]
            }];
        }

        return NO;
    }

    if(prosystem_Load_buffer((uint8_t *)[state bytes]))
        return YES;

    if(outError) {
        *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
            NSLocalizedDescriptionKey : @"The save state data could not be read"
        }];
    }

    return NO;
}

#pragma mark - Input
// ----------------------------------------------------------------------------
// SetInput
// +----------+--------------+-------------------------------------------------
// | Offset   | Controller   | Control
// +----------+--------------+-------------------------------------------------
// | 00       | Joystick 1   | Right
// | 01       | Joystick 1   | Left
// | 02       | Joystick 1   | Down
// | 03       | Joystick 1   | Up
// | 04       | Joystick 1   | Button 1
// | 05       | Joystick 1   | Button 2
// | 06       | Joystick 2   | Right
// | 07       | Joystick 2   | Left
// | 08       | Joystick 2   | Down
// | 09       | Joystick 2   | Up
// | 10       | Joystick 2   | Button 1
// | 11       | Joystick 2   | Button 2
// | 12       | Console      | Reset
// | 13       | Console      | Select
// | 14       | Console      | Pause
// | 15       | Console      | Left Difficulty
// | 16       | Console      | Right Difficulty
// +----------+--------------+-------------------------------------------------
const int ProSystemMap[] = { 3, 2, 1, 0, 4, 5, 9, 8, 7, 6, 10, 11, 13, 14, 12, 15, 16};

#pragma mark Input
- (void)pollControllers {
    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        
        if ([controller extendedGamepad]) {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // Up
            _inputState[03] = (dpad.up.isPressed    || gamepad.leftThumbstick.up.isPressed);
            // Down
            _inputState[02] = (dpad.down.isPressed  || gamepad.leftThumbstick.down.isPressed);
            // Left
            _inputState[01] = (dpad.left.isPressed  || gamepad.leftThumbstick.left.isPressed);
            // Right
            _inputState[00] = (dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed);
            
            // Button 1
            _inputState[04] = (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed);
            // Button 2
            _inputState[05] = (gamepad.buttonB.isPressed || gamepad.buttonB.isPressed);
           
            // Reset
            _inputState[12] = (gamepad.rightShoulder.isPressed);
            // Select
            _inputState[13]  = (gamepad.leftShoulder.isPressed);
            // Pause
//            _inputState[14] = (gamepad.buttonY.isPressed);
            // Left Difficulty
            _inputState[15] = (gamepad.leftTrigger.isPressed);
            // Right Difficulty
            _inputState[16] = (gamepad.rightTrigger.isPressed);

        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // Up
            _inputState[03] = (dpad.up.isPressed);
            // Down
            _inputState[02] = (dpad.down.isPressed);
            // Left
            _inputState[01] = (dpad.left.isPressed);
            // Right
            _inputState[00] = (dpad.right.isPressed);
            
            // Button 1
            _inputState[04] = (gamepad.buttonA.isPressed);
            // Button 2
            _inputState[05] = (gamepad.buttonB.isPressed);
            
            // Reset
            _inputState[12] = (gamepad.rightShoulder.isPressed);
            // Select
            _inputState[13]  = (gamepad.leftShoulder.isPressed);
            // Pause
            //            _inputState[14] = (gamepad.buttonY.isPressed);
            // Left Difficulty
            _inputState[15] = (gamepad.buttonX.isPressed);
            // Right Difficulty
            _inputState[16] = (gamepad.buttonY.isPressed);
            
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _inputState[03]    = dpad.up.value > 0.5;
            _inputState[02]  = dpad.down.value > 0.5;
            _inputState[01]  = dpad.left.value > 0.5;
            _inputState[00] = dpad.right.value > 0.5;
            
            _inputState[04] = gamepad.buttonX.isPressed;
            _inputState[05] = gamepad.buttonA.isPressed;
        }
#endif
    }
}

- (oneway void)didPush7800Button:(OE7800Button)button forPlayer:(NSUInteger)player {
    int playerShift = player == 0 ? 0 : 6;

    switch(button)
    {
            // Controller buttons P1 + P2
        case OE7800ButtonUp:
//            _inputState[ProSystemMap[button + playerShift]] ^= 1;
//            break;
        case OE7800ButtonDown:
        case OE7800ButtonLeft:
        case OE7800ButtonRight:
        case OE7800ButtonFire1:
        case OE7800ButtonFire2:
            _inputState[ProSystemMap[button + playerShift]] = 1;
            break;
            // Console buttons
        case OE7800ButtonSelect:
        case OE7800ButtonPause:
        case OE7800ButtonReset:
            _inputState[ProSystemMap[button + 6]] = 1;
            break;
            // Difficulty switches
        case OE7800ButtonLeftDiff:
        case OE7800ButtonRightDiff:
            _inputState[ProSystemMap[button + 6]] ^= (1 << 0);
            break;

        default:
            break;
    }
}

- (oneway void)didRelease7800Button:(OE7800Button)button forPlayer:(NSUInteger)player {
    int playerShift = player == 0 ? 0 : 6;

    switch(button)
    {
            // Controller buttons P1 + P2
        case OE7800ButtonUp:
//            _inputState[ProSystemMap[button + playerShift]] ^= 1;
//            break;
        case OE7800ButtonDown:
        case OE7800ButtonLeft:
        case OE7800ButtonRight:
        case OE7800ButtonFire1:
        case OE7800ButtonFire2:
            _inputState[ProSystemMap[button + playerShift]] = 0;
            break;
            // Console buttons
        case OE7800ButtonSelect:
        case OE7800ButtonPause:
        case OE7800ButtonReset:
            _inputState[ProSystemMap[button + 6]] = 0;
            break;

        default:
            break;
    }
}

- (oneway void)mouseMovedAtPoint:(CGPoint)aPoint {
    if(_isLightgunEnabled) {
        // All of this really needs to be tweaked per the 5 games that support light gun
        int yoffset = (cartridge_region == REGION_NTSC ? 2 : -2);

        // The number of scanlines for the current cartridge
        int scanlines = _videoHeight;

        float yratio = ((float)scanlines / (float)_videoHeight);
        float xratio = ((float)LG_CYCLES_PER_SCANLINE / (float)_videoWidth);

        lightgun_scanline = (((float)aPoint.y * yratio) + (maria_visibleArea.top - maria_displayArea.top + 1) + yoffset);
        lightgun_cycle = (HBLANK_CYCLES + LG_CYCLES_INDENT + ((float)aPoint.x * xratio));

        if(lightgun_cycle > CYCLES_PER_SCANLINE)
        {
            lightgun_scanline++;
            lightgun_cycle -= CYCLES_PER_SCANLINE;
        }
    }
}

- (oneway void)leftMouseDownAtPoint:(CGPoint)aPoint {
    if(_isLightgunEnabled) {
        [self mouseMovedAtPoint:aPoint];

        _inputState[3] = 0;
    }
}

- (oneway void)leftMouseUp {
    if(_isLightgunEnabled)
        _inputState[3] = 1;
}

#pragma mark - Misc Helper Methods
// Set palette 32bpp
- (void)setPalette32 {
    for(int index = 0; index < 256; index++)
    {
        uint32_t r = CFSwapInt32LittleToHost(palette_data[(index * 3) + 0] << 16);
        uint32_t g = CFSwapInt32LittleToHost(palette_data[(index * 3) + 1] << 8);
        uint32_t b = CFSwapInt32LittleToHost(palette_data[(index * 3) + 2] << 0);
        _displayPalette[index] = r | g | b;
    }
}

@end
