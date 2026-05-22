//
//  PVThinLibretroFrontend.h
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A minimal libretro frontend that:
//  - Depends on libretro.h and PVCoreBridge (ObjCBridgedCoreBridge); no RetroArch internals
//  - Loads cores via dlopen/dlsym
//  - Handles the full libretro environment callback API
//  - Provides the 5 core callbacks (video, audio, audio_batch, input_poll, input_state)
//  - Manages an IOSurface-backed GLES3 render path for hw-render cores
//
//  This class is the foundation for the "thin wrapper" approach described in
//  issues #2624 and #2639: instead of embedding a full RetroArch binary, thin
//  sub-cores can dlopen a libretro buildbot .dylib and delegate to this frontend.
//

@import Foundation;
@import PVCoreObjCBridge;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import <PVCoreBridgeRetro/libretro.h>
#import <dlfcn.h>

// ---------------------------------------------------------------------------
// MARK: - libretro Performance Interface (C functions)
// ---------------------------------------------------------------------------
// Implementations live in PVThinLibretroFrontend.mm.
// Wired into RETRO_ENVIRONMENT_GET_PERF_INTERFACE in both frontend paths.
// In DEBUG builds, perf_start/perf_stop emit os_signpost intervals visible
// in Xcode Instruments under "org.provenance-emu.PVCoreBridgeRetro / libretro-perf".

/// Returns current time in microseconds via mach_absolute_time.
retro_time_t pv_perf_get_time_usec(void);

/// Returns a raw performance tick (mach_absolute_time).
retro_perf_tick_t pv_perf_get_counter(void);

/// Returns a bitmask of detected SIMD CPU features (RETRO_SIMD_*).
uint64_t pv_perf_get_cpu_features(void);

/// Register a named performance counter for tracking.
void pv_perf_register(struct retro_perf_counter *_Nullable counter);

/// Start a registered counter (records start tick, emits signpost in debug).
void pv_perf_start(struct retro_perf_counter *_Nullable counter);

/// Stop a registered counter (accumulates elapsed ticks, emits signpost in debug).
void pv_perf_stop(struct retro_perf_counter *_Nullable counter);

/// Log all registered counters to the Provenance log.
void pv_perf_log(void);

/// Maximum number of players supported for input.
/// Matches RetroArch's DEFAULT_INPUT_MAX_USERS so GET_INPUT_MAX_USERS stays consistent.
#define THIN_MAX_PLAYERS 8

/// Maximum number of analog axes tracked (2 sticks x 2 axes = 4 per player).
#define THIN_MAX_ANALOG_AXES 4

NS_ASSUME_NONNULL_BEGIN

/// Result of calling retro_get_system_info on a loaded core.
typedef struct PVLibretroSystemInfo {
    char library_name[256];
    char library_version[256];
    char valid_extensions[512];
    bool need_fullpath;
    bool block_extract;
} PVLibretroSystemInfo;

/// Result of calling retro_get_system_av_info.
typedef struct PVLibretroAVInfo {
    unsigned base_width;
    unsigned base_height;
    unsigned max_width;
    unsigned max_height;
    double   fps;
    double   sample_rate;
    float    aspect_ratio;
} PVLibretroAVInfo;

/// Pixel format used by the core for software-rendered video frames.
typedef NS_ENUM(NSInteger, PVLibretroPixelFormat) {
    PVLibretroPixelFormatRGB1555   = 0, ///< RETRO_PIXEL_FORMAT_0RGB1555
    PVLibretroPixelFormatXRGB8888  = 1, ///< RETRO_PIXEL_FORMAT_XRGB8888
    PVLibretroPixelFormatRGB565    = 2, ///< RETRO_PIXEL_FORMAT_RGB565
};

/// Hardware render context types that the thin frontend supports.
typedef NS_ENUM(NSInteger, PVLibretroHWContextType) {
    PVLibretroHWContextNone       = 0,
    PVLibretroHWContextOpenGLES2  = 2, ///< RETRO_HW_CONTEXT_OPENGLES2
    PVLibretroHWContextOpenGLES3  = 4, ///< RETRO_HW_CONTEXT_OPENGLES3
    PVLibretroHWContextOpenGLESVer = 5, ///< RETRO_HW_CONTEXT_OPENGLES_VERSION
    PVLibretroHWContextVulkan     = 6, ///< RETRO_HW_CONTEXT_VULKAN
};

