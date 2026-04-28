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

#import "PVPicoDriveBridge.h"
//#include "libretro.h"

@import PVAudio;
@import PVCoreBridge;
@import PVLoggingObjC;
@import PVSupport;
@import GameController;
@import PVEmulatorCore;
@import PVSettings;
#import <stdatomic.h>

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

@import libpicodrive;

__weak PVPicoDriveBridge *_current;


@interface PVPicoDriveBridge () <PVSega32XSystemResponderClient>
{
    uint16_t *videoBuffer;
    uint16_t *videoBufferA;
    uint16_t *videoBufferB;
    int videoWidth, videoHeight;
    // Indexed by libretro RETRO_DEVICE_ID_JOYPAD_* constants (max R3 = 15), not by
    // PVSega32XButton enum values — the two orderings differ.
    int16_t _pad[2][16];
    NSString *romName;
    double sampleRate;
    NSTimeInterval frameInterval;
    NSMutableDictionary<NSString *, NSString *> *_variableCache;
    atomic_bool _shouldRun;
    atomic_bool _isGameLoaded;
    atomic_bool _didShutdownCore;
}

@end

@implementation PVPicoDriveBridge
@synthesize valueChangedHandler;


static void audio_callback(int16_t left, int16_t right)
{
    __strong PVPicoDriveBridge *strongCurrent = _current;

	[[strongCurrent ringBufferAtIndex:0] write:&left size:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right size:2];

    strongCurrent = nil;
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
    __strong PVPicoDriveBridge *strongCurrent = _current;

    [[strongCurrent ringBufferAtIndex:0] write:data size:frames << 2];
    strongCurrent = nil;
    return frames;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    __strong PVPicoDriveBridge *strongCurrent = _current;

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
    __strong PVPicoDriveBridge *strongCurrent = _current;

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
    __strong PVPicoDriveBridge *strongCurrent = _current;

    switch(cmd)
    {
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE :
        {
            break;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE:
        {
            struct retro_variable *var = (struct retro_variable *)data;
            NSString *optionKey = [NSString stringWithUTF8String:var->key];
            NSString *userDefaultsKey = [NSString stringWithFormat:@"PVPicoDrive.%@", optionKey];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

            if ([optionKey isEqualToString:@"picodrive_input1"]) {
                NSInteger value = [defaults integerForKey:userDefaultsKey];
                NSString *stringValue;
                switch (value) {
                    case 0: stringValue = @"3 button pad"; break;
                    case 1: stringValue = @"6 button pad"; break;
                    case 2: stringValue = @"None"; break;
                    default: stringValue = @"3 button pad"; break;
                }
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_input2"]) {
                NSInteger value = [defaults integerForKey:userDefaultsKey];
                NSString *stringValue;
                switch (value) {
                    case 0: stringValue = @"3 button pad"; break;
                    case 1: stringValue = @"6 button pad"; break;
                    case 2: stringValue = @"None"; break;
                    default: stringValue = @"3 button pad"; break;
                }
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_sprlim"]) {
                BOOL value = [defaults boolForKey:userDefaultsKey];
                NSString *stringValue = value ? @"enabled" : @"disabled";
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_ramcart"]) {
                BOOL value = [defaults boolForKey:userDefaultsKey];
                NSString *stringValue = value ? @"enabled" : @"disabled";
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_region"]) {
                NSInteger value = [defaults integerForKey:userDefaultsKey];
                NSString *stringValue;
                switch (value) {
                    case 0: stringValue = @"Auto"; break;
                    case 1: stringValue = @"Japan NTSC"; break;
                    case 2: stringValue = @"Japan PAL"; break;
                    case 3: stringValue = @"US"; break;
                    case 4: stringValue = @"Europe"; break;
                    default: stringValue = @"Auto"; break;
                }
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_aspect"]) {
                NSInteger value = [defaults integerForKey:userDefaultsKey];
                NSString *stringValue;
                switch (value) {
                    case 0: stringValue = @"PAR"; break;
                    case 1: stringValue = @"4/3"; break;
                    case 2: stringValue = @"CRT"; break;
                    default: stringValue = @"PAR"; break;
                }
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_overscan"]) {
                BOOL value = [defaults boolForKey:userDefaultsKey];
                NSString *stringValue = value ? @"enabled" : @"disabled";
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }
            else if ([optionKey isEqualToString:@"picodrive_overclk68k"]) {
                NSInteger value = [defaults integerForKey:userDefaultsKey];
                NSString *stringValue;
                switch (value) {
                    case 0: stringValue = @"disabled"; break;
                    case 1: stringValue = @"+25%"; break;
                    case 2: stringValue = @"+50%"; break;
                    case 3: stringValue = @"+75%"; break;
                    case 4: stringValue = @"+100%"; break;
                    case 5: stringValue = @"+200%"; break;
                    case 6: stringValue = @"+400%"; break;
                    default: stringValue = @"disabled"; break;
                }
                strongCurrent->_variableCache[optionKey] = stringValue;
                var->value = [stringValue UTF8String];
                return true;
            }

            WLOG(@"Unhandled variable: %s", var->key);
            return false;
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

    size_t rc = fread(data, sizeof(uint8_t), size, file);
    if ( rc != size ) {
        ELOG(@"Couldn't load save file.");
    } else {
        ILOG(@"Loaded save file: %s", path);
    }

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

- (instancetype)init {
    if((self = [super init])) {
        self->videoBufferA = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));
        self->videoBufferB = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));
        self->videoBuffer = self->videoBufferA;

//        _pad = (int16_t *)malloc(24 * sizeof(int16_t));
        memset((void*)_pad, 0, sizeof(int16_t) * 24);
        _variableCache = [NSMutableDictionary dictionary];
        atomic_init(&_shouldRun, false);
        atomic_init(&_isGameLoaded, false);
        atomic_init(&_didShutdownCore, false);
    }

	_current = self;

	return self;
}

