//
//  PVThinLibretroFrontend.mm
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Implementation of the thin, RetroArch-free libretro frontend.
//  See PVThinLibretroFrontend.h for the design rationale.
//
//  Key design decisions:
//  - No RetroArch headers: only libretro.h, dlopen/dlsym, EAGL, and Provenance frameworks
//  - Static C callbacks forward to the ObjC instance via a weak _thinCurrent pointer
//  - Core options stored in a mutable dictionary; dirty flag drives VARIABLE_UPDATE
//  - HW-render cores get an EAGLContext + IOSurface-backed FBO (same approach as PVLibRetroGLESCore)
//  - Serialization uses retro_serialize_size / retro_serialize / retro_unserialize directly
//

#import "PVThinLibretroFrontend.h"

@import Foundation;
@import QuartzCore;   // CACurrentMediaTime
@import CoreVideo;    // kCVPixelFormatType_32BGRA
@import PVLoggingObjC;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVAudio;

#include <dlfcn.h>
#include <string.h>
#import <objc/message.h>

/// Rumble callback matching retro_set_rumble_state_t.
/// Dispatches to PVLibRetroRumbleHelper (Swift) via ObjC runtime.
static bool pv_retro_rumble_callback(unsigned port, enum retro_rumble_effect effect, uint16_t strength) {
    Class helper = NSClassFromString(@"PVLibRetro.PVLibRetroRumbleHelper");
    if (!helper) helper = NSClassFromString(@"PVLibRetroRumbleHelper");
    if (!helper) return false;
    BOOL isStrong = (effect == RETRO_RUMBLE_STRONG);
    SEL sel = @selector(rumbleWithPort:isStrong:strength:);
    if ([helper respondsToSelector:sel]) {
        ((void(*)(id, SEL, uint32_t, BOOL, uint16_t))objc_msgSend)(helper, sel, (uint32_t)port, isStrong, strength);
        return true;
    }
    return false;
}
#include <stdarg.h>
#include <os/lock.h>
#include <pthread.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
@import OpenGLES.ES3;
@import OpenGLES.EAGL;
@import IOSurface;
@import OpenGLES.EAGLIOSurface;
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations" // EAGLContext on iOS 17+

// ---------------------------------------------------------------------------
// MARK: - Private EAGLContext SPI for IOSurface binding
// ---------------------------------------------------------------------------
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
@interface EAGLContext (ThinFrontendIOSurface)
- (BOOL)texImageIOSurface:(IOSurfaceRef)ioSurface
                   target:(NSUInteger)target
           internalFormat:(NSUInteger)internalFormat
                    width:(uint32_t)width
                   height:(uint32_t)height
                   format:(NSUInteger)format
                     type:(NSUInteger)type
                    plane:(uint32_t)plane;
@end
#endif

// ---------------------------------------------------------------------------
// MARK: - libretro function-pointer table
// ---------------------------------------------------------------------------

/// All `retro_*` function pointers resolved from the core dylib.
typedef struct PVThinLibretroSymbols {
    // Core lifecycle
    void     (*retro_init)(void);
    void     (*retro_deinit)(void);
    unsigned (*retro_api_version)(void);
    void     (*retro_get_system_info)(struct retro_system_info *info);
    void     (*retro_get_system_av_info)(struct retro_system_av_info *info);
    bool     (*retro_load_game)(const struct retro_game_info *game);
    void     (*retro_unload_game)(void);
    void     (*retro_run)(void);
    void     (*retro_reset)(void);

    // Callbacks
    void     (*retro_set_environment)(retro_environment_t cb);
    void     (*retro_set_video_refresh)(retro_video_refresh_t cb);
    void     (*retro_set_audio_sample)(retro_audio_sample_t cb);
    void     (*retro_set_audio_sample_batch)(retro_audio_sample_batch_t cb);
    void     (*retro_set_input_poll)(retro_input_poll_t cb);
    void     (*retro_set_input_state)(retro_input_state_t cb);

    // State / cheats
    size_t   (*retro_serialize_size)(void);
    bool     (*retro_serialize)(void *data, size_t size);
    bool     (*retro_unserialize)(const void *data, size_t size);
    void     (*retro_cheat_reset)(void);
    void     (*retro_cheat_set)(unsigned index, bool enabled, const char *code);

    // Memory (SRAM / battery saves)
    void    *(*retro_get_memory_data)(unsigned id);
    size_t   (*retro_get_memory_size)(unsigned id);
} PVThinLibretroSymbols;

#define THIN_RESOLVE(sym, handle, name) \
    do { \
        (sym).name = (typeof((sym).name))dlsym((handle), #name); \
        if (!(sym).name) { WLOG(@"ThinFrontend: missing symbol %s", #name); } \
    } while (0)

// ---------------------------------------------------------------------------
// MARK: - Private interface
// ---------------------------------------------------------------------------

@interface PVThinLibretroFrontend () {
    void *_dylibHandle;
    PVThinLibretroSymbols _sym;

    // AV info & system info
    struct retro_system_info _rawSystemInfo;
    struct retro_system_av_info _rawAVInfo;

    // Core options
    NSMutableDictionary<NSString *, NSString *> *_coreOptions;
    BOOL _coreOptionsDirty;
    os_unfair_lock _optionsLock;

    // Structured option metadata (for CoreOptional UI support)
    NSMutableArray<NSDictionary<NSString *, id> *> *_coreOptionDefinitions;
    NSMutableArray<NSDictionary<NSString *, id> *> *_coreOptionCategories;
    NSMutableDictionary<NSString *, NSNumber *> *_coreOptionVisibility;

    // Frame-time callback (RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK)
    struct retro_frame_time_callback _frameTimeCallback;
    BOOL _hasFrameTimeCallback;
    int64_t _lastFrameTimeUs;

    // Audio callback (RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK)
    struct retro_audio_callback _audioCallback;
    BOOL _hasAudioCallback;

    // Keyboard callback
    retro_keyboard_event_t _keyboardEventCb;

    // HW render state
    struct retro_hw_render_callback _hwRenderCallback;
    BOOL _hwRenderRequested;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLContext *_glContext;
    EAGLContext *_glShareContext;
    IOSurfaceRef _ioSurface;
    GLuint _emuFBO;
    GLuint _emuColorTex;
    GLuint _emuDepthRB;
#endif

    // Serialization quirks bitmask
    uint64_t _serializationQuirks;

    // Disk control (v1 and v2)
    struct retro_disk_control_callback _diskControl;
    struct retro_disk_control_ext_callback _diskControlExt;
    BOOL _hasDiskControl;
    BOOL _hasDiskControlExt;

    // Pixel format
    enum retro_pixel_format _retroPixelFormat;

    // Geometry override
    struct retro_game_geometry _pendingGeometry;
    BOOL _hasPendingGeometry;

    // Message interface version supported
    unsigned _messageInterfaceVersion;

    // Rumble
    struct retro_rumble_interface _rumbleInterface;

    // Stable C-string pointer for RETRO_ENVIRONMENT_GET_USERNAME; retained for
    // the core's lifetime so the pointer remains valid after the callback returns.
    NSString *_usernameString;

    // Stable C-string storage for directory paths returned via environment callbacks.
    // Cores may cache the returned pointer, so we must keep the backing char* alive
    // for the entire core lifetime. Using strdup + free rather than NSString.UTF8String
    // which is tied to an autorelease pool.
    char *_systemDirCString;
    char *_saveDirCString;
    char *_coreAssetsDirCString;
    char *_libretroPathCString;

    // Software video buffer (used in ObjCBridgedCoreBridge / PVEmulatorCore mode)
    uint8_t *_videoBufferData;
    NSUInteger _videoBufferBytesPerRow;

    // Input state — joypad bitmask per player (bit N = RETRO_DEVICE_ID_JOYPAD_N)
    uint16_t _joypadState[THIN_MAX_PLAYERS];

    // Analog axis state per player: [player][index*2 + axis]
    // index 0 = left stick, 1 = right stick; axis 0 = X, 1 = Y
    int16_t _analogState[THIN_MAX_PLAYERS][THIN_MAX_ANALOG_AXES];

    // Keyboard state — indexed by retro_key enum (RETROK_*), max 512 keys
    bool _keyState[512];

    // Mouse state — relative deltas (cleared after read) and button bitmask
    int16_t _mouseRelX;
    int16_t _mouseRelY;
    uint32_t _mouseButtons; // bit N = RETRO_DEVICE_ID_MOUSE_* button N

    // Pointer (touch) state — normalized coordinates and pressed flag
    int16_t _pointerX;
    int16_t _pointerY;
    bool _pointerPressed;

    // Pause flag — when YES, audio callbacks discard samples to prevent
    // stale audio from leaking through during the pause/resume transition.
    BOOL _audioPaused;
}

/// Internal callback methods invoked by the static C trampolines.
- (void)_thinVideoRefresh:(const void *)data width:(unsigned)w height:(unsigned)h pitch:(size_t)pitch;
- (void)_thinAudioSample:(int16_t)left right:(int16_t)right;
- (size_t)_thinAudioSampleBatch:(const int16_t *)data frames:(size_t)frames;
- (void)_thinInputPoll;
- (int16_t)_thinInputStatePort:(unsigned)port device:(unsigned)dev index:(unsigned)idx id:(unsigned)bid;
- (BOOL)handleEnvironmentCommand:(unsigned)cmd data:(void *)data;
- (void)_parseV1OptionDefinition:(const struct retro_core_option_definition *)def;
- (void)_parseCoreOptionsV2:(const struct retro_core_options_v2 *)opts;
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
- (uintptr_t)currentEmuFBO;
#endif

@end

// ---------------------------------------------------------------------------
// MARK: - Thread-local current-instance pointer (for static C callbacks)
// ---------------------------------------------------------------------------

/// Thread-local reference to the currently-executing ThinFrontend instance.
/// Using __thread avoids the need for locks around C callback dispatch since
/// each emulation thread has exactly one frontend.
/// Note: __thread TLS cannot use __weak (non-trivial ownership), so we use
/// __unsafe_unretained. This is safe because the frontend instance outlives
/// its emulation thread — the instance is retained by the view controller.
static __thread __unsafe_unretained PVThinLibretroFrontend *_thinCurrentTLS = nil;

// ---------------------------------------------------------------------------
// MARK: - Static C callbacks (bridge → ObjC instance)
// ---------------------------------------------------------------------------

static void thin_video_refresh(const void *data, unsigned width, unsigned height, size_t pitch) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return;
    [self _thinVideoRefresh:data width:width height:height pitch:pitch];
}

static void thin_audio_sample(int16_t left, int16_t right) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return;
    [self _thinAudioSample:left right:right];
}

static size_t thin_audio_sample_batch(const int16_t *data, size_t frames) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return 0;
    return [self _thinAudioSampleBatch:data frames:frames];
}

