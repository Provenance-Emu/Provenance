//
//  PVGenesisEmulatorCore.m
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVGenesisEmulatorCore.h"
#import "libretro.h"
#import <OpenGLES/EAGL.h>

@interface PVGenesisEmulatorCore ()
{
	uint16_t *_videoBuffer;
	int _videoWidth, _videoHeight;
	int16_t _pad[2][12];
	NSString *_romName;
	double _sampleRate;
	NSTimeInterval _frameInterval;
}

@end

NSUInteger _GenesisEmulatorValues[] = { RETRO_DEVICE_ID_JOYPAD_UP, RETRO_DEVICE_ID_JOYPAD_DOWN, RETRO_DEVICE_ID_JOYPAD_LEFT, RETRO_DEVICE_ID_JOYPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_Y, RETRO_DEVICE_ID_JOYPAD_B, RETRO_DEVICE_ID_JOYPAD_A, RETRO_DEVICE_ID_JOYPAD_L, RETRO_DEVICE_ID_JOYPAD_X, RETRO_DEVICE_ID_JOYPAD_R, RETRO_DEVICE_ID_JOYPAD_START, RETRO_DEVICE_ID_JOYPAD_SELECT };
PVGenesisEmulatorCore *_current;

@implementation PVGenesisEmulatorCore

static void audio_callback(int16_t left, int16_t right)
{
//	[[current ringBufferAtIndex:0] write:&left maxLength:2];
//	[[current ringBufferAtIndex:0] write:&right maxLength:2];
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
//	[[current ringBufferAtIndex:0] write:data maxLength:frames << 2];
//	return frames;
	return 0;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    _current->_videoWidth  = width;
    _current->_videoHeight = height;
    
    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(height, the_queue, ^(size_t y){
        const uint16_t *src = (uint16_t*)data + y * (pitch >> 1); //pitch is in bytes not pixels
        uint16_t *dst = _current->_videoBuffer + y * 720;
        
        memcpy(dst, src, sizeof(uint16_t)*width);
    });
}

static void input_poll_callback(void)
{
	//NSLog(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
	//NSLog(@"polled input: port: %d device: %d id: %d", port, device, id);
	
	if (port == 0 & device == RETRO_DEVICE_JOYPAD) {
		return _current->_pad[0][_id];
	}
	else if(port == 1 & device == RETRO_DEVICE_JOYPAD) {
		return _current->_pad[1][_id];
	}
	
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
		_videoBuffer = malloc(720 * 576 * 4);
	}
	
	_current = self;
	
	return self;
}

- (void)dealloc
{
	free(_videoBuffer);
	[super dealloc];
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
    if(dataObj == nil) return false;
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
    
    if(retro_load_game(&info))
    {
//        NSString *path = _romName;
//        NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
//        
//        NSString *batterySavesDirectory = nil;//[self batterySavesDirectoryPath];
//        
//        if([batterySavesDirectory length] != 0)
//        {
//            [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
//            
//            NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
//            
//            loadSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
//        }
        
        struct retro_system_av_info info;
        retro_get_system_av_info(&info);
        
        _current->_frameInterval = info.timing.fps;
        _current->_sampleRate = info.timing.sample_rate;
        
        //retro_set_controller_port_device(SNES_PORT_1, RETRO_DEVICE_JOYPAD);
        
        retro_get_region();
        
        retro_run();
        
        return YES;
    }
    
    return NO;
}

#pragma mark Video
- (uint16_t *)videoBuffer
{
	return _videoBuffer;
}

- (CGRect)screenRect
{
	return CGRectMake(0, 0, _current->_videoWidth, _current->_videoHeight);
}

- (CGSize)bufferSize
{
	return CGSizeMake(720, 576);
}

- (void)setupEmulation
{
}

- (void)resetEmulation
{
	retro_reset();
}

- (void)stopEmulation
{
//    NSString *path = _romName;
//    NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
    
//    NSString *batterySavesDirectory = [self batterySavesDirectoryPath];
//    
//    if([batterySavesDirectory length] != 0)
//    {
//        
//        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
//        
//        NSLog(@"Trying to save SRAM");
//        
//        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
//        
//        writeSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
//    }
	
	retro_unload_game();
	retro_deinit();
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

- (double)audioSampleRate
{
    return _sampleRate ? _sampleRate : 48000;
}

- (NSTimeInterval)frameInterval
{
    return _frameInterval ? _frameInterval : 59.92;
}

- (NSUInteger)channelCount
{
    return 2;
}

@end
