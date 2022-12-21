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

#import "PicodriveGameCore.h"
#import <PVSupport/OERingBuffer.h>

#import <TargetConditionals.h>

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
@import OpenGL;
@import GLUT;
#endif

#include "libretro.h"

@interface PicodriveGameCore () <PVSega32XSystemResponderClient>
{
    uint16_t *videoBuffer;
    uint16_t *videoBufferA;
    uint16_t *videoBufferB;
    int videoWidth, videoHeight;
    int16_t _pad[2][12];
    NSString *romName;
    double sampleRate;
    NSTimeInterval frameInterval;
}

@end

__weak PicodriveGameCore *_current;

@implementation PicodriveGameCore

static void audio_callback(int16_t left, int16_t right)
{
    __strong PicodriveGameCore *strongCurrent = _current;

	[[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];
    
    strongCurrent = nil;
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
    __strong PicodriveGameCore *strongCurrent = _current;

    [[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames << 2];
    strongCurrent = nil;
    return frames;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    __strong PicodriveGameCore *strongCurrent = _current;

    strongCurrent->videoWidth  = width;
    strongCurrent->videoHeight = height;
    
    
    static dispatch_queue_t memory_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
        memory_queue = dispatch_queue_create("com.provenance.video", queueAttributes);
    });
        
    dispatch_apply(height, memory_queue, ^(size_t y){
        const uint16_t *src = (uint16_t*)data + y * (pitch >> 1); //pitch is in bytes not pixels
        uint16_t *dst = strongCurrent->videoBuffer + y * 320;
        
        memcpy(dst, src, sizeof(uint16_t)*width);
    });
    strongCurrent = nil;
}

static void input_poll_callback(void)
{
    
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
    __strong PicodriveGameCore *strongCurrent = _current;
    
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
    __strong PicodriveGameCore *strongCurrent = _current;

    switch(cmd)
    {
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE :
        {
            break;
        }
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT :
        {
            enum retro_pixel_format pix_fmt = *(const enum retro_pixel_format*)data;
            switch (pix_fmt)
            {
                case RETRO_PIXEL_FORMAT_0RGB1555:
                    NSLog(@"Environ SET_PIXEL_FORMAT: 0RGB1555");
                    break;
                
                case RETRO_PIXEL_FORMAT_RGB565:
                    NSLog(@"Environ SET_PIXEL_FORMAT: RGB565");
                    break;
                    
                case RETRO_PIXEL_FORMAT_XRGB8888:
                    NSLog(@"Environ SET_PIXEL_FORMAT: XRGB8888");
                    break;
                    
                default:
                    return false;
            }
            //currentPixFmt = pix_fmt;
            break;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY :
        {
            NSString *appSupportPath = [strongCurrent BIOSPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            NSLog(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
        case RETRO_ENVIRONMENT_SET_VARIABLES:
        {
            // We could potentionally ask the user what options they want
            const struct retro_variable* envs = (const struct retro_variable*)data;
            int i=0;
            const struct retro_variable *currentEnv;
            do {
                currentEnv = &envs[i];
                NSLog(@"Environ SET_VARIABLES: {\"%s\",\"%s\"}.\n", currentEnv->key, currentEnv->value);
                i++;
            } while(currentEnv->key != NULL && currentEnv->value != NULL);

            break;

        }
        default :
            NSLog(@"Environ UNSUPPORTED (#%u).\n", cmd);
            return false;
    }
    
    return true;
}

static void loadSaveFile(const char* path, int type)
{
    FILE *file;
    
    file = fopen(path, "rb");
    if ( !file )
    {
        return;
    }
    
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if (size == 0 || !data)
    {
        fclose(file);
        return;
    }
    
    int rc = fread(data, sizeof(uint8_t), size, file);
    if ( rc != size )
    {
        NSLog(@"Couldn't load save file.");
    }
    
//    NSLog(@"Loaded save file: %s", path);
    
    fclose(file);
}

static void writeSaveFile(const char* path, int type)
{
    size_t size = retro_get_memory_size(type);
    void *data = retro_get_memory_data(type);
    
    if ( data && size > 0 )
    {
        FILE *file = fopen(path, "wb");
        if ( file != NULL )
        {
            NSLog(@"Saving state %s. Size: %d bytes.", path, (int)size);
            retro_serialize(data, size);
            if ( fwrite(data, sizeof(uint8_t), size, file) != size )
                NSLog(@"Did not save state properly.");
            fclose(file);
        }
    }
}

#pragma mark Execution

- (id)init
{
    if((self = [super init]))
    {
        videoBuffer = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));
        videoBufferA = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));
        videoBufferB = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));
    }
    
	_current = self;
    
	return self;
}

