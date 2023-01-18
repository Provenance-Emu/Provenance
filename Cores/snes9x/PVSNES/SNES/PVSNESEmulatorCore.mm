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
#import <PVSupport/OERingBuffer.h>
#import <PVLogging/PVLogging.h>
#import <PVSupport/PVSupport-Swift.h>

//#import <PVSupport/PVGameControllerUtilities.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

#include "snes9x.h"
#include "memmap.h"
#include "pixform.h"
#include "gfx.h"
#include "display.h"
#include "ppu.h"
#include "apu.h"
#include "controls.h"
#include "snapshot.h"
#include "screenshot.h"
#include "cheats.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#include <pthread.h>

#define SAMPLERATE      48000
#define SIZESOUNDBUFFER SAMPLERATE / 50 * 4

static __weak PVSNESEmulatorCore *_current;

@interface PVSNESEmulatorCore () {

@public
    UInt16        *soundBuffer;
    unsigned char *videoBuffer;
    unsigned char *videoBufferA;
    unsigned char *videoBufferB;
    
    BOOL isMultitap;
}

@end

NSString *SNESEmulatorKeys[] = { @"Up", @"Down", @"Left", @"Right", @"A", @"B", @"X", @"Y", @"L", @"R", @"Start", @"Select", nil };

@implementation PVSNESEmulatorCore

- (id)init
{
	if ((self = [super init]))
	{
        if(soundBuffer) free(soundBuffer);
		soundBuffer = (UInt16 *)malloc(SIZESOUNDBUFFER * sizeof(UInt16));
		memset(soundBuffer, 0, SIZESOUNDBUFFER * sizeof(UInt16));
        _current = self;
    }
	
	return self;
}

- (void)dealloc
{
    S9xSetSamplesAvailableCallback(NULL, NULL);
    free(videoBufferA);
    videoBufferA = NULL;
    free(videoBufferB);
    videoBufferB = NULL;
    videoBuffer = NULL;
    free(soundBuffer);
    soundBuffer = NULL;
}

#pragma mark Execution

- (void)resetEmulation
{
    CPU.Flags = 0;
    S9xSoftReset();
}

- (void)stopEmulation
{
    NSString *path = [NSString stringWithUTF8String:Memory.ROMFilename];
    NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
	
    NSString *batterySavesDirectory = [self batterySavesPath];
    
    [super stopEmulation];
	
    if([batterySavesDirectory length] != 0)
    {
		
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
		
        DLOG(@"Trying to save SRAM");
		
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
		
        Memory.SaveSRAM([filePath UTF8String]);
    }
	
}

