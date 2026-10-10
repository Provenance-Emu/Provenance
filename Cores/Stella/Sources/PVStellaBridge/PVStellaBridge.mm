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

@import PVAudio;
@import PVSupport;
@import libstella;
@import PVStellaCPP;
@import PVLoggingObjC;
#if !TARGET_OS_WATCH
@import GameController;
#endif
@import PVCoreBridge;
@import PVObjCUtils;
@import PVEmulatorCore;
#import <libstella/libretro/libretro.h>
#import <libstella/libstella.h>

#import "PVStellaBridge.h"

#include <atomic>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <os/lock.h>
#import <CommonCrypto/CommonDigest.h>

// Atari 2600 RIOT RAM exposed to RetroAchievements (rcheevos addresses 0x00-0x7F).
static constexpr size_t kStellaSystemRAMSize = 128;

// ---------------------------------------------------------------------------
// MARK: - RetroAchievements rc_client (HAVE_RCHEEVOS)
// ---------------------------------------------------------------------------
#if HAVE_RCHEEVOS
#include "rc_client.h"

static uint32_t pvstella_read_memory(uint32_t address, uint8_t *buffer,
                                     uint32_t num_bytes, rc_client_t *client) {
    // Read the bridge's RAM mirror, never the core directly: the core's RAM
    // pointer is only valid while a game is loaded.
    PVStellaBridge *bridge = (__bridge PVStellaBridge *)rc_client_get_userdata(client);
    const uint8_t *ram = (const uint8_t *)bridge.stellaSystemRAMPtr;
    size_t ramSize = bridge.stellaSystemRAMSize;
    for (uint32_t i = 0; i < num_bytes; ++i) {
        uint32_t addr = address + i;
        uint8_t value = 0xFF;
        if (ram && ramSize > 0 && addr < ramSize) {
            value = ram[addr];
        }
        buffer[i] = value;
    }
    return num_bytes;
}

