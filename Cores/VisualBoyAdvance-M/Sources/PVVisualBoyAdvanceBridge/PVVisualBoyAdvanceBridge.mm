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

#ifndef GLES_SILENCE_DEPRECATION
#define GLES_SILENCE_DEPRECATION 1
#endif

@import PVEmulatorCore;
@import PVCoreBridge;
@import PVCoreObjCBridge;

#import "PVVisualBoyAdvanceBridge.h"

@import PVAudio;
@import PVVisualBoyAdvanceOptions;
@import PVLoggingObjC;

#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
#import <OpenGL/gl3.h>
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
@import GameController;
#else
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#endif

#include <atomic>
#include <memory>

// VBA-M 2.x core (visualboyadvance-m submodule, desktop/non-libretro build).
#include "core/base/message.h"
#include "core/base/sound_driver.h"
#include "core/base/system.h"
#include "core/gba/gba.h"
#include "core/gba/gbaCheats.h"
#include "core/gba/gbaEeprom.h"
#include "core/gba/gbaFlash.h"
#include "core/gba/gbaGlobals.h"
#include "core/gba/gbaRtc.h"
#include "core/gba/gbaSound.h"
// Provenance glue compiled into libvisualboyadvance.
#include "provenance/legacy_state.h"

// ---------------------------------------------------------------------------
// MARK: - RetroAchievements rc_client (HAVE_RCHEEVOS)
// Mirrors PVGambatteBridge: CRcheevos from PVRcheevos SPM; GBA bus addresses.
// ---------------------------------------------------------------------------
#if HAVE_RCHEEVOS
#include "rc_client.h"

static uint32_t pvvba_read_memory(uint32_t address, uint8_t *buffer,
                                  uint32_t num_bytes, rc_client_t *client) {
    (void)client;
    for (uint32_t i = 0; i < num_bytes; ++i) {
        uint32_t addr = address + i;
        uint8_t value = 0xFF;
        if (addr >= 0x02000000 && addr <= 0x0203FFFF) {
            if (g_workRAM) {
                value = g_workRAM[addr - 0x02000000];
            }
        } else if (addr >= 0x03000000 && addr <= 0x03007FFF) {
            if (g_internalRAM) {
                value = g_internalRAM[addr - 0x03000000];
            }
        } else if (addr >= 0x06000000 && addr <= 0x06017FFF) {
            if (g_vram) {
                value = g_vram[addr - 0x06000000];
            }
        }
        buffer[i] = value;
    }
    return num_bytes;
}

static void pvvba_server_call(const rc_api_request_t *request,
                              rc_client_server_callback_t callback,
                              void *callback_data,
                              rc_client_t * __unused client) {
    if (!request->url) {
        rc_api_server_response_t empty = {};
        empty.http_status_code = 0;
        callback(&empty, callback_data);
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:request->url]];
    if (!url) {
        rc_api_server_response_t empty = {};
        empty.http_status_code = 400;
        callback(&empty, callback_data);
        return;
    }
    NSMutableURLRequest *urlReq = [NSMutableURLRequest requestWithURL:url];
    urlReq.timeoutInterval = 30.0;
    const char *postData = request->post_data;
    if (postData && *postData) {
        urlReq.HTTPMethod = @"POST";
        urlReq.HTTPBody = [NSData dataWithBytes:postData length:strlen(postData)];
        [urlReq setValue:@"application/x-www-form-urlencoded"
      forHTTPHeaderField:@"Content-Type"];
    } else {
        urlReq.HTTPMethod = @"GET";
    }
    [urlReq setValue:@"Provenance/PVRcheevos" forHTTPHeaderField:@"User-Agent"];
    [[[NSURLSession sharedSession]
        dataTaskWithRequest:urlReq
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              rc_api_server_response_t resp = {};
              if (data && !error) {
                  resp.body             = (const char *)data.bytes;
                  resp.body_length      = (uint32_t)data.length;
                  resp.http_status_code = (int)[(NSHTTPURLResponse *)response statusCode];
              } else {
                  resp.http_status_code = 0;
              }
              callback(&resp, callback_data);
          }] resume];
}

static void pvvba_event_handler(const rc_client_event_t *event, rc_client_t *client) {
    PVVisualBoyAdvanceBridge *bridge = (__bridge PVVisualBoyAdvanceBridge *)
                                        rc_client_get_userdata(client);
    if (!bridge) { return; }

    switch (event->type) {
        case RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED: {
            const rc_client_achievement_t *ach = event->achievement;
            NSString *badgeName = ach->badge_name ? @(ach->badge_name) : nil;
            NSURL *badgeURL = badgeName.length
                ? [NSURL URLWithString:[NSString stringWithFormat:
                      @"https://media.retroachievements.org/Badge/%@.png", badgeName]]
                : nil;
            [bridge rcAchievementTriggeredWithID:ach->id
                                         title:ach->title       ? @(ach->title)       : nil
                                   description:ach->description ? @(ach->description) : nil
                                        points:ach->points
                                      badgeURL:badgeURL
                                    isHardcore:(BOOL)rc_client_get_hardcore_enabled(client)];
            break;
        }
        case RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW: {
            const rc_client_achievement_t *ach = event->achievement;
            [bridge rcAchievementProgressWithID:ach->id
                                        title:ach->title ? @(ach->title) : nil
                                 progressText:ach->measured_progress ? @(ach->measured_progress) : nil];
            break;
        }
        case RC_CLIENT_EVENT_LEADERBOARD_STARTED: {
            const rc_client_leaderboard_t *lb = event->leaderboard;
            [bridge rcLeaderboardStartedWithID:lb->id
                                       title:lb->title       ? @(lb->title)       : nil
                                 description:lb->description ? @(lb->description) : nil
                                   scoreText:lb->tracker_value ? @(lb->tracker_value) : nil];
            break;
        }
        case RC_CLIENT_EVENT_LEADERBOARD_FAILED:
            if (event->leaderboard != NULL) {
                [bridge rcLeaderboardFailedWithID:event->leaderboard->id];
            }
            break;
        case RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED: {
            const rc_client_leaderboard_t *lb = event->leaderboard;
            [bridge rcLeaderboardSubmittedWithID:lb->id
                                         title:lb->title       ? @(lb->title)       : nil
                                   description:lb->description ? @(lb->description) : nil
                                     scoreText:lb->tracker_value ? @(lb->tracker_value) : nil];
            break;
        }
        default:
            break;
    }
}
#endif // HAVE_RCHEEVOS

EmulatedSystem vba;
int emulating = 0;
uint32_t pad[PVGBAButtonCount];