-(void)copyCartHWCFG {
    NSBundle *myBundle = [NSBundle bundleForClass:[PicodriveGameCore class]];
    NSString *cartPath = [myBundle pathForResource:@"carthw" ofType:@"cfg"];
    
    NSString *systemPath = self.BIOSPath;
    NSString *destinationPath = [systemPath stringByAppendingPathComponent:@"carthw.cfg"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if(![fm fileExistsAtPath:destinationPath]) {
        NSError *error;
        BOOL success = [fm copyItemAtPath:cartPath
                                   toPath:destinationPath
                                    error:&error];
        if(!success) {
            ELOG(@"Error copying carthw.cfg:\n %@\nsource: %@\ndestination: %@", error.localizedDescription, cartPath, destinationPath);
        } else {
            ILOG(@"Copied default carthw.cfg file into system directory. %@", self.BIOSPath);
        }
    }
}

- (void)executeFrame
{
    retro_run();
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    // Copy default cartHW.cfg if need be
    [self copyCartHWCFG];

	memset(_pad, 0, sizeof(int16_t) * 10);
    
    const void *data;
    size_t size;
    romName = [path copy];
    
    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[romName stringByStandardizingPath]];
    if(dataObj == nil) return false;
    size = [dataObj length];
    data = (uint8_t*)[dataObj bytes];
    const char *meta = NULL;
    
    retro_set_environment(environment_callback);
	retro_init();
    
    if (videoBufferA) {
        free(videoBufferA);
    }
    videoBufferA = NULL;

    if (videoBufferB) {
        free(videoBufferB);
    }
    videoBufferB = NULL;

    videoBuffer = NULL;
    
    videoBufferA = (unsigned char *)malloc(320 * 240 * 2);
    videoBufferB = (unsigned char *)malloc(320 * 240 * 2);
    
    videoBuffer = (short unsigned int *)videoBufferA;
	
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
        NSString *path = romName;
        NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
        
        NSString *batterySavesDirectory = [self batterySavesPath];
        
        if([batterySavesDirectory length] != 0)
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
            
            NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
            
            loadSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
        }
        
        struct retro_system_av_info info;
        retro_get_system_av_info(&info);
        
        frameInterval = info.timing.fps;
        sampleRate = info.timing.sample_rate;
        
        retro_get_region();
        
        retro_run();
        
        return YES;
    }

    if (error) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"PicoDrive failed to load ROM.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format PicoDrive supports."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
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

- (BOOL)writeSaveFile:(NSString *)path forType:(int)type
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
		return success;
	} else {
		return NO;
	}
}

- (void)resetEmulation
{
    retro_reset();
}

- (void)stopEmulation
{
    
    NSString *path = romName;
    NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];
    
    NSString *batterySavesDirectory = [self batterySavesPath];
    
    if([batterySavesDirectory length] != 0)
    {
        
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
            
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
        
        writeSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
    }
    
    retro_unload_game();
    retro_deinit();
    [super stopEmulation];
}

- (void)dealloc
{
    free(videoBuffer);
}

#pragma mark Video

- (void)swapBuffers
{
    if (videoBuffer == (short unsigned int *)videoBufferA)
    {
        videoBuffer = videoBufferA;
        videoBuffer = (short unsigned int *)videoBufferB;
    }
    else
    {
        videoBuffer = videoBufferB;
        videoBuffer = (short unsigned int *)videoBufferA;
    }
}

- (const void *)videoBuffer
{
    return videoBuffer;
}

-(BOOL)isDoubleBuffered {
    return NO;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
    return CGSizeMake(320, 240);
}

- (CGSize)aspectSize
{
    float ratio =  32.0 / 35.0;
    return CGSizeMake( ((320.0 / 224.0) * ratio), 1.0);
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
    return frameInterval ? frameInterval : 60;
}

#pragma mark Audio

- (double)audioSampleRate
{
    return sampleRate;
}

- (NSUInteger)channelCount
{
    return 2;
}

#pragma mark - Input

- (void)didPushSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player;
{
    _pad[player][button] = 1;
}