- (void)executeFrame {
    IPPU.RenderThisFrame = TRUE;
    S9xMainLoop();
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {

    CPU.Flags = 0;
    memset(&Settings, 0, sizeof(Settings));

    Settings.DontSaveOopsSnapshot       = false;
    Settings.ForcePAL                   = false;
    Settings.ForceNTSC                  = false;
    Settings.ForceHeader                = false;
    Settings.ForceNoHeader              = false;
    
    Settings.MouseMaster                = true;
    Settings.SuperScopeMaster           = true;
    Settings.MultiPlayer5Master         = true;
    Settings.JustifierMaster            = true;
    
    // Sound
    
    Settings.SoundSync                  =  true;
    Settings.SixteenBitSound            =  true;
    Settings.Stereo                     =  true;
    Settings.ReverseStereo              =  false;
    Settings.SoundPlaybackRate          =  SAMPLERATE;
    Settings.SoundInputRate             =  31955; //31955 assumes 59.94 Hz display @ ((59.94/60.098806)*32040)
    Settings.Mute                       =  false;
    Settings.DynamicRateControl         =  false;
    Settings.DynamicRateLimit           =  5;
    Settings.InterpolationMethod        =  2;

    // Display

    Settings.SupportHiRes               = true;
    Settings.Transparency               = true;
    Settings.DisplayFrameRate           = false;
    Settings.DisplayPressedKeys         = false;
    Settings.AutoDisplayMessages        = true;
    Settings.InitialInfoStringTimeout   = 120;
    
    // Timings
//    Settings.SkipFrames                 =  AUTO_FRAMERATE;
//    Settings.FrameTimePAL               =  20000; // uses generic 50 but should be ((1/50.006978)*1000000) for PAL
//    Settings.FrameTimeNTSC              =  16667; // uses generic 60 but should be ((1/60.098806)*1000000) for NTSC

    // Settings
    
    Settings.BSXBootup                  = false;
    Settings.TurboMode                  = false;
    Settings.TurboSkipFrames            = 15;
    Settings.MovieTruncate              = false;
    Settings.MovieNotifyIgnored         = false;
    Settings.WrongMovieStateProtection  = true;
    Settings.StretchScreenshots         = 1;
    Settings.SnapshotScreenshots        = true;
    Settings.DontSaveOopsSnapshot       = false;
    Settings.AutoSaveDelay              = 0;
    
    // Hack
    Settings.InterpolationMethod        = DSP_INTERPOLATION_GAUSSIAN;
    Settings.OneClockCycle              = ONE_CYCLE;
    Settings.OneSlowClockCycle          = SLOW_ONE_CYCLE;
    Settings.TwoClockCycles             = TWO_CYCLES;
    Settings.SuperFXClockMultiplier     = 100;
    Settings.OverclockMode              = 0;
    Settings.SeparateEchoBuffer         = false;
    Settings.DisableGameSpecificHacks   = true;
    Settings.BlockInvalidVRAMAccessMaster = true; // disabling may fix some homebrew or ROM hacks
    Settings.HDMATimingHack             = 100;
    Settings.MaxSpriteTilesPerLine      = 34;
    
    GFX.Pitch = MAX_SNES_WIDTH * sizeof(uint16_t); // 512 * 2;

    if (videoBuffer)
        {
        free(videoBuffer);
        }
    
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

	GFX.Screen = (short unsigned int *)videoBufferA;

    S9xUnmapAllControls();
    [self mapButtons];

    S9xSetController(0, CTL_JOYPAD, 0, 0, 0, 0);
    S9xSetController(1, CTL_JOYPAD, 1, 0, 0, 0);

    if(!Memory.Init() || !S9xInitAPU() || !S9xGraphicsInit())
    {
        ELOG(@"Couldn't init Graphics");
		if(error != NULL) {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to load game.",
								   NSLocalizedFailureReasonErrorKey: @"Snes9x failed init graphics.",
								   NSLocalizedRecoverySuggestionErrorKey: @"Unknown reason."
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotStart
											userInfo:userInfo];
		*error = newError;
		}
        return NO;
    }

    DLOG(@"loading %@", path);

    /* buffer_ms : buffer size given in millisecond
     lag_ms    : allowable time-lag given in millisecond
     S9xInitSound(macSoundBuffer_ms, macSoundLagEnable ? macSoundBuffer_ms / 2 : 0); */
    if(!S9xInitSound(100))
    {
		ELOG(@"Couldn't init Graphics");
		if(error != NULL) {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to load game.",
								   NSLocalizedFailureReasonErrorKey: @"Snes9x failed init graphics.",
								   NSLocalizedRecoverySuggestionErrorKey: @"Unknown reason."
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotStart
											userInfo:userInfo];
		*error = newError;
		}
		return NO;
    }

    S9xSetSamplesAvailableCallback(FinalizeSamplesAudioCallback, NULL);

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

		NSString *cartCRC32 = [NSString stringWithFormat:@"%08x", Memory.ROMCRC32];
		// Headerless cart data
		NSArray *snesJustifier =   @[@"aa6ee29c", // Lethal Enforcers (Europe)
									 @"3c948ea6", // Lethal Enforcers (Japan)
									 @"5aff8cd5", // Lethal Enforcers (USA)
									 ];

		NSArray *superscopeGames = @[@"11e5bc5e", // Battle Clash (Europe)
									 @"f2dd3be4", // Space Bazooka (Japan)
									 @"59c00310", // Battle Clash (USA)
									 @"6810aa95", // Bazooka Blitzkrieg (USA)
									 @"21b47e62", // Destructive (Japan)
									 @"346e153f", // Hunt for Red October, The (Europe)
									 @"66ed877a", // Hunt for Red October, The (Europe) (Beta)
									 @"c796e830", // Hunt for Red October, The (USA)
									 @"76065e37", // Red October (Japan)
									 @"eb0039c4", // Metal Combat - Falcon's Revenge (Europe)
									 @"c3131b49", // Metal Combat - Falcon's Revenge (USA)
									 @"3042b049", // Operation Thunderbolt (USA)
									 @"b1859ca4", // Nintendo Scope 6 (Europe)
									 @"7887f968", // Super Scope 6 (Japan)
									 @"b141ea99", // Super Scope 6 (USA)
									 @"1a24bc5c", // X Zone (Europe)
									 @"99627bb0", // X Zone (Japan, USA)
									 @"9a8178bf", // Yoshi's Safari (Europe)
									 @"59490ce8", // Yoshi's Safari (USA)
									 @"52948f3c"  // Yoshi no Road Hunting (Japan)
									 ];

		NSArray *snesMouseGames =  @[@"aad3a72d", // ACME Animation Factory (Europe)
									 @"0944a5c3", // ACME Animation Factory (USA)
									 @"20143571", // Advanced Dungeons & Dragons - Eye of the Beholder (USA)
									 @"05798da8", // Alice no Paint Adventure (Japan)
									 @"d436489b", // Arkanoid - Doh It Again (Europe)
									 @"7a8bbafa", // Arkanoid - Doh It Again (Japan)
									 @"b50503a0", // Arkanoid - Doh It Again (USA)
									 @"24fe792f", // Asameshimae Nyanko (Japan)
									 @"10f03e3c", // Bishoujo Senshi Sailor Moon S - Kondo wa Puzzle de Oshioki yo! (Japan)
									 @"ab43e910", // Brandish 2 - Expert (Japan)
									 @"bb89e67e", // Brandish 2 - The Planet Buster (Japan)
									 @"e6c0b5da", // BreakThru! (USA)
									 @"f3b5cbb1", // Cannon Fodder (Europe)
									 //@"dfe9cc90", // Dai-3-ji Super Robot Taisen (Japan)
									 //@"8813029c", // Dai-3-ji Super Robot Taisen (Japan) (Rev 1)
									 //@"c577d666", // Dai-3-ji Super Robot Taisen (Japan) (Rev 2)
									 //@"be764d4c", // Dai-4-ji Super Robot Taisen (Japan)
									 //@"63883e1e", // Dai-4-ji Super Robot Taisen (Japan) (Rev 1)
									 @"ca1eb161", // Doukyuusei 2
									 //@"360243e4", // Doom (Europe)
									 //@"e5d722b2", // Doom (Japan)
									 //@"09e85ea6", // Doom (USA)
									 //@"52fc7228", // Dragon Knight 4 (Japan)
									 @"1cf58de9", // Farland Story 2 (Japan)
									 //@"09ff2dfe", // Fun 'n Games (Europe)
									 //@"5d6deac7", // Fun 'n Games (USA)
									 @"bee62812", // Galaxy Robo (Japan)
									 @"1d4ae6ab", // Hiouden - Mamono-tachi to no Chikai (Japan)
									 //@"247c17d3", // J.R.R. Tolkien's The Lord of the Rings - Volume One (Europe)
									 //@"8b172b4e", // J.R.R. Tolkien's The Lord of the Rings - Volume One (Germany)
									 //@"cd2150c8", // J.R.R. Tolkien's The Lord of the Rings - Volume 1 (USA)
									 //@"7ccb8762", // Jurassic Park (Europe)
									 //@"b2b1804b", // Jurassic Park (Europe) (Beta)
									 //@"61011074", // Jurassic Park (France)
									 //@"8c3f510d", // Jurassic Park (Germany)
									 //@"3ee3e840", // Jurassic Park (Italy)
									 //@"559c7cf5", // Jurassic Park (Japan)
									 //@"3dee6fd9", // Jurassic Park (Spain)
									 //@"77540cb9", // Jurassic Park (USA)
									 //@"8bfde0b7", // Jurassic Park (USA) (Rev 1)
									 //@"a0972c36", // King Arthur's World (Europe)
									 //@"99bd1fe1", // King Arthur's World (USA)
									 //@"cf00d401", // King Arthur's World (USA) (Beta)
									 //@"d66b9ae5", // Koutetsu no Kishi (Japan)
									 //@"9d5ea7f5", // Koutetsu no Kishi 2 - Sabaku no Rommel Gundan (Japan)
									 //@"d889dbdf", // Koutetsu no Kishi 3 - Gekitotsu Europe Sensen (Japan)
									 @"290107a1", // Lemmings 2 - The Tribes (Europe)
									 @"1e7a945a", // Lemmings 2 - The Tribes (Japan)
									 @"df7200c8", // Lemmings 2 - The Tribes (USA)
									 //@"41736e7e", // Lord Monarch (Japan)
									 //@"f64c5aa0", // Mario no Super Picross (Japan)
									 @"266b220e", // Mario Paint (Europe)
									 @"38c9626c", // Mario Paint (Japan, USA)
									 @"8b6bedad", // Mario Paint (Japan, USA) (Beta)
									 @"c6695e34", // Mario to Wario (Japan)
									 @"85a6b2a8", // Mario's Early Years - Preschool Fun (USA)
									 @"480b043a", // Mario's Early Years - Fun with Letters (USA)
									 @"8c0c37f4", // Mario's Early Years - Fun with Numbers (USA)
									 @"e8042edf", // Mega-Lo-Mania (Europe) (En,Fr,De)
									 @"44a9db5c", // Mega lo Mania (Europe) (En,Fr,De) (Beta)
									 @"f23bc69e", // Mega lo Mania - Jikuu Daisenryaku (Japan)
									 @"8af25e7e", // Might and Magic III - Isles of Terra (USA)
									 @"4c3814d5", // Might and Magic III - Isles of Terra (USA) (Beta)
									 @"18aff666", // Motoko-chan no Wonder Kitchen (Japan)
									 @"49da3583", // Nobunaga's Ambition (USA)
									 @"928504a7", // Nobunaga no Yabou - Haouden (Japan)
									 @"7e91d654", // Nobunaga no Yabou - Haouden (Japan) (Rev 1)
									 //@"b577815d", // On the Ball (Europe)
									 //@"50ad3fe8", // On the Ball (USA)
									 //@"78f229dc", // Jigsaw Party (Japan)
									 //@"bb6c3c54", // Pieces (USA)
									 @"6c28cc39", // Populous II - Trials of the Olympian Gods (Europe)
									 @"c5dae9b9", // Populous II - Trials of the Olympian Gods (Germany)
									 @"0a0235c0", // Populous II - Trials of the Olympian Gods (Japan)
									 @"bc06f982", // PowerMonger (Europe)
									 @"3e14376b", // PowerMonger - Mashou no Bouryaku (Japan)
									 //@"f6b0eaa9", // Revolution X (Europe)
									 //@"59d0f587", // Revolution X (Germany)
									 //@"b5939fdc", // Revolution X (Japan)
									 //@"0dc5e7ba", // Revolution X (USA)
									 @"d09762fb", // Sangokushi Seishi - Tenbu Spirits (Japan)
									 @"da5888c7", // Sgt. Saunders' Combat! (Japan)
									 //@"17db8d06", // Shien - The Blade Chaser (Japan)
									 //@"5bb2e6c3", // Shien's Revenge (USA)
									 //@"c56d245f", // Shien's Revenge (USA) (Beta)
									 @"9d5ce088", // Civilization - Sekai Shichi Daibunmei (Japan)
									 @"41fdba82", // Sid Meier's Civilization (USA)
									 @"5855f7ea", // Sid Meier's Civilization (USA) (Beta)
									 @"34b99a85", // SimAnt (Japan)
									 @"d08c05df", // SimAnt - The Electronic Ant Colony (USA)
									 @"9d5feb20", // SimAnt (USA) (Beta)
									 //@"3836a202", // Snoopy Concert (Japan)
									 @"fb0a855a", // Sound Factory (Japan) (En) (Proto)
									 @"47e900bf", // SpellCraft - Aspects of Valor (USA) (Proto)
									 //@"a2381221", // Super Caesars Palace (USA)
									 //@"88eb3131", // Super Caesars Palace (USA) (Beta)
									 //@"6f9632d7", // Super Casino - Caesars Palace (Japan)
									 //@"53193b87", // Super Casino - Caesars Palace (Japan) (Rev 1)
									 @"ff1c41c1", // Super Castles (Japan)
									 @"a644416f", // Super Nobunaga no Yabou - Zenkoku Ban (Japan)
									 //@"2051315b", // Super Pachi-Slot Mahjong (Japan)
									 @"933228f3", // Super Solitaire (Europe) (En,Fr,De,Es,It) (Proto)
									 @"62830bef", // Trump Island (Japan)
									 @"c8e80d55", // Super Solitaire (USA) (En,Fr,De,Es,It)
									 @"32633fa6", // T2 - The Arcade Game (Europe)
									 @"cb5409ff", // T2 - The Arcade Game (Japan)
									 @"5dc6b9fe", // T2 - The Arcade Game (USA)
									 @"ec26f75b", // Tin Star (USA)
									 @"6a3cceb1", // Tokimeki Memorial - Densetsu no Ki no Shita de (Japan)
									 @"ae9f3602", // Tokimeki Memorial - Densetsu no Ki no Shita de (Japan) (Rev 1)
									 //@"dba677eb", // Troddlers (Europe)
									 //@"5a80c4cb", // Troddlers (Europe) (Beta)
									 //@"6a7ff02d", // Troddlers (USA)
									 @"6f702486", // Utopia - The Creation of a Nation (Europe)
									 @"c3a6ce79", // Utopia (Germany)
									 @"268c1181", // Utopia (Japan)
									 @"252a96c7", // Utopia - The Creation of a Nation (USA)
									 @"403db46b", // Utopia - The Creation of a Nation (USA) (Beta)
									 //@"accb5950", // Vegas Stakes (Europe)
									 //@"a6bb5a7a", // Las Vegas Dream in Golden Paradise (Japan)
									 //@"03a0e935", // Vegas Stakes (USA)
									 //@"6a455ee2", // Wolfenstein 3D (Europe)
									 //@"cc47b8f9", // Wolfenstein 3D - The Claw of Eisenfaust (Japan)
									 //@"6582a8f5", // Wolfenstein 3-D (USA)
									 //@"63e442b4", // Wolfenstein 3D (USA) (Beta 1)
									 //@"2bebdb00", // Wolfenstein 3D (USA) (Beta 2)
									 @"af8f4db9", // Wonder Project J - Kikai no Shounen Pino (Japan)
									 //@"39942e05", // Zan II Spirits (Japan)
									 //@"9826771b", // Zan III Spirits (Japan)
									 @"fe66fef2", // Zico Soccer (Japan)
									 ];

		NSArray *multitapGames =   @[@"5613f172", // Bakukyuu Renpatsu!! Super B-Daman (Japan)
									 @"94bfcc92", // Bakutou Dochers - Bumps-jima wa Oosawagi (Japan)
									 @"29fbd13d", // Barkley Shut Up and Jam! (Europe)
									 @"8aff96d0", // Barkley no Power Dunk (Japan)
									 @"726b6c5a", // Barkley Shut Up and Jam! (USA)
									 @"5f5e9b0b", // Battle Cross (Japan)
									 @"d79c1ec5", // Battle Jockey (Japan)
									 @"25391c9f", // Bill Walsh College Football (USA)
									 @"9fea854d", // Bomber Man B-Daman (Japan)
									 @"bbcd16f4", // Soccer Shootout (Europe)
									 @"d96b3936", // J.League Excite Stage '94 (Japan)
									 @"c9e33615", // J.League Excite Stage '94 (Japan) (Rev 1)
									 @"ee314ae5", // Capcom's Soccer Shootout (USA)
									 @"89178bc0", // Capcom's Soccer Shootout (USA) (Beta)
									 @"846151c8", // Chibi Maruko-chan - Harikiri 365-nichi no Maki (Japan)
									 @"f4defcae", // Chibi Maruko-chan - Mezase! Minami no Island!! (Japan)
									 @"ce842c6d", // College Slam (USA)
									 @"79663a93", // Crystal Beans from Dungeon Explorer (Japan)
									 @"dbf4a8ab", // Dino Dini's Soccer! (Europe) (En,Fr,De)
									 @"038212ea", // Dragon - The Bruce Lee Story (Europe)
									 @"407c5c24", // Dragon - The Bruce Lee Story (USA)
									 @"cc24110a", // Dream Basketball - Dunk & Hoop (Japan)
									 @"ebcc121c", // Dynamic Stadium (Japan)
									 @"62abaee1", // Elite Soccer (USA)
									 @"6d16f5e7", // World Cup Striker (Europe) (En,Fr,De)
									 @"6928d52a", // World Cup Striker (Europe) (En,Fr,De) (Beta)
									 @"cab690a1", // World Cup Striker (Japan)
									 @"75058ede", // ESPN National Hockey Night (USA)
									 @"28c2d764", // FIFA - A Caminho Da Copa 98 (Brazil) (En,Fr,De,Es,It,Sv)
									 @"5e4f4856", // FIFA - Road to World Cup 98 (Europe) (En,Fr,De,Es,It,Sv)
									 @"a350821a", // FIFA International Soccer (Europe)
									 @"4fa1d452", // FIFA International Soccer (Japan)
									 @"56296426", // FIFA International Soccer (USA)
									 @"8faf17e5", // FIFA Soccer 96 (Europe) (En,Fr,De,Es,It,Sv)
									 @"7566347d", // FIFA Soccer 96 (USA) (En,Fr,De,Es,It,Sv)
									 @"470eabe5", // FIFA 97 (Europe) (En,Fr,De,Es,It,Sv)
									 @"38916376", // FIFA Soccer 97 (USA) (En,Fr,De,Es,It,Sv)
									 @"e06fae58", // Finalset (Japan)
									 @"e500c7ba", // FireStriker (USA)
									 @"bbbbabb6", // FireStriker (USA) (Beta)
									 @"46acfc84", // Holy Striker (Japan)
									 @"9b1ea779", // Fever Pitch Soccer (Europe) (En,Fr,De,Es,It)
									 @"25c8f98a", // Fever Pitch Soccer (Europe) (Beta)
									 @"60dc3634", // Head-On Soccer (USA)
									 @"d05114c0", // From TV Animation Slam Dunk - SD Heat Up!! (Japan)
									 @"184b07dc", // Go! Go! Dodge League (Japan)
									 @"06e6e66d", // Go! Go! Dodge League (Japan) (Rev 1)
									 @"3d2352ea", // Hammer Lock Wrestling (USA)
									 @"d5fb8c83", // Tenryuu Genichirou no Pro Wres Revolution (Japan)
									 @"19e67dff", // Hat Trick Hero 2 (Japan)
									 @"0b94ccd4", // Hebereke no Oishii Puzzle wa Irimasenka (Japan)
									 @"9f6d0228", // Human Grand Prix III - F1 Triple Battle (Japan)
									 @"47453477", // Human Grand Prix IV - F1 Dream Battle (Japan)
									 @"5c4b2544", // Hungry Dinosaurs (Europe)
									 @"7abdb576", // Harapeko Bakka (Japan)
									 @"cba724ba", // International Superstar Soccer Deluxe (Europe)
									 @"0a20e602", // International Superstar Soccer Deluxe (USA)
									 @"e7559d73", // Jikkyou World Soccer 2 - Fighting Eleven (Japan)
									 @"261e0ea1", // Jikkyou World Soccer 2 - Fighting Eleven (Japan) (Beta)
									 @"dd871511", // J.League Excite Stage '95 (Japan)
									 @"c286ee0c", // J.League Excite Stage '95 (Japan) (Sample)
									 @"e044e0f1", // J.League Excite Stage '96 (Japan)
									 @"857bbfab", // J.League Excite Stage '96 (Japan) (Rev 1)
									 @"b81828ec", // J.League Soccer Prime Goal (Japan)
									 @"7538f598", // J.League Soccer Prime Goal (Japan) (Rev 1)
									 @"26664bb4", // J.League Super Soccer '95 - Jikkyou Stadium (Japan)
									 @"247c17d3", // J.R.R. Tolkien's The Lord of the Rings - Volume One (Europe)
									 @"8b172b4e", // J.R.R. Tolkien's The Lord of the Rings - Volume One (Germany)
									 @"cd2150c8", // J.R.R. Tolkien's The Lord of the Rings - Volume 1 (USA)
									 @"94c1d85c", // Jikkyou Power Pro Wrestling '96 - Max Voltage (Japan)
									 @"bba55bec", // Jimmy Connors Pro Tennis Tour (Europe)
									 @"bea289fc", // Jimmy Connors Pro Tennis Tour (France)
									 @"e2294a8e", // Jimmy Connors Pro Tennis Tour (Germany)
									 @"a95bef02", // Jimmy Connors Pro Tennis Tour (Japan)
									 @"913f1555", // Jimmy Connors Pro Tennis Tour (USA)
									 @"69642b00", // JWP Joshi Pro Wres - Pure Wrestle Queens (Japan)
									 @"c819109c", // Kingyo Chuuihou! - Tobidase! Game Gakuen (Japan)
									 @"7bf62174", // Kunio-kun no Dodge Ball Da yo Zenin Shuugou! (Japan)
									 @"fdf2f478", // Looney Tunes Basketball (Europe)
									 @"6d3bc96f", // Looney Tunes B-Ball (USA)
									 @"a7d31544", // Madden NFL '94 (Europe)
									 @"1e4b3858", // NFL Pro Football '94 (Japan)
									 @"8bed5914", // Madden NFL '94 (USA)
									 @"4b0c7993", // Madden NFL 95 (Europe)
									 @"021a3f69", // Madden NFL 95 (USA)
									 @"51a1fe86", // Madden NFL 96 (USA)
									 @"4c78d04a", // Madden NFL 96 (USA) (Sample)
									 @"abcf026e", // Madden NFL 97 (USA)
									 @"cf10cc01", // Madden NFL 98 (USA)
									 @"b4f64a09", // Micro Machines (Europe)
									 @"364e68bb", // Micro Machines (USA)
									 @"1619b619", // Micro Machines 2 - Turbo Tournament (Europe)
									 @"70740cf4", // Mizuki Shigeru no Youkai Hyakkiyakou (Japan)
									 @"60844b65", // Multi Play Volleyball (Japan)
									 @"d4dc20e1", // Natsume Championship Wrestling (USA)
									 @"e52b9af6", // NBA Give 'n Go (Europe)
									 @"7ecaa194", // NBA Jikkyou Basket - Winning Dunk (Japan)
									 @"68c8b643", // NBA Give 'n Go (USA)
									 @"f1fe37a4", // NBA Hang Time (Europe)
									 @"262ce76b", // NBA Hang Time (USA)
									 @"2b8e81c6", // NBA Jam (Europe)
									 @"fa9a577a", // NBA Jam (Europe) (Rev 1)
									 @"118b162e", // NBA Jam (Japan)
									 @"43f1c013", // NBA Jam (USA)
									 @"8f42cae7", // NBA Jam (USA) (Rev 1)
									 @"0318705b", // NBA Jam (USA) (Beta)
									 @"d48c8041", // NBA Jam - Tournament Edition (Europe)
									 @"3c169224", // NBA Jam - Tournament Edition (Japan)
									 @"1fbc1ddb", // NBA Jam - Tournament Edition (USA)
									 @"8d7b1828", // NBA Jam - Tournament Edition (USA) (Beta)
									 @"56fdbb8c", // NBA Live 95 (Europe)
									 @"500f57d3", // NBA Live 95 (Japan)
									 @"1cd2393d", // NBA Live 95 (USA)
									 @"17689c62", // NBA Live 96 (Europe)
									 @"042a6495", // NBA Live 96 (USA)
									 @"2c680c99", // NBA Live 97 (Europe)
									 @"5115b8e5", // NBA Live 97 (USA)
									 @"514bfcb5", // NBA Live 98 (USA)
									 @"b07cfa91", // NCAA Final Four Basketball (USA)
									 @"2641c12a", // NCAA Football (USA)
									 @"87bc35af", // NFL Quarterback Club (Europe)
									 @"1c036b4f", // NFL Quarterback Club '95 (Japan)
									 @"79f16421", // NFL Quarterback Club (USA)
									 @"78d10e07", // NFL Quarterback Club (USA) (Beta)
									 @"9708abe3", // NFL Quarterback Club 96 (Europe)
									 @"3a4c0de6", // NFL Quarterback Club 96 (Japan)
									 @"e557689f", // NFL Quarterback Club 96 (USA)
									 @"b87abc7e", // NFL Quarterback Club 96 (USA) (Beta)
									 @"208fbf59", // NHL Hockey '94 (Europe)
									 @"bc37d603", // NHL Pro Hockey '94 (Japan)
									 @"42212a77", // NHL '94 (USA)
									 @"00ff0c74", // NHL '94 (USA) (Beta)
									 @"6930b67a", // NHL 95 (Europe)
									 @"2e9b1463", // NHL 95 (USA)
									 @"148b2734", // NHL 96 (Europe)
									 @"b6c6e7f3", // NHL 96 (USA)
									 @"313b9622", // NHL 97 (Europe)
									 @"1a53b7a8", // NHL 97 (Europe) (Rev 1)
									 @"06badb74", // NHL 97 (USA)
									 @"4f72aa8c", // NHL 97 (USA) (Rev 1)
									 @"03cad2d2", // NHL 98 (USA)
									 @"3ed21333", // Olympic Summer Games (Europe)
									 @"6b882d11", // Olympic Summer Games (USA)
									 @"0a2e4c2f", // Rushing Beat Shura (Japan)
									 @"8071e5db", // Peace Keepers, The (USA)
									 @"78f229dc", // Jigsaw Party (Japan)
									 @"bb6c3c54", // Pieces (USA)
									 @"689a7a79", // Puzzle'n Desu! (Japan)
									 @"adf4ffce", // Rap Jam - Volume One (USA) (En,Fr,Es)
									 @"a3876f76", // Saturday Night Slam Masters (Europe)
									 @"a6e028c2", // Muscle Bomber - The Body Explosion (Japan)
									 @"54161830", // Saturday Night Slam Masters (USA)
									 @"c5cb2f26", // Secret of Mana (Europe)
									 @"de112322", // Secret of Mana (Europe) (Rev 1)
									 @"6be4ca95", // Secret of Mana (France)
									 @"e9334b9e", // Secret of Mana (France) (Rev 1)
									 @"b069bb3a", // Secret of Mana (Germany)
									 @"b8049e3c", // Seiken Densetsu 2 (Japan)
									 @"d0176b24", // Secret of Mana (USA)
									 @"e6b9a402", // Shijou Saikyou no Quiz Ou Ketteisen Super (Japan)
									 @"58da330c", // Shin Nihon Pro Wrestling - Chou Senshi in Tokyo Dome - Fantastic Story (Japan)
									 @"6cbbd019", // Shin Nihon Pro Wrestling Kounin - '94 Battlefield in Tokyo Dome (Japan)
									 @"a467c220", // Shin Nihon Pro Wrestling Kounin - '95 Tokyo Dome Battle 7 (Japan)
									 @"6f7d1745", // Smash Tennis (Europe)
									 @"3ccba79c", // Smash Tennis (Europe) (Beta)
									 @"2bcbff26", // Super Family Tennis (Japan)
									 @"315af696", // Sporting News Baseball, The (USA)
									 @"70d9c906", // Sterling Sharpe - End 2 End (USA)
									 @"97357a1b", // Street Sports - Street Hockey '95 (USA)
									 @"29296976", // Street Hockey '95 (USA) (Beta)
									 @"e013d5b0", // Street Racer (Europe)
									 @"2ae69849", // Street Racer (Europe) (Rev 1)
									 @"d1c1f675", // Street Racer (Japan)
									 @"63e8b7d5", // Street Racer (USA)
									 @"1934f184", // Street Racer (USA) (Beta)
									 @"72123ef0", // Sugoi Hebereke (Japan)
									 @"366c84f3", // Sugoro Quest++ - Dicenics (Japan)
									 @"678501f2", // Super Bomberman (Europe)
									 @"7989891a", // Super Bomber Man (Japan)
									 @"63a8e2c6", // Super Bomberman (USA)
									 @"fc633ecb", // Super Bomber Man - Panic Bomber W (Japan)
									 @"c60a4191", // Super Bomberman 2 (Europe)
									 @"fb259f4f", // Super Bomber Man 2 (Japan)
									 @"2aa1ddf8", // Super Bomber Man 2 (Japan) (Caravan You Taikenban)
									 @"9c1f11e4", // Super Bomberman 2 (USA)
									 @"a096a6e5", // Super Bomberman 3 (Europe)
									 @"9ecb0fe6", // Super Bomber Man 3 (Japan)
									 @"002fa245", // Super Bomber Man 3 (Japan) (Beta)
									 @"3bbaeb19", // Super Bomber Man 4 (Japan)
									 @"06b1f0f5", // Super Bomber Man 5 (Japan)
									 @"4590ae9d", // Super Bomber Man 5 (Japan) (Caravan Event Ban)
									 @"4f0b96fa", // Super Final Match Tennis (Japan)
									 @"8fac5efd", // Super Fire Pro Wrestling 2 (Japan)
									 @"b48513fe", // Super Fire Pro Wrestling 2 (Japan) (Beta)
									 @"93f778af", // Super Fire Pro Wrestling III - Easy Type (Japan)
									 @"4dfb9072", // Super Fire Pro Wrestling III - Final Bout (Japan)
									 @"978dc1ca", // Super Fire Pro Wrestling III - Final Bout (Japan) (Rev 1)
									 @"3227f1b1", // Super Fire Pro Wrestling - Queen's Special (Japan)
									 @"e279ebe3", // Super Fire Pro Wrestling Special (Japan)
									 @"1a13435c", // Super Fire Pro Wrestling Special (Japan) (Rev 1)
									 @"959db484", // Super Fire Pro Wrestling X (Japan)
									 @"82de1380", // Super Fire Pro Wrestling X Premium (Japan)
									 @"74c75074", // Super Formation Soccer II (Japan)
									 @"d547c5d2", // Super Formation Soccer 94 - World Cup Edition (Japan)
									 @"bf1f2e16", // Super Formation Soccer 94 - World Cup Final Data (Japan)
									 @"798352bf", // Super Formation Soccer 95 della Serie A (Japan)
									 @"1cf83bc2", // Super Formation Soccer 95 della Serie A (Japan) (UCC Xaqua Version)
									 @"f42272cb", // Super Formation Soccer 96 - World Club Edition (Japan)
									 @"fb1d16c4", // Super Ice Hockey (Europe)
									 @"a3890d4f", // Super Hockey '94 (Japan)
									 @"60305047", // Super Kyousouba - Kaze no Sylphid (Japan)
									 @"56f3a65a", // Super Power League (Japan)
									 @"271e1f3f", // Super Puyo Puyo Tsuu (Japan)
									 @"3276e449", // Magic Johnson no Super Slam Dunk (Japan)
									 @"3effc9e5", // Super Slam Dunk (USA)
									 @"5be4a7e3", // Super Tekkyuu Fight! (Japan)
									 @"329024c7", // Super Tetris 3 (Japan)
									 @"fd851819", // Syndicate (Europe) (En,Fr,De)
									 @"181cae99", // Syndicate (Europe) (En,Fr,De) (Beta)
									 @"63c52dc4", // Syndicate (Japan)
									 @"d74570d3", // Syndicate (USA)
									 @"383face4", // Takeda Nobuhiro no Super League Soccer (Japan)
									 @"ae78b20e", // Tiny Toon Adventures - Wild & Wacky Sports (Europe)
									 @"0f3b758d", // Tiny Toon Adventures - Wild & Wacky Sports (Europe) (Rev 1)
									 @"f13002c7", // Tiny Toon Adventures - Wild & Wacky Sports (Europe) (Beta)
									 @"01344c8e", // Tiny Toon Adventures - Dotabata Daiundoukai (Japan)
									 @"afe72ff0", // Tiny Toon Adventures - Wacky Sports Challenge (USA)
									 @"493fdb13", // Top Gear 3000 (Europe)
									 @"b9b9df06", // Planet's Champ TG 3000, The (Japan)
									 @"a20be998", // Top Gear 3000 (USA)
									 @"26a9c3f4", // Turbo Toons (Europe)
									 @"ecb8a53a", // Virtual Soccer (Europe)
									 @"1d20cac2", // J.League Super Soccer (Japan)
									 @"accb5950", // Vegas Stakes (Europe)
									 @"a6bb5a7a", // Las Vegas Dream in Golden Paradise (Japan)
									 @"03a0e935", // Vegas Stakes (USA)
									 @"6383d9a5", // Virtual Soccer (USA) (Proto)
									 @"a9fcfd53", // Vs. Collection (Japan)
									 @"5fc89932", // Wedding Peach (Japan)
									 @"8b477300", // WCW Super Brawl Wrestling (USA)
									 @"a5a3bfbc", // WWF Raw (Europe)
									 @"3e0038bf", // WWF Raw (USA)
									 @"02855382", // Yuujin no Furi Furi Girls (Japan)
									 @"48e9887f", // Zero 4 Champ RR (Japan)
									 @"3c6a8dc8", // Zero 4 Champ RR-Z (Japan)
									 ];

        isMultitap = NO;
		// Automatically enable SNES Mouse, Super Scope, Justifier and Multitap where supported
		if([snesJustifier containsObject:cartCRC32])
		{
			S9xSetController(1, CTL_JUSTIFIER, 0, 0, 0, 0);
			S9xSetController(0, CTL_JOYPAD,    0, 0, 0, 0);
		}
		else if([superscopeGames containsObject:cartCRC32])
		{
			S9xSetController(1, CTL_SUPERSCOPE, 0, 0, 0, 0);
			S9xReportButton(17, true); // Super Scope turbo on by default
		}
		else if([snesMouseGames containsObject:cartCRC32])
		{
			S9xSetController(0, CTL_MOUSE,  0, 0, 0, 0); // Mouse Port 1
			S9xSetController(1, CTL_JOYPAD, 1, 0, 0, 0); // Controller Port 2
		}
		else if([multitapGames containsObject:cartCRC32])
		{
			// 5 Players
			// Controller in Port 1 and Multitap in Port 2
			S9xSetController(0, CTL_JOYPAD, 0, 0, 0, 0);
			S9xSetController(1, CTL_MP5,    1, 2, 3, 4);
            isMultitap = YES;
		}
		else if([cartCRC32 isEqual:@"be08d788"])
		{
			// 8 Players (N-Warp Daisakusen v1.1 Homebrew)
			// Multitap in Port 1 and Multitap in Port 2
			S9xSetController(0, CTL_MP5, 0, 1, 2, 3);
			S9xSetController(1, CTL_MP5, 4, 5, 6, 7);
		}
		else
		{
			S9xSetController(0, CTL_JOYPAD, 0, 0, 0, 0);
			S9xSetController(1, CTL_JOYPAD, 1, 0, 0, 0);
		}
        
        return YES;
    }

	if(error != NULL) {
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: @"Failed to load game.",
                               NSLocalizedFailureReasonErrorKey: @"Snes9x failed to load ROM.",
                               NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format Snes9x supports."
                               };
    
    NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                            code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                        userInfo:userInfo];
    
    *error = newError;
	}
    return NO;
}

