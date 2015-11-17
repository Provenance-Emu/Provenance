//
//  PVGenesisEmulatorCore.m
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGenesisEmulatorCore.h"
#import "OERingBuffer.h"
#import "OETimingUtils.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>

@interface PVGenesisEmulatorCore ()
{
	uint16_t *_videoBuffer;
	int _videoWidth, _videoHeight;
	int16_t _pad[2][12];
}

@end

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
	//DLog(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
	//DLog(@"polled input: port: %d device: %d id: %d", port, device, id);
	
	__strong PVGenesisEmulatorCore *strongCurrent = _current;
    int16_t value = 0;

    if (port == 0 & device == RETRO_DEVICE_JOYPAD)
	{
        if (strongCurrent.controller1)
        {
            value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
        }

        if (value == 0)
        {
            value = strongCurrent->_pad[0][_id];
        }
	}
	else if(port == 1 & device == RETRO_DEVICE_JOYPAD)
	{
        if (strongCurrent.controller2)
        {
            value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
        }

        if (value == 0)
        {
            value = strongCurrent->_pad[1][_id];
        }
	}
	
	strongCurrent = nil;
	
	return value;
}

static bool environment_callback(unsigned cmd, void *data)
{
    __strong PVGenesisEmulatorCore *strongCurrent = _current;
    
	switch(cmd)
	{
		case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY :
		{
			NSString *appSupportPath = [strongCurrent BIOSPath];
			
			*(const char **)data = [appSupportPath UTF8String];
			DLog(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
			break;
		}
		case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
		{
			break;
		}
		default :
			DLog(@"Environ UNSUPPORTED (#%u).\n", cmd);
			return false;
	}
	
    strongCurrent = nil;
    
	return true;
}

- (id)init
{
	if ((self = [super init]))
	{
		_videoBuffer = malloc(320 * 480 * 2);
	}
	
	_current = self;
	
	return self;
}

- (void)dealloc
{
	free(_videoBuffer);
}

#pragma mark - Execution

- (void)resetEmulation
{
	retro_reset();
}

- (void)stopEmulation
{
	if ([self.batterySavesPath length])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:NULL];
		NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];
		[self writeSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
    }

	[super stopEmulation];
	
	double delayInSeconds = 0.1;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		retro_unload_game();
		retro_deinit();
	});
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
    self.romName = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
    
    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[path stringByStandardizingPath]];
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
            
            NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];
            
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
        DLog(@"Couldn't load save file.");
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
            DLog(@"Error writing save file");
        }
    }
}

#pragma mark - Video

- (const void *)videoBuffer
{
	return _videoBuffer;
}

- (CGRect)screenRect
{
	return CGRectMake(0, 0, _videoWidth, _videoHeight);
}

- (CGSize)aspectSize
{
	return CGSizeMake(4, 3);
}

- (CGSize)bufferSize
{
	return CGSizeMake(320, 480);
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
    return GL_RGB;
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

#pragma mark - Input

- (void)pushGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player
{
	_pad[player][button] = 1;
}

- (void)releaseGenesisButton:(PVGenesisButton)button forPlayer:(NSInteger)player
{
	_pad[player][button] = 0;
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player
{
    GCController *controller = nil;

    if (player == 0)
    {
        controller = self.controller1;
    }
    else
    {
        controller = self.controller2;
    }

    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *pad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVGenesisButtonUp:
                return [[dpad up] isPressed]?:[[[pad leftThumbstick] up] isPressed];
            case PVGenesisButtonDown:
                return [[dpad down] isPressed]?:[[[pad leftThumbstick] down] isPressed];
            case PVGenesisButtonLeft:
                return [[dpad left] isPressed]?:[[[pad leftThumbstick] left] isPressed];
            case PVGenesisButtonRight:
                return [[dpad right] isPressed]?:[[[pad leftThumbstick] right] isPressed];
            case PVGenesisButtonA:
                return [[pad buttonX] isPressed];
            case PVGenesisButtonB:
                return [[pad buttonA] isPressed];
            case PVGenesisButtonC:
                return [[pad buttonB] isPressed];
            case PVGenesisButtonX:
                return [[pad leftShoulder] isPressed];
            case PVGenesisButtonY:
                return [[pad buttonY] isPressed];
            case PVGenesisButtonZ:
                return [[pad rightShoulder] isPressed];
            case PVGenesisButtonStart:
                return [[pad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *pad = [controller gamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVGenesisButtonUp:
                return [[dpad up] isPressed];
            case PVGenesisButtonDown:
                return [[dpad down] isPressed];
            case PVGenesisButtonLeft:
                return [[dpad left] isPressed];
            case PVGenesisButtonRight:
                return [[dpad right] isPressed];
            case PVGenesisButtonA:
                return [[pad buttonX] isPressed];
            case PVGenesisButtonB:
                return [[pad buttonA] isPressed];
            case PVGenesisButtonC:
                return [[pad buttonB] isPressed];
            case PVGenesisButtonX:
                return [[pad leftShoulder] isPressed];
            case PVGenesisButtonY:
                return [[pad buttonY] isPressed];
            case PVGenesisButtonZ:
                return [[pad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *pad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [pad dpad];
        switch (buttonID) {
            case PVGenesisButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVGenesisButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVGenesisButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVGenesisButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVGenesisButtonA:
                return [[pad buttonA] isPressed];
                break;
            case PVGenesisButtonB:
                return [[pad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif

    return 0;
}

#pragma mark - State Saving

- (BOOL)saveStateToFileAtPath:(NSString *)path
{
    @synchronized(self) {
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
            DLog(@"Error saving state: %@", [error localizedDescription]);
            return NO;
        }
        
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path
{
    @synchronized(self) {
        NSData *saveStateData = [NSData dataWithContentsOfFile:path];
        if (!saveStateData)
        {
            DLog(@"Unable to load save state from path: %@", path);
            return NO;
        }
        
        if (!retro_unserialize([saveStateData bytes], [saveStateData length]))
        {
            DLog(@"Unable to load save state");
            return NO;
        }
        
        return YES;
    }
}

@end