static void thin_input_poll(void) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return;
    [self _thinInputPoll];
}

static int16_t thin_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return 0;
    return [self _thinInputStatePort:port device:device index:index id:id];
}

/// libretro logging bridge.
static void thin_core_log(enum retro_log_level level, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    char buf[2048];
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    NSString *msg = [NSString stringWithUTF8String:buf];
    switch (level) {
        case RETRO_LOG_DEBUG: DLOG(@"[Core] %@", msg); break;
        case RETRO_LOG_INFO:  ILOG(@"[Core] %@", msg); break;
        case RETRO_LOG_WARN:  WLOG(@"[Core] %@", msg); break;
        case RETRO_LOG_ERROR: ELOG(@"[Core] %@", msg); break;
        default: ILOG(@"[Core] %@", msg); break;
    }
}

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
/// hw_get_current_framebuffer — called from the core to get the FBO to render into.
static uintptr_t thin_hw_get_current_framebuffer(void) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return 0;
    return [self currentEmuFBO];
}
#endif

/// hw_get_proc_address — called from the core to resolve GL symbols.
static retro_proc_address_t thin_hw_get_proc_address(const char *sym) {
    return (retro_proc_address_t)dlsym(RTLD_DEFAULT, sym);
}

// ---------------------------------------------------------------------------
// MARK: - Environment callback (large switch, libretro.h only)
// ---------------------------------------------------------------------------

static bool thin_environment(unsigned cmd, void *data) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) {
        ELOG(@"ThinFrontend: environ callback with no active instance (cmd=%u)", cmd);
        return false;
    }
    return [self handleEnvironmentCommand:cmd data:data];
}

// ---------------------------------------------------------------------------
// MARK: - Implementation
// ---------------------------------------------------------------------------

@implementation PVThinLibretroFrontend

@synthesize romPath = _romPath;
@synthesize biosPath = _biosPath;
@synthesize savePath = _savePath;
@synthesize frontendDelegate = _frontendDelegate;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
- (uintptr_t)currentEmuFBO {
    return (uintptr_t)_emuFBO;
}
#endif

- (instancetype)init {
    if ((self = [super init])) {
        _dylibHandle = NULL;
        memset(&_sym, 0, sizeof(_sym));
        memset(&_hwRenderCallback, 0, sizeof(_hwRenderCallback));
        _hwRenderRequested = NO;
        _retroPixelFormat = RETRO_PIXEL_FORMAT_0RGB1555;
        _coreOptions = [NSMutableDictionary dictionary];
        _coreOptionsDirty = NO;
        _optionsLock = OS_UNFAIR_LOCK_INIT;
        _coreOptionDefinitions = [NSMutableArray array];
        _coreOptionCategories = [NSMutableArray array];
        _coreOptionVisibility = [NSMutableDictionary dictionary];
        _serializationQuirks = 0;
        _hasDiskControl = NO;
        _hasDiskControlExt = NO;
        _hasPendingGeometry = NO;
        _messageInterfaceVersion = 0;
        _hasFrameTimeCallback = NO;
        _hasAudioCallback = NO;
        _keyboardEventCb = NULL;
        _speedMultiplier = 1.0;
        _videoBufferData = NULL;
        _videoBufferBytesPerRow = 0;
        memset(_joypadState, 0, sizeof(_joypadState));
        memset(_analogState, 0, sizeof(_analogState));
        memset(_keyState, 0, sizeof(_keyState));
        _mouseRelX = 0;
        _mouseRelY = 0;
        _mouseButtons = 0;
        _pointerX = 0;
        _pointerY = 0;
        _pointerPressed = false;
        _audioPaused = NO;
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        _glContext = nil;
        _glShareContext = nil;
        _ioSurface = NULL;
        _emuFBO = 0;
        _emuColorTex = 0;
        _emuDepthRB = 0;
#endif
    }
    return self;
}

- (void)dealloc {
    [self stopEmulation];
    [self unloadCore];
    if (_videoBufferData) { free(_videoBufferData); _videoBufferData = NULL; }
    if (_systemDirCString)    { free(_systemDirCString);    _systemDirCString = NULL; }
    if (_saveDirCString)      { free(_saveDirCString);      _saveDirCString = NULL; }
    if (_coreAssetsDirCString){ free(_coreAssetsDirCString);_coreAssetsDirCString = NULL; }
    if (_libretroPathCString) { free(_libretroPathCString); _libretroPathCString = NULL; }
}

// ---------------------------------------------------------------------------
// MARK: - Core loading via dlopen
// ---------------------------------------------------------------------------

- (BOOL)loadCoreAtPath:(NSString *)corePath error:(NSError **)error {
    if (_dylibHandle) {
        [self unloadCore];
    }

    ILOG(@"ThinFrontend: loading core at %@", corePath);
    _dylibHandle = dlopen(corePath.UTF8String, RTLD_LOCAL | RTLD_LAZY);
    if (!_dylibHandle) {
        NSString *reason = [NSString stringWithUTF8String:(dlerror() ?: "unknown error")];
        ELOG(@"ThinFrontend: dlopen failed: %@", reason);
        if (error) {
            *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        return NO;
    }

    // Resolve required symbols
    THIN_RESOLVE(_sym, _dylibHandle, retro_init);
    THIN_RESOLVE(_sym, _dylibHandle, retro_deinit);
    THIN_RESOLVE(_sym, _dylibHandle, retro_api_version);
    THIN_RESOLVE(_sym, _dylibHandle, retro_get_system_info);
    THIN_RESOLVE(_sym, _dylibHandle, retro_get_system_av_info);
    THIN_RESOLVE(_sym, _dylibHandle, retro_load_game);
    THIN_RESOLVE(_sym, _dylibHandle, retro_unload_game);
    THIN_RESOLVE(_sym, _dylibHandle, retro_run);
    THIN_RESOLVE(_sym, _dylibHandle, retro_reset);
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_environment);
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_video_refresh);
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_audio_sample);
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_audio_sample_batch);
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_input_poll);
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_input_state);
    THIN_RESOLVE(_sym, _dylibHandle, retro_serialize_size);
    THIN_RESOLVE(_sym, _dylibHandle, retro_serialize);
    THIN_RESOLVE(_sym, _dylibHandle, retro_unserialize);
    THIN_RESOLVE(_sym, _dylibHandle, retro_cheat_reset);
    THIN_RESOLVE(_sym, _dylibHandle, retro_cheat_set);
    THIN_RESOLVE(_sym, _dylibHandle, retro_get_memory_data);
    THIN_RESOLVE(_sym, _dylibHandle, retro_get_memory_size);

    // All symbols called unconditionally in startWithROMPath: must be present.
    // Checking only retro_init/retro_set_environment/retro_run is insufficient because
    // startWithROMPath: also calls all retro_set_* callback setters and retro_load_game.
    BOOL missingRequired = !_sym.retro_init
        || !_sym.retro_deinit
        || !_sym.retro_set_environment
        || !_sym.retro_set_video_refresh
        || !_sym.retro_set_audio_sample
        || !_sym.retro_set_audio_sample_batch
        || !_sym.retro_set_input_poll
        || !_sym.retro_set_input_state
        || !_sym.retro_load_game
        || !_sym.retro_unload_game
        || !_sym.retro_run;
    if (missingRequired) {
        NSString *reason = @"Core missing required retro_* symbols (init/deinit/load_game/run/set_* callbacks)";
        ELOG(@"ThinFrontend: %@", reason);
        if (error) {
            *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        [self unloadCore];
        return NO;
    }

    // Read system info immediately (does not require retro_init)
    if (_sym.retro_get_system_info) {
        _sym.retro_get_system_info(&_rawSystemInfo);
        ILOG(@"ThinFrontend: loaded core '%s' v%s ext=%s",
             _rawSystemInfo.library_name,
             _rawSystemInfo.library_version,
             _rawSystemInfo.valid_extensions ?: "");
    }

    return YES;
}

- (void)unloadCore {
    if (_dylibHandle) {
        ILOG(@"ThinFrontend: unloading core dylib");
        dlclose(_dylibHandle);
        _dylibHandle = NULL;
        memset(&_sym, 0, sizeof(_sym));
    }
}

// ---------------------------------------------------------------------------
// MARK: - Core lifecycle
// ---------------------------------------------------------------------------