// The core expects the embedder to instantiate this (core/base/system.h).
// Every field the bridge relies on is set again on each load.
struct CoreOptions coreOptions;

/// GBA BIOS file name inside `BIOSPath`.
static NSString * const PVVBABIOSFileName = @"GBA.BIOS";
/// Flash sizes vba-over.ini may set (64K / 128K carts).
static const int PVVBAFlash64K = 0x10000;
static const int PVVBAFlash128K = 0x20000;
/// Size VBA-M 1.8 wrote SRAM battery saves at (the chip is 32K).
static const NSUInteger PVVBALegacySRAMSaveSize = 0x10000;
/// Sample rate the core mixes at.
static const long PVVBASampleRate = 32768;
/// Boktai solar sensor reading with no light sensor (libretro's default).
static const uint8_t PVVBASensorDarknessDefault = 0xE8;

static __weak PVVisualBoyAdvanceBridge *_current;

@interface PVVisualBoyAdvanceBridge ()
{
    uint8_t *videoBuffer;
    NSURL *_romFile, *_saveFile;

    NSString *_romID;
    BOOL _enableRTC, _enableMirroring, _useBIOS, _haveFrame, _migratingSave;
    /// Which vba-over.ini keys the current game's entry actually sets.
    BOOL _hasRTCOverride, _hasFlashSizeOverride;
    int _flashSize, _cpuSaveType;
    /// Save type resolved at load (GBA_SAVE_*, never AUTO). It is a property
    /// of the cart, re-applied after loading a converted legacy save state.
    int _resolvedSaveType;
#if HAVE_RCHEEVOS
    rc_client_t *_rcClient;
#endif
    std::atomic<bool> _achievementsActive;
}
- (void)loadOverrides:(NSString *)gameID;
- (void)resolveSaveTypeForROMSize:(int)romSize;
- (void)writeSaveFile;
- (void)migrateSaveFile;
/// Called from `pvvba_load_callback` / `pvvba_login_callback` (cannot use private ivars from static C functions).
- (void)pvvba_applyAchievementsLoadResult:(BOOL)success;
@end

/// Fills the 15-bit -> 32-bit colour lookup the GBA renderer reads.
/// VBA-M 1.8 shipped this as utilUpdateSystemColorMaps(false) in Util.cpp;
/// 2.x moved it into the frontends.
static void pvvba_updateColorMaps(void) {
    for (int i = 0; i < 0x10000; i++) {
        systemColorMap32[i] = ((i & 0x1f) << systemRedShift) |
            (((i & 0x3e0) >> 5) << systemGreenShift) |
            (((i & 0x7c00) >> 10) << systemBlueShift);
    }
}

@implementation PVVisualBoyAdvanceBridge
@synthesize valueChangedHandler;

#if !TARGET_OS_WATCH
/// Required by `EmulatorCoreControllerDataSource` (`controller(forPlayer:)` in Swift).
- (GCController * _Nullable)controllerForPlayer:(NSUInteger)player {
    switch (player) {
        case 1: return self.controller1;
        case 2: return self.controller2;
        case 3: return self.controller3;
        case 4: return self.controller4;
        case 5: return self.controller5;
        case 6: return self.controller6;
        case 7: return self.controller7;
        case 8: return self.controller8;
        default: return nil;
    }
}
#endif

- (instancetype)init {
    if((self = [super init])) {
        self->videoBuffer = (uint8_t *) malloc(gbaWidth * gbaHeight * 4);
        vba = GBASystem;
        _achievementsActive.store(false);
    }

    _current = self;

    return self;
}

