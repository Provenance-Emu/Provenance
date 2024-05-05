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

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif


#import <Foundation/Foundation.h>
#import <PVSupport/OERingBuffer.h>
#import <PVSupport/PVSupport-Swift.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVLogging/PVLogging.h>

#import <mednafen/mempatcher.h>
#import <PVMednafen/PVMednafen-Swift.h>

#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface MednafenGameCore (MultiDisc)
+ (NSDictionary<NSString*,NSNumber*>*_Nonnull)multiDiscPSXGames;
+ (NSDictionary<NSString*,NSNumber*>*_Nonnull)sbiRequiredGames;
@end

@interface MednafenGameCore (MultiTap)
+ (NSDictionary<NSString*,NSNumber*>*_Nonnull)multiTapPSXGames;
+ (NSArray<NSString*>*_Nonnull)multiTap5PlayerPort2;
@end

static Mednafen::MDFNGI *game;
static Mednafen::MDFN_Surface *backBufferSurf;
static Mednafen::MDFN_Surface *frontBufferSurf;

namespace MDFN_IEN_VB
{
extern void VIP_SetParallaxDisable(bool disabled);
extern void VIP_SetAnaglyphColors(uint32 lcolor, uint32 rcolor);
int mednafenCurrentDisplayMode = 1;
}


@interface MednafenGameCore () <PVPSXSystemResponderClient, PVWonderSwanSystemResponderClient, PVVirtualBoySystemResponderClient, PVPCESystemResponderClient, PVPCFXSystemResponderClient, PVPCECDSystemResponderClient, PVLynxSystemResponderClient, PVNeoGeoPocketSystemResponderClient, PVSNESSystemResponderClient, PVNESSystemResponderClient, PVGBSystemResponderClient, PVGBASystemResponderClient, PVSaturnSystemResponderClient>
{
    OEIntSize mednafenCoreAspect;
    
    Mednafen::EmulateSpecStruct spec;
}

@end

static __weak MednafenGameCore *_current;

@implementation MednafenGameCore

-(const void *)getGame
{
    return (const void *)game;
}

-(uint32_t*) getInputBuffer:(int)bufferId
{
    return inputBuffer[bufferId];
}

