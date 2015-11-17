/*
 Copyright (c) 2009, OpenEmu Team


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

#import "PVSNESEmulatorCore.h"
#import "OERingBuffer.h"
#import "OETimingUtils.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>

#include "memmap.h"
#include "pixform.h"
#include "gfx.h"
#include "display.h"
#include "ppu.h"
#include "apu.h"
#include "controls.h"
#include "snes9x.h"
#include "movie.h"
#include "snapshot.h"
#include "screenshot.h"
#include "cheats.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#include <pthread.h>

#define SAMPLERATE      32000
#define SIZESOUNDBUFFER SAMPLERATE / 50 * 4

static __weak PVSNESEmulatorCore *_current;

@interface PVSNESEmulatorCore () {

@public
    UInt16        *soundBuffer;
    unsigned char *videoBuffer;
    unsigned char *videoBufferA;
    unsigned char *videoBufferB;
}

@end

bool8 S9xDeinitUpdate(int width, int height)
{
    __strong PVSNESEmulatorCore *strongCurrent = _current;
    [strongCurrent flipBuffers];

    return true;
}

NSString *SNESEmulatorKeys[] = { @"Up", @"Down", @"Left", @"Right", @"A", @"B", @"X", @"Y", @"L", @"R", @"Start", @"Select", nil };

@implementation PVSNESEmulatorCore

- (id)init
{
	if ((self = [super init]))
	{
		soundBuffer = (UInt16 *)malloc(SIZESOUNDBUFFER * sizeof(UInt16));
		memset(soundBuffer, 0, SIZESOUNDBUFFER * sizeof(UInt16));
        _current = self;
	}
	
	return self;
}

- (void)dealloc
{
    free(videoBufferA);
    videoBufferA = NULL;
    free(videoBufferB);
    videoBufferB = NULL;
    videoBuffer = NULL;
    free(soundBuffer);
    soundBuffer = NULL;
}

#pragma mark Exectuion

- (void)resetEmulation
{
    S9xSoftReset();
}

- (void)stopEmulation
{
    NSString *path = [NSString stringWithUTF8String:Memory.ROMFilename];
    NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
	
    NSString *batterySavesDirectory = [self batterySavesPath];
	
    if([batterySavesDirectory length] != 0)
    {
		
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
		
        DLog(@"Trying to save SRAM");
		
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
		
        Memory.SaveSRAM([filePath UTF8String]);
    }
	
    [super stopEmulation];
}

- (void)executeFrame
{
    IPPU.RenderThisFrame = YES;
    S9xMainLoop();
    if (self.controller1 || self.controller2)
    {
        [self pollControllers];
    }
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    memset(&Settings, 0, sizeof(Settings));
    Settings.DontSaveOopsSnapshot = true;
    Settings.ForcePAL      = false;
    Settings.ForceNTSC     = false;
    Settings.ForceHeader   = false;
    Settings.ForceNoHeader = false;

    Settings.MouseMaster            = true;
    Settings.SuperScopeMaster       = true;
    Settings.MultiPlayer5Master     = true;
    Settings.JustifierMaster        = true;
    Settings.BlockInvalidVRAMAccess = true;
    Settings.HDMATimingHack         = 100;
    Settings.SoundPlaybackRate      = SAMPLERATE;
    Settings.Stereo                 = true;
    Settings.SixteenBitSound        = true;
    Settings.Transparency           = true;
    Settings.SupportHiRes           = true;
    GFX.InfoString                  = NULL;
    GFX.InfoStringTimeout           = 0;
    //Settings.OpenGLEnable           = true; -enable this and use (BOOL)rendersToOpenGL
    Settings.SoundInputRate         = 32000;
    //Settings.DumpStreamsMaxFrames   = -1;
    //Settings.AutoDisplayMessages    = true;
    //Settings.FrameTimeNTSC          = 16667;

    if (videoBufferA)
    {
        free(videoBufferA);
    }
    
    if (videoBufferB)
    {
        free(videoBufferB);
    }

    videoBuffer = NULL;
    videoBufferA = (unsigned char *)malloc(MAX_SNES_WIDTH * MAX_SNES_HEIGHT * sizeof(uint16_t));
    videoBufferB = (unsigned char *)malloc(MAX_SNES_WIDTH * MAX_SNES_HEIGHT * sizeof(uint16_t));
    //GFX.PixelFormat = 3;

    GFX.Pitch = 512 * 2;
    //GFX.PPL = SNES_WIDTH;
    GFX.Screen = (short unsigned int *)videoBufferA;

    S9xUnmapAllControls();
    [self mapButtons];

    S9xSetController(0, CTL_JOYPAD, 0, 0, 0, 0);
    S9xSetController(1, CTL_JOYPAD, 1, 0, 0, 0);

    //S9xSetRenderPixelFormat(RGB565);
    if(!Memory.Init() || !S9xInitAPU() || !S9xGraphicsInit())
    {
        DLog(@"Couldn't init");
        return NO;
    }

    DLog(@"loading %@", path);

    /* buffer_ms : buffer size given in millisecond
     lag_ms    : allowable time-lag given in millisecond
     S9xInitSound(macSoundBuffer_ms, macSoundLagEnable ? macSoundBuffer_ms / 2 : 0); */
    if(!S9xInitSound(100, 0))
    {
        DLog(@"Couldn't init sound");
    }

    S9xSetSamplesAvailableCallback(FinalizeSamplesAudioCallback, NULL);

    Settings.NoPatch = true;
    Settings.BSXBootup = false;

    if(Memory.LoadROM([path UTF8String]))
    {
        NSString *path = [NSString stringWithUTF8String:Memory.ROMFilename];
        NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];

        NSString *batterySavesDirectory = [self batterySavesPath];
        
        if([batterySavesDirectory length])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
            
            NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
            
            Memory.LoadSRAM([filePath UTF8String]);
        }
        
        return YES;
    }

    return NO;
}

