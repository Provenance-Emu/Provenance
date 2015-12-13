//
//  PVEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OERingBuffer.h"
#import <GameController/GameController.h>

@interface PVEmulatorCore : NSObject {
	
	OERingBuffer __strong **ringBuffers;
	double _sampleRate;
	
	NSTimeInterval gameInterval;
	NSTimeInterval _frameInterval;

    BOOL isRunning;
    BOOL shouldStop;

    double framerateMultiplier;

}

@property (nonatomic, copy) NSString *romName;
@property (nonatomic, copy) NSString *saveStatesPath;
@property (nonatomic, copy) NSString *batterySavesPath;
@property (nonatomic, copy) NSString *BIOSPath;
@property (atomic, assign) BOOL shouldResyncTime;
@property (nonatomic, assign) BOOL fastForward;

@property (nonatomic, strong) GCController *controller1;
@property (nonatomic, strong) GCController *controller2;

- (void)startEmulation;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag;
- (BOOL)isEmulationPaused;
- (void)stopEmulation;
- (void)frameRefreshThread:(id)anArgument;
- (void)executeFrame;
- (BOOL)loadFileAtPath:(NSString*)path;

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
