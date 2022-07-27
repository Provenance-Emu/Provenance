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
#include <dynamic/dylib.h>
#include <string/stdstring.h>

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
#include <retro_assert.h>

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

#define RETRO_API_VERSION 1

static struct retro_core_t core;
static unsigned            core_poll_type;
static bool                core_input_polled;
static bool   core_has_set_input_descriptors = false;
static struct retro_callbacks retro_ctx;

typedef void *dylib_t;
typedef void (*function_t)(void);

static dylib_t lib_handle;

void retroarch_fail(int error_code, const char *error) {
    ELOG(@"Code: %i, Error: %s", error_code, error);
}


#define SYMBOL(x) do { \
   function_t func = dylib_proc(lib_handle, #x); \
   memcpy(&current_core->x, &func, sizeof(func)); \
   if (current_core->x == NULL) { ELOG(@"Failed to load symbol: \"%s\"\n", #x); retroarch_fail(1, "init_libretro_sym()"); } \
} while (0)

#define SYMBOL_DUMMY(x) current_core->x = libretro_dummy_##x

static void load_symbols(enum rarch_core_type type, struct retro_core_t *current_core);

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
      unsigned idx, unsigned id)
{
   int16_t res                     = 0;
//   settings_t *settings            = config_get_ptr();
   
//
//   device &= RETRO_DEVICE_MASK;
//
//   if (bsv_movie_ctl(BSV_MOVIE_CTL_PLAYBACK_ON, NULL))
//   {
//      int16_t ret;
//      if (bsv_movie_ctl(BSV_MOVIE_CTL_GET_INPUT, &ret))
//         return ret;
//
//      bsv_movie_ctl(BSV_MOVIE_CTL_SET_END, NULL);
//   }
//
//   if (settings->input.remap_binds_enable)
//      input_remapping_state(port, &device, &idx, &id);
//
//   if (!input_driver_is_flushing_input()
//         && !input_driver_is_libretro_input_blocked())
//   {
//      if (((id < RARCH_FIRST_META_KEY) || (device == RETRO_DEVICE_KEYBOARD)))
//         res = current_input->input_state(
//               current_input_data, libretro_input_binds, port, device, idx, id);
//
//#ifdef HAVE_OVERLAY
//      input_state_overlay(&res, port, device, idx, id);
//#endif
//
//#ifdef HAVE_NETWORKGAMEPAD
//      input_remote_state(&res, port, device, idx, id);
//#endif
//   }
//
//   /* Don't allow turbo for D-pad. */
//   if (device == RETRO_DEVICE_JOYPAD && (id < RETRO_DEVICE_ID_JOYPAD_UP ||
//            id > RETRO_DEVICE_ID_JOYPAD_RIGHT))
//   {
//      /*
//       * Apply turbo button if activated.
//       *
//       * If turbo button is held, all buttons pressed except
//       * for D-pad will go into a turbo mode. Until the button is
//       * released again, the input state will be modulated by a
//       * periodic pulse defined by the configured duty cycle.
//       */
//      if (res && input_driver_turbo_btns.frame_enable[port])
//         input_driver_turbo_btns.enable[port] |= (1 << id);
//      else if (!res)
//         input_driver_turbo_btns.enable[port] &= ~(1 << id);
//
//      if (input_driver_turbo_btns.enable[port] & (1 << id))
//      {
//         /* if turbo button is enabled for this key ID */
//         res = res && ((input_driver_turbo_btns.count % settings->input.turbo_period)
//               < settings->input.turbo_duty_cycle);
//      }
//   }
//
//   if (bsv_movie_ctl(BSV_MOVIE_CTL_PLAYBACK_OFF, NULL))
//      bsv_movie_ctl(BSV_MOVIE_CTL_SET_INPUT, &res);

   return res;
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
//   if (state_manager_frame_is_reversed())
//   {
//	  core.retro_set_audio_sample(audio_driver_sample_rewind);
//	  core.retro_set_audio_sample_batch(audio_driver_sample_batch_rewind);
//   }
//   else
//   {
//	  core.retro_set_audio_sample(audio_driver_sample);
//	  core.retro_set_audio_sample_batch(audio_driver_sample_batch);
//   }
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

static settings_t *configuration_settings = NULL;

settings_t *config_get_ptr(void)
{
   return configuration_settings;
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
//   runloop_ctl(RUNLOOP_CTL_SET_FRAME_LIMIT, NULL);

   return true;
}

struct retro_system_av_info *video_viewport_get_system_av_info(void)
{
   static struct retro_system_av_info av_info;

   return &av_info;
}


bool core_verify_api_version(void)
{
//   unsigned api_version = core.retro_api_version();
//   RARCH_LOG("%s: %u\n",
//         msg_hash_to_str(MSG_VERSION_OF_LIBRETRO_API),
//         api_version);
//   RARCH_LOG("%s: %u\n",
//         msg_hash_to_str(MSG_COMPILED_AGAINST_API),
//         RETRO_API_VERSION);
//
//   if (api_version != RETRO_API_VERSION)
//   {
//      RARCH_WARN("%s\n", msg_hash_to_str(MSG_LIBRETRO_ABI_BREAK));
//      return false;
//   }
   return true;
}

/**
 * init_libretro_sym:
 * @type                        : Type of core to be loaded.
 *                                If CORE_TYPE_DUMMY, will
 *                                load dummy symbols.
 *
 * Initializes libretro symbols and
 * setups environment callback functions.
 **/
//void init_libretro_sym(enum rarch_core_type type, struct retro_core_t *current_core)
//{
   /* Guarantee that we can do "dirty" casting.
    * Every OS that this program supports should pass this. */
//   retro_assert(sizeof(void*) == sizeof(void (*)(void)));
//
//   load_symbols(type, current_core);
//}

/**
 * input_poll:
 *
 * Input polling callback function.
 **/
void input_poll(void)
{
//   size_t i;
//   settings_t *settings           = config_get_ptr();
//
//   input_driver_poll();
//
//   for (i = 0; i < MAX_USERS; i++)
//      libretro_input_binds[i] = settings->input.binds[i];
//
//#ifdef HAVE_OVERLAY
//   input_poll_overlay(NULL, settings->input.overlay_opacity);
//#endif
//
//#ifdef HAVE_COMMAND
//   if (input_driver_command)
//      command_poll(input_driver_command);
//#endif
//
//#ifdef HAVE_NETWORKGAMEPAD
//   if (input_driver_remote)
//      input_remote_poll(input_driver_remote);
//#endif
}

/**
 * uninit_libretro_sym:
 *
 * Frees libretro core.
 *
 * Frees all core options,
 * associated state, and
 * unbind all libretro callback symbols.
 **/
void uninit_libretro_sym(struct retro_core_t *current_core)
{
//#ifdef HAVE_DYNAMIC
//   if (lib_handle)
//      dylib_close(lib_handle);
//   lib_handle = NULL;
//#endif
//
//   memset(current_core, 0, sizeof(struct retro_core_t));
//
//   runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_DEINIT, NULL);
//   runloop_ctl(RUNLOOP_CTL_SYSTEM_INFO_FREE, NULL);
//   runloop_ctl(RUNLOOP_CTL_FRAME_TIME_FREE, NULL);
//   camera_driver_ctl(RARCH_CAMERA_CTL_UNSET_ACTIVE, NULL);
////   location_driver_ctl(RARCH_LOCATION_CTL_UNSET_ACTIVE, NULL);
//
//   /* Performance counters no longer valid. */
//   performance_counters_clear();
}

/**
 * video_driver_frame:
 * @data                 : pointer to data of the video frame.
 * @width                : width of the video frame.
 * @height               : height of the video frame.
 * @pitch                : pitch of the video frame.
 *
 * Video frame render callback function.
 **/
void video_driver_frame(const void *data, unsigned width,
      unsigned height, size_t pitch)
{
//   static char video_driver_msg[256];
//   unsigned output_width  = 0;
//   unsigned output_height = 0;
//   unsigned  output_pitch = 0;
//   const char *msg        = NULL;
//   settings_t *settings   = config_get_ptr();
//
//   runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_PULL,   &msg);
//
//   if (!video_driver_is_active())
//      return;
//
//   if (video_driver_scaler_ptr &&
//         video_pixel_frame_scale(data, width, height, pitch))
//   {
//      data                = video_driver_scaler_ptr->scaler_out;
//      pitch               = video_driver_scaler_ptr->scaler->out_stride;
//   }
//
//   video_driver_cached_frame_set(data, width, height, pitch);
//
//   /* Slightly messy code,
//    * but we really need to do processing before blocking on VSync
//    * for best possible scheduling.
//    */
//   if (
//         (
//             !video_driver_state.filter.filter
//          || !settings->video.post_filter_record
//          || !data
//          || video_driver_has_gpu_record()
//         )
//      )
//      recording_dump_frame(data, width, height, pitch);
//
//   if (video_driver_frame_filter(data, width, height, pitch,
//            &output_width, &output_height, &output_pitch))
//   {
//      data   = video_driver_state.filter.buffer;
//      width  = output_width;
//      height = output_height;
//      pitch  = output_pitch;
//   }
//
//   video_driver_msg[0] = '\0';
//   if (msg)
//      strlcpy(video_driver_msg, msg, sizeof(video_driver_msg));
//
//   if (!current_video || !current_video->frame(
//            video_driver_data, data, width, height,
//            video_driver_frame_count,
//            pitch, video_driver_msg))
//   {
//      video_driver_unset_active();
//   }
//
//   video_driver_frame_count++;
}

const char *config_get_active_core_path(void) {
    NSBundle *bundle = [NSBundle bundleForClass:[_current class]];
    const char* path = [bundle.executablePath cStringUsingEncoding:NSUTF8StringEncoding];
    return path;
}
/**
 * init_libretro_sym:
 * @type                        : Type of core to be loaded.
 *                                If CORE_TYPE_DUMMY, will
 *                                load dummy symbols.
 *
 * Initializes libretro symbols and
 * setups environment callback functions.
 **/
void init_libretro_sym(enum rarch_core_type type, struct retro_core_t *current_core)
{
   /* Guarantee that we can do "dirty" casting.
    * Every OS that this program supports should pass this. */
   retro_assert(sizeof(void*) == sizeof(void (*)(void)));

   load_symbols(type, current_core);
}

static void load_dynamic_core(void)
{
    
    ILOG(@"Loading dynamic libretro core from: \"%s\"\n",
    config_get_active_core_path());
    const char* corepath = config_get_active_core_path();
    lib_handle = dylib_load(corepath);

   function_t sym       = dylib_proc(lib_handle, "retro_init");

   if (sym)
   {
      /* Try to verify that -lretro was not linked in from other modules
       * since loading it dynamically and with -l will fail hard. */
      ELOG(@"Serious problem. RetroArch wants to load libretro cores"
            "dyamically, but it is already linked.\n");
       ELOG(@"This could happen if other modules RetroArch depends on "
            "link against libretro directly.\n");
       ELOG(@"Proceeding could cause a crash. Aborting ...\n");
      retroarch_fail(1, "init_libretro_sym()");
   }

   if (string_is_empty(config_get_active_core_path()))
   {
       ELOG(@"RetroArch is built for dynamic libretro cores, but "
            "libretro_path is not set. Cannot continue.\n");
      retroarch_fail(1, "init_libretro_sym()");
   }

   /* Need to use absolute path for this setting. It can be
    * saved to content history, and a relative path would
    * break in that scenario. */
//   path_resolve_realpath(
//         config_get_active_core_path_ptr(),
//         config_get_active_core_path_size());
//
//   ILOG(@"Loading dynamic libretro core from: \"%s\"\n",
//         config_get_active_core_path());
//   lib_handle = dylib_load(config_get_active_core_path());
   if (!lib_handle)
   {
   ELOG(@"Failed to open libretro core: \"%s\"\n",
            config_get_active_core_path());
       ELOG(@"Error(s): %s\n", dylib_error());
      retroarch_fail(1, "load_dynamic()");
   }
}

/**
 * load_symbols:
 * @type                        : Type of core to be loaded.
 *                                If CORE_TYPE_DUMMY, will
 *                                load dummy symbols.
 *
 * Setup libretro callback symbols.
 **/
static void load_symbols(enum rarch_core_type type, struct retro_core_t *current_core)
{
   switch (type)
   {
      case CORE_TYPE_PLAIN:
#ifdef HAVE_DYNAMIC
         load_dynamic_core();
#endif

         SYMBOL(retro_init);
         SYMBOL(retro_deinit);

         SYMBOL(retro_api_version);
         SYMBOL(retro_get_system_info);
         SYMBOL(retro_get_system_av_info);

         SYMBOL(retro_set_environment);
         SYMBOL(retro_set_video_refresh);
         SYMBOL(retro_set_audio_sample);
         SYMBOL(retro_set_audio_sample_batch);
         SYMBOL(retro_set_input_poll);
         SYMBOL(retro_set_input_state);

         SYMBOL(retro_set_controller_port_device);

         SYMBOL(retro_reset);
         SYMBOL(retro_run);

         SYMBOL(retro_serialize_size);
         SYMBOL(retro_serialize);
         SYMBOL(retro_unserialize);

         SYMBOL(retro_cheat_reset);
         SYMBOL(retro_cheat_set);

         SYMBOL(retro_load_game);
         SYMBOL(retro_load_game_special);

         SYMBOL(retro_unload_game);
         SYMBOL(retro_get_region);
         SYMBOL(retro_get_memory_data);
         SYMBOL(retro_get_memory_size);
         break;
      case CORE_TYPE_DUMMY:
         SYMBOL_DUMMY(retro_init);
         SYMBOL_DUMMY(retro_deinit);

         SYMBOL_DUMMY(retro_api_version);
         SYMBOL_DUMMY(retro_get_system_info);
         SYMBOL_DUMMY(retro_get_system_av_info);

         SYMBOL_DUMMY(retro_set_environment);
         SYMBOL_DUMMY(retro_set_video_refresh);
         SYMBOL_DUMMY(retro_set_audio_sample);
         SYMBOL_DUMMY(retro_set_audio_sample_batch);
         SYMBOL_DUMMY(retro_set_input_poll);
         SYMBOL_DUMMY(retro_set_input_state);

         SYMBOL_DUMMY(retro_set_controller_port_device);

         SYMBOL_DUMMY(retro_reset);
         SYMBOL_DUMMY(retro_run);

         SYMBOL_DUMMY(retro_serialize_size);
         SYMBOL_DUMMY(retro_serialize);
         SYMBOL_DUMMY(retro_unserialize);

         SYMBOL_DUMMY(retro_cheat_reset);
         SYMBOL_DUMMY(retro_cheat_set);

         SYMBOL_DUMMY(retro_load_game);
         SYMBOL_DUMMY(retro_load_game_special);

         SYMBOL_DUMMY(retro_unload_game);
         SYMBOL_DUMMY(retro_get_region);
         SYMBOL_DUMMY(retro_get_memory_data);
         SYMBOL_DUMMY(retro_get_memory_size);
         break;
      case CORE_TYPE_FFMPEG:
#ifdef HAVE_FFMPEG
         SYMBOL_FFMPEG(retro_init);
         SYMBOL_FFMPEG(retro_deinit);

         SYMBOL_FFMPEG(retro_api_version);
         SYMBOL_FFMPEG(retro_get_system_info);
         SYMBOL_FFMPEG(retro_get_system_av_info);

         SYMBOL_FFMPEG(retro_set_environment);
         SYMBOL_FFMPEG(retro_set_video_refresh);
         SYMBOL_FFMPEG(retro_set_audio_sample);
         SYMBOL_FFMPEG(retro_set_audio_sample_batch);
         SYMBOL_FFMPEG(retro_set_input_poll);
         SYMBOL_FFMPEG(retro_set_input_state);

         SYMBOL_FFMPEG(retro_set_controller_port_device);

         SYMBOL_FFMPEG(retro_reset);
         SYMBOL_FFMPEG(retro_run);

         SYMBOL_FFMPEG(retro_serialize_size);
         SYMBOL_FFMPEG(retro_serialize);
         SYMBOL_FFMPEG(retro_unserialize);

         SYMBOL_FFMPEG(retro_cheat_reset);
         SYMBOL_FFMPEG(retro_cheat_set);

         SYMBOL_FFMPEG(retro_load_game);
         SYMBOL_FFMPEG(retro_load_game_special);

         SYMBOL_FFMPEG(retro_unload_game);
         SYMBOL_FFMPEG(retro_get_region);
         SYMBOL_FFMPEG(retro_get_memory_data);
         SYMBOL_FFMPEG(retro_get_memory_size);
#endif
         break;
      case CORE_TYPE_IMAGEVIEWER:
#ifdef HAVE_IMAGEVIEWER
         SYMBOL_IMAGEVIEWER(retro_init);
         SYMBOL_IMAGEVIEWER(retro_deinit);

         SYMBOL_IMAGEVIEWER(retro_api_version);
         SYMBOL_IMAGEVIEWER(retro_get_system_info);
         SYMBOL_IMAGEVIEWER(retro_get_system_av_info);

         SYMBOL_IMAGEVIEWER(retro_set_environment);
         SYMBOL_IMAGEVIEWER(retro_set_video_refresh);
         SYMBOL_IMAGEVIEWER(retro_set_audio_sample);
         SYMBOL_IMAGEVIEWER(retro_set_audio_sample_batch);
         SYMBOL_IMAGEVIEWER(retro_set_input_poll);
         SYMBOL_IMAGEVIEWER(retro_set_input_state);

         SYMBOL_IMAGEVIEWER(retro_set_controller_port_device);

         SYMBOL_IMAGEVIEWER(retro_reset);
         SYMBOL_IMAGEVIEWER(retro_run);

         SYMBOL_IMAGEVIEWER(retro_serialize_size);
         SYMBOL_IMAGEVIEWER(retro_serialize);
         SYMBOL_IMAGEVIEWER(retro_unserialize);

         SYMBOL_IMAGEVIEWER(retro_cheat_reset);
         SYMBOL_IMAGEVIEWER(retro_cheat_set);

         SYMBOL_IMAGEVIEWER(retro_load_game);
         SYMBOL_IMAGEVIEWER(retro_load_game_special);

         SYMBOL_IMAGEVIEWER(retro_unload_game);
         SYMBOL_IMAGEVIEWER(retro_get_region);
         SYMBOL_IMAGEVIEWER(retro_get_memory_data);
         SYMBOL_IMAGEVIEWER(retro_get_memory_size);
#endif
         break;
      case CORE_TYPE_NETRETROPAD:
#if defined(HAVE_NETWORKGAMEPAD) && defined(HAVE_NETPLAY)
         SYMBOL_NETRETROPAD(retro_init);
         SYMBOL_NETRETROPAD(retro_deinit);

         SYMBOL_NETRETROPAD(retro_api_version);
         SYMBOL_NETRETROPAD(retro_get_system_info);
         SYMBOL_NETRETROPAD(retro_get_system_av_info);

         SYMBOL_NETRETROPAD(retro_set_environment);
         SYMBOL_NETRETROPAD(retro_set_video_refresh);
         SYMBOL_NETRETROPAD(retro_set_audio_sample);
         SYMBOL_NETRETROPAD(retro_set_audio_sample_batch);
         SYMBOL_NETRETROPAD(retro_set_input_poll);
         SYMBOL_NETRETROPAD(retro_set_input_state);

         SYMBOL_NETRETROPAD(retro_set_controller_port_device);

         SYMBOL_NETRETROPAD(retro_reset);
         SYMBOL_NETRETROPAD(retro_run);

         SYMBOL_NETRETROPAD(retro_serialize_size);
         SYMBOL_NETRETROPAD(retro_serialize);
         SYMBOL_NETRETROPAD(retro_unserialize);

         SYMBOL_NETRETROPAD(retro_cheat_reset);
         SYMBOL_NETRETROPAD(retro_cheat_set);

         SYMBOL_NETRETROPAD(retro_load_game);
         SYMBOL_NETRETROPAD(retro_load_game_special);

         SYMBOL_NETRETROPAD(retro_unload_game);
         SYMBOL_NETRETROPAD(retro_get_region);
         SYMBOL_NETRETROPAD(retro_get_memory_data);
         SYMBOL_NETRETROPAD(retro_get_memory_size);
#endif
         break;
      case CORE_TYPE_VIDEO_PROCESSOR:
#if defined(HAVE_VIDEO_PROCESSOR)
         SYMBOL_VIDEOPROCESSOR(retro_init);
         SYMBOL_VIDEOPROCESSOR(retro_deinit);

         SYMBOL_VIDEOPROCESSOR(retro_api_version);
         SYMBOL_VIDEOPROCESSOR(retro_get_system_info);
         SYMBOL_VIDEOPROCESSOR(retro_get_system_av_info);

         SYMBOL_VIDEOPROCESSOR(retro_set_environment);
         SYMBOL_VIDEOPROCESSOR(retro_set_video_refresh);
         SYMBOL_VIDEOPROCESSOR(retro_set_audio_sample);
         SYMBOL_VIDEOPROCESSOR(retro_set_audio_sample_batch);
         SYMBOL_VIDEOPROCESSOR(retro_set_input_poll);
         SYMBOL_VIDEOPROCESSOR(retro_set_input_state);

         SYMBOL_VIDEOPROCESSOR(retro_set_controller_port_device);

         SYMBOL_VIDEOPROCESSOR(retro_reset);
         SYMBOL_VIDEOPROCESSOR(retro_run);

         SYMBOL_VIDEOPROCESSOR(retro_serialize_size);
         SYMBOL_VIDEOPROCESSOR(retro_serialize);
         SYMBOL_VIDEOPROCESSOR(retro_unserialize);

         SYMBOL_VIDEOPROCESSOR(retro_cheat_reset);
         SYMBOL_VIDEOPROCESSOR(retro_cheat_set);

         SYMBOL_VIDEOPROCESSOR(retro_load_game);
         SYMBOL_VIDEOPROCESSOR(retro_load_game_special);

         SYMBOL_VIDEOPROCESSOR(retro_unload_game);
         SYMBOL_VIDEOPROCESSOR(retro_get_region);
         SYMBOL_VIDEOPROCESSOR(retro_get_memory_data);
         SYMBOL_VIDEOPROCESSOR(retro_get_memory_size);
#endif
         break;
   }
}


@interface PVLibRetroCore ()
{
}
@end

@implementation PVLibRetroCore

- (instancetype)init {
    if((self = [super init])) {
        _current = self;

    //        const char* path = [[NSBundle bundleForClass:[self class]].bundlePath cStringUsingEncoding:NSUTF8StringEncoding];
    //        config_set_active_core_path(path);
        init_libretro_sym(CORE_TYPE_PLAIN, &core);
        load_dynamic_core();
    //        libretro_get_system_info(path,
    //        libretro_get_system_info_lib
        core.retro_init();
    }

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
    // TODO:: retro_load_game
    BOOL loaded = core.retro_load_game(&info); // retro_load_game(&info);
    
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
    core.retro_reset();
}

- (void)stopEmulation {
    core.retro_unload_game();
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval {
    static struct retro_system_av_info av_info;
    core.retro_get_system_av_info(&av_info);
    return 1.0 / av_info.timing.fps;
}

# pragma mark - Video

- (const void *)videoBuffer {
    return NULL;
}

- (CGRect)screenRect {
    static struct retro_system_av_info av_info;
    core.retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.base_height;
    unsigned width = av_info.geometry.base_width;

    return CGRectMake(0, 0, width, height);
}

- (CGSize)aspectSize {
    static struct retro_system_av_info av_info;
    core.retro_get_system_av_info(&av_info);
    float aspect_ratio = av_info.geometry.aspect_ratio;
//    unsigned height = av_info.geometry.max_height;
//    unsigned width = av_info.geometry.max_width;
    if (aspect_ratio == 1.0) {
        return CGSizeMake(1, 1);
    } else if (aspect_ratio < 1.2 && aspect_ratio > 1.1) {
        return CGSizeMake(10, 9);
    } else if (aspect_ratio < 1.26 && aspect_ratio > 1.24) {
        return CGSizeMake(5, 4);
    } else if (aspect_ratio < 1.4 && aspect_ratio > 1.3) {
        return CGSizeMake(4, 3);
    } else if (aspect_ratio < 1.6 && aspect_ratio > 1.4) {
        return CGSizeMake(3, 2);
    } else if (aspect_ratio < 1.7 && aspect_ratio > 1.6) {
        return CGSizeMake(16, 9);
    } else {
        return CGSizeMake(4, 3);
    }
}

- (CGSize)bufferSize {
    static struct retro_system_av_info av_info;
    core.retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.max_height;
    unsigned width = av_info.geometry.max_width;
    
    return CGSizeMake(width, height);
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
    static struct retro_system_av_info av_info;
    core.retro_get_system_av_info(&av_info);
    double sample_rate = av_info.timing.sample_rate;
    return sample_rate;
}

- (NSUInteger)channelCount {
    return 2;
}

@end

# pragma mark - Save States
@implementation PVLibRetroCore (Saves)

#pragma mark Properties
-(BOOL)supportsSaveStates {
    return core.retro_get_memory_size(0) != 0 && core.retro_get_memory_data(0) != NULL;
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
    unsigned index = 0;
    const char* cCode = [code cStringUsingEncoding:NSUTF8StringEncoding];
    core.retro_cheat_set(index, enabled, cCode);
    // void retro_cheat_reset(void) { }
//    void retro_cheat_set(unsigned index, bool enabled, const char *code) { (void)index; (void)enabled; (void)code; }
}

@end

unsigned retro_api_version(void)
{
	return RETRO_API_VERSION;
}

#pragma clang diagnostic pop