#pragma mark Video

- (void)flipBuffers
{
    if (GFX.Screen == (short unsigned int *)videoBufferA)
    {
        videoBuffer = videoBufferA;
        GFX.Screen = (short unsigned int *)videoBufferB;
    }
    else
    {
        videoBuffer = videoBufferB;
        GFX.Screen = (short unsigned int *)videoBufferA;
    }
}

- (const void *)videoBuffer
{
    return videoBuffer;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight);
}

- (CGSize)aspectSize
{
	return CGSizeMake(4, 3);
}

- (CGSize)bufferSize
{
    return CGSizeMake(MAX_SNES_WIDTH, MAX_SNES_HEIGHT);
}

- (GLenum)pixelFormat
{
    return GL_RGB;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB;
}

- (NSTimeInterval)frameInterval
{
    return Settings.PAL ? 50 : 60.098;
}

#pragma mark Audio

bool8 S9xOpenSoundDevice(void)
{
	return true;
}

static void FinalizeSamplesAudioCallback(void *)
{
    __strong PVSNESEmulatorCore *strongCurrent = _current;
    
    S9xFinalizeSamples();
    int samples = S9xGetSampleCount();
    S9xMixSamples((uint8_t*)strongCurrent->soundBuffer, samples);
    [[strongCurrent ringBufferAtIndex:0] write:strongCurrent->soundBuffer maxLength:samples * 2];
}

