/*
 Copyright (c) 2013, OpenEmu Team
 

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PVStellaGameCore.h"

#import <PVSupport/OERingBuffer.h>
#import <PVSupport/DebugUtils.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#include "libretro.h"

// Size and screen buffer consants
typedef                         uint32_t     stellabuffer_t;
#define STELLA_PITCH_SHIFT      2
#define STELLA_PIXEL_TYPE       GL_UNSIGNED_BYTE
#define STELLA_PIXEL_FORMAT     GL_BGRA
#define STELLA_INTERNAL_FORMAT  GL_RGBA

const NSUInteger A2600EmulatorValues[] = {
    RETRO_DEVICE_ID_JOYPAD_UP,
    RETRO_DEVICE_ID_JOYPAD_DOWN,
    RETRO_DEVICE_ID_JOYPAD_LEFT,
    RETRO_DEVICE_ID_JOYPAD_RIGHT,
    RETRO_DEVICE_ID_JOYPAD_B,
    RETRO_DEVICE_ID_JOYPAD_L,
    RETRO_DEVICE_ID_JOYPAD_L2,
    RETRO_DEVICE_ID_JOYPAD_R,
    RETRO_DEVICE_ID_JOYPAD_R2,
    RETRO_DEVICE_ID_JOYPAD_START,
    RETRO_DEVICE_ID_JOYPAD_SELECT
};

#define NUMBER_OF_PADS 2
#define NUMBER_OF_PAD_INPUTS 16

@interface PVStellaGameCore () {
    stellabuffer_t *_videoBuffer;
    int _videoWidth, _videoHeight;
    int16_t _pad[NUMBER_OF_PADS][NUMBER_OF_PAD_INPUTS];
}

@end

static __weak PVStellaGameCore *_current;

@implementation PVStellaGameCore

#pragma mark - Static callbacks
static void audio_callback(int16_t left, int16_t right) {
    __strong PVStellaGameCore *strongCurrent = _current;

	[[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];
    
    strongCurrent = nil;
}

static size_t audio_batch_callback(const int16_t *data, size_t frames) {
    __strong PVStellaGameCore *strongCurrent = _current;

    [[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames << 2];
    
    strongCurrent = nil;
    
    return frames;
}

static dispatch_queue_t memcpy_queue =
dispatch_queue_create("stella memcpy queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0));

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch) {
    __strong PVStellaGameCore *strongCurrent = _current;

    strongCurrent->_videoWidth  = width;
    strongCurrent->_videoHeight = height;
    
    dispatch_apply(height, memcpy_queue, ^(size_t y) {
        const stellabuffer_t *src = (stellabuffer_t*)data + y * (pitch >> STELLA_PITCH_SHIFT); //pitch is in bytes not pixels
        
        //uint16_t *dst = current->videoBuffer + y * current->videoWidth;
        stellabuffer_t *dst = strongCurrent->_videoBuffer + y * strongCurrent->_videoWidth;
        
        memcpy(dst, src, sizeof(stellabuffer_t)*width);
    });
    
    strongCurrent = nil;
}

static void input_poll_callback(void) {
	//DLOG(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
//    NSLog(@"polled input: port: %d device: %d id: %d", port, device, _id);
    
    __strong PVStellaGameCore *strongCurrent = _current;
    int16_t value = 0;
    
    if (port == 0 & device == RETRO_DEVICE_JOYPAD)
    {
        value = strongCurrent->_pad[0][_id];
    }
    else if(port == 1 & device == RETRO_DEVICE_JOYPAD)
    {
        if (value == 0)
        {
            value = strongCurrent->_pad[1][_id];
        }
    }
    
    strongCurrent = nil;
    
    return value;
}

static bool environment_callback(unsigned cmd, void *data) {
    __strong PVStellaGameCore *strongCurrent = _current;
    
    switch(cmd) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent BIOSPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
//            *(retro_pixel_format *)data = RETRO_PIXEL_FORMAT_0RGB1555;
            break;
        }
        default : {
            DLOG(@"Environ UNSUPPORTED (#%u).\n", cmd);
            return false;
        }
    }
    
    strongCurrent = nil;
    
    return true;
}


static void loadSaveFile(const char* path, int type) {
    FILE *file;
    
    file = fopen(path, "rb");
    if ( !file ) {
        return;
    }
    
    size_t size = stella_retro_get_memory_size(type);
    void *data  = stella_retro_get_memory_data(type);
    
    if (size == 0 || !data) {
        fclose(file);
        return;
    }
    
    int rc = fread(data, sizeof(uint8_t), size, file);
    if ( rc != size ) {
        DLOG(@"Couldn't load save file.");
    }
    
    DLOG(@"Loaded save file: %s", path);
    fclose(file);
}

static void writeSaveFile(const char* path, int type)
{
    size_t size = stella_retro_get_memory_size(type);
    void *data = stella_retro_get_memory_data(type);
    
    if ( data && size > 0 )
    {
        FILE *file = fopen(path, "wb");
        if ( file != NULL )
        {
            DLOG(@"Saving state %s. Size: %d bytes.", path, (int)size);
            stella_retro_serialize(data, size);
            if ( fwrite(data, sizeof(uint8_t), size, file) != size )
                DLOG(@"Did not save state properly.");
            fclose(file);
        }
    }
}

- (id)init
{
    if((self = [super init]))
    {
        if(_videoBuffer)
            free(_videoBuffer);
        _videoBuffer = (stellabuffer_t*)malloc(160 * 256 * 4);
    }
    
	_current = self;
    
	return self;
}

#pragma mark Exectuion

- (void)executeFrame
{
    if (self.controller1 || self.controller2) {
        [self pollControllers];
    }
    stella_retro_run();
}

- (void)executeFrameSkippingFrame: (BOOL) skip
{
    stella_retro_run();
}

- (BOOL)loadFileAtPath: (NSString*) path
{
	memset(_pad, 0, sizeof(int16_t) * NUMBER_OF_PADS * NUMBER_OF_PAD_INPUTS);
    
    const void *data;
    size_t size;
    self.romName = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0]; //[path copy];
    
    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[path stringByStandardizingPath]];
    if(dataObj == nil) return false;
    size = [dataObj length];
    data = (uint8_t*)[dataObj bytes];
    const char *meta = NULL;
    
    //memory.copy(data, size);
    stella_retro_set_environment(environment_callback);
	stella_retro_init();
	
    stella_retro_set_audio_sample(audio_callback);
    stella_retro_set_audio_sample_batch(audio_batch_callback);
    stella_retro_set_video_refresh(video_callback);
    stella_retro_set_input_poll(input_poll_callback);
    stella_retro_set_input_state(input_state_callback);
    
    
    const char *fullPath = [path UTF8String];
    
    struct retro_game_info info = {NULL};
    info.path = fullPath;
    info.data = data;
    info.size = size;
    info.meta = meta;
    
    if (stella_retro_load_game(&info))
    {
        if ([self.batterySavesPath length])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:NULL];
            
            NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];
            
            [self loadSaveFile:filePath forType:RETRO_MEMORY_SAVE_RAM];
        }
        
        struct retro_system_av_info info;
        stella_retro_get_system_av_info(&info);
        
        _frameInterval = info.timing.fps;
        _sampleRate = info.timing.sample_rate;
        
        stella_retro_get_region();
        stella_retro_run();
        
        return YES;
    }
    
    return NO;
}

- (BOOL)loadSaveFile:(NSString *)path forType:(int)type
{
    size_t size = stella_retro_get_memory_size(type);
    void *ramData = stella_retro_get_memory_data(type);
    
    if (size == 0 || !ramData)
    {
        return NO;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data || ![data length])
    {
        DLOG(@"Couldn't load save file.");
		return NO;
    }
    
    [data getBytes:ramData length:size];
	return YES;
}

- (BOOL)writeSaveFile:(NSString *)path forType:(int)type {
    size_t size = stella_retro_get_memory_size(type);
    void *ramData = stella_retro_get_memory_data(type);

    if (ramData && (size > 0)) {
        stella_retro_serialize(ramData, size);
        NSData *data = [NSData dataWithBytes:ramData length:size];
        BOOL success = [data writeToFile:path atomically:YES];
        if (!success)
        {
            DLOG(@"Error writing save file");
        }
		return success;
	} else {
		ELOG(@"Stella ramdata is invalid");
		return NO;
	}
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error   {
	NSDictionary *userInfo = @{
							   NSLocalizedDescriptionKey: @"Failed to save state.",
							   NSLocalizedFailureReasonErrorKey: @"Stella does not support save states.",
							   NSLocalizedRecoverySuggestionErrorKey: @"Check for future updates on ticket #753."
							   };

	NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
											code:PVEmulatorCoreErrorCodeCouldNotSaveState
										userInfo:userInfo];

	*error = newError;
	return NO;
//	return [self writeSaveFile:fileName forType:RETRO_MEMORY_SAVE_RAM];
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error   {
	NSDictionary *userInfo = @{
							   NSLocalizedDescriptionKey: @"Failed to load state.",
							   NSLocalizedFailureReasonErrorKey: @"Stella does not support save states.",
							   NSLocalizedRecoverySuggestionErrorKey: @"Check for future updates on ticket #753."
							   };

	NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
											code:PVEmulatorCoreErrorCodeCouldNotLoadState
										userInfo:userInfo];

	*error = newError;
	return NO;
//	return [self loadSaveFile:fileName forType:RETRO_MEMORY_SAVE_RAM];
}


#pragma mark Input
- (void)pollControllers {
    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        
        if ([controller extendedGamepad]) {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            /* TODO: To support paddles we would need to circumvent libRetro's emulation of analog controls or drop libRetro and talk to stella directly like OpenEMU did */
            
            // D-Pad
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = (dpad.up.isPressed    || gamepad.leftThumbstick.up.isPressed);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = (dpad.down.isPressed  || gamepad.leftThumbstick.down.isPressed);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = (dpad.left.isPressed  || gamepad.leftThumbstick.left.isPressed);
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = (dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed);

			// #688, use second thumb to control second player input if no controller active
			// some games used both joysticks for 1 player optionally
			if(playerIndex == 0 && self.controller2 == nil) {
				_pad[1][RETRO_DEVICE_ID_JOYPAD_UP]    = gamepad.rightThumbstick.up.isPressed;
				_pad[1][RETRO_DEVICE_ID_JOYPAD_DOWN]  = gamepad.rightThumbstick.down.isPressed;
				_pad[1][RETRO_DEVICE_ID_JOYPAD_LEFT]  = gamepad.rightThumbstick.left.isPressed;
				_pad[1][RETRO_DEVICE_ID_JOYPAD_RIGHT] = gamepad.rightThumbstick.right.isPressed;
			}

            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] =  gamepad.buttonB.isPressed || gamepad.rightTrigger.isPressed;
            // Booster
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = gamepad.buttonX.isPressed || gamepad.buttonY.isPressed || gamepad.leftTrigger.isPressed;
            
            // Reset
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.rightShoulder.isPressed;
            
            // Select
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.leftShoulder.isPressed;
   
            /*
             #define RETRO_DEVICE_ID_JOYPAD_B        0 == JoystickZeroFire1
             #define RETRO_DEVICE_ID_JOYPAD_Y        1 == Unmapped
             #define RETRO_DEVICE_ID_JOYPAD_SELECT   2 == ConsoleSelect
             #define RETRO_DEVICE_ID_JOYPAD_START    3 == ConsoleReset
             #define RETRO_DEVICE_ID_JOYPAD_UP       4 == Up
             #define RETRO_DEVICE_ID_JOYPAD_DOWN     5 == Down
             #define RETRO_DEVICE_ID_JOYPAD_LEFT     6 == Left
             #define RETRO_DEVICE_ID_JOYPAD_RIGHT    7 == Right
             #define RETRO_DEVICE_ID_JOYPAD_A        8 == JoystickZeroFire2
             #define RETRO_DEVICE_ID_JOYPAD_X        9 == JoystickZeroFire3
             #define RETRO_DEVICE_ID_JOYPAD_L       10 == ConsoleLeftDiffA
             #define RETRO_DEVICE_ID_JOYPAD_R       11 == ConsoleRightDiffA
             #define RETRO_DEVICE_ID_JOYPAD_L2      12 == ConsoleLeftDiffB
             #define RETRO_DEVICE_ID_JOYPAD_R2      13 == ConsoleRightDiffB
             #define RETRO_DEVICE_ID_JOYPAD_L3      14 == ConsoleColor
             #define RETRO_DEVICE_ID_JOYPAD_R3      15 == ConsoleBlackWhite
             */
        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // D-Pad
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.isPressed;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;
            
            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonA.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] =  gamepad.buttonB.isPressed;
            // Booster
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = gamepad.buttonX.isPressed || gamepad.buttonY.isPressed;
            
            // Reset
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.rightShoulder.isPressed;
            
            // Select
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.leftShoulder.isPressed;
            
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.value > 0.5;
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.value > 0.5;

            // Fire
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonX.isPressed;
            // Trigger
            _pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
        }