@protocol PVThinLibretroDelegate <NSObject>

/// Called when the core delivers a software video frame.
/// @param buffer  Pointer to the pixel data (XRGB8888, RGB565, or 0RGB1555).
/// @param width   Frame width in pixels.
/// @param height  Frame height in pixels.
/// @param pitch   Row stride in bytes.
- (void)libretroFrontend:(id)frontend
         didRenderBuffer:(const void *)buffer
                   width:(unsigned)width
                  height:(unsigned)height
                   pitch:(size_t)pitch;

/// Called when the core delivers stereo audio samples.
/// @param left   Left channel sample (-32768…32767).
/// @param right  Right channel sample (-32768…32767).
- (void)libretroFrontend:(id)frontend didEmitAudioLeft:(int16_t)left right:(int16_t)right;

/// Called when the core delivers a batch of stereo audio samples.
/// @param data   Interleaved L/R samples (LRLRLR…).
/// @param frames Number of stereo frames (total samples = frames * 2).
/// @returns      Number of frames actually consumed (return `frames` to consume all).
- (size_t)libretroFrontend:(id)frontend didEmitAudioBatch:(const int16_t *)data frames:(size_t)frames;

/// Called each time the core polls for input. The delegate should update input state.
- (void)libretroFrontendPollInput:(id)frontend;

/// Called when the core queries a specific input axis/button.
/// @returns Raw axis value or 0/1 for buttons.
- (int16_t)libretroFrontend:(id)frontend
           inputStateForPort:(unsigned)port
                      device:(unsigned)device
                       index:(unsigned)index
                          id:(unsigned)buttonId;

@optional
/// AV info changed at runtime (e.g. resolution switch). Reload video surface.
- (void)libretroFrontend:(id)frontend didUpdateAVInfo:(PVLibretroAVInfo)avInfo;

/// Core displayed a message (old-style RETRO_ENVIRONMENT_SET_MESSAGE).
- (void)libretroFrontend:(id)frontend didSetMessage:(NSString *)message frames:(unsigned)frames;

/// Core shut itself down — the host should stop emulation.
- (void)libretroFrontendDidShutdown:(id)frontend;

@end

// ---------------------------------------------------------------------------
// MARK: - PVThinLibretroFrontend
// ---------------------------------------------------------------------------

/// A standalone libretro frontend that depends only on libretro.h.
///
/// Usage:
///   1. Create an instance, set `delegate`, set `romPath`.
///   2. Call `-loadCoreAtPath:error:` to dlopen the core dylib.
///   3. Call `-startWithROMPath:error:` to call retro_init / retro_load_game.
///   4. Call `-runFrame` once per video frame (or use the built-in frame timer).
///   5. Call `-stopEmulation` to unload.
///
/// Hardware rendering:
///   If the core requests GLES3 hardware rendering (RETRO_ENVIRONMENT_SET_HW_RENDER),
///   the frontend creates an EAGLContext pair sharing a GL sharegroup and an
///   IOSurface-backed FBO. The host must call `-setupHardwareContextFBOWidth:height:`
///   from the emulation thread (with the emu EAGLContext current) once the render
///   surface dimensions are known. `context_reset` fires at the end of that call.
///
///   If the core requests Vulkan (RETRO_HW_CONTEXT_VULKAN), the frontend loads
///   MoltenVK via dlopen, creates a VkInstance/VkDevice/VkQueue, and provides
///   the retro_hw_render_interface_vulkan to the core via GET_HW_RENDER_INTERFACE.
///   `context_reset` fires immediately after Vulkan setup completes.
///
@protocol PVRetroArchCoreResponderClient;
@protocol ObjCBridgedCoreBridge;
@protocol DiscSwappable;
@protocol EmulatorCoreViewportPositioning;