static void pvstella_server_call(const rc_api_request_t *request,
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

static void pvstella_event_handler(const rc_client_event_t *event, rc_client_t *client) {
    PVStellaBridge *bridge = (__bridge PVStellaBridge *)rc_client_get_userdata(client);
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

#if __has_include(<OpenGLES/gltypes.h>)
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#elif !TARGET_OS_WATCH
#import <OpenGL/OpenGL.h>
#import <OpenGL/GL3.h>
#import <GLUT/GLUT.h>
#endif

@interface PVStellaBridge () <GameWithCheat> {
    stellabuffer_t *_videoBuffer;
    int _videoWidth, _videoHeight;
    int16_t _pad[NUMBER_OF_PADS][NUMBER_OF_PAD_INPUTS];

    // RETRO_REGION_NTSC, RETRO_REGION_PAL
    unsigned region;

#if HAVE_RCHEEVOS
    rc_client_t *_rcClient;
#endif
    std::atomic<bool> _achievementsActive;

    // Tracks whether libretro is fully initialised AND a game is loaded.
    // Guards retro_run() so the emulation thread cannot race against
    // stopEmulation()'s teardown or against a fresh loadFileAtPath:.
    std::atomic<bool> _loaded;

    // Guards the trackball and light-gun input fields below: written on the
    // main thread by the input setters, read by input_state_callback on the
    // emulation thread. NOT @synchronized(self) -- the emulation loop holds that
    // around every frame, so a setter on main would wait out the frame, and
    // deadlock outright if the frame were waiting on main. Lock order when both
    // are held: the monitor first, then this.
    os_unfair_lock _inputLock;

    // Trackball / Mouse state (Companion Controller input).
    // Accumulated relative deltas consumed each frame by input_state_callback.
    // Guarded by _inputLock.
    float _pendingMouseDX;
    float _pendingMouseDY;
    BOOL  _mouseButtonLeft;

    // Light gun (XG-1) absolute aim state. The libretro lightgun device uses a
    // signed-16-bit range of [-0x8000, 0x7FFF] for `SCREEN_X` / `SCREEN_Y`.
    // We store the latest normalised aim (0…1) here and convert in the input
    // state callback. Off-screen reload is tracked separately.
    // Guarded by _inputLock (except _isStellaLightGunGame, which the input
    // callback never reads).
    int16_t _lightGunScreenX;
    int16_t _lightGunScreenY;
    BOOL    _lightGunIsOffscreen;
    BOOL    _lightGunTrigger;
    BOOL    _isStellaLightGunGame;

    // Copy of the core's RIOT RAM, refreshed after every retro_run() and state
    // load. Stella's libretro core returns a pointer into the live console,
    // which does not exist before load and is freed by retro_unload_game();
    // RetroAchievements may ask for the region outside that window and keeps
    // the base pointer, so it gets this buffer, which lives as long as the bridge.
    uint8_t _systemRAM[kStellaSystemRAMSize];
}
@property (nonatomic, strong) NSMutableArray<NSString*>* cheats;
@property (readwrite, nonatomic, copy) PVStellaBridgeOptionHandler optionHandler;

- (void)pvstella_applyAchievementsLoadResult:(BOOL)success;

@end

#if HAVE_RCHEEVOS

typedef struct pvstella_load_ctx {
    void *bridge;
    void *completion;
} pvstella_load_ctx_t;

static void pvstella_load_callback(int result, const char * __unused error_message,
                                   rc_client_t * __unused client, void *userdata) {
    pvstella_load_ctx_t *ctx = (pvstella_load_ctx_t *)userdata;
    PVStellaBridge *bridge = (__bridge_transfer PVStellaBridge *)ctx->bridge;
    void (^completion)(BOOL) = (__bridge_transfer void (^)(BOOL))ctx->completion;
    ctx->completion = NULL;
    free(ctx);

    BOOL success = (result == RC_OK);
    [bridge pvstella_applyAchievementsLoadResult:success];
    if (completion) { completion(success); }
}

typedef struct pvstella_login_ctx {
    void *bridge;
    void *gameHash;
    void *completion;
} pvstella_login_ctx_t;

static void pvstella_login_callback(int result, const char * __unused error_message,
                                    rc_client_t *client, void *userdata) {
    pvstella_login_ctx_t *lCtx = (pvstella_login_ctx_t *)userdata;
    PVStellaBridge *bridge = (__bridge_transfer PVStellaBridge *)lCtx->bridge;
    NSString *hash               = (__bridge_transfer NSString *)lCtx->gameHash;
    void (^completion)(BOOL)     = (__bridge_transfer void (^)(BOOL))lCtx->completion;
    lCtx->completion = NULL;
    free(lCtx);

    if (result != RC_OK) {
        [bridge pvstella_applyAchievementsLoadResult:NO];
        if (completion) { completion(NO); }
        return;
    }

    pvstella_load_ctx_t *loadCtx = (pvstella_load_ctx_t *)malloc(sizeof(pvstella_load_ctx_t));
    if (!loadCtx) {
        [bridge pvstella_applyAchievementsLoadResult:NO];
        if (completion) { completion(NO); }
        return;
    }
    loadCtx->bridge     = (__bridge_retained void *)bridge;
    loadCtx->completion = completion ? (__bridge_retained void *)[completion copy] : NULL;
    rc_client_begin_load_game(client, hash.UTF8String, pvstella_load_callback, loadCtx);
}
#endif // HAVE_RCHEEVOS

// ---------------------------------------------------------------------------
// MARK: - Light Gun (XG-1) ROM detection
// ---------------------------------------------------------------------------
//
// MD5s sourced from Stella's upstream `stella.pro` cartridge database
// (`Cart.Note "Uses the Light Gun Controller (left only)"`). Only the
// shipping/prototype carts that actually use the XG-1 are listed — paddle and
// keyboard controller carts are intentionally excluded.
static NSString * const kStellaLightGunMD5s[] = {
    @"8da51e0c4b6b46f7619425119c7d018e", // Sentinel (1991) (Atari) — CX26183
    @"10c47acca2ecd212b900ad3cf6942dbb", // Shooting Arcade (03-07-1989) (Atari) (Prototype) [screen 5]
    @"15c11ab6e4502b2010b18366133fc322", // Shooting Arcade (09-19-1989) (Atari) (Prototype)
    @"557e893616648c37a27aab5a47acbf10", // Shooting Arcade (01-16-1990) (Atari) (Prototype) (PAL)
    @"5d7293f1892b66c014e8d222e06f6165", // Shooting Arcade (03-07-1989) (Atari) (Prototype) [screen 2]
    @"b2ab209976354ad4a0e1676fc1fe5a82", // Shooting Arcade (03-07-1989) (Atari) (Prototype) [screen 4]
    @"c5bf03028b2e8f4950ec8835c6811d47", // Shooting Arcade (03-07-1989) (Atari) (Prototype) [screen 3]
    @"f0ef9a1e5d4027a157636d7f19952bb5", // Shooting Arcade (03-07-1989) (Atari) (Prototype) [screen 6]
    @"fb978f1c053e8061cc37a726639f43f7", // Shooting Arcade (03-07-1989) (Atari) (Prototype)
    @"1d67c50baff2df771c32e2f915879176", // Shooting Arcade (09-19-1989) (Atari) (Prototype) [screen 5]
    @"660c378803503a443556525ddda08648", // Shooting Arcade (09-19-1989) (Atari) (Prototype) [screen 6]
    @"83531415b25531b47d23cf205961e51f", // Shooting Arcade (09-19-1989) (Atari) (Prototype) [screen 3]
    @"b018c51949fcf78b76b3bac7d3bcb1ae", // Shooting Arcade (09-19-1989) (Atari) (Prototype) [screen 4]
    @"be7011581614ffb0c38f79f99ae67b4f", // Shooting Arcade (09-19-1989) (Atari) (Prototype) [screen 2]
};
static const NSUInteger kStellaLightGunMD5Count = sizeof(kStellaLightGunMD5s) / sizeof(kStellaLightGunMD5s[0]);

static NSString *pvstella_md5_for_rom(const void *bytes, size_t length) {
    if (!bytes || length == 0) { return @""; }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(bytes, (CC_LONG)length, digest);
    char hex[CC_MD5_DIGEST_LENGTH * 2 + 1];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
        snprintf(hex + (i * 2), 3, "%02x", digest[i]);
    }
    return [NSString stringWithUTF8String:hex];
}

static BOOL pvstella_is_lightgun_md5(NSString *md5) {
    if (md5.length != CC_MD5_DIGEST_LENGTH * 2) { return NO; }
    NSString *normalised = [md5 lowercaseString];
    for (NSUInteger i = 0; i < kStellaLightGunMD5Count; ++i) {
        if ([normalised isEqualToString:kStellaLightGunMD5s[i]]) {
            return YES;
        }
    }
    return NO;
}

static __weak PVStellaBridge *_current;

/// Scaling factor applied to the normalised companion trackball delta (-1…1)
/// to produce a pixel-delta value for RETRO_DEVICE_MOUSE X/Y.
/// 32 px/frame at full deflection gives a responsive feel without overshooting.
static const float kTrackballMouseDeltaScale = 32.0f;

@implementation PVStellaBridge

#pragma mark - Static callbacks
static void audio_callback(int16_t left, int16_t right) {
    __strong PVStellaBridge *strongCurrent = _current;

	[[strongCurrent ringBufferAtIndex:0] write:&left size:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right size:2];

    strongCurrent = nil;
}

static size_t audio_batch_callback(const int16_t *data, size_t frames) {
    __strong PVStellaBridge *strongCurrent = _current;

    [[strongCurrent ringBufferAtIndex:0] write:data size:frames << 2];

    strongCurrent = nil;
    
    return frames;
}

static dispatch_queue_t memcpy_queue =
dispatch_queue_create("stella memcpy queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0));

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch) {
    __strong PVStellaBridge *strongCurrent = _current;

    // Defensive bail-out: if anything is missing, skip this frame instead of
    // racing into a heap-corrupting memcpy. This guards the prime retro_run()
    // fired from loadFileAtPath: where _videoBuffer / data could (in theory)
    // be momentarily nil, and any future teardown ordering bug.
    if (strongCurrent == nil || data == NULL || strongCurrent->_videoBuffer == NULL ||
        width == 0 || height == 0) {
        strongCurrent = nil;
        return;
    }

    // The destination buffer is allocated as STELLA_WIDTH * STELLA_HEIGHT
    // (160 x 256) stellabuffer_t pixels. Stella's libretro core can legally
    // emit frames up to AtariNTSC::outWidth(160) = 568 wide (NTSC TV filter
    // enabled) and 312 tall (PAL). Without clamping, dispatch_apply's parallel
    // memcpy writes past the allocation and corrupts the heap — exactly the
    // crash signature reported (dispatch_apply_invoke3 inside video_callback
    // during the very first retro_run() in loadFileAtPath:).
    const unsigned dstWidth  = STELLA_WIDTH;
    const unsigned dstHeight = STELLA_HEIGHT;
    const unsigned copyWidth  = (width  < dstWidth)  ? width  : dstWidth;
    const unsigned copyHeight = (height < dstHeight) ? height : dstHeight;

    strongCurrent->_videoWidth  = copyWidth;
    strongCurrent->_videoHeight = copyHeight;

    const size_t srcStride = pitch >> STELLA_PITCH_SHIFT; // pitch is in bytes, convert to pixels
    stellabuffer_t *dstBase = strongCurrent->_videoBuffer;

    dispatch_apply(copyHeight, memcpy_queue, ^(size_t y) {
        const stellabuffer_t *src = (const stellabuffer_t*)data + y * srcStride;
        stellabuffer_t *dst = dstBase + y * dstWidth;
        memcpy(dst, src, sizeof(stellabuffer_t) * copyWidth);
    });

    strongCurrent = nil;
}

static void input_poll_callback(void) {
	DLOG(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id) {
//    DLOG(@"polled input: port: %d device: %d id: %d", port, device, _id);

    __strong PVStellaBridge *strongCurrent = _current;
    int16_t value = 0;

    if (port == 0 && device == RETRO_DEVICE_JOYPAD)
    {
        value = strongCurrent->_pad[0][_id];
    }
    else if (port == 1 && device == RETRO_DEVICE_JOYPAD)
    {
        value = strongCurrent->_pad[1][_id];
    }
    else if (port == 0 && device == RETRO_DEVICE_LIGHTGUN)
    {
        // Stella libretro reads SCREEN_X / SCREEN_Y as signed 16-bit values
        // centred on 0 and scales to the visible image rect (see
        // `update_input()` in src/os/libretro/libretro.cxx). It also reads
        // TRIGGER (and uses it for both left/right mouse buttons inside the
        // Stella event system) and IS_OFFSCREEN.
        os_unfair_lock_lock(&strongCurrent->_inputLock);
        {
            switch (_id) {
                case RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X:
                    value = strongCurrent->_lightGunScreenX;
                    break;
                case RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y:
                    value = strongCurrent->_lightGunScreenY;
                    break;
                case RETRO_DEVICE_ID_LIGHTGUN_IS_OFFSCREEN:
                    value = strongCurrent->_lightGunIsOffscreen ? 1 : 0;
                    break;
                case RETRO_DEVICE_ID_LIGHTGUN_TRIGGER:
                    // While "aiming off-screen", treat the trigger as released
                    // so that the host driver's "reload" gesture (offscreen +
                    // fire) is the only way to register an off-screen shot.
                    value = (strongCurrent->_lightGunTrigger && !strongCurrent->_lightGunIsOffscreen) ? 1 : 0;
                    break;
                case RETRO_DEVICE_ID_LIGHTGUN_RELOAD:
                    // Forced off-screen shot — fire while aimed off-screen.
                    value = (strongCurrent->_lightGunTrigger && strongCurrent->_lightGunIsOffscreen) ? 1 : 0;
                    break;
                default:
                    break;
            }
        }
        os_unfair_lock_unlock(&strongCurrent->_inputLock);
    }
    else if (port == 0 && device == RETRO_DEVICE_MOUSE)
    {
        // Trackball / companion controller mouse input.
        // Deltas are consumed (zeroed) after being read so they represent
        // per-frame relative movement, not an absolute position.
        os_unfair_lock_lock(&strongCurrent->_inputLock);
        {
            switch (_id) {
                case RETRO_DEVICE_ID_MOUSE_X: {
                    // Scale -1…1 normalised delta to pixel-delta range.
                    value = (int16_t)(strongCurrent->_pendingMouseDX * kTrackballMouseDeltaScale);
                    strongCurrent->_pendingMouseDX = 0.0f;
                    break;
                }
                case RETRO_DEVICE_ID_MOUSE_Y: {
                    value = (int16_t)(strongCurrent->_pendingMouseDY * kTrackballMouseDeltaScale);
                    strongCurrent->_pendingMouseDY = 0.0f;
                    break;
                }
                case RETRO_DEVICE_ID_MOUSE_LEFT: {
                    value = strongCurrent->_mouseButtonLeft ? 1 : 0;
                    break;
                }
                default:
                    break;
            }
        }
        os_unfair_lock_unlock(&strongCurrent->_inputLock);
    }

    strongCurrent = nil;

    return value;
}

// MARK: - Minimal libretro VFS (v3, POSIX)
// libstella's FSNodeLIBRETRO answers isFile()/exists()/read/write through the frontend's VFS and
// treats every path as "not a file" without one, so OSystem::openROM rejected every ROM.

static const unsigned kPVStellaVFSVersion = 3;

struct retro_vfs_file_handle {
    FILE *fp;
    char *path;
};

struct retro_vfs_dir_handle {
    DIR *dirp;
    struct dirent *entry;
    char *dirPath;
    bool includeHidden;
};

static const char *pvstella_vfs_get_path(struct retro_vfs_file_handle *stream) {
    return stream ? stream->path : NULL;
}

static struct retro_vfs_file_handle *pvstella_vfs_open(const char *path, unsigned mode, unsigned hints) {
    (void)hints;
    if (!path) return NULL;
    const bool update = (mode & RETRO_VFS_FILE_ACCESS_UPDATE_EXISTING) != 0;
    const char *fmode = "rb";
    if ((mode & RETRO_VFS_FILE_ACCESS_READ_WRITE) == RETRO_VFS_FILE_ACCESS_READ_WRITE) {
        fmode = update ? "r+b" : "w+b";
    } else if (mode & RETRO_VFS_FILE_ACCESS_WRITE) {
        fmode = update ? "r+b" : "wb";
    }
    FILE *fp = fopen(path, fmode);
    if (!fp) return NULL;
    struct retro_vfs_file_handle *handle = (struct retro_vfs_file_handle *)calloc(1, sizeof(*handle));
    handle->fp = fp;
    handle->path = strdup(path);
    return handle;
}

static int pvstella_vfs_close(struct retro_vfs_file_handle *stream) {
    if (!stream) return -1;
    const int result = fclose(stream->fp) == 0 ? 0 : -1;
    free(stream->path);
    free(stream);
    return result;
}

static int64_t pvstella_vfs_size(struct retro_vfs_file_handle *stream) {
    if (!stream) return -1;
    struct stat st;
    if (fflush(stream->fp) != 0 || fstat(fileno(stream->fp), &st) != 0) return -1;
    return (int64_t)st.st_size;
}

static int64_t pvstella_vfs_tell(struct retro_vfs_file_handle *stream) {
    return stream ? (int64_t)ftello(stream->fp) : -1;
}

static int64_t pvstella_vfs_seek(struct retro_vfs_file_handle *stream, int64_t offset, int position) {
    if (!stream) return -1;
    int whence = SEEK_SET;
    switch (position) {
        case RETRO_VFS_SEEK_POSITION_START:   whence = SEEK_SET; break;
        case RETRO_VFS_SEEK_POSITION_CURRENT: whence = SEEK_CUR; break;
        case RETRO_VFS_SEEK_POSITION_END:     whence = SEEK_END; break;
        default: return -1;
    }
    return fseeko(stream->fp, (off_t)offset, whence) == 0 ? 0 : -1;
}

static int64_t pvstella_vfs_read(struct retro_vfs_file_handle *stream, void *buffer, uint64_t length) {
    return stream ? (int64_t)fread(buffer, 1, (size_t)length, stream->fp) : -1;
}

static int64_t pvstella_vfs_write(struct retro_vfs_file_handle *stream, const void *buffer, uint64_t length) {
    return stream ? (int64_t)fwrite(buffer, 1, (size_t)length, stream->fp) : -1;
}

static int pvstella_vfs_flush(struct retro_vfs_file_handle *stream) {
    return stream && fflush(stream->fp) == 0 ? 0 : -1;
}

static int pvstella_vfs_remove(const char *path) {
    return path && remove(path) == 0 ? 0 : -1;
}

static int pvstella_vfs_rename(const char *oldPath, const char *newPath) {
    return oldPath && newPath && rename(oldPath, newPath) == 0 ? 0 : -1;
}

static int64_t pvstella_vfs_truncate(struct retro_vfs_file_handle *stream, int64_t length) {
    if (!stream || fflush(stream->fp) != 0) return -1;
    return ftruncate(fileno(stream->fp), (off_t)length) == 0 ? 0 : -1;
}

static int pvstella_vfs_stat(const char *path, int32_t *size) {
    struct stat st;
    if (!path || stat(path, &st) != 0) return 0;
    int flags = RETRO_VFS_STAT_IS_VALID;
    if (S_ISDIR(st.st_mode)) flags |= RETRO_VFS_STAT_IS_DIRECTORY;
    if (S_ISCHR(st.st_mode)) flags |= RETRO_VFS_STAT_IS_CHARACTER_SPECIAL;
    if (size) *size = (int32_t)st.st_size;
    return flags;
}

static int pvstella_vfs_mkdir(const char *dir) {
    if (!dir) return -1;
    if (mkdir(dir, 0755) == 0) return 0;
    return errno == EEXIST ? -2 : -1;
}

static struct retro_vfs_dir_handle *pvstella_vfs_opendir(const char *dir, bool includeHidden) {
    DIR *dirp = dir ? opendir(dir) : NULL;
    if (!dirp) return NULL;
    struct retro_vfs_dir_handle *handle = (struct retro_vfs_dir_handle *)calloc(1, sizeof(*handle));
    handle->dirp = dirp;
    handle->dirPath = strdup(dir);
    handle->includeHidden = includeHidden;
    return handle;
}

static bool pvstella_vfs_readdir(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream) return false;
    while ((dirstream->entry = readdir(dirstream->dirp)) != NULL) {
        if (dirstream->includeHidden || dirstream->entry->d_name[0] != '.') return true;
    }
    return false;
}

static const char *pvstella_vfs_dirent_get_name(struct retro_vfs_dir_handle *dirstream) {
    return dirstream && dirstream->entry ? dirstream->entry->d_name : NULL;
}

static bool pvstella_vfs_dirent_is_dir(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream || !dirstream->entry) return false;
    if (dirstream->entry->d_type == DT_DIR) return true;
    if (dirstream->entry->d_type != DT_UNKNOWN) return false;
    char fullPath[PATH_MAX];
    snprintf(fullPath, sizeof(fullPath), "%s/%s", dirstream->dirPath, dirstream->entry->d_name);
    struct stat st;
    return stat(fullPath, &st) == 0 && S_ISDIR(st.st_mode);
}

