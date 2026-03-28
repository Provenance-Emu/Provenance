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
//  - Vulkan HW-render cores get MoltenVK via dlopen + retro_hw_render_interface_vulkan
//  - Serialization uses retro_serialize_size / retro_serialize / retro_unserialize directly
//

#import "PVThinLibretroFrontend.h"

@import Foundation;
@import QuartzCore;   // CACurrentMediaTime
@import CoreVideo;    // kCVPixelFormatType_32BGRA
#if TARGET_OS_IOS || TARGET_OS_MACCATALYST
@import UIKit;        // UIDevice battery API
#endif
@import PVLoggingObjC;
@import PVCoreBridge;
@import PVCoreObjCBridge;
@import PVAudio;

// Peripheral hardware frameworks
#if __has_include(<AVFoundation/AVFoundation.h>)
#import <AVFoundation/AVFoundation.h>
#define PV_HAS_AVFOUNDATION 1
#else
#define PV_HAS_AVFOUNDATION 0
#endif

#if __has_include(<AudioToolbox/AudioToolbox.h>)
#import <AudioToolbox/AudioToolbox.h>
#define PV_HAS_AUDIOTOOLBOX 1
#else
#define PV_HAS_AUDIOTOOLBOX 0
#endif

#if __has_include(<CoreMIDI/CoreMIDI.h>) && !TARGET_OS_TV
#import <CoreMIDI/CoreMIDI.h>
#define PV_HAS_COREMIDI 1
#else
#define PV_HAS_COREMIDI 0
#endif

#if __has_include(<Accelerate/Accelerate.h>)
#import <Accelerate/Accelerate.h>
#define PV_HAS_ACCELERATE 1
#else
#define PV_HAS_ACCELERATE 0
#endif

#include <dlfcn.h>
#include <os/lock.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#import <objc/message.h>

/// Returns true if Provenance has acquired JIT at runtime (bridged from DOLJitManager).
/// Defined in PVLibRetro+JIT.swift via @_cdecl("pvjit_acquired").
extern "C" bool pvjit_acquired(void);

// Peripheral interfaces: sensor (CoreMotion), location (CoreLocation), LED (GameController)
#if __has_include(<CoreMotion/CoreMotion.h>) && !TARGET_OS_TV && !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <CoreMotion/CoreMotion.h>
#define PV_HAS_COREMOTION 1
#else
#define PV_HAS_COREMOTION 0
#endif

#if __has_include(<CoreLocation/CoreLocation.h>) && !TARGET_OS_TV
#import <CoreLocation/CoreLocation.h>
#define PV_HAS_CORELOCATION 1
#else
#define PV_HAS_CORELOCATION 0
#endif

@import GameController;

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
#include <stdatomic.h>

// Vulkan support via MoltenVK (loaded at runtime via dlopen)
#if HAVE_VULKAN
#include "libretro_vulkan.h"
#endif

// ---------------------------------------------------------------------------
// MARK: - Microphone ring buffer
// ---------------------------------------------------------------------------

/// Simple lock-free single-producer/single-consumer ring buffer for mic PCM data.
/// AudioUnit callback writes, libretro read_mic reads.
#define PV_MIC_RING_BUFFER_SIZE (16384) // 16 KB — ~170 ms at 48kHz mono 16-bit

typedef struct pv_mic_ring_buffer {
    int16_t *data;
    size_t capacity;    // in samples (int16_t count)
    _Atomic size_t writePos;
    _Atomic size_t readPos;
} pv_mic_ring_buffer_t;

static pv_mic_ring_buffer_t *pv_mic_ring_create(size_t capacity_samples) {
    pv_mic_ring_buffer_t *rb = (pv_mic_ring_buffer_t *)calloc(1, sizeof(*rb));
    if (!rb) return NULL;
    rb->data = (int16_t *)calloc(capacity_samples, sizeof(int16_t));
    if (!rb->data) { free(rb); return NULL; }
    rb->capacity = capacity_samples;
    atomic_store(&rb->writePos, 0);
    atomic_store(&rb->readPos, 0);
    return rb;
}

static void pv_mic_ring_free(pv_mic_ring_buffer_t *rb) {
    if (!rb) return;
    free(rb->data);
    free(rb);
}

static size_t pv_mic_ring_available(pv_mic_ring_buffer_t *rb) {
    size_t w = atomic_load(&rb->writePos);
    size_t r = atomic_load(&rb->readPos);
    return (w >= r) ? (w - r) : (rb->capacity - r + w);
}

static size_t pv_mic_ring_write(pv_mic_ring_buffer_t *rb, const int16_t *samples, size_t count) {
    size_t written = 0;
    size_t w = atomic_load(&rb->writePos);
    size_t r = atomic_load(&rb->readPos);
    for (size_t i = 0; i < count; i++) {
        size_t next = (w + 1) % rb->capacity;
        if (next == r) break; // full
        rb->data[w] = samples[i];
        w = next;
        written++;
    }
    atomic_store(&rb->writePos, w);
    return written;
}

static size_t pv_mic_ring_read(pv_mic_ring_buffer_t *rb, int16_t *samples, size_t count) {
    size_t readCount = 0;
    size_t r = atomic_load(&rb->readPos);
    size_t w = atomic_load(&rb->writePos);
    for (size_t i = 0; i < count; i++) {
        if (r == w) break; // empty
        samples[i] = rb->data[r];
        r = (r + 1) % rb->capacity;
        readCount++;
    }
    atomic_store(&rb->readPos, r);
    return readCount;
}

// ---------------------------------------------------------------------------
// MARK: - Microphone handle (opaque retro_microphone_t)
// ---------------------------------------------------------------------------

#if PV_HAS_AUDIOTOOLBOX
struct retro_microphone {
    AudioUnit audioUnit;
    AudioStreamBasicDescription format;
    pv_mic_ring_buffer_t *ringBuffer;
    bool isRunning;
    unsigned sampleRate;
};
#endif

// ---------------------------------------------------------------------------
// MARK: - MIDI state
// ---------------------------------------------------------------------------

#if PV_HAS_COREMIDI
#define PV_MIDI_READ_BUFFER_SIZE 4096

typedef struct pv_midi_state {
    MIDIClientRef client;
    MIDIPortRef inputPort;
    MIDIPortRef outputPort;
    MIDIEndpointRef inputEndpoint;
    MIDIEndpointRef outputEndpoint;
    uint8_t readBuffer[PV_MIDI_READ_BUFFER_SIZE];
    _Atomic size_t readWritePos;
    _Atomic size_t readReadPos;
    bool initialized;
} pv_midi_state_t;

static pv_midi_state_t s_midiState = {0};
/// Lock protecting concurrent ring-buffer reads and writes during active MIDI use.
/// Ensures byte data is written before the index advances (no TOCTOU window).
/// NOTE: lifecycle transitions (thin_midi_ensure_initialized / thin_midi_shutdown)
/// are not fully protected by this lock; they must be called on non-concurrent paths
/// (i.e., before any CoreMIDI callbacks or libretro reads are in flight).
static os_unfair_lock s_midiRingLock = OS_UNFAIR_LOCK_INIT;

/// Thread-safe cache of user-selected MIDI output destination endpoint refs.
/// Updated by +setMIDIOutputEndpoints: (called from Swift via MIDIDeviceManager observation).
/// -1 = never explicitly set by the user — legacy fallback: thin_midi_write uses MIDIGetDestination(0).
///      This preserves the pre-PR behaviour for cores that use pv_libretro_midi_interface() but
///      do not wire up the MIDIDeviceManager observer (e.g. the full RetroArch bridge PVLibRetroCore).
///  0 = user explicitly selected "None" — thin_midi_write is a no-op.
/// >0 = N user-selected destinations.
static os_unfair_lock s_midiDestCacheLock = OS_UNFAIR_LOCK_INIT;
static MIDIEndpointRef s_midiCachedDests[16] = {0};
static int s_midiCachedDestCount = -1; // -1 = never set; 0 = "None"; >0 = N destinations
#endif

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

    // Controller port device type (e.g. mouse on port 2 for Mario Paint)
    void     (*retro_set_controller_port_device)(unsigned port, unsigned device);

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

    // HW render state — @package so static C trampolines can access via ->
    @package
    struct retro_hw_render_callback _hwRenderCallback;
    BOOL _hwRenderRequested;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    EAGLContext *_glContext;
    EAGLContext *_glShareContext;
    IOSurfaceRef _ioSurface;
    GLuint _emuFBO;
    GLuint _emuColorTex;
    GLuint _emuDepthRB;
    /// YES after startRenderingOnAlternateThread has been called on the render delegate.
    /// Used to avoid calling it more than once per session.
    BOOL _renderDelegateStarted;
    /// Current FBO dimensions — used to detect when a resize is needed.
    uint32_t _fboWidth;
    uint32_t _fboHeight;
    /// Set to YES when SET_SYSTEM_AV_INFO / SET_GEOMETRY fires with different dimensions
    /// while a HW FBO is already live. The FBO is rebuilt on the next runFrame call
    /// so that context_reset fires on the emulation thread.
    BOOL _hwFBONeedsRebuild;
#endif

    // Vulkan state (when using MoltenVK via dlopen)
#if HAVE_VULKAN
    void *_vulkanLibrary;
    VkInstance _vulkanInstance;
    VkDevice _vulkanDevice;
    VkQueue _vulkanQueue;
    VkPhysicalDevice _vulkanPhysicalDevice;
    struct retro_hw_render_interface_vulkan _vulkanRenderInterface;
    os_unfair_lock _vulkanQueueLock;
    BOOL _hwSharedContext;

    // Per-frame Vulkan state set by the core callbacks
    VkSemaphore _vulkanSignalSemaphore;        // set by thin_vulkan_set_signal_semaphore
    VkImage _vulkanCurrentVkImage;             // set by thin_vulkan_set_image (VkImage only; no pNext copy)
    BOOL _vulkanHasCurrentImage;
    // Wait semaphores stored from thin_vulkan_set_image, consumed in the next vkQueueSubmit
    VkSemaphore _vulkanWaitSemaphores[8];
    VkPipelineStageFlags _vulkanWaitDstStageMask[8];
    uint32_t _vulkanWaitSemaphoreCount;
    BOOL _vulkanExtMetalObjectsEnabled;        // YES if VK_EXT_metal_objects was enabled at device creation
    // Pending command buffers from thin_vulkan_set_command_buffers, submitted during video_refresh
    // per libretro_vulkan.h: buffers must not be submitted until retro_video_refresh_t is called.
    VkCommandBuffer _vulkanPendingCmdBufs[64];
    uint32_t _vulkanPendingCmdBufCount;

    // Vulkan function pointers loaded from MoltenVK
    PFN_vkVoidFunction (*_vkGetInstanceProcAddr)(VkInstance instance, const char *pName);
    PFN_vkVoidFunction (*_vkGetDeviceProcAddr)(VkDevice device, const char *pName);
    VkResult (*_vkCreateInstance)(const void *pCreateInfo, const void *pAllocator, VkInstance *pInstance);
    void (*_vkDestroyInstance)(VkInstance instance, const void *pAllocator);
    VkResult (*_vkEnumeratePhysicalDevices)(VkInstance instance, uint32_t *pPhysicalDeviceCount, VkPhysicalDevice *pPhysicalDevices);
    VkResult (*_vkCreateDevice)(VkPhysicalDevice physicalDevice, const void *pCreateInfo, const void *pAllocator, VkDevice *pDevice);
    void (*_vkDestroyDevice)(VkDevice device, const void *pAllocator);
    void (*_vkGetDeviceQueue)(VkDevice device, uint32_t queueFamilyIndex, uint32_t queueIndex, VkQueue *pQueue);

    // Additional Vulkan functions for command submission and Metal interop
    PFN_vkQueueSubmit _vkQueueSubmit;
    VkResult (*_vkQueueWaitIdle)(VkQueue queue);
    PFN_vkEnumerateDeviceExtensionProperties _vkEnumerateDeviceExtensionProperties;
    // MoltenVK Metal interop: vkGetMTLTextureMVK(image, &mtlTexture) — deprecated but universally available
    void (*_vkGetMTLTextureMVK)(VkImage image, void **pMTLTexture);
    // VK_EXT_metal_objects: vkExportMetalObjectsEXT(device, &info) — preferred in MoltenVK >= 1.2
    // Return type is VkResult per spec; pMetalObjectsInfo uses void* to avoid needing
    // VkExportMetalObjectsInfoEXT from the bundled vulkan.h (v17 predates this extension).
    VkResult (*_vkExportMetalObjectsEXT)(VkDevice device, void *pMetalObjectsInfo);

    // Double-buffer synchronisation via per-frame fences.
    // Replaces the vkQueueWaitIdle full-queue stall with narrower per-submission waits.
    // _vulkanFrameFences[0/1] are created SIGNALED so the first wait_sync_index is a no-op.
    // _vulkanFrameIndex alternates 0↔1 every frame; get_sync_index_mask returns 3 (both slots valid).
    VkFence  _vulkanFrameFences[2];
    uint32_t _vulkanFrameIndex;
    // Fence lifecycle functions (use PFN_ typedefs for full type safety)
    PFN_vkCreateFence  _vkCreateFence;
    PFN_vkDestroyFence _vkDestroyFence;
    PFN_vkWaitForFences _vkWaitForFences;
    PFN_vkResetFences  _vkResetFences;
#endif

    @private
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

    // Controller port info from RETRO_ENVIRONMENT_SET_CONTROLLER_INFO
    NSArray<NSArray<NSDictionary<NSString *, id> *> *> *_controllerPortInfo;
    // Current device type selected per port (default RETRO_DEVICE_JOYPAD = 1)
    unsigned _portDeviceTypes[THIN_MAX_PLAYERS];

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

    // Light gun state — libretro screen-space coordinates and button flags (separate bools)
    // Coordinate range: -0x7FFF (top/left) .. +0x7FFF (bottom/right)
    int16_t _lightgunX;
    int16_t _lightgunY;
    bool _lightgunIsOffscreen;
    bool _lightgunTrigger;
    bool _lightgunReload;
    bool _lightgunAuxA;
    bool _lightgunAuxB;
    bool _lightgunStart;
    bool _lightgunSelect;

    // Pause flag — when YES, audio callbacks discard samples to prevent
    // stale audio from leaking through during the pause/resume transition.
    BOOL _audioPaused;

    // ---- Peripheral interfaces ----

    // Sensor (CoreMotion — accelerometer, gyroscope)
#if PV_HAS_COREMOTION
    CMMotionManager *_motionManager;
    BOOL _accelerometerActive;
    BOOL _gyroscopeActive;
#endif
    // Cached sensor readings (always present so get_sensor_input returns 0 on unsupported platforms)
    float _sensorAccelX, _sensorAccelY, _sensorAccelZ;
    float _sensorGyroX, _sensorGyroY, _sensorGyroZ;
    float _sensorIlluminance;

    // Camera (AVCaptureSession-backed)
    // @package visibility so static C callback functions can access via ->
    @package
    struct retro_camera_callback _cameraCallback;
    BOOL _hasCameraCallback;
#if PV_HAS_AVFOUNDATION
    AVCaptureSession *_cameraCaptureSession;
    AVCaptureVideoDataOutput *_cameraVideoOutput;
    uint32_t *_cameraFrameBuffer;   // XRGB8888 frame buffer for the core
    size_t _cameraBufferWidth;
    size_t _cameraBufferHeight;
    BOOL _cameraSessionRunning;
    dispatch_queue_t _cameraQueue;
#endif
    @private

    // Microphone (AudioUnit-backed)
    struct retro_microphone_interface _microphoneInterface;
    BOOL _hasMicrophoneInterface;

    // Location (CoreLocation)
#if PV_HAS_CORELOCATION
    CLLocationManager *_locationManager;
    BOOL _locationActive;
    double _lastLatitude, _lastLongitude;
    double _lastHorizAccuracy, _lastVertAccuracy;
    BOOL _locationUpdatedSinceLastRead;
#endif

    // LED (GameController light bar)
    // No persistent state needed — set_led_state maps directly to GCController.current

    // ---- Blocking-core thread support ----
    // Some cores (e.g. prboom) run their own game loop inside retro_load_game and
    // never return. We run them on a dedicated thread and use two semaphores to
    // hand-shake with runFrame: the core signals _blockingFrameReady after each
    // video_refresh call, then waits on _blockingCoreTick before advancing.
    // @package visibility so the static thin_video_refresh callback can access via ->
    @package
    BOOL _isBlockingCore;
    dispatch_semaphore_t _blockingFrameReady;  // core → frontend: frame available
    dispatch_semaphore_t _blockingCoreTick;    // frontend → core: run next tick
    @private
    struct retro_game_info _blockingGameInfo;  // persisted for core thread lifetime
    NSData *_blockingROMData;                  // keeps ROM data bytes alive on heap
    NSString *_blockingROMPath;                // keeps romPath NSString alive so .path ptr is valid
    NSThread *_blockingCoreThread;             // retained reference to blocking core thread

    // Guard against double retro_deinit (dealloc can re-enter stopEmulation)
    BOOL _coreDeinited;
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

// Peripheral interface helpers
- (BOOL)_sensorSetState:(enum retro_sensor_action)action rate:(unsigned)rate port:(unsigned)port;
- (float)_sensorGetInput:(unsigned)sensorId port:(unsigned)port;
- (BOOL)_locationStart;
- (void)_locationStop;
- (BOOL)_locationGetPositionLat:(double *)lat lon:(double *)lon horizAccuracy:(double *)ha vertAccuracy:(double *)va;

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
    // Blocking-core hand-shake: signal frame ready, then stall until frontend
    // says to advance. This yields the core thread back to runFrame.
    if (self->_isBlockingCore) {
        dispatch_semaphore_signal(self->_blockingFrameReady);
        dispatch_semaphore_wait(self->_blockingCoreTick, DISPATCH_TIME_FOREVER);
    }
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
    // Throttle repeated error messages (e.g. Z_Malloc failure loops)
    static char s_lastErrorMsg[256] = {0};
    static int  s_lastErrorRepeat = 0;
    static uint64_t s_lastErrorTime = 0;

    va_list args;
    va_start(args, fmt);
    char buf[2048];
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    if (level == RETRO_LOG_ERROR) {
        uint64_t now = (uint64_t)(CACurrentMediaTime() * 1000); // ms
        if (strncmp(buf, s_lastErrorMsg, sizeof(s_lastErrorMsg) - 1) == 0
            && (now - s_lastErrorTime) < 2000) {
            s_lastErrorRepeat++;
            if (s_lastErrorRepeat == 5) {
                ELOG(@"[Core] (repeated %d times, suppressing further)", s_lastErrorRepeat);
            }
            s_lastErrorTime = now;
            return; // Suppress repeated identical errors within 2s
        }
        // New error or enough time passed — reset counter
        if (s_lastErrorRepeat > 5) {
            ELOG(@"[Core] (previous error repeated %d total times)", s_lastErrorRepeat);
        }
        strncpy(s_lastErrorMsg, buf, sizeof(s_lastErrorMsg) - 1);
        s_lastErrorRepeat = 1;
        s_lastErrorTime = now;
    }

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

