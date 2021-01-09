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
#else
@import Foundation;
@import GameController;
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
};

@protocol PVAudioDelegate
@required
- (void)audioSampleRateDidChange;
@end

@protocol PVRenderDelegate

@required
- (void)startRenderingOnAlternateThread;
- (void)didRenderFrameOnAlternateThread;
@end

@interface PVEmulatorCore : NSObject {
	
	OERingBuffer __strong **ringBuffers;

	double _sampleRate;
	
	NSTimeInterval gameInterval;
	NSTimeInterval _frameInterval;
    BOOL shouldStop;
}

@property (nonatomic, assign) double emulationFPS;
@property (nonatomic, assign) double renderFPS;

@property(weak, nullable)     id<PVAudioDelegate>    audioDelegate;
@property(weak, nullable)     id<PVRenderDelegate>   renderDelegate;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, copy, nullable) NSString *romName;
@property (nonatomic, copy, nullable) NSString *saveStatesPath;
@property (nonatomic, copy, nullable) NSString *batterySavesPath;
@property (nonatomic, copy, nullable) NSString *BIOSPath;
@property (nonatomic, copy, nullable) NSString *systemIdentifier;
@property (nonatomic, copy, nullable) NSString *coreIdentifier;
@property (nonatomic, copy, nullable) NSString* romMD5;
@property (nonatomic, copy, nullable) NSString* romSerial;
@property (nonatomic, assign) BOOL supportsSaveStates;
@property (nonatomic, readonly) BOOL supportsRumble;

@property (atomic, assign) BOOL shouldResyncTime;

typedef NS_ENUM(NSInteger, GameSpeed) {
	GameSpeedSlow = 0,
	GameSpeedNormal,
	GameSpeedFast
};

typedef NS_ENUM(NSInteger, GLESVersion) {
	GLESVersion1,
	GLESVersion2,
	GLESVersion3
};

@property (nonatomic, assign) GameSpeed gameSpeed;
@property (nonatomic, readonly, getter=isSpeedModified) BOOL speedModified;

@property (nonatomic, strong, nullable) GCController *controller1;
@property (nonatomic, strong, nullable) GCController *controller2;
@property (nonatomic, strong, nullable) GCController *controller3;
@property (nonatomic, strong, nullable) GCController *controller4;

@property (nonatomic, strong, readonly, nonnull) NSLock  *emulationLoopThreadLock;
@property (nonatomic, strong, readonly, nonnull) NSCondition  *frontBufferCondition;
@property (nonatomic, strong, readonly, nonnull) NSLock  *frontBufferLock;
@property (nonatomic, assign) BOOL isFrontBufferReady;
@property (nonatomic, assign) GLESVersion glesVersion;
@property (nonatomic, readonly) GLenum depthFormat;

@property (nonatomic, readonly) CGRect screenRect;
@property (nonatomic, readonly) CGSize aspectSize;
@property (nonatomic, readonly) CGSize bufferSize;
@property (nonatomic, readonly) BOOL isDoubleBuffered;
@property (nonatomic, readonly) BOOL rendersToOpenGL;
@property (nonatomic, readonly) GLenum pixelFormat;
@property (nonatomic, readonly) GLenum pixelType;
@property (nonatomic, readonly) GLenum internalPixelFormat;
@property (nonatomic, readonly) NSTimeInterval frameInterval;
@property (nonatomic, readonly) double audioSampleRate;
@property (nonatomic, readonly) NSUInteger channelCount;
@property (nonatomic, readonly) NSUInteger audioBufferCount;
@property (nonatomic, readonly) NSUInteger audioBitDepth;
@property (nonatomic, readonly) BOOL isEmulationPaused;
@property (nonatomic, readonly, nullable) const void * videoBuffer;

- (void)startEmulation NS_REQUIRES_SUPER;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag NS_REQUIRES_SUPER;
- (void)stopEmulation NS_REQUIRES_SUPER;
- (void)executeFrame;
- (BOOL)loadFileAtPath:(NSString * _Nonnull)path
                 error:(NSError * __nullable * __nullable)error;
- (void)updateControllers;

- (void)swapBuffers;

- (void)getAudioBuffer:(void * _Nonnull)buffer
            frameCount:(NSUInteger)frameCount
           bufferIndex:(NSUInteger)index;

- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer;
- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer;
- (double)audioSampleRateForBuffer:(NSUInteger)buffer;
- (OERingBuffer * _Nonnull)ringBufferAtIndex:(NSUInteger)index;

- (BOOL)saveStateToFileAtPath:(NSString * _Nonnull)path
                        error:(NSError * __nullable * __nullable)error DEPRECATED_MSG_ATTRIBUTE("Use saveStateToFileAtPath:completionHandler: instead.");

- (BOOL)loadStateFromFileAtPath:(NSString *_Nonnull)path
                          error:(NSError * __nullable * __nullable)error DEPRECATED_MSG_ATTRIBUTE("Use loadStateFromFileAtPath:completionHandler: instead.");

- (void)saveStateToFileAtPath:(NSString * _Nonnull)fileName
            completionHandler:(nonnull SaveStateCompletion)block;
- (void)loadStateFromFileAtPath:(NSString *_Nonnull )fileName
              completionHandler:(nonnull SaveStateCompletion)block;

- (void)rumble;
@end
