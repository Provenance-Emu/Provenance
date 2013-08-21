//
//  PVGenesisEmulatorCore.m
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGenesisEmulatorCore.h"
#import "libretro.h"
#import "OERingBuffer.h"
#import "OETimingUtils.h"
#import <OpenGLES/EAGL.h>

@interface PVGenesisEmulatorCore ()
{
	uint16_t *_videoBuffer;
	int _videoWidth, _videoHeight;
	int16_t _pad[2][12];
	NSString *_romName;
	
	OERingBuffer __strong **ringBuffers;
	double _sampleRate;
	
	NSThread *emulationThread;
	NSTimeInterval gameInterval;
	NSTimeInterval _frameInterval;
	
	NSUInteger frameSkip;
    NSUInteger frameCounter;
    NSUInteger autoFrameSkipLastTime;
    NSUInteger frameskipadjust;
	
	BOOL frameFinished;
    BOOL willSkipFrame;
	
    BOOL isRunning;
    BOOL shouldStop;
}

@end

NSUInteger _GenesisEmulatorValues[] = { RETRO_DEVICE_ID_JOYPAD_UP, RETRO_DEVICE_ID_JOYPAD_DOWN, RETRO_DEVICE_ID_JOYPAD_LEFT, RETRO_DEVICE_ID_JOYPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_Y, RETRO_DEVICE_ID_JOYPAD_B, RETRO_DEVICE_ID_JOYPAD_A, RETRO_DEVICE_ID_JOYPAD_L, RETRO_DEVICE_ID_JOYPAD_X, RETRO_DEVICE_ID_JOYPAD_R, RETRO_DEVICE_ID_JOYPAD_START, RETRO_DEVICE_ID_JOYPAD_SELECT };
__weak PVGenesisEmulatorCore *_current;

@implementation PVGenesisEmulatorCore