/// hw_get_proc_address — called from the core to resolve GL/Vulkan symbols.
static retro_proc_address_t thin_hw_get_proc_address(const char *sym) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
#if HAVE_VULKAN
    if (self && self->_hwRenderCallback.context_type == RETRO_HW_CONTEXT_VULKAN) {
        // For Vulkan cores, resolve through the Vulkan function pointers
        if (self->_vkGetDeviceProcAddr && self->_vulkanDevice) {
            PFN_vkVoidFunction fn = self->_vkGetDeviceProcAddr(self->_vulkanDevice, sym);
            if (fn) return (retro_proc_address_t)fn;
        }
        if (self->_vkGetInstanceProcAddr && self->_vulkanInstance) {
            PFN_vkVoidFunction fn = self->_vkGetInstanceProcAddr(self->_vulkanInstance, sym);
            if (fn) return (retro_proc_address_t)fn;
        }
        if (self->_vkGetInstanceProcAddr) {
            PFN_vkVoidFunction fn = self->_vkGetInstanceProcAddr(NULL, sym);
            if (fn) return (retro_proc_address_t)fn;
        }
        DLOG(@"ThinFrontend: Vulkan symbol not found: %s", sym);
        return NULL;
    }
#endif
    (void)self;
    return (retro_proc_address_t)dlsym(RTLD_DEFAULT, sym);
}

// ---------------------------------------------------------------------------
// MARK: - Vulkan callback stubs (thin frontend)
// ---------------------------------------------------------------------------

#if HAVE_VULKAN

static PVThinLibretroFrontend *thin_vulkan_bridge(void *handle) {
    return (__bridge PVThinLibretroFrontend *)handle;
}

static void thin_vulkan_set_image(void *handle, const struct retro_vulkan_image *image,
                                  uint32_t num_semaphores, const VkSemaphore *semaphores,
                                  uint32_t src_queue_family) {
    (void)src_queue_family;
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    if (!bridge || !image) return;
    // Serialize writes with submitVulkanCommandBuffers, which reads/clears these
    // fields under _vulkanQueueLock. Without the lock here, concurrent reads in the
    // submit path can race against these writes (data race).
    os_unfair_lock_lock(&bridge->_vulkanQueueLock);
    // Store only the VkImage handle — copying retro_vulkan_image by value is unsafe
    // because the pNext chain cannot be deep-copied and the pointer is only valid
    // until retro_video_refresh_t returns.
    bridge->_vulkanCurrentVkImage = image->create_info.image;
    bridge->_vulkanHasCurrentImage = YES;
    // Store wait semaphores for use as pWaitSemaphores in async-compute path.
    // Cap at 8; the libretro Vulkan interface rarely provides more than 1.
    // Note: these are NOT used in set_command_buffers mode (libretro_vulkan.h spec).
    bridge->_vulkanWaitSemaphoreCount = 0;
    uint32_t storableCount = (num_semaphores < 8) ? num_semaphores : 8;
    for (uint32_t i = 0; i < storableCount; i++) {
        bridge->_vulkanWaitSemaphores[i]   = semaphores[i];
        bridge->_vulkanWaitDstStageMask[i] = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
    }
    bridge->_vulkanWaitSemaphoreCount = storableCount;
    os_unfair_lock_unlock(&bridge->_vulkanQueueLock);
    // Do NOT notify the render delegate here — some cores call set_image before
    // set_command_buffers, so the VkImage may not yet have been rendered into.
    // Notification is deferred to submitVulkanCommandBuffers (after vkQueueSubmit).
}

static uint32_t thin_vulkan_get_sync_index(void *handle) {
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    // Return the current frame slot so the core knows which buffer to write into.
    // _vulkanFrameIndex alternates 0↔1 each frame (double-buffer).
    return bridge ? bridge->_vulkanFrameIndex : 0;
}

static uint32_t thin_vulkan_get_sync_index_mask(void *handle) {
    (void)handle;
    // Bitmask of valid sync indices: 3 = 0b11 → slots 0 and 1 are available (double-buffer).
    return 3;
}

static void thin_vulkan_set_command_buffers(void *handle, uint32_t num_cmd,
                                            const VkCommandBuffer *cmd) {
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    if (!bridge || !cmd || num_cmd == 0) return;
    // Per libretro_vulkan.h, command buffers must not be submitted until
    // retro_video_refresh_t is called. Store them for deferred submission.
    // Protect with _vulkanQueueLock: the Vulkan interface allows callbacks from
    // any thread, and _thinVideoRefresh reads these fields on the emu thread.
    uint32_t count = (num_cmd < 64) ? num_cmd : 64;
    os_unfair_lock_lock(&bridge->_vulkanQueueLock);
    memcpy(bridge->_vulkanPendingCmdBufs, cmd, count * sizeof(VkCommandBuffer));
    bridge->_vulkanPendingCmdBufCount = count;
    os_unfair_lock_unlock(&bridge->_vulkanQueueLock);
}

static void thin_vulkan_wait_sync_index(void *handle) {
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    if (!bridge) return;
    // Wait for the previous submission on this slot to complete so the core can safely
    // reuse its per-frame resources (command pools, descriptor sets, etc.).
    // Prefer the per-frame fence (narrower than vkQueueWaitIdle which stalls the entire queue).
    os_unfair_lock_lock(&bridge->_vulkanQueueLock);
    uint32_t slot = bridge->_vulkanFrameIndex;
    VkFence fence = bridge->_vulkanFrameFences[slot];
    if (fence && bridge->_vkWaitForFences && bridge->_vulkanDevice) {
        // UINT64_MAX = wait indefinitely; the fence is always signaled within one frame.
        bridge->_vkWaitForFences(bridge->_vulkanDevice, 1, &fence, 1 /* VK_TRUE */, UINT64_MAX);
        // Leave fence signaled — submitVulkanCommandBuffers resets it right before the next submit.
    } else if (bridge->_vkQueueWaitIdle && bridge->_vulkanQueue) {
        // Fallback: full-queue stall when fences are unavailable.
        bridge->_vkQueueWaitIdle(bridge->_vulkanQueue);
    }
    os_unfair_lock_unlock(&bridge->_vulkanQueueLock);
}

static void thin_vulkan_lock_queue(void *handle) {
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    if (!bridge) return;
    os_unfair_lock_lock(&bridge->_vulkanQueueLock);
}

static void thin_vulkan_unlock_queue(void *handle) {
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    if (!bridge) return;
    os_unfair_lock_unlock(&bridge->_vulkanQueueLock);
}

static void thin_vulkan_set_signal_semaphore(void *handle, VkSemaphore semaphore) {
    PVThinLibretroFrontend *bridge = thin_vulkan_bridge(handle);
    if (!bridge) return;
    // Serialize with submitVulkanCommandBuffers which reads/clears _vulkanSignalSemaphore
    // under _vulkanQueueLock.
    os_unfair_lock_lock(&bridge->_vulkanQueueLock);
    bridge->_vulkanSignalSemaphore = semaphore;
    os_unfair_lock_unlock(&bridge->_vulkanQueueLock);
}

#endif // HAVE_VULKAN

// ---------------------------------------------------------------------------
// MARK: - Camera capture delegate (AVCaptureVideoDataOutputSampleBufferDelegate)
// ---------------------------------------------------------------------------

#if PV_HAS_AVFOUNDATION
@interface PVThinCameraDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (assign) uint32_t *frameBuffer;
@property (assign) size_t targetWidth;
@property (assign) size_t targetHeight;
@end

@implementation PVThinCameraDelegate

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        if (!self.frameBuffer || self.targetWidth == 0 || self.targetHeight == 0)
            return;

        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!imageBuffer) return;

        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

        size_t sourceWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t sourceHeight = CVPixelBufferGetHeight(imageBuffer);
        void *baseAddr = CVPixelBufferGetBaseAddress(imageBuffer);
        size_t srcBytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);

        if (!baseAddr || sourceWidth == 0 || sourceHeight == 0) {
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            return;
        }

#if PV_HAS_ACCELERATE
        // Source is BGRA, convert to XRGB8888 (ARGB) and scale to target size
        vImage_Buffer srcBuf = {
            .data = baseAddr,
            .width = sourceWidth,
            .height = sourceHeight,
            .rowBytes = srcBytesPerRow
        };

        // Allocate a temporary buffer for BGRA->ARGB permuted full-size image
        size_t intermediateRowBytes = sourceWidth * 4;
        void *intermediateData = malloc(intermediateRowBytes * sourceHeight);
        if (!intermediateData) {
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            return;
        }

        vImage_Buffer intermediateBuf = {
            .data = intermediateData,
            .width = sourceWidth,
            .height = sourceHeight,
            .rowBytes = intermediateRowBytes
        };

        // BGRA -> ARGB (which is XRGB8888 in libretro convention: xx RR GG BB)
        uint8_t permuteMap[4] = {3, 2, 1, 0}; // BGRA -> ARGB
        vImage_Error err = vImagePermuteChannels_ARGB8888(&srcBuf, &intermediateBuf, permuteMap, kvImageNoFlags);
        if (err != kvImageNoError) {
            free(intermediateData);
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            return;
        }

        // Scale to target dimensions
        vImage_Buffer dstBuf = {
            .data = self.frameBuffer,
            .width = self.targetWidth,
            .height = self.targetHeight,
            .rowBytes = self.targetWidth * 4
        };

        err = vImageScale_ARGB8888(&intermediateBuf, &dstBuf, NULL, kvImageHighQualityResampling);
        free(intermediateData);
#else
        // Without Accelerate, do a simple nearest-neighbor copy with BGRA->XRGB conversion
        uint8_t *src = (uint8_t *)baseAddr;
        uint32_t *dst = self.frameBuffer;
        for (size_t y = 0; y < self.targetHeight && y < sourceHeight; y++) {
            uint8_t *srcRow = src + y * srcBytesPerRow;
            for (size_t x = 0; x < self.targetWidth && x < sourceWidth; x++) {
                uint8_t b = srcRow[x * 4 + 0];
                uint8_t g = srcRow[x * 4 + 1];
                uint8_t r = srcRow[x * 4 + 2];
                dst[y * self.targetWidth + x] = (0xFF << 24) | (r << 16) | (g << 8) | b;
            }
        }
#endif

        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    }
}

@end

static PVThinCameraDelegate *s_cameraDelegate = nil;
#endif

// ---------------------------------------------------------------------------
// MARK: - Peripheral interface C callbacks (sensor, camera, location, LED)
// ---------------------------------------------------------------------------

#pragma mark Sensor interface

static bool thin_sensor_set_state(unsigned port, enum retro_sensor_action action, unsigned rate) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return false;
    return [self _sensorSetState:action rate:rate port:port];
}

static float thin_sensor_get_input(unsigned port, unsigned sensor_id) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return 0.0f;
    return [self _sensorGetInput:sensor_id port:port];
}

#pragma mark Camera interface (AVFoundation)

static bool thin_camera_start(void) {
#if PV_HAS_AVFOUNDATION
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return false;

    if (self->_cameraSessionRunning) return true;

    if (!self->_cameraCaptureSession) {
        // Set up AVCaptureSession
        self->_cameraCaptureSession = [[AVCaptureSession alloc] init];
        self->_cameraQueue = dispatch_queue_create("com.provenance.thinCamera", DISPATCH_QUEUE_SERIAL);

        // Select camera device (prefer front camera for Game Boy Camera etc.)
        AVCaptureDevice *device = nil;
#if TARGET_OS_IOS
        AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
            mediaType:AVMediaTypeVideo
            position:AVCaptureDevicePositionFront];
        device = discovery.devices.firstObject;
        if (!device) {
            // Fallback to rear camera
            discovery = [AVCaptureDeviceDiscoverySession
                discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                mediaType:AVMediaTypeVideo
                position:AVCaptureDevicePositionBack];
            device = discovery.devices.firstObject;
        }
#else
        // macOS / other: use default video device
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
#endif
        if (!device) {
            ELOG(@"ThinFrontend: no camera device found");
            self->_cameraCaptureSession = nil;
            return false;
        }

        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!input || error) {
            ELOG(@"ThinFrontend: camera input error: %@", error.localizedDescription);
            self->_cameraCaptureSession = nil;
            return false;
        }

        if ([self->_cameraCaptureSession canAddInput:input]) {
            [self->_cameraCaptureSession addInput:input];
        }

        self->_cameraVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        self->_cameraVideoOutput.videoSettings = @{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
        };
        self->_cameraVideoOutput.alwaysDiscardsLateVideoFrames = YES;

        if (!s_cameraDelegate) {
            s_cameraDelegate = [[PVThinCameraDelegate alloc] init];
        }
        [self->_cameraVideoOutput setSampleBufferDelegate:s_cameraDelegate queue:self->_cameraQueue];

        if ([self->_cameraCaptureSession canAddOutput:self->_cameraVideoOutput]) {
            [self->_cameraCaptureSession addOutput:self->_cameraVideoOutput];
        }

        // Allocate frame buffer at the resolution the core requested
        unsigned w = self->_cameraCallback.width ?: 160;
        unsigned h = self->_cameraCallback.height ?: 120;
        self->_cameraBufferWidth = w;
        self->_cameraBufferHeight = h;
        self->_cameraFrameBuffer = (uint32_t *)calloc(w * h, sizeof(uint32_t));
        if (!self->_cameraFrameBuffer) {
            ELOG(@"ThinFrontend: failed to allocate camera frame buffer");
            self->_cameraCaptureSession = nil;
            return false;
        }

        s_cameraDelegate.frameBuffer = self->_cameraFrameBuffer;
        s_cameraDelegate.targetWidth = w;
        s_cameraDelegate.targetHeight = h;
    }

    // Start the capture session on a background queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self->_cameraCaptureSession startRunning];
    });
    self->_cameraSessionRunning = YES;
    ILOG(@"ThinFrontend: camera started (%zux%zu)", self->_cameraBufferWidth, self->_cameraBufferHeight);
    return true;
#else
    DLOG(@"ThinFrontend: camera start requested but AVFoundation unavailable");
    return false;
#endif
}

static void thin_camera_stop(void) {
#if PV_HAS_AVFOUNDATION
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return;
    if (self->_cameraCaptureSession && self->_cameraSessionRunning) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self->_cameraCaptureSession stopRunning];
        });
        self->_cameraSessionRunning = NO;
        ILOG(@"ThinFrontend: camera stopped");
    }
#else
    DLOG(@"ThinFrontend: camera stop requested (no AVFoundation)");
#endif
}

#pragma mark Location interface

static bool thin_location_start(void) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return false;
    return [self _locationStart];
}

static void thin_location_stop(void) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return;
    [self _locationStop];
}

static bool thin_location_get_position(double *lat, double *lon,
                                        double *horiz_accuracy, double *vert_accuracy) {
    PVThinLibretroFrontend *self = _thinCurrentTLS;
    if (!self) return false;
    return [self _locationGetPositionLat:lat lon:lon horizAccuracy:horiz_accuracy vertAccuracy:vert_accuracy];
}

static void thin_location_set_interval(unsigned interval_ms, unsigned interval_distance) {
    DLOG(@"ThinFrontend: location set_interval ms=%u dist=%u (noted)", interval_ms, interval_distance);
    // The CLLocationManager uses its own accuracy/distance filter;
    // we could map interval_distance to distanceFilter here if needed.
}

#pragma mark LED interface

static void thin_led_set_state(int led, int state) {
    // Map LED state to DualSense/DualShock4 light bar via GameController framework.
    // led index 0 = primary light. state: 0 = off, 1 = on.
    // We use a simple color mapping: off = dim, on = bright green (activity indicator).
    if (@available(iOS 14.0, tvOS 14.0, macOS 11.0, *)) {
        GCController *controller = [GCController current];
        if (!controller) return;
        GCDeviceLight *light = controller.light;
        if (!light) return;
        if (state) {
            // LED on — bright green to indicate activity (e.g. disk access)
            light.color = [[GCColor alloc] initWithRed:0.0 green:1.0 blue:0.0];
        } else {
            // LED off — dim blue (default DualShock color)
            light.color = [[GCColor alloc] initWithRed:0.0 green:0.0 blue:0.25];
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - VFS interface (v3, POSIX/stdio)
// ---------------------------------------------------------------------------

/// Opaque file handle wrapping stdio FILE*.
struct retro_vfs_file_handle {
    FILE *fp;
    char *path;
};

/// Opaque directory handle wrapping POSIX DIR*.
struct retro_vfs_dir_handle {
    DIR *dirp;
    struct dirent *entry;  // last entry read by readdir
    char *dir_path;
    bool include_hidden;
};

static const char *thin_vfs_get_path(struct retro_vfs_file_handle *stream) {
    return stream ? stream->path : NULL;
}

static struct retro_vfs_file_handle *thin_vfs_open(const char *path, unsigned mode, unsigned hints) {
    (void)hints;
    if (!path) return NULL;
    const char *fmode;
    bool update = (mode & RETRO_VFS_FILE_ACCESS_UPDATE_EXISTING) != 0;
    if ((mode & RETRO_VFS_FILE_ACCESS_READ_WRITE) == RETRO_VFS_FILE_ACCESS_READ_WRITE) {
        fmode = update ? "r+b" : "w+b";
    } else if (mode & RETRO_VFS_FILE_ACCESS_WRITE) {
        fmode = update ? "r+b" : "wb";
    } else {
        fmode = "rb";
    }
    FILE *fp = fopen(path, fmode);
    if (!fp) return NULL;
    struct retro_vfs_file_handle *handle = (struct retro_vfs_file_handle *)calloc(1, sizeof(*handle));
    handle->fp = fp;
    handle->path = strdup(path);
    return handle;
}

static int thin_vfs_close(struct retro_vfs_file_handle *stream) {
    if (!stream) return -1;
    int ret = fclose(stream->fp) == 0 ? 0 : -1;
    free(stream->path);
    free(stream);
    return ret;
}

static int64_t thin_vfs_size(struct retro_vfs_file_handle *stream) {
    if (!stream) return -1;
    long cur = ftell(stream->fp);
    if (fseek(stream->fp, 0, SEEK_END) != 0) return -1;
    long sz = ftell(stream->fp);
    fseek(stream->fp, cur, SEEK_SET);
    return (int64_t)sz;
}

static int64_t thin_vfs_tell(struct retro_vfs_file_handle *stream) {
    if (!stream) return -1;
    return (int64_t)ftell(stream->fp);
}

static int64_t thin_vfs_seek(struct retro_vfs_file_handle *stream, int64_t offset, int seek_position) {
    if (!stream) return -1;
    int whence;
    switch (seek_position) {
        case RETRO_VFS_SEEK_POSITION_START:   whence = SEEK_SET; break;
        case RETRO_VFS_SEEK_POSITION_CURRENT: whence = SEEK_CUR; break;
        case RETRO_VFS_SEEK_POSITION_END:     whence = SEEK_END; break;
        default: return -1;
    }
    if (fseek(stream->fp, (long)offset, whence) != 0) return -1;
    return (int64_t)ftell(stream->fp);
}

static int64_t thin_vfs_read(struct retro_vfs_file_handle *stream, void *s, uint64_t len) {
    if (!stream || !s) return -1;
    return (int64_t)fread(s, 1, (size_t)len, stream->fp);
}

static int64_t thin_vfs_write(struct retro_vfs_file_handle *stream, const void *s, uint64_t len) {
    if (!stream || !s) return -1;
    return (int64_t)fwrite(s, 1, (size_t)len, stream->fp);
}

static int thin_vfs_flush(struct retro_vfs_file_handle *stream) {
    if (!stream) return -1;
    return fflush(stream->fp) == 0 ? 0 : -1;
}

static int thin_vfs_remove(const char *path) {
    if (!path) return -1;
    return ::remove(path) == 0 ? 0 : -1;
}

static int thin_vfs_rename(const char *old_path, const char *new_path) {
    if (!old_path || !new_path) return -1;
    return ::rename(old_path, new_path) == 0 ? 0 : -1;
}

static int64_t thin_vfs_truncate(struct retro_vfs_file_handle *stream, int64_t length) {
    if (!stream) return -1;
    fflush(stream->fp);
    int fd = fileno(stream->fp);
    return ftruncate(fd, (off_t)length) == 0 ? 0 : -1;
}

static int thin_vfs_stat(const char *path, int32_t *size) {
    if (!path) return 0;
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    int flags = RETRO_VFS_STAT_IS_VALID;
    if (S_ISDIR(st.st_mode)) flags |= RETRO_VFS_STAT_IS_DIRECTORY;
    if (S_ISCHR(st.st_mode)) flags |= RETRO_VFS_STAT_IS_CHARACTER_SPECIAL;
    if (size) *size = (int32_t)st.st_size;
    return flags;
}

static int thin_vfs_mkdir(const char *dir) {
    if (!dir) return -1;
    if (mkdir(dir, 0755) == 0) return 0;
    if (errno == EEXIST) return -2;
    return -1;
}

static struct retro_vfs_dir_handle *thin_vfs_opendir(const char *dir, bool include_hidden) {
    if (!dir) return NULL;
    DIR *dirp = opendir(dir);
    if (!dirp) return NULL;
    struct retro_vfs_dir_handle *handle = (struct retro_vfs_dir_handle *)calloc(1, sizeof(*handle));
    handle->dirp = dirp;
    handle->entry = NULL;
    handle->dir_path = strdup(dir);
    handle->include_hidden = include_hidden;
    return handle;
}

static bool thin_vfs_readdir(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream) return false;
    while (true) {
        dirstream->entry = readdir(dirstream->dirp);
        if (!dirstream->entry) return false;
        // Skip hidden entries (dot-prefixed) unless include_hidden is set
        if (!dirstream->include_hidden && dirstream->entry->d_name[0] == '.') continue;
        return true;
    }
}

static const char *thin_vfs_dirent_get_name(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream || !dirstream->entry) return NULL;
    return dirstream->entry->d_name;
}

static bool thin_vfs_dirent_is_dir(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream || !dirstream->entry) return false;
    // d_type is available on macOS/iOS; use it for efficiency
    if (dirstream->entry->d_type == DT_DIR) return true;
    if (dirstream->entry->d_type != DT_UNKNOWN) return false;
    // Fallback to stat for DT_UNKNOWN
    char fullpath[PATH_MAX];
    snprintf(fullpath, sizeof(fullpath), "%s/%s", dirstream->dir_path, dirstream->entry->d_name);
    struct stat st;
    if (stat(fullpath, &st) != 0) return false;
    return S_ISDIR(st.st_mode);
}