- (BOOL)startWithROMPath:(NSString *)romPath error:(NSError **)error {
    if (!_dylibHandle) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"No core loaded — call loadCoreAtPath:error: first"}];
        }
        return NO;
    }

    // Install TLS pointer for C callbacks
    _thinCurrentTLS = self;
    _romPath = [romPath copy];

    // Wire callbacks before retro_init
    _sym.retro_set_environment(thin_environment);
    _sym.retro_set_video_refresh(thin_video_refresh);
    _sym.retro_set_audio_sample(thin_audio_sample);
    _sym.retro_set_audio_sample_batch(thin_audio_sample_batch);
    _sym.retro_set_input_poll(thin_input_poll);
    _sym.retro_set_input_state(thin_input_state);

    _sym.retro_init();

    // NOTE: Do NOT call retro_get_system_av_info before retro_load_game.
    // The libretro API requires content to be loaded first; many cores
    // (e.g. mGBA) store per-game state in globals that are NULL until
    // retro_load_game, so calling retro_get_system_av_info early causes
    // a NULL-pointer dereference crash.

    // Load content
    struct retro_game_info gameInfo = {0};
    NSData *romData = nil;

    if (!_rawSystemInfo.need_fullpath) {
        romData = [NSData dataWithContentsOfFile:romPath];
        if (!romData) {
            ELOG(@"ThinFrontend: could not read ROM at %@", romPath);
            if (error) {
                *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                             code:4
                                         userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot read ROM: %@", romPath]}];
            }
            _sym.retro_deinit();
            _thinCurrentTLS = nil;
            return NO;
        }
        gameInfo.data = romData.bytes;
        gameInfo.size = romData.length;
    }

    gameInfo.path = romPath.UTF8String;

    bool loaded = _sym.retro_load_game(&gameInfo);
    if (!loaded) {
        ELOG(@"ThinFrontend: retro_load_game returned false");
        if (error) {
            *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                         code:5
                                     userInfo:@{NSLocalizedDescriptionKey: @"retro_load_game failed"}];
        }
        _sym.retro_deinit();
        _thinCurrentTLS = nil;
        return NO;
    }

    // Refresh AV info after load (core may change geometry)
    if (_sym.retro_get_system_av_info) {
        _sym.retro_get_system_av_info(&_rawAVInfo);
    }

    // Allocate the software video buffer now that we know the geometry.
    // Without this, _videoBufferData is NULL and the Metal renderer gets
    // no frames (videoBuffer returns NULL → "Missing video buffer").
    [self _allocateVideoBuffer];

    // Report save state support based on whether the core implements serialization
    self.supportsSaveStates = (_sym.retro_serialize_size != NULL && _sym.retro_serialize != NULL && _sym.retro_unserialize != NULL);

    // Load battery save (SRAM) if one exists from a previous session
    [self loadBatterySaveData];

    ILOG(@"ThinFrontend: core started — %ux%u @ %.2f fps, audio %.0f Hz, saveStates: %@",
         _rawAVInfo.geometry.base_width,
         _rawAVInfo.geometry.base_height,
         _rawAVInfo.timing.fps,
         _rawAVInfo.timing.sample_rate,
         self.supportsSaveStates ? @"YES" : @"NO");

    return YES;
}

- (void)stopEmulation {
    _audioPaused = YES;
    // Flush battery save (SRAM) before tearing down the core
    [self saveBatterySaveData];
    [super stopEmulation]; // stops emulation loop thread before retro teardown
    [self clearAllInput];
    if (_sym.retro_unload_game) {
        _sym.retro_unload_game();
    }
    if (_sym.retro_deinit) {
        _sym.retro_deinit();
    }
    [self teardownHardwareContext];
    _thinCurrentTLS = nil;
}

- (void)setPauseEmulation:(BOOL)flag {
    _audioPaused = flag;
    [super setPauseEmulation:flag];
}

- (void)runFrame {
    if (!_sym.retro_run) return;

    // Drive the frame-time callback if the core registered one
    if (_hasFrameTimeCallback && _frameTimeCallback.callback) {
        int64_t nowUs = (int64_t)(CACurrentMediaTime() * 1000000.0);
        retro_usec_t delta = (_lastFrameTimeUs == 0) ? (retro_usec_t)(1000000.0 / _rawAVInfo.timing.fps) : (retro_usec_t)(nowUs - _lastFrameTimeUs);
        _lastFrameTimeUs = nowUs;
        _frameTimeCallback.callback(delta);
    }

    _thinCurrentTLS = self;
    _sym.retro_run();
}

// ---------------------------------------------------------------------------
// MARK: - State / Cheats
// ---------------------------------------------------------------------------

- (nullable NSData *)saveState {
    if (!_sym.retro_serialize_size || !_sym.retro_serialize) return nil;
    size_t size = _sym.retro_serialize_size();
    if (size == 0) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (!_sym.retro_serialize(data.mutableBytes, size)) {
        ELOG(@"ThinFrontend: retro_serialize failed");
        return nil;
    }
    return data;
}

- (BOOL)loadState:(NSData *)stateData {
    if (!_sym.retro_unserialize || !stateData) return NO;
    return _sym.retro_unserialize(stateData.bytes, stateData.length);
}

// MARK: - File-based save states (compatible with PVRetroArch save files)

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError **)error {
    NSData *data = [self saveState];
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                         code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                     userInfo:@{NSLocalizedDescriptionKey: @"Core serialization failed"}];
        }
        return NO;
    }
    BOOL written = [data writeToFile:fileName atomically:YES];
    if (!written && error) {
        *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                     code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to write save state file"}];
    }
    return written;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    NSError *error = nil;
    BOOL success = [self saveStateToFileAtPath:fileName error:&error];
    if (block) block(success, error);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:fileName];
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                         code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithFormat:@"Cannot read save state: %@", fileName]}];
        }
        return NO;
    }
    BOOL success = [self loadState:data];
    if (!success && error) {
        *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                     code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                 userInfo:@{NSLocalizedDescriptionKey: @"Core deserialization failed"}];
    }
    return success;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    NSError *error = nil;
    BOOL success = [self loadStateFromFileAtPath:fileName error:&error];
    if (block) block(success, error);
}

// MARK: - Battery saves (SRAM)

- (BOOL)saveBatterySaveData {
    if (!_sym.retro_get_memory_data || !_sym.retro_get_memory_size) return NO;
    void *data = _sym.retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    size_t size = _sym.retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    if (!data || size == 0) return NO;

    NSString *savePath = self.batterySavesPath;
    if (!savePath) return NO;

    // Use ROM filename as base for the .srm file
    NSString *romBase = [_romPath.lastPathComponent stringByDeletingPathExtension];
    NSString *srmPath = [[savePath stringByAppendingPathComponent:romBase]
                         stringByAppendingPathExtension:@"srm"];

    // Ensure directory exists
    [[NSFileManager defaultManager] createDirectoryAtPath:savePath
                              withIntermediateDirectories:YES attributes:nil error:nil];

    NSData *srmData = [NSData dataWithBytes:data length:size];
    BOOL ok = [srmData writeToFile:srmPath atomically:YES];
    if (ok) {
        ILOG(@"ThinFrontend: saved SRAM (%zu bytes) to %@", size, srmPath.lastPathComponent);
    } else {
        ELOG(@"ThinFrontend: failed to save SRAM to %@", srmPath);
    }
    return ok;
}

- (BOOL)loadBatterySaveData {
    if (!_sym.retro_get_memory_data || !_sym.retro_get_memory_size) return NO;
    void *data = _sym.retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
    size_t size = _sym.retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
    if (!data || size == 0) return NO;

    NSString *savePath = self.batterySavesPath;
    if (!savePath) return NO;

    NSString *romBase = [_romPath.lastPathComponent stringByDeletingPathExtension];
    NSString *srmPath = [[savePath stringByAppendingPathComponent:romBase]
                         stringByAppendingPathExtension:@"srm"];

    NSData *srmData = [NSData dataWithContentsOfFile:srmPath];
    if (!srmData) return NO;

    size_t copySize = MIN((size_t)srmData.length, size);
    memcpy(data, srmData.bytes, copySize);
    ILOG(@"ThinFrontend: loaded SRAM (%zu bytes) from %@", copySize, srmPath.lastPathComponent);
    return YES;
}

// MARK: - Cheats

- (void)setCheatCode:(NSString *)code enabled:(BOOL)enabled index:(unsigned)index {
    if (_sym.retro_cheat_set) {
        _sym.retro_cheat_set(index, (bool)enabled, code.UTF8String);
    }
}

- (void)resetCheats {
    if (_sym.retro_cheat_reset) {
        _sym.retro_cheat_reset();
    }
}

// ---------------------------------------------------------------------------
// MARK: - Core options
// ---------------------------------------------------------------------------

- (NSDictionary<NSString *, NSString *> *)coreOptions {
    os_unfair_lock_lock(&_optionsLock);
    NSDictionary *copy = [_coreOptions copy];
    os_unfair_lock_unlock(&_optionsLock);
    return copy;
}

- (void)setCoreOption:(NSString *)key value:(NSString *)value {
    os_unfair_lock_lock(&_optionsLock);
    _coreOptions[key] = value;
    _coreOptionsDirty = YES;
    os_unfair_lock_unlock(&_optionsLock);
}

- (NSArray<NSDictionary<NSString *, id> *> *)coreOptionDefinitions {
    os_unfair_lock_lock(&_optionsLock);
    NSArray *copy = [_coreOptionDefinitions copy];
    os_unfair_lock_unlock(&_optionsLock);
    return copy;
}

- (NSArray<NSDictionary<NSString *, id> *> *)coreOptionCategories {
    os_unfair_lock_lock(&_optionsLock);
    NSArray *copy = [_coreOptionCategories copy];
    os_unfair_lock_unlock(&_optionsLock);
    return copy;
}

- (NSDictionary<NSString *, NSNumber *> *)coreOptionVisibility {
    os_unfair_lock_lock(&_optionsLock);
    NSDictionary *copy = [_coreOptionVisibility copy];
    os_unfair_lock_unlock(&_optionsLock);
    return copy;
}

// ---------------------------------------------------------------------------
// MARK: - Property synthesized accessors
// ---------------------------------------------------------------------------

