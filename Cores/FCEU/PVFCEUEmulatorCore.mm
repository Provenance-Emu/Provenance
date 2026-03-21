/*
 Copyright (c) 2015, OpenEmu Team
 
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

#import "PVFCEUEmulatorCore.h"

@import PVLoggingObjC;
@import PVEmulatorCore;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVAudio;
#if !TARGET_OS_TV
@import AVFoundation;
#endif

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

#include <os/lock.h>
#include "fceux/src/fceu.h"
#include "fceux/src/driver.h"
#include "fceux/src/input.h"
#include "fceux/src/sound.h"
#include "fceux/src/movie.h"
#include "fceux/src/palette.h"
#include "fceux/src/state.h"
#include "fceux/src/emufile.h"
#include "zlib.h"

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

#define WIDTH 256
#define HEIGHT 240

extern uint8 *XBuf;
static uint32_t palette[256];

// Famicom controller 2 had a built-in microphone. FCEU emulates this via
// replaceP2StartWithMicrophone: when true, P2 Start drives a toggling mic bit.
// We expose this global so the bridge can enable Famicom mic mode and feed
// real iOS microphone audio into the P2 Start bit.
extern bool replaceP2StartWithMicrophone;

// P2 Start occupies bit 3 of joy[1], which FCEU extracts as: joy[1] = pad[1][0] >> 8.
// So to drive joy[1] bit 3 (JOY_START), we set bit 11 in pad[1][0].
static const uint32_t kFCMicBit = (JOY_START << 8);  // 0x0800

#if !TARGET_OS_TV
// RMS threshold for considering microphone audio "active" (0.0–1.0 range).
static const float kFCMicThreshold = 0.015f;
#endif

@interface PVFCEUEmulatorCoreBridge ()
{
    uint32_t *videoBuffer;
    uint8_t *pXBuf;
    int32_t *soundBuffer;
    int32_t soundSize;

    NSUInteger currentDisc;

    // Famicom microphone support
#if !TARGET_OS_TV
    AVAudioEngine *_micEngine;
#endif
    _Atomic(BOOL) _micAudioActive;  // set by audio tap; applied in executeFrame

    // Protects _lightGunPosition, _lightGunTrigger, _lightGunIsOffscreen.
    // Written on the main thread by LightGunResponder callbacks;
    // read on the emulator thread in executeFrameSkippingFrame:.
    os_unfair_lock _lightGunLock;
}

#if !TARGET_OS_TV
- (void)startFamicomMicMonitoring;
- (void)stopFamicomMicMonitoring;
#endif

@end

@implementation PVFCEUEmulatorCoreBridge

static __weak PVFCEUEmulatorCoreBridge *_current;

- (id)init
{
    if((self = [super init]))
    {
        soundBuffer = nil;
        pXBuf = nil;
        soundSize = 0;

        videoBuffer = (uint32_t *)malloc(WIDTH * HEIGHT * 4);
        currentDisc = 1;
        _lightGunLock = OS_UNFAIR_LOCK_INIT;
    }

	_current = self;

	return self;
}

- (void)dealloc
{
    free(videoBuffer);
}

- (void)internalSwapDisc:(NSUInteger)discNumber
{
    if (discNumber == currentDisc) {
        WLOG(@"Won't swap for same disc number <%lul>", (unsigned long)discNumber);
        return;
    }
    currentDisc = discNumber;
    
    [self setPauseEmulation:NO];

    FCEUI_FDSInsert();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        FCEUI_FDSSelect();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            FCEUI_FDSInsert();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            });
        });
    });
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error
{
    memset(pad, 0, sizeof(uint32_t) * PVNESButtonCount);

    //newppu = 0 default off, set 1 to enable

    FCEUI_Initialize();

    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    //FCEUI_SetBaseDirectory([[self biosDirectoryPath] UTF8String]); unused for now
    FCEUI_SetDirOverride(FCEUIOD_NV, strdup([[batterySavesDirectory path] UTF8String]));
    FCEUI_SetDirOverride(FCEUIOD_FDSROM, strdup([[self BIOSPath] UTF8String]));

    FCEUI_SetSoundVolume(256);
    FCEUI_Sound(48000);

    FCEUGI *FCEUGameInfo;
    FCEUGameInfo = FCEUI_LoadGame([path UTF8String], 1, false);

    if(!FCEUGameInfo) {
		if(error != NULL) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to load game.",
				NSLocalizedFailureReasonErrorKey: @"FCEUI failed to load game.",
				NSLocalizedRecoverySuggestionErrorKey: @"Check the file isn't corrupt and supported FCEUI ROM format."
			};

			NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
													code:PVEmulatorCoreErrorCodeCouldNotLoadRom
												userInfo:userInfo];

			*error = newError;
		}
        return NO;
    }

    //DLOG(@"FPS: %d", FCEUI_GetDesiredFPS() >> 24); // Hz

    // Check whether the ROM requests a Zapper on either controller port.
    // Port 1 = standard NES Zapper (Duck Hunt, Hogan's Alley, Wild Gunman).
    // Port 0 = VS UniSystem Zapper (set by vsuni.cpp for VS Duck Hunt, etc.).
    // FCEUGameInfo->input[] is populated by the ROM loader from the iNES/UNIF
    // header or a hard-coded table.
    BOOL zapperOnPort0 = (FCEUGameInfo->input[0] == SI_ZAPPER);
    BOOL zapperOnPort1 = (FCEUGameInfo->input[1] == SI_ZAPPER);
    _zapperEnabled = zapperOnPort0 || zapperOnPort1;

    if (_zapperEnabled) {
        memset(_zapperData, 0, sizeof(_zapperData));
    }

    // Port 0
    if (zapperOnPort0) {
        FCEUI_SetInput(0, SI_ZAPPER, _zapperData, 0);
        ILOG(@"[FCEU] Zapper detected on port 0 (VS UniSystem) — LightGunResponder active.");
    } else {
        FCEUI_SetInput(0, SI_GAMEPAD, &pad[0], 0);
    }

    // Port 1
    if (zapperOnPort1) {
        FCEUI_SetInput(1, SI_ZAPPER, _zapperData, 0);
        ILOG(@"[FCEU] Zapper detected on port 1 — LightGunResponder active.");
    } else {
        FCEUI_SetInput(1, SI_GAMEPAD, &pad[1], 0);
    }

    // 4-Player / Fourscore setup.
    // FCEU packs P3 into bits 16-23 of pad[0] and P4 into bits 24-31 of pad[1].
    // No extra FCEUI_SetInput calls are needed; the existing port 0/1 buffers carry all 4 players.
    {
        // 0 = Auto (detect from ROM), 1 = Always On, 2 = Off
        NSInteger fsMode = [[NSUserDefaults standardUserDefaults]
                            integerForKey:@"PVFCEUOptions.4-Player / Fourscore"];
        BOOL romRequiresFourscore = (FCEUGameInfo->inputfc == SIFC_4PLAYER);
        if (fsMode == 1 || (fsMode == 0 && romRequiresFourscore)) {
            FCEUI_SetInputFourscore(true);
        } else {
            FCEUI_SetInputFourscore(false);
        }
    }

    FCEU_ResetPalette();

#if !TARGET_OS_TV
    // Famicom mic mode is opt-in: setting replaceP2StartWithMicrophone unconditionally
    // nullifies the P2 Start button (FCEU input.cpp:128-131), breaking all NES 2-player
    // games. Only enable when the user has opted in via the "Famicom Microphone" option.
    BOOL famicomMicEnabled = [[NSUserDefaults standardUserDefaults]
                              boolForKey:@"PVFCEUOptions.Famicom Microphone"];
    if (famicomMicEnabled) {
        [self startFamicomMicMonitoring];
    }
#endif

    return YES;
}

- (void)executeFrame
{
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip
{
    pXBuf = 0;
    soundSize = 0;

    // Apply Famicom mic state each frame. updateControllers clears P2 Start each frame,
    // so we re-apply the mic bit here immediately before FCEU reads the input.
    if (_micAudioActive) {
        pad[1][0] |= kFCMicBit;
    } else {
        pad[1][0] &= ~kFCMicBit;
    }

    // Feed Zapper position/trigger into FCEU's UpdateZapper data buffer.
    // UpdateZapper(int w, void *data, int arg) expects uint32[3]: x, y, button.
    // Bit 0 of button = trigger fired; bit 1 = offscreen (forces a miss).
    if (_zapperEnabled) {
        // Snapshot light gun state — written on the main thread by LightGunResponder
        // callbacks, read here on the emulator thread.
        os_unfair_lock_lock(&_lightGunLock);
        CGPoint lightGunPos     = _lightGunPosition;
        BOOL    lightGunTrigger = _lightGunTrigger;
        BOOL    lightGunOffscreen = _lightGunIsOffscreen;
        os_unfair_lock_unlock(&_lightGunLock);

        // Convert normalized [0,1] light gun position to pixel coordinates and clamp
        // to valid NES screen range ([0, WIDTH-1] x [0, HEIGHT-1]) to avoid
        // out-of-bounds access in FCEU's XBuf (WIDTH and HEIGHT defined at top of file).
        int32_t zapperX = (int32_t)(lightGunPos.x * WIDTH);
        int32_t zapperY = (int32_t)(lightGunPos.y * HEIGHT);
        if (zapperX < 0) {
            zapperX = 0;
        } else if (zapperX >= WIDTH) {
            zapperX = WIDTH - 1;
        }
        if (zapperY < 0) {
            zapperY = 0;
        } else if (zapperY >= HEIGHT) {
            zapperY = HEIGHT - 1;
        }
        _zapperData[0] = (uint32_t)zapperX;
        _zapperData[1] = (uint32_t)zapperY;

        // Only set button bits when a shot is actually being fired.
        // UpdateZapper treats any non-zero (ptr[2] & 3) as a click edge, so the
        // offscreen/miss bit (2) must not be set during idle off-screen movement.
        uint32_t button = 0;
        if (lightGunTrigger) {
            button |= 1; // bit 0: trigger pressed
            if (lightGunOffscreen) {
                button |= 2; // bit 1: offscreen shot → forces ZD[w].mzb|=2 → miss
            }
        }
        _zapperData[2] = button;
    }

    FCEUI_Emulate(&pXBuf, &soundBuffer, &soundSize, 0);

    pXBuf = XBuf;
    for (unsigned y = 0; y < HEIGHT; y++)
        for (unsigned x = 0; x < WIDTH; x++, pXBuf++)
            videoBuffer[y * WIDTH + x] = palette[*pXBuf];

    for (int i = 0; i < soundSize; i++)
        soundBuffer[i] = (soundBuffer[i] << 16) | (soundBuffer[i] & 0xffff);

    [[self ringBufferAtIndex:0] write:soundBuffer size:soundSize << 2];
}

- (void)resetEmulation
{
    ResetNES();
}

- (void)stopEmulation
{
#if !TARGET_OS_TV
    [self stopFamicomMicMonitoring];
    replaceP2StartWithMicrophone = false;
#endif

    FCEUI_CloseGame();
    FCEUI_Kill();

    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return FCEUI_GetDesiredFPS() / 16777216.0;
}

#pragma mark - Video

- (const void *)videoBuffer
{
    return videoBuffer;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, WIDTH, HEIGHT);
}

- (CGSize)aspectSize
{
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize
{
    return CGSizeMake(WIDTH, HEIGHT);
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

#pragma mark - Audio

- (double)audioSampleRate
{
    return FSettings.SndRate;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error  
{
    @synchronized(self) {
        FCEUSS_Save([fileName UTF8String], false);
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error
{
    @synchronized(self) {
        BOOL success = FCEUSS_Load([fileName UTF8String], false);
		if (!success) {
			if(error != NULL) {
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
    }
}

- (NSData *)serializeStateWithError:(NSError **)outError
{
    std::vector<u8> byteVector;
    EMUFILE *emuFile = new EMUFILE_MEMORY(&byteVector);
    NSData *data = nil;
    
    if(FCEUSS_SaveMS(emuFile, Z_NO_COMPRESSION))
    {
        const void *bytes = (const void *)(&byteVector[0]);
        NSUInteger length = byteVector.size();
        
        data = [NSData dataWithBytes:bytes length:length];
    }
    
    delete emuFile;
    return data;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
{
    u8 *bytes = (u8 *)[state bytes];
    size_t length = [state length];
    std::vector<u8> byteVector(bytes, bytes + length);
    EMUFILE *emuFile = new EMUFILE_MEMORY(&byteVector);
    
    BOOL result = FCEUSS_LoadFP(emuFile, SSLOADPARAM_NOBACKUP);
    
    delete emuFile;
    
    return result;
}

#pragma mark - LightGunResponder

- (BOOL)gameSupportsLightGun {
    return _zapperEnabled;
}

- (BOOL)requiresLightGun {
    return NO;
}

- (void)lightGunMovedToPoint:(CGPoint)point isOffscreen:(BOOL)offscreen {
    os_unfair_lock_lock(&_lightGunLock);
    _lightGunPosition    = point;
    _lightGunIsOffscreen = offscreen;
    os_unfair_lock_unlock(&_lightGunLock);
}

- (void)lightGunTriggerDown {
    os_unfair_lock_lock(&_lightGunLock);
    _lightGunTrigger = YES;
    os_unfair_lock_unlock(&_lightGunLock);
}

- (void)lightGunTriggerUp {
    os_unfair_lock_lock(&_lightGunLock);
    _lightGunTrigger = NO;
    os_unfair_lock_unlock(&_lightGunLock);
}

- (void)lightGunReloadDown {
    // Reload = fire an offscreen shot. Both offscreen and trigger must be set
    // so the button logic in executeFrameSkippingFrame: sets bits 0|1 (offscreen shot).
    os_unfair_lock_lock(&_lightGunLock);
    _lightGunIsOffscreen = YES;
    _lightGunTrigger     = YES;
    os_unfair_lock_unlock(&_lightGunLock);
}

- (void)lightGunReloadUp {
    // Clear the trigger; do NOT reset _lightGunIsOffscreen here — the authoritative
    // offscreen state comes from lightGunMovedToPoint:isOffscreen: which may still
    // report that the cursor is offscreen (e.g. if the pointer has not moved).
    os_unfair_lock_lock(&_lightGunLock);
    _lightGunTrigger = NO;
    os_unfair_lock_unlock(&_lightGunLock);
}

#pragma mark - FCEUX internal functions and stubs

// FCEUD_SetInput is called by FCEU when loading a movie that specifies input config.
// We apply the microphone flag from the movie data; other fields are already configured.
void FCEUD_SetInput(bool fourscore, bool microphone, ESI port0, ESI port1, ESIFC fcexp) {
    replaceP2StartWithMicrophone = microphone;
    FCEUI_SetInputFourscore(fourscore);
}

void FCEUD_SetPalette(unsigned char index, unsigned char r, unsigned char g, unsigned char b)
{
    palette[index] = ( r << 16 ) | ( g << 8 ) | b;
}

void FCEUD_GetPalette(unsigned char i, unsigned char *r, unsigned char *g, unsigned char *b) {}
uint64 FCEUD_GetTime(void) {return 0;}
uint64 FCEUD_GetTimeFreq(void) {return 0;}
const char *GetKeyboard(void) {return "";}
bool turbo = false;
bool swapDuty = 0; // some Famicom and NES clones had duty cycle bits swapped
int dendy = 0;
int pal_emulation = 0;
int closeFinishedMovie = 0;
int FCEUD_ShowStatusIcon(void) {return 0;}
int FCEUD_SendData(void *data, uint32 len) {return 1;}
int FCEUD_RecvData(void *data, uint32 len) {return 1;}
FILE *FCEUD_UTF8fopen(const char *fn, const char *mode)
{
    return fopen(fn, mode);
}
EMUFILE_FILE *FCEUD_UTF8_fstream(const char *fn, const char *m)
{
#if 0
	std::ios_base::openmode mode = std::ios_base::binary;
    if(!strcmp(m,"r") || !strcmp(m,"rb"))
        mode |= std::ios_base::in;
    else if(!strcmp(m,"w") || !strcmp(m,"wb"))
        mode |= std::ios_base::out | std::ios_base::trunc;
    else if(!strcmp(m,"a") || !strcmp(m,"ab"))
        mode |= std::ios_base::out | std::ios_base::app;
    else if(!strcmp(m,"r+") || !strcmp(m,"r+b"))
        mode |= std::ios_base::in | std::ios_base::out;
    else if(!strcmp(m,"w+") || !strcmp(m,"w+b"))
        mode |= std::ios_base::in | std::ios_base::out | std::ios_base::trunc;
    else if(!strcmp(m,"a+") || !strcmp(m,"a+b"))
        mode |= std::ios_base::in | std::ios_base::out | std::ios_base::app;
	return new std::fstream(fn,mode);
#else
    return new EMUFILE_FILE(fn, m);
#endif
}
void FCEUD_NetplayText(uint8 *text) {}
void FCEUD_NetworkClose(void) {}
void FCEUD_VideoChanged (void) {}
bool FCEUD_ShouldDrawInputAids() {return false;}
bool FCEUD_PauseAfterPlayback() {return false;}
void FCEUI_AviVideoUpdate(const unsigned char* buffer) {}
bool FCEUI_AviEnableHUDrecording() {return false;}
bool FCEUI_AviIsRecording(void) {return false;}
bool FCEUI_AviDisableMovieMessages() {return true;}
FCEUFILE *FCEUD_OpenArchiveIndex(ArchiveScanRecord &asr, std::string &fname, int innerIndex) {return 0;}
FCEUFILE *FCEUD_OpenArchiveIndex(ArchiveScanRecord &asr, std::string &fname, int innerIndex, int* userCancel) {return 0;}
FCEUFILE *FCEUD_OpenArchive(ArchiveScanRecord &asr, std::string &fname, std::string *innerFilename) {return 0;}
FCEUFILE *FCEUD_OpenArchive(ArchiveScanRecord &asr, std::string &fname, std::string *innerFilename, int* userCancel) {return 0;}
ArchiveScanRecord FCEUD_ScanArchive(std::string fname) { return ArchiveScanRecord(); }
void FCEUD_PrintError(const char *s)
{
    ELOG(@"FCEUX: %s", s);
}
void FCEUD_Message(const char *s)
{
    ILOG(@"FCEUX: %s", s);
}

// MARK: - Famicom Microphone

- (void)startFamicomMicMonitoring {
#if !TARGET_OS_TV
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
        WLOG(@"[FCEU] Microphone access denied — Famicom mic will not work.");
        return;
    }

    __weak typeof(self) weakSelf = self;

    void (^startEngine)(void) = ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSError *sessionError = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord
                 withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
                             AVAudioSessionCategoryOptionMixWithOthers
                       error:&sessionError];
        if (sessionError) {
            ELOG(@"[FCEU] AVAudioSession error: %@", sessionError.localizedDescription);
            return;
        }
        [session setActive:YES error:nil];

        strongSelf->_micEngine = [[AVAudioEngine alloc] init];
        AVAudioInputNode *inputNode = strongSelf->_micEngine.inputNode;
        AVAudioFormat *fmt = [inputNode outputFormatForBus:0];

        [inputNode installTapOnBus:0
                        bufferSize:1024
                            format:fmt
                             block:^(AVAudioPCMBuffer *buf, AVAudioTime *when) {
            typeof(self) s = weakSelf;
            if (!s) return;

            // Compute RMS of the first channel to get the mic audio level.
            float rms = 0.0f;
            const float *channelData = [buf floatChannelData][0];
            AVAudioFrameCount frameCount = buf.frameLength;
            for (AVAudioFrameCount i = 0; i < frameCount; i++) {
                rms += channelData[i] * channelData[i];
            }
            if (frameCount > 0) {
                rms = sqrtf(rms / (float)frameCount);
            }

            // Latch mic activity; applied to pad[1][0] each frame in executeFrameSkippingFrame:
            // to avoid racing with updateControllers which otherwise clears P2 Start each frame.
            s->_micAudioActive = (rms > kFCMicThreshold);
        }];

        NSError *engineError = nil;
        [strongSelf->_micEngine startAndReturnError:&engineError];
        if (engineError) {
            ELOG(@"[FCEU] AVAudioEngine start error: %@", engineError.localizedDescription);
            [inputNode removeTapOnBus:0];
            strongSelf->_micEngine = nil;
        } else {
            // Enable mic mode only after the engine starts successfully.
            // replaceP2StartWithMicrophone nullifies P2 Start reads (FCEU input.cpp:128-131),
            // so it must never be set for standard NES 2-player games.
            replaceP2StartWithMicrophone = true;
            ILOG(@"[FCEU] Famicom microphone monitoring started.");
        }
    };

    if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), startEngine);
            } else {
                WLOG(@"[FCEU] Microphone permission denied — Famicom mic will not work.");
            }
        }];
    } else {
        startEngine();
    }
#else
    ILOG(@"[FCEU] Famicom mic monitoring not supported on tvOS.");
#endif
}

#if !TARGET_OS_TV
- (void)stopFamicomMicMonitoring {
    if (_micEngine) {
        [_micEngine.inputNode removeTapOnBus:0];
        [_micEngine stop];
        _micEngine = nil;
    }
    _micAudioActive = NO;
    pad[1][0] &= ~kFCMicBit;
    ILOG(@"[FCEU] Famicom microphone monitoring stopped.");
}
#endif

@end

#pragma mark - Cheats

@implementation PVFCEUEmulatorCoreBridge (Cheats)

static NSMutableDictionary *fceu_cheatList = nil;

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
    // Lazy initialise cheat dictionary
    if (!fceu_cheatList) {
        fceu_cheatList = [[NSMutableDictionary alloc] init];
    }

    // Sanitize
    code = [[code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

    if (enabled) {
        // Validate the code can be decoded BEFORE storing it
        int addr = 0, val = 0, compare = -1;
        if (!FCEUI_DecodeGG([code UTF8String], &addr, &val, &compare)) {
            return NO;
        }
        // Store the label (type) for the cheat code so it can be used as the name
        [fceu_cheatList setObject:type ?: code forKey:code];
    } else {
        [fceu_cheatList removeObjectForKey:code];
    }

    // Delete all existing FCEU cheats then re-apply the enabled set
    while (FCEUI_DelCheat(0)) {}

    BOOL anyAdded = NO;
    for (NSString *cheatCode in fceu_cheatList) {
        int addr = 0, val = 0, compare = -1;
        NSString *label = fceu_cheatList[cheatCode];
        if (FCEUI_DecodeGG([cheatCode UTF8String], &addr, &val, &compare)) {
            // Game Genie code: type 1 = substitute (only triggers on matching read)
            FCEUI_AddCheat([label UTF8String], (uint32)addr, (uint8)val, compare, 1);
            anyAdded = YES;
        }
    }

    return anyAdded || [fceu_cheatList count] == 0;
}

- (void)resetCheatCodes {
    [fceu_cheatList removeAllObjects];
    // FCEUI_DelCheat(0) deletes the first cheat; FCEU shifts the list after each deletion,
    // so calling it in a loop with index 0 removes all cheats one at a time.
    while (FCEUI_DelCheat(0)) {}
}

@end

#pragma clang diagnostic pop