static int thin_vfs_closedir(struct retro_vfs_dir_handle *dirstream) {
    if (!dirstream) return -1;
    int ret = closedir(dirstream->dirp) == 0 ? 0 : -1;
    free(dirstream->dir_path);
    free(dirstream);
    return ret;
}

/// Static VFS interface struct — returned to cores via GET_VFS_INTERFACE.
static struct retro_vfs_interface s_thinVFSInterface = {
    /* v1 */
    thin_vfs_get_path,
    thin_vfs_open,
    thin_vfs_close,
    thin_vfs_size,
    thin_vfs_tell,
    thin_vfs_seek,
    thin_vfs_read,
    thin_vfs_write,
    thin_vfs_flush,
    thin_vfs_remove,
    thin_vfs_rename,
    /* v2 */
    thin_vfs_truncate,
    /* v3 */
    thin_vfs_stat,
    thin_vfs_mkdir,
    thin_vfs_opendir,
    thin_vfs_readdir,
    thin_vfs_dirent_get_name,
    thin_vfs_dirent_is_dir,
    thin_vfs_closedir,
};

#define PV_THIN_VFS_INTERFACE_VERSION 3

// ---------------------------------------------------------------------------
// MARK: - MIDI interface (CoreMIDI)
// ---------------------------------------------------------------------------

#if PV_HAS_COREMIDI

/// Write a single byte into the read ring buffer.
/// Protected by s_midiRingLock so the byte write always precedes the index
/// advance, eliminating the TOCTOU window present in a plain CAS approach.
/// Both the CoreMIDI callback and pv_libretro_midi_inject_byte use this helper
/// so the write protocol is defined in exactly one place.
/// Returns false (and drops the byte) when the buffer is full.
///
/// NOTE on locking in the CoreMIDI callback: CoreMIDI delivers packets on a
/// background thread, not a real-time audio thread, so taking os_unfair_lock
/// (held for < 1 µs) is acceptable here.  A true lock-free scheme would add
/// significant complexity for negligible practical benefit.
static bool thin_midi_ring_write_byte(uint8_t byte) {
    os_unfair_lock_lock(&s_midiRingLock);
    size_t writePos = atomic_load_explicit(&s_midiState.readWritePos, memory_order_relaxed);
    size_t readPos  = atomic_load_explicit(&s_midiState.readReadPos,  memory_order_relaxed);
    size_t next     = (writePos + 1) % PV_MIDI_READ_BUFFER_SIZE;
    if (next == readPos) {
        os_unfair_lock_unlock(&s_midiRingLock);
        return false; // buffer full — drop byte
    }
    s_midiState.readBuffer[writePos] = byte;
    atomic_store_explicit(&s_midiState.readWritePos, next, memory_order_release);
    os_unfair_lock_unlock(&s_midiRingLock);
    return true;
}

/// CoreMIDI read callback -- pushes incoming bytes into our ring buffer.
static void thin_midi_read_callback(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon) {
    (void)readProcRefCon;
    (void)srcConnRefCon;
    const MIDIPacket *packet = &pktlist->packet[0];
    for (UInt32 i = 0; i < pktlist->numPackets; i++) {
        for (UInt16 j = 0; j < packet->length; j++) {
            thin_midi_ring_write_byte(packet->data[j]);
        }
        packet = MIDIPacketNext(packet);
    }
}

/// Lazily initialize CoreMIDI client and connect to first available source/destination.
static bool thin_midi_ensure_initialized(void) {
    if (s_midiState.initialized) return true;

    OSStatus err = MIDIClientCreate(CFSTR("Provenance MIDI"), NULL, NULL, &s_midiState.client);
    if (err != noErr) {
        ELOG(@"ThinFrontend MIDI: MIDIClientCreate failed: %d", (int)err);
        return false;
    }

    // Create input port and connect to first available source
    if (MIDIGetNumberOfSources() > 0) {
        err = MIDIInputPortCreate(s_midiState.client, CFSTR("Provenance MIDI In"),
                                  thin_midi_read_callback, NULL, &s_midiState.inputPort);
        if (err == noErr) {
            MIDIEndpointRef src = MIDIGetSource(0);
            err = MIDIPortConnectSource(s_midiState.inputPort, src, NULL);
            if (err == noErr) {
                s_midiState.inputEndpoint = src;
                ILOG(@"ThinFrontend MIDI: connected to input source");
            }
        }
    }

    // Create output port unconditionally. Destination selection is controlled at
    // runtime via +setMIDIOutputEndpoints: (driven by MIDIDeviceManager). We do
    // NOT cache MIDIGetDestination(0) here — that hardcodes the first device
    // regardless of the user's picker selection. Creating the port unconditionally
    // ensures hot-plug destinations work even when none exist at init time.
    err = MIDIOutputPortCreate(s_midiState.client, CFSTR("Provenance MIDI Out"),
                               &s_midiState.outputPort);
    if (err == noErr) {
        ILOG(@"ThinFrontend MIDI: output port created (%lu destination(s) available)",
             (unsigned long)MIDIGetNumberOfDestinations());
    } else {
        ELOG(@"ThinFrontend MIDI: MIDIOutputPortCreate failed: %d", (int)err);
    }

    // Ring-buffer indices are already zero: s_midiState has static storage
    // duration (zero-initialized at start) and thin_midi_shutdown() memsets
    // the whole struct to 0.  Do NOT reset them here — callbacks can fire
    // immediately after MIDIPortConnectSource above and a reset would lose
    // any bytes they already deposited.
    s_midiState.initialized = true;
    ILOG(@"ThinFrontend MIDI: initialized (inputs=%lu, outputs=%lu)",
         (unsigned long)MIDIGetNumberOfSources(),
         (unsigned long)MIDIGetNumberOfDestinations());
    return true;
}

static void thin_midi_shutdown(void) {
    if (!s_midiState.initialized) return;
    if (s_midiState.inputPort) {
        if (s_midiState.inputEndpoint)
            MIDIPortDisconnectSource(s_midiState.inputPort, s_midiState.inputEndpoint);
        MIDIPortDispose(s_midiState.inputPort);
    }
    if (s_midiState.outputPort)
        MIDIPortDispose(s_midiState.outputPort);
    if (s_midiState.client)
        MIDIClientDispose(s_midiState.client);
    // Hold the ring lock while zeroing state so concurrent thin_midi_read calls
    // (driven by the libretro core) cannot observe partially-cleared indices.
    os_unfair_lock_lock(&s_midiRingLock);
    memset(&s_midiState, 0, sizeof(s_midiState));
    os_unfair_lock_unlock(&s_midiRingLock);
}

static bool thin_midi_input_enabled(void) {
    thin_midi_ensure_initialized();
    return s_midiState.inputPort != 0 && s_midiState.inputEndpoint != 0;
}

static bool thin_midi_output_enabled(void) {
    thin_midi_ensure_initialized();
    if (!s_midiState.outputPort) return false;
    os_unfair_lock_lock(&s_midiDestCacheLock);
    int count = s_midiCachedDestCount;
    os_unfair_lock_unlock(&s_midiDestCacheLock);
    // -1 means the user has never made an explicit selection — fall back to legacy behaviour
    // (MIDIGetDestination(0)) for cores that don't wire the MIDIDeviceManager observer.
    if (count < 0) return MIDIGetNumberOfDestinations() > 0;
    return count > 0;
}

static bool thin_midi_read(uint8_t *byte) {
    if (!byte) return false;
    os_unfair_lock_lock(&s_midiRingLock);
    size_t rp = atomic_load_explicit(&s_midiState.readReadPos,  memory_order_relaxed);
    size_t wp = atomic_load_explicit(&s_midiState.readWritePos, memory_order_acquire);
    if (rp == wp) {
        os_unfair_lock_unlock(&s_midiRingLock);
        return false; // empty
    }
    *byte = s_midiState.readBuffer[rp];
    atomic_store_explicit(&s_midiState.readReadPos, (rp + 1) % PV_MIDI_READ_BUFFER_SIZE, memory_order_release);
    os_unfair_lock_unlock(&s_midiRingLock);
    return true;
}

static bool thin_midi_write(uint8_t byte, uint32_t delta_time) {
    (void)delta_time;
    if (!s_midiState.outputPort) return false;

    // Snapshot the current user-selected destinations (thread-safe).
    os_unfair_lock_lock(&s_midiDestCacheLock);
    int destCount = s_midiCachedDestCount;
    MIDIEndpointRef dests[16];
    if (destCount > 0) {
        memcpy(dests, s_midiCachedDests, (size_t)destCount * sizeof(MIDIEndpointRef));
    }
    os_unfair_lock_unlock(&s_midiDestCacheLock);

    // -1 means the user has never made an explicit selection (e.g. PVLibRetroCore which does
    // not wire the MIDIDeviceManager observer). Fall back to the first available destination
    // to preserve pre-PR behaviour for those cores.
    // Cache the result: MIDIGetDestination(0) is called at byte granularity, so hitting
    // CoreMIDI enumeration APIs on every send would be a performance regression.
    // Benign init race: two threads may both see s_fallbackDest == 0 simultaneously and
    // both call MIDIGetDestination(0); they receive the same value and the final store is
    // idempotent — no lock needed here.
    if (destCount < 0) {
        static MIDIEndpointRef s_fallbackDest = (MIDIEndpointRef)0;
        if (!s_fallbackDest) {
            if (MIDIGetNumberOfDestinations() <= 0) return false;
            MIDIEndpointRef ep = MIDIGetDestination(0);
            if (!ep) return false;
            s_fallbackDest = ep;
        }
        if (!s_fallbackDest) return false;
        dests[0] = s_fallbackDest;
        destCount = 1;
    }

    // No destination selected (user explicitly chose "None") — be a no-op.
    if (destCount == 0) return false;

    // Build a single-byte MIDIPacketList. Use alignas to satisfy MIDIPacketList's
    // alignment requirement — a plain char[] may be under-aligned on some archs.
    alignas(MIDIPacketList) char buf[sizeof(MIDIPacketList) + sizeof(MIDIPacket)];
    MIDIPacketList *pktList = (MIDIPacketList *)buf;
    MIDIPacket *pkt = MIDIPacketListInit(pktList);
    pkt = MIDIPacketListAdd(pktList, sizeof(buf), pkt, 0, 1, &byte);
    if (!pkt) return false;

    // Broadcast to all selected destinations.
    bool sent = false;
    for (int i = 0; i < destCount; i++) {
        if (dests[i] && MIDISend(s_midiState.outputPort, dests[i], pktList) == noErr) {
            sent = true;
        }
    }
    return sent;
}

static bool thin_midi_flush(void) {
    // CoreMIDI sends immediately; nothing to flush
    return true;
}

#else // !PV_HAS_COREMIDI

static bool thin_midi_input_enabled(void) { return false; }
static bool thin_midi_output_enabled(void) { return false; }
static bool thin_midi_read(uint8_t *byte) { (void)byte; return false; }
static bool thin_midi_write(uint8_t byte, uint32_t delta_time) { (void)byte; (void)delta_time; return false; }
static bool thin_midi_flush(void) { return false; }

#endif // PV_HAS_COREMIDI

static struct retro_midi_interface s_thinMIDIInterface = {
    thin_midi_input_enabled,
    thin_midi_output_enabled,
    thin_midi_read,
    thin_midi_write,
    thin_midi_flush,
};

/// C-linkage accessor so `PVLibRetroCore.m` (ObjC, no C++ headers) can wire
/// the same CoreMIDI-backed interface without duplicating code.
/// Returns NULL when CoreMIDI is unavailable (tvOS / no-CoreMIDI builds) so
/// callers treat a null interface as "not supported" rather than receiving stubs.
extern "C" struct retro_midi_interface *pv_libretro_midi_interface(void) {
#if PV_HAS_COREMIDI
    return &s_thinMIDIInterface;
#else
    return NULL;
#endif
}

/// Initialise only the ring buffer bookkeeping, without creating any CoreMIDI
/// client or input port.  Safe to call multiple times (one-time via atomic
/// flag).  This is intentionally decoupled from `thin_midi_ensure_initialized`
/// so that callers that only need the ring buffer (e.g. `MIDIResponder`
/// injection) do not implicitly open a CoreMIDI port or connect to source 0,
/// which would bypass the user's device selection in `MIDIDeviceManager`.
#if PV_HAS_COREMIDI
static void thin_midi_ensure_ring_buffer_initialized(void) {
    static atomic_bool s_ringBufferInitialized = ATOMIC_VAR_INIT(false);
    bool expected = false;
    if (atomic_compare_exchange_strong(&s_ringBufferInitialized, &expected, true)) {
        // NOTE: We intentionally do *not* reset the ring buffer indices here.
        // `s_midiState` has static storage duration and is zero-initialized,
        // so `readWritePos` / `readReadPos` already start at 0. Resetting them
        // on first injection can corrupt state if the CoreMIDI path has
        // already begun using the buffer.
    }
}
#endif

/// Inject a single raw MIDI byte into the libretro MIDI input ring buffer.
///
/// Called by `MIDIResponder` protocol implementations (e.g. `PVHatariCore`) to
/// forward decoded MIDI events from `MIDIDeviceManager` into the
/// `retro_midi_interface` read path so the emulated core receives them.
///
/// This function does NOT create a CoreMIDI port or connect to any source —
/// it only ensures the ring buffer state is ready, preserving the device
/// selection made via `MIDIDeviceManager`.
///
/// Thread-safe: writes are serialized via `s_midiRingLock` inside
/// `thin_midi_ring_write_byte`, and the ring indices remain atomic to
/// coordinate readers and writers.  Bytes are silently dropped when the
/// buffer is full.
extern "C" void pv_libretro_midi_inject_byte(uint8_t byte) {
#if PV_HAS_COREMIDI
    // Ensure ring buffer indices are initialised without opening a CoreMIDI port.
    thin_midi_ensure_ring_buffer_initialized();
    // Delegate to the shared write helper which holds s_midiRingLock so the
    // byte write always precedes the index advance (no TOCTOU window).
    thin_midi_ring_write_byte(byte);
#else
    (void)byte;
#endif
}

// ---------------------------------------------------------------------------
// MARK: - Microphone interface (AudioUnit)
// ---------------------------------------------------------------------------

#if PV_HAS_AUDIOTOOLBOX

/// AudioUnit input callback -- captures PCM samples into the ring buffer.
static OSStatus thin_mic_input_callback(
    void *inRefCon,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData)
{
    struct retro_microphone *mic = (struct retro_microphone *)inRefCon;
    if (!mic || !mic->ringBuffer) return kAudio_ParamError;

    size_t bufferSize = inNumberFrames * mic->format.mBytesPerFrame;
    void *tempBuffer = malloc(bufferSize);
    if (!tempBuffer) return kAudio_MemFullError;

    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mDataByteSize = (UInt32)bufferSize;
    bufferList.mBuffers[0].mData = tempBuffer;

    OSStatus status = AudioUnitRender(mic->audioUnit, ioActionFlags,
                                       inTimeStamp, inBusNumber,
                                       inNumberFrames, &bufferList);
    if (status == noErr) {
        pv_mic_ring_write(mic->ringBuffer,
                          (const int16_t *)bufferList.mBuffers[0].mData,
                          bufferList.mBuffers[0].mDataByteSize / sizeof(int16_t));
    }

    free(tempBuffer);
    return status;
}

static retro_microphone_t *thin_open_mic(const retro_microphone_params_t *params) {
    struct retro_microphone *mic = (struct retro_microphone *)calloc(1, sizeof(*mic));
    if (!mic) return NULL;

    unsigned rate = (params && params->rate) ? params->rate : 44100;
    mic->sampleRate = rate;

#if TARGET_OS_IOS
    // Configure audio session for simultaneous playback + recording (iOS only, not tvOS)
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
                         AVAudioSessionCategoryOptionAllowBluetooth
                   error:&error];
    if (error) {
        ELOG(@"ThinFrontend mic: failed to set audio session category: %@", error.localizedDescription);
    }
    [session setPreferredSampleRate:rate error:nil];
    [session setActive:YES error:nil];
    rate = (unsigned)[session sampleRate];
    mic->sampleRate = rate;