- (void)dealloc {
#if HAVE_RCHEEVOS
    if (_rcClient) {
        rc_client_destroy(_rcClient);
        _rcClient = NULL;
    }
#endif
    if(self->videoBuffer) {
        free(self->videoBuffer);
        self->videoBuffer = nil;
    }
}

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    memset(pad, 0, sizeof(uint32_t) * PVGBAButtonCount);

    self->_romFile = [NSURL fileURLWithPath:path];

    // Options the core reads at load. CoreOptions' own defaults differ from
    // Provenance's (e.g. skipSaveGameBattery = 1, mirroringEnable = true).
    coreOptions.skipBios = VisualBoyAdvanceOptions.skipBios;
    coreOptions.cpuDisableSfx = VisualBoyAdvanceOptions.cpuDisableSfx;
    coreOptions.speedHack = VisualBoyAdvanceOptions.speedHack;
    coreOptions.skipSaveGameBattery = VisualBoyAdvanceOptions.skipSaveGameBattery;
    coreOptions.skipSaveGameCheats = VisualBoyAdvanceOptions.skipSaveGameCheats;
    coreOptions.cheatsEnabled = 1;

    int romSize = CPULoadRom([path UTF8String]);

    if(romSize == 0) {
		if(error != NULL) {
			NSDictionary *userInfo = @{
				NSLocalizedDescriptionKey: @"Failed to load game.",
				NSLocalizedFailureReasonErrorKey: @"VisualBoyAdvanced failed to load ROM.",
				NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format VisualBoyAdvanced supports."
			};

			NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
													code:PVEmulatorCoreErrorCodeCouldNotLoadRom
												userInfo:userInfo];

			*error = newError;
		}
        return NO;
    }

    pvvba_updateColorMaps();

    // Read the cart's Game ID
    char gameID[5];
    gameID[0] = g_rom[0xac];
    gameID[1] = g_rom[0xad];
    gameID[2] = g_rom[0xae];
    gameID[3] = g_rom[0xaf];
    gameID[4] = 0;

    DLOG(@"VBA: GameID in ROM is: %s\n", gameID);

    // Load per-game settings from vba-over.ini
    [self loadOverrides:[NSString stringWithFormat:@"%s", gameID]];

    // Check if BIOS file even exists
    NSString *biosPath = [self.BIOSPath stringByAppendingPathComponent:PVVBABIOSFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:biosPath]) {
        ILOG(@"BIOS found at %@. Will use.", biosPath);
        self->_useBIOS = YES;
    } else {
        if (self->_useBIOS) {
			if(error != NULL) {
				NSDictionary *userInfo = @{
					NSLocalizedDescriptionKey: @"Failed to load game.",
					NSLocalizedFailureReasonErrorKey: @"vba-over.ini states this ROM requires BIOS but none found at: %@.\nPlease install this bios.",
					NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format VisualBoyAdvanced supports."
				};

				NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
														code:PVEmulatorCoreErrorCodeCouldNotLoadRom
													userInfo:userInfo];

				*error = newError;
			}
            return NO;
        }

        self->_useBIOS = NO;
    }

    // Save type, flash size and RTC, in the order upstream's desktop frontend
    // (src/wx/panel.cpp) uses: after CPULoadRom, before CPUInit/CPUReset.
    [self resolveSaveTypeForROMSize:romSize];

    coreOptions.mirroringEnable = self->_enableMirroring;
    doMirroring(coreOptions.mirroringEnable);

    soundInit();
    soundSetSampleRate(PVVBASampleRate);

    CPUInit(self->_useBIOS ? biosPath.UTF8String : 0, self->_useBIOS);
    CPUReset();

    // Load battery save or migrate old one
    NSString *extensionlessFilename = [[self->_romFile lastPathComponent] stringByDeletingPathExtension];
    NSString *batterySavesDirectory = [self batterySavesPath];
    if([batterySavesDirectory length]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }

    self->_saveFile = [NSURL fileURLWithPath:[batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav2"]]];

    if ([self->_saveFile checkResourceIsReachableAndReturnError:nil] && vba.emuReadBattery([[self->_saveFile path] UTF8String])) {
        ILOG(@"VBA: Battery loaded");
    }
    else {
        [self migrateSaveFile];
    }
    emulating = 1;

#if HAVE_RCHEEVOS
    if (!_rcClient) {
        _rcClient = rc_client_create(pvvba_read_memory, pvvba_server_call);
        if (_rcClient) {
            rc_client_set_userdata(_rcClient, (__bridge void *)self);
            rc_client_set_event_handler(_rcClient, pvvba_event_handler);
        }
    }
#endif

    return YES;
}

/// Resolves the cart's save type so it is never left at GBA_SAVE_AUTO: with
/// AUTO, VBA-M 2.x's CPUWriteBatteryFile() writes nothing.
/// flashDetectSaveType() scans the ROM for its SDK save-library string and
/// the Seiko RTC string (SIIRTC_V) and sets save type, flash size and RTC;
/// the keys the game's vba-over.ini entry sets are then applied on top.
/// (The 1.8 core Provenance shipped forced the RTC on for every game; 2.x
/// enables it per game from that scan instead.)
- (void)resolveSaveTypeForROMSize:(int)romSize {
    coreOptions.cpuSaveType = self->_cpuSaveType;

    flashDetectSaveType(romSize);
    if (coreOptions.cpuSaveType != GBA_SAVE_AUTO) {
        coreOptions.saveType = coreOptions.cpuSaveType;
    }

    if (self->_hasFlashSizeOverride && (self->_flashSize == PVVBAFlash64K || self->_flashSize == PVVBAFlash128K)) {
        flashSetSize(self->_flashSize);
    }
    if (self->_hasRTCOverride) {
        rtcEnable(self->_enableRTC);
    }
    // The clock only follows the wall clock when this is set too (gbaRtc.cpp).
    coreOptions.rtcEnabled = rtcIsEnabled();

    self->_resolvedSaveType = coreOptions.saveType;
    DLOG(@"VBA: saveType %d (ini %d) flashSize %d rtc %d", coreOptions.saveType, self->_cpuSaveType, g_flashSize, coreOptions.rtcEnabled);
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
    self->_haveFrame = NO;
    while (!self->_haveFrame) { vba.emuMain(vba.emuCount); }
    [self tickAchievements];
}

- (void)resetEmulation { vba.emuReset(); }

- (void)stopEmulation {
    [super stopEmulation]; //Leave emulation loop first

#if HAVE_RCHEEVOS
    if (_rcClient) {
        rc_client_unload_game(_rcClient);
        rc_client_destroy(_rcClient);
        _rcClient = NULL;
    }
    _achievementsActive.store(false);
#endif

    [self writeSaveFile];

    vba.emuCleanUp();
    soundShutdown();
}

- (NSTimeInterval)frameInterval {
    return 59.727501;
}

# pragma mark - RetroAchievements

- (void *)ewramBasePtr {
    return (void *)g_workRAM;
}

- (void *)iwramBasePtr {
    return (void *)g_internalRAM;
}

- (void *)vbaVramBasePtr {
    return (void *)g_vram;
}

- (BOOL)achievementsActive {
    return _achievementsActive.load();
}

- (void)tickAchievements {
#if HAVE_RCHEEVOS
    if (_rcClient && _achievementsActive.load()) {
        rc_client_do_frame(_rcClient);
    }
#endif
}

#if HAVE_RCHEEVOS

typedef struct pvvba_load_ctx {
    void *bridge;
    void *completion;
} pvvba_load_ctx_t;

static void pvvba_load_callback(int result, const char * __unused error_message,
                                rc_client_t * __unused client, void *userdata) {
    pvvba_load_ctx_t *ctx = (pvvba_load_ctx_t *)userdata;
    PVVisualBoyAdvanceBridge *bridge = (__bridge_transfer PVVisualBoyAdvanceBridge *)ctx->bridge;
    void (^completion)(BOOL) = (__bridge_transfer void (^)(BOOL))ctx->completion;
    ctx->completion = NULL;
    free(ctx);

    BOOL success = (result == RC_OK);
    [bridge pvvba_applyAchievementsLoadResult:success];
    if (completion) { completion(success); }
}

typedef struct pvvba_login_ctx {
    void *bridge;
    void *gameHash;
    void *completion;
} pvvba_login_ctx_t;

static void pvvba_login_callback(int result, const char * __unused error_message,
                                 rc_client_t *client, void *userdata) {
    pvvba_login_ctx_t *lCtx = (pvvba_login_ctx_t *)userdata;
    PVVisualBoyAdvanceBridge *bridge = (__bridge_transfer PVVisualBoyAdvanceBridge *)lCtx->bridge;
    NSString *hash               = (__bridge_transfer NSString *)lCtx->gameHash;
    void (^completion)(BOOL)     = (__bridge_transfer void (^)(BOOL))lCtx->completion;
    lCtx->completion = NULL;
    free(lCtx);

    if (result != RC_OK) {
        [bridge pvvba_applyAchievementsLoadResult:NO];
        if (completion) { completion(NO); }
        return;
    }

    pvvba_load_ctx_t *loadCtx = (pvvba_load_ctx_t *)malloc(sizeof(pvvba_load_ctx_t));
    if (!loadCtx) {
        [bridge pvvba_applyAchievementsLoadResult:NO];
        if (completion) { completion(NO); }
        return;
    }
    loadCtx->bridge     = (__bridge_retained void *)bridge;
    loadCtx->completion = completion ? (__bridge_retained void *)[completion copy] : NULL;
    rc_client_begin_load_game(client, hash.UTF8String, pvvba_load_callback, loadCtx);
}

#endif // HAVE_RCHEEVOS

- (void)loadAchievementsForGameHash:(NSString *)gameHash
                         completion:(void (^)(BOOL success))completion {
#if HAVE_RCHEEVOS
    if (!_rcClient) {
        _achievementsActive.store(false);
        if (completion) { completion(NO); }
        return;
    }

    if (rc_client_get_user_info(_rcClient) != NULL) {
        pvvba_load_ctx_t *ctx = (pvvba_load_ctx_t *)malloc(sizeof(pvvba_load_ctx_t));
        if (!ctx) {
            _achievementsActive.store(false);
            if (completion) { completion(NO); }
            return;
        }
        ctx->bridge     = (__bridge_retained void *)self;
        ctx->completion = completion ? (__bridge_retained void *)[completion copy] : NULL;
        rc_client_begin_load_game(_rcClient, gameHash.UTF8String, pvvba_load_callback, ctx);
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults stringForKey:@"ra_username"];
    NSString *token    = [defaults stringForKey:@"ra_session_token"];
    if (!username.length || !token.length) {
        _achievementsActive.store(false);
        if (completion) { completion(NO); }
        return;
    }

    pvvba_login_ctx_t *lCtx = (pvvba_login_ctx_t *)malloc(sizeof(pvvba_login_ctx_t));
    if (!lCtx) {
        _achievementsActive.store(false);
        if (completion) { completion(NO); }
        return;
    }
    lCtx->bridge     = (__bridge_retained void *)self;
    lCtx->gameHash   = (__bridge_retained void *)[gameHash copy];
    lCtx->completion = completion ? (__bridge_retained void *)[completion copy] : NULL;
    rc_client_begin_login_with_token(_rcClient, username.UTF8String, token.UTF8String,
                                     pvvba_login_callback, lCtx);
#else
    _achievementsActive.store(false);
    if (completion) { completion(NO); }
#endif
}

- (void)unloadAchievements {
#if HAVE_RCHEEVOS
    if (_rcClient) {
        rc_client_unload_game(_rcClient);
    }
#endif
    _achievementsActive.store(false);
}

- (void)pvvba_applyAchievementsLoadResult:(BOOL)success {
    _achievementsActive.store(success);
}

# pragma mark - Video

- (const void *)videoBuffer { return self->videoBuffer; }

- (CGRect)screenRect { return CGRectMake(0, 0, 240, 160); }

- (CGSize)bufferSize { return CGSizeMake(240, 160); }

- (CGSize)aspectSize { return CGSizeMake(3, 2); }

- (GLenum)pixelFormat { return GL_BGRA; }

- (GLenum)pixelType { return GL_UNSIGNED_BYTE; }

- (GLenum)internalPixelFormat { return GL_RGBA; }

# pragma mark - Audio

- (double)audioSampleRate {
    double samplerate = soundGetSampleRate();
    if(samplerate < PVVBASampleRate) {
        samplerate = PVVBASampleRate;
    }
    return samplerate;
}

- (NSUInteger)channelCount { return 2; }

# pragma mark - Save States

static NSError *pvvba_stateError(NSInteger code, NSString *description, NSString *reason) {
    return [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                               code:code
                           userInfo:@{
                               NSLocalizedDescriptionKey: description,
                               NSLocalizedFailureReasonErrorKey: reason,
                               NSLocalizedRecoverySuggestionErrorKey: @""
                           }];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        BOOL success = vba.emuWriteState([fileName UTF8String]);
        if (!success && error != NULL) {
            *error = pvvba_stateError(PVEmulatorCoreErrorCodeCouldNotSaveState,
                                      @"Failed to save state.",
                                      @"Core failed to create save state.");
        }
        return success;
    }
}