/// Posted on the main queue when the dlopened libretro core throws an
/// unhandled C++ exception (most commonly `vk::DeviceLostError` from a
/// Vulkan-HPP core) and the `runFrame` try/catch boundary catches it
/// before `_objc_terminate` aborts the process. `userInfo[@"reason"]`
/// carries the `what()` / NSException reason string, if available.
///
/// Swift consumers should use `Notification.Name.pvThinLibretroFrontendCoreDidThrow`
/// from the extension defined in `PVThinLibretroCore.swift`.
FOUNDATION_EXPORT NSNotificationName const PVThinLibretroFrontendCoreDidThrowNotification;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVThinLibretroFrontend : PVCoreObjCBridge <ObjCBridgedCoreBridge>
#pragma clang diagnostic pop

// MARK: Properties

/// Path to the ROM / content file to load.
@property (nonatomic, copy, nullable) NSString *romPath;

/// Path to the BIOS/system directory (RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY).
@property (nonatomic, copy, nullable) NSString *biosPath;

/// Path to the save-state directory (RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY).
@property (nonatomic, copy, nullable) NSString *savePath;

/// Delegate that receives video, audio, and input callbacks.
@property (nonatomic, weak, nullable) id<PVThinLibretroDelegate> frontendDelegate;

/// Fires on the emulation thread whenever the core reports new AV info
/// (`SET_SYSTEM_AV_INFO` or `SET_GEOMETRY`). Lets the Swift layer invalidate
/// any cached aspect-ratio state when the core changes resolution mid-run
/// (e.g. DS dual-screen toggle, PSP buffer resize). Dispatch to main before
/// touching UI state.
@property (nonatomic, copy, nullable) void (^avInfoDidUpdateBlock)(void);

/// Resolved system/AV info after the core loads successfully.
@property (nonatomic, readonly) PVLibretroAVInfo avInfo;

/// System info reported by the core.
@property (nonatomic, readonly) PVLibretroSystemInfo systemInfo;

/// Pixel format chosen by the core (libretro enum).
@property (nonatomic, readonly) PVLibretroPixelFormat libretroPixelFormat;

/// Hardware render context type, if the core requested HW rendering.
@property (nonatomic, readonly) PVLibretroHWContextType hwContextType;

/// YES if the core has requested hardware (GLES) rendering.
@property (nonatomic, readonly) BOOL usesHardwareRendering;

/// Current emulation speed multiplier (1.0 = normal, 2.0 = fast-forward).
@property (nonatomic, assign) double speedMultiplier;

// MARK: Core lifecycle

/// Load a libretro core `.dylib` or `.framework` executable at the given path.
/// This calls `dlopen` and resolves all `retro_*` symbols.
/// @param corePath  Absolute path to the dylib or framework executable.
/// @param error     On failure, populated with a descriptive error.
/// @returns YES on success.
- (BOOL)loadCoreAtPath:(NSString *)corePath error:(NSError **)error;

/// Unload the currently-loaded core dylib (dlclose).
- (void)unloadCore;

/// Initialize and load ROM content.
/// Calls `retro_set_environment`, `retro_init`, `retro_load_game`.
/// @param romPath   Path to the ROM file.
/// @param error     On failure, populated with a descriptive error.
/// @returns YES on success.
- (BOOL)startWithROMPath:(NSString *)romPath error:(NSError **)error;

/// Stop emulation: calls `retro_unload_game`, `retro_deinit`, and tears down the
/// HW render context. Does NOT dlclose the core dylib — call `-unloadCore` separately
/// (or let dealloc handle it) to fully unload the library.
- (void)stopEmulation;

/// Run one emulation frame (calls `retro_run()`).
/// Should be called at the core's reported FPS from a dedicated thread.
- (void)runFrame;

// MARK: Disc control

/// Whether the loaded content supports multiple disc images.
@property (readonly) BOOL currentGameSupportsMultipleDiscs;

/// Number of disc images available (0 if disc control is unsupported).
@property (readonly) NSUInteger numberOfDiscs;

/// Swap to a specific disc image (1-based index).
- (void)swapDiscWithNumber:(NSUInteger)number;

// MARK: State / Cheats

