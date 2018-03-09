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

#include "mednafen.h"
#include "settings-driver.h"
#include "state-driver.h"
#include "mednafen-driver.h"
#include "MemoryStream.h"

#import "MednafenGameCore.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import <UIKit/UIKit.h>
#import <PVSupport/OERingBuffer.h>

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

namespace MDFN_IEN_VB
{
    extern void VIP_SetParallaxDisable(bool disabled);
    extern void VIP_SetAnaglyphColors(uint32 lcolor, uint32 rcolor);
    int mednafenCurrentDisplayMode = 1;
}

typedef enum MednaSystem {lynx, neogeo, pce, pcfx, psx, vb, wswan };

@interface MednafenGameCore ()
{
    uint32_t *inputBuffer[8];
    MednaSystem systemType;
    int videoWidth, videoHeight;
    int videoOffsetX, videoOffsetY;
    int multiTapPlayerCount;
    NSString *romName;
    double sampleRate;
    double masterClock;

    NSString *mednafenCoreModule;
    NSTimeInterval mednafenCoreTiming;
    OEIntSize mednafenCoreAspect;
    NSUInteger maxDiscs;
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
    //passing by parameter
    //GET_CURRENT_OR_RETURN();

    NSString* batterySavesDirectory = current.batterySavesPath;
    NSString* biosPath = current.BIOSPath;
    
    std::vector<MDFNGI*> ext;
    MDFNI_InitializeModules(ext);

    std::vector<MDFNSetting> settings;

    //passing by parameter
    //NSString *batterySavesDirectory = [self batterySavesPath];
    //NSString *biosPath = current.biosDirectoryPath;

    MDFNI_Initialize([biosPath UTF8String], settings);

    // Set bios/system file and memcard save paths
    MDFNI_SetSetting("pce.cdbios", [[[biosPath stringByAppendingPathComponent:@"syscard3"] stringByAppendingPathExtension:@"pce"] UTF8String]); // PCE CD BIOS
    MDFNI_SetSetting("pcfx.bios", [[[biosPath stringByAppendingPathComponent:@"pcfx"] stringByAppendingPathExtension:@"rom"] UTF8String]); // PCFX BIOS
    MDFNI_SetSetting("psx.bios_jp", [[[biosPath stringByAppendingPathComponent:@"scph5500"] stringByAppendingPathExtension:@"bin"] UTF8String]); // JP SCPH-5500 BIOS
    MDFNI_SetSetting("psx.bios_na", [[[biosPath stringByAppendingPathComponent:@"scph5501"] stringByAppendingPathExtension:@"bin"] UTF8String]); // NA SCPH-5501 BIOS
    MDFNI_SetSetting("psx.bios_eu", [[[biosPath stringByAppendingPathComponent:@"scph5502"] stringByAppendingPathExtension:@"bin"] UTF8String]); // EU SCPH-5502 BIOS
    MDFNI_SetSetting("filesys.path_sav", [batterySavesDirectory UTF8String]); // Memcards

    // VB defaults. dox http://mednafen.sourceforge.net/documentation/09x/vb.html
    MDFNI_SetSetting("vb.disable_parallax", "1");       // Disable parallax for BG and OBJ rendering
    MDFNI_SetSetting("vb.anaglyph.preset", "disabled"); // Disable anaglyph preset
    MDFNI_SetSetting("vb.anaglyph.lcolor", "0xFF0000"); // Anaglyph l color
    MDFNI_SetSetting("vb.anaglyph.rcolor", "0x000000"); // Anaglyph r color
    //MDFNI_SetSetting("vb.allow_draw_skip", "1");      // Allow draw skipping
    //MDFNI_SetSetting("vb.instant_display_hack", "1"); // Display latency reduction hack

    MDFNI_SetSetting("pce.slstart", "0"); // PCE: First rendered scanline
    MDFNI_SetSetting("pce.slend", "239"); // PCE: Last rendered scanline

    MDFNI_SetSetting("psx.h_overscan", "0"); // Remove PSX overscan

#pragma message "forget about multitap for now :)"
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
}

- (id)init {
    if((self = [super init]))
    {
        _current = self;

        multiTapPlayerCount = 2;

        for(unsigned i = 0; i < 8; i++) {
            inputBuffer[i] = (uint32_t *) calloc(9, sizeof(uint32_t));
        }
    }

    return self;
}