/// `EmulatorCoreSavesSerializer` exposes this selector (`@objc(loadStateToFileAtPath:error:)`).
/// Accepts states from VBA-M 2.x and from the 1.8-era core Provenance shipped
/// before (see provenance/legacy_state.h); refuses anything else.
- (BOOL)loadStateToFileAtPath:(NSString *)fileName error:(NSError **)error {
    @synchronized(self) {
        const pvvba::StateLoadResult result = pvvba::LoadState(fileName.UTF8String,
                                                               NSTemporaryDirectory().UTF8String);
        NSString *reason = nil;
        switch (result) {
            case pvvba::StateLoadResult::Loaded:
                return YES;
            case pvvba::StateLoadResult::LoadedLegacy:
                // 1.8 stored its own save-type numbering (1 SRAM, 2 FLASH,
                // 3 EEPROM) where 2.x keeps GBA_SAVE_*. The type is a property
                // of the cart, so restore the one resolved at load.
                ILOG(@"VBA: loaded a VBA-M 1.8 save state (upgraded to the 2.x layout)");
                coreOptions.saveType = self->_resolvedSaveType;
                SetSaveType(coreOptions.saveType);
                return YES;
            case pvvba::StateLoadResult::ReadFailed:
                reason = @"Could not read the save state file.";
                break;
            case pvvba::StateLoadResult::Incompatible:
                reason = @"This save state was made by an incompatible version of the VisualBoyAdvance core.";
                break;
            case pvvba::StateLoadResult::CoreRejected:
                reason = @"Core failed to load save state.";
                break;
        }
        if (error != NULL) {
            *error = pvvba_stateError(PVEmulatorCoreErrorCodeCouldNotLoadState,
                                      @"Failed to load state.",
                                      reason);
        }
        return NO;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    return [self loadStateToFileAtPath:fileName error:error];
}

#pragma clang diagnostic pop

# pragma mark - Input

enum {
    KEY_BUTTON_A      = 1 << 0,
    KEY_BUTTON_B      = 1 << 1,
    KEY_BUTTON_SELECT = 1 << 2,
    KEY_BUTTON_START  = 1 << 3,
    KEY_RIGHT         = 1 << 4,
    KEY_LEFT          = 1 << 5,
    KEY_UP            = 1 << 6,
    KEY_DOWN          = 1 << 7,
    KEY_BUTTON_R      = 1 << 8,
    KEY_BUTTON_L      = 1 << 9
};

const int GBAMap[] = {KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_BUTTON_A, KEY_BUTTON_B, KEY_BUTTON_L, KEY_BUTTON_R, KEY_BUTTON_START, KEY_BUTTON_SELECT};

- (void)didPushGBAButton:(PVGBAButton)button forPlayer:(NSInteger)player { pad[player] |= GBAMap[button]; }

- (void)didReleaseGBAButton:(PVGBAButton)button forPlayer:(NSInteger)player { pad[player] &= ~GBAMap[button]; }

bool systemReadJoypads() {
    __strong PVVisualBoyAdvanceBridge *strongCurrent = _current;

    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        if (strongCurrent.controller1 && playerIndex == 0) {
            controller = strongCurrent.controller1;
        }
        else if (strongCurrent.controller2 && playerIndex == 1) {
            controller = strongCurrent.controller2;
            playerIndex = 1;
        }

        if (controller) {
            if ([controller extendedGamepad]) {
                GCExtendedGamepad *gamepad = [controller extendedGamepad];
                GCControllerDirectionPad *dpad = [gamepad dpad];

                (gamepad.dpad.up.isPressed || gamepad.leftThumbstick.up.isPressed) ? pad[playerIndex] |= KEY_UP : pad[playerIndex] &= ~KEY_UP;
                (gamepad.dpad.down.isPressed || gamepad.leftThumbstick.down.isPressed) ? pad[playerIndex] |= KEY_DOWN : pad[playerIndex] &= ~KEY_DOWN;
                (gamepad.dpad.left.isPressed || gamepad.leftThumbstick.left.isPressed) ? pad[playerIndex] |= KEY_LEFT : pad[playerIndex] &= ~KEY_LEFT;
                (gamepad.dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed) ? pad[playerIndex] |= KEY_RIGHT : pad[playerIndex] &= ~KEY_RIGHT;

                (gamepad.buttonA.isPressed || gamepad.buttonY.isPressed) ? pad[playerIndex] |= KEY_BUTTON_B : pad[playerIndex] &= ~KEY_BUTTON_B;
                (gamepad.buttonB.isPressed || gamepad.buttonX.isPressed) ? pad[playerIndex] |= KEY_BUTTON_A : pad[playerIndex] &= ~KEY_BUTTON_A;

                gamepad.leftShoulder.isPressed ? pad[playerIndex] |= KEY_BUTTON_L : pad[playerIndex] &= ~KEY_BUTTON_L;
                gamepad.rightShoulder.isPressed ? pad[playerIndex] |= KEY_BUTTON_R : pad[playerIndex] &= ~KEY_BUTTON_R;

				gamepad.leftTrigger.isPressed ? pad[playerIndex] |= KEY_BUTTON_SELECT : pad[playerIndex] &= ~KEY_BUTTON_SELECT;
                gamepad.rightTrigger.isPressed ? pad[playerIndex] |= KEY_BUTTON_START : pad[playerIndex] &= ~KEY_BUTTON_START;
                
            }
#if TARGET_OS_TV
            else if ([controller microGamepad])
            {
                GCMicroGamepad *gamepad = [controller microGamepad];
                GCControllerDirectionPad *dpad = [gamepad dpad];

                gamepad.dpad.up.value > 0.5 ? pad[playerIndex] |= KEY_UP : pad[playerIndex] &= ~KEY_UP;
                gamepad.dpad.down.value > 0.5 ? pad[playerIndex] |= KEY_DOWN : pad[playerIndex] &= ~KEY_DOWN;
                gamepad.dpad.left.value > 0.5 ? pad[playerIndex] |= KEY_LEFT : pad[playerIndex] &= ~KEY_LEFT;
                gamepad.dpad.right.value > 0.5 ? pad[playerIndex] |= KEY_RIGHT : pad[playerIndex] &= ~KEY_RIGHT;
                
                gamepad.buttonA.isPressed ? pad[playerIndex] |= KEY_BUTTON_B : pad[playerIndex] &= ~KEY_BUTTON_B;
                gamepad.buttonX.isPressed ? pad[playerIndex] |= KEY_BUTTON_A : pad[playerIndex] &= ~KEY_BUTTON_A;
            }
#endif
        }
    }

    return true;
}