/// Serialize current state into an NSData.
- (nullable NSData *)saveState;

/// Deserialize a previously-saved state.
- (BOOL)loadState:(NSData *)stateData;

/// Apply a cheat code (RETRO_CHEAT_SET).
- (void)setCheatCode:(NSString *)code enabled:(BOOL)enabled index:(unsigned)index;

/// Clear all active cheat codes (RETRO_CHEAT_RESET).
- (void)resetCheats;

// MARK: Core options

/// Returns all options declared by the core via RETRO_ENVIRONMENT_SET_VARIABLES
/// or RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2.
/// Keys are option keys, values are current string values.
@property (nonatomic, readonly) NSDictionary<NSString *, NSString *> *coreOptions;

/// Structured option metadata parsed from SET_VARIABLES or SET_CORE_OPTIONS_V2.
/// Each dictionary contains: key, desc, info (nullable), category (nullable),
/// values (array of {value, label}), default (string).
@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, id> *> *coreOptionDefinitions;

/// Category metadata parsed from SET_CORE_OPTIONS_V2.
/// Each dictionary contains: key (String), desc (String), info (String or NSNull).
@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, id> *> *coreOptionCategories;

/// Visibility map for core options (key → visible bool).
/// Options not present are assumed visible. Updated via SET_CORE_OPTIONS_DISPLAY.
@property (nonatomic, readonly) NSDictionary<NSString *, NSNumber *> *coreOptionVisibility;

/// Update a core option at runtime.
- (void)setCoreOption:(NSString *)key value:(NSString *)value;

// MARK: MIDI routing

/// Update the cached list of MIDI output destination endpoint refs.
/// Call this whenever the user's `MIDIDeviceManager` selection changes
/// (driven by the Swift observer in `PVThinLibretroCore+MIDI.swift`).
/// Thread-safe; may be called from any thread.
///
/// @param endpointRefs  Array of `NSNumber` wrapping `MIDIEndpointRef` (UInt32) values.
///                      Pass an empty array when the user selects "None" — `thin_midi_write`
///                      becomes a no-op until a destination is selected.
+ (void)setMIDIOutputEndpoints:(NSArray<NSNumber *> *)endpointRefs;

// MARK: Netpacket interface (env 78)

/// Whether the loaded core registered a netpacket callback via env 78.
@property (nonatomic, readonly) BOOL hasNetpacketInterface;

/// The protocol_version string from the core's netpacket callback, or nil.
@property (nonatomic, readonly, nullable) NSString *netpacketProtocolVersion;

/// Block invoked from the emulation thread when the core calls send_fn.
/// The Swift transport layer sets this to forward packets over the network.
@property (nonatomic, copy, nullable) void (^netpacketSendBlock)(int flags,
    const void *buf, size_t len, uint16_t clientID);

/// Start a netpacket session with the given client ID.
/// Calls the core's start callback with send_fn and poll_receive_fn.
- (void)startNetpacketSessionWithClientID:(uint16_t)clientID;

/// Stop the active netpacket session.
- (void)stopNetpacketSession;

/// Enqueue a received network packet for delivery to the core.
- (void)enqueueNetpacketData:(NSData *)data fromClient:(uint16_t)clientID;

/// Notify the core that a remote peer connected.
- (void)netpacketPeerConnected:(uint16_t)clientID;

/// Notify the core that a remote peer disconnected.
- (void)netpacketPeerDisconnected:(uint16_t)clientID;

// MARK: Utility

/// Probe a core dylib without fully loading it — reads retro_get_system_info.
/// Does not retain the dylib in the caller's process space after return.
/// @param corePath  Absolute path to the dylib or framework executable.
+ (nullable NSDictionary<NSString *, id> *)probeCoreDylibAtPath:(NSString *)corePath;

// MARK: Startup hooks

/// Optional block invoked after the ROM is loaded successfully but before the emulation loop
/// thread starts. Assign this block to perform post-load setup in a thread-safe window
/// (e.g. restoring per-port controller device type selections before the core starts running).
@property (nonatomic, copy, nullable) dispatch_block_t afterROMLoadBlock;

