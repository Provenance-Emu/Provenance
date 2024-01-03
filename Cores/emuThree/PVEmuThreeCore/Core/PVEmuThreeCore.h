//  PVEmuThreeCore.h
//  Copyright © 2023 Provenance. All rights reserved.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface PVEmuThreeCore : PVEmulatorCore
<PV3DSSystemResponderClient>
{
    int videoWidth;
    int videoHeight;
    int videoBitDepth;
    int8_t resFactor;
    int8_t gsPreference;
    BOOL enableHLE;
    int8_t cpuOClock;
    BOOL enableJIT;
    BOOL useNew3DS;
    BOOL asyncShader;
    BOOL asyncPresent;
    int8_t shaderType;
    BOOL enableVSync;
    BOOL enableShaderAccurate;
    BOOL enableShaderJIT;
    int8_t portraitType;
    int8_t landscapeType;
    BOOL swapScreen;
    BOOL uprightScreen;
    BOOL preloadTextures;
    UIView *m_view;
    UIViewController *m_view_controller;
    CAMetalLayer* m_metal_layer;
    CAEAGLLayer *m_gl_layer;
@public
    dispatch_queue_t _callbackQueue;
}
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;
@property (nonatomic, assign) int8_t resFactor;
@property (nonatomic, assign) int8_t gsPreference;
@property (nonatomic, assign) bool enableHLE;
@property (nonatomic, assign) int8_t cpuOClock;
@property (nonatomic, assign) bool enableJIT;
@property (nonatomic, assign) bool useNew3DS;
@property (nonatomic, assign) bool asyncShader;
@property (nonatomic, assign) bool asyncPresent;
@property (nonatomic, assign) int8_t shaderType;
@property (nonatomic, assign) bool enableVSync;
@property (nonatomic, assign) bool enableShaderAccurate;
@property (nonatomic, assign) bool enableShaderJIT;
@property (nonatomic, assign) int8_t portraitType;
@property (nonatomic, assign) int8_t landscapeType;
@property (nonatomic, assign) int8_t volume;
@property (nonatomic, assign) bool stretchAudio;
@property (nonatomic, assign) bool swapScreen;
@property (nonatomic, assign) bool uprightScreen;
@property (nonatomic, assign) bool preloadTextures;
@property (nonatomic, assign) int8_t stereoRender;
@property (nonatomic, assign) int8_t threedFactor;
- (void) refreshScreenSize;
- (void) startVM:(UIView *)view;
- (void) setupControllers;
- (void) pollControllers;
- (void) setupView;
- (void) swap;
- (void) rotate;
- (void) gamepadEventOnPad:(int)player button:(int)button action:(int)action;
- (void) gamepadEventIrRecenter:(int)action;
- (BOOL) setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
-(void) controllerConnected:(NSNotification *)notification;
-(void) controllerDisconnected:(NSNotification *)notification;
-(void) optionUpdated:(NSNotification *)notification;
@end
extern __weak PVEmuThreeCore *_current;

// Options
#define MAP_MULTIPLAYER "Assign Controllers to Multiple Players"