static int pvstella_vfs_closedir(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream) return -1;
    const int result = closedir(dirstream->dirp) == 0 ? 0 : -1;
    free(dirstream->dirPath);
    free(dirstream);
    return result;
}

static struct retro_vfs_interface sPVStellaVFS = {
    pvstella_vfs_get_path, pvstella_vfs_open, pvstella_vfs_close, pvstella_vfs_size,
    pvstella_vfs_tell, pvstella_vfs_seek, pvstella_vfs_read, pvstella_vfs_write,
    pvstella_vfs_flush, pvstella_vfs_remove, pvstella_vfs_rename,
    pvstella_vfs_truncate,
    pvstella_vfs_stat, pvstella_vfs_mkdir, pvstella_vfs_opendir, pvstella_vfs_readdir,
    pvstella_vfs_dirent_get_name, pvstella_vfs_dirent_is_dir, pvstella_vfs_closedir,
};

static bool environment_callback(unsigned cmd, void *data) {
    __strong PVStellaBridge *strongCurrent = _current;
    
    switch(cmd) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent BIOSPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VFS_INTERFACE: {
            struct retro_vfs_interface_info *info = (struct retro_vfs_interface_info *)data;
            if (info->required_interface_version > kPVStellaVFSVersion) return false;
            info->required_interface_version = kPVStellaVFSVersion;
            info->iface = &sPVStellaVFS;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            enum retro_pixel_format pix_fmt = *(const enum retro_pixel_format*)data;
            switch (pix_fmt)
            {
                case RETRO_PIXEL_FORMAT_0RGB1555:
                    NSLog(@"Environ SET_PIXEL_FORMAT: 0RGB1555");
                    break;

                case RETRO_PIXEL_FORMAT_RGB565:
                    NSLog(@"Environ SET_PIXEL_FORMAT: RGB565");
                    break;

                case RETRO_PIXEL_FORMAT_XRGB8888:
                    NSLog(@"Environ SET_PIXEL_FORMAT: XRGB8888");
                    break;

                default:
                    return false;
            }
            //currentPixFmt = pix_fmt;
            break;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *var = (struct retro_variable*)data;
            NSString *varS = [NSString stringWithUTF8String:var->key];
            id _Nullable oValue = strongCurrent.optionHandler(varS); //[strongCurrent getVariable:varS];
            
            if ([oValue isKindOfClass:[NSString class]]) {
                NSString *value = oValue;
                if(oValue && value && value.length) {
                    var->value = [value cStringUsingEncoding:kCFStringEncodingUTF8];
                    return true;
                } else {
                    return false;
                }
            } else if ([oValue isKindOfClass:[NSNumber class]]) {
                NSNumber *value = oValue;
                if(value) {
                    var->value = [[value stringValue] cStringUsingEncoding:kCFStringEncodingUTF8];
                    return true;
                } else {
                    return false;
                }
            } else {
                return false;
            }

        }
        default : {
            DLOG(@"Environ UNSUPPORTED (#%u).\n", cmd);
            return false;
        }
    }
    
    strongCurrent = nil;
    
    return true;
}