// MARK: Controller port info

/// Maximum number of controller ports the thin frontend tracks (matches THIN_MAX_PLAYERS).
/// Exposed as a class property so Swift callers can reference the authoritative limit
/// without duplicating the ObjC preprocessor constant.
@property (class, readonly) NSUInteger maxPlayers;

/// Per-port list of device types reported by the core via
/// RETRO_ENVIRONMENT_SET_CONTROLLER_INFO.
/// Outer array is indexed by port (0-based).
/// Each inner array contains dictionaries with keys:
///   @"id"   : NSNumber (unsigned) — RETRO_DEVICE_* constant
///   @"desc" : NSString — human-readable device description
/// Returns an empty array if the core did not call SET_CONTROLLER_INFO.
@property (nonatomic, readonly) NSArray<NSArray<NSDictionary<NSString *, id> *> *> *controllerPortInfo;

/// Returns the currently-selected device type for the given port (0-based).
/// Defaults to RETRO_DEVICE_JOYPAD (1) unless changed via setControllerPortDevice:forPort:.
- (unsigned)currentDeviceTypeForPort:(unsigned)port NS_SWIFT_NAME(currentDeviceType(forPort:));

// MARK: Core capability flags

/// YES when the core declared support for running without game content
/// via RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME.
@property (nonatomic, readonly) BOOL coreSupportsNoGame;

/// YES when the core declared achievement support via
/// RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS.
@property (nonatomic, readonly) BOOL coreSupportsAchievements;

// MARK: Input descriptors

/// Per-button / per-axis descriptors reported by the core via
/// RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS.
/// Each dictionary contains:
///   @"port"   : NSNumber (unsigned) — player port
///   @"device" : NSNumber (unsigned) — RETRO_DEVICE_* type
///   @"index"  : NSNumber (unsigned) — sub-device index
///   @"id"     : NSNumber (unsigned) — button / axis id
///   @"desc"   : NSString — human-readable description
/// Returns an empty array if the core did not call SET_INPUT_DESCRIPTORS.
@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, id> *> *inputDescriptors;

// MARK: Subsystem info

/// Subsystems declared by the core via RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO.
/// Each dictionary contains:
///   @"desc"  : NSString — human-readable name (e.g. "Super GameBoy")
///   @"ident" : NSString — short [a-z] identifier (e.g. "sgb")
///   @"id"    : NSNumber (unsigned) — type passed to retro_load_game_special()
///   @"roms"  : NSArray of NSDictionary with keys:
///       @"desc", @"valid_extensions", @"need_fullpath", @"block_extract", @"required"
/// Returns an empty array if the core did not call SET_SUBSYSTEM_INFO.
@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, id> *> *subsystemInfo;

/// Per-extension content loading overrides declared by the core via
/// RETRO_ENVIRONMENT_SET_CONTENT_INFO_OVERRIDE.
/// Each dictionary contains:
///   @"extensions"     : NSString — pipe-separated extensions (e.g. "md|sms|gg")
///   @"need_fullpath"  : NSNumber (BOOL)
///   @"persistent_data": NSNumber (BOOL)
/// Returns an empty array if the core did not call SET_CONTENT_INFO_OVERRIDE.
@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, id> *> *contentInfoOverrides;

// MARK: Memory maps

/// Number of memory descriptors stored from RETRO_ENVIRONMENT_SET_MEMORY_MAPS.
@property (nonatomic, readonly) unsigned memoryMapCount;

/// Returns a snapshot of the stored memory descriptors.
/// Each dictionary contains:
///   @"flags"      : NSNumber (uint64_t)
///   @"ptr"        : NSValue wrapping the raw void* (or NSNull if NULL)
///   @"offset"     : NSNumber (uint64_t)
///   @"start"      : NSNumber (uint64_t) — emulated address
///   @"select"     : NSNumber (uint64_t)
///   @"disconnect" : NSNumber (uint64_t)
///   @"len"        : NSNumber (uint64_t)
///   @"addrspace"  : NSString (or @"" if NULL)
/// Returns an empty array if the core did not call SET_MEMORY_MAPS.
@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, id> *> *memoryMapDescriptors;

