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
#import "OESega32XSystemResponderClient.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#include "libretro.h"

@interface PicodriveGameCore () <OESega32XSystemResponderClient>
{
    uint16_t *videoBuffer;
    int videoWidth, videoHeight;
    int16_t pad[2][12];
    NSString *romName;
    double sampleRate;
    NSTimeInterval frameInterval;
}

@end

NSUInteger Sega32XEmulatorValues[] = { RETRO_DEVICE_ID_JOYPAD_UP, RETRO_DEVICE_ID_JOYPAD_DOWN, RETRO_DEVICE_ID_JOYPAD_LEFT, RETRO_DEVICE_ID_JOYPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_Y, RETRO_DEVICE_ID_JOYPAD_B, RETRO_DEVICE_ID_JOYPAD_A, RETRO_DEVICE_ID_JOYPAD_L, RETRO_DEVICE_ID_JOYPAD_X, RETRO_DEVICE_ID_JOYPAD_R, RETRO_DEVICE_ID_JOYPAD_START, RETRO_DEVICE_ID_JOYPAD_SELECT };

static __weak PicodriveGameCore *_current;

@implementation PicodriveGameCore

static void audio_callback(int16_t left, int16_t right)
{
    GET_CURRENT_OR_RETURN();

	[[current ringBufferAtIndex:0] write:&left maxLength:2];
    [[current ringBufferAtIndex:0] write:&right maxLength:2];
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
    GET_CURRENT_OR_RETURN(frames);

    [[current ringBufferAtIndex:0] write:data maxLength:frames << 2];
    return frames;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    GET_CURRENT_OR_RETURN();

    current->videoWidth  = width;
    current->videoHeight = height;
    
    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(height, the_queue, ^(size_t y){
        const uint16_t *src = (uint16_t*)data + y * (pitch >> 1); //pitch is in bytes not pixels
        uint16_t *dst = current->videoBuffer + y * 320;
        
        memcpy(dst, src, sizeof(uint16_t)*width);
    });
}

static void input_poll_callback(void)
{
    GET_CURRENT_OR_RETURN();

    [current pollControllers];
	//NSLog(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
    GET_CURRENT_OR_RETURN(0);

    //NSLog(@"polled input: port: %d device: %d id: %d", port, device, id);
    
    if (port == 0 & device == RETRO_DEVICE_JOYPAD) {
        return current->pad[0][_id];
    }
    else if(port == 1 & device == RETRO_DEVICE_JOYPAD) {
        return current->pad[1][_id];
    }
    
    return 0;
}

static bool environment_callback(unsigned cmd, void *data)
{
    GET_CURRENT_OR_RETURN(false);

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
            NSString *appSupportPath = current.BIOSPath;
            
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
    
    NSLog(@"Loaded save file: %s", path);
    
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

-(BOOL)rendersToOpenGL;
{
    return NO;
}

#pragma mark - Input

- (oneway void)didPushSega32XButton:(OESega32XButton)button forPlayer:(NSUInteger)player;
{
    pad[player][Sega32XEmulatorValues[button]] = 1;
}

- (oneway void)didReleaseSega32XButton:(OESega32XButton)button forPlayer:(NSUInteger)player;
{
    pad[player][Sega32XEmulatorValues[button]] = 0;
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
        GCExtendedGamepad *gamePad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OESega32XButtonUp:
                return [[dpad up] isPressed]?:[[[gamePad leftThumbstick] up] isPressed];
            case OESega32XButtonDown:
                return [[dpad down] isPressed]?:[[[gamePad leftThumbstick] down] isPressed];
            case OESega32XButtonLeft:
                return [[dpad left] isPressed]?:[[[gamePad leftThumbstick] left] isPressed];
            case OESega32XButtonRight:
                return [[dpad right] isPressed]?:[[[gamePad leftThumbstick] right] isPressed];
            case OESega32XButtonA:
                return [[gamePad buttonX] isPressed];
            case OESega32XButtonB:
                return [[gamePad buttonA] isPressed];
            case OESega32XButtonC:
                return [[gamePad buttonB] isPressed];
            case OESega32XButtonX:
                return [[gamePad leftShoulder] isPressed];
            case OESega32XButtonY:
                return [[gamePad buttonY] isPressed];
            case OESega32XButtonZ:
                return [[gamePad rightShoulder] isPressed];
            case OESega32XButtonStart:
                return [[gamePad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamePad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OESega32XButtonUp:
                return [[dpad up] isPressed];
            case OESega32XButtonDown:
                return [[dpad down] isPressed];
            case OESega32XButtonLeft:
                return [[dpad left] isPressed];
            case OESega32XButtonRight:
                return [[dpad right] isPressed];
            case OESega32XButtonA:
                return [[gamePad buttonX] isPressed];
            case OESega32XButtonB:
                return [[gamePad buttonA] isPressed];
            case OESega32XButtonC:
                return [[gamePad buttonB] isPressed];
            case OESega32XButtonX:
                return [[gamePad leftShoulder] isPressed];
            case OESega32XButtonY:
                return [[gamePad buttonY] isPressed];
            case OESega32XButtonZ:
                return [[gamePad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamePad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamePad dpad];
        switch (buttonID) {
            case OESega32XButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case OESega32XButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case OESega32XButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case OESega32XButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case OESega32XButtonA:
                return [[gamePad buttonA] isPressed];
                break;
            case OESega32XButtonB:
                return [[gamePad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    
    return 0;
}

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
            
            /* TODO: To support paddles we would need to circumvent libRatre's emulation of analog controls or drop libRetro and talk to stella directly like OpenEMU did */
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = (dpad.up.isPressed    || gamepad.leftThumbstick.up.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  =  (dpad.down.isPressed  || gamepad.leftThumbstick.down.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = (dpad.left.isPressed  || gamepad.leftThumbstick.left.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = (dpad.right.isPressed || gamepad.leftThumbstick.right.isPressed);
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = (gamepad.buttonA.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = (gamepad.buttonX.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_L] = (gamepad.buttonB.isPressed);
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = (gamepad.leftShoulder.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_Y] = (gamepad.buttonY.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_R] = (gamepad.rightShoulder.isPressed);
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.leftTrigger.isPressed;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.rightTrigger.isPressed;
        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.isPressed;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.isPressed;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.isPressed;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.isPressed;

            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = (gamepad.buttonA.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = (gamepad.buttonX.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_L] = (gamepad.buttonB.isPressed);
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_X] = (gamepad.leftShoulder.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_Y] = (gamepad.buttonY.isPressed);
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_R] = (gamepad.rightShoulder.isPressed);
            
//            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_START]  = gamepad.leftShoulder.isPressed;
//            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_SELECT] = gamepad.rightShoulder.isPressed;
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_UP]    = dpad.up.value > 0.5;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_DOWN]  = dpad.down.value > 0.5;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_LEFT]  = dpad.left.value > 0.5;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_RIGHT] = dpad.right.value > 0.5;
            
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_B] = gamepad.buttonX.isPressed;
            pad[playerIndex][RETRO_DEVICE_ID_JOYPAD_A] = gamepad.buttonA.isPressed;
        }
#endif
    }
}

- (id)init
{
    if((self = [super init]))
    {
        videoBuffer = (uint16_t*)malloc(320 * 240 * 2);
    }
    
	_current = self;
    
	return self;
}

-(void)copyCartHWCFG {
    NSBundle *myBundle = [NSBundle bundleForClass:[self class]];
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
            NSLog(@"Error copying carthw.cfg:\n %@", error.localizedDescription);
        } else {
            NSLog(@"Copied default carthw.cfg file into system directory. %@", self.BIOSPath);
        }
    }
}

