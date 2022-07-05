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
#include "runloop.h"
#include "performance_counters.h"
#include "system.h"
//#include "queues/message_queue.h"
//#include "gfx/video_context_driver.h"
#include <retro_assert.h>

#include "core.h"
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


// MARK: - Retro Structs
static struct retro_core_t      core;
static unsigned                 core_poll_type;
static bool                     core_input_polled;
static bool                     core_has_set_input_descriptors = false;

static struct retro_callbacks   retro_ctx;
//static retro_video_refresh_t video_cb;
//static retro_audio_sample_t audio_cb;
//static retro_audio_sample_batch_t audio_batch_cb;
static retro_environment_t environ_cb;
//static retro_input_poll_t input_poll_cb;
//static retro_input_state_t input_state_cb;

static dylib_t lib_handle;

// MARK: - Runloop
//static rarch_dir_list_t runloop_shader_dir;
static char runloop_fullpath[PATH_MAX_LENGTH];
static char runloop_default_shader_preset[PATH_MAX_LENGTH];
static rarch_system_info_t runloop_system;
static unsigned runloop_pending_windowed_scale;
static struct retro_frame_time_callback runloop_frame_time;
static retro_keyboard_event_t runloop_key_event          = NULL;
static retro_keyboard_event_t runloop_frontend_key_event = NULL;
static retro_usec_t runloop_frame_time_last      = 0;
static unsigned runloop_max_frames               = false;
static bool runloop_force_nonblock               = false;
static bool runloop_frame_time_last_enable       = false;
static bool runloop_set_frame_limit              = false;
static bool runloop_paused                       = false;
static bool runloop_idle                         = false;
static bool runloop_exec                         = false;
static bool runloop_slowmotion                   = false;
static bool runloop_shutdown_initiated           = false;
static bool runloop_core_shutdown_initiated      = false;
static bool runloop_perfcnt_enable               = false;
static bool runloop_overrides_active             = false;
static bool runloop_game_options_active          = false;
//static core_option_manager_t *runloop_core_options = NULL;
#ifdef HAVE_THREADS
static slock_t *_runloop_msg_queue_lock           = NULL;
#endif
//static msg_queue_t *runloop_msg_queue            = NULL;

// MARK: - Config

static char path_libretro[PATH_MAX_LENGTH];

char *config_get_active_core_path_ptr(void)
{
   return path_libretro;
}

//const char *config_get_active_core_path(void)
//{
//   return path_libretro;
//}

bool config_active_core_path_is_empty(void)
{
   return !path_libretro[0];
}

size_t config_get_active_core_path_size(void)
{
   return sizeof(path_libretro);
}

void config_set_active_core_path(const char *path)
{
   strlcpy(path_libretro, path, sizeof(path_libretro));
}

void config_clear_active_core_path(void)
{
   *path_libretro = '\0';
}

const char *config_get_active_path(void)
{
//   global_t   *global          = global_get_ptr();
//
//   if (!string_is_empty(global->path.config))
//	  return global->path.config;


   return NULL;
}

void config_free_state(void)
{
}


// MARK: - Retro typedefs
typedef void *dylib_t;
typedef void (*function_t)(void);

// MARK: - Retro Macros

void retroarch_fail(int error_code, const char *error) {
    ELOG(@"Code: %i, Error: %s", error_code, error);
}

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
    
   core.retro_set_video_refresh(video_driver_frame);
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
//	cbs->sample_cb       = audio_callback;
//	cbs->sample_batch_cb = audio_batch_callback;
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
   runloop_ctl(RUNLOOP_CTL_SET_FRAME_LIMIT, NULL);
    
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
    #ifdef HAVE_DYNAMIC
       if (lib_handle)
          dylib_close(lib_handle);
       lib_handle = NULL;
    #endif
    
       memset(current_core, 0, sizeof(struct retro_core_t));
    
      runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_DEINIT, NULL);
      runloop_ctl(RUNLOOP_CTL_SYSTEM_INFO_FREE, NULL);
      runloop_ctl(RUNLOOP_CTL_FRAME_TIME_FREE, NULL);
    //   camera_driver_ctl(RARCH_CAMERA_CTL_UNSET_ACTIVE, NULL);
    ////   location_driver_ctl(RARCH_LOCATION_CTL_UNSET_ACTIVE, NULL);
    //
    //   /* Performance counters no longer valid. */
    //   performance_counters_clear();
}