/// Returns the core's raw memory block for a given RETRO_MEMORY_* id, or NULL
/// if the core does not expose that region. Pointer lifetime matches the
/// loaded game — the buffer is valid from `retro_load_game` until
/// `retro_unload_game` / `retro_deinit`.
/// @param memoryID  One of `RETRO_MEMORY_SAVE_RAM` (0), `RETRO_MEMORY_RTC` (1),
///                  `RETRO_MEMORY_SYSTEM_RAM` (2), or `RETRO_MEMORY_VIDEO_RAM` (3).
/// @param outSize   On return, filled with the region size in bytes (0 if
///                  the region is unavailable). May be NULL.
- (nullable void *)memoryDataForID:(unsigned)memoryID size:(nullable size_t *)outSize;

// MARK: Input state

/// Set or clear a single joypad button for a given player.
/// @param buttonId  A RETRO_DEVICE_ID_JOYPAD_* constant (0..15).
/// @param pressed   YES to press, NO to release.
/// @param player    Player index (0-based).
- (void)setButton:(unsigned)buttonId pressed:(BOOL)pressed forPlayer:(unsigned)player;

/// Set an analog axis value for a given player.
/// @param index  Stick index: 0 = left stick, 1 = right stick.
/// @param axis   Axis: 0 = X, 1 = Y.
/// @param value  Axis value in libretro range (-0x7FFF .. +0x7FFF).
/// @param player Player index (0-based).
- (void)setAnalogIndex:(unsigned)index axis:(unsigned)axis value:(int16_t)value forPlayer:(unsigned)player;

/// Set the controller device type for a specific port.
/// Use RETRO_DEVICE_MOUSE (2) for mouse games like Mario Paint.
/// @param device  libretro device type (RETRO_DEVICE_JOYPAD, RETRO_DEVICE_MOUSE, etc.)
/// @param port    Port number (0-based).
- (void)setControllerPortDevice:(unsigned)device forPort:(unsigned)port;

/// Clear all button and analog state for all players.
- (void)clearAllInput;

/// Optional block called each frame from the input poll callback (emulation thread).
/// The thin Swift core sets this to call `pollControllers()` for GCController support.
@property (nonatomic, copy, nullable) dispatch_block_t inputPollBlock;

// MARK: Keyboard input

/// Set the press/release state of a libretro keyboard key.
/// @param keycode  A `retro_key` enum value (e.g. RETROK_a, RETROK_RETURN).
/// @param pressed  YES when the key is pressed, NO when released.
- (void)setKeyState:(unsigned)keycode pressed:(BOOL)pressed;

// MARK: Mouse input

/// Set the relative mouse movement delta for the current frame.
/// Deltas are cleared (consumed) after `thin_input_state` reads them.
/// @param dx  Horizontal delta (positive = right).
/// @param dy  Vertical delta (positive = down).
- (void)setMouseDeltaX:(int16_t)dx deltaY:(int16_t)dy;

/// Set or clear a mouse button.
/// @param button  A RETRO_DEVICE_ID_MOUSE_* button constant (LEFT=2, RIGHT=3, MIDDLE=6).
/// @param pressed YES to press, NO to release.
- (void)setMouseButton:(unsigned)button pressed:(BOOL)pressed;

// MARK: Pointer (touch) input

/// Set the pointer (touch) position and pressed state.
/// Coordinates are in libretro normalized range: -0x7FFF .. +0x7FFF.
/// @param x        Horizontal position.
/// @param y        Vertical position.
/// @param pressed  YES if the pointer/touch is active.
- (void)setPointerX:(int16_t)x y:(int16_t)y pressed:(BOOL)pressed;

// MARK: Achievements (rcheevos)

/// Drive one frame of rcheevos trigger evaluation. Called automatically from
/// `executeFrame` after `runFrame` returns, so the Swift core does not need
/// to invoke this directly. No-op if the rcheevos client is not yet active.
- (void)tickAchievements;