- (void)dealloc {
    for(unsigned i = 0; i < 8; i++) {
        free(inputBuffer[i]);
    }

    delete backBufferSurf;
    delete frontBufferSurf;
    
    if (_current == self) {
        _current = nil;
    }
}

# pragma mark - Execution

static void emulation_run() {
    GET_CURRENT_OR_RETURN();
    
    static int16_t sound_buf[0x10000];
    int32 rects[game->fb_height];
    rects[0] = ~0;

    EmulateSpecStruct spec = {0};
    spec.surface = backBufferSurf;
    spec.SoundRate = current->sampleRate;
    spec.SoundBuf = sound_buf;
    spec.LineWidths = rects;
    spec.SoundBufMaxSize = sizeof(sound_buf) / 2;
    spec.SoundVolume = 1.0;
    spec.soundmultiplier = 1.0;

    MDFNI_Emulate(&spec);

    current->mednafenCoreTiming = current->masterClock / spec.MasterCycles;
    
    // Fix for game stutter. mednafenCoreTiming flutters on init before settling so
    // now we reset the game speed each frame to make sure current->gameInterval
    // is up to date while respecting the current game speed setting
    [current setGameSpeed:[current gameSpeed]];

    if(current->systemType == psx)
    {
        current->videoWidth = rects[spec.DisplayRect.y];
        current->videoOffsetX = spec.DisplayRect.x;
    }
    else if(game->multires)
    {
        current->videoWidth = rects[spec.DisplayRect.y];
        current->videoOffsetX = spec.DisplayRect.x;
    }
    else
    {
        current->videoWidth = spec.DisplayRect.w;
        current->videoOffsetX = spec.DisplayRect.x;
    }

    current->videoHeight = spec.DisplayRect.h;
    current->videoOffsetY = spec.DisplayRect.y;

    update_audio_batch(spec.SoundBuf, spec.SoundBufSize);
}