#pragma mark Video

- (void)swapBuffers {
    if (GFX.Screen == (short unsigned int *)videoBufferA) {
        videoBuffer = videoBufferA;
        GFX.Screen = (short unsigned int *)videoBufferB;
    } else {
        videoBuffer = videoBufferB;
        GFX.Screen = (short unsigned int *)videoBufferA;
    }
}

- (const void *)videoBuffer {
    return videoBuffer;
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, IPPU.RenderedScreenWidth, IPPU.RenderedScreenHeight);
}

- (CGSize)aspectSize {
	return CGSizeMake(IPPU.RenderedScreenWidth * (8.0/7.0), IPPU.RenderedScreenHeight);
}

- (CGSize)bufferSize {
    static dispatch_once_t onceToken;
    static CGSize size;
    dispatch_once(&onceToken, ^{
        size =  CGSizeMake(MAX_SNES_WIDTH, MAX_SNES_HEIGHT);
    });
    return size;
}

- (GLenum)pixelFormat {
    return GL_RGB;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    return GL_RGB;
}

- (NSTimeInterval)frameInterval {
    return Settings.PAL ? 50 : 60; // for more "accuracy" does 50.007 : 60.098806 make a difference?
}

- (BOOL)isDoubleBuffered {
    return YES;
}

#pragma mark Audio