- (void)didReleaseSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player;
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
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        if (PVSettingsModel.shared.use8BitdoM30) // Maps the Sega Controls to the 8BitDo M30 if enabled in Settings / Controller
        { switch (buttonID) {
            case PVSega32XButtonUp:
                return [[[gamepad leftThumbstick] up] value] > 0.1;
            case PVSega32XButtonDown:
                return [[[gamepad leftThumbstick] down] value] > 0.1;
            case PVSega32XButtonLeft:
                return [[[gamepad leftThumbstick] left] value] > 0.1;
            case PVSega32XButtonRight:
                return [[[gamepad leftThumbstick] right] value] > 0.1;
            case PVSega32XButtonA:
                return [[gamepad buttonA] isPressed];
            case PVSega32XButtonB:
                return [[gamepad buttonB] isPressed];
            case PVSega32XButtonC:
                return [[gamepad rightShoulder] isPressed];
            case PVSega32XButtonX:
                return [[gamepad buttonX] isPressed];
            case PVSega32XButtonY:
                return [[gamepad buttonY] isPressed];
            case PVSega32XButtonZ:
                return [[gamepad leftShoulder] isPressed];
            case PVSega32XButtonMode:
                return [[gamepad leftTrigger] isPressed];
            case PVSega32XButtonStart:
#if TARGET_OS_TV
                return [[gamepad buttonMenu] isPressed]?:[[gamepad rightTrigger] isPressed];
#else
                return [[gamepad rightTrigger] isPressed];
#endif
            default:
                break;
        }}
        { switch (buttonID) {
            case PVSega32XButtonUp:
                return [[dpad up] isPressed]?:[[[gamepad leftThumbstick] up] isPressed];
            case PVSega32XButtonDown:
                return [[dpad down] isPressed]?:[[[gamepad leftThumbstick] down] isPressed];
            case PVSega32XButtonLeft:
                return [[dpad left] isPressed]?:[[[gamepad leftThumbstick] left] isPressed];
            case PVSega32XButtonRight:
                return [[dpad right] isPressed]?:[[[gamepad leftThumbstick] right] isPressed];
            case PVSega32XButtonA:
                return [[gamepad buttonX] isPressed];
            case PVSega32XButtonB:
                return [[gamepad buttonA] isPressed];
            case PVSega32XButtonC:
                return [[gamepad buttonB] isPressed];
            case PVSega32XButtonX:
                return [[gamepad buttonY] isPressed];
            case PVSega32XButtonY:
                return [[gamepad leftShoulder] isPressed];
            case PVSega32XButtonZ:
                return [[gamepad rightShoulder] isPressed];
            case PVSega32XButtonStart:
                return [[gamepad rightTrigger] isPressed];
             case PVSega32XButtonMode:
                return [[gamepad leftTrigger] isPressed];
            default:
                break;
        }}
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSega32XButtonUp:
                return [[dpad up] isPressed];
            case PVSega32XButtonDown:
                return [[dpad down] isPressed];
            case PVSega32XButtonLeft:
                return [[dpad left] isPressed];
            case PVSega32XButtonRight:
                return [[dpad right] isPressed];
            case PVSega32XButtonA:
                return [[gamepad buttonY] isPressed];
            case PVSega32XButtonB:
                return [[gamepad buttonX] isPressed];
            case PVSega32XButtonC:
                return [[gamepad buttonA] isPressed];
            case PVSega32XButtonX:
                return [[gamepad buttonB] isPressed];
            case PVSega32XButtonY:
                return [[gamepad leftShoulder] isPressed];
            case PVSega32XButtonZ:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSega32XButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVSega32XButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVSega32XButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVSega32XButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVSega32XButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            case PVSega32XButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            default:
                break;
        }
    }
#endif

    return 0;
}

#pragma mark - Save States

- (NSData *)serializeStateWithError:(NSError *__autoreleasing *)outError
{
    size_t length = retro_serialize_size();
    void *bytes = malloc(length);
    
    if(retro_serialize(bytes, length))
        return [NSData dataWithBytesNoCopy:bytes length:length];

    if(outError) {
        *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotSaveState userInfo:@{
            NSLocalizedDescriptionKey : @"Save state data could not be written",
            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
        }];
    }

    return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError *__autoreleasing *)outError
{
    size_t serial_size = retro_serialize_size();
    if(serial_size != [state length]) {
        if(outError) {
            *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeStateHasWrongSize userInfo:@{
                NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The save state does not have the right size, %ld expected, got: %ld.", serial_size, [state length]]
            }];
        }

        return NO;
    }
    
    if(retro_unserialize([state bytes], [state length]))
        return YES;

    if(outError) {
        *outError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
            NSLocalizedDescriptionKey : @"The save state data could not be read"
        }];
    }
    
    return NO;
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error //completionHandler:(void (^)(BOOL, NSError *))block
{
    size_t serial_size = retro_serialize_size();
    NSMutableData *stateData = [NSMutableData dataWithLength:serial_size];

    if(!retro_serialize([stateData mutableBytes], serial_size)) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                                userInfo:@{
                                                           NSLocalizedDescriptionKey : @"Save state data could not be written",
                                                           NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
                                                           }];

            *error = newError;
        }
//        block(NO, error);
        return NO;
    }

    BOOL success = [stateData writeToFile:fileName options:NSDataWritingAtomic error:&error];
//    block(success, success ? nil : error);
	
    return success;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error //completionHandler:(void (^)(BOOL, NSError *))block
{
    NSData *data = [NSData dataWithContentsOfFile:fileName options:NSDataReadingMappedIfSafe | NSDataReadingUncached error:error];
    if(data == nil)  {
//        block(NO, error);
        if (error) {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to save state.",
                                       NSLocalizedFailureReasonErrorKey: @"Core failed to load save state. No Data at path.",
                                       NSLocalizedRecoverySuggestionErrorKey: @""
                                       };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];

            *error = newError;
        }
        return NO;
    }

    int serial_size = 678514;
    if(serial_size != [data length]) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                 code:PVEmulatorCoreErrorCodeStateHasWrongSize
                                             userInfo:@{
                NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the file %@ does not have the right size, %d expected, got: %ld.", fileName, serial_size, [data length]],
            }];

            *error = newError;
        }
//        block(NO, error);
        return NO;
    }

    if(!retro_unserialize([data bytes], serial_size)) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
                                                                                                                                            NSLocalizedDescriptionKey : @"The save state data could not be read",
                                                                                                                                            NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Could not read the file state in %@.", fileName]
                                                                                                                                            }];
            *error = newError;
        }
        return NO;
    }
    
//    block(YES, nil);
    return YES;
}

@end