- (PVLibretroAVInfo)avInfo {
    PVLibretroAVInfo info;
    info.base_width   = _rawAVInfo.geometry.base_width;
    info.base_height  = _rawAVInfo.geometry.base_height;
    info.max_width    = _rawAVInfo.geometry.max_width;
    info.max_height   = _rawAVInfo.geometry.max_height;
    info.fps          = _rawAVInfo.timing.fps;
    info.sample_rate  = _rawAVInfo.timing.sample_rate;
    info.aspect_ratio = _rawAVInfo.geometry.aspect_ratio;
    return info;
}

- (PVLibretroSystemInfo)systemInfo {
    PVLibretroSystemInfo info;
    memset(&info, 0, sizeof(info));
    if (_rawSystemInfo.library_name)    strlcpy(info.library_name,    _rawSystemInfo.library_name,    sizeof(info.library_name));
    if (_rawSystemInfo.library_version) strlcpy(info.library_version, _rawSystemInfo.library_version, sizeof(info.library_version));
    if (_rawSystemInfo.valid_extensions) strlcpy(info.valid_extensions, _rawSystemInfo.valid_extensions, sizeof(info.valid_extensions));
    info.need_fullpath = _rawSystemInfo.need_fullpath;
    info.block_extract = _rawSystemInfo.block_extract;
    return info;
}

- (PVLibretroPixelFormat)libretroPixelFormat {
    switch (_retroPixelFormat) {
        case RETRO_PIXEL_FORMAT_0RGB1555: return PVLibretroPixelFormatRGB1555;
        case RETRO_PIXEL_FORMAT_XRGB8888: return PVLibretroPixelFormatXRGB8888;
        case RETRO_PIXEL_FORMAT_RGB565:   return PVLibretroPixelFormatRGB565;
        default: return PVLibretroPixelFormatRGB1555;
    }
}

// ---------------------------------------------------------------------------
// MARK: - ObjCBridgedCoreBridge / EmulatorCoreVideoDelegate overrides
// ---------------------------------------------------------------------------

#if !TARGET_OS_WATCH
- (GLenum)pixelFormat {
    switch (_retroPixelFormat) {
        case RETRO_PIXEL_FORMAT_XRGB8888: return GL_BGRA_EXT;
        case RETRO_PIXEL_FORMAT_RGB565:   return GL_RGB;
        default:                          return GL_RGBA;    // 0RGB1555 — upsampled
    }
}

- (GLenum)pixelType {
    switch (_retroPixelFormat) {
        case RETRO_PIXEL_FORMAT_XRGB8888: return GL_UNSIGNED_BYTE;
        case RETRO_PIXEL_FORMAT_RGB565:   return GL_UNSIGNED_SHORT_5_6_5;
        default:                          return GL_UNSIGNED_SHORT_5_5_5_1;
    }
}

- (GLenum)internalPixelFormat {
    switch (_retroPixelFormat) {
        case RETRO_PIXEL_FORMAT_XRGB8888: return GL_RGBA8_OES;
        default:                          return GL_RGB;
    }
}
#endif

- (NSTimeInterval)frameInterval {
    return (_rawAVInfo.timing.fps > 0.0) ? _rawAVInfo.timing.fps : 60.0;
}

- (const void *)videoBuffer { return _videoBufferData; }

- (CGRect)screenRect {
    unsigned w = _rawAVInfo.geometry.base_width  ?: 256;
    unsigned h = _rawAVInfo.geometry.base_height ?: 240;
    return CGRectMake(0, 0, w, h);
}

- (CGSize)aspectSize {
    unsigned w = _rawAVInfo.geometry.base_width  ?: 256;
    unsigned h = _rawAVInfo.geometry.base_height ?: 240;
    float    ar = _rawAVInfo.geometry.aspect_ratio;
    if (ar > 0.01f) { return CGSizeMake((CGFloat)(h * ar), (CGFloat)h); }
    return CGSizeMake((CGFloat)w, (CGFloat)h);
}

- (CGSize)bufferSize {
    unsigned w = _rawAVInfo.geometry.max_width  ?: (_rawAVInfo.geometry.base_width  ?: 256);
    unsigned h = _rawAVInfo.geometry.max_height ?: (_rawAVInfo.geometry.base_height ?: 240);
    return CGSizeMake((CGFloat)w, (CGFloat)h);
}

- (double)audioSampleRate {
    return (_rawAVInfo.timing.sample_rate > 0.0) ? _rawAVInfo.timing.sample_rate : 44100.0;
}

- (NSUInteger)channelCount { return 2; }

- (void)executeFrame { [self runFrame]; }

// ---------------------------------------------------------------------------
// MARK: - loadFileAtPath / startEmulation overrides for PVEmulatorCore flow
// ---------------------------------------------------------------------------

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    self.romPath = path;
    NSString *corePath = [self _resolvedCoreDylibPath];
    if (!corePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                         code:10
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         [NSString stringWithFormat:@"Could not locate dylib for coreIdentifier '%@'", self.coreIdentifier ?: @"(nil)"]}];
        }
        return NO;
    }
    return [self loadCoreAtPath:corePath error:error];
}

- (void)startEmulation {
    NSError *error = nil;
    if (![self startWithROMPath:self.romPath error:&error]) {
        ELOG(@"ThinFrontend: startWithROMPath failed: %@", error);
        return;
    }
    [self _allocateVideoBuffer];
    // _frameInterval ivar read by PVCoreObjCBridge emulation loop timing
    _frameInterval = (_rawAVInfo.timing.fps > 0.0) ? _rawAVInfo.timing.fps : 60.0;
    [super startEmulation];
}

// ---------------------------------------------------------------------------
// MARK: - Callback routing (delegate or direct-to-buffer)
// ---------------------------------------------------------------------------

- (void)_thinVideoRefresh:(const void *)data width:(unsigned)w height:(unsigned)h pitch:(size_t)pitch {
    if (self.frontendDelegate) {
        [self.frontendDelegate libretroFrontend:self didRenderBuffer:data width:w height:h pitch:pitch];
        return;
    }
    if (!data || !_videoBufferData) return;
    NSUInteger maxW = (_rawAVInfo.geometry.max_width  ?: w);
    NSUInteger bpp  = (_retroPixelFormat == RETRO_PIXEL_FORMAT_XRGB8888) ? 4 : 2;
    NSUInteger dstStride  = maxW * bpp;
    NSUInteger copyBytes  = MIN(w, maxW) * bpp;
    for (unsigned y = 0; y < h; y++) {
        memcpy(_videoBufferData + (NSUInteger)y * dstStride,
               (const uint8_t *)data + (NSUInteger)y * pitch,
               copyBytes);
    }
}

- (void)_thinAudioSample:(int16_t)left right:(int16_t)right {
    if (_audioPaused) return; // Discard audio while paused
    if (self.frontendDelegate) {
        [self.frontendDelegate libretroFrontend:self didEmitAudioLeft:left right:right];
        return;
    }
    int16_t buf[2] = {left, right};
    [[self ringBufferAtIndex:0] write:buf size:4];
}

- (size_t)_thinAudioSampleBatch:(const int16_t *)data frames:(size_t)frames {
    if (_audioPaused) return frames; // Discard audio while paused (consume to avoid backpressure)
    if (self.frontendDelegate) {
        return [self.frontendDelegate libretroFrontend:self didEmitAudioBatch:data frames:frames];
    }
    [[self ringBufferAtIndex:0] write:data size:frames * 2 * sizeof(int16_t)];
    return frames;
}

- (void)_thinInputPoll {
    if (self.frontendDelegate) {
        [self.frontendDelegate libretroFrontendPollInput:self];
    }
    // In PVEmulatorCore mode input is driven by GCController callbacks.
}

- (int16_t)_thinInputStatePort:(unsigned)port device:(unsigned)dev index:(unsigned)idx id:(unsigned)bid {
    if (self.frontendDelegate) {
        return [self.frontendDelegate libretroFrontend:self inputStateForPort:port device:dev index:idx id:bid];
    }

    // Direct bitmask-based input (used by PVThinLibretroCore Swift responder protocols)
    if (port >= THIN_MAX_PLAYERS) return 0;

    unsigned deviceType = dev & RETRO_DEVICE_MASK;

    if (deviceType == RETRO_DEVICE_JOYPAD) {
        if (bid == RETRO_DEVICE_ID_JOYPAD_MASK) {
            // Bitmask query — return all buttons at once
            return _joypadState[port];
        }
        if (bid <= 15) {
            return (_joypadState[port] >> bid) & 1;
        }
        return 0;
    }

    if (deviceType == RETRO_DEVICE_ANALOG) {
        // idx: 0 = left stick, 1 = right stick
        // bid: 0 = X axis, 1 = Y axis
        if (idx <= 1 && bid <= 1) {
            return _analogState[port][idx * 2 + bid];
        }
        return 0;
    }

    if (deviceType == RETRO_DEVICE_KEYBOARD) {
        if (bid < 512) {
            return _keyState[bid] ? 1 : 0;
        }
        return 0;
    }

    if (deviceType == RETRO_DEVICE_MOUSE) {
        switch (bid) {
            case RETRO_DEVICE_ID_MOUSE_X: {
                int16_t dx = _mouseRelX;
                _mouseRelX = 0; // consume delta after read
                return dx;
            }
            case RETRO_DEVICE_ID_MOUSE_Y: {
                int16_t dy = _mouseRelY;
                _mouseRelY = 0; // consume delta after read
                return dy;
            }
            case RETRO_DEVICE_ID_MOUSE_LEFT:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_LEFT)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_RIGHT:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_RIGHT)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_MIDDLE:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_MIDDLE)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_WHEELUP:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_WHEELUP)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_WHEELDOWN:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_WHEELDOWN)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELUP:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELUP)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELDOWN:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELDOWN)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_BUTTON_4:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_BUTTON_4)) ? 1 : 0;
            case RETRO_DEVICE_ID_MOUSE_BUTTON_5:
                return (_mouseButtons & (1 << RETRO_DEVICE_ID_MOUSE_BUTTON_5)) ? 1 : 0;
            default:
                return 0;
        }
    }

    if (deviceType == RETRO_DEVICE_POINTER) {
        switch (bid) {
            case RETRO_DEVICE_ID_POINTER_X:
                return _pointerX;
            case RETRO_DEVICE_ID_POINTER_Y:
                return _pointerY;
            case RETRO_DEVICE_ID_POINTER_PRESSED:
                return _pointerPressed ? 1 : 0;
            case RETRO_DEVICE_ID_POINTER_COUNT:
                return _pointerPressed ? 1 : 0;
            default:
                return 0;
        }
    }

    return 0;
}