- (BOOL)loadFileAtPath:(NSString *)path
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[self batterySavesPath] withIntermediateDirectories:YES attributes:nil error:NULL];

    if([[self systemIdentifier] isEqualToString:@"com.provenance.lynx"])
    {
        systemType = lynx;
        
        mednafenCoreModule = @"lynx";
        mednafenCoreAspect = OEIntSizeMake(80, 51);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ngp"] || [[self systemIdentifier] isEqualToString:@"com.provenance.ngpc"])
    {
        systemType = neogeo;
        
        mednafenCoreModule = @"ngp";
        mednafenCoreAspect = OEIntSizeMake(20, 19);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pce"] || [[self systemIdentifier] isEqualToString:@"com.provenance.pcecd"] || [[self systemIdentifier] isEqualToString:@"com.provenance.sgfx"])
    {
        systemType = pce;
        
        mednafenCoreModule = @"pce";
        mednafenCoreAspect = OEIntSizeMake(256 * (8.0/7.0), 240);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.pcfx"])
    {
        systemType = pcfx;
        
        mednafenCoreModule = @"pcfx";
        mednafenCoreAspect = OEIntSizeMake(4, 3);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.psx"])
    {
        systemType = psx;
        
        mednafenCoreModule = @"psx";
        // Note: OpenEMU sets this to 4, 3.
        mednafenCoreAspect = OEIntSizeMake(3, 2);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 44100;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.vb"])
    {
        systemType = vb;
        
        mednafenCoreModule = @"vb";
        mednafenCoreAspect = OEIntSizeMake(12, 7);
        //mednafenCoreAspect = OEIntSizeMake(game->nominal_width, game->nominal_height);
        sampleRate         = 48000;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.ws"] || [[self systemIdentifier] isEqualToString:@"com.provenance.wsc"])
    {
        systemType = wswan;
        
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

    if(!game) {
        return NO;
    }
    
    // BGRA pixel format
    MDFN_PixelFormat pix_fmt(MDFN_COLORSPACE_RGB, 16, 8, 0, 24);
    backBufferSurf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);
    frontBufferSurf = new MDFN_Surface(NULL, game->fb_width, game->fb_height, game->fb_width, pix_fmt);

    masterClock = game->MasterClock >> 32;

    if (systemType == pce)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
        game->SetInput(2, "gamepad", (uint8_t *)inputBuffer[2]);
        game->SetInput(3, "gamepad", (uint8_t *)inputBuffer[3]);
        game->SetInput(4, "gamepad", (uint8_t *)inputBuffer[4]);
    }
    else if (systemType == pcfx)
    {
        game->SetInput(0, "gamepad", (uint8_t *)inputBuffer[0]);
        game->SetInput(1, "gamepad", (uint8_t *)inputBuffer[1]);
    }
    else if (systemType == psx)
    {
        for(unsigned i = 0; i < multiTapPlayerCount; i++) {
            game->SetInput(i, "dualshock", (uint8_t *)inputBuffer[i]);
        }
        
        
        
        // Multi-Disc check
        BOOL multiDiscGame = NO;
        NSNumber *discCount = [MednafenGameCore multiDiscPSXGames][self.romSerial];
        if (discCount) {
            maxDiscs = [discCount intValue];
            multiDiscGame = YES;
        }
        
        if (multiDiscGame && ![path.pathExtension.lowercaseString isEqualToString:@"m3u"]) {
            NSString *m3uPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"m3u"];
            NSRange rangeOfDocuments = [m3uPath rangeOfString:@"/Documents/" options:NSCaseInsensitiveSearch];
            if (rangeOfDocuments.location != NSNotFound) {
                m3uPath = [m3uPath substringFromIndex:rangeOfDocuments.location + 11];
            }
            
            NSString *message = [NSString stringWithFormat:@"This game requires multiple discs and must be loaded using a m3u file with all %lu discs.\n\nTo enable disc switching and ensure save files load across discs, it cannot be loaded as a single disc.\n\nPlease install a .m3u file with the filename %@.\nSee https://bitly.com/provm3u", maxDiscs, m3uPath];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Required m3u file missing."
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"View Wiki" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://bitly.com/provm3u"] options:nil completionHandler:nil];
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            [UIApplication.sharedApplication.delegate.window.rootViewController presentViewController:alert animated:YES completion:nil];
            
            return NO;
        }
        
        if (maxDiscs > 1) {
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

    emulation_run();

    return YES;
}

- (void)pollControllers {
    unsigned maxValue = 0;
    const int*map;
    switch (systemType) {
        case psx:
            maxValue = PVPSXButtonCount;
            map = PSXMap;
            break;
        case neogeo:
            maxValue = OENGPButtonCount;
            map = NeoMap;
            break;
        case lynx:
            maxValue = OELynxButtonCount;
            map = LynxMap;
            break;
        case pce:
            maxValue = OEPCEButtonCount;
            map = PCEMap;
            break;
        case pcfx:
            maxValue = OEPCFXButtonCount;
            map = PCFXMap;
            break;
        case vb:
            maxValue = OEVBButtonCount;
            map = VBMap;
            break;
        case wswan:
            maxValue = OEWSButtonCount;
            map = WSMap;
            break;
            return;
    }

    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        
        if (controller) {
            for (unsigned i=0; i<maxValue; i++) {
                
                if (systemType != psx || i < OEPSXLeftAnalogUp) {
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

- (void)executeFrame
{
    // Should we be using controller callbacks instead?
    if (self.controller1 || self.controller2) {
        [self pollControllers];
    }
    
    emulation_run();
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
    return mednafenCoreTiming ?: 60;
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

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
    return MDFNI_SaveState(fileName.fileSystemRepresentation, "", NULL, NULL, NULL);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    return MDFNI_LoadState(fileName.fileSystemRepresentation, "");
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
#pragma message "fix error log"
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
        #pragma message "fix error log"
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

# pragma mark - Input

// Map OE button order to Mednafen button order
const int LynxMap[] = { 6, 7, 4, 5, 0, 1, 3, 2 };
const int PCEMap[]  = { 4, 6, 7, 5, 0, 1, 8, 9, 10, 11, 3, 2, 12 };
const int PCFXMap[] = { 8, 10, 11, 9, 0, 1, 2, 3, 4, 5, 7, 6 };
const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };
const int VBMap[]   = { 9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11 };
const int WSMap[]   = { 0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11 };
const int NeoMap[]  = { 0, 1, 2, 3, 4, 5, 6};

#pragma mark Atari Lynx
- (oneway void)didPushLynxButton:(OELynxButton)button forPlayer:(NSUInteger)player {
    inputBuffer[player][0] |= 1 << LynxMap[button];
}

- (oneway void)didReleaseLynxButton:(OELynxButton)button forPlayer:(NSUInteger)player {
    inputBuffer[player][0] &= ~(1 << LynxMap[button]);
}

- (NSInteger)LynxControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OELynxButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case OELynxButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case OELynxButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case OELynxButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case OELynxButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OELynxButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OELynxButtonOption1:
                return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed];
            case OELynxButtonOption2:
                return [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OELynxButtonUp:
                return [[dpad up] isPressed];
            case OELynxButtonDown:
                return [[dpad down] isPressed];
            case OELynxButtonLeft:
                return [[dpad left] isPressed];
            case OELynxButtonRight:
                return [[dpad right] isPressed];
            case OELynxButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OELynxButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OELynxButtonOption1:
                return [[pad leftShoulder] isPressed];
            case OELynxButtonOption2:
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
            case OELynxButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OELynxButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OELynxButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OELynxButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OELynxButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OELynxButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

#pragma mark Neo Geo
- (oneway void)didPushNGPButton:(OENGPButton)button forPlayer:(NSUInteger)player
{
    inputBuffer[player][0] |= 1 << NeoMap[button];
}

- (oneway void)didReleaseNGPButton:(OENGPButton)button forPlayer:(NSUInteger)player
{
    inputBuffer[player][0] &= ~(1 << NeoMap[button]);
}

#pragma mark PC-*
- (oneway void)didPushPCEButton:(OEPCEButton)button forPlayer:(NSUInteger)player
{
    if (button != OEPCEButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (oneway void)didReleasePCEButton:(OEPCEButton)button forPlayer:(NSUInteger)player
{
    if (button != OEPCEButtonMode)
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
}

- (oneway void)didPushPCECDButton:(OEPCECDButton)button forPlayer:(NSUInteger)player
{
    if (button != OEPCECDButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (oneway void)didReleasePCECDButton:(OEPCECDButton)button forPlayer:(NSUInteger)player;
{
    if (button != OEPCECDButtonMode) {
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
    }
}

- (oneway void)didPushPCFXButton:(OEPCFXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << PCFXMap[button];
}

- (oneway void)didReleasePCFXButton:(OEPCFXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << PCFXMap[button]);
}

#pragma mark PSX
- (oneway void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << PSXMap[button];
}

- (oneway void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << PSXMap[button]);
}

- (oneway void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
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
- (oneway void)didPushVBButton:(OEVBButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << VBMap[button];
}

- (oneway void)didReleaseVBButton:(OEVBButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << VBMap[button]);
}

#pragma mark WonderSwan
- (oneway void)didPushWSButton:(OEWSButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] |= 1 << WSMap[button];
}

- (oneway void)didReleaseWSButton:(OEWSButton)button forPlayer:(NSUInteger)player;
{
    inputBuffer[player][0] &= ~(1 << WSMap[button]);
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player {
    GCController *controller = nil;
    
    if (player == 0) {
        controller = self.controller1;
    } else {
        controller = self.controller2;
    }
    
    switch (systemType) {
        case neogeo:
            return [self NeoGeoValueForButtonID:buttonID forController:controller];
            break;

        case lynx:
            return [self LynxControllerValueForButtonID:buttonID forController:controller];
            break;

        case pce:
        case pcfx:
            return [self PCEValueForButtonID:buttonID forController:controller];
            break;

        case psx:
            return [self PSXcontrollerValueForButtonID:buttonID forController:controller];
            break;

        case vb:
            return [self VirtualBoyControllerValueForButtonID:buttonID forController:controller];
            break;

        case wswan:
            return [self WonderSwanControllerValueForButtonID:buttonID forController:controller];
            break;
            
        default:
            break;
    }

    return 0;
}

- (NSInteger)NeoGeoValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OENGPButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case OENGPButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case OENGPButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case OENGPButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case OENGPButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OENGPButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OENGPButtonOption:
                return [[pad leftShoulder] isPressed]?:[[pad leftTrigger] isPressed] ?: [[pad rightShoulder] isPressed]?:[[pad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OENGPButtonUp:
                return [[dpad up] isPressed];
            case OENGPButtonDown:
                return [[dpad down] isPressed];
            case OENGPButtonLeft:
                return [[dpad left] isPressed];
            case OENGPButtonRight:
                return [[dpad right] isPressed];
            case OENGPButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OENGPButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OENGPButtonOption:
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
            case OENGPButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OENGPButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OENGPButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OENGPButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OENGPButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OENGPButtonB:
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
            case OEPCEButtonUp:
                return [[dpad up] isPressed]?:[[[gamePad leftThumbstick] up] isPressed];
            case OEPCEButtonDown:
                return [[dpad down] isPressed]?:[[[gamePad leftThumbstick] down] isPressed];
            case OEPCEButtonLeft:
                return [[dpad left] isPressed]?:[[[gamePad leftThumbstick] left] isPressed];
            case OEPCEButtonRight:
                return [[dpad right] isPressed]?:[[[gamePad leftThumbstick] right] isPressed];
            case OEPCEButton3:
                return [[gamePad buttonX] isPressed];
            case OEPCEButton2:
                return [[gamePad buttonA] isPressed];
            case OEPCEButton1:
                return [[gamePad buttonB] isPressed];
            case OEPCEButton4:
                return [[gamePad leftShoulder] isPressed];
            case OEPCEButton5:
                return [[gamePad buttonY] isPressed];
            case OEPCEButton6:
                return [[gamePad rightShoulder] isPressed];
            case OEPCEButtonMode:
                return [[gamePad leftTrigger] isPressed];
            case OEPCEButtonRun:
                return [[gamePad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamePad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OEPCEButtonUp:
                return [[dpad up] isPressed];
            case OEPCEButtonDown:
                return [[dpad down] isPressed];
            case OEPCEButtonLeft:
                return [[dpad left] isPressed];
            case OEPCEButtonRight:
                return [[dpad right] isPressed];
            case OEPCEButton3:
                return [[gamePad buttonX] isPressed];
            case OEPCEButton2:
                return [[gamePad buttonA] isPressed];
            case OEPCEButton1:
                return [[gamePad buttonB] isPressed];
            case OEPCEButton4:
                return [[gamePad leftShoulder] isPressed];
            case OEPCEButton5:
                return [[gamePad buttonY] isPressed];
            case OEPCEButton6:
                return [[gamePad rightShoulder] isPressed];
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
            case OEPCEButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OEPCEButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OEPCEButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OEPCEButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OEPCEButton2:
                return [[gamePad buttonA] isPressed];
                break;
            case OEPCEButton1:
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
            case OEPSXLeftAnalogUp:
                return [pad leftThumbstick].up.value;
            case OEPSXLeftAnalogDown:
                return [pad leftThumbstick].down.value;
            case OEPSXLeftAnalogLeft:
                return [pad leftThumbstick].left.value;
            case OEPSXLeftAnalogRight:
                return [pad leftThumbstick].right.value;
            case OEPSXRightAnalogUp:
                return [pad rightThumbstick].up.value;
            case OEPSXRightAnalogDown:
                return [pad rightThumbstick].down.value;
            case OEPSXRightAnalogLeft:
                return [pad rightThumbstick].left.value;
            case OEPSXRightAnalogRight:
                return [pad rightThumbstick].right.value;
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *pad = [controller gamepad];
        switch (buttonID) {
            case OEPSXLeftAnalogUp:
                return [pad dpad].up.value;
            case OEPSXLeftAnalogDown:
                return [pad dpad].down.value;
            case OEPSXLeftAnalogLeft:
                return [pad dpad].left.value;
            case OEPSXLeftAnalogRight:
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
            case OEPSXLeftAnalogUp:
                return [pad leftThumbstick].up.value;
            case OEPSXLeftAnalogDown:
                return [pad leftThumbstick].down.value;
            case OEPSXLeftAnalogLeft:
                return [pad leftThumbstick].left.value;
            case OEPSXLeftAnalogRight:
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
            case OEVBButtonLeftUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case OEVBButtonLeftDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case OEVBButtonLeftLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case OEVBButtonLeftRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case OEVBButtonRightUp:
                return [[[pad rightThumbstick] up] isPressed];
            case OEVBButtonRightDown:
                return [[[pad rightThumbstick] down] isPressed];
            case OEVBButtonRightLeft:
                return [[[pad rightThumbstick] left] isPressed];
            case OEVBButtonRightRight:
                return [[[pad rightThumbstick] right] isPressed];
            case OEVBButtonB:
                return [[pad buttonB] isPressed]?:[[pad buttonX] isPressed];
            case OEVBButtonA:
                return [[pad buttonA] isPressed]?:[[pad buttonY] isPressed];
            case OEVBButtonL:
                return [[pad leftShoulder] isPressed];
            case OEVBButtonR:
                return [[pad rightShoulder] isPressed];
            case OEVBButtonStart:
                return [[pad leftTrigger] isPressed];
            case OEVBButtonSelect:
                return [[pad rightTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case OEVBButtonLeftUp:
                return [[dpad up] isPressed];
            case OEVBButtonLeftDown:
                return [[dpad down] isPressed];
            case OEVBButtonLeftLeft:
                return [[dpad left] isPressed];
            case OEVBButtonLeftRight:
                return [[dpad right] isPressed];
            case OEVBButtonB:
                return [[pad buttonB] isPressed];
            case OEVBButtonA:
                return [[pad buttonA] isPressed];
            case OEVBButtonL:
                return [[pad leftShoulder] isPressed];
            case OEVBButtonR:
                return [[pad rightShoulder] isPressed];
            case OEVBButtonStart:
                return [[pad buttonX] isPressed];
            case OEVBButtonSelect:
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
            case OEVBButtonLeftUp:
                return [[dpad up] value] > 0.5;
                break;
            case OEVBButtonLeftDown:
                return [[dpad down] value] > 0.5;
                break;
            case OEVBButtonLeftLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OEVBButtonLeftRight:
                return [[dpad right] value] > 0.5;
                break;
            case OEVBButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OEVBButtonB:
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
            case OEWSButtonX1:
                return [[[pad leftThumbstick] up] isPressed];
            case OEWSButtonX3:
                return [[[pad leftThumbstick] down] isPressed];
            case OEWSButtonX4:
                return [[[pad leftThumbstick] left] isPressed];
            case OEWSButtonX2:
                return [[[pad leftThumbstick] right] isPressed];
            case OEWSButtonY1:
                return [[dpad up] isPressed];
            case OEWSButtonY3:
                return [[dpad down] isPressed];
            case OEWSButtonY4:
                return [[dpad left] isPressed];
            case OEWSButtonY2:
                return [[dpad right] isPressed];
            case OEWSButtonA:
                return [[pad buttonX] isPressed];
            case OEWSButtonB:
                return [[pad buttonA] isPressed];
            case OEWSButtonStart:
                return [[pad buttonB] isPressed];
            case OEWSButtonSound:
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
            case OEWSButtonX1:
                return [[dpad up] isPressed];
            case OEWSButtonX3:
                return [[dpad down] isPressed];
            case OEWSButtonX4:
                return [[dpad left] isPressed];
            case OEWSButtonX2:
                return [[dpad right] isPressed];
            case OEWSButtonA:
                return [[pad buttonX] isPressed];
            case OEWSButtonB:
                return [[pad buttonA] isPressed];
            case OEWSButtonStart:
                return [[pad buttonB] isPressed];
            case OEWSButtonSound:
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
            case OEWSButtonX1:
                return [[dpad up] value] > 0.5;
                break;
            case OEWSButtonX3:
                return [[dpad down] value] > 0.5;
                break;
            case OEWSButtonX4:
                return [[dpad left] value] > 0.5;
                break;
            case OEWSButtonX2:
                return [[dpad right] value] > 0.5;
                break;
            case OEWSButtonA:
                return [[pad buttonA] isPressed];
                break;
            case OEWSButtonB:
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
    if (systemType == vb)
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

- (void)swapDisc:(NSUInteger)discNumber {
    [self setPauseEmulation:NO];
    
    uint32_t index = discNumber - 1; // 0-based index
    MDFNI_SetMedia(0, 0, 0, 0); // open drive/eject disc

    // Open/eject needs a bit of delay, so wait 1 second until inserting new disc
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        MDFNI_SetMedia(0, 2, index, 0); // close drive/insert disc (2 = close)
    });
}

- (NSUInteger)discCount {
    return maxDiscs ? maxDiscs : 1;
}

- (BOOL)supportsDiskSwapping {
    switch (systemType) {
        case psx:
            return [self discCount] > 1;
        case neogeo:
        case lynx:
        case pce:
        case pcfx:
        case vb:
        case wswan:
            return NO;
    }
}

@end