static void loadSaveFile(const char* path, int type) {
    FILE *file;
    
    file = fopen(path, "rb");
    if ( !file ) {
        return;
    }
    
    size_t size = retro_get_memory_size(type);
    void *data  = retro_get_memory_data(type);
    
    if (size == 0 || !data) {
        fclose(file);
        return;
    }
    
    size_t rc = fread(data, sizeof(uint8_t), size, file);
    if ( rc != size ) {
        DLOG(@"Couldn't load save file.");
    }
    
    DLOG(@"Loaded save file: %s", path);
    fclose(file);
}

static void writeSaveFile(const char* path, int type) {
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if ( data && size > 0 ) {
        FILE *file = fopen(path, "wb");
        if ( file != NULL ) {
            DLOG(@"Saving state %s. Size: %d bytes.", path, (int)size);
            retro_serialize(data, size);
            if ( fwrite(data, sizeof(uint8_t), size, file) != size ) {
                DLOG(@"Did not save state properly.");
            }
            fclose(file);
        }
    }
}

- (instancetype)initWithOptionHandler:(PVStellaBridgeOptionHandler)optionHandler {
    if((self = [super init])) {
        _current = self;
        self.optionHandler = optionHandler;
        self.cheats = [[NSMutableArray alloc] init];
        _inputLock = OS_UNFAIR_LOCK_INIT;
        _pendingMouseDX = 0.0f;
        _pendingMouseDY = 0.0f;
        _mouseButtonLeft = NO;
        // Light gun starts centred, off-screen, trigger released.
        _lightGunScreenX = 0;
        _lightGunScreenY = 0;
        _lightGunIsOffscreen = NO;
        _lightGunTrigger = NO;
        _isStellaLightGunGame = NO;
        _achievementsActive.store(false);
        _loaded.store(false);
    }

	return self;
}

