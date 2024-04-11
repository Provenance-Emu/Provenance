//
//  PVDolphinCore.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@interface PVDolphinCore : PVEmulatorCore
<PVGameCubeSystemResponderClient, PVWiiSystemResponderClient>
{
    uint8_t padData[4][PVDreamcastButtonCount];
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
@property (nonatomic, assign) bool isWii;
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;
@property (nonatomic, assign) int8_t resFactor;
@property (nonatomic, assign) int8_t gsPreference;
@property (nonatomic, assign) int8_t cpuType;
@property (nonatomic, assign) int8_t cpuOClock;
@property (nonatomic, assign) bool isBilinear;
@property (nonatomic, assign) int8_t msaa;
@property (nonatomic, assign) bool ssaa;
@property (nonatomic, assign) bool fastMemory;
@property (nonatomic, assign) bool enableCheatCode;
@property (nonatomic, assign) bool multiPlayer;
@property (nonatomic, assign) int8_t volume;
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
@end
extern __weak PVDolphinCore *_current;

// Options
#define MAP_MULTIPLAYER "Assign Controllers to Multiple Players"
