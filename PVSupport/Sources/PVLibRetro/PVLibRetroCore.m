//
//  PVLibretro.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PVLibretro.h"

#import <PVSupport/PVSupport-Swift.h>

#if !TARGET_OS_MACCATALYST
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif

#include "libretro.h"
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include "command.h"
#include "core_info.h"

#include "managers/state_manager.h"
//#include "audio/audio_driver.h"
//#include "camera/camera_driver.h"
//#include "location/location_driver.h"
//#include "record/record_driver.h"
#include "core.h"
#include "performance_counters.h"
#include "system.h"
//#include "gfx/video_context_driver.h"

#include "cores/internal_cores.h"
#include "frontend/frontend_driver.h"
#include "content.h"
#ifdef HAVE_CHEEVOS
#include "cheevos.h"
#endif
#include "retroarch.h"
#include "configuration.h"
#include "general.h"
#include "msg_hash.h"
#include "verbosity.h"

#pragma clang diagnostic push
#pragma clang diagnostic error "-Wall"

#define WIDTH 256
#define HEIGHT 240

static struct retro_core_t core;
static unsigned            core_poll_type;
static bool                core_input_polled;
static bool   core_has_set_input_descriptors = false;
static struct retro_callbacks retro_ctx;

/**
 * input_poll:
 *
 * Input polling callback function.
 **/
void input_poll(void);

/**
 * input_state:
 * @port                 : user number.
 * @device               : device identifier of user.
 * @idx                  : index value of user.
 * @id                   : identifier of key pressed by user.
 *
 * Input state callback function.
 *
 * Returns: Non-zero if the given key (identified by @id) was pressed by the user
 * (assigned to @port).
 **/
int16_t input_state(unsigned port, unsigned device,
	  unsigned idx, unsigned id);

static void core_input_state_poll_maybe(void)
{
   if (core_poll_type == POLL_TYPE_NORMAL)
	  input_poll();
}

static int16_t core_input_state_poll(unsigned port,
	  unsigned device, unsigned idx, unsigned id)
{
   if (core_poll_type == POLL_TYPE_LATE)
   {
	  if (!core_input_polled)
		 input_poll();

	  core_input_polled = true;
   }
   return input_state(port, device, idx, id);
}

void core_set_input_state(retro_ctx_input_state_info_t *info)
{
   core.retro_set_input_state(info->cb);
}

/**
 * core_init_libretro_cbs:
 * @data           : pointer to retro_callbacks object
 *
 * Initializes libretro callbacks, and binds the libretro callbacks
 * to default callback functions.
 **/
static bool core_init_libretro_cbs(void *data)
{
   struct retro_callbacks *cbs = (struct retro_callbacks*)data;
#ifdef HAVE_NETPLAY
   global_t            *global = global_get_ptr();
#endif

   if (!cbs)
	  return false;

//   core.retro_set_video_refresh(video_driver_frame);
//   core.retro_set_audio_sample(audio_driver_sample);
//   core.retro_set_audio_sample_batch(audio_driver_sample_batch);
   core.retro_set_input_state(core_input_state_poll);
   core.retro_set_input_poll(core_input_state_poll_maybe);

   core_set_default_callbacks(cbs);

#ifdef HAVE_NETPLAY
   if (!netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_DATA_INITED, NULL))
	  return true;

   /* Force normal poll type for netplay. */
   core_poll_type = POLL_TYPE_NORMAL;

   if (global->netplay.is_spectate)
   {
	  core.retro_set_input_state(
			(global->netplay.is_client ?
			 input_state_spectate_client : input_state_spectate)
			);
   }
   else
   {
	  core.retro_set_video_refresh(video_frame_net);
	  core.retro_set_audio_sample(audio_sample_net);
	  core.retro_set_audio_sample_batch(audio_sample_batch_net);
	  core.retro_set_input_state(input_state_net);
   }
#endif

   return true;
}

/**
 * core_set_default_callbacks:
 * @data           : pointer to retro_callbacks object
 *
 * Binds the libretro callbacks to default callback functions.
 **/
bool core_set_default_callbacks(void *data)
{
   struct retro_callbacks *cbs = (struct retro_callbacks*)data;

   if (!cbs)
	  return false;

   cbs->frame_cb        = video_driver_frame;
//   cbs->sample_cb       = audio_driver_sample;
//   cbs->sample_batch_cb = audio_driver_sample_batch;
   cbs->state_cb        = core_input_state_poll;
   cbs->poll_cb         = input_poll;

   return true;
}


