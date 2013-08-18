//
//  PVGenesisEmulatorCore.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, PVGenesisButton)
{
    PVGenesisButtonUp,
    PVGenesisButtonDown,
    PVGenesisButtonLeft,
    PVGenesisButtonRight,
    PVGenesisButtonA,
    PVGenesisButtonB,
    PVGenesisButtonC,
    PVGenesisButtonX,
    PVGenesisButtonY,
    PVGenesisButtonZ,
    PVGenesisButtonStart,
    PVGenesisButtonMode,
    PVGenesisButtonCount,
};

@class OERingBuffer;

@interface PVGenesisEmulatorCore : NSObject

- (void)startEmulation;
- (void)resetEmulation;
- (void)setPauseEmulation:(BOOL)flag;
- (BOOL)isEmulationPaused;
- (void)stopEmulation;
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

- (void)pushGenesisButton:(PVGenesisButton)button;
- (void)releaseGenesisButton:(PVGenesisButton)button;

@end