#ifdef HAVE_ZLIB
#define DEFAULT_EXT "zip"
#else
#define DEFAULT_EXT ""
#endif
void audio_driver_unset_callback(void)
{
//   audio_callback.callback  = NULL;
//   audio_callback.set_state = NULL;
}


bool runloop_ctl(enum runloop_ctl_state state, void *data) {
    NSLog(@"runloop_ctl : %i", state);
    switch (state)
    {
//       case RUNLOOP_CTL_SHADER_DIR_DEINIT:
//          shader_dir_free(&runloop_shader_dir);
//          break;
//       case RUNLOOP_CTL_SHADER_DIR_INIT:
//          return shader_dir_init(&runloop_shader_dir);
       case RUNLOOP_CTL_SYSTEM_INFO_INIT:
          core_get_system_info(&runloop_system.info);

//          if (!runloop_system.info.library_name)
//             runloop_system.info.library_name = msg_hash_to_str(MSG_UNKNOWN);
          if (!runloop_system.info.library_version)
             runloop_system.info.library_version = "v0";

//          video_driver_set_title_buf();

          strlcpy(runloop_system.valid_extensions,
                runloop_system.info.valid_extensions ?
                runloop_system.info.valid_extensions : DEFAULT_EXT,
                sizeof(runloop_system.valid_extensions));
          break;
       case RUNLOOP_CTL_GET_CORE_OPTION_SIZE:
//          {
//             unsigned *idx = (unsigned*)data;
//             if (!idx)
//                return false;
//             *idx = core_option_manager_size(runloop_core_options);
//          }
          break;
       case RUNLOOP_CTL_HAS_CORE_OPTIONS:
            return false; //runloop_core_options;
       case RUNLOOP_CTL_CORE_OPTIONS_LIST_GET:
//          {
//             core_option_manager_t **coreopts = (core_option_manager_t**)data;
//             if (!coreopts)
//                return false;
//             *coreopts = runloop_core_options;
//          }
          break;
       case RUNLOOP_CTL_SYSTEM_INFO_GET:
          {
             rarch_system_info_t **system = (rarch_system_info_t**)data;
             if (!system)
                return false;
             *system = &runloop_system;
          }
          break;
       case RUNLOOP_CTL_SYSTEM_INFO_FREE:

          /* No longer valid. */
          if (runloop_system.subsystem.data)
             free(runloop_system.subsystem.data);
          runloop_system.subsystem.data = NULL;
          runloop_system.subsystem.size = 0;
          
          if (runloop_system.ports.data)
             free(runloop_system.ports.data);
          runloop_system.ports.data = NULL;
          runloop_system.ports.size = 0;
          
          if (runloop_system.mmaps.descriptors)
             free((void *)runloop_system.mmaps.descriptors);
          runloop_system.mmaps.descriptors     = NULL;
          runloop_system.mmaps.num_descriptors = 0;
          
          runloop_key_event          = NULL;
          runloop_frontend_key_event = NULL;

          audio_driver_unset_callback();
          memset(&runloop_system, 0, sizeof(rarch_system_info_t));
          break;
       case RUNLOOP_CTL_SET_FRAME_TIME_LAST:
          runloop_frame_time_last_enable = true;
          break;
       case RUNLOOP_CTL_UNSET_FRAME_TIME_LAST:
          if (!runloop_ctl(RUNLOOP_CTL_IS_FRAME_TIME_LAST, NULL))
             return false;
          runloop_frame_time_last        = 0;
          runloop_frame_time_last_enable = false;
          break;
       case RUNLOOP_CTL_SET_OVERRIDES_ACTIVE:
          runloop_overrides_active = true;
          break;
       case RUNLOOP_CTL_UNSET_OVERRIDES_ACTIVE:
          runloop_overrides_active = false;
          break;
       case RUNLOOP_CTL_IS_OVERRIDES_ACTIVE:
          return runloop_overrides_active;
       case RUNLOOP_CTL_SET_GAME_OPTIONS_ACTIVE:
          runloop_game_options_active = true;
          break;
       case RUNLOOP_CTL_UNSET_GAME_OPTIONS_ACTIVE:
          runloop_game_options_active = false;
          break;
       case RUNLOOP_CTL_IS_GAME_OPTIONS_ACTIVE:
          return runloop_game_options_active;
       case RUNLOOP_CTL_IS_FRAME_TIME_LAST:
          return runloop_frame_time_last_enable;
       case RUNLOOP_CTL_SET_FRAME_LIMIT:
          runloop_set_frame_limit = true;
          break;
       case RUNLOOP_CTL_UNSET_FRAME_LIMIT:
          runloop_set_frame_limit = false;
          break;
       case RUNLOOP_CTL_SHOULD_SET_FRAME_LIMIT:
          return runloop_set_frame_limit;
       case RUNLOOP_CTL_GET_PERFCNT:
          {
             bool **perfcnt = (bool**)data;
             if (!perfcnt)
                return false;
             *perfcnt = &runloop_perfcnt_enable;
          }
          break;
       case RUNLOOP_CTL_SET_PERFCNT_ENABLE:
          runloop_perfcnt_enable = true;
          break;
       case RUNLOOP_CTL_UNSET_PERFCNT_ENABLE:
          runloop_perfcnt_enable = false;
          break;
       case RUNLOOP_CTL_IS_PERFCNT_ENABLE:
          return runloop_perfcnt_enable;
       case RUNLOOP_CTL_SET_NONBLOCK_FORCED:
          runloop_force_nonblock = true;
          break;
       case RUNLOOP_CTL_UNSET_NONBLOCK_FORCED:
          runloop_force_nonblock = false;
          break;
       case RUNLOOP_CTL_IS_NONBLOCK_FORCED:
          return runloop_force_nonblock;
       case RUNLOOP_CTL_SET_FRAME_TIME:
          {
             const struct retro_frame_time_callback *info =
                (const struct retro_frame_time_callback*)data;
 #ifdef HAVE_NETPLAY
             global_t *global = global_get_ptr();

             /* retro_run() will be called in very strange and
              * mysterious ways, have to disable it. */
             if (global->netplay.enable)
                return false;
 #endif
             runloop_frame_time = *info;
          }
          break;
       case RUNLOOP_CTL_GET_WINDOWED_SCALE:
          {
             unsigned **scale = (unsigned**)data;
             if (!scale)
                return false;
             *scale       = (unsigned*)&runloop_pending_windowed_scale;
          }
          break;
       case RUNLOOP_CTL_SET_WINDOWED_SCALE:
          {
             unsigned *idx = (unsigned*)data;
             if (!idx)
                return false;
             runloop_pending_windowed_scale = *idx;
          }
          break;
       case RUNLOOP_CTL_SET_LIBRETRO_PATH:
          {
             const char *fullpath = (const char*)data;
             if (!fullpath)
                return false;
             config_set_active_core_path(fullpath);
          }
          break;
       case RUNLOOP_CTL_CLEAR_CONTENT_PATH:
          *runloop_fullpath = '\0';
          break;
       case RUNLOOP_CTL_GET_CONTENT_PATH:
          {
             char **fullpath = (char**)data;
             if (!fullpath)
                return false;
             *fullpath       = (char*)runloop_fullpath;
          }
          break;
       case RUNLOOP_CTL_SET_CONTENT_PATH:
          {
             const char *fullpath = (const char*)data;
             if (!fullpath)
                return false;
             strlcpy(runloop_fullpath, fullpath, sizeof(runloop_fullpath));
          }
          break;
       case RUNLOOP_CTL_CLEAR_DEFAULT_SHADER_PRESET:
          *runloop_default_shader_preset = '\0';
          break;
       case RUNLOOP_CTL_GET_DEFAULT_SHADER_PRESET:
          {
             char **preset = (char**)data;
             if (!preset)
                return false;
             *preset       = (char*)runloop_default_shader_preset;
          }
          break;
       case RUNLOOP_CTL_SET_DEFAULT_SHADER_PRESET:
          {
             const char *preset = (const char*)data;
             if (!preset)
                return false;
             strlcpy(runloop_default_shader_preset, preset,
                sizeof(runloop_default_shader_preset));
          }
          break;
       case RUNLOOP_CTL_FRAME_TIME_FREE:
          memset(&runloop_frame_time, 0, sizeof(struct retro_frame_time_callback));
          runloop_frame_time_last           = 0;
          runloop_max_frames                = 0;
          break;
       case RUNLOOP_CTL_STATE_FREE:
          runloop_perfcnt_enable            = false;
          runloop_idle                      = false;
          runloop_paused                    = false;
          runloop_slowmotion                = false;
          runloop_frame_time_last_enable    = false;
          runloop_set_frame_limit           = false;
          runloop_overrides_active          = false;
          runloop_ctl(RUNLOOP_CTL_FRAME_TIME_FREE, NULL);
          break;
       case RUNLOOP_CTL_GLOBAL_FREE:
          {
             global_t *global = NULL;
//             command_event(CMD_EVENT_TEMPORARY_CONTENT_DEINIT, NULL);
//             command_event(CMD_EVENT_SUBSYSTEM_FULLPATHS_DEINIT, NULL);
//             command_event(CMD_EVENT_RECORD_DEINIT, NULL);
//             command_event(CMD_EVENT_LOG_FILE_DEINIT, NULL);

//             rarch_ctl(RARCH_CTL_UNSET_BLOCK_CONFIG_READ, NULL);
             runloop_ctl(RUNLOOP_CTL_CLEAR_CONTENT_PATH,  NULL);
             runloop_overrides_active   = false;

             core_unset_input_descriptors();

//             global = global_get_ptr();
             memset(global, 0, sizeof(struct global));
//             retroarch_override_setting_free_state();
//             config_free_state();
          }
          break;
       case RUNLOOP_CTL_CLEAR_STATE:
//          driver_ctl(RARCH_DRIVER_CTL_DEINIT,  NULL);
          runloop_ctl(RUNLOOP_CTL_STATE_FREE,  NULL);
          runloop_ctl(RUNLOOP_CTL_GLOBAL_FREE, NULL);
          break;
       case RUNLOOP_CTL_SET_MAX_FRAMES:
          {
             unsigned *ptr = (unsigned*)data;
             if (!ptr)
                return false;
             runloop_max_frames = *ptr;
          }
          break;
       case RUNLOOP_CTL_IS_IDLE:
          return runloop_idle;
       case RUNLOOP_CTL_SET_IDLE:
          {
             bool *ptr = (bool*)data;
             if (!ptr)
                return false;
             runloop_idle = *ptr;
          }
          break;
       case RUNLOOP_CTL_IS_SLOWMOTION:
          return runloop_slowmotion;
       case RUNLOOP_CTL_SET_SLOWMOTION:
          {
             bool *ptr = (bool*)data;
             if (!ptr)
                return false;
             runloop_slowmotion = *ptr;
          }
          break;
       case RUNLOOP_CTL_SET_PAUSED:
          {
             bool *ptr = (bool*)data;
             if (!ptr)
                return false;
             runloop_paused = *ptr;
          }
          break;
       case RUNLOOP_CTL_IS_PAUSED:
          return runloop_paused;
       case RUNLOOP_CTL_MSG_QUEUE_PULL:
//          runloop_msg_queue_lock();
//          {
//             const char **ret = (const char**)data;
//             if (!ret)
//                return false;
//             *ret = msg_queue_pull(runloop_msg_queue);
//          }
//          runloop_msg_queue_unlock();
          break;
       case RUNLOOP_CTL_MSG_QUEUE_FREE:
 #ifdef HAVE_THREADS
          slock_free(_runloop_msg_queue_lock);
          _runloop_msg_queue_lock = NULL;
 #endif
          break;
       case RUNLOOP_CTL_MSG_QUEUE_CLEAR:
//          msg_queue_clear(runloop_msg_queue);
          break;
       case RUNLOOP_CTL_MSG_QUEUE_DEINIT:
//          if (!runloop_msg_queue)
//             return true;
//
//          runloop_msg_queue_lock();
//
//          msg_queue_free(runloop_msg_queue);
//
//          runloop_msg_queue_unlock();
//          runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_FREE, NULL);
//
//          runloop_msg_queue = NULL;
          break;
       case RUNLOOP_CTL_MSG_QUEUE_INIT:
          runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_DEINIT, NULL);
//          runloop_msg_queue = msg_queue_new(8);
//          retro_assert(runloop_msg_queue);

 #ifdef HAVE_THREADS
          _runloop_msg_queue_lock = slock_new();
          retro_assert(_runloop_msg_queue_lock);
 #endif
          break;
       case RUNLOOP_CTL_TASK_INIT:
          {
// #ifdef HAVE_THREADS
//             settings_t *settings = config_get_ptr();
//             bool threaded_enable = settings->threaded_data_runloop_enable;
// #else
//             bool threaded_enable = false;
// #endif
//             task_queue_ctl(TASK_QUEUE_CTL_DEINIT, NULL);
//             task_queue_ctl(TASK_QUEUE_CTL_INIT, &threaded_enable);
          }
          break;
       case RUNLOOP_CTL_SET_CORE_SHUTDOWN:
          runloop_core_shutdown_initiated = true;
          break;
       case RUNLOOP_CTL_UNSET_CORE_SHUTDOWN:
          runloop_core_shutdown_initiated = false;
          break;
       case RUNLOOP_CTL_IS_CORE_SHUTDOWN:
          return runloop_core_shutdown_initiated;
       case RUNLOOP_CTL_SET_SHUTDOWN:
          runloop_shutdown_initiated = true;
          break;
       case RUNLOOP_CTL_UNSET_SHUTDOWN:
          runloop_shutdown_initiated = false;
          break;
       case RUNLOOP_CTL_IS_SHUTDOWN:
          return runloop_shutdown_initiated;
       case RUNLOOP_CTL_SET_EXEC:
          runloop_exec = true;
          break;
       case RUNLOOP_CTL_UNSET_EXEC:
          runloop_exec = false;
          break;
       case RUNLOOP_CTL_IS_EXEC:
          return runloop_exec;
       case RUNLOOP_CTL_DATA_DEINIT:
//          task_queue_ctl(TASK_QUEUE_CTL_DEINIT, NULL);
          break;
//       case RUNLOOP_CTL_IS_CORE_OPTION_UPDATED:
//          if (!runloop_core_options)
//             return false;
//          return  core_option_manager_updated(runloop_core_options);
//       case RUNLOOP_CTL_CORE_OPTION_PREV:
//          {
//             unsigned *idx = (unsigned*)data;
//             if (!idx)
//                return false;
//             core_option_manager_prev(runloop_core_options, *idx);
//             if (ui_companion_is_on_foreground())
//                ui_companion_driver_notify_refresh();
//          }
//          break;
//       case RUNLOOP_CTL_CORE_OPTION_NEXT:
//          {
//             unsigned *idx = (unsigned*)data;
//             if (!idx)
//                return false;
//             core_option_manager_next(runloop_core_options, *idx);
//             if (ui_companion_is_on_foreground())
//                ui_companion_driver_notify_refresh();
//          }
//          break;
//       case RUNLOOP_CTL_CORE_OPTIONS_GET:
//          {
//             struct retro_variable *var = (struct retro_variable*)data;
//
//             if (!runloop_core_options || !var)
//                return false;
//
//             RARCH_LOG("Environ GET_VARIABLE %s:\n", var->key);
//             core_option_manager_get(runloop_core_options, var);
//             RARCH_LOG("\t%s\n", var->value ? var->value :
//                   msg_hash_to_str(MENU_ENUM_LABEL_VALUE_NOT_AVAILABLE));
//          }
//          break;
       case RUNLOOP_CTL_CORE_OPTIONS_INIT:
          {
//             char *game_options_path           = NULL;
//             bool ret                          = false;
//             char buf[PATH_MAX_LENGTH]         = {0};
//             global_t *global                  = global_get_ptr();
//             settings_t *settings              = config_get_ptr();
//             const char *options_path          = settings->path.core_options;
//             const struct retro_variable *vars =
//                (const struct retro_variable*)data;

//             if (string_is_empty(options_path)
//                   && !string_is_empty(global->path.config))
//             {
//                fill_pathname_resolve_relative(buf, global->path.config,
//                      file_path_str(FILE_PATH_CORE_OPTIONS_CONFIG), sizeof(buf));
//                options_path = buf;
//             }
//
//
//             if (settings->game_specific_options)
//                ret = rarch_game_specific_options(&game_options_path);
//
//             if(ret)
//             {
//                runloop_ctl(RUNLOOP_CTL_SET_GAME_OPTIONS_ACTIVE, NULL);
//                runloop_core_options =
//                   core_option_manager_new(game_options_path, vars);
//                free(game_options_path);
//             }
//             else
//             {
//                runloop_ctl(RUNLOOP_CTL_UNSET_GAME_OPTIONS_ACTIVE, NULL);
//                runloop_core_options =
//                   core_option_manager_new(options_path, vars);
//             }

          }
          break;
//       case RUNLOOP_CTL_CORE_OPTIONS_FREE:
//          if (runloop_core_options)
//             core_option_manager_free(runloop_core_options);
//          runloop_core_options          = NULL;
//          break;
//       case RUNLOOP_CTL_CORE_OPTIONS_DEINIT:
//          {
//             global_t *global                  = global_get_ptr();
//             if (!runloop_core_options)
//                return false;
//
//             /* check if game options file was just created and flush
//                to that file instead */
//             if(global && !string_is_empty(global->path.core_options_path))
//             {
//                core_option_manager_flush_game_specific(runloop_core_options,
//                      global->path.core_options_path);
//                global->path.core_options_path[0] = '\0';
//             }
//             else
//                core_option_manager_flush(runloop_core_options);
//
//             if (runloop_ctl(RUNLOOP_CTL_IS_GAME_OPTIONS_ACTIVE, NULL))
//                runloop_ctl(RUNLOOP_CTL_UNSET_GAME_OPTIONS_ACTIVE, NULL);
//
//             runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_FREE, NULL);
//          }
//          break;
       case RUNLOOP_CTL_KEY_EVENT_GET:
          {
             retro_keyboard_event_t **key_event =
                (retro_keyboard_event_t**)data;
             if (!key_event)
                return false;
             *key_event = &runloop_key_event;
          }
          break;
       case RUNLOOP_CTL_FRONTEND_KEY_EVENT_GET:
          {
             retro_keyboard_event_t **key_event =
                (retro_keyboard_event_t**)data;
             if (!key_event)
                return false;
             *key_event = &runloop_frontend_key_event;
          }
          break;
       case RUNLOOP_CTL_HTTPSERVER_INIT:
 #if defined(HAVE_HTTPSERVER) && defined(HAVE_ZLIB)
          httpserver_init(8888);
 #endif
          break;
       case RUNLOOP_CTL_HTTPSERVER_DESTROY:
 #if defined(HAVE_HTTPSERVER) && defined(HAVE_ZLIB)
          httpserver_destroy();
 #endif
          break;
       case RUNLOOP_CTL_NONE:
       default:
          break;
    }

    return true;
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
//    const char* path = [bundle.executablePath fileSystemRepresentation];
    NSString *bundleName = bundle.infoDictionary[@"CFBundleName"];
    NSString *executableName = bundle.infoDictionary[@"CFBundleExecutable"];

    NSString *frameworkPath = [NSString stringWithFormat:@"%@.framework/%@", bundleName, executableName];
    NSString *rspPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:frameworkPath];
    NSLog(@"%@", rspPath);
    return [rspPath fileSystemRepresentation];
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