#pragma mark - Exectuion

- (void)resetEmulation {
    // Serialize against the emulation loop: retro_reset walks Stella's system
    // state and cannot run concurrently with retro_run on the emulation thread.
    @synchronized(self) {
        if (!_loaded.load()) { return; }
        retro_reset();
    }
}

- (void)stopEmulation {
    // Mark unloaded BEFORE anything else so the emulation thread's next
    // executeFrame skips retro_run() instead of touching state we are about
    // to tear down.
    _loaded.store(false);
    // Clear light-gun session state so the next ROM load starts clean.
    _isStellaLightGunGame = NO;
    os_unfair_lock_lock(&_inputLock);
    _lightGunTrigger      = NO;
    _lightGunIsOffscreen  = NO;
    os_unfair_lock_unlock(&_inputLock);

#if HAVE_RCHEEVOS
    if (_rcClient) {
        rc_client_unload_game(_rcClient);
        rc_client_destroy(_rcClient);
        _rcClient = NULL;
    }
    _achievementsActive.store(false);
#endif

    if ([self.batterySavesPath length]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];
        [self writeSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
    }

    [super stopEmulation];

    // Synchronous teardown. Previously this was dispatched 0.1s on the main
    // queue, which raced two ways: (1) the emulation thread could still be
    // inside retro_run when retro_unload_game fired, and (2) a quick re-launch
    // would call retro_init for the new game *before* the stale unload/deinit
    // ran, destroying the new game's state mid-frame and producing the
    // "TIA::scanlines() with null myFrameManager" crash.
    //
    // The legacy emulation loop wraps each executeFrame in @synchronized(self)
    // (see EmulatorCore.m). Acquiring the same monitor here blocks until any
    // in-flight frame has returned, so retro_unload_game/retro_deinit can never
    // race against retro_run.
    @synchronized(self) {
        retro_unload_game();
        retro_deinit();
    }

    self->region = RETRO_REGION_NTSC;
}

- (void)dealloc {
#if HAVE_RCHEEVOS
    if (_rcClient) {
        rc_client_destroy(_rcClient);
        _rcClient = NULL;
    }
#endif
    // Free on main, where the presenter reads the buffer. Directly when already
    // there: dispatch_sync to the main queue from main traps in libdispatch.
    stellabuffer_t *videoBuffer = self->_videoBuffer;
    if (!videoBuffer) {
        return;
    }
    if (NSThread.isMainThread) {
        free(videoBuffer);
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            free(videoBuffer);
        });
    }
}

- (void)executeFrame {
    if (!_loaded.load()) { return; }
#if !TARGET_OS_WATCH
    if (self.controller1 || self.controller2) {
        [self pollControllers];
    }
#endif
    retro_run();
    [self pvstella_syncSystemRAM];
    [self tickAchievements];
    [self pvstella_notifyFrameCompleted];
}

- (void)executeFrameSkippingFrame: (BOOL) skip {
    if (!_loaded.load()) { return; }
#if !TARGET_OS_WATCH
    if (!skip && (self.controller1 || self.controller2)) {
        [self pollControllers];
    }
#endif
    retro_run();
    [self pvstella_syncSystemRAM];
    [self tickAchievements];
    [self pvstella_notifyFrameCompleted];
}