#endif

    // Configure audio format: mono 16-bit PCM
    mic->format.mSampleRate = rate;
    mic->format.mFormatID = kAudioFormatLinearPCM;
    mic->format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    mic->format.mFramesPerPacket = 1;
    mic->format.mChannelsPerFrame = 1;
    mic->format.mBitsPerChannel = 16;
    mic->format.mBytesPerFrame = 2;
    mic->format.mBytesPerPacket = 2;

    // Create ring buffer (~250ms of audio at the given rate)
    size_t ringCapacity = (rate / 4);
    mic->ringBuffer = pv_mic_ring_create(ringCapacity);
    if (!mic->ringBuffer) {
        free(mic);
        return NULL;
    }

    // Set up AudioUnit (RemoteIO on iOS, HALOutput on macOS)
    AudioComponentDescription desc = {
        .componentType = kAudioUnitType_Output,
#if TARGET_OS_IPHONE
        .componentSubType = kAudioUnitSubType_RemoteIO,
#else
        .componentSubType = kAudioUnitSubType_HALOutput,
#endif
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) {
        ELOG(@"ThinFrontend mic: no audio component found");
        pv_mic_ring_free(mic->ringBuffer);
        free(mic);
        return NULL;
    }

    OSStatus status = AudioComponentInstanceNew(comp, &mic->audioUnit);
    if (status != noErr) {
        ELOG(@"ThinFrontend mic: AudioComponentInstanceNew failed: %d", (int)status);
        pv_mic_ring_free(mic->ringBuffer);
        free(mic);
        return NULL;
    }

    // Enable input on bus 1
    UInt32 enableInput = 1;
    status = AudioUnitSetProperty(mic->audioUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Input,
                                   1, &enableInput, sizeof(enableInput));
    if (status != noErr) {
        ELOG(@"ThinFrontend mic: failed to enable input: %d", (int)status);
        AudioComponentInstanceDispose(mic->audioUnit);
        pv_mic_ring_free(mic->ringBuffer);
        free(mic);
        return NULL;
    }

#if !TARGET_OS_IPHONE
    // On macOS, disable output on bus 0 (we only want input)
    UInt32 disableOutput = 0;
    AudioUnitSetProperty(mic->audioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         0, &disableOutput, sizeof(disableOutput));
#endif

    // Set stream format on the output scope of the input bus
    status = AudioUnitSetProperty(mic->audioUnit,
                                   kAudioUnitProperty_StreamFormat,
                                   kAudioUnitScope_Output,
                                   1, &mic->format, sizeof(mic->format));
    if (status != noErr) {
        ELOG(@"ThinFrontend mic: failed to set stream format: %d", (int)status);
        AudioComponentInstanceDispose(mic->audioUnit);
        pv_mic_ring_free(mic->ringBuffer);
        free(mic);
        return NULL;
    }

    // Set input callback
    AURenderCallbackStruct callbackStruct = { thin_mic_input_callback, mic };
    status = AudioUnitSetProperty(mic->audioUnit,
                                   kAudioOutputUnitProperty_SetInputCallback,
                                   kAudioUnitScope_Global,
                                   1, &callbackStruct, sizeof(callbackStruct));
    if (status != noErr) {
        ELOG(@"ThinFrontend mic: failed to set input callback: %d", (int)status);
        AudioComponentInstanceDispose(mic->audioUnit);
        pv_mic_ring_free(mic->ringBuffer);
        free(mic);
        return NULL;
    }

    // Initialize the audio unit
    status = AudioUnitInitialize(mic->audioUnit);
    if (status != noErr) {
        ELOG(@"ThinFrontend mic: AudioUnitInitialize failed: %d", (int)status);
        AudioComponentInstanceDispose(mic->audioUnit);
        pv_mic_ring_free(mic->ringBuffer);
        free(mic);
        return NULL;
    }

    ILOG(@"ThinFrontend mic: opened at %u Hz (mono 16-bit)", mic->sampleRate);
    return mic;
}

static void thin_close_mic(retro_microphone_t *microphone) {
    if (!microphone) return;
    if (microphone->isRunning) {
        AudioOutputUnitStop(microphone->audioUnit);
        microphone->isRunning = false;
    }
    AudioUnitUninitialize(microphone->audioUnit);
    AudioComponentInstanceDispose(microphone->audioUnit);
    pv_mic_ring_free(microphone->ringBuffer);
    ILOG(@"ThinFrontend mic: closed");
    free(microphone);
}

static bool thin_get_mic_params(const retro_microphone_t *microphone, retro_microphone_params_t *params) {
    if (!microphone || !params) return false;
    params->rate = microphone->sampleRate;
    return true;
}

static bool thin_set_mic_state(retro_microphone_t *microphone, bool state) {
    if (!microphone) return false;
    if (state && !microphone->isRunning) {
#if TARGET_OS_IOS
        // Request microphone permission (if not already granted) — iOS only, not tvOS
        AVAudioSession *session = [AVAudioSession sharedInstance];
        if ([session recordPermission] != AVAudioSessionRecordPermissionGranted) {
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            [session requestRecordPermission:^(BOOL granted) {
                dispatch_semaphore_signal(sema);
            }];
            dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
            if ([session recordPermission] != AVAudioSessionRecordPermissionGranted) {
                ELOG(@"ThinFrontend mic: microphone permission denied");
                return false;
            }
        }
#endif
        OSStatus status = AudioOutputUnitStart(microphone->audioUnit);
        if (status != noErr) {
            ELOG(@"ThinFrontend mic: start failed: %d", (int)status);
            return false;
        }
        microphone->isRunning = true;
        ILOG(@"ThinFrontend mic: started capture");
    } else if (!state && microphone->isRunning) {
        AudioOutputUnitStop(microphone->audioUnit);
        microphone->isRunning = false;
        ILOG(@"ThinFrontend mic: stopped capture");
    }
    return true;
}

static bool thin_get_mic_state(const retro_microphone_t *microphone) {
    return microphone && microphone->isRunning;
}

static int thin_read_mic(retro_microphone_t *microphone, int16_t *samples, size_t num_samples) {
    if (!microphone || !samples || !microphone->ringBuffer) return -1;
    size_t readCount = pv_mic_ring_read(microphone->ringBuffer, samples, num_samples);
    return (int)readCount;
}

#else // !PV_HAS_AUDIOTOOLBOX

static retro_microphone_t *thin_open_mic(const retro_microphone_params_t *params) {
    (void)params;
    DLOG(@"ThinFrontend: microphone requested but AudioToolbox unavailable");
    return NULL;
}
static void thin_close_mic(retro_microphone_t *mic) { (void)mic; }
static bool thin_get_mic_params(const retro_microphone_t *mic, retro_microphone_params_t *params) {
    (void)mic; (void)params; return false;
}
static bool thin_set_mic_state(retro_microphone_t *mic, bool state) { (void)mic; (void)state; return false; }
static bool thin_get_mic_state(const retro_microphone_t *mic) { (void)mic; return false; }
static int thin_read_mic(retro_microphone_t *mic, int16_t *samples, size_t num_samples) {
    (void)mic; (void)samples; (void)num_samples; return -1;
}

#endif // PV_HAS_AUDIOTOOLBOX

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
// Note: controllerPortInfo is a readonly property with an explicit getter below; no @synthesize needed.

// MARK: - MIDI routing (class-level, called from Swift MIDIDeviceManager observation)

/// Update the cached list of MIDI output destination endpoint refs.
/// Called from `PVThinLibretroCore+MIDI.swift` whenever `MIDIDeviceManager.selectedDestinationIDs`
/// or `destinations` changes. Thread-safe; may be called from any thread.
///
/// @param endpointRefs  Array of NSNumber wrapping MIDIEndpointRef (UInt32) values.
///                      Pass an empty array when the user selects "None".
+ (void)setMIDIOutputEndpoints:(NSArray<NSNumber *> *)endpointRefs {
#if PV_HAS_COREMIDI
    int n = (int)MIN((NSInteger)endpointRefs.count, (NSInteger)16);
    os_unfair_lock_lock(&s_midiDestCacheLock);
    for (int i = 0; i < n; i++) {
        s_midiCachedDests[i] = (MIDIEndpointRef)[endpointRefs[(NSUInteger)i] unsignedIntValue];
    }
    s_midiCachedDestCount = n;
    os_unfair_lock_unlock(&s_midiDestCacheLock);
    ILOG(@"ThinFrontend MIDI: output destinations updated (count=%d)", n);
#else
    (void)endpointRefs; // suppress unused-parameter warning on non-CoreMIDI builds
#endif
}

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
        _controllerPortInfo = [NSMutableArray array];
        for (unsigned p = 0; p < THIN_MAX_PLAYERS; p++) {
            _portDeviceTypes[p] = RETRO_DEVICE_JOYPAD; // default
        }
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
        // Peripheral interfaces
#if PV_HAS_COREMOTION
        _motionManager = nil;
        _accelerometerActive = NO;
        _gyroscopeActive = NO;
#endif
        _sensorAccelX = _sensorAccelY = _sensorAccelZ = 0.0f;
        _sensorGyroX = _sensorGyroY = _sensorGyroZ = 0.0f;
        _sensorIlluminance = 0.0f;
        _hasCameraCallback = NO;
#if (TARGET_OS_IOS && !TARGET_OS_TV) || TARGET_OS_MACCATALYST
        // Enable battery monitoring once so env 77 (GET_DEVICE_POWER) can read
        // the current level without setting the flag on every callback invocation.
        UIDevice.currentDevice.batteryMonitoringEnabled = YES;
#endif
#if PV_HAS_CORELOCATION
        _locationManager = nil;
        _locationActive = NO;
        _lastLatitude = _lastLongitude = 0.0;
        _lastHorizAccuracy = _lastVertAccuracy = 0.0;
        _locationUpdatedSinceLastRead = NO;
#endif
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        _glContext = nil;
        _glShareContext = nil;
        _ioSurface = NULL;
        _emuFBO = 0;
        _emuColorTex = 0;
        _emuDepthRB = 0;
#endif
#if HAVE_VULKAN
        _vulkanLibrary = NULL;
        _vulkanInstance = NULL;
        _vulkanDevice = NULL;
        _vulkanQueue = NULL;
        _vulkanPhysicalDevice = NULL;
        memset(&_vulkanRenderInterface, 0, sizeof(_vulkanRenderInterface));
        _vulkanQueueLock = OS_UNFAIR_LOCK_INIT;
        _hwSharedContext = NO;
        _vkGetInstanceProcAddr = NULL;
        _vkGetDeviceProcAddr = NULL;
        _vkCreateInstance = NULL;
        _vkDestroyInstance = NULL;
        _vkEnumeratePhysicalDevices = NULL;
        _vkCreateDevice = NULL;
        _vkDestroyDevice = NULL;
        _vkGetDeviceQueue = NULL;
        _vkQueueSubmit = NULL;
        _vkQueueWaitIdle = NULL;
        _vkGetMTLTextureMVK = NULL;
        _vkExportMetalObjectsEXT = NULL;
        _vulkanSignalSemaphore = VK_NULL_HANDLE;
        _vulkanPendingCmdBufCount = 0;
        _vulkanCurrentVkImage = VK_NULL_HANDLE;
        _vulkanHasCurrentImage = NO;
        _vulkanWaitSemaphoreCount = 0;
        _vulkanExtMetalObjectsEnabled = NO;
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
    // Peripheral cleanup
#if PV_HAS_COREMOTION
    if (_motionManager) {
        [_motionManager stopAccelerometerUpdates];
        [_motionManager stopGyroUpdates];
        _motionManager = nil;
    }
#endif
#if PV_HAS_CORELOCATION
    if (_locationManager) {
        [_locationManager stopUpdatingLocation];
        _locationManager = nil;
    }
#endif
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
    THIN_RESOLVE(_sym, _dylibHandle, retro_set_controller_port_device);
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
    _coreDeinited = NO;

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

    // Detect blocking cores (those that run their own loop inside retro_load_game).
    // These cores never return from retro_load_game; instead they call video_refresh
    // internally. We run them on a background thread and use semaphores to sync.
    static NSSet<NSString *> *blockingCoreLibNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockingCoreLibNames = [NSSet setWithObjects:@"prboom", nil];
    });
    NSString *dylibLastComponent = [[self.coreIdentifier componentsSeparatedByString:@"."] firstObject] ?: @"";
    _isBlockingCore = [blockingCoreLibNames containsObject:dylibLastComponent] ||
                      [[self _resolvedCoreDylibPath].lastPathComponent.lowercaseString containsString:@"prboom"];

    bool loaded = NO;
    if (_isBlockingCore) {
        ILOG(@"ThinFrontend: blocking core detected (%@) — running on background thread", self.coreIdentifier);
        _blockingFrameReady = dispatch_semaphore_create(0);
        _blockingCoreTick   = dispatch_semaphore_create(0);
        // Keep data/path alive for the core thread's entire lifetime.
        // _blockingROMPath retains the NSString so the UTF8String pointer in
        // _blockingGameInfo.path remains valid after startWithROMPath: returns.
        _blockingROMData = romData;
        _blockingROMPath = romPath;
        _blockingGameInfo = gameInfo;

        _blockingCoreThread = [[NSThread alloc] initWithTarget:self
                                                     selector:@selector(_blockingCoreThread)
                                                       object:nil];
        _blockingCoreThread.name = @"PVThinLibretro-BlockingCore";
        [_blockingCoreThread start];

        // Wait for the first video_refresh call (= first frame produced) with a
        // generous timeout. If the core fails to init it won't signal at all.
        const long timeoutNs = (long)(10.0 * NSEC_PER_SEC);
        long waitResult = dispatch_semaphore_wait(_blockingFrameReady,
                                                   dispatch_time(DISPATCH_TIME_NOW, timeoutNs));
        if (waitResult != 0) {
            ELOG(@"ThinFrontend: blocking core timed out during retro_load_game");
            if (error) {
                *error = [NSError errorWithDomain:@"PVThinLibretroFrontend"
                                             code:5
                                         userInfo:@{NSLocalizedDescriptionKey: @"retro_load_game timed out (blocking core)"}];
            }
            _sym.retro_deinit();
            _thinCurrentTLS = nil;
            return NO;
        }
        loaded = YES;  // if we got a frame, load succeeded
    } else {
        loaded = _sym.retro_load_game(&gameInfo);
    }

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

- (void)setControllerPortDevice:(unsigned)device forPort:(unsigned)port {
    if (_sym.retro_set_controller_port_device) {
        ILOG(@"ThinFrontend: set port %u device = %u", port, device);
        _sym.retro_set_controller_port_device(port, device);
        if (port < THIN_MAX_PLAYERS) {
            _portDeviceTypes[port] = device;
        }
    } else {
        // Core does not export retro_set_controller_port_device; ignore the request.
        ILOG(@"ThinFrontend: core does not support setting controller port devices; "
             "ignoring request for port %u device = %u", port, device);
    }
}

- (BOOL)supportsControllerPortDevice {
    return _sym.retro_set_controller_port_device != NULL;
}

+ (NSUInteger)maxPlayers {
    return THIN_MAX_PLAYERS;
}

- (NSArray<NSArray<NSDictionary<NSString *, id> *> *> *)controllerPortInfo {
    return _controllerPortInfo ?: @[];
}

- (unsigned)currentDeviceTypeForPort:(unsigned)port {
    if (port >= THIN_MAX_PLAYERS) return RETRO_DEVICE_JOYPAD;
    return _portDeviceTypes[port];
}

- (void)resetEmulation {
    if (_sym.retro_reset) {
        ILOG(@"ThinFrontend: retro_reset");
        _sym.retro_reset();
    }
}

- (void)stopEmulation {
    // Guard: retro_deinit must only be called once. dealloc also calls stopEmulation,
    // which can re-enter after the core has already been torn down → crash.
    if (_coreDeinited) {
        return;
    }
    _audioPaused = YES;
    // Stop peripheral interfaces
#if PV_HAS_COREMOTION
    if (_motionManager) {
        [_motionManager stopAccelerometerUpdates];
        [_motionManager stopGyroUpdates];
        _accelerometerActive = NO;
        _gyroscopeActive = NO;
    }
#endif
#if PV_HAS_CORELOCATION
    [self _locationStop];
#endif
#if PV_HAS_AVFOUNDATION
    // Stop camera capture
    if (_cameraCaptureSession) {
        [_cameraCaptureSession stopRunning];
        _cameraCaptureSession = nil;
        _cameraVideoOutput = nil;
        _cameraSessionRunning = NO;
    }
    if (_cameraFrameBuffer) {
        free(_cameraFrameBuffer);
        _cameraFrameBuffer = NULL;
    }
    s_cameraDelegate = nil;
#endif
#if PV_HAS_COREMIDI
    thin_midi_shutdown();
#endif
    // Flush battery save (SRAM) before tearing down the core
    [self saveBatterySaveData];
    // Unblock a blocking core thread so it doesn't deadlock waiting on _blockingCoreTick.
    if (_isBlockingCore && _blockingCoreTick) {
        dispatch_semaphore_signal(_blockingCoreTick);
        // Wait for the blocking core thread to finish before tearing down.
        // The thread sets _thinCurrentTLS = nil on exit; poll with a timeout
        // so we don't hang forever if the core is stuck.
        if (_blockingCoreThread && !_blockingCoreThread.isFinished) {
            NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
            while (!_blockingCoreThread.isFinished && [deadline timeIntervalSinceNow] > 0) {
                [NSThread sleepForTimeInterval:0.01];
            }
            if (!_blockingCoreThread.isFinished) {
                WLOG(@"ThinFrontend: blocking core thread did not exit within 3s, proceeding with teardown");
            }
        }
        _blockingCoreThread = nil;
    }
    [super stopEmulation]; // stops emulation loop thread before retro teardown
    [self clearAllInput];
    if (_sym.retro_unload_game) {
        _sym.retro_unload_game();
    }
    if (_sym.retro_deinit) {
        _sym.retro_deinit();
    }
    _coreDeinited = YES;
    [self teardownHardwareContext];
    _thinCurrentTLS = nil;
}

- (void)setPauseEmulation:(BOOL)flag {
    _audioPaused = flag;
    [super setPauseEmulation:flag];
}

- (void)_blockingCoreThread {
    _thinCurrentTLS = self;
    // retro_load_game never returns for blocking cores; it runs the game loop
    // internally and calls video_refresh each frame. thin_video_refresh will
    // signal _blockingFrameReady and then stall on _blockingCoreTick, giving
    // the frontend thread a chance to present each frame via runFrame.
    _sym.retro_load_game(&_blockingGameInfo);
    // If we get here the core exited its loop (e.g. user quit from menu).
    ILOG(@"ThinFrontend: blocking core thread exited");
    _thinCurrentTLS = nil;
}