#pragma mark Exectuion

- (void)executeFrame
{
    retro_run();
}

- (BOOL)loadFileAtPath:(NSString *)path //error:(NSError **)error
{
        // Copy default cartHW.cfg if need be
    [self copyCartHWCFG];

	memset(pad, 0, sizeof(int16_t) * 10);
    
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
        
        //retro_set_controller_port_device(SNES_PORT_1, RETRO_DEVICE_JOYPAD);
        
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

#pragma mark Video
- (const void *)videoBuffer
{
    return videoBuffer;
}

- (CGRect)screenRect
{
    return CGRectMake(0, 0, videoWidth, videoHeight);
}

- (CGSize)bufferSize
{
    return CGSizeMake(320, 240);
    //return OEIntSizeMake(current->videoWidth, current->videoHeight);
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
        
        NSLog(@"Trying to save SRAM");
        
        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];
        
        writeSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
    }
    
    NSLog(@"retro term");
    retro_unload_game();
    retro_deinit();
    [super stopEmulation];
}

- (void)dealloc
{
    free(videoBuffer);
}

- (GLenum)pixelFormat
{
    return GL_RGB; // GL_RGB
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_SHORT_5_6_5; //GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat
{
    return GL_RGB; //GL_RGB5
}

- (double)audioSampleRate
{
    return sampleRate ? sampleRate : 44100;
}

- (NSTimeInterval)frameInterval
{
    return frameInterval ? frameInterval : 60;
}

- (NSUInteger)channelCount
{
    return 2;
}

- (CGSize)aspectSize
{
    return CGSizeMake(4, 3);
}

#pragma mark - Save States

- (NSData *)serializeStateWithError:(NSError **)outError
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

- (BOOL)deserializeState:(NSData *)state withError:(NSError **)outError
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

- (BOOL)saveStateToFileAtPath:(NSString *)fileName //completionHandler:(void (^)(BOOL, NSError *))block
{
    size_t serial_size = retro_serialize_size();
    NSMutableData *stateData = [NSMutableData dataWithLength:serial_size];

    if(!retro_serialize([stateData mutableBytes], serial_size)) {
        NSError *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotSaveState userInfo:@{
            NSLocalizedDescriptionKey : @"Save state data could not be written",
            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
        }];
//        block(NO, error);
        return NO;
    }

    NSError *error = nil;
    BOOL success = [stateData writeToFile:fileName options:NSDataWritingAtomic error:&error];
//    block(success, success ? nil : error);
    return success;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName //completionHandler:(void (^)(BOOL, NSError *))block
{
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:fileName options:NSDataReadingMappedIfSafe | NSDataReadingUncached error:&error];
    if(data == nil)  {
//        block(NO, error);
        return NO;
    }

    int serial_size = 678514;
    if(serial_size != [data length]) {
        NSError *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeStateHasWrongSize userInfo:@{
            NSLocalizedDescriptionKey : @"Save state has wrong file size.",
            NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The size of the file %@ does not have the right size, %d expected, got: %ld.", fileName, serial_size, [data length]],
        }];
//        block(NO, error);
        return NO;
    }

    if(!retro_unserialize([data bytes], serial_size)) {
        NSError *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
            NSLocalizedDescriptionKey : @"The save state data could not be read",
            NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"Could not read the file state in %@.", fileName]
        }];
//        block(NO, error);
        return NO;
    }
    
//    block(YES, nil);
    return YES;
}

@end