/// Runs `frameCompletedHandler` once per emulated frame, after the RAM mirror
/// the achievement regions point at has been refreshed.
- (void)pvstella_notifyFrameCompleted {
    void (^frameCompleted)(void) = self.frameCompletedHandler;
    if (frameCompleted) {
        frameCompleted();
    }
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    // Flip `_loaded` off BEFORE taking the monitor so an emulation thread
    // that's already inside @synchronized(self) and about to call retro_run
    // returns early instead of racing the libretro teardown we're about to run.
    _loaded.store(false);

    self.romName = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0]; //[path copy];

    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[path stringByStandardizingPath]];
    if(dataObj == nil) return false;
    size_t size = [dataObj length];
    const void *data = (uint8_t*)[dataObj bytes];
    const char *meta = NULL;

    const char *fullPath = [path UTF8String];

    struct retro_game_info info = {NULL};
    info.path = fullPath;
    info.data = data;
    info.size = size;
    info.meta = meta;

    BOOL loaded = NO;

    // Serialize the entire libretro state transition against the emulation
    // loop's monitor. The emulation thread wraps executeFrame in
    // @synchronized(self) (see _PVCoreObjCBridge.m:282) and executeFrame calls
    // retro_run(). Holding the same monitor here guarantees that
    // retro_unload_game/retro_deinit/retro_init/retro_load_game/retro_run
    // cannot interleave with a retro_run on the emulation thread. Without this
    // the TIA pointer inside Stella is destroyed under the emulation thread
    // while it's mid-frame, producing a use-after-free on myFrameManager.
    @synchronized(self) {
        // Reset per-frame input and rebuild the video buffer under the
        // monitor too — retro_run()'s video_callback writes into _videoBuffer,
        // so a free/alloc outside the lock would race the emulation thread.
        memset(_pad, 0, sizeof(int16_t) * NUMBER_OF_PADS * NUMBER_OF_PAD_INPUTS);
        _isStellaLightGunGame = NO;
        os_unfair_lock_lock(&_inputLock);
        _lightGunTrigger      = NO;
        _lightGunIsOffscreen  = NO;
        _lightGunScreenX      = 0;
        _lightGunScreenY      = 0;
        os_unfair_lock_unlock(&_inputLock);
        memset(_systemRAM, 0, sizeof(_systemRAM));
        if(self->_videoBuffer) {
            free(self->_videoBuffer);
        }
        self->_videoBuffer = (stellabuffer_t*)malloc(STELLA_WIDTH * STELLA_HEIGHT * 4);

        // If a previous session is still in libretro state (e.g. quick
        // re-launch before stopEmulation finished), tear it down first so we
        // don't end up with two retro_init() calls without a matching
        // retro_deinit() in between.
        retro_unload_game();
        retro_deinit();

        retro_set_environment(environment_callback);
        retro_init();

        retro_set_audio_sample(audio_callback);
        retro_set_audio_sample_batch(audio_batch_callback);
        retro_set_video_refresh(video_callback);
        retro_set_input_poll(input_poll_callback);
        retro_set_input_state(input_state_callback);

        loaded = retro_load_game(&info);

        if (loaded) {
            if ([self.batterySavesPath length]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:NULL];

                NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];

                [self loadSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
            }

            struct retro_system_av_info av_info;
            retro_get_system_av_info(&av_info);

            self->_frameInterval = av_info.timing.fps;
            self->_sampleRate = av_info.timing.sample_rate;

            uint currentRegion = retro_get_region();
            if (currentRegion == RETRO_REGION_PAL) {
                self->region = RETRO_REGION_PAL;
            } else {
                self->region = RETRO_REGION_NTSC;
            }

            // Detect known light-gun (XG-1) carts and switch port 0 to the
            // libretro lightgun device so Stella loads
            // `Controller::Type::Lightgun` for the left port. Must happen
            // BEFORE the prime retro_run() so the first frame already routes
            // through the lightgun input path.
            NSString *md5 = pvstella_md5_for_rom(data, size);
            _isStellaLightGunGame = pvstella_is_lightgun_md5(md5);
            if (_isStellaLightGunGame) {
                retro_set_controller_port_device(0, RETRO_DEVICE_LIGHTGUN);
                ILOG(@"[Stella] Detected light-gun game (MD5 %@); switching port 0 to RETRO_DEVICE_LIGHTGUN.", md5);
            }

            retro_run();
            [self pvstella_syncSystemRAM];

            // Publish the loaded state only after retro_load_game and the
            // prime retro_run() have completed, and only while we still hold
            // the monitor. executeFrame reads this flag under the same
            // monitor, so it is impossible for the emulation thread to enter
            // retro_run() before Stella is fully initialised.
            _loaded.store(true);
        }
    }

    if (loaded) {
#if HAVE_RCHEEVOS
        if (!_rcClient) {
            _rcClient = rc_client_create(pvstella_read_memory, pvstella_server_call);
            if (_rcClient) {
                rc_client_set_userdata(_rcClient, (__bridge void *)self);
                rc_client_set_event_handler(_rcClient, pvstella_event_handler);
            }
        }
#endif

        return YES;
    } else {
        if(error) {
            *error = [NSError errorWithDomain:@"" code:-1 userInfo:@{
                NSLocalizedDescriptionKey : @"Failed to load ROM",
                NSLocalizedRecoverySuggestionErrorKey : @"Stella could not load the ROM. The core does not supply additional information."
            }];
        }

        ELOG(@"Stella failed to load ROM.")

        return NO;

    }
}

#pragma mark - Input
#if !TARGET_OS_WATCH

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
            
            /* TODO: To support paddles we would need to circumvent libRetro's emulation of analog controls or drop libRetro and talk to stella directly like OpenEMU did */
            
            // D-Pad
            float deadZone = 0.1;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = (dpad.up.isPressed    || gamepad.leftThumbstick.up.value > deadZone);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = (dpad.down.isPressed  || gamepad.leftThumbstick.down.value > deadZone);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = (dpad.left.isPressed  || gamepad.leftThumbstick.left.value > deadZone);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = (dpad.right.isPressed || gamepad.leftThumbstick.right.value > deadZone);

			// #688, use second thumb to control second player input if no controller active
			// some games used both joysticks for 1 player optionally
			if(playerIndex == 0 && self.controller2 == nil) {
				_pad[1][RETRO_DEVICE_ID_JOYPAD_UP]    = gamepad.rightThumbstick.up.isPressed;
				_pad[1][RETRO_DEVICE_ID_JOYPAD_DOWN]  = gamepad.rightThumbstick.down.isPressed;
				_pad[1][RETRO_DEVICE_ID_JOYPAD_LEFT]  = gamepad.rightThumbstick.left.isPressed;
				_pad[1][RETRO_DEVICE_ID_JOYPAD_RIGHT] = gamepad.rightThumbstick.right.isPressed;
			}

            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] =  gamepad.buttonB.isPressed || gamepad.rightTrigger.isPressed;
            // Booster
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = gamepad.buttonX.isPressed || gamepad.buttonY.isPressed || gamepad.leftTrigger.isPressed;
            
            // Reset
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.rightShoulder.isPressed;
            
            // Select
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.leftShoulder.isPressed;
   
            /*
             #define RETRO_DEVICE_ID_JOYPAD_B        0 == JoystickZeroFire1
             #define RETRO_DEVICE_ID_JOYPAD_Y        1 == Unmapped
             #define RETRO_DEVICE_ID_JOYPAD_SELECT   2 == ConsoleSelect
             #define RETRO_DEVICE_ID_JOYPAD_START    3 == ConsoleReset
             #define RETRO_DEVICE_ID_JOYPAD_UP       4 == Up
             #define RETRO_DEVICE_ID_JOYPAD_DOWN     5 == Down
             #define RETRO_DEVICE_ID_JOYPAD_LEFT     6 == Left
             #define RETRO_DEVICE_ID_JOYPAD_RIGHT    7 == Right
             #define RETRO_DEVICE_ID_JOYPAD_A        8 == JoystickZeroFire2
             #define RETRO_DEVICE_ID_JOYPAD_X        9 == JoystickZeroFire3
             #define RETRO_DEVICE_ID_JOYPAD_L       10 == ConsoleLeftDiffA
             #define RETRO_DEVICE_ID_JOYPAD_R       11 == ConsoleRightDiffA
             #define RETRO_DEVICE_ID_JOYPAD_L2      12 == ConsoleLeftDiffB
             #define RETRO_DEVICE_ID_JOYPAD_R2      13 == ConsoleRightDiffB
             #define RETRO_DEVICE_ID_JOYPAD_L3      14 == ConsoleColor
             #define RETRO_DEVICE_ID_JOYPAD_R3      15 == ConsoleBlackWhite
             */
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.value > 0.5;

            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonX.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
        }
