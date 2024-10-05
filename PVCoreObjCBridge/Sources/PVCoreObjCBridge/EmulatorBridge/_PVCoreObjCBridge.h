//
//  PVEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#ifdef __cplusplus
#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#import <MetalKit/MTKView.h>
//@import PVCoreBridge;
#import <PVObjCUtils/PVObjCUtils.h>
#else
@import Foundation;
//@import PVCoreBridge;
@import PVObjCUtils;
#if !TARGET_OS_WATCH
@import GameController;
@import MetalKit.MTKView;
#endif
#endif

#if TARGET_OS_OSX
#ifdef __cplusplus
#import <OpenGL/OpenGL.h>
#else
@import OpenGL;
#endif
#endif

#pragma mark -

typedef void (^SaveStateCompletion)(BOOL, NSError * _Nullable );

/*!
 * @function GET_CURRENT_OR_RETURN
 * @abstract Fetch the current game core, or fail with given return code if there is none.
 */
#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@class OERingBuffer;
extern NSString * _Nonnull const PVEmulatorCoreErrorDomain;

typedef NS_ENUM(NSInteger, PVEmulatorCoreErrorCode) {
    PVEmulatorCoreErrorCodeCouldNotStart            = -1,
    PVEmulatorCoreErrorCodeCouldNotLoadRom          = -2,
    PVEmulatorCoreErrorCodeCouldNotLoadState        = -3,
    PVEmulatorCoreErrorCodeStateHasWrongSize        = -4,
    PVEmulatorCoreErrorCodeCouldNotSaveState        = -5,
    PVEmulatorCoreErrorCodeDoesNotSupportSaveStates = -6,
    PVEmulatorCoreErrorCodeMissingM3U               = -7,
    PVEmulatorCoreErrorCodeCouldNotLoadBIOS         = -8,
};

@protocol PVAudioDelegate;
//@required
//- (void)audioSampleRateDidChange;
//@end

//@protocol PVRenderDelegate
//
//@required
//- (void)startRenderingOnAlternateThread;
//- (void)didRenderFrameOnAlternateThread;
//
///*!
// * @property presentationFramebuffer
// * @discussion
// * 2D - Not used.
// * 3D - For cores which can directly render to a GL FBO or equivalent,
// * this will return the FBO which game pixels eventually go to. This
// * allows porting of cores that overwrite GL_DRAW_FRAMEBUFFER.
// */
//@property (nonatomic, readonly, nullable) id presentationFramebuffer;
//
//@optional
//@property (nonatomic, nullable, readonly) MTKView* mtlview;
//
//@end

enum GLESVersion : NSInteger;
@protocol PVRenderDelegate;
@protocol RingBufferProtocol;

enum GameSpeed : NSInteger;

typedef NS_ENUM(NSInteger, GameSpeed) {
  GameSpeedVerySlow = 0,
  GameSpeedSlow = 1,
  GameSpeedNormal = 2,
  GameSpeedFast = 3,
  GameSpeedVeryFast = 4,
};

@interface PVCoreObjCBridge : NSObject {

@public
    NSMutableArray<id<RingBufferProtocol>> *ringBuffers;

	double _sampleRate;

	NSTimeInterval gameInterval;
	NSTimeInterval _frameInterval;

    BOOL _isFrontBufferReady;

    BOOL _alwaysUseMetal;
    BOOL _isOn;

    GameSpeed _gameSpeed;

#if !TARGET_OS_WATCH
    GCController *_controller1;
    GCController *_controller2;
    GCController *_controller3;
    GCController *_controller4;
    GCController *_controller5;
    GCController *_controller6;
    GCController *_controller7;
    GCController *_controller8;
#endif

#if !TARGET_OS_OSX && !TARGET_OS_WATCH
//    UIViewController* _Nullable _touchViewController;
#endif
}

@property (nonatomic, copy, nullable) NSString *romName;
@property (nonatomic, copy, nullable) NSString *batterySavesPath;
@property (nonatomic, copy, nullable) NSString *BIOSPath;
@property (nonatomic, copy, nullable) NSString *systemIdentifier;
@property (nonatomic, copy, nullable) NSString *coreIdentifier;
@property (nonatomic, copy, nullable) NSString *romMD5;
@property (nonatomic, copy, nullable) NSString *romSerial;
@property (nonatomic, copy, nullable) NSString *screenType;


@property (class, retain, nonnull, nonatomic) NSString *systemName;
@property (class, retain, nonnull, nonatomic) NSString *coreClassName;

@property (atomic, assign) BOOL shouldResyncTime;

@property (nonatomic, assign) BOOL shouldStop;
@property (nonatomic, assign) BOOL skipEmulationLoop;
@property (nonatomic, assign) BOOL skipLayout;

@property (nonatomic, strong, readonly, nonnull) NSLock  *emulationLoopThreadLock;
@property (nonatomic, assign) BOOL extractArchive;

+ (void)setCoreClassName:(NSString *_Nullable)name;
+ (void)setSystemName:(NSString *_Nullable)name;

- (void)initialize;

//@end

//@protocol EmulatorCoreRumbleDataSource <EmulatorCoreControllerDataSource>
//@property (nonatomic, readonly) BOOL supportsRumble;
//@end

//@interface PVCoreObjCBridge (Rumble) //<EmulatorCoreRumbleDataSource>

@property (nonatomic, readonly) BOOL supportsRumble;