- (void)executeFrame {
    if (!atomic_load(&_shouldRun)) {
        return;
    }
    retro_run();
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
	memset((void*)_pad, 0, sizeof(int16_t) * 24);

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

    if (self->videoBufferA) {
        free(self->videoBufferA);
    }
    self->videoBufferA = NULL;

    if (self->videoBufferB) {
        free(self->videoBufferB);
    }
    self->videoBufferB = NULL;

    self->videoBuffer = NULL;

    self->videoBufferA = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));
    self->videoBufferB = (uint16_t *)malloc(320 * 240 * sizeof(uint16_t));

    self->videoBuffer = (uint16_t *)self->videoBufferA;

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

    if(retro_load_game(&info)) {
        NSString *path = self.romName;
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

        self->frameInterval = info.timing.fps;
        self->_sampleRate = info.timing.sample_rate;

        retro_get_region();

        retro_run();
        atomic_store(&_shouldRun, true);
        atomic_store(&_isGameLoaded, true);

        return YES;
    }

    if (error) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"PicoDrive failed to load ROM.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format PicoDrive supports."
                                   };

        NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];

        *error = newError;
    }
    return NO;

}

- (void)loadSaveFile:(NSString *)path forType:(int)type {
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

- (BOOL)writeSaveFile:(NSString *)path forType:(int)type {
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

- (void)resetEmulation {
    retro_reset();
}

- (void)stopEmulation {
    atomic_store(&_shouldRun, false);
    // Snapshot before shutdown: after `shutdownCoreIfNeeded`, libretro must not be queried (e.g. second `stopEmulation`).
    BOOL const hadGameLoaded = atomic_load(&_isGameLoaded);
    [super stopEmulation];

    NSString *path = romName;
    NSString *extensionlessFilename = [[path lastPathComponent] stringByDeletingPathExtension];

    NSString *batterySavesDirectory = [self batterySavesPath];

    if (hadGameLoaded && [batterySavesDirectory length] != 0 && [extensionlessFilename length] != 0) {
        [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];

        NSString *filePath = [batterySavesDirectory stringByAppendingPathComponent:[extensionlessFilename stringByAppendingPathExtension:@"sav"]];

        writeSaveFile([filePath UTF8String], RETRO_MEMORY_SAVE_RAM);
    }

    [self shutdownCoreIfNeeded];
}

- (void)dealloc {
    atomic_store(&_shouldRun, false);
    [self shutdownCoreIfNeeded];
    free(self->videoBufferA);
    free(self->videoBufferB);
}

- (void)shutdownCoreIfNeeded {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&_didShutdownCore, &expected, true)) {
        return;
    }

    if (atomic_load(&_isGameLoaded)) {
        retro_unload_game();
        atomic_store(&_isGameLoaded, false);
    }

    retro_deinit();
    _current = nil;
}