#endif
    }
}

#endif

#pragma mark - RetroAchievements

- (void *)stellaSystemRAMPtr {
    return _systemRAM;
}

- (NSUInteger)stellaSystemRAMSize {
    return kStellaSystemRAMSize;
}

/// Copies the core's RIOT RAM into `_systemRAM`. Call only while a game is
/// loaded, under the emulation monitor (Stella's RAM pointer is not valid otherwise).
- (void)pvstella_syncSystemRAM {
    const void *ram = retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM);
    if (ram && retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM) >= kStellaSystemRAMSize) {
        memcpy(_systemRAM, ram, kStellaSystemRAMSize);
    }
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

- (void)pvstella_applyAchievementsLoadResult:(BOOL)success {
    _achievementsActive.store(success);
}

- (void)loadAchievementsForGameHash:(NSString *)gameHash
                         completion:(void (^)(BOOL success))completion {
#if HAVE_RCHEEVOS
    if (!_rcClient) {
        _achievementsActive.store(false);
        if (completion) { completion(NO); }
        return;
    }

    if (rc_client_get_user_info(_rcClient) != NULL) {
        pvstella_load_ctx_t *ctx = (pvstella_load_ctx_t *)malloc(sizeof(pvstella_load_ctx_t));
        if (!ctx) {
            _achievementsActive.store(false);
            if (completion) { completion(NO); }
            return;
        }
        ctx->bridge     = (__bridge_retained void *)self;
        ctx->completion = completion ? (__bridge_retained void *)[completion copy] : NULL;
        rc_client_begin_load_game(_rcClient, gameHash.UTF8String, pvstella_load_callback, ctx);
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

    pvstella_login_ctx_t *lCtx = (pvstella_login_ctx_t *)malloc(sizeof(pvstella_login_ctx_t));
    if (!lCtx) {
        _achievementsActive.store(false);
        if (completion) { completion(NO); }
        return;
    }
    lCtx->bridge     = (__bridge_retained void *)self;
    lCtx->gameHash   = (__bridge_retained void *)[gameHash copy];
    lCtx->completion = completion ? (__bridge_retained void *)[completion copy] : NULL;
    rc_client_begin_login_with_token(_rcClient, username.UTF8String, token.UTF8String,
                                     pvstella_login_callback, lCtx);
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

#pragma mark - Video
- (const void *)videoBuffer
{
    return self->_videoBuffer;
}

- (CGRect)screenRect {
//    __strong PVStellaGameCore *strongCurrent = _current;

    //return OEIntRectMake(0, 0, strongCurrent->_videoWidth, strongCurrent->_videoHeight);
    return CGRectMake(0, 0, self->_videoWidth, self->_videoHeight);
}

- (CGSize)bufferSize {
    return CGSizeMake(STELLA_WIDTH, STELLA_HEIGHT);
    
//    __strong PVStellaGameCore *strongCurrent = _current;
    //return CGSizeMake(strongCurrent->_videoWidth, strongCurrent->_videoHeight);
}

- (CGSize)aspectSize {
//    return CGSizeMake(4, 3);
    return CGSizeMake(self->_videoWidth * (12.0/7.0), self->_videoHeight);
//    return CGSizeMake(STELLA_WIDTH * 2, STELLA_HEIGHT);
}

#pragma mark - Video
#if !TARGET_OS_WATCH

- (GLenum)pixelFormat
{
    return STELLA_PIXEL_FORMAT;
}

- (GLenum)pixelType
{
    return  STELLA_PIXEL_TYPE;
}

- (GLenum)internalPixelFormat
{
    return STELLA_INTERNAL_FORMAT;
}
#endif

#pragma mark - Audio
- (double)audioSampleRate {
    return (self->_sampleRate > 0) ? self->_sampleRate : 31400;
}

- (NSTimeInterval)frameInterval {
    NSTimeInterval frameInterval = (_frameInterval > 0) ? _frameInterval : 60.0;
    return frameInterval;
}

- (NSUInteger)channelCount { return 2; }

#pragma mark - Saves
-(BOOL)supportsSaveStates {
	return YES;
}

- (void)loadSaveFile:(NSString *)path forType:(int)type {
    size_t size = retro_get_memory_size(type);
    void *ramData = retro_get_memory_data(type);
    
    if (size == 0 || !ramData) {
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || ![data length]) {
        WLOG(@"Couldn't load save file.");
    }
    
    [data getBytes:ramData length:size];
}

- (BOOL)writeSaveFile:(NSString *)path forType:(int)type {
    size_t size = retro_get_memory_size(type);
    void *ramData = retro_get_memory_data(type);
    
    if (ramData && (size > 0)) {
        retro_serialize(ramData, size);
        NSData *data = [NSData dataWithBytes:ramData length:size];
        BOOL success = [data writeToFile:path atomically:YES];
        if (!success) {
            ELOG(@"Error writing save file");
        }
        return success;
    } else {
        return NO;
    }
}

//- (void)loadStateFromFileAtPath:(nonnull NSString *)fileName completionHandler:(nonnull void (^)(BOOL, NSError * _Nonnull __strong))block {
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSError *error = nil;
//        BOOL success = [self loadStateFromFileAtPath:fileName error:&error];
//        block(success, error);
//    });
//}
//
//
//- (void)saveStateToFileAtPath:(nonnull NSString *)fileName completionHandler:(nonnull void (^)(BOOL, NSError * _Nonnull __strong))block {
//    // Async call the sync version
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSError *error = nil;
//        BOOL success = [self saveStateToFileAtPath:fileName error:&error];
//        block(success, error);
//    });
//}


- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        size_t serial_size = _loaded.load() ? retro_serialize_size() : 0;
        uint8_t *serial_data = serial_size ? (uint8_t *) malloc(serial_size) : NULL;

        // Never write a state file from a buffer the core did not fill.
        if (!serial_data || !retro_serialize(serial_data, serial_size)) {
            free(serial_data);
            if (error != NULL) {
                *error = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                             code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to save state.",
                                                    NSLocalizedFailureReasonErrorKey: @"Stella could not serialize the current state."}];
            }
            ELOG(@"Stella failed to serialize state (size %zu)", serial_size);
            return NO;
        }

        NSError *writeError = nil;
        NSData *saveStateData = [NSData dataWithBytes:serial_data length:serial_size];
        free(serial_data);
        BOOL success = [saveStateData writeToFile:path
                                          options:NSDataWritingAtomic
                                            error:&writeError];
        if (!success) {
            ELOG(@"Error saving state: %@", [writeError localizedDescription]);
            if (error != NULL) {
                *error = writeError;
            }
            return NO;
        }
        
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    @synchronized(self) {
        NSData *saveStateData = [NSData dataWithContentsOfFile:path];
        if (!saveStateData)
        {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey: @"Failed to load save state.",
                                           NSLocalizedFailureReasonErrorKey: @"Stella failed to read savestate data.",
                                           NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                                           };

                NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            ELOG(@"Unable to load save state from path: %@", path);
            return NO;
        }
        
        // Stella has no console before a game is loaded; unserializing then would
        // dereference it.
        if (!_loaded.load() || !retro_unserialize([saveStateData bytes], [saveStateData length]))
        {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                    NSLocalizedDescriptionKey: @"Failed to load save state.",
                    NSLocalizedFailureReasonErrorKey: @"Stella failed to load savestate data. It may have been made by an older version of the core.",
                    NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                };

                NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];
                *error = newError;
            }
            // Old Stella states (header "06070002state", app builds before the
            // 8.0 core) are rejected by StateManager's header check here,
            // before any console state is touched.
            ELOG(@"Stella rejected the save state (incompatible or corrupt)");
            return NO;
        }

        [self pvstella_syncSystemRAM];
        return YES;
    }
}

