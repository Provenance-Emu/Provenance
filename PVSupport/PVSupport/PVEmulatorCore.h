//
//  PVEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameController/GameController.h>

#pragma mark -

/*!
 * @function GET_CURRENT_OR_RETURN
 * @abstract Fetch the current game core, or fail with given return code if there is none.
 */
#define GET_CURRENT_OR_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@class OERingBuffer;
extern NSString *const PVEmulatorCoreErrorDomain;

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

@property(weak)     id<PVAudioDelegate>    audioDelegate;
@property(weak)     id<PVRenderDelegate>   renderDelegate;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, copy) NSString *romName;
@property (nonatomic, copy) NSString *saveStatesPath;
@property (nonatomic, copy) NSString *batterySavesPath;
@property (nonatomic, copy) NSString *BIOSPath;
@property (nonatomic, copy) NSString *systemIdentifier;
@property (nonatomic, copy) NSString *coreIdentifier;
@property (nonatomic, strong) NSString* romMD5;
@property (nonatomic, strong) NSString* romSerial;
@property (nonatomic, assign) BOOL supportsSaveStates;

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

@property (nonatomic, strong) GCController *controller1;
@property (nonatomic, strong) GCController *controller2;
@property (nonatomic, strong) GCController *controller3;
@property (nonatomic, strong) GCController *controller4;

@property (nonatomic, strong) NSLock  *emulationLoopThreadLock;
@property (nonatomic, strong) NSCondition  *frontBufferCondition;
@property (nonatomic, strong) NSLock  *frontBufferLock;
@property (nonatomic, assign) BOOL isFrontBufferReady;
@property (nonatomic, assign) GLESVersion glesVersion;

- (BOOL)rendersToOpenGL;
- (void)startEmulation;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag;
- (BOOL)isEmulationPaused;
- (void)stopEmulation;
- (void)frameRefreshThread:(id)anArgument;
- (void)executeFrame;
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error;
- (void)updateControllers;

- (const void *)videoBuffer;
- (CGRect)screenRect;
- (CGSize)aspectSize;
- (CGSize)bufferSize;
- (BOOL)isDoubleBuffered;
- (void)swapBuffers;
- (GLenum)pixelFormat;
- (GLenum)pixelType;
- (GLenum)internalPixelFormat;
- (NSTimeInterval)frameInterval;

- (double)audioSampleRate;
- (NSUInteger)channelCount;
- (NSUInteger)audioBufferCount;
- (void)getAudioBuffer:(void *)buffer frameCount:(NSUInteger)frameCount bufferIndex:(NSUInteger)index;
- (NSUInteger)audioBitDepth;
- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer;
- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer;
- (double)audioSampleRateForBuffer:(NSUInteger)buffer;
- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index;

- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error;
- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error;

@end
