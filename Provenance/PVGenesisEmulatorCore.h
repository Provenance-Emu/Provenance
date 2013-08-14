//
//  PVGenesisEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OERingBuffer;

@interface PVGenesisEmulatorCore : NSObject

- (void)executeFrame;
- (BOOL)loadFileAtPath:(NSString*)path;
- (uint16_t *)videoBuffer;
- (CGRect)screenRect;
- (CGSize)bufferSize;
- (void)setupEmulation;
- (void)resetEmulation;
- (void)stopEmulation;
- (GLenum)pixelFormat;
- (GLenum)pixelType;
- (GLenum)internalPixelFormat;
- (double)audioSampleRate;
- (NSTimeInterval)frameInterval;
- (NSUInteger)channelCount;
- (NSUInteger)audioBufferCount;
- (void)getAudioBuffer:(void *)buffer frameCount:(NSUInteger)frameCount bufferIndex:(NSUInteger)index;
- (NSUInteger)audioBitDepth;
- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer;
- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer;
- (double)audioSampleRateForBuffer:(NSUInteger)buffer;
- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index;

@end
