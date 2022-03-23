//
//  PVTGBDualCore.mm
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualCore.h"
#import "PVTGBDualCore+Audio.h"
#import "PVTGBDualCore+Controls.h"
#import "PVTGBDualCore+Saves.h"
#import "PVTGBDualCore+Video.h"

#include "libretro.h"

void log(retro_log_level level, const char *fmt, ...) {
    
}

@interface PVTGBDualCore () {
    bool emulationHasRun;
}

@end

static __weak PVTGBDualCore *_current;

@implementation PVTGBDualCore


#pragma mark - PVTGBDualCore Begin
- (id)init {
    if (self = [super init]) {
        emulationHasRun = false;
    }
    
    _current = self;
    return self;
}

- (void)dealloc {
    free(_videoBuffer);
    _current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error {
    memset(_gb_pad, 0, sizeof(uint16_t) * NUMBER_OF_PADS * NUMBER_OF_PAD_INPUTS);
    
    const void *data;
    size_t size;
    self.romName = [[[path lastPathComponent] componentsSeparatedByString:@"."] objectAtIndex:0];
    
    //load cart, read bytes, get length
    NSData* dataObj = [NSData dataWithContentsOfFile:[path stringByStandardizingPath]];
    if(dataObj == nil) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Failed to load game.",
            NSLocalizedFailureReasonErrorKey: @"TGBDual failed to load ROM.",
            NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format TGBDual supports."
        };
        
        *error = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                     code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                 userInfo:userInfo];
        ELOG(@"dataObj is nil");
        return false;
    }
    size = [dataObj length];
    data = (uint8_t*)[dataObj bytes];
    const char *meta = NULL;
    
    retro_set_environment(environment_callback);
    retro_set_video_refresh(video_callback);
    retro_set_input_poll(input_poll_callback);
    retro_set_input_state(input_state_callback);
    retro_set_audio_sample(audio_callback);
    retro_set_audio_sample_batch(audio_batch_callback);
    
    retro_init();
    
    const char *fullPath = [path UTF8String];
    
    struct retro_game_info info = {NULL};
    info.path = fullPath;
    info.data = data;
    info.size = size;
    info.meta = meta;
    
    if(retro_load_game(&info)) {
        if([self.batterySavesPath length]) {
            NSError *fmError;
            [[NSFileManager defaultManager] createDirectoryAtPath:self.batterySavesPath withIntermediateDirectories:YES attributes:nil error:&fmError];
            
            if (error) {
                ELOG(@"%@", fmError.localizedDescription);
                *error = fmError;
            }
            
            NSString *filePath = [self.batterySavesPath stringByAppendingPathComponent:[self.romName stringByAppendingPathExtension:@"sav"]];
            
            BOOL success = [self loadSaveFile:filePath forType: RETRO_MEMORY_SAVE_RAM];
            if (!success) {
                ELOG(@"failed to load battery save: %@", filePath);
            }
        }
        
        struct retro_system_av_info info;
        retro_get_system_av_info(&info);
        
        if (_videoBuffer) {
            free(_videoBuffer);
        }
        
        _videoWidth = info.geometry.max_width;
        _videoHeight = info.geometry.max_height;
        _videoBuffer = (uint16_t*)malloc(_videoWidth * _videoHeight * 2 * 2);
        
        _frameInterval = info.timing.fps;
        _sampleRate = info.timing.sample_rate;
        
        retro_get_region();
        retro_run();
        
        return YES;
    }
    
    if (error) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"TGBDual failed to load ROM.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format TGBDual supports."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
    }
    
    return NO;
}

 - (void)startEmulation {
     if(self.isRunning == false) {
         emulationHasRun = true;
         [super startEmulation];
     }
}