# pragma mark - Misc Helper Methods

- (void)loadOverrides:(NSString *)gameID {
    // Set defaults
    self->_enableRTC       = NO;
    self->_enableMirroring = NO;
    self->_useBIOS         = NO;
    self->_cpuSaveType     = GBA_SAVE_AUTO;
    self->_flashSize       = PVVBAFlash64K;
    self->_hasRTCOverride       = NO;
    self->_hasFlashSizeOverride = NO;

    // Read in vba-over.ini and break it into an array of strings
    NSString *iniPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"vba-over" ofType:@"ini"];
    NSString *iniString = [NSString stringWithContentsOfFile:iniPath encoding:NSUTF8StringEncoding error:NULL];
    NSArray *settings = [iniString componentsSeparatedByString:@"\n"];

    BOOL matchFound = NO;
    NSMutableDictionary *overridesFound = [[NSMutableDictionary alloc] init];
    NSString *temp;

    // Check if vba-over.ini has per-game settings for our gameID
    for (NSString *s in settings) {
        temp = nil;

        if ([s hasPrefix:@"["]) {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"[" intoString:nil];
            [scanner scanUpToString:@"]" intoString:&temp];

            if([temp caseInsensitiveCompare:gameID] == NSOrderedSame) {
                matchFound = YES;
                self->_romID = temp;
            }

            continue;
        } else if (matchFound && [s hasPrefix:@"saveType="]) {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"saveType=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            self->_cpuSaveType = [temp intValue];
            if (self->_cpuSaveType < GBA_SAVE_AUTO || self->_cpuSaveType > GBA_SAVE_NONE) {
                self->_cpuSaveType = GBA_SAVE_AUTO;
            }
            [overridesFound setObject:temp forKey:@"CPU saveType"];

            continue;
        } else if (matchFound && [s hasPrefix:@"rtcEnabled="]) {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"rtcEnabled=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            self->_enableRTC = [temp boolValue];
            self->_hasRTCOverride = YES;
            [overridesFound setObject:temp forKey:@"rtcEnabled"];

            continue;
        } else if (matchFound && [s hasPrefix:@"flashSize="]) {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"flashSize=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            self->_flashSize = [temp intValue];
            self->_hasFlashSizeOverride = YES;
            [overridesFound setObject:temp forKey:@"flashSize"];

            continue;
        } else if (matchFound && [s hasPrefix:@"mirroringEnabled="]) {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"mirroringEnabled=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            self->_enableMirroring = [temp boolValue];
            [overridesFound setObject:temp forKey:@"mirroringEnabled"];

            continue;
        } else if (matchFound && [s hasPrefix:@"useBios="]) {
            NSScanner *scanner = [NSScanner scannerWithString:s];
            [scanner scanString:@"useBios=" intoString:nil];
            [scanner scanUpToString:@"\n" intoString:&temp];
            self->_useBIOS = [temp boolValue];
            [overridesFound setObject:temp forKey:@"useBios"];

            continue;
        }
        else if (matchFound) {
            break;
        }
    }

    if (matchFound) { DLOG(@"VBA: overrides found: %@", overridesFound); }
}