- (void)runFrame {
    if (!_sym.retro_run && !_isBlockingCore) return;

    if (_isBlockingCore) {
        // Signal core to advance one tick, then wait for the next frame.
        dispatch_semaphore_signal(_blockingCoreTick);
        dispatch_semaphore_wait(_blockingFrameReady, DISPATCH_TIME_FOREVER);
        return;
    }

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    // Initial setup: if OpenGL ES HW render was requested, set up the FBO now.
    // Resize: if geometry changed at runtime (SET_SYSTEM_AV_INFO / SET_GEOMETRY),
    //   tear down the old FBO and rebuild it so context_reset re-fires with correct dims.
    // Both paths MUST run on the emulation thread so EAGLContext and context_reset share
    // the same GL context as subsequent retro_run calls.
    if (_hwRenderRequested && _glContext) {
        if (!_emuFBO) {
            uint32_t w = _rawAVInfo.geometry.max_width  ?: (_rawAVInfo.geometry.base_width  ?: 640);
            uint32_t h = _rawAVInfo.geometry.max_height ?: (_rawAVInfo.geometry.base_height ?: 480);
            ILOG(@"ThinFrontend: first frame — setting up HW render FBO %ux%u", w, h);
            [self setupHardwareContextFBOWidth:w height:h];
        } else if (_hwFBONeedsRebuild) {
            uint32_t w = _rawAVInfo.geometry.max_width  ?: (_rawAVInfo.geometry.base_width  ?: 640);
            uint32_t h = _rawAVInfo.geometry.max_height ?: (_rawAVInfo.geometry.base_height ?: 480);
            ILOG(@"ThinFrontend: geometry changed — rebuilding HW render FBO %ux%u", w, h);
            // Clear the flag immediately so a failed setup does not cause an
            // infinite teardown loop on every subsequent runFrame call.
            _hwFBONeedsRebuild = NO;
            // Make the core's GL context current BEFORE notifying it via context_destroy.
            // Cores commonly issue GL calls (e.g. glDeleteTextures) in context_destroy,
            // which require a valid current context; calling it without one can crash or leak.
            [EAGLContext setCurrentContext:_glContext];
            // Notify core that the context is being destroyed before teardown
            if (_hwRenderCallback.context_destroy) {
                _hwRenderCallback.context_destroy();
            }
            // Release GL objects only — keep EAGLContext and _hwRenderRequested intact
            if (_emuFBO)      { glDeleteFramebuffers(1,  &_emuFBO);    _emuFBO = 0; }
            if (_emuColorTex) { glDeleteTextures(1,      &_emuColorTex); _emuColorTex = 0; }
            if (_emuDepthRB)  { glDeleteRenderbuffers(1, &_emuDepthRB); _emuDepthRB = 0; }
            if (_ioSurface)   { CFRelease(_ioSurface);  _ioSurface = NULL; }
            // Reset so setupHardwareContextFBOWidth:height: re-calls startRenderingOnAlternateThread
            // to obtain a new IOSurface sized for the updated geometry. This is intentional:
            // the delegate must re-create its Metal texture at the new dimensions.
            _renderDelegateStarted = NO;
            [self setupHardwareContextFBOWidth:w height:h];
        }
    }
#endif

    // Drive the frame-time callback if the core registered one
    if (_hasFrameTimeCallback && _frameTimeCallback.callback) {
        int64_t nowUs = (int64_t)(CACurrentMediaTime() * 1000000.0);
        retro_usec_t delta = (_lastFrameTimeUs == 0) ? (retro_usec_t)(1000000.0 / _rawAVInfo.timing.fps) : (retro_usec_t)(nowUs - _lastFrameTimeUs);
        _lastFrameTimeUs = nowUs;
        _frameTimeCallback.callback(delta);
    }

    _thinCurrentTLS = self;

#if PV_HAS_AVFOUNDATION
    // Deliver camera frame to core if capture is active
    if (_hasCameraCallback && _cameraSessionRunning && _cameraFrameBuffer
        && _cameraCallback.frame_raw_framebuffer) {
        _cameraCallback.frame_raw_framebuffer(
            _cameraFrameBuffer,
            (unsigned)_cameraBufferWidth,
            (unsigned)_cameraBufferHeight,
            _cameraBufferWidth * sizeof(uint32_t));
    }
#endif

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
    if (!_sym.retro_unserialize || !stateData || stateData.length == 0) return NO;

    // Validate size against what the core expects. A size mismatch usually means
    // the save state came from a different core version or a different wrapper
    // (e.g. full RetroArch vs thin). Allow loading if sizes differ (some cores
    // handle version differences gracefully) but warn about it.
    if (_sym.retro_serialize_size) {
        size_t expectedSize = _sym.retro_serialize_size();
        if (expectedSize > 0 && stateData.length != expectedSize) {
            WLOG(@"ThinFrontend: save state size mismatch — file: %zu, core expects: %zu",
                 (size_t)stateData.length, expectedSize);
        }
    }

    BOOL success = _sym.retro_unserialize(stateData.bytes, stateData.length);
    if (!success) {
        ELOG(@"ThinFrontend: retro_unserialize failed — save state may be from incompatible core version");
    }
    return success;
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

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError * _Nullable))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self saveStateToFileAtPath:fileName error:&error];
        if (block) block(error);
    });
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

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError * _Nullable))block {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        [self loadStateFromFileAtPath:fileName error:&error];
        if (block) block(error);
    });
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

// MARK: - Disc control

- (BOOL)currentGameSupportsMultipleDiscs {
    if (_hasDiskControlExt && _diskControlExt.get_num_images) {
        return _diskControlExt.get_num_images() > 1;
    }
    if (_hasDiskControl && _diskControl.get_num_images) {
        return _diskControl.get_num_images() > 1;
    }
    return NO;
}

- (NSUInteger)numberOfDiscs {
    if (_hasDiskControlExt && _diskControlExt.get_num_images) {
        return (NSUInteger)_diskControlExt.get_num_images();
    }
    if (_hasDiskControl && _diskControl.get_num_images) {
        return (NSUInteger)_diskControl.get_num_images();
    }
    return 0;
}

- (void)swapDiscWithNumber:(NSUInteger)number {
    // libretro disc swap: eject → set_image_index → insert
    if (_hasDiskControlExt) {
        if (_diskControlExt.set_eject_state) _diskControlExt.set_eject_state(true);
        if (_diskControlExt.set_image_index) _diskControlExt.set_image_index((unsigned)(number > 0 ? number - 1 : 0));
        if (_diskControlExt.set_eject_state) _diskControlExt.set_eject_state(false);
    } else if (_hasDiskControl) {
        if (_diskControl.set_eject_state) _diskControl.set_eject_state(true);
        if (_diskControl.set_image_index) _diskControl.set_image_index((unsigned)(number > 0 ? number - 1 : 0));
        if (_diskControl.set_eject_state) _diskControl.set_eject_state(false);
    }
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

- (const void *)videoBuffer { return (const void *)_videoBufferData; }

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
    // Call post-load hook before starting the emulation loop thread so subclasses
    // can apply per-port device types in a thread-safe window.
    if (self.afterROMLoadBlock) {
        self.afterROMLoadBlock();
    }
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

    // RETRO_HW_FRAME_BUFFER_VALID means the core has rendered into our FBO
    // (_emuFBO / _ioSurface). Notify the Metal presenter so it can blit the
    // IOSurface-backed texture to the display. The render delegate's
    // didRenderFrameOnAlternateThread already calls glFlush(), so we do not
    // flush here to avoid a redundant double-flush per frame.
    if (data == RETRO_HW_FRAME_BUFFER_VALID) {
#if HAVE_VULKAN
        if (_hwRenderCallback.context_type == RETRO_HW_CONTEXT_VULKAN) {
            // Snapshot and clear pending command buffers under the lock so we don't
            // race with thin_vulkan_set_command_buffers (which may be called from
            // any thread per the libretro Vulkan interface spec).
            os_unfair_lock_lock(&_vulkanQueueLock);
            uint32_t pendingCount = _vulkanPendingCmdBufCount;
            VkCommandBuffer pendingCmds[64];
            if (pendingCount > 0) {
                memcpy(pendingCmds, _vulkanPendingCmdBufs, pendingCount * sizeof(VkCommandBuffer));
                _vulkanPendingCmdBufCount = 0;
            }
            os_unfair_lock_unlock(&_vulkanQueueLock);

            if (pendingCount > 0) {
                // Normal Vulkan path: submit the deferred command buffers now that
                // retro_video_refresh_t has been called (per libretro_vulkan.h spec).
                [self submitVulkanCommandBuffers:pendingCmds count:pendingCount];
                // submitVulkanCommandBuffers notifies the delegate if _vulkanHasCurrentImage.
            } else if (_vulkanHasCurrentImage) {
                // Async-compute path: core called set_image but no set_command_buffers.
                // Consume wait semaphores (if any) via a wait-only queue submission,
                // then export and present the VkImage.
                _vulkanHasCurrentImage = NO;
                if (_vulkanWaitSemaphoreCount > 0 && _vkQueueSubmit && _vulkanQueue) {
                    os_unfair_lock_lock(&_vulkanQueueLock);
                    uint32_t waitCount = _vulkanWaitSemaphoreCount;
                    VkSemaphore waitSems[8];
                    VkPipelineStageFlags waitMasks[8];
                    memcpy(waitSems,  _vulkanWaitSemaphores,    waitCount * sizeof(VkSemaphore));
                    memcpy(waitMasks, _vulkanWaitDstStageMask,  waitCount * sizeof(VkPipelineStageFlags));
                    _vulkanWaitSemaphoreCount = 0;
                    VkSubmitInfo waitSubmit = {
                        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
                        .waitSemaphoreCount = waitCount,
                        .pWaitSemaphores = waitSems,
                        .pWaitDstStageMask = waitMasks,
                        .commandBufferCount = 0,
                    };
                    VkResult waitResult = _vkQueueSubmit(_vulkanQueue, 1, &waitSubmit, VK_NULL_HANDLE);
                    if (waitResult == VK_SUCCESS && _vkQueueWaitIdle) {
                        _vkQueueWaitIdle(_vulkanQueue);
                    } else if (waitResult != VK_SUCCESS) {
                        ELOG(@"ThinFrontend: async-compute vkQueueSubmit failed (result=%d)", waitResult);
                    }
                    os_unfair_lock_unlock(&_vulkanQueueLock);
                    if (waitResult != VK_SUCCESS) { return; }
                }
                [self notifyRenderDelegateOfVulkanFrame:nil];
            }
            return;
        }
#endif // HAVE_VULKAN
        id renderDelegate = self.renderDelegate;
        if ([renderDelegate respondsToSelector:@selector(didRenderFrameOnAlternateThread)]) {
            [renderDelegate didRenderFrameOnAlternateThread];
        }
        return;
    }

    if (!data || !_videoBufferData) return;
    NSUInteger maxW = (_rawAVInfo.geometry.max_width  ?: w);
    NSUInteger bpp  = (_retroPixelFormat == RETRO_PIXEL_FORMAT_XRGB8888) ? 4 : 2;
    NSUInteger dstStride  = maxW * bpp;
    NSUInteger copyW = MIN(w, maxW);
    // vImageCopyBuffer handles strided copies with NEON, avoiding per-row memcpy overhead.
    // When pitch == dstStride it degrades to a single vectorised block copy.
    vImage_Buffer src = { .data = (void *)data,       .height = h, .width = copyW, .rowBytes = pitch    };
    vImage_Buffer dst = { .data = _videoBufferData,   .height = h, .width = copyW, .rowBytes = dstStride };
    vImageCopyBuffer(&src, &dst, bpp, kvImageNoFlags);
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
    static bool s_loggedPoll = false;
    if (!s_loggedPoll) {
        ILOG(@"ThinFrontend: _thinInputPoll called (delegate=%@, joypad[0]=0x%04X, inputPollBlock=%@)", self.frontendDelegate, _joypadState[0], self.inputPollBlock ? @"YES" : @"NO");
        s_loggedPoll = true;
    }
    if (self.frontendDelegate) {
        [self.frontendDelegate libretroFrontendPollInput:self];
    }
    // Poll physical GCControllers if the Swift core registered a poll block
    if (self.inputPollBlock) {
        self.inputPollBlock();
    }
}