bool core_deinit(void *data)
{
   struct retro_callbacks *cbs = (struct retro_callbacks*)data;

   if (!cbs)
	  return false;

   cbs->frame_cb        = NULL;
   cbs->sample_cb       = NULL;
   cbs->sample_batch_cb = NULL;
   cbs->state_cb        = NULL;
   cbs->poll_cb         = NULL;

   return true;
}

bool core_uninit_libretro_callbacks(void)
{
   return core_deinit(&retro_ctx);
}

/**
 * core_set_rewind_callbacks:
 *
 * Sets the audio sampling callbacks based on whether or not
 * rewinding is currently activated.
 **/
bool core_set_rewind_callbacks(void)
{
   if (state_manager_frame_is_reversed())
   {
//	  core.retro_set_audio_sample(audio_driver_sample_rewind);
//	  core.retro_set_audio_sample_batch(audio_driver_sample_batch_rewind);
   }
   else
   {
//	  core.retro_set_audio_sample(audio_driver_sample);
//	  core.retro_set_audio_sample_batch(audio_driver_sample_batch);
   }
   return true;
}

bool core_set_cheat(retro_ctx_cheat_info_t *info)
{
   core.retro_cheat_set(info->index, info->enabled, info->code);
   return true;
}

bool core_reset_cheat(void)
{
   core.retro_cheat_reset();
   return true;
}

bool core_api_version(retro_ctx_api_info_t *api)
{
   if (!api)
	  return false;
   api->version = core.retro_api_version();
   return true;
}

bool core_set_poll_type(unsigned *type)
{
   core_poll_type = *type;
   return true;
}

void core_uninit_symbols(void)
{
   uninit_libretro_sym(&core);
}

bool core_init_symbols(enum rarch_core_type *type)
{
   if (!type)
	  return false;
   init_libretro_sym(*type, &core);
   return true;
}

bool core_set_controller_port_device(retro_ctx_controller_info_t *pad)
{
   if (!pad)
	  return false;
   core.retro_set_controller_port_device(pad->port, pad->device);
   return true;
}

bool core_get_memory(retro_ctx_memory_info_t *info)
{
   if (!info)
	  return false;
   info->size  = core.retro_get_memory_size(info->id);
   info->data  = core.retro_get_memory_data(info->id);
   return true;
}

bool core_load_game(retro_ctx_load_content_info_t *load_info)
{
   if (!load_info)
	  return false;

   if (load_info->special)
	  return core.retro_load_game_special(load_info->special->id, load_info->info, load_info->content->size);
   return core.retro_load_game(*load_info->content->elems[0].data ? load_info->info : NULL);
}

bool core_get_system_info(struct retro_system_info *system)
{
   if (!system)
	  return false;
   core.retro_get_system_info(system);
   return true;
}

bool core_unserialize(retro_ctx_serialize_info_t *info)
{
   if (!info)
	  return false;
   if (!core.retro_unserialize(info->data_const, info->size))
	  return false;
   return true;
}

bool core_serialize(retro_ctx_serialize_info_t *info)
{
   if (!info)
	  return false;
   if (!core.retro_serialize(info->data, info->size))
	  return false;
   return true;
}

bool core_serialize_size(retro_ctx_size_info_t *info)
{
   if (!info)
	  return false;
   info->size = core.retro_serialize_size();
   return true;
}

bool core_frame(retro_ctx_frame_info_t *info)
{
   if (!info || !retro_ctx.frame_cb)
	  return false;

   retro_ctx.frame_cb(
		 info->data, info->width, info->height, info->pitch);
   return true;
}

bool core_poll(void)
{
   if (!retro_ctx.poll_cb)
	  return false;
   retro_ctx.poll_cb();
   return true;
}

bool core_set_environment(retro_ctx_environ_info_t *info)
{
   if (!info)
	  return false;
   core.retro_set_environment(info->env);
   return true;
}

bool core_get_system_av_info(struct retro_system_av_info *av_info)
{
   if (!av_info)
	  return false;
   core.retro_get_system_av_info(av_info);
   return true;
}

bool core_reset(void)
{
   core.retro_reset();
   return true;
}

bool core_init(void)
{
   core.retro_init();
   return true;
}

bool core_unload(void)
{
   core.retro_deinit();
   return true;
}

bool core_has_set_input_descriptor(void)
{
   return core_has_set_input_descriptors;
}

void core_set_input_descriptors(void)
{
   core_has_set_input_descriptors = true;
}