static void mednafen_init(MednafenGameCore* current)
{
    NSString* batterySavesDirectory = current.batterySavesPath;
    NSString* biosPath = current.BIOSPath;
    
    Mednafen::MDFNI_InitializeModules();
    
    std::vector<Mednafen::MDFNSetting> settings;
    
    MDFNI_Initialize([biosPath UTF8String], settings);
    
    // Set bios/system file and memcard save paths
    Mednafen::MDFNI_SetSetting("pce.cdbios", [[[biosPath stringByAppendingPathComponent:@"syscard3"] stringByAppendingPathExtension:@"pce"] UTF8String]); // PCE CD BIOS
    Mednafen::MDFNI_SetSetting("pce_fast.cdbios", [[[biosPath stringByAppendingPathComponent:@"syscard3"] stringByAppendingPathExtension:@"pce"] UTF8String]); // PCE CD BIOS
    Mednafen::MDFNI_SetSetting("pcfx.bios", [[[biosPath stringByAppendingPathComponent:@"pcfx"] stringByAppendingPathExtension:@"rom"] UTF8String]); // PCFX BIOS
    
    Mednafen::MDFNI_SetSetting("psx.bios_jp", [[[biosPath stringByAppendingPathComponent:@"scph5500"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SCPH-5500 BIOS
    Mednafen::MDFNI_SetSetting("psx.bios_na", [[[biosPath stringByAppendingPathComponent:@"scph5501"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA SCPH-5501 BIOS
    Mednafen::MDFNI_SetSetting("psx.bios_eu", [[[biosPath stringByAppendingPathComponent:@"scph5502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // EU SCPH-5502 BIOS
    
    Mednafen::MDFNI_SetSetting("ss.bios_jp", [[[biosPath stringByAppendingPathComponent:@"sega_101"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SS BIOS
    Mednafen::MDFNI_SetSetting("ss.bios_na_eu", [[[biosPath stringByAppendingPathComponent:@"mpr-17933"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA/EU SS BIOS
    
    NSString *gbaBIOSPath = [[biosPath stringByAppendingPathComponent:@"GBA"] stringByAppendingPathExtension:@"BIOS"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:gbaBIOSPath]) {
        Mednafen::MDFNI_SetSetting("gba.bios", [[[biosPath stringByAppendingPathComponent:@"GBA"] stringByAppendingPathExtension:@"BIOS"] UTF8String]); //
    }
    
    Mednafen::MDFNI_SetSetting("filesys.path_sav", [batterySavesDirectory UTF8String]); // Memcards
    
    // MARK: Global settings
    
    // Enable time synchronization(waiting) for frame blitting.
    // Disable to reduce latency, at the cost of potentially increased video "juddering", with the maximum reduction in latency being about 1 video frame's time.
    // Will work best with emulated systems that are not very computationally expensive to emulate, combined with running on a relatively fast CPU.
    // Default: 1
//    BOOL video_blit_timesync = current.video_blit_timesync;
//    Mednafen::MDFNI_SetSettingUI("video.blit_timesync", video_blit_timesync);
//
//    BOOL video_fs = current.video_fs;
//    Mednafen::MDFNI_SetSettingUI("video.fs", video_fs); // Enable fullscreen mode. Default: 0
//
//    const char* video_opengl = current.video_opengl ? "opengl" : "default";
//    Mednafen::MDFNI_SetSetting("video.driver", video_opengl);

    // Cache cd's to memory
    BOOL cd_image_memcache = current.cd_image_memcache;
    Mednafen::MDFNI_SetSettingB("cd.image_memcache", cd_image_memcache);
    
    // MARK: Sound
    // TODO: Read from device?
//    Mednafen::MDFNI_SetSettingUI("sound.rate", "44100");
    
    // MARK: VirtualBoy
    
    // VB defaults. dox http://mednafen.sourceforge.net/documentation/09x/vb.html
    Mednafen::MDFNI_SetSetting("vb.disable_parallax", "1");       // Disable parallax for BG and OBJ rendering
    Mednafen::MDFNI_SetSetting("vb.anaglyph.preset", "disabled"); // Disable anaglyph preset
    Mednafen::MDFNI_SetSetting("vb.anaglyph.lcolor", "0xFF0000"); // Anaglyph l color
    Mednafen::MDFNI_SetSetting("vb.anaglyph.rcolor", "0x000000"); // Anaglyph r color
    
    Mednafen::MDFNI_SetSetting("vb.default_color", "0xFF0000"); // Anaglyph r color
    
    //MDFNI_SetSetting("vb.allow_draw_skip", "1");      // Allow draw skipping
    
    // Display latency reduction hack.
    // Reduces latency in games by displaying the framebuffer 20ms earlier. This hack has some potential of causing graphical glitches, so it is disabled by default.
    BOOL vb_instant_display_hack = current.vb_instant_display_hack;
    Mednafen::MDFNI_SetSettingB("vb.instant_display_hack", vb_instant_display_hack); // Display latency reduction hack
    
    const char* vb_sidebyside = current.vb_sidebyside ? "sidebyside" : "anaglyph";
    Mednafen::MDFNI_SetSetting("vb.3dmode", vb_sidebyside);
    
    // This setting refers to pixels before vb.xscale(fs) scaling is taken into consideration. For example, a value of "100" here will result in a separation of 300 screen pixels if vb.xscale(fs) is set to "3".
//    int seperation = current.vb_sidebyside_seperation;
//    Mednafen::MDFNI_SetSetting("vb.sidebyside.separation", seperation);
    // Mednafen::MDFNI_SetSetting("vb.sidebyside.separation", [NSString stringWithFormat:@"%i", seperation].UTF8String);
    
    // MARK: SNES Faust settings
    BOOL snes_faust_spex = current.mednafen_snesFast_spex;
    Mednafen::MDFNI_SetSettingB("snes_faust.spex", snes_faust_spex);
    // Enable 1-frame speculative execution for video output.
    // Hack to reduce input->output video latency by 1 frame. Enabling will increase CPU usage,
    // and may cause video glitches(such as "jerkiness") in some oddball games, but most commercially-released games should be fine.
    // Default 0
    
    //	MDFNI_SetSetting("snes_faust.special", "nn2x");
    
    // MARK: Sega Saturn Settings
    // https://mednafen.github.io/documentation/ss.html
    BOOL ss_h_overscan = current.ss_h_overscan;
    Mednafen::MDFNI_SetSettingB("ss.h_overscan", ss_h_overscan); // Show horizontal overscan area. 1 default

    const char* ss_cart_autodefault;
    switch (current.ss_cart_autodefault) {
        case 0:
            ss_cart_autodefault = "none";
            break;
        case 1:
            ss_cart_autodefault = "backup";
            break;
        case 2:
            ss_cart_autodefault = "extram1";
            break;
        case 3:
            ss_cart_autodefault = "extram4";
            break;
        case 4:
            ss_cart_autodefault = "cs1ram16";
            break;
        default:
            ss_cart_autodefault = "backup";
            break;
    }
    Mednafen::MDFNI_SetSetting("ss.cart.auto_default", ss_cart_autodefault);
    
    const char* ss_region_default;
    switch (current.ss_region_default) {
        case 0:
            ss_region_default = "jp";
            break;
        case 1:
            ss_region_default = "na";
            break;
        case 2:
            ss_region_default = "eu";
            break;
        case 3:
            ss_region_default = "kr";
            break;
        case 4:
            ss_region_default = "tw";
            break;
        case 5:
            ss_region_default = "as";
            break;
        case 6:
            ss_region_default = "br";
            break;
        case 7:
            ss_region_default = "la";
            break;
        default:
            ss_region_default = "jp";
            break;
    }
    Mednafen::MDFNI_SetSetting("ss.region_default", ss_region_default);

    // MARK: NES Settings
    
    Mednafen::MDFNI_SetSettingUI("nes.clipsides", 1); // Clip left+right 8 pixel columns. 0 default
    Mednafen::MDFNI_SetSettingB("nes.correct_aspect", true); // Correct the aspect ratio. 0 default
    
    
    // MARK: PSX Settings
    BOOL psx_h_overscan = current.psx_h_overscan;
    Mednafen::MDFNI_SetSettingB("psx.h_overscan", psx_h_overscan); // Show horizontal overscan area. 1 default
    Mednafen::MDFNI_SetSetting("psx.region_default", "na"); // Set default region to North America if auto detect fails, default: jp
    
    Mednafen::MDFNI_SetSettingB("psx.input.analog_mode_ct", false); // Enable Analog mode toggle
    /*
     0x0001=SELECT
     0x0002=L3
     0x0004=R3
     0x0008=START
     0x0010=D-Pad Up
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
    // Analog/Digital Toggle
    uint64 amct =
    ((1 << PSXMap[PVPSXButtonL1]) | (1 << PSXMap[PVPSXButtonR1]) | (1 << PSXMap[PVPSXButtonL2]) | (1 << PSXMap[PVPSXButtonR2]) | (1 << PSXMap[PVPSXButtonCircle])) ||
    ((1 << PSXMap[PVPSXButtonL1]) | (1 << PSXMap[PVPSXButtonR1]) | (1 << PSXMap[PVPSXButtonCircle]));
    Mednafen::MDFNI_SetSettingUI("psx.input.analog_mode_ct.compare", amct);
    
    // MARK: PCE Settings
    //	MDFNI_SetSetting("pce.disable_softreset", "1"); // PCE: To prevent soft resets due to accidentally hitting RUN and SEL at the same time.
    //	MDFNI_SetSetting("pce.adpcmextraprec", "1"); // PCE: Enabling this option causes the MSM5205 ADPCM predictor to be outputted with full precision of 12-bits,
    //												 // rather than only outputting 10-bits of precision(as an actual MSM5205 does).
    //												 // Enable this option to reduce whining noise during ADPCM playback.
    Mednafen::MDFNI_SetSetting("pce.slstart", "0"); // PCE: First rendered scanline 4 default
    Mednafen::MDFNI_SetSetting("pce.slend", "239"); // PCE: Last rendered scanline 235 default, 241 max
    Mednafen::MDFNI_SetSetting("pce.h_overscan", "1"); // PCE: Show horizontal overscan are, default 0. Needed for correctly displaying the system aspect ratio.
    Mednafen::MDFNI_SetSetting("pce.resamp_quality", "5"); // PCE: Audio resampler quality, default 3 Higher values correspond to better SNR and better preservation of higher frequencies("brightness"), at the cost of increased computational complexity and a negligible increase in latency. Higher values will also slightly increase the probability of sample clipping(relevant if Mednafen's volume control settings are set too high), due to increased (time-domain) ringing.
    Mednafen::MDFNI_SetSetting("pce.resamp_rate_error", "0.0000001"); // PCE: Sound output rate tolerance. Lower values correspond to better matching of the output rate of the resampler to the actual desired output rate, at the expense of increased RAM usage and poorer CPU cache utilization. default 0.0000009
    Mednafen::MDFNI_SetSetting("pce.cdpsgvolume", "62"); // PCE: PSG volume when playing a CD game. Setting this volume control too high may cause sample clipping. default 100
    
    // MARK: PCE_Fast settings
    
    Mednafen::MDFNI_SetSetting("pce_fast.cdspeed", "4"); // PCE: CD-ROM data transfer speed multiplier. Default is 1
    //      MDFNI_SetSetting("pce_fast.disable_softreset", "1"); // PCE: To prevent soft resets due to accidentally hitting RUN and SEL at the same time
    Mednafen::MDFNI_SetSetting("pce_fast.slstart", "0"); // PCE: First rendered scanline
    Mednafen::MDFNI_SetSetting("pce_fast.slend", "239"); // PCE: Last rendered scanline
    
    // MARK: PC-FX Settings
    Mednafen::MDFNI_SetSetting("pcfx.cdspeed", "8"); // PCFX: Emulated CD-ROM speed. Setting the value higher than 2, the default, will decrease loading times in most games by some degree.
    //	MDFNI_SetSetting("pcfx.input.port1.multitap", "1"); // PCFX: EXPERIMENTAL emulation of the unreleased multitap. Enables ports 3 4 5.
    Mednafen::MDFNI_SetSetting("pcfx.nospritelimit", "1"); // PCFX: Remove 16-sprites-per-scanline hardware limit.
    Mednafen::MDFNI_SetSetting("pcfx.slstart", "4"); // PCFX: First rendered scanline 4 default
    Mednafen::MDFNI_SetSetting("pcfx.slend", "235"); // PCFX: Last rendered scanline 235 default, 239max
    
    // MARK: Cheats
    Mednafen::MDFNI_SetSetting("cheats", "1");       //
    
    // MARK: HUD
    // Enable FPS
#if DEBUG
//    Mednafen::MDFNI_SetSettingUI("fps.autoenable", 1);
#endif
    
    //	NSString *cfgPath = [[current BIOSPath] stringByAppendingPathComponent:@"mednafen-export.cfg"];
    //    Mednafen::MDFN_SaveSettings(cfgPath.UTF8String);
}

- (id)init {
    if((self = [super init])) {
        _current = self;
        
        multiTapPlayerCount = 2;
        
        for(unsigned i = 0; i < 13; i++) {
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
        
        // NES Map
        NESMap[PVNESButtonUp]           = 4;
        NESMap[PVNESButtonDown]         = 5;
        NESMap[PVNESButtonLeft]         = 6;
        NESMap[PVNESButtonRight]        = 7;
        
        NESMap[PVNESButtonA]            = 0;
        NESMap[PVNESButtonB]            = 1;
        
        NESMap[PVNESButtonSelect]       = 2;
        NESMap[PVNESButtonStart]        = 3;
        
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
        
        // Saturn SS map
        // static const int SSMap[]   = { 4, 5, 6, 7, 10, 8, 9, 2, 1, 0, 15, 3, 11 };
        /* IDIISG IODevice_Gamepad_IDII =
         {
          IDIIS_Button("z", "Z", 10),
          IDIIS_Button("y", "Y", 9),
          IDIIS_Button("x", "X", 8),
          IDIIS_Button("rs", "Right Shoulder", 12),

          IDIIS_Button("up", "UP ↑", 0, "down"),
          IDIIS_Button("down", "DOWN ↓", 1, "up"),
          IDIIS_Button("left", "LEFT ←", 2, "right"),
          IDIIS_Button("right", "RIGHT →", 3, "left"),

          IDIIS_Button("b", "B", 6),
          IDIIS_Button("c", "C", 7),
          IDIIS_Button("a", "A", 5),
          IDIIS_Button("start", "START", 4),

          IDIIS_Padding<1>(),
          IDIIS_Padding<1>(),
          IDIIS_Padding<1>(),
          IDIIS_Button("ls", "Left Shoulder", 11),
         };
         */
        SSMap[PVSaturnButtonUp]    = 4;
        SSMap[PVSaturnButtonDown]  = 5;
        SSMap[PVSaturnButtonLeft]  = 6;
        SSMap[PVSaturnButtonRight] = 7;
        
        SSMap[PVSaturnButtonStart] = 3;
        
        SSMap[PVSaturnButtonA]     = 10;
        SSMap[PVSaturnButtonB]     = 8;
        SSMap[PVSaturnButtonC]     = 9;
        SSMap[PVSaturnButtonX]     = 2;
        SSMap[PVSaturnButtonY]     = 1;
        SSMap[PVSaturnButtonZ]     = 0;
        
        SSMap[PVSaturnButtonL]     = 11;
        SSMap[PVSaturnButtonR]     = 12;
    }
    
    [self parseOptions];
    
    return self;
}

- (void)dealloc {
    for(unsigned i = 0; i < 13; i++) {
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
    int32 rects[game->fb_height];//int32 *rects = new int32[game->fb_height]; //(int32 *)malloc(sizeof(int32) * game->fb_height);
    memset(rects, 0, game->fb_height*sizeof(int32));
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
    
    current->videoOffsetX = current->spec.DisplayRect.x;
    current->videoOffsetY = current->spec.DisplayRect.y;
    if(game->multires || current->_systemType == MednaSystemPSX) {
        current->videoWidth = rects[current->spec.DisplayRect.y];
    }
    else {
        current->videoWidth = current->spec.DisplayRect.w ?: rects[current->spec.DisplayRect.y];
    }
    current->videoHeight  = current->spec.DisplayRect.h;
    
    update_audio_batch(current->spec.SoundBuf, current->spec.SoundBufSize);
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    [self parseOptions];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath] withIntermediateDirectories:YES attributes:nil error:NULL];
    
    if([[self systemIdentifier] isEqualToString:@"com.provenance.lynx"])
    {
        self.systemType = MednaSystemLynx;
        
        mednafenCoreModule = @"lynx";
        //mednafenCoreAspect = OEIntSizeMake(80, 51);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.nes"])
    {
        self.systemType = MednaSystemNES;
        
        mednafenCoreModule = @"nes";
        //mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.snes"])
    {
        self.systemType = MednaSystemSNES;
        
        mednafenCoreModule = self.mednafen_snesFast ? @"snes_faust" : @"snes";
        
        //mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.gb"] || [[self systemIdentifier] isEqualToString:@"com.provenance.gbc"])
    {
        self.systemType = MednaSystemGB;
        
        mednafenCoreModule = @"gb";
        //mednafenCoreAspect = OEIntSizeMake(10, 9);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.gba"])
    {
        self.systemType = MednaSystemGBA;
        
        mednafenCoreModule = @"gba";
        //mednafenCoreAspect = OEIntSizeMake(3, 2);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.genesis"]) // Genesis aka Megaddrive
    {
        self.systemType = MednaSystemMD;
        
        mednafenCoreModule = @"md";
        //mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.mastersystem"])
    {
        self.systemType = MednaSystemSMS;
        
        mednafenCoreModule = @"sms";
        //mednafenCoreAspect = OEIntSizeMake(256 * (8.0/7.0), 192);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ngp"] || [[self systemIdentifier] isEqualToString:@"com.provenance.ngpc"])
    {
        self.systemType = MednaSystemNeoGeo;
        
        mednafenCoreModule = @"ngp";
        //mednafenCoreAspect = OEIntSizeMake(20, 19);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pce"] || [[self systemIdentifier] isEqualToString:@"com.provenance.pcecd"] || [[self systemIdentifier] isEqualToString:@"com.provenance.sgfx"])
    {
        self.systemType = MednaSystemPCE;
        
        
        mednafenCoreModule = self.mednafen_pceFast ? @"pce_fast" : @"pce";
        //mednafenCoreAspect = OEIntSizeMake(256 * (8.0/7.0), 240);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pcfx"])
    {
        self.systemType = MednaSystemPCFX;
        
        mednafenCoreModule = @"pcfx";
        //mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.saturn"])
    {
        self.systemType = MednaSystemSS;
        
        mednafenCoreModule = @"ss";
        //mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.psx"])
    {
        self.systemType = MednaSystemPSX;
        
        mednafenCoreModule = @"psx";
        // Note: OpenEmu sets this to 4:3, but it's demonstrably wrong. Tested and looked into it myself… the other emulators got this wrong, 3:2 was close, but it's actually 10:7 - Sev
        //mednafenCoreAspect = OEIntSizeMake(10, 7);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.vb"])
    {
        self.systemType = MednaSystemVirtualBoy;
        
        mednafenCoreModule = @"vb";
        //mednafenCoreAspect = OEIntSizeMake(12, 7);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ws"] || [[self systemIdentifier] isEqualToString:@"com.provenance.wsc"])
    {
        self.systemType = MednaSystemWonderSwan;
        
        mednafenCoreModule = @"wswan";
        //mednafenCoreAspect = OEIntSizeMake(14, 9);
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
    Mednafen::NativeVFS fs = Mednafen::NativeVFS();
    
    game = Mednafen::MDFNI_LoadGame([mednafenCoreModule UTF8String], &fs, [path UTF8String]);
    assert(game);
    
    if(!game) {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to load game.",
                NSLocalizedFailureReasonErrorKey: @"Mednafen failed to load game.",
                NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported Mednafen ROM format."
            };
            
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                                userInfo:userInfo];
            
            *error = newError;
        }
        return NO;
    }
    
    // Uncomment this to set the aspect ratio by the game's render size according to mednafen
    // is this correct for EU, JP, US? Still testing.
    mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
    
    // BGRA pixel format
    Mednafen::MDFN_PixelFormat pix_fmt(Mednafen::MDFN_COLORSPACE_RGB, 4, 0, 8, 16, 24);
    backBufferSurf = new Mednafen::MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
    frontBufferSurf = new Mednafen::MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
    
    masterClock = game->MasterClock >> 32;
    BOOL multiDiscGame = NO;
    
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
    else if (self.systemType == MednaSystemVirtualBoy || self.systemType == MednaSystemSNES || self.systemType == MednaSystemNES)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
    }
    else if (self.systemType == MednaSystemSS) {
        BOOL hasM3u = [path.pathExtension.lowercaseString isEqualToString:@"m3u"];
        if (hasM3u) {
            multiDiscGame = YES;
            
            // TODO: Make this real
            // https://gamicus.fandom.com/wiki/List_of_Saturn_video_games_with_multiple_discs
            self.maxDiscs = 4;
        }
        
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
    }
    else if (self.systemType == MednaSystemPSX)
    {
        for(unsigned i = 0; i < multiTapPlayerCount; i++) {
            // Center the Dual Analog Sticks
            uint8 *buf = (uint8 *)inputBuffer[i];
            Mednafen::MDFN_en16lsb(&buf[3], (uint16) 32767);
            Mednafen::MDFN_en16lsb(&buf[3]+2, (uint16) 32767);
            Mednafen::MDFN_en16lsb(&buf[3]+4, (uint16) 32767);
            Mednafen::MDFN_en16lsb(&buf[3]+6, (uint16) 32767);
            // Do we want to use gamepad when not using an MFi device?
            game->SetInput(i, "dualshock", (uint8_t *)inputBuffer[i]);
        }
        
        // Multi-Disc check
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
        // PSX: Check if SBI file is required
        if ([MednafenGameCore sbiRequiredGames][self.romSerial])
        {
            _isSBIRequired = YES;
        }
        
        // Handle required SBI files for games
        // TODO: Handle SBI Games
        //        if(_isSBIRequired && _allCueSheetFiles.count && ([path.pathExtension.lowercaseString isEqualToString:@"cue"] || [path.pathExtension.lowercaseString isEqualToString:@"m3u"]))
        //        {
        //            NSURL *romPath = [NSURL fileURLWithPath:path.stringByDeletingLastPathComponent];
        //
        //            BOOL missingFileStatus = NO;
        //            NSUInteger missingFileCount = 0;
        //            NSMutableString *missingFilesList = [NSMutableString string];
        //
        //            // Build a path to SBI file and check if it exists
        //            for(NSString *cueSheetFile in _allCueSheetFiles)
        //            {
        //                NSString *extensionlessFilename = cueSheetFile.stringByDeletingPathExtension;
        //                NSURL *sbiFile = [romPath URLByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sbi"]];
        //
        //                // Check if the required SBI files exist
        //                if(![sbiFile checkResourceIsReachableAndReturnError:nil])
        //                {
        //                    missingFileStatus = YES;
        //                    missingFileCount++;
        //                    [missingFilesList appendString:[NSString stringWithFormat:@"\"%@\"\n\n", extensionlessFilename]];
        //                }
        //            }
        //            // Alert the user of missing SBI files that are required for the game
        //            if(missingFileStatus)
        //            {
        //                NSError *outErr = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadROMError userInfo:@{
        //                    NSLocalizedDescriptionKey : missingFileCount > 1 ? @"Required SBI files missing." : @"Required SBI file missing.",
        //                    NSLocalizedRecoverySuggestionErrorKey : missingFileCount > 1 ? [NSString stringWithFormat:@"To run this game you need SBI files for the discs:\n\n%@Drag and drop the required files onto the game library window and try again.\n\nFor more information, visit:\nhttps://github.com/OpenEmu/OpenEmu/wiki/User-guide:-CD-based-games#q-i-have-a-sbi-file", missingFilesList] : [NSString stringWithFormat:@"To run this game you need a SBI file for the disc:\n\n%@Drag and drop the required file onto the game library window and try again.\n\nFor more information, visit:\nhttps://github.com/OpenEmu/OpenEmu/wiki/User-guide:-CD-based-games#q-i-have-a-sbi-file", missingFilesList],
        //                    }];
        //
        //                *error = outErr;
        //
        //                return NO;
        //            }
        //        }
    }
    else if (self.systemType == MednaSystemGBA) {
        // gba sets all of these in 1 variable, so setting the one we use
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
    } else {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
//        game->SetInput(2, "gamepad", (uint8_t *)inputBuffer[2]);
//        game->SetInput(3, "gamepad", (uint8_t *)inputBuffer[3]);
    }
    
    if (multiDiscGame && ![path.pathExtension.lowercaseString isEqualToString:@"m3u"]) {
        NSString *m3uPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"m3u"];
        NSRange rangeOfDocuments = [m3uPath rangeOfString:@"/Documents/" options:NSCaseInsensitiveSearch];
        if (rangeOfDocuments.location != NSNotFound) {
            m3uPath = [m3uPath substringFromIndex:rangeOfDocuments.location + 11];
        }
        
        if (error) {
            NSString *message = [NSString stringWithFormat:@"This game requires multiple discs and must be loaded using a m3u file with all %lu discs.\n\nTo enable disc switching and ensure save files load across discs, it cannot be loaded as a single disc.\n\nPlease install a .m3u file with the filename %@.\nSee https://bitly.com/provdiscs", self.maxDiscs, m3uPath];
            
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to load game.",
                NSLocalizedFailureReasonErrorKey: @"Missing required m3u file.",
                NSLocalizedRecoverySuggestionErrorKey: message
            };
            
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeMissingM3U
                                                userInfo:userInfo];
            
            *error = newError;
        }
        return NO;
    }
    
    if (self.maxDiscs > 1) {
        // Parse number of discs in m3u
        NSString *m3uString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".cue|.ccd" options:NSRegularExpressionCaseInsensitive error:nil];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:m3uString options:0 range:NSMakeRange(0, [m3uString length])];
        
        ILOG(@"Loaded m3u containing %lu cue sheets or ccd",numberOfMatches);
    }
    
    //    BOOL success =
    Mednafen::MDFNI_SetMedia(0, 2, 0, 0); // Disc selection API
    //    if (!success) {
    //        NSString *message = [NSString stringWithFormat:@"MDFNI_SetMedia returned 0. Check your m3u or other file paths."];
    //
    //        NSDictionary *userInfo = @{
    //                                   NSLocalizedDescriptionKey: @"Failed to load game.",
    //                                   NSLocalizedFailureReasonErrorKey: @"MDFNI_SetMedia returned 0",
    //                                   NSLocalizedRecoverySuggestionErrorKey: message
    //                                   };
    //
    //        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
    //                                                code:PVEmulatorCoreErrorCodeMissingM3U
    //                                            userInfo:userInfo];
    //
    //        *error = newError;
    //        return NO;
    //    }
    
    emulation_run(NO);
    
    return YES;
}

-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc {
    Mednafen::MDFNI_SetMedia(0, open ? 0 : 2, (uint32) disc, 0);
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
        case MednaSystemSS:
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
        case MednaSystemSS:
            maxValue = PVSaturnButtonCount;
            map = SSMap;
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
        else if (self.controller3 && playerIndex == 2)
        {
            controller = self.controller3;
        }
        else if (self.controller4 && playerIndex == 3)
        {
            controller = self.controller4;
        }
        
        if (controller) {
            uint8 *d8 = (uint8 *)inputBuffer[playerIndex];
            bool analogMode = (d8[2] & 0x02);
            
            for (unsigned i=0; i<maxValue; i++) {
                
                if (self.systemType != MednaSystemPSX || i < PVPSXButtonLeftAnalogUp) {
                    uint32_t value = (uint32_t)[self controllerValueForButtonID:i forPlayer:playerIndex withAnalogMode:analogMode];
                    
                    if(value > 0) {
                        inputBuffer[playerIndex][0] |= 1 << map[i];
                    } else {
                        inputBuffer[playerIndex][0] &= ~(1 << map[i]);
                    }
                } else if (analogMode) {
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
    Mednafen::MDFNI_Reset();
}

- (void)stopEmulation
{
    Mednafen::MDFNI_CloseGame();
    Mednafen::MDFNI_Kill();
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval {
    return mednafenCoreTiming ?: 60;
}

# pragma mark - Video

- (CGRect)screenRect {
    return CGRectMake(videoOffsetX, videoOffsetY, videoWidth, videoHeight);
}

- (CGSize)bufferSize {
    if ( game == NULL )
    {
        return CGSizeMake(0, 0);
    }
    else
    {
        return CGSizeMake(game->fb_width, game->fb_height);
    }
}

- (CGSize)aspectSize {
    return CGSizeMake(mednafenCoreAspect.width, mednafenCoreAspect.height);
}

- (const void *)videoBuffer {
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
    return GL_RGBA;
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
    Mednafen::MDFN_Surface *tempSurf = backBufferSurf;
    backBufferSurf = frontBufferSurf;
    frontBufferSurf = tempSurf;
}

- (BOOL)rendersToOpenGL {
    return self.video_opengl;
}

#pragma mark - Audio

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
    if(game == nil) { return 2; }
    return game->soundchan;
}

# pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
    if (game != nil ) {
        BOOL success = Mednafen::MDFNI_SaveState(fileName.fileSystemRepresentation, "", NULL, NULL, NULL);
        if (!success) {
            if (error) {
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
        }
        return success;
    } else {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to save state.",
                NSLocalizedFailureReasonErrorKey: @"Core failed to create save state because no game is loaded.",
                NSLocalizedRecoverySuggestionErrorKey: @""
            };
            
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                userInfo:userInfo];
            
            *error = newError;
        }
        return NO;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error   {
    if (game != nil ) {
        BOOL success = Mednafen::MDFNI_LoadState(fileName.fileSystemRepresentation, "");
        if (!success) {
            if (error) {
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
        }
        return success;
    } else {
        if (error) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: @"Failed to save state.",
                NSLocalizedFailureReasonErrorKey: @"No game loaded.",
                NSLocalizedRecoverySuggestionErrorKey: @""
            };
            
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];
            
            *error = newError;
        }
        return NO;
    }
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
    Mednafen::MemoryStream stream(65536, false);
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
    
    Mednafen::MemoryStream stream(length, -1);
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

//static_assert(sizeof(char) == SIZEOF_CHAR, "unexpected size");
//static_assert(sizeof(short) == SIZEOF_SHORT, "unexpected size");
//static_assert(sizeof(int) == SIZEOF_INT, "unexpected size");
//static_assert(sizeof(long) == SIZEOF_LONG, "unexpected size");
//static_assert(sizeof(long long) == SIZEOF_LONG_LONG, "unexpected size");
//
//static_assert(sizeof(off_t) == SIZEOF_OFF_T, "unexpected size");
//static_assert(sizeof(ptrdiff_t) == SIZEOF_PTRDIFF_T, "unexpected size");
//static_assert(sizeof(size_t) == SIZEOF_SIZE_T, "unexpected size");
//static_assert(sizeof(void*) == SIZEOF_VOID_P, "unexpected size");
//
//static_assert(sizeof(double) == SIZEOF_DOUBLE, "unexpected size");

// Make sure the "char" type is signed(pass -fsigned-char to gcc).  New code in Mednafen shouldn't be written with the
// assumption that "char" is signed, but there likely is at least some code that does.
static_assert((char)255 == -1, "char type is not signed 8-bit");
