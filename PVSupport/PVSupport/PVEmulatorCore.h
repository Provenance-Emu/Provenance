//
//  PVEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <PVSupport/OERingBuffer.h>

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
};

#define GetSecondsSince(x) (-[x timeIntervalSinceNow])

@interface PVEmulatorCore : NSObject {
	
	OERingBuffer __strong **ringBuffers;

	double _sampleRate;
	
	NSTimeInterval gameInterval;
	NSTimeInterval _frameInterval;

    BOOL isRunning;
    BOOL shouldStop;
}

@property (nonatomic, assign) double emulationFPS;

@property (nonatomic, copy) NSString *romName;
@property (nonatomic, copy) NSString *saveStatesPath;
@property (nonatomic, copy) NSString *batterySavesPath;
@property (nonatomic, copy) NSString *BIOSPath;
@property (atomic, assign) BOOL shouldResyncTime;

typedef NS_ENUM(NSInteger, GameSpeed) {
	GameSpeedSlow = 0,
	GameSpeedNormal,
	GameSpeedFast
};
@property (nonatomic, assign) GameSpeed gameSpeed;
@property (nonatomic, readonly, getter=isSpeedModified) BOOL speedModified;

@property (nonatomic, strong) GCController *controller1;
@property (nonatomic, strong) GCController *controller2;

@property (nonatomic, strong) NSLock  *emulationLoopThreadLock;

- (void)startEmulation;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag;
- (BOOL)isEmulationPaused;
- (void)stopEmulation;
- (void)frameRefreshThread:(id)anArgument;
- (void)executeFrame;
- (BOOL)loadFileAtPath:(NSString*)path;
- (void)updateControllers;

- (BOOL)supportsDiskSwapping;
- (void)swapDisk;

- (const void *)videoBuffer;
- (CGRect)screenRect;
- (CGSize)aspectSize;
- (CGSize)bufferSize;
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

- (void)loadSaveFile:(NSString *)path forType:(int)type;
- (void)writeSaveFile:(NSString *)path forType:(int)type;

- (BOOL)autoSaveState;
- (BOOL)saveStateToFileAtPath:(NSString *)path;
- (BOOL)loadStateFromFileAtPath:(NSString *)path;

@end
