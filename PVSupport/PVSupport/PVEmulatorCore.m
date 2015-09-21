//
//  PVEmulatorCore.m
//  Provenance
//
//  Created by James Addyman on 31/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorCore.h"
#import "NSObject+PVAbstractAdditions.h"
#import <mach/mach_time.h>
static Class PVEmulatorCoreClass = Nil;
static NSTimeInterval defaultFrameInterval = 60.0;

@implementation PVEmulatorCore

+ (void)initialize
{
    if(self == [PVEmulatorCore class])
    {
        PVEmulatorCoreClass = [PVEmulatorCore class];
    }
}

- (id)init
{
	if ((self = [super init]))
	{
		NSUInteger count = [self audioBufferCount];
        ringBuffers = (__strong OERingBuffer **)calloc(count, sizeof(OERingBuffer *));
	}
	
	return self;
}

- (void)dealloc
{
    [self stopEmulation];

	for (NSUInteger i = 0, count = [self audioBufferCount]; i < count; i++)
	{
		ringBuffers[i] = nil;
	}
	
    free(ringBuffers);
}

#pragma mark - Execution

- (void)startEmulation
{
	if([self class] != PVEmulatorCoreClass)
    {
		if (!isRunning)
		{
			isRunning  = YES;
			shouldStop = NO;
			
			[NSThread detachNewThreadSelector:@selector(frameRefreshThread:) toTarget:self withObject:nil];
		}
	}
}

- (void)resetEmulation
{
	[self doesNotImplementSelector:_cmd];
}

- (void)setPauseEmulation:(BOOL)flag
{
    if (flag)
	{
		isRunning = NO;
	}
    else
	{
		isRunning = YES;
	}
}

- (BOOL)isEmulationPaused
{
    return !isRunning;
}

- (void)stopEmulation
{
	shouldStop = YES;
    isRunning  = NO;
}

- (void)frameRefreshThread:(id)anArgument
{
	[self doesNotImplementSelector:_cmd];
}

- (void)executeFrame
{
	[self doesNotImplementOptionalSelector:_cmd];
}

- (BOOL)loadFileAtPath:(NSString*)path
{
	[self doesNotImplementSelector:_cmd];
	return NO;
}

#pragma mark - Video

- (const void *)videoBuffer
{
	[self doesNotImplementSelector:_cmd];
	return NULL;
}

- (CGRect)screenRect
{
	[self doesNotImplementSelector:_cmd];
	return CGRectZero;
}

- (CGSize)aspectSize
{
	[self doesNotImplementSelector:_cmd];
	return CGSizeZero;
}

- (CGSize)bufferSize
{
	[self doesNotImplementSelector:_cmd];
	return CGSizeZero;
}

- (GLenum)pixelFormat
{
	[self doesNotImplementSelector:_cmd];
	return 0;
}

- (GLenum)pixelType
{
	[self doesNotImplementSelector:_cmd];
	return 0;
}

- (GLenum)internalPixelFormat
{
	[self doesNotImplementSelector:_cmd];
	return 0;
}

- (NSTimeInterval)frameInterval
{
	return defaultFrameInterval;
}

#pragma mark - Audio

- (double)audioSampleRate
{
	[self doesNotImplementSelector:_cmd];
	return 0;
}

- (NSUInteger)channelCount
{
	[self doesNotImplementSelector:_cmd];
	return 0;
}

- (NSUInteger)audioBufferCount
{
	return 1;
}

- (void)getAudioBuffer:(void *)buffer frameCount:(NSUInteger)frameCount bufferIndex:(NSUInteger)index
{
	[[self ringBufferAtIndex:index] read:buffer maxLength:frameCount * [self channelCountForBuffer:index] * sizeof(UInt16)];
}

- (NSUInteger)audioBitDepth
{
	return 16;
}

- (NSUInteger)channelCountForBuffer:(NSUInteger)buffer
{
	if (buffer == 0)
	{
		return [self channelCount];
	}
	
	DLog(@"Buffer counts greater than 1 must implement %@", NSStringFromSelector(_cmd));
	[self doesNotImplementSelector:_cmd];
	
	return 0;
}

- (NSUInteger)audioBufferSizeForBuffer:(NSUInteger)buffer
{
	// 4 frames is a complete guess
    double frameSampleCount = [self audioSampleRateForBuffer:buffer] / [self frameInterval];
    NSUInteger channelCount = [self channelCountForBuffer:buffer];
    NSUInteger bytesPerSample = [self audioBitDepth] / 8;
    NSAssert(frameSampleCount, @"frameSampleCount is 0");
    return channelCount*bytesPerSample * frameSampleCount;
}

- (double)audioSampleRateForBuffer:(NSUInteger)buffer
{
	if(buffer == 0)
	{
		return [self audioSampleRate];
	}
	
    DLog(@"Buffer count is greater than 1, must implement %@", NSStringFromSelector(_cmd));
    [self doesNotImplementSelector:_cmd];
    return 0;
}

- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index
{
	if (ringBuffers[index] == nil)
	{
        ringBuffers[index] = [[OERingBuffer alloc] initWithLength:[self audioBufferSizeForBuffer:index] * 16];
	}
	
    return ringBuffers[index];
}

#pragma mark - Save States

- (BOOL)saveStateToFileAtPath:(NSString *)path
{
	[self doesNotImplementSelector:_cmd];
	return NO;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path
{
	[self doesNotImplementSelector:_cmd];
	return NO;
}

- (void)loadSaveFile:(NSString *)path forType:(int)type
{
	[self doesNotImplementSelector:_cmd];
}

- (void)writeSaveFile:(NSString *)path forType:(int)type
{
	[self doesNotImplementSelector:_cmd];
}

@end