- (double)audioSampleRate
{
    return SAMPLERATE;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark Save States
- (BOOL)saveStateToFileAtPath: (NSString *) fileName
{
    @synchronized(self) {
        return S9xFreezeGame([fileName UTF8String]) ? YES : NO;
    }
}

- (BOOL)loadStateFromFileAtPath: (NSString *) fileName
{
    @synchronized(self) {
        return S9xUnfreezeGame([fileName UTF8String]) ? YES : NO;
    }
}

#pragma mark - Cheats

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled
{
    Settings.ApplyCheats = true;
    
    NSArray *multipleCodes = [[NSArray alloc] init];
    multipleCodes = [code componentsSeparatedByString:@"+"];
    
    for (NSString *singleCode in multipleCodes) {
        // Sanitize for PAR codes that might contain colons
        const char *cheatCode = [[singleCode stringByReplacingOccurrencesOfString:@":"
                                                                   withString:@""] UTF8String];
        uint32		address;
        uint8		byte;
        
        // Both will determine if valid cheat code or not
        S9xGameGenieToRaw(cheatCode, address, byte);
        S9xProActionReplayToRaw(cheatCode, address, byte);
        
        S9xAddCheat(TRUE, FALSE, address, byte);
    }
}

#pragma mark - Input

- (void)pushSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player
{
    S9xReportButton((player+1 << 16) | button, true);
}

- (void)releaseSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player
{
    S9xReportButton((player+1 << 16) | button, false);
}

- (void)mapButtons
{
    for(int player = 1; player <= 8; player++)
    {
        NSUInteger playerMask = player << 16;
		
        NSString *playerString = [NSString stringWithFormat:@"Joypad%d ", player];
		
        for(NSUInteger idx = 0; idx < PVSNESButtonCount; idx++)
        {
            s9xcommand_t cmd = S9xGetCommandT([[playerString stringByAppendingString:SNESEmulatorKeys[idx]] UTF8String]);
            S9xMapButton(playerMask | idx, cmd, false);
        }
    }
}

- (void)pollControllers
{
    GCController *controller = nil;

    for (NSInteger player = 1; player <= 2; player++)
    {
        NSUInteger playerMask = player << 16;
        GCController *controller = (player == 1) ? self.controller1 : self.controller2;

        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *pad = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [pad dpad];

            S9xReportButton(playerMask | PVSNESButtonUp, dpad.up.pressed?:pad.leftThumbstick.up.pressed);
            S9xReportButton(playerMask | PVSNESButtonDown, dpad.down.pressed?:pad.leftThumbstick.down.pressed);
            S9xReportButton(playerMask | PVSNESButtonLeft, dpad.left.pressed?:pad.leftThumbstick.left.pressed);
            S9xReportButton(playerMask | PVSNESButtonRight, dpad.right.pressed?:pad.leftThumbstick.right.pressed);

            S9xReportButton(playerMask | PVSNESButtonB, pad.buttonA.pressed);
            S9xReportButton(playerMask | PVSNESButtonA, pad.buttonB.pressed);
            S9xReportButton(playerMask | PVSNESButtonY, pad.buttonX.pressed);
            S9xReportButton(playerMask | PVSNESButtonX, pad.buttonY.pressed);

            S9xReportButton(playerMask | PVSNESButtonTriggerLeft, pad.leftShoulder.pressed);
            S9xReportButton(playerMask | PVSNESButtonTriggerRight, pad.rightShoulder.pressed);

            S9xReportButton(playerMask | PVSNESButtonStart, pad.leftTrigger.pressed);
            S9xReportButton(playerMask | PVSNESButtonSelect, pad.rightTrigger.pressed);

        }
        else if ([controller gamepad])
        {
            GCGamepad *pad = [controller gamepad];
            GCControllerDirectionPad *dpad = [pad dpad];

            S9xReportButton(playerMask | PVSNESButtonUp, dpad.up.pressed);
            S9xReportButton(playerMask | PVSNESButtonDown, dpad.down.pressed);
            S9xReportButton(playerMask | PVSNESButtonLeft, dpad.left.pressed);
            S9xReportButton(playerMask | PVSNESButtonRight, dpad.right.pressed);

            S9xReportButton(playerMask | PVSNESButtonB, pad.buttonA.pressed);
            S9xReportButton(playerMask | PVSNESButtonA, pad.buttonB.pressed);
            S9xReportButton(playerMask | PVSNESButtonY, pad.buttonX.pressed);
            S9xReportButton(playerMask | PVSNESButtonX, pad.buttonY.pressed);

            S9xReportButton(playerMask | PVSNESButtonTriggerLeft, pad.leftShoulder.pressed);
            S9xReportButton(playerMask | PVSNESButtonTriggerRight, pad.rightShoulder.pressed);
        }
#if TARGET_OS_TV
        else if ([controller microGamepad])
        {
            GCMicroGamepad *pad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [pad dpad];

            S9xReportButton(playerMask | PVSNESButtonUp, dpad.up.value > 0.5);
            S9xReportButton(playerMask | PVSNESButtonDown, dpad.down.value > 0.5);
            S9xReportButton(playerMask | PVSNESButtonLeft, dpad.left.value > 0.5);
            S9xReportButton(playerMask | PVSNESButtonRight, dpad.right.value > 0.5);

            S9xReportButton(playerMask | PVSNESButtonB, pad.buttonA.pressed);
            S9xReportButton(playerMask | PVSNESButtonA, pad.buttonX.pressed);
        }
#endif
    }
}

@end