- (void)stopEmulation {
    if (emulationHasRun) {
        if([self.batterySavesPath length]) {
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
        
        emulationHasRun = false;
    }
}

- (void)resetEmulation {
    retro_reset();
}


static void audio_callback(int16_t left, int16_t right) {
    GET_CURRENT_OR_RETURN();
    [[current ringBufferAtIndex:0] write:&left maxLength:2];
    [[current ringBufferAtIndex:0] write:&right maxLength:2];
}

static size_t audio_batch_callback(const int16_t *data, size_t frames) {
    GET_CURRENT_OR_RETURN(frames);
    [[current ringBufferAtIndex:0] write:data maxLength:frames << 2];
    return frames;
}

static dispatch_queue_t memcpy_queue =
dispatch_queue_create("tgbdual memcpy queue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0));

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch) {
    GET_CURRENT_OR_RETURN();
    current->_videoWidth  = width;
    current->_videoHeight = height;
    
    dispatch_apply(height, memcpy_queue, ^(size_t y){
        const uint16_t *src = (uint16_t*)data + y * (pitch >> TGBDUAL_PITCH_SHIFT); //pitch is in bytes not pixels
        uint16_t *dst = current->_videoBuffer + y * current->_videoWidth;
        
        memcpy(dst, src, sizeof(uint16_t)*width);
    });
}

static void input_poll_callback(void) {
    GET_CURRENT_OR_RETURN();
    [current pollControllers];
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id) {
    GET_CURRENT_OR_RETURN(0);
    //NSLog(@"polled input: port: %d device: %d id: %d", port, device, _id);
    
    if (port == 0 & device == RETRO_DEVICE_JOYPAD) {
        return current->_gb_pad[0][_id];
    }
    else if(port == 1 & device == RETRO_DEVICE_JOYPAD) {
        return current->_gb_pad[1][_id];
    }
    
    return 0;
}


static bool environment_callback(unsigned cmd, void *data) {
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
                    ILOG(@"Environ SET_PIXEL_FORMAT: 0RGB1555");
                    break;
                
                case RETRO_PIXEL_FORMAT_RGB565:
                    ILOG(@"Environ SET_PIXEL_FORMAT: RGB565");
                    break;
                    
                case RETRO_PIXEL_FORMAT_XRGB8888:
                    ILOG(@"Environ SET_PIXEL_FORMAT: XRGB8888");
                    break;
                    
                default:
                    return false;
            }
            break;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY :
        {
            NSString *appSupportPath = current.BIOSPath;
            
            *(const char **)data = [appSupportPath UTF8String];
            ILOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE:
        {
            auto req = (retro_variable *)data;
            if(!strcmp(req->key, "tgbdual_gblink_enable"))
            {
                req->value = "enabled"; //disabled|enabled
                ILOG(@"Setting key: %s to val: %s", req->key, req->value);
                return true;
            }
            else if(!strcmp(req->key, "tgbdual_screen_placement"))
            {
                req->value = "left-right"; //left-right|top-down
                ILOG(@"Setting key: %s to val: %s", req->key, req->value);
                return true;
            }
            else if(!strcmp(req->key, "tgbdual_switch_screens"))
            {
                req->value = "normal"; //normal|switched
                ILOG(@"Setting key: %s to val: %s", req->key, req->value);
                return true;
            }
            else if(!strcmp(req->key, "tgbdual_single_screen_mp"))
            {
                req->value = "both players"; //both players|player 1 only|player 2 only
                ILOG(@"Setting key: %s to val: %s", req->key, req->value);
                return true;
            }
            else if(!strcmp(req->key, "tgbdual_audio_output"))
            {
                req->value = "Game Boy #1"; //Game Boy #1|Game Boy #2
                ILOG(@"Setting key: %s to val: %s", req->key, req->value);
                return true;
            }

            WLOG(@"Unhandled variable: %s", req->key);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_VARIABLES:
        {
            break;
        }
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
        {
            retro_log_callback log_callback = *(retro_log_callback*)data;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_GEOMETRY:
        case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO:
        {
            break;
        }
        default :
            WLOG(@"Environ UNSUPPORTED (#%u).\n", cmd);
            return false;
    }
    
    return true;
}

@end