#endif
    }
}

- (void)didPushPV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player {
    _pad[player][A2600EmulatorValues[button]] = 1;
}

- (void)didReleasePV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player {
    _pad[player][A2600EmulatorValues[button]] = 0;
}

#pragma mark Video
- (const void *)videoBuffer
{
    return _videoBuffer;
}

- (CGRect)screenRect {
//    __strong PVStellaGameCore *strongCurrent = _current;

    //return OEIntRectMake(0, 0, strongCurrent->_videoWidth, strongCurrent->_videoHeight);
    return CGRectMake(0, 0, _videoWidth, _videoHeight);
}

- (CGSize)bufferSize {
    return CGSizeMake(160, 256);
    
//    __strong PVStellaGameCore *strongCurrent = _current;
    //return CGSizeMake(strongCurrent->_videoWidth, strongCurrent->_videoHeight);
}

- (CGSize)aspectSize {
    return CGSizeMake(_videoWidth * (12.0/7.0), _videoHeight);
//    return CGSizeMake(STELLA_WIDTH * 2, STELLA_HEIGHT);
}

//- (void)setupEmulation
//{
//}

- (void)resetEmulation
{
    stella_retro_reset();
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
        stella_retro_unload_game();
        stella_retro_deinit();
    });
}

- (void)dealloc
{
    free(_videoBuffer);
}

- (GLenum)pixelFormat
{
    return STELLA_PIXEL_FORMAT;
}

- (GLenum)pixelType
{
    return  STELLA_PIXEL_TYPE;
}

- (GLenum)internalPixelFormat
{
    return STELLA_INTERNAL_FORMAT;
}

- (double)audioSampleRate
{
    return _sampleRate ? _sampleRate : 31400;
}

- (NSTimeInterval)frameInterval
{
    return _frameInterval ? _frameInterval : 60.0;
}

- (NSUInteger)channelCount
{
    return 2;
}

-(BOOL)supportsSaveStates {
	return NO;
}

@end