/// Login (using cached `ra_username` / `ra_session_token` in `NSUserDefaults`)
/// and load the game-hash session. Completion fires on the network queue with
/// success=YES once `rc_client_begin_load_game` returns RC_OK.
///
/// If a previous session is active, the rc_client is reused and only the
/// load-game step runs.
///
/// @param gameHash    The MD5 hash returned by Provenance's hashing layer.
/// @param hardcore    YES to enable hardcore mode (no save-state/cheats/rewind).
/// @param completion  Optional callback invoked with the load result.
- (void)loadAchievementsForGameHash:(NSString *)gameHash
                           hardcore:(BOOL)hardcore
                         completion:(nullable void (^)(BOOL success))completion;

/// Tear down the active rcheevos game session and stop frame ticking.
/// The rc_client itself is preserved across game changes so the cached login
/// token does not need re-validation.
- (void)unloadAchievements;

/// YES while the rcheevos client has a loaded game and trigger evaluation is
/// running each frame. Reset to NO by `unloadAchievements` and on session load
/// failure.
@property (nonatomic, readonly) BOOL achievementsActive;

/// Block invoked on the emulation thread when an achievement is unlocked.
/// The Swift core converts this into a `RetroAchievementsOSDDelegate` call.
/// Dispatch to main before touching UI state.
@property (nonatomic, copy, nullable) void (^achievementTriggeredBlock)(uint32_t achievementID,
    NSString *title, NSString *desc, uint32_t points, NSURL * _Nullable badgeURL, BOOL isHardcore);

/// Block invoked when measurable achievement progress changes.
@property (nonatomic, copy, nullable) void (^achievementProgressBlock)(uint32_t achievementID,
    NSString *title, NSString *progressText);

/// Block invoked when a leaderboard attempt starts.
@property (nonatomic, copy, nullable) void (^leaderboardStartedBlock)(uint32_t leaderboardID,
    NSString *title, NSString *desc, NSString *scoreText);

/// Block invoked when a leaderboard attempt is cancelled or fails.
@property (nonatomic, copy, nullable) void (^leaderboardFailedBlock)(uint32_t leaderboardID);

/// Block invoked when a leaderboard score is submitted successfully.
@property (nonatomic, copy, nullable) void (^leaderboardSubmittedBlock)(uint32_t leaderboardID,
    NSString *title, NSString *desc, NSString *scoreText);

/// Block invoked when rcheevos fails to load the game's achievement set
/// or fails to log in for the session. The Swift core converts this to
/// `RetroAchievementsOSDDelegate.sessionLoadFailed(rcResult:message:)`
/// so the UI can surface a categorised toast (network vs unknown game
/// vs auth). Without this, load failures were log-only — the user had no
/// way to tell why their cheevos weren't tracking (audit Section J.1).
@property (nonatomic, copy, nullable) void (^sessionLoadFailedBlock)(int32_t rcResult,
    NSString * _Nullable message);

// MARK: Light gun input

/// Set the light gun aim position and button states.
///
/// Screen coordinates use the libretro light gun range:
///   X: -0x7FFF (left edge) .. +0x7FFF (right edge)
///   Y: -0x7FFF (top edge)  .. +0x7FFF (bottom edge)
///
/// @param x           Horizontal aim position in libretro screen-space.
/// @param y           Vertical aim position in libretro screen-space.
/// @param trigger     YES when the primary trigger is pressed.
/// @param auxA        YES when auxiliary button A is pressed (Super Scope pause / Guncon B).
/// @param auxB        YES when auxiliary button B is pressed (Super Scope turbo / Guncon C).
/// @param start       YES when the start button is pressed (Guncon A).
/// @param select      YES when the select button is pressed.
/// @param isOffscreen YES when the gun is aimed off-screen.
/// @param reload      YES when a forced reload (off-screen fire) is requested.
- (void)setLightgunX:(int16_t)x
                   y:(int16_t)y
             trigger:(BOOL)trigger
                auxA:(BOOL)auxA
                auxB:(BOOL)auxB
               start:(BOOL)start
              select:(BOOL)select
         isOffscreen:(BOOL)isOffscreen
              reload:(BOOL)reload;

@end

NS_ASSUME_NONNULL_END