bool8 S9xOpenSoundDevice(void) {
	return true;
}

static void FinalizeSamplesAudioCallback(void *) {
    __strong PVSNESEmulatorCore *strongCurrent = _current;
    
    int samples = S9xGetSampleCount();
    S9xMixSamples((uint8_t*)strongCurrent->soundBuffer, samples);
    [[strongCurrent ringBufferAtIndex:0] write:strongCurrent->soundBuffer maxLength:samples * 2];
}

- (double)audioSampleRate {
    return SAMPLERATE;
}

- (NSUInteger)channelCount {
    return 2;
}

#pragma mark Save States
- (BOOL)saveStateToFileAtPath: (NSString *) fileName error:(NSError**)error   {
    @synchronized(self) {
        return S9xFreezeGame([fileName UTF8String]) ? YES : NO;
    }
}

- (BOOL)loadStateFromFileAtPath: (NSString *) fileName error:(NSError**)error {
    @synchronized(self) {
        return S9xUnfreezeGame([fileName UTF8String]) ? YES : NO;
    }
}

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled  error:(NSError**)error {
    NSArray *multipleCodes = [code componentsSeparatedByString:@"+"];
	if (enabled && [codeType isEqualToString:@"Raw Code"]) {
		if (multipleCodes.count < 2)
			return false;
		for (int i=0; i+1 < multipleCodes.count; i+=2) {
			uint32 mem = (uint32)strtol([multipleCodes[i] UTF8String], NULL, 16);
            uint8 value = (uint8)strtol([multipleCodes[i+1] UTF8String], NULL, 16);
            ELOG(@"Received: %d %d\n", mem, value);
			if (![self applyRawCheat:mem setValue: value]) {
                ELOG(@"Code %x %x failed", mem, value);
				return false;
			}
			ELOG(@"Code %x %x applied successfully", mem, value);
		}
	} else if (enabled) {
		for (NSString *singleCode in multipleCodes) {
			const char *cheatCode = [[singleCode stringByReplacingOccurrencesOfString:@":" withString:@""] UTF8String];
			if (singleCode != nil && singleCode.length > 0) {
				if (![self applyCheat:cheatCode setCodeType: codeType]) {
					ELOG(@"Code %s failed", cheatCode);
					return false;
				}
				ELOG(@"Code %s applied successfully", cheatCode);
			}
		}
	}
	return true;
}

