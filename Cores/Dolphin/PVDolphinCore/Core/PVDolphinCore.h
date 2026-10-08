//
//  PVDolphinCore.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//
#pragma once
#import <Foundation/Foundation.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#if !TARGET_OS_TV
#import <CoreMotion/CoreMotion.h>
#endif

@protocol PVWiiSystemResponderClient;
@protocol PVGameCubeSystemResponderClient;
@protocol ObjCBridgedCoreBridge;
@protocol EmulatorCoreViewportPositioning;

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface PVDolphinCoreBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGameCubeSystemResponderClient, PVWiiSystemResponderClient, EmulatorCoreViewportPositioning>
{
    uint8_t padData[4][74]; // [PVDreamcastButtonCount];
    int8_t xAxis[4];
    int8_t yAxis[4];
//    int videoWidth;
//    int videoHeight;
//    int videoBitDepth;
    int videoDepthBitDepth; // eh
//    int8_t gsPreference;
//    int8_t resFactor;
//    int8_t cpuType;
//    int8_t cpuOClock;
//    int8_t msaa;
//    BOOL ssaa;
//    BOOL fastMemory;
    float sampleRate;
    BOOL isNTSC;
//    BOOL isBilinear;
//    BOOL isWii;
//    BOOL enableCheatCode;
//    BOOL multiPlayer;
    UIView *m_view;
    UIViewController *m_view_controller;
    CAMetalLayer* m_metal_layer;
    CAEAGLLayer *m_gl_layer;
    /// Externally-provided CAMetalLayer for direct Vulkan rendering (bypasses view.layer)
    CAMetalLayer* m_external_render_layer;
@public
    dispatch_queue_t _callbackQueue;
}
// System Properties
@property (nonatomic, assign) bool isWii;
/// True when the JIT recompiler is the CPU engine actually selected for this session.
@property (nonatomic, assign) bool jitActive;
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;

// Graphics Settings
@property (nonatomic, assign) int8_t resFactor;
@property (nonatomic, assign) int8_t gsPreference;
@property (nonatomic, assign) int8_t aspectRatio;
@property (nonatomic, assign) bool vsync;
@property (nonatomic, assign) int8_t anisotropicFiltering;
@property (nonatomic, assign) bool isBilinear;
@property (nonatomic, assign) bool showFPS;

// Graphics Enhancements
@property (nonatomic, assign) bool scaledEFBCopy;
@property (nonatomic, assign) bool disableFog;
@property (nonatomic, assign) bool pixelLighting;
@property (nonatomic, assign) bool forceTrueColor;

// Graphics Hacks (DolphinQt Parity)
@property (nonatomic, assign) bool skipEFBAccessFromCPU;
@property (nonatomic, assign) bool ignoreFormatChanges;
@property (nonatomic, assign) bool storeEFBCopiesToTextureOnly;
@property (nonatomic, assign) bool deferEFBCopies;
@property (nonatomic, assign) int8_t textureCacheAccuracy;
@property (nonatomic, assign) bool storeXFBCopiesToTextureOnly;
@property (nonatomic, assign) bool immediateXFB;
@property (nonatomic, assign) bool skipDuplicateXFBs;
@property (nonatomic, assign) bool gpuTextureDecoding;
@property (nonatomic, assign) bool fastDepthCalculation;
@property (nonatomic, assign) bool disableBoundingBox;
@property (nonatomic, assign) bool saveTextureCacheToState;
@property (nonatomic, assign) bool vertexRounding;
@property (nonatomic, assign) int8_t viSkipMode;  // 0=Off 1=On(legacy) 2=Auto(bounded)

// Textures & Mods
@property (nonatomic, assign) bool customTextures;
@property (nonatomic, assign) bool prefetchCustomTextures;
@property (nonatomic, assign) bool graphicsMods;
@property (nonatomic, assign) bool osdMessages;

// Shader Settings
@property (nonatomic, assign) int8_t shaderCompilationMode;
@property (nonatomic, assign) bool waitForShaders;

// Anti-Aliasing
@property (nonatomic, assign) int8_t msaa;
@property (nonatomic, assign) bool ssaa;

// CPU/Emulation Settings
@property (nonatomic, assign) int8_t cpuType;
@property (nonatomic, assign) int8_t cpuOClock;
@property (nonatomic, assign) bool dualCore;
@property (nonatomic, assign) bool idleSkipping;
@property (nonatomic, assign) bool fastMemory;
@property (nonatomic, assign) bool enableCheatCode;

// Advanced Emulation Settings
@property (nonatomic, assign) bool enableVBIOverride;
@property (nonatomic, assign) float vbiFrequencyRange;
@property (nonatomic, assign) bool enableMMU;
@property (nonatomic, assign) bool autoDiscChange;
@property (nonatomic, assign) bool accurateNaNs;
@property (nonatomic, assign) bool accurateCPUCache;
@property (nonatomic, assign) bool disableICache;
@property (nonatomic, assign) bool fastFP;
@property (nonatomic, assign) bool dcbzHack;
@property (nonatomic, assign) bool relaxedIdleDetection;
@property (nonatomic, assign) bool fastForwardCTRIdle;
// CachedInterpreter (CIR) flags: `[Core]` ini key -> value, one per PVDolphinCoreOptions.cirFlags entry.
@property (nonatomic, copy) NSDictionary<NSString *, NSNumber *> *cirFlags;
// Diagnostics
@property (nonatomic, assign) bool stallMetrics;
@property (nonatomic, assign) bool cirCacheLoopFFValidate;
@property (nonatomic, assign) bool dspHLE;
@property (nonatomic, assign) bool dspThread;
@property (nonatomic, assign) bool syncGPU;
@property (nonatomic, assign) bool fastDiscSpeed;
@property (nonatomic, assign) int8_t speedLimit;
@property (nonatomic, assign) int8_t fallbackRegion;