- (void)writeSaveFile {
    NSString *savePath = [self->_saveFile path];
    if (!vba.emuWriteBattery(savePath.UTF8String)) { return; }
    DLOG(@"VBA: Battery saved");

    // VBA-M 2.x writes SRAM saves as 32K. The 1.8 core Provenance shipped
    // before wrote 64K and fails to load anything else, so a 32K save synced
    // to a device still on an older build would be ignored there and then
    // overwritten. Keep writing the 64K image (2.x loads both sizes).
    if (coreOptions.saveType == GBA_SAVE_SRAM && !eepromInUse) {
        NSData *sram = [NSData dataWithBytes:flashSaveMemory length:PVVBALegacySRAMSaveSize];
        if (![sram writeToFile:savePath atomically:YES]) {
            ELOG(@"VBA: could not write 64K SRAM save to %@", savePath);
        }
    }
}

/*
 This migration method is meant to correct broken behavior in forks of VBA/VBA-M so that we can reuse battery saves with our unmodified VBA-M core port. Forks vba-next/vbam-libretro created battery saves incompatible with vanilla VBA-M. Problems include:

 - EEPROM and FLASH all arbitrarily saved as 139KB (139264 bytes) instead of correct sizes.
 - SRAM sometimes saved incorrectly as 8KB (8192 bytes) instead of proper 66KB (65536 bytes).
 - SRAM sometimes saved incorrectly as 512 bytes instead of proper 66KB, resulting in data loss.
 - SRAM sometimes saved incorrectly as 139KB (139264 bytes) instead of proper 66KB (65536 bytes).
 - FLASH sometimes saved corrupt/empty 66KB files instead of saves meant to be 131KB (131072 bytes).
 - Battery save files always generated even if a game did not support saving.
 */
- (void)migrateSaveFile {
    // Build a path to the old save file and check if it exists
    NSURL *extensionlessFilename = [self->_saveFile URLByDeletingPathExtension];
    NSURL *saveFileToMigrate = [extensionlessFilename URLByAppendingPathExtension:@"sav"];

    if (![saveFileToMigrate checkResourceIsReachableAndReturnError:nil]) { return; }

    /*
     +----------------+---------------------------+-----------------+--------------------------------------+
     |     Format     | saveType / cpuSaveType    |  Size in Bytes  |            Example Games             |
     +----------------+---------------------------+-----------------+--------------------------------------|
     |  (AUTODETECT)  | 0 GBA_SAVE_AUTO           |        -        |                                      |
     |  EEPROM        | 1 GBA_SAVE_EEPROM         |   512 or 8192   | Super Mario Advance, LoZ: Minish Cap |
     |  SRAM          | 2 GBA_SAVE_SRAM           |      65536*     | F-Zero, Kirby Nightmare in Dreamland |
     |  FLASH         | 3 GBA_SAVE_FLASH          | 65536 or 131072 | Golden Sun, Pokemon Emerald          |
     |  EEPROM+Sensor | 4 GBA_SAVE_EEPROM_SENSOR  |   512 or 8192   | Yoshi's Universal Gravitation        |
     |  (NONE)        | 5 GBA_SAVE_NONE           |        -        |                                      |
     +---------------------------------------------------------------+--------------------------------------+
     * SRAM is 32K on the cart; Provenance keeps writing VBA-M 1.8's 64K image (see writeSaveFile).
     VBA-M 2.x uses one numbering for vba-over.ini `saveType=` and the core's
     coreOptions.saveType; 1.8 used a different internal one.
     See http://problemkaputt.de/gbatek.htm#gbacartbackupids
     */

    // Step 0
    // Backup original save file as .sav.old
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *backupSaveFile = [saveFileToMigrate URLByAppendingPathExtension:@"old"];
    [fileManager copyItemAtURL:saveFileToMigrate toURL:backupSaveFile error:nil];

    // Step 1
    // The save type was resolved at load (vba-over.ini override, else the
    // ROM's save-library string). Without an ini override, run the CPU for 500
    // frames as before: the EEPROM size (512 vs 8K) is only known once the
    // game touches it, which the 139KB EEPROM fix-ups below depend on.
    self->_migratingSave = YES;

    if (self->_cpuSaveType == GBA_SAVE_AUTO) {
        for (int i = 0; i < 500; i++) { vba.emuMain(vba.emuCount); }
    }

    const int saveType = coreOptions.saveType;
    const bool isEEPROM = saveType == GBA_SAVE_EEPROM || saveType == GBA_SAVE_EEPROM_SENSOR || eepromInUse;
    DLOG(@"VBA migrate: saveType %d eepromInUse %d flashSize %d eepromSize %d", saveType, eepromInUse, g_flashSize, eepromSize);

    // Step 2
    // Migrate save file if needed
    uint8_t *saveFileData;
    size_t saveFileSize;

    // Load save file, read bytes, get length
    NSData *dataObj = [NSData dataWithContentsOfURL:saveFileToMigrate];
    if(dataObj == nil) {
        CPUReset();
        self->_migratingSave = NO;
        return;
    }
    NSMutableData *mutableSave = [dataObj mutableCopy];
    saveFileSize = [mutableSave length];
    saveFileData = (uint8_t *)[mutableSave mutableBytes];

    // EEPROM saves

    // 139KB to 8KB - remove the front 131072 bytes
    if (isEEPROM && eepromSize == SIZE_EEPROM_8K && saveFileSize == 139264)
        memmove(saveFileData, saveFileData + 131072, saveFileSize -= 131072);

    // 139KB to 512 bytes - remove the front 131072 and last 7680 bytes
    else if (isEEPROM && eepromSize == SIZE_EEPROM_512 && saveFileSize == 139264) {
        memmove(saveFileData, saveFileData + 131072, SIZE_EEPROM_512);
        saveFileSize = SIZE_EEPROM_512;
    }

    // FLASH saves

    // 139KB to 131KB - remove the last 8192 bytes
    else if (saveType == GBA_SAVE_FLASH && g_flashSize == SIZE_FLASH1M && saveFileSize == 139264) {
        saveFileSize = SIZE_FLASH1M;
    }
    // 139KB to 66KB  - remove the last 73728 bytes
    // GUARD: If the vba-over.ini override declares this cart is FLASH 128K
    // (flashSize=0x20000), refuse to truncate to 64K — doing so would destroy
    // 64KB of save data (this was the cause of Pokemon "save failed" reports
    // when the cart was mis-detected as FLASH 64K). Leave the original .sav
    // alone in that case so it can still be loaded as 128K.
    else if (saveType == GBA_SAVE_FLASH && g_flashSize == SIZE_FLASH512 && saveFileSize == 139264) {
        if (self->_hasFlashSizeOverride && self->_flashSize == PVVBAFlash128K) {
            DLOG(@"VBA migrate: refusing to truncate 139KB save to 64K — vba-over.ini says cart is FLASH 128K. Leaving .sav intact.");
            CPUReset();
            self->_migratingSave = NO;
            return;
        }
        saveFileSize = SIZE_FLASH512;
    }
    // Case where some 131KB FLASH saved as 66KB with nothing but 0xFF bytes and no save data
    // All we can do is delete so the game doesn't crash
    else if (saveType == GBA_SAVE_FLASH && g_flashSize == SIZE_FLASH1M && saveFileSize == 65536) {
        [fileManager removeItemAtURL:saveFileToMigrate error:nil];
        CPUReset();
        self->_migratingSave = NO;
        return;
    }

    // SRAM saves

    // 139KB to 66KB  - remove the last 73728 bytes
    else if (saveType == GBA_SAVE_SRAM && saveFileSize == 139264) {
        saveFileSize = PVVBALegacySRAMSaveSize;
    }
    // Case where some 66KB SRAM saved as 8KB - add 57344 bytes of 0xFF to the end
    // e.g. Kirby Nightmare in Dreamland
    // Note: This is a lot of potential data lost and might not fix all saves
    else if (saveType == GBA_SAVE_SRAM && saveFileSize == 8192) {
        const size_t padding = PVVBALegacySRAMSaveSize - saveFileSize;
        [mutableSave increaseLengthBy:padding];
        saveFileData = (uint8_t *)[mutableSave mutableBytes];
        memset(saveFileData + saveFileSize, 0xFF, padding);
        saveFileSize = PVVBALegacySRAMSaveSize;
    } else {
        DLOG(@"VBA: Did not migrate save file because unnecessary or not detected.");
    }

    // Step 3
    // Save migrated file to .sav2 and delete old save file
    if (saveFileSize < 139264) {
        NSError *error = nil;
        NSURL *extensionlessFilename = [saveFileToMigrate URLByDeletingPathExtension];
        NSURL *migratedSaveFile = [extensionlessFilename URLByAppendingPathExtension:@"sav2"];
        NSData *outData = [NSData dataWithBytes:saveFileData length:saveFileSize];

        [outData writeToURL:migratedSaveFile options:NSDataWritingAtomic error:&error];

        if (error) {
            DLOG(@"VBA: Error writing migrated save file: %@", error);
            CPUReset();
            self->_migratingSave = NO;
            return;
        }

        DLOG(@"VBA: Writing new save file: %@", migratedSaveFile);

        // Reset because we ran the CPU
        CPUReset();
        self->_migratingSave = NO;

        if (vba.emuReadBattery([[migratedSaveFile path] UTF8String]))
            DLOG(@"VBA: Battery loaded");
    } else {
        CPUReset();
        self->_migratingSave = NO;
    }

    // Delete old save file since we created a backup .sav.old
    [fileManager removeItemAtURL:saveFileToMigrate error:nil];
}

