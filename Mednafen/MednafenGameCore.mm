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

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
#pragma clang diagnostic ignored "-Wextra"
#include <mednafen/mednafen.h>
#include <mednafen/settings-driver.h>
#include <mednafen/state-driver.h>
#include <mednafen/mednafen-driver.h>
#include <mednafen/MemoryStream.h>
#pragma clang diagnostic pop

#import "MednafenGameCore.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import <UIKit/UIKit.h>
#import <PVSupport/OERingBuffer.h>
#import <PVSupport/PVSupport-Swift.h>


#define USE_PCE_FAST 0
#define USE_SNES_FAUST 1

#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface MednafenGameCore (MultiDisc)
+ (NSDictionary<NSString*,NSNumber*>*_Nonnull)multiDiscPSXGames;
@end

@interface MednafenGameCore (MultiTap)
+ (NSDictionary<NSString*,NSNumber*>*_Nonnull)multiTapPSXGames;
+ (NSArray<NSString*>*_Nonnull)multiTap5PlayerPort2;
@end

typedef struct OEIntPoint {
    int x;
    int y;
} OEIntPoint;

typedef struct OEIntSize {
    int width;
    int height;
} OEIntSize;

typedef struct OEIntRect {
    OEIntPoint origin;
    OEIntSize size;
} OEIntRect;

static inline OEIntSize OEIntSizeMake(int width, int height)
{
    return (OEIntSize){ width, height };
}
static inline BOOL OEIntSizeEqualToSize(OEIntSize size1, OEIntSize size2)
{
    return size1.width == size2.width && size1.height == size2.height;
}
static inline BOOL OEIntSizeIsEmpty(OEIntSize size)
{
    return size.width == 0 || size.height == 0;
}

static inline OEIntRect OEIntRectMake(int x, int y, int width, int height)
{
    return (OEIntRect){ (OEIntPoint){ x, y }, (OEIntSize){ width, height } };
}

static MDFNGI *game;
static MDFN_Surface *backBufferSurf;
static MDFN_Surface *frontBufferSurf;

#pragma mark - Input maps
int GBAMap[PVGBAButtonCount];
int GBMap[PVGBButtonCount];
int SNESMap[PVSNESButtonCount];
int PCEMap[PVPCEButtonCount];
int PCFXMap[PVPCFXButtonCount];

// Map OE button order to Mednafen button order

const int LynxMap[] = { 6, 7, 4, 5, 0, 1, 3, 2 }; // pause, b, 01, 02, d, u, l, r

// u, d, l, r, a, b, start, select
const int NESMap[] = { 4, 5, 6, 7, 0, 1, 3, 2};

// Select, Triangle, X, Start, R1, R2, left stick u, left stick left,
const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };
const int VBMap[]   = { 9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11 };
const int WSMap[]   = { 0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11 };
const int NeoMap[]  = { 0, 1, 2, 3, 4, 5, 6};

// SMS, GG and MD unused as of now. Mednafen support is not maintained
const int GenesisMap[] = { 5, 7, 11, 10, 0 ,1, 2, 3, 4, 6, 8, 9};

namespace MDFN_IEN_VB
{
    extern void VIP_SetParallaxDisable(bool disabled);
    extern void VIP_SetAnaglyphColors(uint32 lcolor, uint32 rcolor);
    int mednafenCurrentDisplayMode = 1;
}

@interface MednafenGameCore () <PVPSXSystemResponderClient, PVWonderSwanSystemResponderClient, PVVirtualBoySystemResponderClient, PVPCESystemResponderClient, PVPCFXSystemResponderClient, PVPCECDSystemResponderClient, PVLynxSystemResponderClient, PVNeoGeoPocketSystemResponderClient, PVSNESSystemResponderClient, PVNESSystemResponderClient, PVGBSystemResponderClient, PVGBASystemResponderClient>
{
    uint32_t *inputBuffer[8];
    int videoWidth, videoHeight;
    int videoOffsetX, videoOffsetY;
    int multiTapPlayerCount;
    NSString *romName;
    double sampleRate;
    double masterClock;

    NSString *mednafenCoreModule;
    NSTimeInterval mednafenCoreTiming;
    OEIntSize mednafenCoreAspect;

	EmulateSpecStruct spec;
}

@end

static __weak MednafenGameCore *_current;

@implementation MednafenGameCore

-(uint32_t*) getInputBuffer:(int)bufferId
{
    return inputBuffer[bufferId];
}

