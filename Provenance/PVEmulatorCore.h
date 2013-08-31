//
//  PVEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OERingBuffer.h"

@interface PVEmulatorCore : NSObject {
	
	OERingBuffer __strong **ringBuffers;
	double _sampleRate;
	
	NSTimeInterval gameInterval;
	NSTimeInterval _frameInterval;

    BOOL isRunning;
    BOOL shouldStop;
	
}

@property (nonatomic, copy) NSString *romName;
@property (nonatomic, copy) NSString *batterySavesPath;
@property (atomic, assign) BOOL shouldResyncTime;

- (void)startEmulation;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag;
- (BOOL)isEmulationPaused;
- (void)stopEmulation;
- (void)frameRefreshThread:(id)anArgument;
- (void)executeFrame;
- (BOOL)loadFileAtPath:(NSString*)path;

- (uint16_t *)videoBuffer;
- (CGRect)screenRect;
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

- (BOOL)saveStateToFileAtPath:(NSString *)path;
- (BOOL)loadStateFromFileAtPath:(NSString *)path;

@end