#pragma mark Video

- (void)swapBuffers {
    if (self->videoBuffer == (short unsigned int *)self->videoBufferA) {
        self->videoBuffer = self->videoBufferA;
        self->videoBuffer = (short unsigned int *)self->videoBufferB;
    } else {
        self->videoBuffer = self->videoBufferB;
        self->videoBuffer = (short unsigned int *)self->videoBufferA;
    }
}

- (const void *)videoBuffer {
    return self->videoBuffer;
}

-(BOOL)isDoubleBuffered {
    return NO;
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, self->videoWidth, self->videoHeight);
}

- (CGSize)bufferSize {
    return CGSizeMake(320, 240);
}

- (CGSize)aspectSize {
    float ratio =  32.0 / 35.0;
    return CGSizeMake( ((320.0 / 224.0) * ratio), 1.0);
}

- (GLenum)pixelFormat {
    return GL_RGB;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_SHORT_5_6_5;
}

- (GLenum)internalPixelFormat {
    return GL_RGB;
}

- (NSTimeInterval)frameInterval {
    return self->frameInterval ? self->frameInterval : 60;
}

#pragma mark Audio

- (double)audioSampleRate {
    return self->_sampleRate;
}

- (NSUInteger)channelCount {
    return 2;
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player {

    GCController *controller = (player == 0) ? self.controller1 : self.controller2;

    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        // TODO: Read this from Swift Defaults pacakge somehow? @JoeMatt

        BOOL use8BitdoM30 = PVSettingsWrapper.use8BitdoM30;
//        BOOL use8BitdoM30 = [NSUserDefaults.standardUserDefaults boolForKey:@"use8BitdoM30"];
        // `buttonID` is the libretro RETRO_DEVICE_ID_JOYPAD_* constant passed by
        // input_state_callback, NOT a PVSega32XButton enum value. The two orderings
        // differ — see Sega32XLibretroMap. Cases below switch on the libretro ID
        // and the comment names which Sega button the libretro ID represents.
        if (use8BitdoM30) // Maps the Sega Controls to the 8BitDo M30 if enabled in Settings / Controller
        { switch (buttonID) {
            case RETRO_DEVICE_ID_JOYPAD_UP:    // Sega Up
                return [[[gamepad leftThumbstick] up] value] > 0.1;
            case RETRO_DEVICE_ID_JOYPAD_DOWN:  // Sega Down
                return [[[gamepad leftThumbstick] down] value] > 0.1;
            case RETRO_DEVICE_ID_JOYPAD_LEFT:  // Sega Left
                return [[[gamepad leftThumbstick] left] value] > 0.1;
            case RETRO_DEVICE_ID_JOYPAD_RIGHT: // Sega Right
                return [[[gamepad leftThumbstick] right] value] > 0.1;
            case RETRO_DEVICE_ID_JOYPAD_Y:     // Sega A
                return [[gamepad buttonA] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_B:     // Sega B
                return [[gamepad buttonB] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_A:     // Sega C
                return [[gamepad rightShoulder] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_L:     // Sega X
                return [[gamepad buttonX] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_X:     // Sega Y
                return [[gamepad buttonY] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_R:     // Sega Z
                return [[gamepad leftShoulder] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_SELECT: // Sega Mode
                return [[gamepad leftTrigger] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_START: // Sega Start
#if TARGET_OS_TV
                return [[gamepad buttonMenu] isPressed]?:[[gamepad rightTrigger] isPressed];
#else
                return [[gamepad rightTrigger] isPressed];
#endif
            default:
                break;
        }}
        // Harmonized Sega 6-button MFi layout (matches 8BitDo M30 + Sega Genesis Mini conventions).
        // Same physical button always means the same Sega button across every Sega-platform core,
        // so a DualSense / Xbox / generic MFi pad gives an intuitive "label-to-label" mapping
        // (Cross→A, Circle→B, Square→X, Triangle→Y) and the shoulder C/Z line up with M30.
        //   D-pad up/down/left/right  → D-pad (with left-thumbstick fallback, deadzoned per-axis)
        //   buttonA  (south, Cross)   → Sega A
        //   buttonB  (east,  Circle)  → Sega B
        //   rightShoulder (R1)        → Sega C
        //   buttonX  (west,  Square)  → Sega X
        //   buttonY  (north, Triangle)→ Sega Y
        //   leftShoulder  (L1)        → Sega Z
        //   rightTrigger  (R2)        → Sega Start  (tvOS pads without R2 cannot Start; do NOT poll buttonMenu — it owns pause)
        //   leftTrigger   (L2)        → Sega Mode
        // No modifier combo is required: all 8 Genesis/32X inputs map to distinct physical buttons.
        //
        // Thumbstick fallback uses an explicit per-axis deadzone (PVSega32XThumbstickDeadzone)
        // applied to the analog `value`, NOT the synthesized `up/down/left/right.isPressed` getters.
        // Apple's synthesized direction-pad button on a thumbstick reports `isPressed=YES` for
        // any non-zero magnitude on its half-axis — so a stick at (xAxis≈0.15, yAxis≈0.85) would
        // fire UP *and* RIGHT simultaneously, producing the "diagonal bleed" symptom (32X is
        // strictly digital so even a tiny cross-axis component becomes a full directional press).
        //
        // `buttonID` is the libretro RETRO_DEVICE_ID_JOYPAD_* constant passed by
        // input_state_callback (see Sega32XLibretroMap above). Each case names
        // which Sega button the libretro ID corresponds to.
        static const float PVSega32XThumbstickDeadzone = 0.5f;
        { switch (buttonID) {
            case RETRO_DEVICE_ID_JOYPAD_UP:    // Sega Up
                return [[dpad up] isPressed]?:([[[gamepad leftThumbstick] up] value]    > PVSega32XThumbstickDeadzone);
            case RETRO_DEVICE_ID_JOYPAD_DOWN:  // Sega Down
                return [[dpad down] isPressed]?:([[[gamepad leftThumbstick] down] value]  > PVSega32XThumbstickDeadzone);
            case RETRO_DEVICE_ID_JOYPAD_LEFT:  // Sega Left
                return [[dpad left] isPressed]?:([[[gamepad leftThumbstick] left] value]  > PVSega32XThumbstickDeadzone);
            case RETRO_DEVICE_ID_JOYPAD_RIGHT: // Sega Right
                return [[dpad right] isPressed]?:([[[gamepad leftThumbstick] right] value] > PVSega32XThumbstickDeadzone);
            case RETRO_DEVICE_ID_JOYPAD_Y:     // Sega A
                return [[gamepad buttonA] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_B:     // Sega B
                return [[gamepad buttonB] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_A:     // Sega C
                return [[gamepad rightShoulder] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_L:     // Sega X
                return [[gamepad buttonX] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_X:     // Sega Y
                return [[gamepad buttonY] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_R:     // Sega Z
                return [[gamepad leftShoulder] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_START: // Sega Start
                // Do NOT fall back to buttonMenu on tvOS — buttonMenu is reserved
                // for the pause-menu pipeline (controllerPausedHandler / GCEventViewController),
                // and polling it from the bridge suppresses pause on Siri Remote and
                // on MFi pads that lack buttonOptions / thumbstick-button pause triggers.
                // See PVUI/Sources/PVUIBase/Controller/GCControllerExtensions.swift.
                return [[gamepad rightTrigger] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_SELECT: // Sega Mode
                return [[gamepad leftTrigger] isPressed];
            default:
                break;
        }}
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        // Legacy GCGamepad has only A/B/X/Y + L1/R1 — 6 buttons but 32X needs 8.
        // Use L1+R1 as a Start/Mode modifier and map the four face buttons to the four
        // primary face Sega buttons (A/B/X/Y) so labels stay consistent with the harmonized
        // extended-gamepad layout. C and Z fall under the modifier (rare on basic gamepads).
        // `buttonID` is the libretro RETRO_DEVICE_ID_JOYPAD_* constant.
        bool modifierPressed = [[gamepad leftShoulder] isPressed] && [[gamepad rightShoulder] isPressed];
        switch (buttonID) {
            case RETRO_DEVICE_ID_JOYPAD_UP:    // Sega Up
                return [[dpad up] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_DOWN:  // Sega Down
                return [[dpad down] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_LEFT:  // Sega Left
                return [[dpad left] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_RIGHT: // Sega Right
                return [[dpad right] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_Y:     // Sega A
                return [[gamepad buttonA] isPressed] && !modifierPressed;
            case RETRO_DEVICE_ID_JOYPAD_B:     // Sega B
                return [[gamepad buttonB] isPressed] && !modifierPressed;
            case RETRO_DEVICE_ID_JOYPAD_A:     // Sega C
                return [[gamepad rightShoulder] isPressed] && !modifierPressed;
            case RETRO_DEVICE_ID_JOYPAD_L:     // Sega X
                return [[gamepad buttonX] isPressed] && !modifierPressed;
            case RETRO_DEVICE_ID_JOYPAD_X:     // Sega Y
                return [[gamepad buttonY] isPressed] && !modifierPressed;
            case RETRO_DEVICE_ID_JOYPAD_R:     // Sega Z
                return [[gamepad leftShoulder] isPressed] && !modifierPressed;
            case RETRO_DEVICE_ID_JOYPAD_START: // Sega Start
                return modifierPressed && [[gamepad buttonA] isPressed];
            case RETRO_DEVICE_ID_JOYPAD_SELECT: // Sega Mode
                return modifierPressed && [[gamepad buttonB] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        // `buttonID` is the libretro RETRO_DEVICE_ID_JOYPAD_* constant.
        switch (buttonID) {
            case RETRO_DEVICE_ID_JOYPAD_UP:    // Sega Up
                return [[dpad up] value] > 0.5;
                break;
            case RETRO_DEVICE_ID_JOYPAD_DOWN:  // Sega Down
                return [[dpad down] value] > 0.5;
                break;
            case RETRO_DEVICE_ID_JOYPAD_LEFT:  // Sega Left
                return [[dpad left] value] > 0.5;
                break;
            case RETRO_DEVICE_ID_JOYPAD_RIGHT: // Sega Right
                return [[dpad right] value] > 0.5;
                break;
            case RETRO_DEVICE_ID_JOYPAD_Y:     // Sega A
                return [[gamepad buttonA] isPressed];
                break;
            case RETRO_DEVICE_ID_JOYPAD_L:     // Sega X
                return [[gamepad buttonX] isPressed];
                break;
            // Siri Remote: do NOT bind Start to buttonMenu — buttonMenu is owned
            // by the pause pipeline (controllerPausedHandler), and polling it from
            // the bridge suppresses pause. Start is unreachable on Siri Remote;
            // use a real MFi controller for 32X.
            default:
                break;
        }
    }
#endif

    return 0;
}

#pragma mark - Save States

- (NSData *)serializeStateWithError:(NSError *__autoreleasing *)outError {
    size_t length = retro_serialize_size();
    void *bytes = malloc(length);

    if(retro_serialize(bytes, length))
        return [NSData dataWithBytesNoCopy:bytes length:length];

    if(outError) {
        *outError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotSaveState userInfo:@{
            NSLocalizedDescriptionKey : @"Save state data could not be written",
            NSLocalizedRecoverySuggestionErrorKey : @"The emulator could not write the state data."
        }];
    }

    return nil;
}

- (BOOL)deserializeState:(NSData *)state withError:(NSError *__autoreleasing *)outError {
    size_t serial_size = retro_serialize_size();
    if(serial_size != [state length]) {
        if(outError) {
            *outError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeStateHasWrongSize userInfo:@{
                NSLocalizedDescriptionKey : @"Save state has wrong file size.",
                NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:@"The save state does not have the right size, %ld expected, got: %ld.", serial_size, [state length]]
            }];
        }

        return NO;
    }

    if(retro_unserialize([state bytes], [state length]))
        return YES;

    if(outError) {
        *outError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain code:PVEmulatorCoreErrorCodeCouldNotLoadState userInfo:@{
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
            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
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

    BOOL success = [stateData writeToFile:fileName options:NSDataWritingAtomic error:error];
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

            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];

            *error = newError;
        }
        return NO;
    }

    int serial_size = 678514;
    if(serial_size != [data length]) {
        if (error) {
            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
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
            NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:@{
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

@implementation PVPicoDriveBridge (PVSega32XSystemResponderClient)
#pragma mark - Input

// PVSega32XButton enum ordinal → libretro RETRO_DEVICE_ID_JOYPAD_* constant.
// Without this translation, _pad[] is indexed at the wrong slot — pressing on-screen
// "A" would end up firing libretro UP (both happen to share index 4 in their
// respective enums), making the entire control scheme nonsensical.
//
// PicoDrive's libretro Genesis/32X mapping (see libretro.c desc[] block):
//   B(0)=Sega B,  Y(1)=Sega A,  SELECT(2)=Mode,  START(3)=Start,
//   UP(4),        DOWN(5),       LEFT(6),         RIGHT(7),
//   A(8)=Sega C,  X(9)=Sega Y,   L(10)=Sega X,    R(11)=Sega Z
static const int Sega32XLibretroMap[] = {
    [PVSega32XButtonUp]    = RETRO_DEVICE_ID_JOYPAD_UP,
    [PVSega32XButtonDown]  = RETRO_DEVICE_ID_JOYPAD_DOWN,
    [PVSega32XButtonLeft]  = RETRO_DEVICE_ID_JOYPAD_LEFT,
    [PVSega32XButtonRight] = RETRO_DEVICE_ID_JOYPAD_RIGHT,
    [PVSega32XButtonA]     = RETRO_DEVICE_ID_JOYPAD_Y,      // libretro Y → Sega A
    [PVSega32XButtonB]     = RETRO_DEVICE_ID_JOYPAD_B,      // libretro B → Sega B
    [PVSega32XButtonC]     = RETRO_DEVICE_ID_JOYPAD_A,      // libretro A → Sega C
    [PVSega32XButtonX]     = RETRO_DEVICE_ID_JOYPAD_L,      // libretro L → Sega X
    [PVSega32XButtonY]     = RETRO_DEVICE_ID_JOYPAD_X,      // libretro X → Sega Y
    [PVSega32XButtonZ]     = RETRO_DEVICE_ID_JOYPAD_R,      // libretro R → Sega Z
    [PVSega32XButtonStart] = RETRO_DEVICE_ID_JOYPAD_START,
    [PVSega32XButtonMode]  = RETRO_DEVICE_ID_JOYPAD_SELECT, // libretro SELECT → Sega Mode
};

- (void)didPushSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player; {
    _pad[player][Sega32XLibretroMap[button]] = 1;
}

- (void)didReleaseSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player; {
    _pad[player][Sega32XLibretroMap[button]] = 0;
}
@end