static void mednafen_init(MednafenGameCore* current)
{
    NSString* batterySavesDirectory = current.batterySavesPath;
    NSString* biosPath = current.BIOSPath;

	MDFNI_InitializeModules();

    std::vector<MDFNSetting> settings;

    MDFNI_Initialize([biosPath UTF8String], settings);

    // Set bios/system file and memcard save paths
    MDFNI_SetSetting("pce.cdbios", [[[biosPath stringByAppendingPathComponent:@"syscard3"] stringByAppendingPathExtension:@"pce"] UTF8String]); // PCE CD BIOS
	MDFNI_SetSetting("pce_fast.cdbios", [[[biosPath stringByAppendingPathComponent:@"syscard3"] stringByAppendingPathExtension:@"pce"] UTF8String]); // PCE CD BIOS
    MDFNI_SetSetting("pcfx.bios", [[[biosPath stringByAppendingPathComponent:@"pcfx"] stringByAppendingPathExtension:@"rom"] UTF8String]); // PCFX BIOS

    MDFNI_SetSetting("psx.bios_jp", [[[biosPath stringByAppendingPathComponent:@"scph5500"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SCPH-5500 BIOS
    MDFNI_SetSetting("psx.bios_na", [[[biosPath stringByAppendingPathComponent:@"scph5501"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA SCPH-5501 BIOS
    MDFNI_SetSetting("psx.bios_eu", [[[biosPath stringByAppendingPathComponent:@"scph5502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // EU SCPH-5502 BIOS

    MDFNI_SetSetting("filesys.path_sav", [batterySavesDirectory UTF8String]); // Memcards

	// Global settings

	// Enable time synchronization(waiting) for frame blitting.
	// Disable to reduce latency, at the cost of potentially increased video "juddering", with the maximum reduction in latency being about 1 video frame's time.
	// Will work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU.
	// Default: 1
//	MDFNI_SetSettingB("video.blit_timesync", false);
//	MDFNI_SetSettingB("video.fs", false); // Enable fullscreen mode. Default: 0

    // VB defaults. dox http://mednafen.sourceforge.net/documentation/09x/vb.html
	// VirtualBoy
    MDFNI_SetSetting("vb.disable_parallax", "1");       // Disable parallax for BG and OBJ rendering
    MDFNI_SetSetting("vb.anaglyph.preset", "disabled"); // Disable anaglyph preset
    MDFNI_SetSetting("vb.anaglyph.lcolor", "0xFF0000"); // Anaglyph l color
    MDFNI_SetSetting("vb.anaglyph.rcolor", "0x000000"); // Anaglyph r color
    //MDFNI_SetSetting("vb.allow_draw_skip", "1");      // Allow draw skipping
    //MDFNI_SetSetting("vb.instant_display_hack", "1"); // Display latency reduction hack

	// SNES Faust settings
	MDFNI_SetSettingB("snes_faust.spex", false);
	// Enable 1-frame speculative execution for video output.
	// Hack to reduce input->output video latency by 1 frame. Enabling will increase CPU usage,
	// and may cause video glitches(such as "jerkiness") in some oddball games, but most commercially-released games should be fine.
	// Default 0

//	MDFNI_SetSetting("snes_faust.special", "nn2x");



	// NES Settings

	MDFNI_SetSettingUI("nes.clipsides", 1); // Clip left+right 8 pixel columns. 0 default
	MDFNI_SetSettingB("nes.correct_aspect", true); // Correct the aspect ratio. 0 default


	// PSX Settings
	MDFNI_SetSettingB("psx.h_overscan", true); // Show horizontal overscan area. 1 default
	MDFNI_SetSetting("psx.region_default", "na"); // Set default region to North America if auto detect fails, default: jp

	MDFNI_SetSettingB("psx.input.analog_mode_ct", true); // Enable Analog mode toggle
		/*
		 0x0001=SELECT
		 0x0002=L3
		 0x0004=R3
		 0x0008=START
		 0x0010=D-Pad UP
		 0x0020=D-Pad Right
		 0x0040=D-Pad Down
		 0x0080=D-Pad Left
		 0x0100=L2
		 0x0200=R2
		 0x0400=L1
		 0x0800=R1
		 0x1000=△
		 0x2000=○
		 0x4000=x
		 0x8000=□
		 */
	// The buttons to press to toggle analog / digital mode (hold for couple seconds)
	uint64 amct = ((1 << PSXMap[PVPSXButtonCircle]) |
				   (1 << PSXMap[PVPSXButtonL1]) |
                   (1 << PSXMap[PVPSXButtonL2]) |
                   (1 << PSXMap[PVPSXButtonR1]) |
				   (1 << PSXMap[PVPSXButtonR2]));
	MDFNI_SetSettingUI("psx.input.analog_mode_ct.compare", amct);

	// PCE Settings
//	MDFNI_SetSetting("pce.disable_softreset", "1"); // PCE: To prevent soft resets due to accidentally hitting RUN and SEL at the same time.
//	MDFNI_SetSetting("pce.adpcmextraprec", "1"); // PCE: Enabling this option causes the MSM5205 ADPCM predictor to be outputted with full precision of 12-bits,
//												 // rather than only outputting 10-bits of precision(as an actual MSM5205 does).
//												 // Enable this option to reduce whining noise during ADPCM playback.
//    MDFNI_SetSetting("pce.slstart", "4"); // PCE: First rendered scanline 4 default
//    MDFNI_SetSetting("pce.slend", "235"); // PCE: Last rendered scanline 235 default, 239max

	// PCE_Fast settings

	MDFNI_SetSetting("pce_fast.cdspeed", "4"); // PCE: CD-ROM data transfer speed multiplier. Default is 1
	MDFNI_SetSetting("pce_fast.disable_softreset", "1"); // PCE: To prevent soft resets due to accidentally hitting RUN and SEL at the same time
//	MDFNI_SetSetting("pce_fast.slstart", "4"); // PCE: First rendered scanline
//	MDFNI_SetSetting("pce_fast.slend", "235"); // PCE: Last rendered scanline

	// PC-FX Settings
	MDFNI_SetSetting("pcfx.cdspeed", "8"); // PCFX: Emulated CD-ROM speed. Setting the value higher than 2, the default, will decrease loading times in most games by some degree.
//	MDFNI_SetSetting("pcfx.input.port1.multitap", "1"); // PCFX: EXPERIMENTAL emulation of the unreleased multitap. Enables ports 3 4 5.
	MDFNI_SetSetting("pcfx.nospritelimit", "1"); // PCFX: Remove 16-sprites-per-scanline hardware limit.
	MDFNI_SetSetting("pcfx.slstart", "4"); // PCFX: First rendered scanline 4 default
	MDFNI_SetSetting("pcfx.slend", "235"); // PCFX: Last rendered scanline 235 default, 239max

//	NSString *cfgPath = [[current BIOSPath] stringByAppendingPathComponent:@"mednafen-export.cfg"];
//	MDFN_SaveSettings(cfgPath.UTF8String);
}

- (id)init {
    if((self = [super init])) {
        _current = self;

        multiTapPlayerCount = 2;

        for(unsigned i = 0; i < 8; i++) {
            inputBuffer[i] = (uint32_t *) calloc(9, sizeof(uint32_t));
        }

		GBAMap[PVGBAButtonRight] 	= 4;
        GBAMap[PVGBAButtonLeft]     = 5;
        GBAMap[PVGBAButtonUp]       = 6;
        GBAMap[PVGBAButtonDown]     = 7;
        
        GBAMap[PVGBAButtonA]        = 0;
		GBAMap[PVGBAButtonB] 		= 1;
        
		GBAMap[PVGBAButtonSelect]	= 2;
		GBAMap[PVGBAButtonStart] 	= 3;
        
        GBAMap[PVGBAButtonR]        = 8;
		GBAMap[PVGBAButtonL] 		= 9;

		// Gameboy + Color Map
		GBMap[PVGBButtonRight] 	= 4;
        GBMap[PVGBButtonLeft]   = 5;
        GBMap[PVGBButtonUp]     = 6;
        GBMap[PVGBButtonDown]   = 7;
        
        GBMap[PVGBButtonA]      = 0;
		GBMap[PVGBButtonB] 		= 1;
		GBMap[PVGBButtonSelect]	= 2;
		GBMap[PVGBButtonStart] 	= 3;

		// SNES Map
        SNESMap[PVSNESButtonUp]           = 4;
        SNESMap[PVSNESButtonDown]         = 5;
        SNESMap[PVSNESButtonLeft]         = 6;
        SNESMap[PVSNESButtonRight]        = 7;
        
        SNESMap[PVSNESButtonA]            = 8;
        SNESMap[PVSNESButtonB]            = 0;
        SNESMap[PVSNESButtonX]            = 9;
        SNESMap[PVSNESButtonY]            = 1;
        
        SNESMap[PVSNESButtonTriggerLeft]  = 10;
        SNESMap[PVSNESButtonTriggerRight] = 11;
        
        SNESMap[PVSNESButtonSelect]       = 2;
        SNESMap[PVSNESButtonStart]        = 3;

		// PCE Map
        PCEMap[PVPCEButtonUp]       = 4;
        PCEMap[PVPCEButtonRight]    = 5;
        PCEMap[PVPCEButtonDown]     = 6;
        PCEMap[PVPCEButtonLeft]     = 7;

        PCEMap[PVPCEButtonButton1]  = 0;
        PCEMap[PVPCEButtonButton2]  = 1;
        PCEMap[PVPCEButtonButton3]  = 8;
        PCEMap[PVPCEButtonButton4]  = 9;
        PCEMap[PVPCEButtonButton5]  = 10;
        PCEMap[PVPCEButtonButton6]  = 11;

        PCEMap[PVPCEButtonSelect]   = 2;
        PCEMap[PVPCEButtonRun]      = 3;
        PCEMap[PVPCEButtonMode]     = 12;

		// PCFX Map
        PCFXMap[PVPCFXButtonUp]         = 8;
        PCFXMap[PVPCFXButtonRight]      = 9;
        PCFXMap[PVPCFXButtonDown]       = 10;
        PCFXMap[PVPCFXButtonLeft]       = 11;

        PCFXMap[PVPCFXButtonButton1]    = 0;
        PCFXMap[PVPCFXButtonButton2]    = 1;
        PCFXMap[PVPCFXButtonButton3]    = 2;
        PCFXMap[PVPCFXButtonButton4]    = 3;
        PCFXMap[PVPCFXButtonButton5]    = 4;
        PCFXMap[PVPCFXButtonButton6]    = 5;

        PCFXMap[PVPCFXButtonSelect]     = 6;
        PCFXMap[PVPCFXButtonRun]        = 7;
        PCFXMap[PVPCFXButtonMode]       = 12;
        
    }

    
    return self;
}

- (void)dealloc {
    for(unsigned i = 0; i < 8; i++) {
        free(inputBuffer[i]);
    }


    if (_current == self) {
        _current = nil;
		delete backBufferSurf;
		delete frontBufferSurf;
    }
}

# pragma mark - Execution

static void emulation_run(BOOL skipFrame) {
    GET_CURRENT_OR_RETURN();
    
    static int16_t sound_buf[0x10000];
	int32 *rects = new int32[game->fb_height]; //(int32 *)malloc(sizeof(int32) * game->fb_height);
    rects[0] = ~0;

	current->spec = {0};
    current->spec.surface = backBufferSurf;
    current->spec.SoundRate = current->sampleRate;
    current->spec.SoundBuf = sound_buf;
    current->spec.LineWidths = rects;
    current->spec.SoundBufMaxSize = sizeof(sound_buf) / 2;
	current->spec.SoundBufSize = 0;
    current->spec.SoundVolume = 1.0;
    current->spec.soundmultiplier = 1.0;
	current->spec.skip = skipFrame;

    MDFNI_Emulate(&current->spec);

    current->mednafenCoreTiming = current->masterClock / current->spec.MasterCycles;
    
    // Fix for game stutter. mednafenCoreTiming flutters on init before settling so
    // now we reset the game speed each frame to make sure current->gameInterval
    // is up to date while respecting the current game speed setting
    [current setGameSpeed:[current gameSpeed]];

    if(current->_systemType == MednaSystemPSX)
    {
        current->videoWidth = rects[current->spec.DisplayRect.y];
        current->videoOffsetX = current->spec.DisplayRect.x;
    }
    else if(game->multires)
    {
        current->videoWidth = rects[current->spec.DisplayRect.y];
        current->videoOffsetX = current->spec.DisplayRect.x;
    }
    else
    {
        current->videoWidth = current->spec.DisplayRect.w;
        current->videoOffsetX = current->spec.DisplayRect.x;
    }

    current->videoHeight = current->spec.DisplayRect.h;
    current->videoOffsetY = current->spec.DisplayRect.y;

    update_audio_batch(current->spec.SoundBuf, current->spec.SoundBufSize);

	delete[] rects;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath] withIntermediateDirectories:YES attributes:nil error:NULL];

    if([[self systemIdentifier] isEqualToString:@"com.provenance.lynx"])
    {
        self.systemType = MednaSystemLynx;
        
        mednafenCoreModule = @"lynx";
        mednafenCoreAspect = OEIntSizeMake(80, 51);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
	else if([[self systemIdentifier] isEqualToString:@"com.provenance.nes"])
	{
		self.systemType = MednaSystemNES;

		mednafenCoreModule = @"nes";
		mednafenCoreAspect = OEIntSizeMake(4, 3);
		//mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
		sampleRate         = 48000;
	}
	else if([[self systemIdentifier] isEqualToString:@"com.provenance.snes"])
	{
		self.systemType = MednaSystemSNES;

#if USE_SNES_FAUST
		mednafenCoreModule = @"snes_faust";
#else
		mednafenCoreModule = @"snes";
#endif
		mednafenCoreAspect = OEIntSizeMake(4, 3);
		//mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
		sampleRate         = 48000;
	}
	else if([[self systemIdentifier] isEqualToString:@"com.provenance.gb"] || [[self systemIdentifier] isEqualToString:@"com.provenance.gbc"])
	{
		self.systemType = MednaSystemGB;

		mednafenCoreModule = @"gb";
		mednafenCoreAspect = OEIntSizeMake(10, 9);
		//mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
		sampleRate         = 48000;
	}
	else if([[self systemIdentifier] isEqualToString:@"com.provenance.gba"])
	{
		self.systemType = MednaSystemGBA;

		mednafenCoreModule = @"gba";
		mednafenCoreAspect = OEIntSizeMake(3, 2);
		//mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
		sampleRate         = 44100;
	}
	else if([[self systemIdentifier] isEqualToString:@"com.provenance.genesis"]) // Genesis aka Megaddrive
	{
		self.systemType = MednaSystemMD;

		mednafenCoreModule = @"md";
		mednafenCoreAspect = OEIntSizeMake(4, 3);
		//mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
		sampleRate         = 48000;
	}
	else if([[self systemIdentifier] isEqualToString:@"com.provenance.mastersystem"])
	{
		self.systemType = MednaSystemSMS;

		mednafenCoreModule = @"sms";
		mednafenCoreAspect = OEIntSizeMake(256 * (8.0/7.0), 192);
//		mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
		sampleRate         = 48000;
	}
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ngp"] || [[self systemIdentifier] isEqualToString:@"com.provenance.ngpc"])
    {
        self.systemType = MednaSystemNeoGeo;
        
        mednafenCoreModule = @"ngp";
        mednafenCoreAspect = OEIntSizeMake(20, 19);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pce"] || [[self systemIdentifier] isEqualToString:@"com.provenance.pcecd"] || [[self systemIdentifier] isEqualToString:@"com.provenance.sgfx"])
    {
        self.systemType = MednaSystemPCE;

#if USE_PCE_FAST
		mednafenCoreModule = @"pce_fast";
#else
		mednafenCoreModule = @"pce";
#endif
        mednafenCoreAspect = OEIntSizeMake(256 * (8.0/7.0), 240);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pcfx"])
    {
        self.systemType = MednaSystemPCFX;
        
        mednafenCoreModule = @"pcfx";
        mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.psx"])
    {
        self.systemType = MednaSystemPSX;
        
        mednafenCoreModule = @"psx";
        // Note: OpenEMU sets this to 4:3, but it's demonstrably wrong. Tested andlooked into it myself… the other emulators got this wrong, 3:2 was close, but it's actually 10:7 - Sev
        mednafenCoreAspect = OEIntSizeMake(10, 7);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.vb"])
    {
        self.systemType = MednaSystemVirtualBoy;
        
        mednafenCoreModule = @"vb";
        mednafenCoreAspect = OEIntSizeMake(12, 7);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ws"] || [[self systemIdentifier] isEqualToString:@"com.provenance.wsc"])
    {
        self.systemType = MednaSystemWonderSwan;
        
        mednafenCoreModule = @"wswan";
        mednafenCoreAspect = OEIntSizeMake(14, 9);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else
    {
        NSLog(@"MednafenGameCore loadFileAtPath: Incorrect systemIdentifier");
        assert(false);
    }

    assert(_current);
    mednafen_init(_current);

    game = MDFNI_LoadGame([mednafenCoreModule UTF8String], [path UTF8String]);

	// Uncomment this to set the aspect ratio by the game's render size according to mednafen
	// is this correct for EU, JP, US? Still testing.
//	mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);

    if(!game) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"Mednafen failed to load game.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported Mednafen ROM format."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
        return NO;
    }
    
    // BGRA pixel format
    MDFN_PixelFormat pix_fmt(MDFN_COLORSPACE_RGB, 16, 8, 0, 24);
    backBufferSurf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
    frontBufferSurf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);

    masterClock = game->MasterClock >> 32;

    if (self.systemType == MednaSystemPCE)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
        game->SetInput(2, "gamepad", (uint8_t *)inputBuffer[2]);
        game->SetInput(3, "gamepad", (uint8_t *)inputBuffer[3]);
        game->SetInput(4, "gamepad", (uint8_t *)inputBuffer[4]);
    }
    else if (self.systemType == MednaSystemPCFX)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
    }
    else if (self.systemType == MednaSystemPSX)
    {
        for(unsigned i = 0; i < multiTapPlayerCount; i++) {
            // changing "dualshock" to "gampepad" ↓ to make games playable for now, until we can fix the analog input bugs
            game->SetInput(i, "gamepad", (uint8_t *)inputBuffer[i]);
        }
        
        // Multi-Disc check
        BOOL multiDiscGame = NO;
        NSNumber *discCount = [MednafenGameCore multiDiscPSXGames][self.romSerial];
        if (discCount) {
            self.maxDiscs = [discCount intValue];
            multiDiscGame = YES;
        }
        
        // PSX: Set multitap configuration if detected
//        NSString *serial = [self romSerial];
//        NSNumber* multitapCount = [MednafenGameCore multiDiscPSXGames][serial];
//
// FIXME:  "forget about multitap for now :)"
		// Set multitap configuration if detected
		//    if (multiTapGames[[current ROMSerial]])
		//    {
		//        current->multiTapPlayerCount = [[multiTapGames objectForKey:[current ROMSerial]] intValue];
		//
		//        if([multiTap5PlayerPort2 containsObject:[current ROMSerial]])
		//            MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
		//        else
		//        {
		//            MDFNI_SetSetting("psx.input.pport1.multitap", "1"); // Enable multitap on PSX port 1
		//            if(current->multiTapPlayerCount > 5)
		//                MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
		//        }
		//    }


//        if (multitapCount != nil)
//        {
//            multiTapPlayerCount = [multitapCount intValue];
//            
//            if([[MednafenGameCore multiTap5PlayerPort2] containsObject:serial]) {
//                MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
//            } else {
//                MDFNI_SetSetting("psx.input.pport1.multitap", "1"); // Enable multitap on PSX port 1
//                if(multiTapPlayerCount > 5) {
//                    MDFNI_SetSetting("psx.input.pport2.multitap", "1"); // Enable multitap on PSX port 2
//                }
//            }
//        }
        
        if (multiDiscGame && ![path.pathExtension.lowercaseString isEqualToString:@"m3u"]) {
            NSString *m3uPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"m3u"];
            NSRange rangeOfDocuments = [m3uPath rangeOfString:@"/Documents/" options:NSCaseInsensitiveSearch];
            if (rangeOfDocuments.location != NSNotFound) {
                m3uPath = [m3uPath substringFromIndex:rangeOfDocuments.location + 11];
            }

            NSString *message = [NSString stringWithFormat:@"This game requires multiple discs and must be loaded using a m3u file with all %lu discs.\n\nTo enable disc switching and ensure save files load across discs, it cannot be loaded as a single disc.\n\nPlease install a .m3u file with the filename %@.\nSee https://bitly.com/provm3u", self.maxDiscs, m3uPath];

            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to load game.",
                                       NSLocalizedFailureReasonErrorKey: @"Missing required m3u file.",
                                       NSLocalizedRecoverySuggestionErrorKey: message
                                       };
            
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeMissingM3U
                                                userInfo:userInfo];
            
            *error = newError;
            return NO;
        }
        
        if (self.maxDiscs > 1) {
            // Parse number of discs in m3u
            NSString *m3uString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".cue|.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, [m3uString length])];
            
            NSLog(@"Loaded m3u containing %lu cue sheets or ccd",numberOfMatches);
        }
    }
    else
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
    }

    MDFNI_SetMedia(0, 2, 0, 0); // Disc selection API

    emulation_run(NO);

    return YES;
}

-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc {
    MDFNI_SetMedia(0, open ? 0 : 2, (uint32) disc, 0);
}

-(NSUInteger)maxNumberPlayers {
    NSUInteger maxPlayers = 2;
    switch (self.systemType) {
        case MednaSystemPSX:
            maxPlayers = multiTapPlayerCount;
            break;
        case MednaSystemPCE:
            maxPlayers = 5;
            break;
		case MednaSystemMD:
		case MednaSystemSMS:
		case MednaSystemNES:
		case MednaSystemSNES:
        case MednaSystemPCFX:
            maxPlayers = 2;
            break;
		case MednaSystemGB:
		case MednaSystemGBA:
        case MednaSystemNeoGeo:
        case MednaSystemLynx:
        case MednaSystemVirtualBoy:
		case MednaSystemGG:
        case MednaSystemWonderSwan:
            maxPlayers = 1;
            break;
	}
    
    return maxPlayers;
}

- (void)pollControllers {
    unsigned maxValue = 0;
	const int*map = nullptr;
    switch (self.systemType) {
		case MednaSystemGBA:
			maxValue = PVGBAButtonCount;
			map = GBAMap;
			break;
		case MednaSystemGB:
			maxValue = PVGBButtonCount;
			map = GBMap;
			break;
        case MednaSystemPSX:
            maxValue = PVPSXButtonCount;
            map = PSXMap;
            break;
        case MednaSystemNeoGeo:
            maxValue = PVNGPButtonCount;
            map = NeoMap;
            break;
        case MednaSystemLynx:
            maxValue = PVLynxButtonCount;
            map = LynxMap;
            break;
		case MednaSystemSNES:
			maxValue = PVSNESButtonCount;
			map = SNESMap;
			break;
		case MednaSystemNES:
			maxValue = PVNESButtonCount;
			map = NESMap;
			break;
        case MednaSystemPCE:
            maxValue = PVPCEButtonCount;
            map = PCEMap;
            break;
        case MednaSystemPCFX:
            maxValue = PVPCFXButtonCount;
            map = PCFXMap;
            break;
        case MednaSystemVirtualBoy:
            maxValue = PVVBButtonCount;
            map = VBMap;
            break;
        case MednaSystemWonderSwan:
            maxValue = PVWSButtonCount;
            map = WSMap;
            break;
		case MednaSystemGG:
			return;
			break;
		case MednaSystemMD:
			return;
			break;
		case MednaSystemSMS:
			return;
			break;
	}
    
    NSUInteger maxNumberPlayers = MIN([self maxNumberPlayers], 4);

    for (NSInteger playerIndex = 0; playerIndex < maxNumberPlayers; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        else if (self.controller3 && playerIndex == 3)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 4)
        {
            controller = self.controller4;
        }
        
        if (controller) {
            for (unsigned i=0; i<maxValue; i++) {

				if (self.systemType != MednaSystemPSX || i < PVPSXButtonLeftAnalogUp) {
                    uint32_t value = (uint32_t)[self controllerValueForButtonID:i forPlayer:playerIndex];
                    
                    if(value > 0) {
                        inputBuffer[playerIndex][0] |= 1 << map[i];
                    } else {
                        inputBuffer[playerIndex][0] &= ~(1 << map[i]);
                    }
                } else {
                    float analogValue = [self PSXAnalogControllerValueForButtonID:i forController:controller];
                    [self didMovePSXJoystickDirection:(PVPSXButton)i
                                            withValue:analogValue
                                            forPlayer:playerIndex];
                }
            }
        }
    }
}

- (void)executeFrameSkippingFrame: (BOOL) skip
{
	// Should we be using controller callbacks instead?
	if (!skip && (self.controller1 || self.controller2 || self.controller3 || self.controller4)) {
		[self pollControllers];
	}

	emulation_run(skip);
}

- (void)executeFrame
{
	[self executeFrameSkippingFrame:NO];
}

- (void)resetEmulation
{
    MDFNI_Reset();
}

- (void)stopEmulation
{
    MDFNI_CloseGame();
    MDFNI_Kill();
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return mednafenCoreTiming ?: 59.92;
}

# pragma mark - Video

- (CGRect)screenRect
{
    return CGRectMake(videoOffsetX, videoOffsetY, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
    if ( game == NULL )
    {
        return CGSizeMake(0, 0);
    }
    else
    {
        return CGSizeMake(game->fb_width, game->fb_height);
    }
}

- (CGSize)aspectSize
{
    return CGSizeMake(mednafenCoreAspect.width,mednafenCoreAspect.height);
}

- (const void *)videoBuffer
{
    if ( frontBufferSurf == NULL )
    {
        return NULL;
    }
    else
    {
        return frontBufferSurf->pixels;
    }
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

- (BOOL)isDoubleBuffered {
    return YES;
}

- (void)swapBuffers
{
    MDFN_Surface *tempSurf = backBufferSurf;
    backBufferSurf = frontBufferSurf;
    frontBufferSurf = tempSurf;
}

# pragma mark - Audio

static size_t update_audio_batch(const int16_t *data, size_t frames)
{
    GET_CURRENT_OR_RETURN(frames);

    [[current ringBufferAtIndex:0] write:data maxLength:frames * [current channelCount] * 2];
    return frames;
}

- (double)audioSampleRate
{
    return sampleRate ? sampleRate : 48000;
}

- (NSUInteger)channelCount
{
    return game->soundchan;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
	if (game != nil ) {
		BOOL success = MDFNI_SaveState(fileName.fileSystemRepresentation, "", NULL, NULL, NULL);
		if (!success) {
			NSDictionary *userInfo = @{
									   NSLocalizedDescriptionKey: @"Failed to save state.",
									   NSLocalizedFailureReasonErrorKey: @"Core failed to create save state.",
									   NSLocalizedRecoverySuggestionErrorKey: @""
									   };

			NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
													code:PVEmulatorCoreErrorCodeCouldNotSaveState
												userInfo:userInfo];

			*error = newError;
		}
		return success;
	} else {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to save state.",
								   NSLocalizedFailureReasonErrorKey: @"Core failed to create save state because no game is loaded.",
								   NSLocalizedRecoverySuggestionErrorKey: @""
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotSaveState
											userInfo:userInfo];

		*error = newError;

		return NO;
	}
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error   {
	if (game != nil ) {
    	BOOL success = MDFNI_LoadState(fileName.fileSystemRepresentation, "");
		if (!success) {
			NSDictionary *userInfo = @{
									   NSLocalizedDescriptionKey: @"Failed to save state.",
									   NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
									   NSLocalizedRecoverySuggestionErrorKey: @""
									   };

			NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
													code:PVEmulatorCoreErrorCodeCouldNotLoadState
												userInfo:userInfo];

			*error = newError;
		}
		return success;
	} else {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to save state.",
								   NSLocalizedFailureReasonErrorKey: @"No game loaded.",
								   NSLocalizedRecoverySuggestionErrorKey: @""
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotLoadState
											userInfo:userInfo];

		*error = newError;

		return NO;
	}
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
    MemoryStream stream(65536, false);
    MDFNSS_SaveSM(&stream, true);
    size_t length = stream.map_size();
    void *bytes = stream.map();

    if(length) {
        return [NSData dataWithBytes:bytes length:length];
    }
    
    if(outError) {
        assert(false);
		// TODO: "fix error log"
//        *outError = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotSaveStateError  userInfo:@{
//            NSLocalizedDescriptionKey : @"Save state data could not be written",
//            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
//        }];
    }

    return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError {
    NSError *error;
    const void *bytes = [state bytes];
    size_t length = [state length];

    MemoryStream stream(length, -1);
    memcpy(stream.map(), bytes, length);
    MDFNSS_LoadSM(&stream, true);
    size_t serialSize = stream.map_size();

    if(serialSize != length)
    {
		// TODO: "fix error log"
//        error = [NSError errorWithDomain:OEGameCoreErrorDomain
//                                    code:OEGameCoreStateHasWrongSizeError
//                                userInfo:@{
//                                           NSLocalizedDescriptionKey : @"Save state has wrong file size.",
//                                           NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the save state does not have the right size, %lu expected, got: %ld.", serialSize, [state length]],
//                                        }];
    }

    if(error) {
        if(outError) {
            *outError = error;
        }
        return false;
    } else {
        return true;
    }
}

# pragma mark - Input -

#pragma mark Atari Lynx
- (void)didPushLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] |= 1 << LynxMap[button];
}

- (void)didReleaseLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] &= ~(1 << LynxMap[button]);
}

- (NSInteger)LynxControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVLynxButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case PVLynxButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case PVLynxButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case PVLynxButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case PVLynxButtonA:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVLynxButtonB:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVLynxButtonOption1:
                return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed];
            case PVLynxButtonOption2:
                return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVLynxButtonUp:
                return [[dpad up] isPressed];
            case PVLynxButtonDown:
                return [[dpad down] isPressed];
            case PVLynxButtonLeft:
                return [[dpad left] isPressed];
            case PVLynxButtonRight:
                return [[dpad right] isPressed];
            case PVLynxButtonA:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVLynxButtonB:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVLynxButtonOption1:
                return [[pad leftShoulder] isPressed];
            case PVLynxButtonOption2:
                return [[pad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad]) {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVLynxButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVLynxButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVLynxButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVLynxButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVLynxButtonB:
                return [[pad buttonA] isPressed];
                break;
            case PVLynxButtonA:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

#pragma mark SNES
- (void)didPushSNESButton:(enum PVSNESButton)button forPlayer:(NSInteger)player {
	int mappedButton = SNESMap[button];
	inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseSNESButton:(enum PVSNESButton)button forPlayer:(NSInteger)player {
	inputBuffer[player][0] &= ~(1 << SNESMap[button]);
}

#pragma mark NES
- (void)didPushNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
	int mappedButton = NESMap[button];
	inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
	inputBuffer[player][0] &= ~(1 << NESMap[button]);
}

#pragma mark GB / GBC
- (void)didPushGBButton:(enum PVGBButton)button forPlayer:(NSInteger)player {
	int mappedButton = GBMap[button];
	inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseGBButton:(enum PVGBButton)button forPlayer:(NSInteger)player {
	inputBuffer[player][0] &= ~(1 << GBMap[button]);
}

#pragma mark GBA
- (void)didPushGBAButton:(enum PVGBAButton)button forPlayer:(NSInteger)player {
	int mappedButton = GBAMap[button];
	inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseGBAButton:(enum PVGBAButton)button forPlayer:(NSInteger)player {
	int mappedButton = GBAMap[button];
	inputBuffer[player][0] &= ~(1 << mappedButton);
}

#pragma mark Sega
- (void)didPushSegaButton:(enum PVGenesisButton)button forPlayer:(NSInteger)player {
	int mappedButton = GenesisMap[button];
	inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseSegaButton:(enum PVGenesisButton)button forPlayer:(NSInteger)player {
	inputBuffer[player][0] &= ~(1 << GenesisMap[button]);
}

#pragma mark Neo Geo
- (void)didPushNGPButton:(PVNGPButton)button forPlayer:(NSInteger)player
{
    inputBuffer[player][0] |= 1 << NeoMap[button];
}

- (void)didReleaseNGPButton:(PVNGPButton)button forPlayer:(NSInteger)player
{
    inputBuffer[player][0] &= ~(1 << NeoMap[button]);
}

#pragma mark PC-*
#pragma mark PCE aka TurboGFX-16 & SuperGFX
- (void)didPushPCEButton:(PVPCEButton)button forPlayer:(NSInteger)player
{
    if (button != PVPCEButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (void)didReleasePCEButton:(PVPCEButton)button forPlayer:(NSInteger)player
{
    if (button != PVPCEButtonMode)
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
}

#pragma mark PCE-CD
- (void)didPushPCECDButton:(PVPCECDButton)button forPlayer:(NSInteger)player
{
    if (button != PVPCECDButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (void)didReleasePCECDButton:(PVPCECDButton)button forPlayer:(NSInteger)player;
{
    if (button != PVPCECDButtonMode) {
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
    }
}

#pragma mark PCFX
- (void)didPushPCFXButton:(PVPCFXButton)button forPlayer:(NSInteger)player;
{
	if (button != PVPCFXButtonMode) { // Check for six button mode toggle
		inputBuffer[player][0] |= 1 << PCFXMap[button];
	} else {
		inputBuffer[player][0] ^= 1 << PCFXMap[button];
	}
}

- (void)didReleasePCFXButton:(PVPCFXButton)button forPlayer:(NSInteger)player;
{
	if (button != PVPCFXButtonMode) {
    	inputBuffer[player][0] &= ~(1 << PCFXMap[button]);
	}
}

#pragma mark PSX
- (void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
{
    if (button == PVPSXButtonStart) {
        self.isStartPressed = true;
    } else if (button == PVPSXButtonSelect) {
        self.isSelectPressed = true;
    }
    inputBuffer[player][0] |= 1 << PSXMap[button];
}

- (void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
{
    if (button == PVPSXButtonStart) {
        self.isStartPressed = false;
    } else if (button == PVPSXButtonSelect) {
        self.isSelectPressed = false;
    }
    inputBuffer[player][0] &= ~(1 << PSXMap[button]);
}

- (void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player
{
    // Fix the analog circle-to-square axis range conversion by scaling between a value of 1.00 and 1.50
    // We cannot use MDFNI_SetSetting("psx.input.port1.dualshock.axis_scale", "1.33") directly.
    // Background: https://mednafen.github.io/documentation/psx.html#Section_analog_range
    value *= 32767; // de-normalize
    double scaledValue = MIN(floor(0.5 + value * 1.33), 32767); // 30712 / cos(2*pi/8) / 32767 = 1.33
    
    int analogNumber = PSXMap[button] - 17;
    uint8_t *buf = (uint8_t *)inputBuffer[player];
    MDFN_en16lsb(&buf[3 + analogNumber * 2], scaledValue);
    MDFN_en16lsb(&buf[3 + (analogNumber ^ 1) * 2], 0);
}

#pragma mark Virtual Boy
- (void)didPushVBButton:(PVVBButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] |= 1 << VBMap[button];
}

- (void)didReleaseVBButton:(PVVBButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] &= ~(1 << VBMap[button]);
}

#pragma mark WonderSwan
- (void)didPushWSButton:(PVWSButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] |= 1 << WSMap[button];
}

- (void)didReleaseWSButton:(PVWSButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] &= ~(1 << WSMap[button]);
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player {
    GCController *controller = nil;
    
    if (player == 0) {
        controller = self.controller1;
    }
    else if (player == 1) {
        controller = self.controller2;
    }
    else if (player == 2) {
        controller = self.controller3;
    }
    else if (player == 3) {
        controller = self.controller4;
    }
        
	switch (self.systemType) {
		case MednaSystemSMS:
		case MednaSystemMD:
			// TODO: Unused since Mednafen sega support is 'low priority'
			return 0;
			break;
		case MednaSystemGB:
			return [self GBValueForButtonID:buttonID forController:controller];
			break;
		case MednaSystemGBA:
			return [self GBAValueForButtonID:buttonID forController:controller];
			break;
		case MednaSystemSNES:
			return [self SNESValueForButtonID:buttonID forController:controller];
			break;
		case MednaSystemNES:
			return [self NESValueForButtonID:buttonID forController:controller];
			break;
        case MednaSystemNeoGeo:
            return [self NeoGeoValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemLynx:
            return [self LynxControllerValueForButtonID:buttonID forController:controller];
            break;

        case MednaSystemPCE:
        case MednaSystemPCFX:
            return [self PCEValueForButtonID:buttonID forController:controller];
            break;

        case MednaSystemPSX:
            return [self PSXcontrollerValueForButtonID:buttonID forController:controller];
            break;

        case MednaSystemVirtualBoy:
            return [self VirtualBoyControllerValueForButtonID:buttonID forController:controller];
            break;

        case MednaSystemWonderSwan:
            return [self WonderSwanControllerValueForButtonID:buttonID forController:controller];
            break;
            
        default:
            break;
    }

    return 0;
}

- (NSInteger)GBValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
	if ([controller extendedGamepad]) {
		GCExtendedGamepad *pad = [controller extendedGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVGBButtonUp:
				return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
			case PVGBButtonDown:
				return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
			case PVGBButtonLeft:
				return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
			case PVGBButtonRight:
				return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
			case PVGBButtonB:
				return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
			case PVGBButtonA:
				return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
			case PVGBButtonSelect:
				return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed];
			case PVGBButtonStart:
				return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
			default:
				NSLog(@"Unknown button %i", buttonID);
				break;
		}

//		if (buttonID == GBMap[PVGBButtonUp]) {
//			return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonDown]) {
//			return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonLeft]) {
//			return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonRight]) {
//			return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonA]) {
//			return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonB]) {
//			return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonSelect]) {
//			return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed];
//		}
//		else if (buttonID == GBMap[PVGBButtonStart]) {
//			return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
//		}
	} else if ([controller gamepad]) {
		GCGamepad *pad = [controller gamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVGBButtonUp:
				return [[dpad up] isPressed];
			case PVGBButtonDown:
				return [[dpad down] isPressed];
			case PVGBButtonLeft:
				return [[dpad left] isPressed];
			case PVGBButtonRight:
				return [[dpad right] isPressed];
			case PVGBButtonB:
				return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
			case PVGBButtonA:
				return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
			case PVGBButtonSelect:
				return [[pad leftShoulder] isPressed];
			case PVGBButtonStart:
				return [[pad rightShoulder] isPressed];
			default:
				break;
		}
	}
#if TARGET_OS_TV
	else if ([controller microGamepad])
	{
		GCMicroGamepad *pad = [controller microGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVGBButtonUp:
				return [[dpad up] value] > 0.5;
				break;
			case PVGBButtonDown:
				return [[dpad down] value] > 0.5;
				break;
			case PVGBButtonLeft:
				return [[dpad left] value] > 0.5;
				break;
			case PVGBButtonRight:
				return [[dpad right] value] > 0.5;
				break;
			case PVGBButtonA:
				return [[pad buttonX] isPressed];
				break;
			case PVGBButtonB:
				return [[pad buttonA] isPressed];
				break;
			default:
				break;
		}
	}
#endif
	return 0;
}

- (NSInteger)GBAValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
	if ([controller extendedGamepad]) {
		GCExtendedGamepad *pad = [controller extendedGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVGBAButtonUp:
				return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
			case PVGBAButtonDown:
				return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
			case PVGBAButtonLeft:
				return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
			case PVGBAButtonRight:
				return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
			case PVGBAButtonB:
				return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
			case PVGBAButtonA:
				return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
			case PVGBAButtonL:
				return [[pad leftShoulder] isPressed];
			case PVGBAButtonR:
				return [[pad rightShoulder] isPressed];
			case PVGBAButtonSelect:
				return [[pad leftTrigger] isPressed];
			case PVGBAButtonStart:
				return [[pad rightTrigger] isPressed];
			default:
				break;
		}
	} else if ([controller gamepad]) {
		GCGamepad *pad = [controller gamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVGBAButtonUp:
				return [[dpad up] isPressed];
			case PVGBAButtonDown:
				return [[dpad down] isPressed];
			case PVGBAButtonLeft:
				return [[dpad left] isPressed];
			case PVGBAButtonRight:
				return [[dpad right] isPressed];
			case PVGBAButtonB:
				return [[pad buttonA] isPressed];
			case PVGBAButtonA:
				return [[pad buttonB] isPressed];
			case PVGBAButtonL:
				return [[pad leftShoulder] isPressed];
			case PVGBAButtonR:
				return [[pad rightShoulder] isPressed];
			case PVGBAButtonSelect:
				return [[pad buttonX] isPressed];
			case PVGBAButtonStart:
				return [[pad buttonY] isPressed];
			default:
				break;
		}
	}
#if TARGET_OS_TV
	else if ([controller microGamepad])
	{
		GCMicroGamepad *pad = [controller microGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVGBAButtonUp:
				return [[dpad up] value] > 0.5;
				break;
			case PVGBAButtonDown:
				return [[dpad down] value] > 0.5;
				break;
			case PVGBAButtonLeft:
				return [[dpad left] value] > 0.5;
				break;
			case PVGBAButtonRight:
				return [[dpad right] value] > 0.5;
				break;
			case PVGBAButtonA:
				return [[pad buttonX] isPressed];
				break;
			case PVGBAButtonB:
				return [[pad buttonA] isPressed];
				break;
			default:
				break;
		}
	}
#endif
	return 0;
}

- (NSInteger)SNESValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
	if ([controller extendedGamepad]) {
		GCExtendedGamepad *pad = [controller extendedGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVSNESButtonUp:
				return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
			case PVSNESButtonDown:
				return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
			case PVSNESButtonLeft:
				return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
			case PVSNESButtonRight:
				return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
			case PVSNESButtonB:
				return [[pad buttonA] isPressed];
			case PVSNESButtonA:
				return [[pad buttonB] isPressed];
			case PVSNESButtonX:
				return [[pad buttonY] isPressed];
			case PVSNESButtonY:
				return [[pad buttonX] isPressed];
			case PVSNESButtonTriggerLeft:
				return [[pad leftShoulder] isPressed];
			case PVSNESButtonTriggerRight:
				return [[pad rightShoulder] isPressed];
			case PVSNESButtonSelect:
				return [[pad leftTrigger] isPressed];
			case PVSNESButtonStart:
				return [[pad rightTrigger] isPressed];
			default:
				break;
		}
	} else if ([controller gamepad]) {
		GCGamepad *pad = [controller gamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVSNESButtonUp:
				return [[dpad up] isPressed];
			case PVSNESButtonDown:
				return [[dpad down] isPressed];
			case PVSNESButtonLeft:
				return [[dpad left] isPressed];
			case PVSNESButtonRight:
				return [[dpad right] isPressed];
			case PVSNESButtonB:
				return [[pad buttonA] isPressed];
			case PVSNESButtonA:
				return [[pad buttonB] isPressed];
			case PVSNESButtonX:
				return [[pad buttonY] isPressed];
			case PVSNESButtonY:
				return [[pad buttonX] isPressed];
			case PVSNESButtonTriggerLeft:
				return [[pad leftShoulder] isPressed];
			case PVSNESButtonTriggerRight:
				return [[pad rightShoulder] isPressed];
			default:
				break;
		}
	}
#if TARGET_OS_TV
	else if ([controller microGamepad])
	{
		GCMicroGamepad *pad = [controller microGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVSNESButtonUp:
				return [[dpad up] value] > 0.5;
				break;
			case PVSNESButtonDown:
				return [[dpad down] value] > 0.5;
				break;
			case PVSNESButtonLeft:
				return [[dpad left] value] > 0.5;
				break;
			case PVSNESButtonRight:
				return [[dpad right] value] > 0.5;
				break;
			case PVSNESButtonA:
				return [[pad buttonX] isPressed];
				break;
			case PVSNESButtonB:
				return [[pad buttonA] isPressed];
				break;
			default:
				break;
		}
	}
#endif
	return 0;
}

- (NSInteger)NESValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
	if ([controller extendedGamepad]) {
		GCExtendedGamepad *pad = [controller extendedGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVNESButtonUp:
				return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
			case PVNESButtonDown:
				return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
			case PVNESButtonLeft:
				return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
			case PVNESButtonRight:
				return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
			case PVNESButtonB:
				return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
			case PVNESButtonA:
				return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
			case PVNESButtonSelect:
				return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed];
			case PVNESButtonStart:
				return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
			default:
				break;
		}
	} else if ([controller gamepad]) {
		GCGamepad *pad = [controller gamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVNESButtonUp:
				return [[dpad up] isPressed];
			case PVNESButtonDown:
				return [[dpad down] isPressed];
			case PVNESButtonLeft:
				return [[dpad left] isPressed];
			case PVNESButtonRight:
				return [[dpad right] isPressed];
			case PVNESButtonB:
				return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
			case PVNESButtonA:
				return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
			case PVNESButtonSelect:
				return [[pad leftShoulder] isPressed];
			case PVNESButtonStart:
				return [[pad rightShoulder] isPressed];
			default:
				break;
		}
	}
#if TARGET_OS_TV
	else if ([controller microGamepad])
	{
		GCMicroGamepad *pad = [controller microGamepad];
		GCControllerDirectionPad *dpad = [pad dpad];
		switch (buttonID) {
			case PVNESButtonUp:
				return [[dpad up] value] > 0.5;
				break;
			case PVNESButtonDown:
				return [[dpad down] value] > 0.5;
				break;
			case PVNESButtonLeft:
				return [[dpad left] value] > 0.5;
				break;
			case PVNESButtonRight:
				return [[dpad right] value] > 0.5;
				break;
			case PVNESButtonA:
				return [[pad buttonX] isPressed];
				break;
			case PVNESButtonB:
				return [[pad buttonA] isPressed];
				break;
			default:
				break;
		}
	}
#endif
	return 0;
}

- (NSInteger)NeoGeoValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVNGPButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case PVNGPButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case PVNGPButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case PVNGPButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case PVNGPButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVNGPButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVNGPButtonOption:
                return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed] ?: [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVNGPButtonUp:
                return [[dpad up] isPressed];
            case PVNGPButtonDown:
                return [[dpad down] isPressed];
            case PVNGPButtonLeft:
                return [[dpad left] isPressed];
            case PVNGPButtonRight:
                return [[dpad right] isPressed];
            case PVNGPButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVNGPButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVNGPButtonOption:
                return [[pad leftShoulder] isPressed] ?: [[pad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVNGPButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVNGPButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVNGPButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVNGPButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVNGPButtonA:
                return [[pad buttonA] isPressed];
                break;
            case PVNGPButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (NSInteger)PCEValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamePad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
				// D-Pad
			case PVPCEButtonUp:
                return [[dpad up] isPressed]?:[[[gamePad leftThumbstick] up] value] > 0.1;
            case PVPCEButtonDown:
                return [[dpad down] isPressed]?:[[[gamePad leftThumbstick] down] value] > 0.1;
            case PVPCEButtonLeft:
                return [[dpad left] isPressed]?:[[[gamePad leftThumbstick] left] value] > 0.1;
            case PVPCEButtonRight:
                return [[dpad right] isPressed]?:[[[gamePad leftThumbstick] right] value] > 0.1;

				// Standard Buttons
			case PVPCEButtonButton1:
				return [[gamePad buttonB] isPressed];
			case PVPCEButtonButton2:
				return [[gamePad buttonA] isPressed];

			case PVPCEButtonSelect:
				return [[gamePad leftTrigger] isPressed];
			case PVPCEButtonRun:
				return [[gamePad rightTrigger] isPressed];

				// Extended Buttons
			case PVPCEButtonButton3:
                return [[gamePad buttonX] isPressed];
            case PVPCEButtonButton4:
                return [[gamePad leftShoulder] isPressed];
            case PVPCEButtonButton5:
                return [[gamePad buttonY] isPressed];
            case PVPCEButtonButton6:
                return [[gamePad rightShoulder] isPressed];

                // Toggle the Mode: Extended Buttons are pressed
            case PVPCEButtonMode:
                return [[gamePad buttonX] isPressed] || [[gamePad leftShoulder] isPressed] || [[gamePad buttonY] isPressed] || [[gamePad rightShoulder] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamePad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
                // D-Pad
            case PVPCEButtonUp:
                return [[dpad up] isPressed];
            case PVPCEButtonDown:
                return [[dpad down] isPressed];
            case PVPCEButtonLeft:
                return [[dpad left] isPressed];
            case PVPCEButtonRight:
                return [[dpad right] isPressed];
                
				// Standard Buttons
			case PVPCEButtonButton1:
				return [[gamePad buttonB] isPressed];
			case PVPCEButtonButton2:
				return [[gamePad buttonA] isPressed];

			case PVPCEButtonSelect:
				return [[gamePad leftShoulder] isPressed];
			case PVPCEButtonRun:
				return [[gamePad rightShoulder] isPressed];

				// Extended Buttons
            case PVPCEButtonButton3:
                return [[gamePad buttonX] isPressed];
            case PVPCEButtonButton4:
                return [[gamePad buttonY] isPressed];

                // Toggle the Mode: Extended Buttons are pressed
			case PVPCEButtonMode:
				return [[gamePad buttonX] isPressed] || [[gamePad buttonY] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamePad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case PVPCEButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVPCEButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVPCEButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVPCEButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVPCEButtonButton1:
                return [[gamePad buttonA] isPressed];
                break;
            case PVPCEButtonButton2:
                return [[gamePad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    
    return 0;
}

- (float)PSXAnalogControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        switch (buttonID) {
            case PVPSXButtonLeftAnalogUp:
                return [pad leftThumbstick].up.value;
            case PVPSXButtonLeftAnalogDown:
                return [pad leftThumbstick].down.value;
            case PVPSXButtonLeftAnalogLeft:
                return [pad leftThumbstick].left.value;
            case PVPSXButtonLeftAnalogRight:
                return [pad leftThumbstick].right.value;
            case PVPSXButtonRightAnalogUp:
                return [pad rightThumbstick].up.value;
            case PVPSXButtonRightAnalogDown:
                return [pad rightThumbstick].down.value;
            case PVPSXButtonRightAnalogLeft:
                return [pad rightThumbstick].left.value;
            case PVPSXButtonRightAnalogRight:
                return [pad rightThumbstick].right.value;
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        switch (buttonID) {
            case PVPSXButtonLeftAnalogUp:
                return [pad dpad].up.value;
            case PVPSXButtonLeftAnalogDown:
                return [pad dpad].down.value;
            case PVPSXButtonLeftAnalogLeft:
                return [pad dpad].left.value;
            case PVPSXButtonLeftAnalogRight:
                return [pad dpad].right.value;
            default:
                break;
        }
    }
    return 0;
}

- (NSInteger)PSXcontrollerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] isPressed];
            case PVPSXButtonDown:
                return [[dpad down] isPressed];
            case PVPSXButtonLeft:
                return [[dpad left] isPressed];
            case PVPSXButtonRight:
                return [[dpad right] isPressed];
            case PVPSXButtonLeftAnalogUp:
                return [pad leftThumbstick].up.value;
            case PVPSXButtonLeftAnalogDown:
                return [pad leftThumbstick].down.value;
            case PVPSXButtonLeftAnalogLeft:
                return [pad leftThumbstick].left.value;
            case PVPSXButtonLeftAnalogRight:
                return [pad leftThumbstick].right.value;
            case PVPSXButtonSquare:
                return [[pad buttonX] isPressed];
            case PVPSXButtonCross:
                return [[pad buttonA] isPressed];
            case PVPSXButtonCircle:
                return [[pad buttonB] isPressed];
            case PVPSXButtonL1:
                return [[pad leftShoulder] isPressed];
            case PVPSXButtonTriangle:
                return [[pad buttonY] isPressed];
            case PVPSXButtonR1:
                return [[pad rightShoulder] isPressed];
            case PVPSXButtonL2:
                return [[pad leftTrigger] isPressed];
            case PVPSXButtonR2:
                return [[pad rightTrigger] isPressed];
			case PVPSXButtonStart:
				return self.isStartPressed;
			case PVPSXButtonSelect:
				return self.isSelectPressed;
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] isPressed];
            case PVPSXButtonDown:
                return [[dpad down] isPressed];
            case PVPSXButtonLeft:
                return [[dpad left] isPressed];
            case PVPSXButtonRight:
                return [[dpad right] isPressed];
            case PVPSXButtonSquare:
                return [[pad buttonX] isPressed];
            case PVPSXButtonCross:
                return [[pad buttonA] isPressed];
            case PVPSXButtonCircle:
                return [[pad buttonB] isPressed];
            case PVPSXButtonL1:
                return [[pad leftShoulder] isPressed];
            case PVPSXButtonTriangle:
                return [[pad buttonY] isPressed];
            case PVPSXButtonR1:
                return [[pad rightShoulder] isPressed];
            case PVPSXButtonStart:
                return self.isStartPressed;
            case PVPSXButtonSelect:
                return self.isSelectPressed;
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVPSXButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVPSXButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVPSXButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVPSXButtonCross:
                return [[pad buttonA] isPressed];
                break;
            case PVPSXButtonCircle:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (NSInteger)VirtualBoyControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVVBButtonLeftUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case PVVBButtonLeftDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case PVVBButtonLeftLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case PVVBButtonLeftRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case PVVBButtonRightUp:
                return [[[pad rightThumbstick] up] isPressed];
            case PVVBButtonRightDown:
                return [[[pad rightThumbstick] down] isPressed];
            case PVVBButtonRightLeft:
                return [[[pad rightThumbstick] left] isPressed];
            case PVVBButtonRightRight:
                return [[[pad rightThumbstick] right] isPressed];
            case PVVBButtonA:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVVBButtonB:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVVBButtonL:
                return [[pad leftShoulder] isPressed];
            case PVVBButtonR:
                return [[pad rightShoulder] isPressed];
            case PVVBButtonStart:
                return [[pad rightTrigger] isPressed];
            case PVVBButtonSelect:
                return [[pad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVVBButtonLeftUp:
                return [[dpad up] isPressed];
            case PVVBButtonLeftDown:
                return [[dpad down] isPressed];
            case PVVBButtonLeftLeft:
                return [[dpad left] isPressed];
            case PVVBButtonLeftRight:
                return [[dpad right] isPressed];
            case PVVBButtonA:
                return [[pad buttonB] isPressed];
            case PVVBButtonB:
                return [[pad buttonA] isPressed];
            case PVVBButtonL:
                return [[pad leftShoulder] isPressed];
            case PVVBButtonR:
                return [[pad rightShoulder] isPressed];
            case PVVBButtonStart:
                return [[pad buttonY] isPressed];
            case PVVBButtonSelect:
                return [[pad buttonX] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVVBButtonLeftUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVVBButtonLeftDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVVBButtonLeftLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVVBButtonLeftRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVVBButtonA:
                return [[pad buttonA] isPressed];
                break;
            case PVVBButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (NSInteger)WonderSwanControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
                /* WonderSwan has a Top (Y) D-Pad and a lower (X) D-Pad. MFi controllers
                 may have the Joy Stick and Left D-Pad in either Top/Bottom configuration.
                 Another Option is to map to Left/Right Joystick and Make left D-Pad same as
                 left JoyStick, but if the games require using Left/Right hand at same time it
                 may be difficult to his the right d-pad and action buttons at the same time.
                 -joe M */
            case PVWSButtonX1:
                return [[[pad leftThumbstick] up] isPressed];
            case PVWSButtonX3:
                return [[[pad leftThumbstick] down] isPressed];
            case PVWSButtonX4:
                return [[[pad leftThumbstick] left] isPressed];
            case PVWSButtonX2:
                return [[[pad leftThumbstick] right] isPressed];
            case PVWSButtonY1:
                return [[dpad up] isPressed];
            case PVWSButtonY3:
                return [[dpad down] isPressed];
            case PVWSButtonY4:
                return [[dpad left] isPressed];
            case PVWSButtonY2:
                return [[dpad right] isPressed];
            case PVWSButtonA:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVWSButtonB:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVWSButtonStart:
                return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            case PVWSButtonSound:
                return [[pad leftShoulder] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVWSButtonX1:
                return [[dpad up] isPressed];
            case PVWSButtonX3:
                return [[dpad down] isPressed];
            case PVWSButtonX4:
                return [[dpad left] isPressed];
            case PVWSButtonX2:
                return [[dpad right] isPressed];
            case PVWSButtonA:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case PVWSButtonB:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case PVWSButtonStart:
                return [[pad rightShoulder] isPressed];
            case PVWSButtonSound:
                return [[pad leftShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVWSButtonX1:
                return [[dpad up] value] > 0.5;
                break;
            case PVWSButtonX3:
                return [[dpad down] value] > 0.5;
                break;
            case PVWSButtonX4:
                return [[dpad left] value] > 0.5;
                break;
            case PVWSButtonX2:
                return [[dpad right] value] > 0.5;
                break;
            case PVWSButtonA:
                return [[pad buttonA] isPressed];
                break;
            case PVWSButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

- (void)changeDisplayMode
{
    if (self.systemType == MednaSystemVirtualBoy)
    {
        switch (MDFN_IEN_VB::mednafenCurrentDisplayMode)
        {
            case 0: // (2D) red/black
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x000000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(true);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 1: // (2D) white/black
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFFFFFF, 0x000000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(true);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 2: // (2D) purple/black
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF00FF, 0x000000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(true);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 3: // (3D) red/blue
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x0000FF);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 4: // (3D) red/cyan
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00B7EB);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 5: // (3D) red/electric cyan
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00FFFF);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 6: // (3D) red/green
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFF0000, 0x00FF00);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 7: // (3D) green/red
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0x00FF00, 0xFF0000);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode++;
                break;

            case 8: // (3D) yellow/blue
                MDFN_IEN_VB::VIP_SetAnaglyphColors(0xFFFF00, 0x0000FF);
                MDFN_IEN_VB::VIP_SetParallaxDisable(false);
                MDFN_IEN_VB::mednafenCurrentDisplayMode = 0;
                break;

            default:
                return;
                break;
        }
    }
}

//- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
//
//}
//
//- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
//
//}
//
//- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
//
//}

@end

// -- Sanity checks
static_assert(sizeof(uint8) == 1, "unexpected size");
static_assert(sizeof(int8) == 1, "unexpected size");

static_assert(sizeof(uint16) == 2, "unexpected size");
static_assert(sizeof(int16) == 2, "unexpected size");

static_assert(sizeof(uint32) == 4, "unexpected size");
static_assert(sizeof(int32) == 4, "unexpected size");

static_assert(sizeof(uint64) == 8, "unexpected size");
static_assert(sizeof(int64) == 8, "unexpected size");

static_assert(sizeof(char) == 1, "unexpected size");
static_assert(sizeof(int) == 4, "unexpected size");

static_assert(sizeof(short) >= 2, "unexpected size");
static_assert(sizeof(long) >= 4, "unexpected size");
static_assert(sizeof(long long) >= 8, "unexpected size");
static_assert(sizeof(size_t) >= 4, "unexpected size");

static_assert(sizeof(float) >= 4, "unexpected size");
static_assert(sizeof(double) >= 8, "unexpected size");
static_assert(sizeof(long double) >= 8, "unexpected size");

static_assert(sizeof(void*) >= 4, "unexpected size");
//static_assert(sizeof(void*) >= sizeof(void (*)(void)), "unexpected size");
static_assert(sizeof(uintptr_t) >= sizeof(void*), "unexpected size");

static_assert(sizeof(char) == SIZEOF_CHAR, "unexpected size");
static_assert(sizeof(short) == SIZEOF_SHORT, "unexpected size");
static_assert(sizeof(int) == SIZEOF_INT, "unexpected size");
static_assert(sizeof(long) == SIZEOF_LONG, "unexpected size");
static_assert(sizeof(long long) == SIZEOF_LONG_LONG, "unexpected size");

static_assert(sizeof(off_t) == SIZEOF_OFF_T, "unexpected size");
static_assert(sizeof(ptrdiff_t) == SIZEOF_PTRDIFF_T, "unexpected size");
static_assert(sizeof(size_t) == SIZEOF_SIZE_T, "unexpected size");
static_assert(sizeof(void*) == SIZEOF_VOID_P, "unexpected size");

static_assert(sizeof(double) == SIZEOF_DOUBLE, "unexpected size");

// Make sure the "char" type is signed(pass -fsigned-char to gcc).  New code in Mednafen shouldn't be written with the
// assumption that "char" is signed, but there likely is at least some code that does.
static_assert((char)255 == -1, "char type is not signed 8-bit");
