//
//  PVThinLibretroFrontend.h
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  A minimal libretro frontend that:
//  - Depends ONLY on libretro.h (no RetroArch internals)
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

@protocol ObjCBridgedCoreBridge;

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import <PVCoreBridgeRetro/libretro.h>
#import <dlfcn.h>

/// Maximum number of players supported for input.
#define THIN_MAX_PLAYERS 4

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
@interface PVThinLibretroFrontend : PVCoreObjCBridge <ObjCBridgedCoreBridge>

// MARK: Properties

/// Path to the ROM / content file to load.
@property (nonatomic, copy, nullable) NSString *romPath;

/// Path to the BIOS/system directory (RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY).
@property (nonatomic, copy, nullable) NSString *biosPath;

/// Path to the save-state directory (RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY).
@property (nonatomic, copy, nullable) NSString *savePath;

/// Delegate that receives video, audio, and input callbacks.
@property (nonatomic, weak, nullable) id<PVThinLibretroDelegate> frontendDelegate;

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

// MARK: Utility

/// Probe a core dylib without fully loading it — reads retro_get_system_info.
/// Does not retain the dylib in the caller's process space after return.
/// @param corePath  Absolute path to the dylib or framework executable.
+ (nullable NSDictionary<NSString *, id> *)probeCoreDylibAtPath:(NSString *)corePath;

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

/// Clear all button and analog state for all players.
- (void)clearAllInput;

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

@end

NS_ASSUME_NONNULL_END