// ---------------------------------------------------------------------------
// MARK: - Input state management
// ---------------------------------------------------------------------------

- (void)setButton:(unsigned)buttonId pressed:(BOOL)pressed forPlayer:(unsigned)player {
    if (player >= THIN_MAX_PLAYERS || buttonId > 15) return;
    if (pressed) {
        _joypadState[player] |= (1 << buttonId);
    } else {
        _joypadState[player] &= ~(1 << buttonId);
    }
}

- (void)setAnalogIndex:(unsigned)index axis:(unsigned)axis value:(int16_t)value forPlayer:(unsigned)player {
    if (player >= THIN_MAX_PLAYERS || index > 1 || axis > 1) return;
    _analogState[player][index * 2 + axis] = value;
}

- (void)clearAllInput {
    memset(_joypadState, 0, sizeof(_joypadState));
    memset(_analogState, 0, sizeof(_analogState));
    memset(_keyState, 0, sizeof(_keyState));
    _mouseRelX = 0;
    _mouseRelY = 0;
    _mouseButtons = 0;
    _pointerX = 0;
    _pointerY = 0;
    _pointerPressed = false;
}

// MARK: Keyboard input

- (void)setKeyState:(unsigned)keycode pressed:(BOOL)pressed {
    if (keycode < 512) {
        _keyState[keycode] = pressed ? true : false;
    }
    // Also forward to the core's keyboard callback if registered
    if (_keyboardEventCb) {
        _keyboardEventCb(pressed, (enum retro_key)keycode, 0, RETROKMOD_NONE);
    }
}

// MARK: Mouse input

- (void)setMouseDeltaX:(int16_t)dx deltaY:(int16_t)dy {
    _mouseRelX += dx;
    _mouseRelY += dy;
}

- (void)setMouseButton:(unsigned)button pressed:(BOOL)pressed {
    if (button > 31) return;
    if (pressed) {
        _mouseButtons |= (1 << button);
    } else {
        _mouseButtons &= ~(1 << button);
    }
}

// MARK: Pointer (touch) input

- (void)setPointerX:(int16_t)x y:(int16_t)y pressed:(BOOL)pressed {
    _pointerX = x;
    _pointerY = y;
    _pointerPressed = pressed ? true : false;
}

// ---------------------------------------------------------------------------
// MARK: - Private helpers
// ---------------------------------------------------------------------------