// Audio Settings
@property (nonatomic, assign) int8_t audioBackend;
@property (nonatomic, assign) bool audioStretch;
@property (nonatomic, assign) int8_t volume;

// System Settings
@property (nonatomic, assign) bool skipIPL;
@property (nonatomic, assign) int8_t wiiLanguage;
@property (nonatomic, assign) bool multiPlayer;
@property (nonatomic, assign) bool enableLogging;
@property (nonatomic, assign) bool enableHapticFeedback;
@property (nonatomic, assign) bool enableGyroMotionControls;
@property (nonatomic, assign) bool enableGyroIRCursor;
@property (nonatomic, assign) bool disableJoystickIRCursor;

/// Called on Dolphin's CPU thread at the end of every emulated video field
/// (VideoInterface's `vi_end_field_event`). Dolphin runs its own emulation
/// loop (`skipEmulationLoop`), so neither this bridge's nor the Swift core's
/// `executeFrame` is ever called; this drives the per-frame achievements tick.
/// Declared in the main @interface: SwiftPM can drop ObjC categories. No
/// nullability keyword: this header has none, and one would trigger
/// -Wnullability-completeness on every other pointer in it.
@property (nonatomic, copy) void (^frameCompletedHandler)(void);

- (void) refreshScreenSize;
- (void) startVM:(UIView *)view;
/// Sets the CAMetalLayer directly for Vulkan rendering, bypassing view.layer access
- (void) setRenderLayer:(CAMetalLayer *)layer;
- (void) setupControllers;
- (void) pollControllers;
- (void) gamepadEventOnPad:(int)player button:(int)button action:(int)action;
- (void) gamepadEventIrRecenter:(int)action;
- (BOOL) setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
/// Apply a controller layout variant (ConsoleVariantConfigurable). Accepts
/// ControllerLayoutVariant ids: wii-wiimote / wii-wiimote-nunchuck / wii-classic[-pro],
/// gc-standard / gc-bongos / gc-keyboard. Regenerates config inis and hot-swaps when running.
- (void) applyControllerVariant:(NSString *)variantID;
/// The ControllerLayoutVariant id last loaded or applied, or nil when the core runs its defaults.
- (NSString *) currentControllerVariantID;
- (void) resetCheatCodes;
-(void)controllerConnected:(NSNotification *)notification;
-(void)controllerDisconnected:(NSNotification *)notification;
-(void)optionUpdated:(NSNotification *)notification;

// Touch Screen Support for Wii IR Cursor
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player;
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player;
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player;
-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event forPlayer:(NSInteger)player;

// Helper methods for touch screen IR cursor
-(void)updateIRCursorWithLocation:(CGPoint)location inView:(UIView*)view forPlayer:(NSInteger)player;
-(void)resetIRCursorForPlayer:(NSInteger)player;

// Haptic feedback setup
-(void)setupHapticFeedback;

// Gyro motion controls setup
-(void)setupGyroMotionControls;
-(void)startMotionUpdates;
-(void)stopMotionUpdates;
#if !TARGET_OS_TV
+(CMMotionManager*)sharedMotionManager;
-(void)updateWiimoteGyroFromMotion:(CMDeviceMotion*)motion;
-(void)updateIRCursorFromMotion:(CMDeviceMotion*)motion;
#endif

// JIT detection
-(BOOL)checkJITAvailable;

// Applies the Aspect Ratio option and the app's scaling mode to Dolphin's aspect setting,
// then asks the render view to lay itself out again. Safe to call from any thread.
-(void)applyAspectRatioSetting;

/// YES when the app's Aspect Fill, Integer Scale or Native Resolution mode is applied by
/// sizing the render layer (Dolphin itself then stretches to that layer). Aspect Fit and
/// Stretch are Dolphin's own aspect modes, and the OpenGL backend has no sizable layer.
@property (nonatomic, readonly) BOOL sizesRenderLayerForScalingMode;
/// Width / height of the picture Dolphin is drawing, ignoring stretch. 0 until known.
@property (nonatomic, readonly) CGFloat gameDisplayAspect;
/// Where the render layer sits inside the render view. Main thread; used to map touches.
- (void)renderLayerFrameDidChange:(CGRect)frame;
/// The rect, in `view`'s coordinates, that the game picture occupies: the render layer's
/// frame while it is sized for the scaling mode, otherwise all of `view`. For touch input.
- (CGRect)renderPictureRectInView:(UIView *)view;
/// Lays the render view out again, so the render layer picks up a new scaling mode or aspect.
/// Safe to call from any thread.
- (void)requestRenderLayerRelayout;

// DeltaSkin viewport (EmulatorCoreViewportPositioning). Declared here, not in a category
// header, so Swift module synthesis can't drop them.
/// YES: the render view follows frames from `applyRenderViewFrameInTouchView:` instead of
/// filling its host. NO: it fills its host again.
- (void)setUseCustomRenderViewLayout:(BOOL)enabled;
/// Positions the render view at `frame`, given in the coordinate space of the GPU view's
/// superview. Frames that arrive before `setupView` are kept and applied once it runs.
- (void)applyRenderViewFrameInTouchView:(CGRect)frame;
/// YES once `stopEmulation` has started, so delayed skin viewport updates are dropped.
- (BOOL)isShuttingDownForViewportUpdates;

@end
extern __weak PVDolphinCoreBridge *_current;

// Options
#define MAP_MULTIPLAYER "Assign Controllers to Multiple Players"
