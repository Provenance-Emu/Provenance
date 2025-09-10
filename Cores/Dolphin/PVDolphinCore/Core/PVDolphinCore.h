//
//  PVDolphinCore.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//
#pragma once
#import <Foundation/Foundation.h>
@import PVCoreObjCBridge;

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <CoreMotion/CoreMotion.h>

@protocol PVWiiSystemResponderClient;
@protocol PVGameCubeSystemResponderClient;
@protocol ObjCBridgedCoreBridge;

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface PVDolphinCoreBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGameCubeSystemResponderClient, PVWiiSystemResponderClient>
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
@public
    dispatch_queue_t _callbackQueue;
}
// System Properties
@property (nonatomic, assign) bool isWii;
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
@property (nonatomic, assign) bool viSkip;

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
@property (nonatomic, assign) bool pauseOnPanic;
@property (nonatomic, assign) bool enableWriteBackCache;
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
- (void) refreshScreenSize;
- (void) startVM:(UIView *)view;
- (void) setupControllers;
- (void) pollControllers;
- (void) gamepadEventOnPad:(int)player button:(int)button action:(int)action;
- (void) gamepadEventIrRecenter:(int)action;
- (BOOL) setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
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
+(CMMotionManager*)sharedMotionManager;
-(void)updateWiimoteGyroFromMotion:(CMDeviceMotion*)motion;
-(void)updateIRCursorFromMotion:(CMDeviceMotion*)motion;

// JIT detection
-(BOOL)checkJITAvailable;

@end
extern __weak PVDolphinCoreBridge *_current;

// Options
#define MAP_MULTIPLAYER "Assign Controllers to Multiple Players"