static void audio_callback(int16_t left, int16_t right)
{
	__strong PVGenesisEmulatorCore *strongCurrent = _current;
	
	[[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
	[[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];
	
	strongCurrent = nil;
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
	__strong PVGenesisEmulatorCore *strongCurrent = _current;
	
	[[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames << 2];
	
	strongCurrent = nil;
	
	return frames;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
	__strong PVGenesisEmulatorCore *strongCurrent = _current;
	
    strongCurrent->_videoWidth  = width;
    strongCurrent->_videoHeight = height;
    
    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(height, the_queue, ^(size_t y){
        const uint16_t *src = (uint16_t*)data + y * (pitch >> 1); //pitch is in bytes not pixels
        uint16_t *dst = strongCurrent->_videoBuffer + y * 320;
        
        memcpy(dst, src, sizeof(uint16_t)*width);
    });
	
	strongCurrent = nil;
}

static void input_poll_callback(void)
{
	//NSLog(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
	//NSLog(@"polled input: port: %d device: %d id: %d", port, device, id);
	
	__strong PVGenesisEmulatorCore *strongCurrent = _current;
	
	if (port == 0 & device == RETRO_DEVICE_JOYPAD)
	{
		return strongCurrent->_pad[0][_id];
	}
	else if(port == 1 & device == RETRO_DEVICE_JOYPAD)
	{
		return strongCurrent->_pad[1][_id];
	}
	
	strongCurrent = nil;
	
	return 0;
}

static bool environment_callback(unsigned cmd, void *data)
{
	switch(cmd)
	{
		case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY :
		{
			// FIXME: Build a path in a more appropriate place
			NSString *appSupportPath = [NSString pathWithComponents:@[
										[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
										@"BIOS"]];
			
			*(const char **)data = [appSupportPath UTF8String];
			NSLog(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
			break;
		}
		case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
		{
			break;
		}
		default :
			NSLog(@"Environ UNSUPPORTED (#%u).\n", cmd);
			return false;
	}
	
	return true;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		_videoBuffer = malloc(320 * 224 * 2);
		NSUInteger count = [self audioBufferCount];
        ringBuffers = (__strong OERingBuffer **)calloc(count, sizeof(OERingBuffer *));
	}
	
	_current = self;
	
	return self;
}

- (void)dealloc
{
	for (NSUInteger i = 0, count = [self audioBufferCount]; i < count; i++)
	{
		ringBuffers[i] = nil;
	}
	
    free(ringBuffers);
	free(_videoBuffer);
}

#pragma mark - Execution

- (void)startEmulation
{
	if (!isRunning)
	{
		isRunning  = YES;
		shouldStop = NO;
		
		[NSThread detachNewThreadSelector:@selector(frameRefreshThread:) toTarget:self withObject:nil];
	}
}

- (void)resetEmulation
{
	retro_reset();
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
	if ([self.batterySavesPath length])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:NULL];
		
		NSString *extensionlessFilename = [[[_romName lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
		NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
		[self writeSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
    }

	shouldStop = YES;
    isRunning  = NO;
	
	double delayInSeconds = 0.1;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		retro_unload_game();
		retro_deinit();
	});
}

- (void)frameRefreshThread:(id)anArgument
{
    gameInterval = 1./[self frameInterval];
    NSTimeInterval gameTime = OEMonotonicTime();
	
    frameFinished = YES;
    willSkipFrame = NO;
    frameSkip = 0;
	
    OESetThreadRealtime(gameInterval, .007, .03); // guessed from bsnes
    while (!shouldStop)
    {
        gameTime += gameInterval;
        @autoreleasepool
        {			
            willSkipFrame = (frameCounter != frameSkip);
			
            if (isRunning)
            {
				[self executeFrame];
            }
			
            if (frameCounter >= frameSkip)
			{
				frameCounter = 0;
			}
            else
			{
				frameCounter++;
			}
        }
		
        OEWaitUntil(gameTime);
    }
}

- (void)executeFrame
{
	retro_run();
}

- (BOOL)loadFileAtPath:(NSString*)path
{
	memset(_pad, 0, sizeof(int16_t) * 10);
    
    const void *data;
    size_t size;
    _romName = [path copy];
    
    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[_romName stringByStandardizingPath]];
    if (dataObj == nil)
	{
		return false;
	}
    size = [dataObj length];
    data = (uint8_t*)[dataObj bytes];
    const char *meta = NULL;
    
    retro_set_environment(environment_callback);
	retro_init();
	
    retro_set_audio_sample(audio_callback);
    retro_set_audio_sample_batch(audio_batch_callback);
    retro_set_video_refresh(video_callback);
    retro_set_input_poll(input_poll_callback);
    retro_set_input_state(input_state_callback);
    
    const char *fullPath = [path UTF8String];
    
    struct retro_game_info info = {NULL};
    info.path = fullPath;
    info.data = data;
    info.size = size;
    info.meta = meta;
    
    if (retro_load_game(&info))
    {
        if ([self.batterySavesPath length])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:NULL];
            
			NSString *extensionlessFilename = [[[_romName lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
            NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
            
            [self loadSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
        }
        
        struct retro_system_av_info info;
        retro_get_system_av_info(&info);
        
        _frameInterval = info.timing.fps;
        _sampleRate = info.timing.sample_rate;
        
        retro_get_region();
        retro_run();
        
        return YES;
    }
    
    return NO;
}

- (void)loadSaveFile:(NSString *)path forType:(int)type
{
	size_t size = retro_get_memory_size(type);
	void *ramData = retro_get_memory_data(type);
	
	if (size == 0 || !ramData)
	{
		return;
	}
	
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data || ![data length])
	{
		NSLog(@"Couldn't load save file.");
	}
	
	[data getBytes:ramData length:size];
}

- (void)writeSaveFile:(NSString *)path forType:(int)type
{
    size_t size = retro_get_memory_size(type);
    void *ramData = retro_get_memory_data(type);
    
    if (ramData && (size > 0))
    {
		retro_serialize(ramData, size);
		NSData *data = [NSData dataWithBytes:ramData length:size];
		BOOL success = [data writeToFile:path atomically:YES];
		if (!success)
		{
			NSLog(@"Error writing save file");
		}
    }
}

#pragma mark - Video

- (uint16_t *)videoBuffer
{
	return _videoBuffer;
}

- (CGRect)screenRect
{
	return CGRectMake(0, 0, _videoWidth, _videoHeight);
}

- (CGSize)bufferSize
{
	return CGSizeMake(320, 224);
}

- (GLenum)pixelFormat
{
    return GL_RGB;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB565;
}

- (NSTimeInterval)frameInterval
{
    return _frameInterval ? _frameInterval : 59.92;
}

#pragma mark - Audio

- (double)audioSampleRate
{
    return _sampleRate ? _sampleRate : 48000;
}

- (NSUInteger)channelCount
{
    return 2;
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
	return [self channelCount];
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
    return [self audioSampleRate];
}

- (OERingBuffer *)ringBufferAtIndex:(NSUInteger)index
{
    if (ringBuffers[index] == nil)
	{
        ringBuffers[index] = [[OERingBuffer alloc] initWithLength:[self audioBufferSizeForBuffer:index] * 16];
	}
	
    return ringBuffers[index];
}

#pragma mark - Input

- (void)pushGenesisButton:(PVGenesisButton)button
{
	_pad[0][_GenesisEmulatorValues[button]] = 1;
}

- (void)releaseGenesisButton:(PVGenesisButton)button
{
	_pad[0][_GenesisEmulatorValues[button]] = 0;
}

#pragma mark - State Saving

- (BOOL)saveStateToFileAtPath:(NSString *)path
{
	int serial_size = retro_serialize_size();
    uint8_t *serial_data = (uint8_t *) malloc(serial_size);
    
    retro_serialize(serial_data, serial_size);
	
	NSError *error = nil;
	NSData *saveStateData = [NSData dataWithBytes:serial_data length:serial_size];
	free(serial_data);
	[saveStateData writeToFile:path
					   options:NSDataWritingAtomic
						 error:&error];
	if (error)
	{
		NSLog(@"Error saving state: %@", [error localizedDescription]);
		return NO;
	}
	
	return YES;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path
{
	NSData *saveStateData = [NSData dataWithContentsOfFile:path];
	if (!saveStateData)
	{
		NSLog(@"Unable to load save state from path: %@", path);
		return NO;
	}
	
	if (!retro_unserialize([saveStateData bytes], [saveStateData length]))
	{
		NSLog(@"Unable to load save state");
		return NO;
	}
	
	return YES;
}

@end