- (BOOL)applyCheat:(const char*)code setCodeType:(NSString *)codeType {
    SCheat c;
    unsigned int byte = 0;
    unsigned int cond_byte = 0;
    c.enabled     = false;
    c.conditional = false;
	ELOG(@"Applying Cheat Code %s\n", code);
    if ([codeType isEqualToString:@"Game Genie"]) {
        if (!S9xGameGenieToRaw(code, c.address, c.byte))
			c.enabled = true;
        ELOG(@"GameGenie Code Decrypted: %s %d %d\n", code, c.address, c.byte);
    } else if ([codeType isEqualToString:@"Pro Action Replay" ]) {
        if (!S9xProActionReplayToRaw(code, c.address, c.byte))
			c.enabled = true;
        ELOG(@"PAR Code Decrypted: %s %d %d\n", code, c.address, c.byte);
    } else if ([codeType isEqualToString:@"Gold Finger" ]) {
		bool8 sram;
		uint8 bytes[3];
		uint8 byte;
        if (!S9xGoldFingerToRaw(code, c.address, sram, byte, bytes)) {
			c.byte=bytes[0];
			c.saved_byte=bytes[0];
			c.cond_byte=bytes[0];
			c.conditional=false;
			c.enabled = true;
			ELOG(@"Bytes %d %d %d\n", bytes[0], bytes[1], bytes[2]);
		} else {
			ELOG(@"Invalid Code: %s\n", code);
		}
		ELOG(@"Goldfinger Code Decrypted: %s %d %d\n", code, c.address, c.byte);
    }
    if (c.enabled) {
		// Call Structure of S9xUpdateCheatInMemory
		void S9xUpdateCheatInMemory(SCheat *c);
        // Update the Cheat in Memory
		S9xUpdateCheatInMemory(&c);
	}
	return c.enabled;
}