// MARK: - VBA-M embedder callbacks (core/base/system.h)

// Only the 32-bit map is filled (systemColorDepth = 32); the core also
// references the 8/16-bit ones.
uint8_t systemColorMap8[0x10000];
uint16_t systemColorMap16[0x10000];
uint32_t systemColorMap32[0x10000];
int systemColorDepth = 32;
int systemRedShift = 19;
int systemGreenShift = 11;
int systemBlueShift = 3;
int systemVerbose = 0;
int systemFrameSkip = 0;
int systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;
int systemSpeed = 0;
void (*dbgOutput)(const char *s, uint32_t addr);
void (*dbgSignal)(int sig, int number);

uint32_t systemGetClock() { return 0; }

int systemGetSensorX() { return 0; }
int systemGetSensorY() { return 0; }
int systemGetSensorZ() { return 0; }
uint8_t systemGetSensorDarkness() { return PVVBASensorDarknessDefault; }
void systemUpdateMotionSensor() {}
void systemCartridgeRumble(bool) {}
void systemPossibleCartridgeRumble(bool) {}
void updateRumbleFrame() {}
bool systemPauseOnFrame() { return false; }
bool systemCanChangeSoundQuality() { return false; }
void systemFrame() {}
void systemShowSpeed(int) {}
void systemScreenCapture(int) {}
void systemSetTitle(const char *) {}
void systemOnSoundShutdown() {}
void systemOnWriteDataToSoundBuffer(const uint16_t *, int) {}
void systemGbPrint(uint8_t *, int, int, int, int, int) {}
void systemGbBorderOn() {}

// VBA video and execution
void system10Frames() {
    __strong PVVisualBoyAdvanceBridge *strongCurrent = _current;

    if(systemSaveUpdateCounter && !strongCurrent->_migratingSave)
    {
        if(--systemSaveUpdateCounter <= SYSTEM_SAVE_NOT_UPDATED)
        {
            [strongCurrent writeSaveFile];
            systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;
        }
    }
}

void systemDrawScreen() {
    __strong PVVisualBoyAdvanceBridge *strongCurrent = _current;

    strongCurrent->_haveFrame = YES;

    // g_pix rows are gbaWidth + 1 pixels wide with one guard row on top
    // (desktop build); copy out the visible 240x160.
    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_apply(gbaHeight, the_queue, ^(size_t y){
        memcpy(strongCurrent->videoBuffer + y * gbaWidth * 4, g_pix + (y + 1) * (gbaWidth + 1) * 4, gbaWidth * 4);
    });
}

void systemSendScreen() {}

// VBA input
uint32_t systemReadJoypad(int which) {
    uint32_t res = 0;

    which %= 4;
    if(which == -1)
        which = 0;

    res = pad[which];

    // Disallow L+R or U+D of being pressed at the same time
    if((res & (KEY_RIGHT | KEY_LEFT)) == (KEY_RIGHT | KEY_LEFT)) res &= ~ KEY_RIGHT;
    if((res & (KEY_UP    | KEY_DOWN)) == (KEY_UP    | KEY_DOWN)) res &= ~ KEY_UP;

    return res;
}

// VBA audio
class PVVBASoundDriver : public SoundDriver {
public:
    bool init(long) override { return true; }
    void pause() override {}
    void reset() override {}
    void resume() override {}
    void setThrottle(unsigned short) override {}