void retro_set_environment(retro_environment_t cb)
{
    environ_cb = cb;
    core.retro_set_environment(cb);
}

static bool environment_callback(unsigned cmd, void *data) {
    __strong PVLibRetroCore *strongCurrent = _current;
    
    switch(cmd) {
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent BIOSPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent BIOSPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
        case RETRO_ENVIRONMENT_GET_CONTENT_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent BIOSPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", appSupportPath);
            break;
        }
            
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
//            *(retro_pixel_format *)data = [strongCurrent pixelFormat];
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

@import Darwin.POSIX;

static void load_dynamic_core(void)
{
    
    ILOG(@"Loading dynamic libretro core from: \"%s\"\n",
         config_get_active_core_path());
    const char* corepath = config_get_active_core_path();
    lib_handle = dylib_load(corepath);
    
//    function_t sym       = dylib_proc(lib_handle, "retro_init");
    
//    if (sym)
//    {
//        /* Try to verify that -lretro was not linked in from other modules
//         * since loading it dynamically and with -l will fail hard. */
//        ELOG(@"Serious problem. RetroArch wants to load libretro cores"
//             "dyamically, but it is already linked.\n");
//        ELOG(@"This could happen if other modules RetroArch depends on "
//             "link against libretro directly.\n");
//        ELOG(@"Proceeding could cause a crash. Aborting ...\n");
//        retroarch_fail(1, "init_libretro_sym()");
//    }
//
//    if (string_is_empty(config_get_active_core_path()))
//    {
//        ELOG(@"RetroArch is built for dynamic libretro cores, but "
//             "libretro_path is not set. Cannot continue.\n");
//        retroarch_fail(1, "init_libretro_sym()");
//    }
//
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
            ILOG(@"type:%x, current_core: %x, lib_handle: %x", type, current_core, lib_handle);

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
    uint32_t *videoBuffer;
    uint32_t *videoBufferA;
    uint32_t *videoBufferB;

    int _videoWidth, _videoHeight;
    int16_t _pad[2][12];
}
@end

@implementation PVLibRetroCore
static void audio_callback(int16_t left, int16_t right)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    [[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];
    
    strongCurrent = nil;
}

static size_t audio_batch_callback(const int16_t *data, size_t frames)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    [[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames << 2];
    
    strongCurrent = nil;
    
    return frames;
}

static void video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    strongCurrent->_videoWidth  = width;
    strongCurrent->_videoHeight = height;

    dispatch_queue_t the_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    dispatch_apply(height, the_queue, ^(size_t y){
        const uint32_t *src = (uint32_t*)data + y * (pitch >> 2); //pitch is in bytes not pixels
        uint32_t *dst = strongCurrent->videoBuffer + y * 720;

        memcpy(dst, src, sizeof(uint32_t)*width);
    });

    strongCurrent = nil;
}