- (nullable NSString *)_resolvedCoreDylibPath {
    NSString *identifier = self.coreIdentifier;
    if (!identifier) { ELOG(@"ThinFrontend: coreIdentifier not set"); return nil; }

    NSString *frameworkFolder, *executableName;
    if ([identifier hasSuffix:@".libretro.framework"]) {
        frameworkFolder = identifier;
        executableName  = [identifier stringByDeletingPathExtension]; // drops .framework
    } else if ([identifier hasSuffix:@".libretro"]) {
        frameworkFolder = [identifier stringByAppendingPathExtension:@"framework"];
        executableName  = identifier;
    } else {
        executableName  = [NSString stringWithFormat:@"%@.libretro", identifier];
        frameworkFolder = [NSString stringWithFormat:@"%@.libretro.framework", identifier];
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *bases = @[
        [NSBundle mainBundle].privateFrameworksPath ?: @"",
        [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"Frameworks"],
    ];
    for (NSString *base in bases) {
        if (!base.length) continue;
        NSString *frameworkPath = [base stringByAppendingPathComponent:frameworkFolder];
        if (![fm fileExistsAtPath:frameworkPath]) continue;
        NSBundle *bundle = [NSBundle bundleWithPath:frameworkPath];
        if (bundle.executablePath && [fm fileExistsAtPath:bundle.executablePath]) {
            return bundle.executablePath;
        }
        NSString *direct = [frameworkPath stringByAppendingPathComponent:executableName];
        if ([fm fileExistsAtPath:direct]) return direct;
    }
    ELOG(@"ThinFrontend: dylib not found for identifier '%@'", identifier);
    return nil;
}

- (void)_allocateVideoBuffer {
    if (_videoBufferData) { free(_videoBufferData); _videoBufferData = NULL; }
    unsigned maxW = _rawAVInfo.geometry.max_width  ?: (_rawAVInfo.geometry.base_width  ?: 1024);
    unsigned maxH = _rawAVInfo.geometry.max_height ?: (_rawAVInfo.geometry.base_height ?: 1024);
    NSUInteger bpp = (_retroPixelFormat == RETRO_PIXEL_FORMAT_XRGB8888) ? 4 : 2;
    _videoBufferBytesPerRow = (NSUInteger)maxW * bpp;
    _videoBufferData = (uint8_t *)calloc(1, _videoBufferBytesPerRow * (NSUInteger)maxH);
    ILOG(@"ThinFrontend: video buffer %ux%u (%lu bytes/row)", maxW, maxH, (unsigned long)_videoBufferBytesPerRow);
}

- (PVLibretroHWContextType)hwContextType {
    switch (_hwRenderCallback.context_type) {
        case RETRO_HW_CONTEXT_OPENGLES2:        return PVLibretroHWContextOpenGLES2;
        case RETRO_HW_CONTEXT_OPENGLES3:        return PVLibretroHWContextOpenGLES3;
        case RETRO_HW_CONTEXT_OPENGLES_VERSION: return PVLibretroHWContextOpenGLESVer;
        default: return PVLibretroHWContextNone;
    }
}

- (BOOL)usesHardwareRendering {
    return _hwRenderRequested;
}

// ---------------------------------------------------------------------------
// MARK: - Core option parsing helpers
// ---------------------------------------------------------------------------

/// Parse a v1 retro_core_option_definition into our NSDictionary metadata format.
/// MUST be called with _optionsLock held.
- (void)_parseV1OptionDefinition:(const struct retro_core_option_definition *)def {
    NSString *key = [NSString stringWithUTF8String:def->key];
    NSString *desc = def->desc ? [NSString stringWithUTF8String:def->desc] : key;
    id info = def->info ? (id)[NSString stringWithUTF8String:def->info] : [NSNull null];

    NSMutableArray *valuesArray = [NSMutableArray array];
    for (int i = 0; i < RETRO_NUM_CORE_OPTION_VALUES_MAX && def->values[i].value; i++) {
        NSString *val = [NSString stringWithUTF8String:def->values[i].value];
        NSString *label = def->values[i].label
            ? [NSString stringWithUTF8String:def->values[i].label]
            : val;
        [valuesArray addObject:@{@"value": val, @"label": label}];
    }

    NSString *defaultVal = def->default_value
        ? [NSString stringWithUTF8String:def->default_value]
        : ((valuesArray.count > 0) ? valuesArray[0][@"value"] : @"");

    if (!_coreOptions[key]) {
        _coreOptions[key] = defaultVal;
    }

    [_coreOptionDefinitions addObject:@{
        @"key": key,
        @"desc": desc,
        @"info": info,
        @"category": [NSNull null],
        @"values": valuesArray,
        @"default": defaultVal
    }];
}

/// Parse a retro_core_options_v2 struct (categories + definitions).
/// MUST be called with _optionsLock held.
- (void)_parseCoreOptionsV2:(const struct retro_core_options_v2 *)opts {
    [_coreOptionDefinitions removeAllObjects];
    [_coreOptionCategories removeAllObjects];
    [_coreOptionVisibility removeAllObjects];

    // Parse categories
    if (opts->categories) {
        for (const struct retro_core_option_v2_category *cat = opts->categories; cat->key; cat++) {
            NSString *catKey = [NSString stringWithUTF8String:cat->key];
            NSString *catDesc = cat->desc ? [NSString stringWithUTF8String:cat->desc] : catKey;
            id catInfo = cat->info ? (id)[NSString stringWithUTF8String:cat->info] : [NSNull null];
            [_coreOptionCategories addObject:@{
                @"key": catKey,
                @"desc": catDesc,
                @"info": catInfo
            }];
        }
    }

    // Parse definitions
    if (opts->definitions) {
        for (const struct retro_core_option_v2_definition *def = opts->definitions; def->key; def++) {
            NSString *key = [NSString stringWithUTF8String:def->key];
            NSString *desc = def->desc ? [NSString stringWithUTF8String:def->desc] : key;
            id info = def->info ? (id)[NSString stringWithUTF8String:def->info] : [NSNull null];
            id category = def->category_key && strlen(def->category_key) > 0
                ? (id)[NSString stringWithUTF8String:def->category_key]
                : [NSNull null];

            NSMutableArray *valuesArray = [NSMutableArray array];
            for (int i = 0; i < RETRO_NUM_CORE_OPTION_VALUES_MAX && def->values[i].value; i++) {
                NSString *val = [NSString stringWithUTF8String:def->values[i].value];
                NSString *label = def->values[i].label
                    ? [NSString stringWithUTF8String:def->values[i].label]
                    : val;
                [valuesArray addObject:@{@"value": val, @"label": label}];
            }

            NSString *defaultVal = def->default_value
                ? [NSString stringWithUTF8String:def->default_value]
                : ((valuesArray.count > 0) ? valuesArray[0][@"value"] : @"");

            if (!_coreOptions[key]) {
                _coreOptions[key] = defaultVal;
            }

            [_coreOptionDefinitions addObject:@{
                @"key": key,
                @"desc": desc,
                @"info": info,
                @"category": category,
                @"values": valuesArray,
                @"default": defaultVal
            }];
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Environment callback handler
// ---------------------------------------------------------------------------

/// Central switch for all RETRO_ENVIRONMENT_* commands.
/// Only depends on libretro.h structs — no RetroArch internals.
- (BOOL)handleEnvironmentCommand:(unsigned)cmd data:(void *)data {
    switch (cmd) {

        // ---- Rotation ----
        case RETRO_ENVIRONMENT_SET_ROTATION:
            DLOG(@"ThinEnv SET_ROTATION %u", *(unsigned *)data);
            return true;

        // ---- Pixel format ----
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            enum retro_pixel_format fmt = *(enum retro_pixel_format *)data;
            ILOG(@"ThinEnv SET_PIXEL_FORMAT %d", (int)fmt);
            _retroPixelFormat = fmt;
            return true;
        }

        // ---- Can dupe ----
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            if (data) *(bool *)data = true;
            return true;

        // ---- Logging ----
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
            struct retro_log_callback *cb = (struct retro_log_callback *)data;
            cb->log = thin_core_log;
            return true;
        }

        // ---- System / save directories ----
        // Use inherited BIOSPath/saveStatePath from PVCoreObjCBridge (set by PVEmulatorCore)
        // rather than the local _biosPath/_savePath which may not be set.
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY: {
            NSString *sysDir = self.BIOSPath ?: _biosPath;
            if (!sysDir) return false;
            // Cache the C string so the pointer stays valid for the core's lifetime.
            if (_systemDirCString) free(_systemDirCString);
            _systemDirCString = strdup(sysDir.UTF8String);
            if (data) *(const char **)data = _systemDirCString;
            DLOG(@"ThinEnv GET_SYSTEM_DIRECTORY: %@", sysDir);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: {
            NSString *saveDir = self.batterySavesPath ?: _savePath;
            if (!saveDir) return false;
            if (_saveDirCString) free(_saveDirCString);
            _saveDirCString = strdup(saveDir.UTF8String);
            if (data) *(const char **)data = _saveDirCString;
            DLOG(@"ThinEnv GET_SAVE_DIRECTORY: %@", saveDir);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
        /* RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY is the same value (30) */
        {
            NSString *assetsDir = self.BIOSPath ?: _biosPath;
            if (!assetsDir) return false;
            if (_coreAssetsDirCString) free(_coreAssetsDirCString);
            _coreAssetsDirCString = strdup(assetsDir.UTF8String);
            if (data) *(const char **)data = _coreAssetsDirCString;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_LIBRETRO_PATH: {
            // Return empty — the thin frontend doesn't have a fixed "libretro path"
            if (data) *(const char **)data = NULL;
            return false;
        }

        // ---- Core options (v1) ----
        case RETRO_ENVIRONMENT_SET_VARIABLES: {
            const struct retro_variable *vars = (const struct retro_variable *)data;
            if (!vars) return false;
            os_unfair_lock_lock(&_optionsLock);
            [_coreOptionDefinitions removeAllObjects];
            [_coreOptionVisibility removeAllObjects];
            for (const struct retro_variable *v = vars; v->key; v++) {
                NSString *key = [NSString stringWithUTF8String:v->key];
                if (v->value) {
                    NSString *valStr = [NSString stringWithUTF8String:v->value];
                    NSRange semi = [valStr rangeOfString:@"; "];
                    NSString *desc = (semi.location != NSNotFound)
                        ? [valStr substringToIndex:semi.location]
                        : key;
                    NSString *valuesStr = (semi.location != NSNotFound)
                        ? [valStr substringFromIndex:NSMaxRange(semi)]
                        : valStr;
                    NSArray<NSString *> *valueTokens = [valuesStr componentsSeparatedByString:@"|"];
                    NSMutableArray *valuesArray = [NSMutableArray arrayWithCapacity:valueTokens.count];
                    for (NSString *token in valueTokens) {
                        NSString *trimmed = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        if (trimmed.length > 0) {
                            [valuesArray addObject:@{@"value": trimmed, @"label": trimmed}];
                        }
                    }
                    NSString *defaultVal = (valuesArray.count > 0) ? valuesArray[0][@"value"] : @"";
                    if (!_coreOptions[key]) {
                        _coreOptions[key] = defaultVal;
                    }
                    [_coreOptionDefinitions addObject:@{
                        @"key": key,
                        @"desc": desc,
                        @"info": [NSNull null],
                        @"category": [NSNull null],
                        @"values": valuesArray,
                        @"default": defaultVal
                    }];
                }
            }
            os_unfair_lock_unlock(&_optionsLock);
            DLOG(@"ThinEnv SET_VARIABLES: parsed %lu option definitions", (unsigned long)_coreOptionDefinitions.count);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *v = (struct retro_variable *)data;
            if (!v || !v->key) return false;
            NSString *key = [NSString stringWithUTF8String:v->key];
            os_unfair_lock_lock(&_optionsLock);
            NSString *val = _coreOptions[key];
            os_unfair_lock_unlock(&_optionsLock);
            v->value = val ? val.UTF8String : NULL;
            DLOG(@"ThinEnv GET_VARIABLE %s = %@", v->key, val);
            return (val != nil);
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: {
            os_unfair_lock_lock(&_optionsLock);
            bool dirty = _coreOptionsDirty;
            _coreOptionsDirty = NO;
            os_unfair_lock_unlock(&_optionsLock);
            if (data) *(bool *)data = dirty;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_VARIABLE: {
            const struct retro_variable *v = (const struct retro_variable *)data;
            if (!v || !v->key) return false;
            NSString *key   = [NSString stringWithUTF8String:v->key];
            NSString *value = v->value ? [NSString stringWithUTF8String:v->value] : nil;
            os_unfair_lock_lock(&_optionsLock);
            if (value) _coreOptions[key] = value;
            else [_coreOptions removeObjectForKey:key];
            _coreOptionsDirty = YES;
            os_unfair_lock_unlock(&_optionsLock);
            return true;
        }

        // ---- Core options v1 (array of retro_core_option_definition) ----
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS: {
            const struct retro_core_option_definition *defs = (const struct retro_core_option_definition *)data;
            if (!defs) return false;
            os_unfair_lock_lock(&_optionsLock);
            [_coreOptionDefinitions removeAllObjects];
            [_coreOptionCategories removeAllObjects];
            [_coreOptionVisibility removeAllObjects];
            for (const struct retro_core_option_definition *d = defs; d->key; d++) {
                [self _parseV1OptionDefinition:d];
            }
            os_unfair_lock_unlock(&_optionsLock);
            DLOG(@"ThinEnv SET_CORE_OPTIONS: parsed %lu definitions", (unsigned long)_coreOptionDefinitions.count);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL: {
            const struct retro_core_options_intl *intl = (const struct retro_core_options_intl *)data;
            if (!intl || !intl->us) return false;
            const struct retro_core_option_definition *defs = intl->us;
            os_unfair_lock_lock(&_optionsLock);
            [_coreOptionDefinitions removeAllObjects];
            [_coreOptionCategories removeAllObjects];
            [_coreOptionVisibility removeAllObjects];
            for (const struct retro_core_option_definition *d = defs; d->key; d++) {
                [self _parseV1OptionDefinition:d];
            }
            os_unfair_lock_unlock(&_optionsLock);
            DLOG(@"ThinEnv SET_CORE_OPTIONS_INTL: parsed %lu definitions", (unsigned long)_coreOptionDefinitions.count);
            return true;
        }

        // ---- Core options v2 ----
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2: {
            const struct retro_core_options_v2 *opts = (const struct retro_core_options_v2 *)data;
            if (!opts) return false;
            os_unfair_lock_lock(&_optionsLock);
            [self _parseCoreOptionsV2:opts];
            os_unfair_lock_unlock(&_optionsLock);
            DLOG(@"ThinEnv SET_CORE_OPTIONS_V2: %lu categories, %lu definitions",
                 (unsigned long)_coreOptionCategories.count, (unsigned long)_coreOptionDefinitions.count);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL: {
            const struct retro_core_options_v2_intl *intl = (const struct retro_core_options_v2_intl *)data;
            if (!intl || !intl->us) return false;
            os_unfair_lock_lock(&_optionsLock);
            [self _parseCoreOptionsV2:intl->us];
            os_unfair_lock_unlock(&_optionsLock);
            DLOG(@"ThinEnv SET_CORE_OPTIONS_V2_INTL: %lu categories, %lu definitions",
                 (unsigned long)_coreOptionCategories.count, (unsigned long)_coreOptionDefinitions.count);
            return true;
        }

        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY: {
            const struct retro_core_option_display *disp = (const struct retro_core_option_display *)data;
            if (!disp || !disp->key) return true;
            NSString *key = [NSString stringWithUTF8String:disp->key];
            os_unfair_lock_lock(&_optionsLock);
            _coreOptionVisibility[key] = @(disp->visible);
            os_unfair_lock_unlock(&_optionsLock);
            DLOG(@"ThinEnv SET_CORE_OPTIONS_DISPLAY: %@ visible=%d", key, disp->visible);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK:
            return true;
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: {
            *(unsigned *)data = 2; // We speak options v2
            return true;
        }

        // ---- AV info ----
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: {
            const struct retro_system_av_info *info = (const struct retro_system_av_info *)data;
            if (!info) return false;
            _rawAVInfo = *info;
            ILOG(@"ThinEnv SET_SYSTEM_AV_INFO %ux%u (max %ux%u) @ %.2f fps, sample_rate=%.1f",
                 info->geometry.base_width, info->geometry.base_height,
                 info->geometry.max_width, info->geometry.max_height,
                 info->timing.fps, info->timing.sample_rate);
            // Reallocate video buffer since geometry may have changed
            [self _allocateVideoBuffer];
            if ([_frontendDelegate respondsToSelector:@selector(libretroFrontend:didUpdateAVInfo:)]) {
                [_frontendDelegate libretroFrontend:self didUpdateAVInfo:self.avInfo];
            }
            return true;
        }
        case RETRO_ENVIRONMENT_SET_GEOMETRY: {
            const struct retro_game_geometry *geo = (const struct retro_game_geometry *)data;
            if (!geo) return false;
            // Reallocate video buffer if max dimensions grew
            BOOL needsRealloc = (geo->max_width  > _rawAVInfo.geometry.max_width ||
                                 geo->max_height > _rawAVInfo.geometry.max_height);
            _rawAVInfo.geometry = *geo;
            ILOG(@"ThinEnv SET_GEOMETRY %ux%u (max %ux%u) aspect=%.3f",
                 geo->base_width, geo->base_height,
                 geo->max_width, geo->max_height, geo->aspect_ratio);
            if (needsRealloc) {
                [self _allocateVideoBuffer];
            }
            // Notify delegate so the rendering layer can resize
            if ([_frontendDelegate respondsToSelector:@selector(libretroFrontend:didUpdateAVInfo:)]) {
                [_frontendDelegate libretroFrontend:self didUpdateAVInfo:self.avInfo];
            }
            return true;
        }

        // ---- Performance ----
        case RETRO_ENVIRONMENT_GET_PERF_INTERFACE: {
            // Return false (not supported). Returning true with NULL function pointers
            // would allow cores to call them and crash. Cores that query this interface
            // should fall back to their own timing/perf paths when the frontend returns false.
            DLOG(@"ThinEnv GET_PERF_INTERFACE — not supported, returning false");
            return false;
        }
        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
            return true;

        // ---- Capabilities / info queries ----
        case RETRO_ENVIRONMENT_GET_OVERSCAN:
            if (data) *(bool *)data = false;
            return true;
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
            if (data) *(bool *)data = true;
            return true;
        case RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES:
            if (data) *(uint64_t *)data = (1ULL << RETRO_DEVICE_JOYPAD)
                                        | (1ULL << RETRO_DEVICE_ANALOG)
                                        | (1ULL << RETRO_DEVICE_MOUSE)
                                        | (1ULL << RETRO_DEVICE_POINTER);
            return true;
        case RETRO_ENVIRONMENT_GET_INPUT_MAX_USERS:
            if (data) *(unsigned *)data = 8;
            return true;
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true;
        case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
            return true;
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
            return true;
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
            return true;
        case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO:
            return true;
        case RETRO_ENVIRONMENT_SET_CONTENT_INFO_OVERRIDE:
            return true;

        // ---- Username / Language ----
        case RETRO_ENVIRONMENT_GET_USERNAME: {
            // Retain the NSString in an ivar so the UTF8String pointer stays
            // valid for the entire lifetime of the loaded core.
            if (!_usernameString) {
                _usernameString = NSUserName() ?: @"Provenance";
            }
            if (data) *(const char **)data = _usernameString.UTF8String;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_LANGUAGE: {
            if (data) *(unsigned *)data = RETRO_LANGUAGE_ENGLISH;
            return true;
        }

        // ---- Messages ----
        case RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION:
            if (data) *(unsigned *)data = 1;
            return true;
        case RETRO_ENVIRONMENT_SET_MESSAGE: {
            const struct retro_message *msg = (const struct retro_message *)data;
            if (!msg || !msg->msg) return false;
            NSString *msgStr = [NSString stringWithUTF8String:msg->msg];
            ILOG(@"ThinEnv [core message] %@", msgStr);
            if ([_frontendDelegate respondsToSelector:@selector(libretroFrontend:didSetMessage:frames:)]) {
                [_frontendDelegate libretroFrontend:self didSetMessage:msgStr frames:msg->frames];
            }
            // Forward to OSD toast system — assume ~60fps, convert frames to seconds
            NSTimeInterval duration = (msg->frames > 0) ? (NSTimeInterval)msg->frames / 60.0 : 3.0;
            [PVOSDNotification postMessage:msgStr type:PVOSDTypeInfo duration:duration];
            return true;
        }
        case RETRO_ENVIRONMENT_SET_MESSAGE_EXT: {
            const struct retro_message_ext *msg = (const struct retro_message_ext *)data;
            if (!msg || !msg->msg) return false;
            NSString *msgStr = [NSString stringWithUTF8String:msg->msg];

            // Log regardless of target
            switch (msg->level) {
                case RETRO_LOG_DEBUG: DLOG(@"[Core] %@", msgStr); break;
                case RETRO_LOG_INFO:  ILOG(@"[Core] %@", msgStr); break;
                case RETRO_LOG_WARN:  WLOG(@"[Core] %@", msgStr); break;
                case RETRO_LOG_ERROR: ELOG(@"[Core] %@", msgStr); break;
                default: ILOG(@"[Core] %@", msgStr); break;
            }

            // Forward to OSD unless target is log-only
            if (msg->target != RETRO_MESSAGE_TARGET_LOG) {
                // Map retro_log_level to PVOSDType
                PVOSDType osdType;
                switch (msg->level) {
                    case RETRO_LOG_ERROR: osdType = PVOSDTypeError;   break;
                    case RETRO_LOG_WARN:  osdType = PVOSDTypeWarning; break;
                    default:              osdType = PVOSDTypeInfo;    break;
                }
                // duration is in ms, convert to seconds
                NSTimeInterval duration = (msg->duration > 0) ? (NSTimeInterval)msg->duration / 1000.0 : 3.0;
                [PVOSDNotification postMessage:msgStr type:osdType duration:duration];
            }
            return true;
        }

        // ---- Frame time callback ----
        case RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK: {
            const struct retro_frame_time_callback *cb = (const struct retro_frame_time_callback *)data;
            if (!cb) return false;
            _frameTimeCallback = *cb;
            _hasFrameTimeCallback = YES;
            _lastFrameTimeUs = 0;
            ILOG(@"ThinEnv SET_FRAME_TIME_CALLBACK registered");
            return true;
        }

        // ---- Audio callback ----
        case RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK: {
            // Not implemented: the thin frontend does not run a dedicated audio thread
            // that would call cb->callback on demand. Returning false tells the core to
            // use the normal retro_audio_sample / retro_audio_sample_batch push model
            // instead. Returning true here without actually invoking the callback would
            // cause silence or timing errors for cores that rely on the pull model.
            DLOG(@"ThinEnv SET_AUDIO_CALLBACK — not supported (returning false; core will use push model)");
            return false;
        }
        case RETRO_ENVIRONMENT_SET_MINIMUM_AUDIO_LATENCY:
            return true;
        case RETRO_ENVIRONMENT_SET_AUDIO_BUFFER_STATUS_CALLBACK:
            return true;

        // ---- Keyboard ----
        case RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK: {
            const struct retro_keyboard_callback *kb = (const struct retro_keyboard_callback *)data;
            if (!kb) return false;
            _keyboardEventCb = kb->callback;
            return true;
        }

        // ---- Proc address ----
        case RETRO_ENVIRONMENT_SET_PROC_ADDRESS_CALLBACK:
            return true;

        // ---- Rumble ----
        case RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE: {
            struct retro_rumble_interface *rumble = (struct retro_rumble_interface *)data;
            if (!rumble) return false;
            rumble->set_rumble_state = pv_retro_rumble_callback;
            DLOG(@"ThinEnv GET_RUMBLE_INTERFACE: provided rumble callback");
            return true;
        }

        // ---- Sensor / Camera / Location (not supported) ----
        case RETRO_ENVIRONMENT_GET_SENSOR_INTERFACE:
        case RETRO_ENVIRONMENT_GET_CAMERA_INTERFACE:
        case RETRO_ENVIRONMENT_GET_LOCATION_INTERFACE:
            return false;

        // ---- LED / MIDI / VFS (not supported) ----
        case RETRO_ENVIRONMENT_GET_LED_INTERFACE:
        case RETRO_ENVIRONMENT_GET_MIDI_INTERFACE:
        case RETRO_ENVIRONMENT_GET_VFS_INTERFACE:
        case RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER:
            return false;

        // ---- Disk control ----
        case RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE: {
            const struct retro_disk_control_callback *dc = (const struct retro_disk_control_callback *)data;
            if (dc) { _diskControl = *dc; _hasDiskControl = YES; }
            return true;
        }
        case RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION:
            if (data) *(unsigned *)data = 1;
            return true;
        case RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE: {
            const struct retro_disk_control_ext_callback *dc = (const struct retro_disk_control_ext_callback *)data;
            if (dc) { _diskControlExt = *dc; _hasDiskControlExt = YES; }
            return true;
        }

        // ---- Serialization quirks ----
        case RETRO_ENVIRONMENT_SET_SERIALIZATION_QUIRKS: {
            uint64_t *quirks = (uint64_t *)data;
            if (quirks) { _serializationQuirks = *quirks; }
            return true;
        }

        // ---- Memory maps ----
        case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
            return true;

        // ---- Fast-forward / throttle ----
        case RETRO_ENVIRONMENT_GET_FASTFORWARDING:
            if (data) *(bool *)data = (_speedMultiplier > 1.5);
            return true;
        case RETRO_ENVIRONMENT_SET_FASTFORWARDING_OVERRIDE:
            return true;
        case RETRO_ENVIRONMENT_GET_TARGET_REFRESH_RATE:
            if (data) *(float *)data = (float)_rawAVInfo.timing.fps;
            return true;
        case RETRO_ENVIRONMENT_GET_THROTTLE_STATE:
            return false;

        // ---- Audio / video enable bitmask ----
        case RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE: {
            if (data) *(int *)data = 0x3; // bit0=video, bit1=audio
            return true;
        }

        // ---- Game info ext ----
        case RETRO_ENVIRONMENT_GET_GAME_INFO_EXT:
            return false; // Opt out — cores will use basic retro_game_info

        // ---- Shutdown ----
        case RETRO_ENVIRONMENT_SHUTDOWN: {
            ILOG(@"ThinEnv SHUTDOWN requested by core");
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.frontendDelegate respondsToSelector:@selector(libretroFrontendDidShutdown:)]) {
                    [self.frontendDelegate libretroFrontendDidShutdown:self];
                }
            });
            return true;
        }

        // ---- Hardware rendering ----
        case RETRO_ENVIRONMENT_SET_HW_RENDER: {
            struct retro_hw_render_callback *hwCb = (struct retro_hw_render_callback *)data;
            if (!hwCb) return false;
            return [self setupHardwareRenderCallback:hwCb];
        }
        case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE: {
            // Vulkan cores call this after context_reset.
            // The GL path doesn't need it; Vulkan support is future work.
            DLOG(@"ThinEnv GET_HW_RENDER_INTERFACE — not implemented");
            return false;
        }
        case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE: {
            DLOG(@"ThinEnv SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE");
            return false;
        }
        case RETRO_ENVIRONMENT_GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT: {
            DLOG(@"ThinEnv GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT");
            return false;
        }
        case RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT:
            DLOG(@"ThinEnv SET_HW_SHARED_CONTEXT");
            return false;

        // ---- Preferred HW render ----
        case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER: {
            if (data) *(unsigned *)data = RETRO_HW_CONTEXT_OPENGLES3;
            return true;
        }

        default:
            DLOG(@"ThinEnv UNSUPPORTED cmd=%u", cmd);
            return false;
    }
}

// ---------------------------------------------------------------------------
// MARK: - Hardware rendering setup (GLES3 / IOSurface)
// ---------------------------------------------------------------------------

- (BOOL)setupHardwareRenderCallback:(struct retro_hw_render_callback *)hwCb {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    switch (hwCb->context_type) {
        case RETRO_HW_CONTEXT_OPENGLES2:
        case RETRO_HW_CONTEXT_OPENGLES3:
        case RETRO_HW_CONTEXT_OPENGLES_VERSION:
            break;
        default:
            WLOG(@"ThinFrontend: unsupported HW context type %d", (int)hwCb->context_type);
            return false;
    }

    _hwRenderCallback = *hwCb;
    _hwRenderRequested = YES;

    // Install our framebuffer getter + proc address resolver
    _hwRenderCallback.get_current_framebuffer = thin_hw_get_current_framebuffer;
    _hwRenderCallback.get_proc_address         = thin_hw_get_proc_address;
    *hwCb = _hwRenderCallback;

    // Create the EAGLContext pair.
    // _glShareContext is the render thread context; _glContext is the emu thread context.
    // They share GL objects via sharegroup.
    EAGLRenderingAPI api = (hwCb->context_type == RETRO_HW_CONTEXT_OPENGLES2)
        ? kEAGLRenderingAPIOpenGLES2
        : kEAGLRenderingAPIOpenGLES3;

    _glShareContext = [[EAGLContext alloc] initWithAPI:api];
    if (!_glShareContext) {
        ELOG(@"ThinFrontend: failed to create EAGLContext");
        return false;
    }
    _glContext = [[EAGLContext alloc] initWithAPI:api sharegroup:_glShareContext.sharegroup];
    if (!_glContext) {
        ELOG(@"ThinFrontend: failed to create shared EAGLContext");
        _glShareContext = nil;
        return false;
    }

    ILOG(@"ThinFrontend: HW render context created (GLES%u) — context_reset will fire after FBO setup",
         api == kEAGLRenderingAPIOpenGLES2 ? 2 : 3);

    // FBO setup and context_reset are deferred. The host must call
    // -setupHardwareContextFBOWidth:height: from the EMULATION THREAD
    // with _glContext current (i.e. after [EAGLContext setCurrentContext:_glContext]).
    // context_reset fires at the end of that call, matching libretro's requirement
    // that context_reset and subsequent retro_run() calls share the same GL context.
    return YES;
#else
    WLOG(@"ThinFrontend: HW rendering not supported on macOS/Catalyst");
    return false;
#endif
}

- (void)setupHardwareContextFBOWidth:(uint32_t)w height:(uint32_t)h {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    if (!_glContext || !_hwRenderRequested) return;

    [EAGLContext setCurrentContext:_glContext];

    // Release any previously-allocated GL objects and IOSurface before recreating
    // (handles resize / repeated setup calls without leaking resources).
    if (_emuFBO) { glDeleteFramebuffers(1, &_emuFBO); _emuFBO = 0; }
    if (_emuColorTex) { glDeleteTextures(1, &_emuColorTex); _emuColorTex = 0; }
    if (_emuDepthRB) { glDeleteRenderbuffers(1, &_emuDepthRB); _emuDepthRB = 0; }
    if (_ioSurface) { CFRelease(_ioSurface); _ioSurface = NULL; }

    // Create an IOSurface-backed texture so the render delegate can read the
    // frame without a GPU readback.
    NSDictionary *props = @{
        (id)kIOSurfaceWidth:             @(w),
        (id)kIOSurfaceHeight:            @(h),
        (id)kIOSurfaceBytesPerElement:   @4,
        (id)kIOSurfacePixelFormat:       @(kCVPixelFormatType_32BGRA),
    };
    _ioSurface = IOSurfaceCreate((CFDictionaryRef)props);
    if (!_ioSurface) {
        ELOG(@"ThinFrontend: IOSurfaceCreate failed");
        return;
    }

    // Create FBO + color texture bound to the IOSurface
    glGenFramebuffers(1, &_emuFBO);
    glGenTextures(1, &_emuColorTex);

    glBindTexture(GL_TEXTURE_2D, _emuColorTex);
    [_glContext texImageIOSurface:_ioSurface
                           target:GL_TEXTURE_2D
                   internalFormat:GL_RGBA
                            width:w
                           height:h
                           format:GL_BGRA_EXT
                             type:GL_UNSIGNED_BYTE
                            plane:0];
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glBindFramebuffer(GL_FRAMEBUFFER, _emuFBO);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _emuColorTex, 0);

    if (_hwRenderCallback.depth || _hwRenderCallback.stencil) {
        glGenRenderbuffers(1, &_emuDepthRB);
        glBindRenderbuffer(GL_RENDERBUFFER, _emuDepthRB);
        GLenum fmt = _hwRenderCallback.stencil ? GL_DEPTH24_STENCIL8 : GL_DEPTH_COMPONENT24;
        glRenderbufferStorage(GL_RENDERBUFFER, fmt, (GLsizei)w, (GLsizei)h);
        GLenum attach = _hwRenderCallback.stencil ? GL_DEPTH_STENCIL_ATTACHMENT : GL_DEPTH_ATTACHMENT;
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, attach, GL_RENDERBUFFER, _emuDepthRB);
    }

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        ELOG(@"ThinFrontend: FBO incomplete (status=0x%04x)", status);
        return;
    }
    ILOG(@"ThinFrontend: FBO %u ready (%ux%u) — firing context_reset", _emuFBO, w, h);

    // Fire context_reset now that the FBO is ready
    if (_hwRenderCallback.context_reset) {
        _hwRenderCallback.context_reset();
    }
#endif
}

- (void)teardownHardwareContext {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    if (_hwRenderCallback.context_destroy) {
        _hwRenderCallback.context_destroy();
    }
    if (_glContext) {
        [EAGLContext setCurrentContext:_glContext];
        if (_emuFBO)      { glDeleteFramebuffers(1, &_emuFBO);   _emuFBO = 0; }
        if (_emuColorTex) { glDeleteTextures(1, &_emuColorTex);  _emuColorTex = 0; }
        if (_emuDepthRB)  { glDeleteRenderbuffers(1, &_emuDepthRB); _emuDepthRB = 0; }
        [EAGLContext setCurrentContext:nil];
    }
    if (_ioSurface) { CFRelease(_ioSurface); _ioSurface = NULL; }
    _glContext      = nil;
    _glShareContext = nil;
    _hwRenderRequested = NO;
    memset(&_hwRenderCallback, 0, sizeof(_hwRenderCallback));
#endif
}

// ---------------------------------------------------------------------------
// MARK: - Probe utility
// ---------------------------------------------------------------------------

+ (nullable NSDictionary<NSString *, id> *)probeCoreDylibAtPath:(NSString *)corePath {
    void *handle = dlopen(corePath.UTF8String, RTLD_LOCAL | RTLD_LAZY);
    if (!handle) return nil;

    typedef void (*GetSystemInfoFn)(struct retro_system_info *);
    GetSystemInfoFn getInfo = (GetSystemInfoFn)dlsym(handle, "retro_get_system_info");
    if (!getInfo) {
        dlclose(handle);
        return nil;
    }

    struct retro_system_info info = {0};
    getInfo(&info);

    NSDictionary *result = @{
        @"library_name":     info.library_name     ? @(info.library_name)     : @"",
        @"library_version":  info.library_version  ? @(info.library_version)  : @"",
        @"valid_extensions": info.valid_extensions ? @(info.valid_extensions) : @"",
        @"need_fullpath":    @(info.need_fullpath),
        @"block_extract":    @(info.block_extract),
    };

    dlclose(handle);
    return result;
}

@end

#pragma clang diagnostic pop