- (BOOL)applyRawCheat:(uint32)mem setValue:(uint8)value {
	mem = mem & 0xFFFFFFF;
	SCheat c;
	c.address = mem;
	c.byte = value;
	c.enabled     = true;
	c.conditional = false;
	void S9xUpdateCheatInMemory(SCheat *c);
    S9xUpdateCheatInMemory(&c);
	return true;
}
#pragma mark - Input

- (void)didPushSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player
{
    S9xReportButton((player+1 << 16) | button, true);
}

- (void)didReleaseSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player
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


-(NSUInteger)maxNumberPlayers {
    return isMultitap ? 8 : 4;
}

- (void)updateControllers {
    GCController *controller = nil;

    for (NSInteger player = 1; player <= 2; player++)
    {
        NSUInteger playerMask = player << 16;
        GCController *controller = (player == 1) ? self.controller1 : self.controller2;

        if ([controller extendedGamepad])
        {
            GCExtendedGamepad *gamepad = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            PVControllerAxisDirection axisDirection = [PVGameControllerUtilities axisDirectionForThumbstick:gamepad.leftThumbstick];

            BOOL upPressed = dpad.up.pressed || axisDirection == PVControllerAxisDirectionUp || axisDirection == PVControllerAxisDirectionUpLeft || axisDirection == PVControllerAxisDirectionUpRight;
            S9xReportButton(playerMask | PVSNESButtonUp, upPressed);
            
            BOOL downPressed = dpad.down.pressed || axisDirection == PVControllerAxisDirectionDown || axisDirection == PVControllerAxisDirectionDownLeft || axisDirection == PVControllerAxisDirectionDownRight;
            S9xReportButton(playerMask | PVSNESButtonDown, downPressed);
            
            BOOL leftPressed = dpad.left.pressed || axisDirection == PVControllerAxisDirectionLeft || axisDirection == PVControllerAxisDirectionUpLeft || axisDirection == PVControllerAxisDirectionDownLeft;
            S9xReportButton(playerMask | PVSNESButtonLeft, leftPressed);
            
            BOOL rightPressed = dpad.right.pressed || axisDirection == PVControllerAxisDirectionRight || axisDirection == PVControllerAxisDirectionUpRight || axisDirection == PVControllerAxisDirectionDownRight;
            S9xReportButton(playerMask | PVSNESButtonRight, rightPressed);

            S9xReportButton(playerMask | PVSNESButtonB, gamepad.buttonA.pressed);
            S9xReportButton(playerMask | PVSNESButtonA, gamepad.buttonB.pressed);
            S9xReportButton(playerMask | PVSNESButtonY, gamepad.buttonX.pressed);
            S9xReportButton(playerMask | PVSNESButtonX, gamepad.buttonY.pressed);

            S9xReportButton(playerMask | PVSNESButtonTriggerLeft, gamepad.leftShoulder.pressed);
            S9xReportButton(playerMask | PVSNESButtonTriggerRight, gamepad.rightShoulder.pressed);

            S9xReportButton(playerMask | PVSNESButtonStart, gamepad.rightTrigger.pressed);
            S9xReportButton(playerMask | PVSNESButtonSelect, gamepad.leftTrigger.pressed);

        }
        else if ([controller gamepad])
        {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            S9xReportButton(playerMask | PVSNESButtonUp, dpad.up.pressed);
            S9xReportButton(playerMask | PVSNESButtonDown, dpad.down.pressed);
            S9xReportButton(playerMask | PVSNESButtonLeft, dpad.left.pressed);
            S9xReportButton(playerMask | PVSNESButtonRight, dpad.right.pressed);

            S9xReportButton(playerMask | PVSNESButtonB, gamepad.buttonA.pressed);
            S9xReportButton(playerMask | PVSNESButtonA, gamepad.buttonB.pressed);
            S9xReportButton(playerMask | PVSNESButtonY, gamepad.buttonX.pressed);
            S9xReportButton(playerMask | PVSNESButtonX, gamepad.buttonY.pressed);

            S9xReportButton(playerMask | PVSNESButtonTriggerLeft, gamepad.leftShoulder.pressed);
            S9xReportButton(playerMask | PVSNESButtonTriggerRight, gamepad.rightShoulder.pressed);
        }
#if TARGET_OS_TV
        else if ([controller microGamepad])
        {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];

            S9xReportButton(playerMask | PVSNESButtonUp, dpad.up.value > 0.5);
            S9xReportButton(playerMask | PVSNESButtonDown, dpad.down.value > 0.5);
            S9xReportButton(playerMask | PVSNESButtonLeft, dpad.left.value > 0.5);
            S9xReportButton(playerMask | PVSNESButtonRight, dpad.right.value > 0.5);

            S9xReportButton(playerMask | PVSNESButtonB, gamepad.buttonA.pressed);
            S9xReportButton(playerMask | PVSNESButtonA, gamepad.buttonX.pressed);
        }
#endif
    }
}

@end