@dynamic supportsCheatCode;
@synthesize valueChangedHandler;

@synthesize cheatCodeTypes;


- (void)swapBuffers {
    // Does not impliment double buffering
}

- (BOOL)rendersToOpenGL {
    return NO;
}

#pragma mark - Light Gun (XG-1)
// Methods inlined into main @implementation (declarations moved into main
// @interface) — previously a (LightGun) category which was silently elided
// during Swift module synthesis on iOS / tvOS device builds.

- (BOOL)isStellaLightGunGame {
    // Read of a primitive BOOL is atomic on Apple architectures; the value is
    // only mutated synchronously from loadFileAtPath: while no observer can
    // race against it. No lock required.
    return _isStellaLightGunGame;
}

- (void)setLightGunNormalisedX:(CGFloat)nx y:(CGFloat)ny isOffscreen:(BOOL)isOffscreen {
    // Convert normalised 0…1 coords to libretro's signed-16-bit screen space.
    // Centre is 0; left/top edges are -0x8000; right/bottom edges are 0x7FFF.
    CGFloat cx = nx;
    CGFloat cy = ny;
    if (cx < 0.0) cx = 0.0; else if (cx > 1.0) cx = 1.0;
    if (cy < 0.0) cy = 0.0; else if (cy > 1.0) cy = 1.0;
    int32_t sx = (int32_t)(cx * (CGFloat)0xFFFF) - 0x8000;
    int32_t sy = (int32_t)(cy * (CGFloat)0xFFFF) - 0x8000;
    if (sx >  0x7FFF) sx =  0x7FFF;
    if (sx < -0x8000) sx = -0x8000;
    if (sy >  0x7FFF) sy =  0x7FFF;
    if (sy < -0x8000) sy = -0x8000;

    os_unfair_lock_lock(&_inputLock);
    _lightGunScreenX     = (int16_t)sx;
    _lightGunScreenY     = (int16_t)sy;
    _lightGunIsOffscreen = isOffscreen;
    os_unfair_lock_unlock(&_inputLock);
}

- (void)setLightGunTrigger:(BOOL)pressed {
    os_unfair_lock_lock(&_inputLock);
    _lightGunTrigger = pressed;
    os_unfair_lock_unlock(&_inputLock);
}

@end

#pragma mark - Cheats

@interface PVStellaBridge (GameWithCheat) <GameWithCheat>
@end

@implementation PVStellaBridge (GameWithCheat)

- (NSArray<NSString *> *)cheatCodeTypes {
    return @[@"Game Genie", @"Pro Action Replay"];
}

-(BOOL)supportsCheatCode {
    // Stella's libretro core implements retro_cheat_set/retro_cheat_reset as empty no-ops.
    // Cheat support is disabled until those hooks are implemented upstream.
    return NO;
}

- (BOOL)setCheatWithCode:(NSString * _Nonnull)code type:(NSString * _Nonnull)type codeType:(NSString * _Nonnull)codeType cheatIndex:(uint8_t)cheatIndex enabled:(BOOL)enabled {
    return [self setCheat:code setType:type setEnabled:enabled error:nil];
}

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled  error:(NSError**)error {
    @synchronized(self) {
        const char* _Nullable code_c = [code cStringUsingEncoding:NSUTF8StringEncoding];
        if (!code_c) {
            if (error) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                             code:NSFileWriteInapplicableStringEncodingError
                                         userInfo:@{NSLocalizedDescriptionKey: @"Cheat code could not be encoded as UTF-8"}];
            }
            return NO;
        }

        NSUInteger foundIndex = [self.cheats indexOfObject:code];
        NSUInteger index;
        if (foundIndex != NSNotFound) {
            index = foundIndex;
            [self.cheats replaceObjectAtIndex:index withObject:code];
        } else {
            index = self.cheats.count;
            [self.cheats addObject:code];
        }

        retro_cheat_set((unsigned int)index, enabled, code_c);

        ILOG(@"Applied Cheat Code %@ %@", code, type);

        return YES;
    }
}

- (void)resetCheatCodes {
    @synchronized(self) {
        [self.cheats removeAllObjects];
        retro_cheat_reset();
        ILOG(@"Stella resetCheatCodes");
    }
}

@end

@implementation PVStellaBridge (PV2600SystemResponderClient)
- (void)didPushPV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player {
    _pad[player][A2600EmulatorValues[button]] = 1;
}

- (void)didReleasePV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player {
    _pad[player][A2600EmulatorValues[button]] = 0;
}
@end

// MARK: - Trackball / Mouse input (Companion Controller)

@implementation PVStellaBridge (Trackball)

- (void)setTrackballDeltaX:(float)deltaX deltaY:(float)deltaY {
    // Accumulate: multiple companion events may arrive between emulation frames.
    os_unfair_lock_lock(&_inputLock);
    _pendingMouseDX += deltaX;
    _pendingMouseDY += deltaY;
    os_unfair_lock_unlock(&_inputLock);
}

- (void)setMouseButtonLeft:(BOOL)pressed {
    os_unfair_lock_lock(&_inputLock);
    _mouseButtonLeft = pressed;
    os_unfair_lock_unlock(&_inputLock);
}

@end