static void input_poll_callback(void)
{
    //DLOG(@"poll callback");
}

static int16_t input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
    //DLOG(@"polled input: port: %d device: %d id: %d", port, device, id);
    
    __strong PVLibRetroCore *strongCurrent = _current;
    int16_t value = 0;

    if (port == 0 & device == RETRO_DEVICE_JOYPAD)
    {
        if (strongCurrent.controller1)
        {
//            value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
        }

        if (value == 0)
        {
//            value = strongCurrent->_pad[0][_id];
        }
    }
    else if(port == 1 & device == RETRO_DEVICE_JOYPAD)
    {
        if (strongCurrent.controller2)
        {
//            value = [strongCurrent controllerValueForButtonID:_id forPlayer:port];
        }

        if (value == 0)
        {
//            value = strongCurrent->_pad[1][_id];
        }
    }
    
    strongCurrent = nil;
    
    return value;
}

- (instancetype)init {
    if((self = [super init])) {
        _current = self;
        
        videoBufferA = (uint32_t *)malloc(720 * 576 * sizeof(uint32_t));
        videoBufferB = (uint32_t *)malloc(720 * 576 * sizeof(uint32_t));
        videoBuffer = videoBufferA;
        
        const char* path = [[NSBundle bundleForClass:[self class]].bundlePath fileSystemRepresentation];
        config_set_active_core_path(path);
//        load_dynamic_core();
        init_libretro_sym(CORE_TYPE_PLAIN, &core);
        retro_set_environment(environment_callback);
        //        libretro_get_system_info(path,
        //        libretro_get_system_info_lib
        core.retro_init();

//		retro_set_audio_sample(audio_callback);
//		retro_set_audio_sample_batch(audio_batch_callback);
//		retro_set_video_refresh(video_callback);
//		retro_set_input_poll(input_poll_callback);
//		retro_set_input_state(input_state_callback);

        core.retro_set_audio_sample(audio_callback);
        core.retro_set_audio_sample_batch(audio_batch_callback);
        core.retro_set_video_refresh(video_callback);
        core.retro_set_input_poll(input_poll_callback);
        core.retro_set_input_state(input_state_callback);
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
    info.data = [NSData dataWithContentsOfFile:path].bytes;
    info.path = [path fileSystemRepresentation];
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
          input_poll();
            break;
        case POLL_TYPE_LATE:
            core_input_polled = false;
            break;
    }
    if (core.retro_run)
        core.retro_run();
    if (core_poll_type == POLL_TYPE_LATE && !core_input_polled)
       input_poll();
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
//    static struct retro_system_av_info av_info;
//    core.retro_get_system_av_info(&av_info);
//    return 1.0 / av_info.timing.fps;
    return 60.0;
}

# pragma mark - Video

//- (void)swapBuffers
//{
//    if (bitmap.data == (uint8_t*)videoBufferA)
//    {
//        videoBuffer = videoBufferA;
//        bitmap.data = (uint8_t*)videoBufferB;
//    }
//    else
//    {
//        videoBuffer = videoBufferB;
//        bitmap.data = (uint8_t*)videoBufferA;
//    }
//}
//
//-(BOOL)isDoubleBuffered {
//    return YES;
//}

- (const void *)videoBuffer {
    return videoBuffer;
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
    return sample_rate ?: 44100;
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
