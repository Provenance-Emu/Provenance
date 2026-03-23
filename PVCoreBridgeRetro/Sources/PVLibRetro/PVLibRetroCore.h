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
@protocol TouchPadResponder;
@class PVLibRetroCoreBridge;
static __weak PVLibRetroCoreBridge * _Nonnull _current;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((weak_import))
@interface PVLibRetroCoreBridge: PVCoreObjCBridge  <ObjCBridgedCoreBridge, TouchPadResponder> {
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
- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player;
- (void)pollControllers;

- (void *_Nonnull)getVariable:(const char *_Nonnull)variable;

// Touch and mouse input support
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
- (void)handleTouchEvent:(UIEvent *)event;
#else
- (void)handleMouseEvent:(NSEvent *)event;
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

@property (nonatomic, readonly) CGFloat videoWidth;
@property (nonatomic, readonly) CGFloat videoHeight;
@property (nonatomic, retain, nullable) NSString * romPath;

#if !TARGET_OS_WATCH
@property (nonatomic, readonly, nullable) GCControllerButtonTouchedChangedHandler touchedChangedHandler;
@property (nonatomic, readonly, nullable) GCControllerButtonValueChangedHandler pressedChangedHandler;
@property (nonatomic, readonly, nullable) GCControllerButtonValueChangedHandler valueChangedHandler;
#endif
@property (nonatomic, assign) BOOL touchpadEnabled;
@property (nonatomic, readonly) BOOL gameSupportsTouchpad;

@end

@interface PVLibRetroCoreBridge (Cheats)
- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error;
- (void)resetCheatCodes;
@end

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