//@end

//@interface PVCoreObjCBridge (Runloop) // <EmulatorCoreRunLoop>

@property (atomic, assign, readonly) BOOL isRunning;

@property (nonatomic, assign) GameSpeed gameSpeed;
@property (nonatomic, readonly, getter=isSpeedModified) BOOL speedModified;

@property (nonatomic, readonly) BOOL isEmulationPaused;
@property (nonatomic, assign) BOOL isOn;

- (void)startEmulation NS_REQUIRES_SUPER;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag NS_REQUIRES_SUPER;
- (void)stopEmulationWithMessage:(NSString * _Nullable) message NS_REQUIRES_SUPER;
- (void)stopEmulation NS_REQUIRES_SUPER;
- (BOOL)loadFileAtPath:(NSString *)path
                 error:(NSError * __nullable __autoreleasing * __nullable) error;

//@end

//@interface PVCoreObjCBridge (Video) // <EmulatorCoreVideoDelegate>

@property (nonatomic, assign) BOOL alwaysUseMetal;

@property (nonatomic, assign) double emulationFPS;
@property (nonatomic, assign) double renderFPS;

@property(nonatomic, weak, nullable) id<PVRenderDelegate> renderDelegate;

@property (atomic, strong, readonly, nonnull) NSCondition  *frontBufferCondition;
@property (atomic, strong, readonly, nonnull) NSLock  *frontBufferLock;
@property (atomic, assign) BOOL isFrontBufferReady;

#if !TARGET_OS_WATCH
@property (nonatomic, assign) enum GLESVersion glesVersion;
@property (nonatomic, readonly) GLenum depthFormat;
@property (nonatomic, readonly) GLenum pixelFormat;
@property (nonatomic, readonly) GLenum pixelType;
@property (nonatomic, readonly) GLenum internalPixelFormat;
#endif

@property (nonatomic, readonly) CGRect screenRect;
@property (nonatomic, readonly) CGSize aspectSize;
@property (nonatomic, readonly) CGSize bufferSize;
@property (nonatomic, readonly) BOOL isDoubleBuffered;
@property (nonatomic, readonly) BOOL rendersToOpenGL;
@property (nonatomic, readonly) NSTimeInterval frameInterval;

@property (nonatomic, readonly, nullable) const void * videoBuffer;
- (void)swapBuffers;
- (void)executeFrame;
//@end

//@interface PVCoreObjCBridge (Controllers) // <EmulatorCoreControllerDataSource>

#if !TARGET_OS_OSX && !TARGET_OS_WATCH
@property (nonatomic, assign) UIViewController* _Nullable touchViewController;
#endif

#if !TARGET_OS_WATCH
@property (nonatomic, strong, nullable) GCController *controller1;
@property (nonatomic, strong, nullable) GCController *controller2;
@property (nonatomic, strong, nullable) GCController *controller3;
@property (nonatomic, strong, nullable) GCController *controller4;
@property (nonatomic, strong, nullable) GCController *controller5;
@property (nonatomic, strong, nullable) GCController *controller6;
@property (nonatomic, strong, nullable) GCController *controller7;
@property (nonatomic, strong, nullable) GCController *controller8;
#endif


/// Subclasses may impliment this for controller polling
- (void)updateControllers;

#if !TARGET_OS_OSX && !TARGET_OS_WATCH
- (void)sendEvent:(UIEvent *_Nullable)event;
#endif

//@end

//@interface PVCoreObjCBridge (Audio) //<EmulatorCoreAudioDataSource>

@property(weak, nullable, nonatomic) id<PVAudioDelegate> audioDelegate;

@property (nonatomic, readonly) double audioSampleRate;
@property (nonatomic, readonly) NSUInteger channelCount;
@property (nonatomic, readonly) NSUInteger audioBufferCount;
@property (nonatomic, readonly) NSUInteger audioBitDepth;

- (void)getAudioBuffer:(void * _Nonnull)buffer
            frameCount:(uint32_t)frameCount
           bufferIndex:(NSUInteger)index;

- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer;
- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer;
- (double)audioSampleRateForBuffer:(NSUInteger)buffer;
- (id<RingBufferProtocol>)ringBufferAtIndex:(NSUInteger)index;
//@end

//@interface PVCoreObjCBridge (Saves) // <EmulatorCoreSavesDataSource>

@property (nonatomic, copy, nullable) NSString *saveStatesPath;
@property (nonatomic, assign) BOOL supportsSaveStates;

- (BOOL)saveStateToFileAtPath:(NSString * _Nonnull)path
                        error:(NSError * __nullable * __nullable)error DEPRECATED_MSG_ATTRIBUTE("Use saveStateToFileAtPath:completionHandler: instead.");

- (BOOL)loadStateFromFileAtPath:(NSString *_Nonnull)path
                          error:(NSError * __nullable * __nullable)error DEPRECATED_MSG_ATTRIBUTE("Use loadStateFromFileAtPath:completionHandler: instead.");
typedef void (^SaveStateCompletion)(BOOL, NSError * _Nullable );

- (void)saveStateToFileAtPath:(NSString * _Nonnull)fileName
            completionHandler:(nonnull SaveStateCompletion)block;
- (void)loadStateFromFileAtPath:(NSString *_Nonnull )fileName
              completionHandler:(nonnull SaveStateCompletion)block;

@end
