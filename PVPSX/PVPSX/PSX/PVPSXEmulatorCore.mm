//
//  PVPSXEmulatorCore.m
//  PVPSX
//
//  Created by David Green on 10/27/14.
//  Copyright (c) 2014 David Green. All rights reserved.
//

#include "mednafen.h"
#include "settings-driver.h"

#import "PVPSXEmulatorCore.h"
#import "OERingBuffer.h"
#import "OETimingUtils.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface PVPSXEmulatorCore ()
{
	uint32_t *inputBuffer[2];
	int systemType;
	int videoWidth, videoHeight;
	int videoOffsetX, videoOffsetY;
	//NSString *romName;
	double masterClock;
	
	NSString *mednafenCoreModule;
	NSTimeInterval mednafenCoreTiming;
	CGSize mednafenCoreAspect;
}
@property NSString *romPath;
@end

static MDFNGI *game;
static MDFN_Surface *surf;

enum systemTypes{ psx };
//enum systemTypes{ lynx, pce, pcfx, psx, vb, wswan }; // might need this

__weak PVPSXEmulatorCore *_current;

@implementation PVPSXEmulatorCore

static void mednafen_init()
{
	__strong PVPSXEmulatorCore *strongCurrent = _current;
	
	std::vector<MDFNGI*> ext;
	MDFNI_InitializeModules(ext);
	
	std::vector<MDFNSetting> settings;
	
	NSString *batterySavesDirectory = strongCurrent.batterySavesDirectoryPath;
	NSString *biosPath = strongCurrent.biosDirectoryPath;
	
	MDFNI_Initialize([biosPath UTF8String], settings);
	
	// Set bios/system file and memcard save paths
	MDFNI_SetSetting("psx.bios_jp", [[[biosPath stringByAppendingPathComponent:@"scph5500"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SCPH-5500 BIOS
	MDFNI_SetSetting("psx.bios_na", [[[biosPath stringByAppendingPathComponent:@"scph7502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA SCPH-5501 BIOS
	MDFNI_SetSetting("psx.bios_eu", [[[biosPath stringByAppendingPathComponent:@"scph5502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // EU SCPH-5502 BIOS
	MDFNI_SetSetting("filesys.path_sav", [batterySavesDirectory UTF8String]); // Memcards
	
	
	//MDFNI_SetSetting("psx.clobbers_lament", "1"); // Enable experimental save states
}

- (instancetype)init
{
	if ((self = [super init])) {
		_current = self;
		
		inputBuffer[0] = (uint32_t *) calloc(9, sizeof(uint32_t));
		inputBuffer[1] = (uint32_t *) calloc(9, sizeof(uint32_t));
		
	}
	
	return self;
}

- (void)dealloc
{
	free(inputBuffer[0]);
	free(inputBuffer[1]);
	
	delete surf;
}

- (NSString *)biosDirectoryPath
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectoryPath = [paths objectAtIndex:0];
	NSString *biosPath = [documentsDirectoryPath stringByAppendingPathComponent:@"bios"];
	
	return biosPath;
}

//- (NSString *)supportDirectoryPath
//{
//	// TODO: get the bios path in documents
//	return @"";//return [[self owner] supportDirectoryPath];
//}

- (NSString *)batterySavesDirectoryPath
{
	return self.batterySavesPath;
}

# pragma mark - Execution

static void emulation_run()
{
	__strong PVPSXEmulatorCore *strongCurrent = _current;
	
	static int16_t sound_buf[0x10000];
	int32 rects[game->fb_height];
	rects[0] = ~0;
	
	EmulateSpecStruct spec = {0};
	spec.surface = surf;
	spec.SoundRate = strongCurrent->_sampleRate;
	spec.SoundBuf = sound_buf;
	spec.LineWidths = rects;
	spec.SoundBufMaxSize = sizeof(sound_buf) / 2;
	spec.SoundVolume = 1.0;
	spec.soundmultiplier = 1.0;
	
	MDFNI_Emulate(&spec);
	
	strongCurrent->mednafenCoreTiming = strongCurrent->masterClock / spec.MasterCycles;
	
	if(strongCurrent->systemType == psx)
	{
		strongCurrent->videoWidth = rects[spec.DisplayRect.y];
		
		// Crop overscan for NTSC. Might remove as this kinda sucks
		if(game->VideoSystem == VIDSYS_NTSC) {
			switch(strongCurrent->videoWidth)
			{
					// The shifts are not simply (padded_width - real_width) / 2.
				case 350:
					strongCurrent->videoOffsetX = 14;
					strongCurrent->videoWidth = 320;
					break;
					
				case 700:
					strongCurrent->videoOffsetX = 33;
					strongCurrent->videoWidth = 640;
					break;
					
				case 400:
					strongCurrent->videoOffsetX = 15;
					strongCurrent->videoWidth = 364;
					break;
					
				case 280:
					strongCurrent->videoOffsetX = 10;
					strongCurrent->videoWidth = 256;
					break;
					
				case 560:
					strongCurrent->videoOffsetX = 26;
					strongCurrent->videoWidth = 512;
					break;
					
				default:
					// This shouldn't happen.
					break;
			}
		}
	}
	else if(game->multires)
	{
		strongCurrent->videoWidth = rects[spec.DisplayRect.y];
		strongCurrent->videoOffsetX = spec.DisplayRect.x;
	}
	else
	{
		strongCurrent->videoWidth = spec.DisplayRect.w;
		strongCurrent->videoOffsetX = spec.DisplayRect.x;
	}
	
	strongCurrent->videoHeight = spec.DisplayRect.h;
	strongCurrent->videoOffsetY = spec.DisplayRect.y;
	
	update_audio_batch(spec.SoundBuf, spec.SoundBufSize);
}

- (BOOL)loadFileAtPath:(NSString *)path
{
	[[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesDirectoryPath] withIntermediateDirectories:YES attributes:nil error:NULL];
	
	
	
	systemType = psx;
	
	mednafenCoreModule = @"psx";
	mednafenCoreAspect = CGSizeMake(4, 3);
	_sampleRate         = 44100;
	
	
	mednafen_init();
	
	game = MDFNI_LoadGame([mednafenCoreModule UTF8String], [path UTF8String]);
	if(!game) 
	{
		return NO;
	}
	
	// BGRA pixel format
	MDFN_PixelFormat pix_fmt(MDFN_COLORSPACE_RGB, 16, 8, 0, 24);
	surf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
	
	masterClock = game->MasterClock >> 32;
	
	
	game->SetInput(0, "dualshock", inputBuffer[0]);
	game->SetInput(1, "dualshock", inputBuffer[1]);
	
	emulation_run();
	
	return YES;
}

- (void)executeFrame
{
	[self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame: (BOOL) skip
{
	emulation_run();
}

- (void)resetEmulation
{
	MDFNI_Reset();
}

- (void)stopEmulation
{
	MDFNI_CloseGame();
	
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
	
	////	struct mach_timebase_info timebase;
	////	mach_timebase_info(&timebase);
	////	double toSec = 1e-09 * (timebase.numer / timebase.denom);
	////	NSTimeInterval gameTime = mach_absolute_time() * toSec;
	
	OESetThreadRealtime(gameInterval, 0.005, 0.01666); // guessed from bsnes
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

- (NSTimeInterval)frameInterval
{
	NSLog(@"FrameInterval %f", mednafenCoreTiming);
	return 59.97;//mednafenCoreTiming ?: 60;
}

# pragma mark - Video

- (CGRect)screenRect
{
	return CGRectMake(videoOffsetX, videoOffsetY, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
	return CGSizeMake(game->fb_width, game->fb_height);
}

- (CGSize)aspectSize
{
	return mednafenCoreAspect;
}

- (const void *)videoBuffer
{
	return surf->pixels;
}

- (GLenum)pixelFormat
{
	return GL_BGRA_EXT;
}

- (GLenum)pixelType
{
	return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
	return GL_RGBA;
}

# pragma mark - Audio

static size_t update_audio_batch(const int16_t *data, size_t frames)
{
	__strong PVPSXEmulatorCore *strongCurrent = _current;
	
	[[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames * [strongCurrent channelCount] * 2];
	return frames;
}

- (double)audioSampleRate
{
	return _sampleRate ? _sampleRate : 48000;
}

- (NSUInteger)channelCount
{
	return game->soundchan;
}

- (NSUInteger)audioBufferCount
{
	return 1;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
	return MDFNSS_Save([fileName UTF8String], "");
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
	return MDFNSS_Load([fileName UTF8String], "");
}

# pragma mark - Input

// Map OE button order to Mednafen button order
const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };

- (void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
{
	inputBuffer[player-1][0] |= 1 << PSXMap[button];
}

- (void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
{
	inputBuffer[player-1][0] &= ~(1 << PSXMap[button]);
}

- (void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
	int analogNumber = PSXMap[button] - 17;
	uint8_t *buf = (uint8_t *)inputBuffer[player-1];
	*(uint16*)& buf[3 + analogNumber * 2] = 32767 * value;
}

- (void)changeDisplayMode
{
//	if (systemType == vb)
//	{
//		switch (MDFN_IEN_VB::mednafenCurrentDisplayMode)
//		{
//			case 0: // (2D) red/black
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x000000);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(true);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 1: // (2D) white/black
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFFFFFF, 0x000000);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(true);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 2: // (2D) purple/black
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF00FF, 0x000000);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(true);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 3: // (3D) red/blue
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x0000FF);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(false);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 4: // (3D) red/cyan
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00B7EB);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(false);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 5: // (3D) red/electric cyan
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00FFFF);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(false);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 6: // (3D) red/green
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00FF00);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(false);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 7: // (3D) green/red
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0x00FF00, 0xFF0000);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(false);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode++;
//				break;
//				
//			case 8: // (3D) yellow/blue
//				MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFFFF00, 0x0000FF);
//				MDFN_IEN_VB::VIP_SetParallaxDisable(false);
//				MDFN_IEN_VB::mednafenCurrentDisplayMode = 0;
//				break;
//				
//			default:
//				return;
//				break;
//		}
//	}
}


@end
