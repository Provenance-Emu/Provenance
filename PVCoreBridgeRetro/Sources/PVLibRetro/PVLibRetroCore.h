//
//  PVLibretro.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//


@import Foundation;
@import PVCoreObjCBridge;

#import <PVCoreBridgeRetro/libretro.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
//#import <PVLibRetro/dynamic.h>

//#pragma clang diagnostic push
//#pragma clang diagnostic error "-Wall"

#define RETRO_API_VERSION 1

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

typedef struct retro_core_t retro_core_t;

@protocol ObjCBridgedCoreBridge;
@class PVLibRetroCoreBridge;
static __weak PVLibRetroCoreBridge * _Nonnull _current;

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((weak_import))
@interface PVLibRetroCoreBridge: PVCoreObjCBridge  <ObjCBridgedCoreBridge> {
#pragma clang diagnostic pop
@public
    unsigned short pitch_shift;

    uint32_t *videoBuffer;
    uint32_t *videoBufferA;
    uint32_t *videoBufferB;

    int16_t _pad[2][16]; // full RetroPad range: RETRO_DEVICE_ID_JOYPAD_B(0)..RETRO_DEVICE_ID_JOYPAD_R3(15)

    retro_core_t* core;

    // MARK: - Retro Structs
    unsigned                 core_poll_type;
    bool                     core_input_polled;
    bool                     core_has_set_input_descriptors;
    struct retro_system_av_info av_info;
    enum retro_pixel_format pix_fmt;
}
- (instancetype _Nonnull )init;

- (void *_Nonnull)getVariable:(const char *_Nonnull)variable;

@property (nonatomic, readonly) CGFloat videoWidth;
@property (nonatomic, readonly) CGFloat videoHeight;
@property (nonatomic, retain, nullable) NSString * romPath;

/// Gate flag for the bridge's libretro-pointer touch routing (used by
/// `sendEvent:` to decide whether to forward UITouch events into the core).
/// Not part of any controller-touchpad protocol — kept after the
/// TouchPadResponder deletion because it has a separate consumer.
@property (nonatomic, assign) BOOL touchpadEnabled;

// MARK: - Netpacket interface (env 78)

/// Whether the loaded core registered a netpacket callback via env 78.
@property (nonatomic, readonly) BOOL hasNetpacketInterface;

/// The protocol_version string from the core's netpacket callback, or nil.
@property (nonatomic, readonly, nullable) NSString *netpacketProtocolVersion;

/// Block invoked from the emulation thread when the core calls send_fn.
/// The Swift transport layer sets this to forward packets over the network.
@property (nonatomic, copy, nullable) void (^netpacketSendBlock)(int flags,
    const void *_Nonnull buf, size_t len, uint16_t clientID);

/// Start a netpacket session with the given client ID.
- (void)startNetpacketSessionWithClientID:(uint16_t)clientID;

/// Stop the active netpacket session.
- (void)stopNetpacketSession;

/// Enqueue a received network packet for delivery to the core.
- (void)enqueueNetpacketData:(NSData *_Nonnull)data fromClient:(uint16_t)clientID;

/// Notify the core that a remote peer connected.
- (void)netpacketPeerConnected:(uint16_t)clientID;

/// Notify the core that a remote peer disconnected.
- (void)netpacketPeerDisconnected:(uint16_t)clientID;

@end

@interface PVLibRetroCoreBridge (Controls)
- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player;
- (void)pollControllers;
@end

@interface PVLibRetroCoreBridge (TouchMouseInput)
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
- (void)handleTouchEvent:(UIEvent *_Nonnull)event;
#else
- (void)handleMouseEvent:(NSEvent *_Nonnull)event;
#endif
- (int16_t)getPointerState:(unsigned)port device:(unsigned)device index:(unsigned)index id:(unsigned)id;
// Keyboard event forwarding for libretro keyboard-based cores (e.g., DosBox, MSX)
// hidCode: HID USB usage page key code (matches GCKeyCode.rawValue on iOS 14+)
// character: Unicode character value (pass 0 if unknown)
- (void)sendKeyboardEvent:(BOOL)down hidCode:(unsigned)hidCode character:(uint32_t)character;
// Mouse state management for libretro mouse-based cores
// normalizedPoint: coordinates in 0.0-1.0 range relative to the video surface
- (void)setMousePosition:(CGPoint)normalizedPoint;
- (void)setLeftMouseButtonPressed:(BOOL)pressed;
- (void)setRightMouseButtonPressed:(BOOL)pressed;
/// Sets the libretro controller device type for a specific port.
/// Returns YES when the device type was applied, NO when the core is not yet
/// initialised (logs an info message). Safe to call before init — callers can retry
/// on the next input event. Ideally called after `retro_load_game` succeeds.
- (BOOL)pv_setControllerPortDevice:(unsigned)device forPort:(unsigned)port;
/// Inject a single raw MIDI byte into the libretro MIDI input ring buffer.
///
/// Called by `MIDIResponder` protocol implementations to forward decoded MIDI
/// events received from `MIDIDeviceManager` into the `retro_midi_interface`
/// read path so that the emulated core receives them on the next `retro_run` frame.
///
/// Thread-safe; silently drops bytes when the buffer is full.
- (void)injectMIDIByte:(uint8_t)byte;
@end

@interface PVLibRetroCoreBridge (Cheats)
- (void)setCheat:(NSString *_Nonnull)code setType:(NSString *_Nonnull)type setEnabled:(BOOL)enabled;
- (BOOL)setCheat:(NSString *_Nonnull)code setType:(NSString *_Nonnull)type setCodeType:(NSString *_Nonnull)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError * _Nullable * _Nullable)error;
- (void)resetCheatCodes;
@end

NS_ASSUME_NONNULL_END

#define SYMBOL(x) \
do { \
    function_t func = dylib_proc(lib_handle, #x); \
    memcpy(&current_core->x, &func, sizeof(func)); \
    if (current_core->x == NULL) { \
        ELOG(@"Failed to load symbol: \"%s\"\n", #x); \
        retroarch_fail(1, "init_libretro_sym()"); \
    } \
} while (0)

#define SYMBOL_DUMMY(x) current_core->x = libretro_dummy_##x

//#pragma clang diagnostic pop
