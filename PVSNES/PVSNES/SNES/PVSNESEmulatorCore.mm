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

#define SAMPLERATE      48000
#define SIZESOUNDBUFFER SAMPLERATE / 50 * 4

@interface PVSNESEmulatorCore ()
{
    UInt16        *soundBuffer;
    unsigned char *videoBuffer;
}

@end

NSString *SNESEmulatorKeys[] = { @"Up", @"Down", @"Left", @"Right", @"A", @"B", @"X", @"Y", @"L", @"R", @"Start", @"Select", nil };

@implementation PVSNESEmulatorCore

- (id)init
{
	if ((self = [super init]))
	{
		soundBuffer = (UInt16 *)malloc(SIZESOUNDBUFFER * sizeof(UInt16));
		memset(soundBuffer, 0, SIZESOUNDBUFFER * sizeof(UInt16));
	}
	
	return self;
}

- (void)dealloc
{
    free(videoBuffer);
    free(soundBuffer);
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
		
        NSLog(@"Trying to save SRAM");
		
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
		
        Memory.SaveSRAM([filePath UTF8String]);
    }
	
    [super stopEmulation];
}

- (void)frameRefreshThread:(id)anArgument
{
	gameInterval = 1.0 / [self frameInterval];
	NSTimeInterval gameTime = OEMonotonicTime();
	
	/*
	 Calling OEMonotonicTime() from the base class implementation
	 of this method causes it to return a garbage value similar
	 to 1.52746e+9 which, in turn, causes OEWaitUntil to wait forever.
	 
	 Calculating the absolute time in the base class implementation
	 without using OETimingUtils yields an expected value.
	 
	 However, calculating the absolute time while in the base class
	 implementation seems to have a performance hit effect as
	 emulation is not as fast as it should be when running on a device,
	 causing audio and video glitches, but appears fine in the simulator
	 (no doubt because it's on a faster CPU).
	 
	 Calling OEMonotonicTime() from any subclass implementation of
	 this method also yields the expected value, and results in
	 expected emulation speed.
	 
	 I am unable to understand or explain why this occurs. I am obviously
	 missing some vital information relating to this issue.
	 Perhaps someone more knowledgable than myself can explain and/or fix this.
	 */
	
//	struct mach_timebase_info timebase;
//	mach_timebase_info(&timebase);
//	double toSec = 1e-09 * (timebase.numer / timebase.denom);
//	NSTimeInterval gameTime = mach_absolute_time() * toSec;
	
	OESetThreadRealtime(gameInterval, 0.007, 0.03); // guessed from bsnes
	while (!shouldStop)
	{
		if (self.shouldResyncTime)
		{
			self.shouldResyncTime = NO;
			gameTime = OEMonotonicTime();
		}
		
		gameTime += gameInterval;
		
		@autoreleasepool
		{
			if (isRunning)
			{
				[self executeFrame];
			}
		}
		
		OEWaitUntil(gameTime);
//		mach_wait_until(gameTime / toSec);
	}
}

- (void)executeFrame
{
    IPPU.RenderThisFrame = YES;
    S9xMainLoop();

    S9xMixSamples((unsigned char *)soundBuffer, (SAMPLERATE / [self frameInterval]) * [self channelCount]);
    [[self ringBufferAtIndex:0] write:soundBuffer maxLength:sizeof(UInt16) * [self channelCount] * (SAMPLERATE / [self frameInterval])];
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
    Settings.SoundPlaybackRate      = 48000;
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

    if(videoBuffer) free(videoBuffer);

    videoBuffer = (unsigned char *)malloc(MAX_SNES_WIDTH * MAX_SNES_HEIGHT * sizeof(uint16_t));
    //GFX.PixelFormat = 3;

    GFX.Pitch = 512 * 2;
    //GFX.PPL = SNES_WIDTH;
    GFX.Screen = (short unsigned int *)videoBuffer;

    S9xUnmapAllControls();

    [self mapButtons];

    S9xSetController(0, CTL_JOYPAD, 0, 0, 0, 0);
    S9xSetController(1, CTL_JOYPAD, 1, 0, 0, 0);

    //S9xSetRenderPixelFormat(RGB565);
    if(!Memory.Init() || !S9xInitAPU() || !S9xGraphicsInit())
    {
        NSLog(@"Couldn't init");
        return NO;
    }

    NSLog(@"loading %@", path);

    /* buffer_ms : buffer size given in millisecond
     lag_ms    : allowable time-lag given in millisecond
     S9xInitSound(macSoundBuffer_ms, macSoundLagEnable ? macSoundBuffer_ms / 2 : 0); */
    if(!S9xInitSound(SIZESOUNDBUFFER, 0))
        NSLog(@"Couldn't init sound");

    Settings.NoPatch = true;
    Settings.BSXBootup = false;

    if(Memory.LoadROM([path UTF8String]))
    {
        NSString *path = [NSString stringWithUTF8String:Memory.ROMFilename];
        NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];

        NSString *batterySavesDirectory = [self batterySavesPath];

        //if((batterySavesDirectory != nil) && ![batterySavesDirectory isEqualToString:@""])
        if([batterySavesDirectory length] != 0)
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

- (uint16_t *)videoBuffer
{
    return GFX.Screen;
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
    return Settings.PAL ? 50 : 60;
}

#pragma mark Audio

bool8 S9xOpenSoundDevice(void)
{
	return true;
}

- (double)audioSampleRate
{
    return SAMPLERATE;
}

- (NSUInteger)audioBufferCount
{
	return 1;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark Save States
- (BOOL)saveStateToFileAtPath: (NSString *) fileName
{
    return S9xFreezeGame([fileName UTF8String]) ? YES : NO;
}

- (BOOL)loadStateFromFileAtPath: (NSString *) fileName
{
    return S9xUnfreezeGame([fileName UTF8String]) ? YES : NO;
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

- (void)pushSNESButton:(PVSNESButton)button
{
    S9xReportButton((1 << 16) | button, true);
}

- (void)releaseSNESButton:(PVSNESButton)button
{
    S9xReportButton((1 << 16) | button, false);
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

@end