- (int16_t)_thinInputStatePort:(unsigned)port device:(unsigned)dev index:(unsigned)idx id:(unsigned)bid {
    // One-shot diagnostic: confirm core is actually polling input
    static bool s_loggedInputPoll = false;
    if (!s_loggedInputPoll) {
        ILOG(@"ThinFrontend: ✅ Core is polling input (port=%u dev=%u idx=%u id=%u) delegate=%@", port, dev, idx, bid, self.frontendDelegate);
        s_loggedInputPoll = true;
    }

    if (self.frontendDelegate) {
        return [self.frontendDelegate libretroFrontend:self inputStateForPort:port device:dev index:idx id:bid];
    }

    // Direct bitmask-based input (used by PVThinLibretroCore Swift responder protocols)
    if (port >= THIN_MAX_PLAYERS) return 0;

    unsigned deviceType = dev & RETRO_DEVICE_MASK;

    if (deviceType == RETRO_DEVICE_JOYPAD) {
        if (bid == RETRO_DEVICE_ID_JOYPAD_MASK) {
            // Bitmask query — return all buttons at once
            // Log when state is non-zero (throttled)
            static uint64_t s_lastNonZeroLog = 0;
            if (_joypadState[port] != 0) {
                uint64_t now = (uint64_t)(CACurrentMediaTime() * 1000);
                if (now - s_lastNonZeroLog > 500) { // Max once per 500ms
                    ILOG(@"ThinFrontend: input_state BITMASK port=%u → 0x%04X", port, _joypadState[port]);
                    s_lastNonZeroLog = now;
                }
            }
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

    if (deviceType == RETRO_DEVICE_LIGHTGUN) {
        switch (bid) {
            case RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X:
                return _lightgunX;
            case RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y:
                return _lightgunY;
            case RETRO_DEVICE_ID_LIGHTGUN_IS_OFFSCREEN:
                return _lightgunIsOffscreen ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_TRIGGER:
                return _lightgunTrigger ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_RELOAD:
                return _lightgunReload ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_AUX_A:
                return _lightgunAuxA ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_AUX_B:
                return _lightgunAuxB ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_START:
                return _lightgunStart ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_SELECT:
                return _lightgunSelect ? 1 : 0;
            case RETRO_DEVICE_ID_LIGHTGUN_DPAD_UP:
                return (_joypadState[port] >> RETRO_DEVICE_ID_JOYPAD_UP) & 1;
            case RETRO_DEVICE_ID_LIGHTGUN_DPAD_DOWN:
                return (_joypadState[port] >> RETRO_DEVICE_ID_JOYPAD_DOWN) & 1;
            case RETRO_DEVICE_ID_LIGHTGUN_DPAD_LEFT:
                return (_joypadState[port] >> RETRO_DEVICE_ID_JOYPAD_LEFT) & 1;
            case RETRO_DEVICE_ID_LIGHTGUN_DPAD_RIGHT:
                return (_joypadState[port] >> RETRO_DEVICE_ID_JOYPAD_RIGHT) & 1;
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
        ILOG(@"ThinFrontend: setButton %u pressed for player %u → joypadState=0x%04X", buttonId, player, _joypadState[player]);
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
    // Reset light-gun state to prevent stale values across resets/pause/resume
    _lightgunX           = 0;
    _lightgunY           = 0;
    _lightgunIsOffscreen = false;
    _lightgunTrigger     = false;
    _lightgunReload      = false;
    _lightgunAuxA        = false;
    _lightgunAuxB        = false;
    _lightgunStart       = false;
    _lightgunSelect      = false;
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

// MARK: Light gun input

- (void)setLightgunX:(int16_t)x
                   y:(int16_t)y
             trigger:(BOOL)trigger
                auxA:(BOOL)auxA
                auxB:(BOOL)auxB
               start:(BOOL)start
              select:(BOOL)select
         isOffscreen:(BOOL)isOffscreen
              reload:(BOOL)reload {
    _lightgunX          = x;
    _lightgunY          = y;
    _lightgunTrigger    = trigger    ? true : false;
    _lightgunAuxA       = auxA       ? true : false;
    _lightgunAuxB       = auxB       ? true : false;
    _lightgunStart      = start      ? true : false;
    _lightgunSelect     = select     ? true : false;
    _lightgunIsOffscreen = isOffscreen ? true : false;
    _lightgunReload     = reload     ? true : false;
}

// ---------------------------------------------------------------------------
// MARK: - Sensor interface implementation (CoreMotion)
// ---------------------------------------------------------------------------

- (BOOL)_sensorSetState:(enum retro_sensor_action)action rate:(unsigned)rate port:(unsigned)port {
#if PV_HAS_COREMOTION
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    NSTimeInterval interval = (rate > 0) ? (1.0 / (NSTimeInterval)rate) : (1.0 / 60.0);

    switch (action) {
        case RETRO_SENSOR_ACCELEROMETER_ENABLE:
            if (_motionManager.isAccelerometerAvailable && !_accelerometerActive) {
                _motionManager.accelerometerUpdateInterval = interval;
                [_motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue]
                    withHandler:^(CMAccelerometerData *data, NSError *error) {
                        if (data) {
                            self->_sensorAccelX = (float)data.acceleration.x;
                            self->_sensorAccelY = (float)data.acceleration.y;
                            self->_sensorAccelZ = (float)data.acceleration.z;
                        }
                    }];
                _accelerometerActive = YES;
                ILOG(@"ThinFrontend: accelerometer enabled (rate=%u Hz)", rate);
            }
            return true;

        case RETRO_SENSOR_ACCELEROMETER_DISABLE:
            if (_accelerometerActive) {
                [_motionManager stopAccelerometerUpdates];
                _accelerometerActive = NO;
                _sensorAccelX = _sensorAccelY = _sensorAccelZ = 0.0f;
                ILOG(@"ThinFrontend: accelerometer disabled");
            }
            return true;

        case RETRO_SENSOR_GYROSCOPE_ENABLE:
            if (_motionManager.isGyroAvailable && !_gyroscopeActive) {
                _motionManager.gyroUpdateInterval = interval;
                [_motionManager startGyroUpdatesToQueue:[NSOperationQueue mainQueue]
                    withHandler:^(CMGyroData *data, NSError *error) {
                        if (data) {
                            self->_sensorGyroX = (float)data.rotationRate.x;
                            self->_sensorGyroY = (float)data.rotationRate.y;
                            self->_sensorGyroZ = (float)data.rotationRate.z;
                        }
                    }];
                _gyroscopeActive = YES;
                ILOG(@"ThinFrontend: gyroscope enabled (rate=%u Hz)", rate);
            }
            return true;

        case RETRO_SENSOR_GYROSCOPE_DISABLE:
            if (_gyroscopeActive) {
                [_motionManager stopGyroUpdates];
                _gyroscopeActive = NO;
                _sensorGyroX = _sensorGyroY = _sensorGyroZ = 0.0f;
                ILOG(@"ThinFrontend: gyroscope disabled");
            }
            return true;

        case RETRO_SENSOR_ILLUMINANCE_ENABLE:
            // Ambient light sensor is not directly accessible on iOS via CoreMotion.
            // Would need a private API or screen brightness heuristic.
            DLOG(@"ThinFrontend: illuminance sensor not available");
            return false;

        case RETRO_SENSOR_ILLUMINANCE_DISABLE:
            _sensorIlluminance = 0.0f;
            return true;

        default:
            return false;
    }
#else
    // No CoreMotion on this platform (tvOS, macOS, etc.)
    DLOG(@"ThinFrontend: sensor interface not available on this platform");
    return false;
#endif
}

- (float)_sensorGetInput:(unsigned)sensorId port:(unsigned)port {
    switch (sensorId) {
        case RETRO_SENSOR_ACCELEROMETER_X: return _sensorAccelX;
        case RETRO_SENSOR_ACCELEROMETER_Y: return _sensorAccelY;
        case RETRO_SENSOR_ACCELEROMETER_Z: return _sensorAccelZ;
        case RETRO_SENSOR_GYROSCOPE_X:     return _sensorGyroX;
        case RETRO_SENSOR_GYROSCOPE_Y:     return _sensorGyroY;
        case RETRO_SENSOR_GYROSCOPE_Z:     return _sensorGyroZ;
        case RETRO_SENSOR_ILLUMINANCE:     return _sensorIlluminance;
        default: return 0.0f;
    }
}

// ---------------------------------------------------------------------------
// MARK: - Location interface implementation (CoreLocation)
// ---------------------------------------------------------------------------

- (BOOL)_locationStart {
#if PV_HAS_CORELOCATION
    if (_locationActive) return true;
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        // Note: NSLocationWhenInUseUsageDescription must be in Info.plist.
        // On iOS 13.4+ authorization is requested lazily by the system.
        if ([_locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [_locationManager requestWhenInUseAuthorization];
        }
    }
    [_locationManager startUpdatingLocation];
    _locationActive = YES;
    _locationUpdatedSinceLastRead = NO;
    ILOG(@"ThinFrontend: location services started");
    return true;
#else
    DLOG(@"ThinFrontend: location interface not available on this platform");
    return false;
#endif
}

- (void)_locationStop {
#if PV_HAS_CORELOCATION
    if (!_locationActive) return;
    [_locationManager stopUpdatingLocation];
    _locationActive = NO;
    ILOG(@"ThinFrontend: location services stopped");
#endif
}

- (BOOL)_locationGetPositionLat:(double *)lat lon:(double *)lon
                  horizAccuracy:(double *)ha vertAccuracy:(double *)va {
#if PV_HAS_CORELOCATION
    // Read the latest location from CLLocationManager
    CLLocation *loc = _locationManager.location;
    if (loc) {
        _lastLatitude = loc.coordinate.latitude;
        _lastLongitude = loc.coordinate.longitude;
        _lastHorizAccuracy = loc.horizontalAccuracy;
        _lastVertAccuracy = loc.verticalAccuracy;
        _locationUpdatedSinceLastRead = YES;
    }

    if (!_locationUpdatedSinceLastRead) {
        // No update since last read — return zeros per libretro spec
        if (lat) *lat = 0.0;
        if (lon) *lon = 0.0;
        if (ha)  *ha  = 0.0;
        if (va)  *va  = 0.0;
        return false;
    }

    if (lat) *lat = _lastLatitude;
    if (lon) *lon = _lastLongitude;
    if (ha)  *ha  = _lastHorizAccuracy;
    if (va)  *va  = _lastVertAccuracy;
    _locationUpdatedSinceLastRead = NO;
    return true;
#else
    if (lat) *lat = 0.0;
    if (lon) *lon = 0.0;
    if (ha)  *ha  = 0.0;
    if (va)  *va  = 0.0;
    return false;
#endif
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

/// Returns YES when a HW-render core is loaded so PVMetalViewController
/// uses the OpenGL rendering path (IOSurface + didRenderFrameOnAlternateThread)
/// instead of the software buffer upload path.
///
/// This path is intentionally enabled on both iOS and tvOS — both platforms
/// support Metal + IOSurface-backed textures. Only macOS/Catalyst is excluded
/// because the EAGL/IOSurface bridge APIs are unavailable there.
- (BOOL)rendersToOpenGL {
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
    return _hwRenderRequested;
#else
    return NO;
#endif
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
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
            // If a HW FBO is live and the new dimensions differ, schedule a rebuild.
            // The rebuild runs on the emulation thread (next runFrame call) so that
            // context_reset and subsequent retro_run share the same EAGLContext.
            if (_emuFBO) {
                uint32_t newW = info->geometry.max_width  ?: info->geometry.base_width;
                uint32_t newH = info->geometry.max_height ?: info->geometry.base_height;
                if (newW != _fboWidth || newH != _fboHeight) {
                    ILOG(@"ThinEnv SET_SYSTEM_AV_INFO: HW FBO resize %ux%u → %ux%u (deferred)",
                         _fboWidth, _fboHeight, newW, newH);
                    _hwFBONeedsRebuild = YES;
                }
            }
#endif
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
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
            // If a HW FBO is live and the max dimensions grew, schedule a rebuild.
            if (_emuFBO && needsRealloc) {
                uint32_t newW = geo->max_width  ?: geo->base_width;
                uint32_t newH = geo->max_height ?: geo->base_height;
                ILOG(@"ThinEnv SET_GEOMETRY: HW FBO resize %ux%u → %ux%u (deferred)",
                     _fboWidth, _fboHeight, newW, newH);
                _hwFBONeedsRebuild = YES;
            }
#endif
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
                                        | (1ULL << RETRO_DEVICE_POINTER)
                                        | (1ULL << RETRO_DEVICE_LIGHTGUN)
                                        | (1ULL << RETRO_DEVICE_KEYBOARD);
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
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO: {
            const struct retro_controller_info *info = (const struct retro_controller_info *)data;
            if (!info) return true;

            NSMutableArray *portsArray = [NSMutableArray array];
            for (unsigned p = 0; info[p].types && p < THIN_MAX_PLAYERS; p++) {
                NSMutableArray *portTypes = [NSMutableArray array];
                for (unsigned t = 0; t < info[p].num_types; t++) {
                    NSString *desc = info[p].types[t].desc
                        ? [NSString stringWithUTF8String:info[p].types[t].desc]
                        : [NSString stringWithFormat:@"Device %u", info[p].types[t].id];
                    [portTypes addObject:@{
                        @"id": @(info[p].types[t].id),
                        @"desc": desc
                    }];
                }
                [portsArray addObject:portTypes];
            }
            _controllerPortInfo = [portsArray copy];
            ILOG(@"ThinEnv SET_CONTROLLER_INFO: %lu ports (clamped to THIN_MAX_PLAYERS=%u)", (unsigned long)portsArray.count, THIN_MAX_PLAYERS);
            return true;
        }
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

            // Forward to OSD only for user-facing notification types.
            // STATUS (2) and PROGRESS (3) are in-place status overlays sent every frame
            // (e.g. melonDS "Layout 1/2") — they must NOT become individual toasts.
            // NOTIFICATION (0) and NOTIFICATION_ALT (1) are genuine one-shot messages.
            BOOL isStatusOverlay = (msg->type == RETRO_MESSAGE_TYPE_STATUS ||
                                    msg->type == RETRO_MESSAGE_TYPE_PROGRESS);
            if (msg->target != RETRO_MESSAGE_TARGET_LOG && !isStatusOverlay) {
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

        // ---- Sensor interface (CoreMotion) ----
        case RETRO_ENVIRONMENT_GET_SENSOR_INTERFACE: {
            struct retro_sensor_interface *sensor = (struct retro_sensor_interface *)data;
            if (!sensor) return false;
            sensor->set_sensor_state = thin_sensor_set_state;
            sensor->get_sensor_input = thin_sensor_get_input;
            ILOG(@"ThinEnv GET_SENSOR_INTERFACE: provided sensor callbacks");
            return true;
        }

        // ---- Camera interface (AVFoundation-backed) ----
        case RETRO_ENVIRONMENT_GET_CAMERA_INTERFACE: {
            struct retro_camera_callback *cam = (struct retro_camera_callback *)data;
            if (!cam) return false;
            // Store the core's callbacks (frame_raw_framebuffer, frame_opengl_texture, etc.)
            _cameraCallback = *cam;
            _hasCameraCallback = YES;
            // Provide our start/stop implementations
            cam->start = thin_camera_start;
            cam->stop  = thin_camera_stop;
            // Announce raw framebuffer capability (no GL texture support yet)
            cam->caps = (1 << RETRO_CAMERA_BUFFER_RAW_FRAMEBUFFER);
            ILOG(@"ThinEnv GET_CAMERA_INTERFACE: provided AVFoundation-backed camera (%ux%u)", cam->width, cam->height);
            return true;
        }

        // ---- Microphone interface (AudioUnit-backed) ----
        case RETRO_ENVIRONMENT_GET_MICROPHONE_INTERFACE: {
            struct retro_microphone_interface *mic = (struct retro_microphone_interface *)data;
            if (!mic) return false;
            // Store the core's requested interface version
            _microphoneInterface = *mic;
            _hasMicrophoneInterface = YES;
            // Provide our implementation
            mic->interface_version = RETRO_MICROPHONE_INTERFACE_VERSION;
            mic->open_mic = thin_open_mic;
            mic->close_mic = thin_close_mic;
            mic->get_params = thin_get_mic_params;
            mic->set_mic_state = thin_set_mic_state;
            mic->get_mic_state = thin_get_mic_state;
            mic->read_mic = thin_read_mic;
            ILOG(@"ThinEnv GET_MICROPHONE_INTERFACE: provided AudioUnit-backed implementation");
            return true;
        }

        // ---- Location interface (CoreLocation) ----
        case RETRO_ENVIRONMENT_GET_LOCATION_INTERFACE: {
            struct retro_location_callback *loc = (struct retro_location_callback *)data;
            if (!loc) return false;
            loc->start        = thin_location_start;
            loc->stop         = thin_location_stop;
            loc->get_position = thin_location_get_position;
            loc->set_interval = thin_location_set_interval;
            // initialized/deinitialized are set by the core, not by us
            ILOG(@"ThinEnv GET_LOCATION_INTERFACE: provided location callbacks");
            return true;
        }

        // ---- LED interface (GameController light bar) ----
        case RETRO_ENVIRONMENT_GET_LED_INTERFACE: {
            struct retro_led_interface *led = (struct retro_led_interface *)data;
            if (!led) return false;
            led->set_led_state = thin_led_set_state;
            ILOG(@"ThinEnv GET_LED_INTERFACE: provided LED callback");
            return true;
        }

        // ---- VFS interface (v3) ----
        case RETRO_ENVIRONMENT_GET_VFS_INTERFACE: {
            struct retro_vfs_interface_info *vfsInfo = (struct retro_vfs_interface_info *)data;
            if (!vfsInfo) return false;
            if (vfsInfo->required_interface_version > PV_THIN_VFS_INTERFACE_VERSION) {
                WLOG(@"ThinEnv GET_VFS_INTERFACE: core requires v%u, we support v%d",
                     vfsInfo->required_interface_version, PV_THIN_VFS_INTERFACE_VERSION);
                return false;
            }
            vfsInfo->required_interface_version = PV_THIN_VFS_INTERFACE_VERSION;
            vfsInfo->iface = &s_thinVFSInterface;
            ILOG(@"ThinEnv GET_VFS_INTERFACE: provided v%d", PV_THIN_VFS_INTERFACE_VERSION);
            return true;
        }

        // ---- Software framebuffer ----
        // Returning false forces cores to use their own buffer and pass it via
        // video_refresh, where we memcpy into _videoBufferData. Sharing our
        // buffer here is unsafe: some cores (Mednafen) cache the pointer in an
        // internal surface and free() it in retro_deinit, causing a double-free
        // crash since the pointer was allocated by the frontend, not the core.
        case RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER: {
            return false;
        }

        // ---- MIDI interface (CoreMIDI) ----
        case RETRO_ENVIRONMENT_GET_MIDI_INTERFACE: {
            struct retro_midi_interface **midiPtr = (struct retro_midi_interface **)data;
            if (!midiPtr) return false;
            struct retro_midi_interface *iface = pv_libretro_midi_interface();
            if (!iface) {
                DLOG(@"ThinEnv GET_MIDI_INTERFACE — CoreMIDI interface unavailable");
                return false;
            }
            *midiPtr = iface;
            ILOG(@"ThinEnv GET_MIDI_INTERFACE: provided CoreMIDI-backed interface");
            return true;
        }

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
        case RETRO_ENVIRONMENT_GET_THROTTLE_STATE: {
            struct retro_throttle_state *throttle = (struct retro_throttle_state *)data;
            if (!throttle) return false;
            float fps = (_rawAVInfo.timing.fps > 0.0) ? (float)_rawAVInfo.timing.fps : 60.0f;
            if (_speedMultiplier > 1.5) {
                throttle->mode = RETRO_THROTTLE_FAST_FORWARD;
                throttle->rate = fps * (float)_speedMultiplier;
            } else if (_speedMultiplier < 0.5) {
                throttle->mode = RETRO_THROTTLE_SLOW_MOTION;
                throttle->rate = fps * (float)_speedMultiplier;
            } else {
                throttle->mode = RETRO_THROTTLE_UNBLOCKED;
                throttle->rate = fps;
            }
            return true;
        }

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
            // Vulkan cores call this after context_reset to get the Vulkan interface.
#if HAVE_VULKAN
            if (_hwRenderCallback.context_type == RETRO_HW_CONTEXT_VULKAN && data) {
                const struct retro_hw_render_interface **iface =
                    (const struct retro_hw_render_interface **)data;
                [self refreshVulkanRenderInterface];
                if (_vulkanRenderInterface.interface_version != RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION) {
                    ELOG(@"ThinEnv GET_HW_RENDER_INTERFACE — Vulkan interface not ready");
                    *iface = NULL;
                    return false;
                }
                *iface = (const struct retro_hw_render_interface *)&_vulkanRenderInterface;
                ILOG(@"ThinEnv GET_HW_RENDER_INTERFACE — returning Vulkan interface");
                return true;
            }
#endif
            DLOG(@"ThinEnv GET_HW_RENDER_INTERFACE — not available for context type %d",
                 (int)_hwRenderCallback.context_type);
            return false;
        }
        case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE: {
            // Cores use this to pass a context-negotiation interface *before* context_reset.
            // We accept and log it; the interface is not actively driven because Provenance
            // creates the context itself (EAGLContext / MoltenVK).  Returning true signals to
            // the core that the interface was received; returning false would make cores like
            // Beetle PSX HW fall back to a software path or refuse to run.
            const struct retro_hw_render_context_negotiation_interface *iface =
                (const struct retro_hw_render_context_negotiation_interface *)data;
            if (iface) {
                ILOG(@"ThinEnv SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE type=%u version=%u",
                     (unsigned)iface->interface_type, iface->interface_version);
            } else {
                DLOG(@"ThinEnv SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE (null — core clearing interface)");
            }
            return true;
        }
        case RETRO_ENVIRONMENT_GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT: {
            // Core queries which negotiation interface versions the frontend supports.
            // We fill in interface_version = 0 (version 0 = "I know of this interface but
            // don't drive it"; the core must still work with a frontend-created context).
            struct retro_hw_render_context_negotiation_interface *iface =
                (struct retro_hw_render_context_negotiation_interface *)data;
            if (iface) {
                ILOG(@"ThinEnv GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT type=%u — reporting version 0",
                     (unsigned)iface->interface_type);
                iface->interface_version = 0;
            }
            return true;
        }
        case RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT:
            DLOG(@"ThinEnv SET_HW_SHARED_CONTEXT");
#if HAVE_VULKAN
            _hwSharedContext = YES;
            return true;
#else
            return false;
#endif

        // ---- Preferred HW render ----
        case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER: {
#if HAVE_VULKAN
            // Prefer Vulkan when MoltenVK support is compiled in.
            // Cores that can use either path will pick Vulkan first; cores that only support
            // GLES will ignore this and call SET_HW_RENDER with a GLES context type instead.
            if (data) *(unsigned *)data = RETRO_HW_CONTEXT_VULKAN;
#else
            if (data) *(unsigned *)data = RETRO_HW_CONTEXT_OPENGLES3;
#endif
            return true;
        }

        // ---- Savestate context (env 72 | EXPERIMENTAL) ----
        case RETRO_ENVIRONMENT_GET_SAVESTATE_CONTEXT: {
            // Tell the core we're doing normal (non-runahead, non-rollback) saves.
            enum retro_savestate_context *ctx = (enum retro_savestate_context *)data;
            if (ctx) *ctx = RETRO_SAVESTATE_CONTEXT_NORMAL;
            return true;
        }

        // ---- JIT capability (env 74) ----
        case RETRO_ENVIRONMENT_GET_JIT_CAPABLE: {
            // Query the JIT manager for the real runtime acquisition state.
            // Falls back to false if JIT has not been acquired (e.g. no debugger,
            // no TrollStore, no iOS-26+ entitlement).
            bool capable = pvjit_acquired();
            if (data) *(bool *)data = capable;
            DLOG(@"ThinEnv GET_JIT_CAPABLE: %@", capable ? @"true" : @"false");
            return true;
        }

        // ---- Device power state (env 77 | EXPERIMENTAL) ----
        case RETRO_ENVIRONMENT_GET_DEVICE_POWER: {
            // Return true even for NULL data — cores use a NULL probe to check support.
            struct retro_device_power *pwr = (struct retro_device_power *)data;
            if (!pwr) return true;
            // Exclude tvOS explicitly: TARGET_OS_IOS is 0 on tvOS in modern SDKs,
            // but the extra guard makes platform intent unambiguous.
#if (TARGET_OS_IOS && !TARGET_OS_TV) || TARGET_OS_MACCATALYST
            UIDevice *dev = UIDevice.currentDevice;
            // batteryMonitoringEnabled is enabled once at init; no need to re-enable here.
            float level = dev.batteryLevel; // 0..1, or -1 if unknown
            UIDeviceBatteryState state = dev.batteryState;
            pwr->percent = (level >= 0.0f) ? (int8_t)(level * 100.0f) : -1;
            pwr->seconds = RETRO_POWERSTATE_NO_ESTIMATE;
            switch (state) {
                case UIDeviceBatteryStateCharging:
                    pwr->state = RETRO_POWERSTATE_CHARGING; break;
                case UIDeviceBatteryStateFull:
                    pwr->state = RETRO_POWERSTATE_CHARGED; break;
                case UIDeviceBatteryStateUnplugged:
                    pwr->state = RETRO_POWERSTATE_DISCHARGING; break;
                default:
                    pwr->state = RETRO_POWERSTATE_UNKNOWN; break;
            }
#else
            // tvOS has no battery API — report plugged-in with unknown percentage.
            pwr->state   = RETRO_POWERSTATE_PLUGGED_IN;
            pwr->percent = -1;
            pwr->seconds = RETRO_POWERSTATE_NO_ESTIMATE;
#endif
            return true;
        }

        // ---- Netpacket interface (env 78) ----
        // Network multiplayer via custom packet routing — not supported.
        case RETRO_ENVIRONMENT_SET_NETPACKET_INTERFACE:
            DLOG(@"ThinEnv SET_NETPACKET_INTERFACE: not supported");
            return false;

        default:
            DLOG(@"ThinEnv UNSUPPORTED cmd=%u", cmd);
            return false;
    }
}

// ---------------------------------------------------------------------------
// MARK: - Hardware rendering setup (GLES3 / IOSurface)
// ---------------------------------------------------------------------------

- (BOOL)setupHardwareRenderCallback:(struct retro_hw_render_callback *)hwCb {
#if HAVE_VULKAN
    if (hwCb->context_type == RETRO_HW_CONTEXT_VULKAN) {
        ILOG(@"ThinFrontend: core requesting Vulkan HW context");

        _hwRenderCallback = *hwCb;
        _hwRenderRequested = YES;

        // Install our proc address resolver (framebuffer is N/A for Vulkan)
        _hwRenderCallback.get_current_framebuffer = NULL;
        _hwRenderCallback.get_proc_address = thin_hw_get_proc_address;
        *hwCb = _hwRenderCallback;

        // Set up Vulkan context via MoltenVK
        if (![self setupVulkanContext]) {
            ELOG(@"ThinFrontend: Vulkan context setup failed");
            _hwRenderRequested = NO;
            memset(&_hwRenderCallback, 0, sizeof(_hwRenderCallback));
            return false;
        }

        // Fire context_reset immediately for Vulkan (no FBO setup needed)
        if (_hwRenderCallback.context_reset) {
            ILOG(@"ThinFrontend: firing Vulkan context_reset");
            _hwRenderCallback.context_reset();
        }

        return YES;
    }
#endif

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

    // --- Step 1: obtain (or create) the shared IOSurface ---
    //
    // Preferred path: ask the render delegate (PVMetalViewController) to create
    // the IOSurface-backed Metal texture via startRenderingOnAlternateThread.
    // That gives us a zero-copy path: the core renders into the IOSurface via GL,
    // and the Metal presenter reads the same IOSurface without any CPU blit.
    //
    // If the render delegate doesn't support this protocol we fall back to
    // creating a private IOSurface (display won't work until the delegate is
    // upgraded, but at least context_reset fires and the core runs).
    IOSurfaceRef delegateSurface = NULL;

    id renderDelegate = self.renderDelegate;
    if (!_renderDelegateStarted
        && [renderDelegate respondsToSelector:@selector(startRenderingOnAlternateThread)]) {
        // startRenderingOnAlternateThread may set a different GL context current.
        // Save/restore so we keep _glContext active on the emulation thread.
        EAGLContext *savedContext = [EAGLContext currentContext];
        [renderDelegate startRenderingOnAlternateThread];
        [EAGLContext setCurrentContext:savedContext];
        ILOG(@"ThinFrontend: called startRenderingOnAlternateThread on render delegate");
    }

    if ([renderDelegate conformsToProtocol:@protocol(PVRenderDelegateIOSurface)]) {
        id<PVRenderDelegateIOSurface> ioDelegate = (id<PVRenderDelegateIOSurface>)renderDelegate;
        if ([(NSObject *)ioDelegate respondsToSelector:@selector(renderIOSurface)]) {
            delegateSurface = [ioDelegate renderIOSurface];
        }
    }

    // Only mark the delegate as started once we have confirmed it produced a
    // usable IOSurface. This allows a retry on the next context_reset if the
    // delegate's GL context was not ready yet (renderIOSurface == NULL).
    if (!_renderDelegateStarted && delegateSurface) {
        _renderDelegateStarted = YES;
    }

    // --- Step 2: set up the emu-thread GL context ---
    [EAGLContext setCurrentContext:_glContext];

    // Release any previously-allocated GL objects and IOSurface before recreating
    // (handles resize / repeated setup calls without leaking resources).
    if (_emuFBO) { glDeleteFramebuffers(1, &_emuFBO); _emuFBO = 0; }
    if (_emuColorTex) { glDeleteTextures(1, &_emuColorTex); _emuColorTex = 0; }
    if (_emuDepthRB) { glDeleteRenderbuffers(1, &_emuDepthRB); _emuDepthRB = 0; }
    if (_ioSurface) { CFRelease(_ioSurface); _ioSurface = NULL; }

    // --- Step 3: get (or create) the IOSurface ---
    if (delegateSurface) {
        // Validate that the delegate's IOSurface matches the requested dimensions
        // before binding it. A size mismatch would cause undefined behaviour in
        // texImageIOSurface (the GL driver reads w×h pixels from an IOSurface of
        // a different size).
        size_t dsW = IOSurfaceGetWidth(delegateSurface);
        size_t dsH = IOSurfaceGetHeight(delegateSurface);
        if (dsW == w && dsH == h) {
            // Zero-copy path: reuse the render delegate's IOSurface so the
            // Metal presenter can display our rendered frames without a copy.
            _ioSurface = delegateSurface;
            CFRetain(_ioSurface);
            ILOG(@"ThinFrontend: using render delegate IOSurface (%zux%zu)", dsW, dsH);
        } else {
            WLOG(@"ThinFrontend: delegate IOSurface size %zux%zu != requested %ux%u — falling back to private surface",
                 dsW, dsH, w, h);
        }
    }
    if (!_ioSurface) {
        // Fallback: create a private IOSurface.
        // Omit kIOSurfacePixelFormat to match the approach used by
        // PVMetalViewController and PVLibRetroGLESCore (bound as GL_RGBA),
        // avoiding channel-swapped output from a format mismatch.
        // Frames will render correctly but won't reach the display until
        // the render delegate is updated to expose an IOSurface.
        NSDictionary *props = @{
            (id)kIOSurfaceWidth:             @(w),
            (id)kIOSurfaceHeight:            @(h),
            (id)kIOSurfaceBytesPerElement:   @4,
        };
        _ioSurface = IOSurfaceCreate((CFDictionaryRef)props);
        WLOG(@"ThinFrontend: render delegate has no IOSurface — created private surface (frames won't display)");
    }
    if (!_ioSurface) {
        ELOG(@"ThinFrontend: IOSurface unavailable — aborting FBO setup");
        return;
    }

    // Create FBO + color texture bound to the IOSurface
    glGenFramebuffers(1, &_emuFBO);
    glGenTextures(1, &_emuColorTex);

    glBindTexture(GL_TEXTURE_2D, _emuColorTex);
    // Use GL_RGBA for both internalFormat and format to match the IOSurface
    // created without an explicit kIOSurfacePixelFormat (same as PVMetalViewController
    // and PVLibRetroGLESCore). Using GL_BGRA_EXT here while omitting the pixel format
    // from the IOSurface would cause channel-swapped output.
    [_glContext texImageIOSurface:_ioSurface
                           target:GL_TEXTURE_2D
                   internalFormat:GL_RGBA
                            width:w
                           height:h
                           format:GL_RGBA
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
    _fboWidth  = w;
    _fboHeight = h;
    _hwFBONeedsRebuild = NO;

    // Fire context_reset now that the FBO is ready
    if (_hwRenderCallback.context_reset) {
        _hwRenderCallback.context_reset();
    }
#endif
}

// ---------------------------------------------------------------------------
// MARK: - Vulkan / MoltenVK support
// ---------------------------------------------------------------------------

#if HAVE_VULKAN

- (BOOL)setupVulkanContext {
    ILOG(@"ThinFrontend: setting up Vulkan context via MoltenVK");

    if (![self loadMoltenVKLibrary]) {
        ELOG(@"ThinFrontend: failed to load MoltenVK library");
        return NO;
    }

    if (![self loadVulkanFunctions]) {
        ELOG(@"ThinFrontend: failed to load Vulkan functions");
        [self unloadMoltenVKLibrary];
        return NO;
    }

    if (![self createVulkanInstance]) {
        ELOG(@"ThinFrontend: failed to create Vulkan instance");
        [self unloadMoltenVKLibrary];
        return NO;
    }

    if (![self selectVulkanPhysicalDevice]) {
        ELOG(@"ThinFrontend: failed to select Vulkan physical device");
        [self destroyVulkanInstance];
        [self unloadMoltenVKLibrary];
        return NO;
    }

    if (![self createVulkanDevice]) {
        ELOG(@"ThinFrontend: failed to create Vulkan device");
        [self destroyVulkanInstance];
        [self unloadMoltenVKLibrary];
        return NO;
    }

    [self getVulkanDeviceQueue];
    [self refreshVulkanRenderInterface];

    ILOG(@"ThinFrontend: Vulkan hardware context created successfully via MoltenVK");
    return YES;
}

- (void)destroyVulkanContext {
    [self destroyVulkanDevice];
    [self destroyVulkanInstance];
    [self unloadMoltenVKLibrary];
    [self resetVulkanRenderInterface];
}

- (BOOL)loadMoltenVKLibrary {
    // First try RTLD_DEFAULT — if MoltenVK is already linked into the process
    // (e.g., as a dynamic framework in the app bundle), vkGetInstanceProcAddr
    // will be available without an explicit dlopen.
    {
        void *sym = dlsym(RTLD_DEFAULT, "vkGetInstanceProcAddr");
        if (sym) {
            // Use sentinel handle: NULL means "use RTLD_DEFAULT for all dlsym calls"
            _vulkanLibrary = RTLD_DEFAULT;
            ILOG(@"ThinFrontend: MoltenVK symbols already available via RTLD_DEFAULT");
            return YES;
        }
    }

    // Build a list of candidate paths.  On iOS/tvOS the framework lives inside
    // the app bundle's Frameworks/ directory, accessible via @rpath.
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSString *frameworksPath = [mainBundle.privateFrameworksPath
                                stringByAppendingPathComponent:@"MoltenVK.framework/MoltenVK"];
    NSString *bundleFrameworksPath = [[mainBundle bundlePath]
                                      stringByAppendingPathComponent:@"Frameworks/MoltenVK.framework/MoltenVK"];

    const char *hardcodedPaths[] = {
        // rpath-resolved — works when the app has Frameworks/ in LD_RUNPATH_SEARCH_PATHS
        "@rpath/MoltenVK.framework/MoltenVK",
        "MoltenVK.framework/MoltenVK",
        "MoltenVK",
        "../Contents/MoltenVK.framework/MoltenVK",
        "/System/Library/Frameworks/MoltenVK.framework/MoltenVK",
        "/usr/local/lib/libMoltenVK.dylib",
        NULL
    };

    // Try bundle-derived paths first (absolute, most reliable on iOS/tvOS)
    NSMutableArray<NSString *> *bundlePaths = [NSMutableArray array];
    if (frameworksPath) {
        [bundlePaths addObject:frameworksPath];
    }
    if (bundleFrameworksPath) {
        [bundlePaths addObject:bundleFrameworksPath];
    }
    for (NSString *p in bundlePaths) {
        if (!p) continue;
        _vulkanLibrary = dlopen(p.UTF8String, RTLD_LOCAL | RTLD_LAZY);
        if (_vulkanLibrary) {
            ILOG(@"ThinFrontend: MoltenVK loaded from bundle path: %@", p);
            return YES;
        }
        DLOG(@"ThinFrontend: failed to load MoltenVK from %@ (%s)", p, dlerror());
    }

    for (int i = 0; hardcodedPaths[i] != NULL; i++) {
        _vulkanLibrary = dlopen(hardcodedPaths[i], RTLD_LOCAL | RTLD_LAZY);
        if (_vulkanLibrary) {
            ILOG(@"ThinFrontend: MoltenVK loaded from: %s", hardcodedPaths[i]);
            return YES;
        }
        DLOG(@"ThinFrontend: failed to load MoltenVK from: %s (%s)", hardcodedPaths[i], dlerror());
    }

    ELOG(@"ThinFrontend: failed to load MoltenVK from any known path");
    return NO;
}

- (void)unloadMoltenVKLibrary {
    if (_vulkanLibrary && _vulkanLibrary != RTLD_DEFAULT) {
        dlclose(_vulkanLibrary);
        _vulkanLibrary = NULL;
        ILOG(@"ThinFrontend: MoltenVK library unloaded");
    } else if (_vulkanLibrary == RTLD_DEFAULT) {
        _vulkanLibrary = NULL;
        ILOG(@"ThinFrontend: MoltenVK (RTLD_DEFAULT) reference released");
    }
}

- (BOOL)loadVulkanFunctions {
    if (!_vulkanLibrary) {
        ELOG(@"ThinFrontend: cannot load Vulkan functions — MoltenVK not loaded");
        return NO;
    }

    // When _vulkanLibrary == RTLD_DEFAULT the symbols are already in the
    // process image; use RTLD_DEFAULT directly for the initial dlsym lookup.
    void *libHandle = (_vulkanLibrary == RTLD_DEFAULT) ? RTLD_DEFAULT : _vulkanLibrary;
    _vkGetInstanceProcAddr = (PFN_vkVoidFunction (*)(VkInstance, const char *))dlsym(libHandle, "vkGetInstanceProcAddr");
    if (!_vkGetInstanceProcAddr) {
        ELOG(@"ThinFrontend: failed to load vkGetInstanceProcAddr");
        return NO;
    }

    _vkCreateInstance = (VkResult (*)(const void *, const void *, VkInstance *))
        _vkGetInstanceProcAddr(NULL, "vkCreateInstance");
    if (!_vkCreateInstance) {
        ELOG(@"ThinFrontend: failed to load vkCreateInstance");
        return NO;
    }

    ILOG(@"ThinFrontend: essential Vulkan functions loaded");
    return YES;
}

- (BOOL)createVulkanInstance {
    struct {
        int sType;           // VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
        const void *pNext;
        const char *pApplicationName;
        uint32_t applicationVersion;
        const char *pEngineName;
        uint32_t engineVersion;
        uint32_t apiVersion;
    } appInfo = {
        .sType = 0,
        .pNext = NULL,
        .pApplicationName = "PVThinFrontend",
        .applicationVersion = 1,
        .pEngineName = "PVThinFrontend",
        .engineVersion = 1,
        .apiVersion = 0x00400000 // VK_API_VERSION_1_0
    };

    struct {
        int sType;           // VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
        const void *pNext;
        uint32_t flags;
        const void *pApplicationInfo;
        uint32_t enabledLayerCount;
        const char *const *ppEnabledLayerNames;
        uint32_t enabledExtensionCount;
        const char *const *ppEnabledExtensionNames;
    } createInfo = {
        .sType = 1,
        .pNext = NULL,
        .flags = 0,
        .pApplicationInfo = &appInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = NULL,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = NULL
    };

    VkResult result = _vkCreateInstance(&createInfo, NULL, &_vulkanInstance);
    if (result != 0) { // VK_SUCCESS = 0
        ELOG(@"ThinFrontend: vkCreateInstance failed (result=%d)", result);
        return NO;
    }

    // Load instance-specific functions
    _vkDestroyInstance = (void (*)(VkInstance, const void *))
        _vkGetInstanceProcAddr(_vulkanInstance, "vkDestroyInstance");
    _vkEnumeratePhysicalDevices = (VkResult (*)(VkInstance, uint32_t *, VkPhysicalDevice *))
        _vkGetInstanceProcAddr(_vulkanInstance, "vkEnumeratePhysicalDevices");
    _vkCreateDevice = (VkResult (*)(VkPhysicalDevice, const void *, const void *, VkDevice *))
        _vkGetInstanceProcAddr(_vulkanInstance, "vkCreateDevice");

    if (!_vkDestroyInstance || !_vkEnumeratePhysicalDevices || !_vkCreateDevice) {
        ELOG(@"ThinFrontend: failed to load instance-level Vulkan functions");
        return NO;
    }

    ILOG(@"ThinFrontend: Vulkan instance created");
    return YES;
}

- (void)destroyVulkanInstance {
    if (_vulkanInstance && _vkDestroyInstance) {
        _vkDestroyInstance(_vulkanInstance, NULL);
        _vulkanInstance = NULL;
        ILOG(@"ThinFrontend: Vulkan instance destroyed");
    }
}

- (BOOL)selectVulkanPhysicalDevice {
    if (!_vulkanInstance || !_vkEnumeratePhysicalDevices) {
        ELOG(@"ThinFrontend: cannot select physical device — no instance");
        return NO;
    }

    uint32_t deviceCount = 0;
    VkResult result = _vkEnumeratePhysicalDevices(_vulkanInstance, &deviceCount, NULL);
    if (result != 0 || deviceCount == 0) {
        ELOG(@"ThinFrontend: no Vulkan physical devices (result=%d, count=%u)", result, deviceCount);
        return NO;
    }

    VkPhysicalDevice devices[1];
    uint32_t requestCount = 1;
    result = _vkEnumeratePhysicalDevices(_vulkanInstance, &requestCount, devices);
    if (result != 0 || requestCount == 0) {
        ELOG(@"ThinFrontend: failed to get physical device (result=%d)", result);
        return NO;
    }

    _vulkanPhysicalDevice = devices[0];
    ILOG(@"ThinFrontend: Vulkan physical device selected");
    return YES;
}

- (BOOL)createVulkanDevice {
    if (!_vulkanPhysicalDevice || !_vkCreateDevice) {
        ELOG(@"ThinFrontend: cannot create device — no physical device");
        return NO;
    }

    float queuePriority = 1.0f;
    struct {
        int sType;           // VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
        const void *pNext;
        uint32_t flags;
        uint32_t queueFamilyIndex;
        uint32_t queueCount;
        const float *pQueuePriorities;
    } queueCreateInfo = {
        .sType = 2,
        .pNext = NULL,
        .flags = 0,
        .queueFamilyIndex = 0,
        .queueCount = 1,
        .pQueuePriorities = &queuePriority
    };

    // Check for VK_EXT_metal_objects support before creating the device.
    static const char *kExtMetalObjects = "VK_EXT_metal_objects";
    BOOL extMetalObjectsAvailable = NO;
    // Load vkEnumerateDeviceExtensionProperties via the instance proc addr (device not yet created)
    PFN_vkEnumerateDeviceExtensionProperties vkEnumDevExts =
        (PFN_vkEnumerateDeviceExtensionProperties)
        _vkGetInstanceProcAddr(_vulkanInstance, "vkEnumerateDeviceExtensionProperties");
    if (vkEnumDevExts) {
        uint32_t extCount = 0;
        if (vkEnumDevExts(_vulkanPhysicalDevice, NULL, &extCount, NULL) == VK_SUCCESS && extCount > 0) {
            VkExtensionProperties *exts = (VkExtensionProperties *)malloc(extCount * sizeof(VkExtensionProperties));
            if (exts) {
                if (vkEnumDevExts(_vulkanPhysicalDevice, NULL, &extCount, exts) == VK_SUCCESS) {
                    for (uint32_t i = 0; i < extCount; i++) {
                        if (strcmp(exts[i].extensionName, kExtMetalObjects) == 0) {
                            extMetalObjectsAvailable = YES;
                            break;
                        }
                    }
                }
                free(exts);
            }
        }
    }

    const char *enabledExtensions[1];
    uint32_t enabledExtensionCount = 0;
    if (extMetalObjectsAvailable) {
        enabledExtensions[enabledExtensionCount++] = kExtMetalObjects;
    }

    struct {
        int sType;           // VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
        const void *pNext;
        uint32_t flags;
        uint32_t queueCreateInfoCount;
        const void *pQueueCreateInfos;
        uint32_t enabledLayerCount;
        const char *const *ppEnabledLayerNames;
        uint32_t enabledExtensionCount;
        const char *const *ppEnabledExtensionNames;
        const void *pEnabledFeatures;
    } createInfo = {
        .sType = 3,
        .pNext = NULL,
        .flags = 0,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queueCreateInfo,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = NULL,
        .enabledExtensionCount = enabledExtensionCount,
        .ppEnabledExtensionNames = enabledExtensionCount > 0 ? enabledExtensions : NULL,
        .pEnabledFeatures = NULL
    };

    VkResult result = _vkCreateDevice(_vulkanPhysicalDevice, &createInfo, NULL, &_vulkanDevice);
    if (result != 0) {
        ELOG(@"ThinFrontend: vkCreateDevice failed (result=%d)", result);
        return NO;
    }

    _vulkanExtMetalObjectsEnabled = extMetalObjectsAvailable;
    if (extMetalObjectsAvailable) {
        ILOG(@"ThinFrontend: VK_EXT_metal_objects enabled at device creation");
    }

    // Load device-specific functions
    _vkGetDeviceProcAddr = (PFN_vkVoidFunction (*)(VkDevice, const char *))
        _vkGetInstanceProcAddr(_vulkanInstance, "vkGetDeviceProcAddr");
    _vkDestroyDevice = (void (*)(VkDevice, const void *))
        _vkGetDeviceProcAddr(_vulkanDevice, "vkDestroyDevice");
    _vkGetDeviceQueue = (void (*)(VkDevice, uint32_t, uint32_t, VkQueue *))
        _vkGetDeviceProcAddr(_vulkanDevice, "vkGetDeviceQueue");

    if (!_vkGetDeviceProcAddr || !_vkDestroyDevice || !_vkGetDeviceQueue) {
        ELOG(@"ThinFrontend: failed to load device-level Vulkan functions");
        return NO;
    }

    // Load command submission functions
    _vkQueueSubmit = (PFN_vkQueueSubmit)
        _vkGetDeviceProcAddr(_vulkanDevice, "vkQueueSubmit");
    _vkQueueWaitIdle = (VkResult (*)(VkQueue))
        _vkGetDeviceProcAddr(_vulkanDevice, "vkQueueWaitIdle");
    _vkEnumerateDeviceExtensionProperties = (PFN_vkEnumerateDeviceExtensionProperties)
        _vkGetInstanceProcAddr(_vulkanInstance, "vkEnumerateDeviceExtensionProperties");

    if (!_vkQueueSubmit || !_vkQueueWaitIdle) {
        ELOG(@"ThinFrontend: failed to load vkQueueSubmit / vkQueueWaitIdle");
        return NO;
    }

    // Load fence functions for double-buffer synchronisation (non-fatal if unavailable;
    // the code falls back to vkQueueWaitIdle when any fence function is missing).
    _vkCreateFence  = (PFN_vkCreateFence) _vkGetDeviceProcAddr(_vulkanDevice, "vkCreateFence");
    _vkDestroyFence = (PFN_vkDestroyFence)_vkGetDeviceProcAddr(_vulkanDevice, "vkDestroyFence");
    _vkWaitForFences = (PFN_vkWaitForFences)_vkGetDeviceProcAddr(_vulkanDevice, "vkWaitForFences");
    _vkResetFences  = (PFN_vkResetFences) _vkGetDeviceProcAddr(_vulkanDevice, "vkResetFences");

    if (_vkCreateFence && _vkDestroyFence && _vkWaitForFences && _vkResetFences) {
        // Pre-signaled so the very first thin_vulkan_wait_sync_index returns immediately.
        VkFenceCreateInfo fenceCI = {
            .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .pNext = NULL,
            .flags = VK_FENCE_CREATE_SIGNALED_BIT,
        };
        _vulkanFrameIndex = 0;
        BOOL fencesOK = YES;
        for (int i = 0; i < 2; i++) {
            VkResult fr = _vkCreateFence(_vulkanDevice, &fenceCI, NULL, &_vulkanFrameFences[i]);
            if (fr != VK_SUCCESS) {
                WLOG(@"ThinFrontend: vkCreateFence[%d] failed (result=%d) — will use vkQueueWaitIdle", i, fr);
                _vulkanFrameFences[i] = VK_NULL_HANDLE;
                fencesOK = NO;
                break;
            }
        }
        if (fencesOK) {
            ILOG(@"ThinFrontend: double-buffer frame fences created");
        } else {
            // Destroy any partially-created fences
            for (int i = 0; i < 2; i++) {
                if (_vulkanFrameFences[i]) {
                    _vkDestroyFence(_vulkanDevice, _vulkanFrameFences[i], NULL);
                    _vulkanFrameFences[i] = VK_NULL_HANDLE;
                }
            }
        }
    } else {
        WLOG(@"ThinFrontend: fence functions unavailable — falling back to vkQueueWaitIdle");
        _vulkanFrameFences[0] = VK_NULL_HANDLE;
        _vulkanFrameFences[1] = VK_NULL_HANDLE;
    }

    // Load Metal interop functions (MoltenVK-specific; non-fatal if unavailable)
    // Primary: VK_EXT_metal_objects (MoltenVK >= 1.2)
    _vkExportMetalObjectsEXT = (VkResult (*)(VkDevice, void *))
        _vkGetDeviceProcAddr(_vulkanDevice, "vkExportMetalObjectsEXT");
    if (!_vkExportMetalObjectsEXT) {
        _vkExportMetalObjectsEXT = (VkResult (*)(VkDevice, void *))
            _vkGetInstanceProcAddr(_vulkanInstance, "vkExportMetalObjectsEXT");
    }

    // Fallback: deprecated MVK extension (vkGetMTLTextureMVK), available in all MoltenVK versions
    _vkGetMTLTextureMVK = (void (*)(VkImage, void **))
        _vkGetInstanceProcAddr(_vulkanInstance, "vkGetMTLTextureMVK");
    if (!_vkGetMTLTextureMVK) {
        _vkGetMTLTextureMVK = (void (*)(VkImage, void **))
            _vkGetDeviceProcAddr(_vulkanDevice, "vkGetMTLTextureMVK");
    }

    if (_vkExportMetalObjectsEXT) {
        ILOG(@"ThinFrontend: Vulkan Metal interop via VK_EXT_metal_objects");
    } else if (_vkGetMTLTextureMVK) {
        ILOG(@"ThinFrontend: Vulkan Metal interop via vkGetMTLTextureMVK (MVK deprecated)");
    } else {
        WLOG(@"ThinFrontend: no Vulkan→Metal interop available; frames won't display");
    }

    ILOG(@"ThinFrontend: Vulkan device created");
    return YES;
}

- (void)destroyVulkanDevice {
    if (_vulkanDevice && _vkDestroyDevice) {
        // Drain the queue before tearing down fences to ensure no fence is still in-flight.
        if (_vkQueueWaitIdle && _vulkanQueue) {
            _vkQueueWaitIdle(_vulkanQueue);
        }
        // Destroy double-buffer frame fences.
        if (_vkDestroyFence) {
            for (int i = 0; i < 2; i++) {
                if (_vulkanFrameFences[i]) {
                    _vkDestroyFence(_vulkanDevice, _vulkanFrameFences[i], NULL);
                    _vulkanFrameFences[i] = VK_NULL_HANDLE;
                }
            }
        }
        _vulkanFrameIndex = 0;
        _vkCreateFence  = NULL;
        _vkDestroyFence = NULL;
        _vkWaitForFences = NULL;
        _vkResetFences  = NULL;
        _vkDestroyDevice(_vulkanDevice, NULL);
        _vulkanDevice = NULL;
        _vulkanQueue = NULL;
        ILOG(@"ThinFrontend: Vulkan device destroyed");
    }
}

- (void)getVulkanDeviceQueue {
    if (_vulkanDevice && _vkGetDeviceQueue) {
        _vkGetDeviceQueue(_vulkanDevice, 0, 0, &_vulkanQueue);
        ILOG(@"ThinFrontend: Vulkan device queue obtained");
    }
}

- (void)resetVulkanRenderInterface {
    memset(&_vulkanRenderInterface, 0, sizeof(_vulkanRenderInterface));
}

- (void)refreshVulkanRenderInterface {
    [self resetVulkanRenderInterface];

    if (!_vulkanInstance || !_vulkanDevice || !_vulkanQueue ||
        !_vkGetInstanceProcAddr || !_vkGetDeviceProcAddr) {
        return;
    }

    _vulkanRenderInterface.interface_type = RETRO_HW_RENDER_INTERFACE_VULKAN;
    _vulkanRenderInterface.interface_version = RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION;
    _vulkanRenderInterface.handle = (__bridge void *)self;
    _vulkanRenderInterface.instance = _vulkanInstance;
    _vulkanRenderInterface.gpu = _vulkanPhysicalDevice;
    _vulkanRenderInterface.device = _vulkanDevice;
    _vulkanRenderInterface.get_device_proc_addr = (PFN_vkGetDeviceProcAddr)_vkGetDeviceProcAddr;
    _vulkanRenderInterface.get_instance_proc_addr = (PFN_vkGetInstanceProcAddr)_vkGetInstanceProcAddr;
    _vulkanRenderInterface.queue = _vulkanQueue;
    _vulkanRenderInterface.queue_index = 0;
    _vulkanRenderInterface.set_image = thin_vulkan_set_image;
    _vulkanRenderInterface.get_sync_index = thin_vulkan_get_sync_index;
    _vulkanRenderInterface.get_sync_index_mask = thin_vulkan_get_sync_index_mask;
    _vulkanRenderInterface.set_command_buffers = thin_vulkan_set_command_buffers;
    _vulkanRenderInterface.wait_sync_index = thin_vulkan_wait_sync_index;
    _vulkanRenderInterface.lock_queue = thin_vulkan_lock_queue;
    _vulkanRenderInterface.unlock_queue = thin_vulkan_unlock_queue;
    _vulkanRenderInterface.set_signal_semaphore = thin_vulkan_set_signal_semaphore;
}

// ---------------------------------------------------------------------------
// MARK: - Vulkan command submission
// ---------------------------------------------------------------------------

- (void)submitVulkanCommandBuffers:(const VkCommandBuffer *)cmdBufs count:(uint32_t)count {
    if (!_vkQueueSubmit || !_vulkanQueue || !cmdBufs || count == 0) return;

    // Per libretro_vulkan.h: when set_command_buffers is used, semaphores provided via
    // set_image MUST be ignored — the spec explicitly says they are not consumed in this
    // mode. Using them risks a deadlock if the core never signals them in cmd-buf mode.
    // Snapshot and clear the signal semaphore (per-frame) and discard any wait semaphores.
    os_unfair_lock_lock(&_vulkanQueueLock);
    VkSemaphore signalSem = _vulkanSignalSemaphore;
    _vulkanSignalSemaphore = VK_NULL_HANDLE;
    // Discard set_image semaphores — not valid in set_command_buffers mode.
    _vulkanWaitSemaphoreCount = 0;

    // Use the per-frame fence for this slot, resetting it right before submit so it
    // transitions SIGNALED→UNSIGNALED and will be re-signaled when the GPU finishes.
    VkFence frameFence = (_vulkanFrameFences[0] && _vkResetFences && _vkWaitForFences)
        ? _vulkanFrameFences[_vulkanFrameIndex]
        : VK_NULL_HANDLE;
    if (frameFence) {
        _vkResetFences(_vulkanDevice, 1, &frameFence);
    }

    VkSubmitInfo submitInfo = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = NULL,
        .waitSemaphoreCount = 0,    // set_image semaphores ignored per libretro_vulkan.h
        .pWaitSemaphores = NULL,
        .pWaitDstStageMask = NULL,
        .commandBufferCount = count,
        .pCommandBuffers = cmdBufs,
        .signalSemaphoreCount = (signalSem != VK_NULL_HANDLE) ? 1u : 0u,
        .pSignalSemaphores = (signalSem != VK_NULL_HANDLE) ? &signalSem : NULL,
    };

    VkResult result = _vkQueueSubmit(_vulkanQueue, 1, &submitInfo, frameFence);

    // Wait for GPU completion before extracting the MTLTexture.
    // Per-frame fence (preferred): waits only on this specific submission, leaving other
    // queue work unaffected.  Falls back to vkQueueWaitIdle when fences are unavailable.
    // The fence is left SIGNALED after the wait; wait_sync_index reads it at the start
    // of the next iteration of this slot to confirm the slot is free.
    if (result == VK_SUCCESS) {
        if (frameFence && _vkWaitForFences) {
            _vkWaitForFences(_vulkanDevice, 1, &frameFence, 1 /* VK_TRUE */, UINT64_MAX);
        } else if (_vkQueueWaitIdle) {
            _vkQueueWaitIdle(_vulkanQueue);
        }
    }

    // Advance the frame slot so the next frame uses the other buffer.
    _vulkanFrameIndex = (_vulkanFrameIndex + 1) % 2;
    os_unfair_lock_unlock(&_vulkanQueueLock);

    if (result != VK_SUCCESS) {
        ELOG(@"ThinFrontend: vkQueueSubmit failed (result=%d)", result);
        return;
    }

    // Notify the render delegate now that the GPU has finished and the VkImage is safe
    // to export. Some cores (e.g. libretro-test-vulkan) call set_image before
    // set_command_buffers, so notification is deferred until after queue submission.
    if (_vulkanHasCurrentImage) {
        _vulkanHasCurrentImage = NO;
        [self notifyRenderDelegateOfVulkanFrame:nil];
    }
}

// ---------------------------------------------------------------------------
// MARK: - Vulkan → Metal interop
// ---------------------------------------------------------------------------

/// VK_STRUCTURE_TYPE values for VK_EXT_metal_objects (spec range 1000311xxx)
#define PV_VK_STYPE_EXPORT_METAL_OBJECTS_INFO_EXT  ((VkStructureType)1000311001)
#define PV_VK_STYPE_EXPORT_METAL_TEXTURE_INFO_EXT  ((VkStructureType)1000311006)
#define PV_VK_STYPE_EXPORT_METAL_IO_SURFACE_INFO_EXT ((VkStructureType)1000311008)
#define PV_VK_IMAGE_ASPECT_COLOR_BIT 1

/// Try to get the MTLTexture backing a MoltenVK VkImage.
/// Tries vkGetMTLTextureMVK (deprecated, universal) first, then vkExportMetalObjectsEXT.
/// Returns nil if neither path works.
- (nullable id<MTLTexture>)getMTLTextureForVkImage:(VkImage)vkImage {
    if (vkImage == VK_NULL_HANDLE) return nil;

    // --- Path 1: vkGetMTLTextureMVK (deprecated MVK extension, works on all MoltenVK versions) ---
    if (_vkGetMTLTextureMVK) {
        // Use void* to avoid ARC interference: MoltenVK returns a non-owning reference
        // retained by the VkImage. Bridge-cast to a __strong local so ARC retains it.
        void *rawTexture = NULL;
        _vkGetMTLTextureMVK(vkImage, &rawTexture);
        if (rawTexture) {
            DLOG(@"ThinFrontend: Vulkan→Metal via vkGetMTLTextureMVK");
            return (__bridge id<MTLTexture>)rawTexture;
        }
    }

    // --- Path 2: vkExportMetalObjectsEXT (VK_EXT_metal_objects, MoltenVK >= 1.2) ---
    // Only valid when the extension was explicitly enabled at device creation time.
    // Uses raw structs because our bundled vulkan.h (v17) predates this extension.
    if (_vkExportMetalObjectsEXT && _vulkanDevice && _vulkanExtMetalObjectsEnabled) {
        // VkExportMetalTextureInfoEXT chained in pNext of VkExportMetalObjectsInfoEXT.
        // Use void* for the mtlTexture field to avoid ARC interference with an ObjC
        // object embedded inside a C struct — __unsafe_unretained in structs can lead
        // to use-after-free if the object is autoreleased before we return it.
        struct {
            VkStructureType  sType;
            const void      *pNext;
            VkImage          image;
            VkImageView      imageView;
            VkBufferView     bufferView;
            uint32_t         plane;     // VkImageAspectFlagBits
            void            *mtlTexturePtr;  // void* to keep ARC out of the struct
        } texInfo = {
            .sType         = PV_VK_STYPE_EXPORT_METAL_TEXTURE_INFO_EXT,
            .pNext         = NULL,
            .image         = vkImage,
            .imageView     = VK_NULL_HANDLE,
            .bufferView    = VK_NULL_HANDLE,
            .plane         = PV_VK_IMAGE_ASPECT_COLOR_BIT,
            .mtlTexturePtr = NULL,
        };
        struct {
            VkStructureType  sType;
            const void      *pNext;
        } exportInfo = {
            .sType = PV_VK_STYPE_EXPORT_METAL_OBJECTS_INFO_EXT,
            .pNext = &texInfo,
        };
        VkResult exportResult = _vkExportMetalObjectsEXT(_vulkanDevice, &exportInfo);
        if (exportResult == VK_SUCCESS && texInfo.mtlTexturePtr) {
            DLOG(@"ThinFrontend: Vulkan→Metal via vkExportMetalObjectsEXT");
            return (__bridge id<MTLTexture>)texInfo.mtlTexturePtr;
        } else if (exportResult != VK_SUCCESS) {
            WLOG(@"ThinFrontend: vkExportMetalObjectsEXT failed (result=%d)", exportResult);
        }
    }

    DLOG(@"ThinFrontend: getMTLTextureForVkImage — no interop path available");
    return nil;
}

/// Called from submitVulkanCommandBuffers (normal Vulkan path) and _thinVideoRefresh
/// (async-compute path). Extracts the MTLTexture from the VkImage and notifies the
/// render delegate so it can blit the frame to the display.
- (void)notifyRenderDelegateOfVulkanFrame:(const struct retro_vulkan_image *)image {
    (void)image; // VkImage is already stored in _vulkanCurrentVkImage
    id<MTLTexture> mtlTexture = [self getMTLTextureForVkImage:_vulkanCurrentVkImage];
    if (!mtlTexture) {
        DLOG(@"ThinFrontend: notifyRenderDelegateOfVulkanFrame — no MTLTexture");
        return;
    }

    id renderDelegate = self.renderDelegate;

    // Preferred: PVRenderDelegateMetal (direct Metal texture handoff)
    if ([renderDelegate conformsToProtocol:@protocol(PVRenderDelegateMetal)]
        && [renderDelegate respondsToSelector:@selector(didRenderFrameWithMTLTexture:)]) {
        [(id<PVRenderDelegateMetal>)renderDelegate didRenderFrameWithMTLTexture:mtlTexture];
        return;
    }

    // Fallback: try IOSurface path if the texture has IOSurface backing.
    // iosurface returns an IOSurfaceRef (a CF type), not an ObjC object — no bridge cast.
#if __has_include(<IOSurface/IOSurface.h>)
    IOSurfaceRef surface = [mtlTexture iosurface];
    if (surface && [renderDelegate conformsToProtocol:@protocol(PVRenderDelegateIOSurface)]) {
        DLOG(@"ThinFrontend: Vulkan frame via IOSurface fallback path");
        // Nothing to do — the IOSurface is shared; the Metal presenter reads it on next draw.
    }
#endif // __has_include(<IOSurface/IOSurface.h>)
}

#endif // HAVE_VULKAN

- (void)teardownHardwareContext {
    if (_hwRenderCallback.context_destroy) {
        _hwRenderCallback.context_destroy();
    }

#if HAVE_VULKAN
    if (_hwRenderCallback.context_type == RETRO_HW_CONTEXT_VULKAN) {
        [self destroyVulkanContext];
        _hwRenderRequested = NO;
        _vulkanSignalSemaphore = VK_NULL_HANDLE;
        _vulkanPendingCmdBufCount = 0;
        _vulkanHasCurrentImage = NO;
        _vulkanCurrentVkImage = VK_NULL_HANDLE;
        _vulkanWaitSemaphoreCount = 0;
        _vulkanExtMetalObjectsEnabled = NO;
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
        _renderDelegateStarted = NO;
#endif
        memset(&_hwRenderCallback, 0, sizeof(_hwRenderCallback));
        return;
    }
#endif

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
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
    _renderDelegateStarted = NO;
    _fboWidth  = 0;
    _fboHeight = 0;
    _hwFBONeedsRebuild = NO;
#endif
    _hwRenderRequested = NO;
    memset(&_hwRenderCallback, 0, sizeof(_hwRenderCallback));
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