    // `length` is in bytes in the desktop build (gbaSound.cpp flush_samples).
    void write(uint16_t *finalWave, int length) override {
        __strong PVVisualBoyAdvanceBridge *strongCurrent = _current;
        [[strongCurrent ringBufferAtIndex:0] write:finalWave size:length];
    }
};

std::unique_ptr<SoundDriver> systemSoundInit() {
    return std::make_unique<PVVBASoundDriver>();
}

// VBA logging
static void pvvba_logv(const char *format, va_list args) {
    char buf[1024];
    vsnprintf(buf, sizeof(buf), format, args);
    DLOG(@"VBA: %s", buf);
}

void log(const char *format, ...) {
    va_list args;
    va_start(args, format);
    pvvba_logv(format, args);
    va_end(args);
}

void systemScreenMessage(const char *msg) {
    DLOG(@"VBA screen message: %s", msg);
}

void systemMessage(int, const char * str, ...) {
    va_list args;
    va_start(args, str);
    char buf[1024];
    vsnprintf(buf, sizeof(buf), str, args);
    va_end(args);
    DLOG(@"VBA message: %s", buf);
    NSString *msg = [NSString stringWithUTF8String:buf];
    if (msg.length > 0) {
        [PVOSDNotification postMessage:msg type:PVOSDTypeInfo duration:3.0];
    }
}

- (void)didPush:(PVGBAButton)button forPlayer:(NSInteger)player {
    [self didPushGBAButton:button forPlayer:player];
}

- (void)didRelease:(PVGBAButton)button forPlayer:(NSInteger)player {
    [self didReleaseGBAButton:button forPlayer:player];
}

@end

#pragma mark - Cheats

@implementation PVVisualBoyAdvanceBridge (Cheats)

// Maps sanitized code -> user-provided label
static NSMutableDictionary *cheatList = nil;
// Maps sanitized code -> codeType (e.g. "GameShark", "Action Replay v3") for per-code dispatch
static NSMutableDictionary *cheatCodeTypeList = nil;

- (NSArray<NSString *> *)cheatCodeTypes {
    return @[
        @"GameShark",
        @"Code Breaker",
        @"Action Replay v3",
        @"Action Replay v1/v2"
    ];
}

- (BOOL)setCheatWithCode:(NSString *)code type:(NSString *)type codeType:(NSString *)codeType
          cheatIndex:(UInt8)cheatIndex enabled:(BOOL)enabled {
    // Lazy-initialise cheat dictionaries
    if (!cheatList) {
        cheatList = [[NSMutableDictionary alloc] init];
    }
    if (!cheatCodeTypeList) {
        cheatCodeTypeList = [[NSMutableDictionary alloc] init];
    }

    // Sanitize
    code = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // VBA expects cheats UPPERCASE
    code = [code uppercaseString];

    // Remove any spaces
    code = [code stringByReplacingOccurrencesOfString:@" " withString:@""];

    // Concat address/value pairs
    NSArray *multipleCodes = [code componentsSeparatedByString:@"+"];
    for (NSUInteger i = 0; i < multipleCodes.count; i++) {
        NSString *singleCode = multipleCodes[i];
        if (i + 1 < multipleCodes.count && singleCode.length <= 8) {
            singleCode = [singleCode stringByAppendingString:multipleCodes[i + 1]];
            i++;
        }
        if (enabled) {
            // Store the user-provided label (type) so it can be passed to the VBA cheat engine
            [cheatList setValue:type ?: singleCode forKey:singleCode];
            // Store per-code codeType so 16-char codes are dispatched correctly
            // even when cheats of different types are mixed together
            [cheatCodeTypeList setValue:codeType ?: @"" forKey:singleCode];
        } else {
            [cheatList removeObjectForKey:singleCode];
            [cheatCodeTypeList removeObjectForKey:singleCode];
        }
    }

    cheatsDeleteAll(false); // Old values not restored by default. Dunno if matters much to cheaters

    BOOL anyAdded = NO;

    // Apply enabled cheats found in dictionary
    for (NSString *singleCode in cheatList)
    {
        NSString *label = cheatList[singleCode] ?: @"cheat";
        NSString *storedCodeType = cheatCodeTypeList[singleCode] ?: codeType;
        DLOG(@"VBA: Processing cheat %@ codeType %@", singleCode, storedCodeType);
        if ([singleCode length] == 11 || [singleCode length] == 13 || [singleCode length] == 17) // Code with Address:Value
        {
            // XXXXXXXX:YY || XXXXXXXX:YYYY || XXXXXXXX:YYYYYYYY
            cheatsAddCheatCode([singleCode UTF8String], [label UTF8String]);
            anyAdded = YES;
        }
        else if ([singleCode length] == 12) // Codebreaker/GameShark SP/Xploder code
        {
            // VBA expects 12-character Codebreaker/GameShark SP codes in format: XXXXXXXX YYYY
            NSMutableString *formattedCode = [NSMutableString stringWithString:singleCode];
            [formattedCode insertString:@" " atIndex:8];

            cheatsAddCBACode([formattedCode UTF8String], [label UTF8String]);
            anyAdded = YES;
        }
        else if ([singleCode length] == 16) // GameShark Advance/Action Replay (v1/v2) and Action Replay v3
        {
            // Note: GameShark and Action Replay were synonymous until AR v3. Same codes and devices, but different names by region
            if ([storedCodeType isEqualToString:@"GameShark"])
                cheatsAddGSACode([singleCode UTF8String], [label UTF8String], false); // false = GS/AR v1/v2 (not AR v3)

            // AR v3 was an entirely different device from GS/AR v1/v2, with different code types and encryption
            else if ([storedCodeType isEqualToString:@"Action Replay v3"])
                cheatsAddGSACode([singleCode UTF8String], [label UTF8String], true); // true = AR v3 code

            else // default to GS/AR v1/v2 code (can't determine GS/AR v1/v2 vs AR v3 because same length)
                cheatsAddGSACode([singleCode UTF8String], [label UTF8String], false);

            anyAdded = YES;
        }
    }

    // Return YES if cheats were applied or if all cheats were disabled (empty list = success)
    return anyAdded || [cheatList count] == 0;
}

- (void)resetCheatCodes {
    if (cheatList) {
        [cheatList removeAllObjects];
    }
    if (cheatCodeTypeList) {
        [cheatCodeTypeList removeAllObjects];
    }
    cheatsDeleteAll(false);
}

-(BOOL)supportsCheatCode { return YES; }

@end