void core_unset_input_descriptors(void)
{
   core_has_set_input_descriptors = false;
}

bool core_load(void)
{
   settings_t *settings = config_get_ptr();
   core_poll_type = settings->input.poll_type_behavior;

   if (!core_verify_api_version())
	  return false;
   if (!core_init_libretro_cbs(&retro_ctx))
	  return false;

   core_get_system_av_info(video_viewport_get_system_av_info());
   runloop_ctl(RUNLOOP_CTL_SET_FRAME_LIMIT, NULL);

   return true;
}

@interface PVLibRetroCore ()
{
}
@end

@implementation PVLibRetroCore
static __weak PVLibRetroCore *_current;

- (instancetype)init {
    if((self = [super init])) {
		core.retro_init();
    }

    _current = self;

    return self;
}

- (void)dealloc {
	core.retro_deinit();
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory withIntermediateDirectories:YES attributes:nil error:nil];

    struct retro_game_info info;
    info.path = [path cStringUsingEncoding:NSUTF8StringEncoding];
    
    BOOL loaded = false; //retro_load_game(&info);
    
    return loaded;
}

- (void)executeFrame {
    [self executeFrameSkippingFrame:NO];
}

- (void)executeFrameSkippingFrame:(BOOL)skip {
	switch (core_poll_type)
	{
	   case POLL_TYPE_EARLY:
//		  input_poll();
		  break;
	   case POLL_TYPE_LATE:
		  core_input_polled = false;
		  break;
	}
	if (core.retro_run)
	   core.retro_run();
//	if (core_poll_type == POLL_TYPE_LATE && !core_input_polled)
//	   input_poll();
//	return true;
//    retro_run();
//    for (unsigned y = 0; y < HEIGHT; y++)
//        for (unsigned x = 0; x < WIDTH; x++, pXBuf++)
//            videoBuffer[y * WIDTH + x] = palette[*pXBuf];
//
//    for (int i = 0; i < soundSize; i++)
//        soundBuffer[i] = (soundBuffer[i] << 16) | (soundBuffer[i] & 0xffff);
//
//    [[self ringBufferAtIndex:0] write:soundBuffer maxLength:soundSize << 2];
}

- (void)resetEmulation {
//    retro_reset();
}

- (void)stopEmulation {
//    retro_unload_game();
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval {
    return 1.0 / 60.0;
}

# pragma mark - Video

- (const void *)videoBuffer {
    return NULL;
}

- (CGRect)screenRect {
    return CGRectMake(0, 0, WIDTH, HEIGHT);
}

- (CGSize)aspectSize
{
    return CGSizeMake(4, 3);
}

- (CGSize)bufferSize
{
    return CGSizeMake(WIDTH, HEIGHT);
}

- (GLenum)pixelFormat {
    return GL_BGRA;
}

- (GLenum)pixelType {
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
    return GL_RGBA;
}

# pragma mark - Audio

- (double)audioSampleRate {
    return 44100;
}

- (NSUInteger)channelCount {
    return 2;
}

@end

# pragma mark - Save States
@implementation PVLibRetroCore (Saves)

#pragma mark Properties
-(BOOL)supportsSaveStates {
    return false; //return retro_get_memory_size(0) != 0 && retro_get_memory_data(0) != NULL;
}

#pragma mark Methods
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        // Save
        //  bool retro_serialize_all(DBPArchive& ar, bool unlock_thread)
        return YES;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    @synchronized(self) {
        BOOL success = NO; // bool retro_unserialize(const void *data, size_t size)
        if (!success) {
            if(error != NULL) {
                NSDictionary *userInfo = @{
                                           NSLocalizedDescriptionKey: @"Failed to save state.",
                                           NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
                                           NSLocalizedRecoverySuggestionErrorKey: @""
                                           };

                NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                        code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                    userInfo:userInfo];

                *error = newError;
            }
        }
        return success;
    }
}
//
//- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
//    return NO;
//}
//
//- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    block(NO, nil);
//}
//
//- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
//    return NO;
//}
//
//- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    block(NO, nil);
//}
//
@end

@implementation PVLibRetroCore (Cheats)

- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
    // void retro_cheat_reset(void) { }
//    void retro_cheat_set(unsigned index, bool enabled, const char *code) { (void)index; (void)enabled; (void)code; }
}

@end

unsigned retro_api_version(void)
{
	return 1; //RETRO_API_VERSION;
}

#pragma clang diagnostic pop
