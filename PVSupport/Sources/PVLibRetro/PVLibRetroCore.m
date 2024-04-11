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
@import PVLoggingObjC;

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
#include "record/record_driver.h"
//#include "queues/message_queue.h"
#include "gfx/video_driver.h"
#include "gfx/video_context_driver.h"
#include "gfx/scaler/scaler.h"
//#include "gfx/video_frame.h"

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

@interface PVLibRetroCore ()
{
    BOOL loaded;
}
@end

video_driver_t video_gl;
video_driver_t video_null;

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

char *config_get_active_core_path_ptr(void) {
    return path_libretro;
}

//const char *config_get_active_core_path(void)
//{
//   return path_libretro;
//}

NSString *privateFrameworkPath(void) {
    NSBundle *bundle = [NSBundle bundleForClass:[_current class]];
    //    const char* path = [bundle.executablePath fileSystemRepresentation];
    NSString *executableName = bundle.infoDictionary[@"CFBundleExecutable"];
    
    NSString *frameworkPath = [NSString stringWithFormat:@"%@/%@", bundle.bundlePath, executableName];
    
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:frameworkPath error:nil];
    for (NSString *fileName in fileNames) {
        ILOG(@"%@", fileName);
    }
//    NSString *privateFrameworkPath = [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:frameworkPath];
//    DLOG(@"%@", privateFrameworkPath);
    return frameworkPath;
}

const char *config_get_active_core_path(void) {

    return [privateFrameworkPath() fileSystemRepresentation];
}

bool config_active_core_path_is_empty(void) {
    return !path_libretro[0];
}

size_t config_get_active_core_path_size(void) {
    DLOG(@"");
    return privateFrameworkPath().length; //sizeof(path_libretro);
}

void config_set_active_core_path(const char *path) {
    DLOG(@"%s", path);
    strlcpy(path_libretro, path, sizeof(path_libretro));
}

void config_clear_active_core_path(void) {
    DLOG(@"");
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
    GET_CURRENT_OR_RETURN();
    if (current->core_poll_type == POLL_TYPE_NORMAL)
        input_poll();
}

static int16_t core_input_state_poll(unsigned port,
                                     unsigned device, unsigned idx, unsigned id)
{
    GET_CURRENT_OR_RETURN(0);
    if (current->core_poll_type == POLL_TYPE_LATE)
    {
        if (!current->core_input_polled)
            input_poll();
        
        current->core_input_polled = true;
    }
    return input_state(port, device, idx, id);
}

void core_set_input_state(retro_ctx_input_state_info_t *info)
{
    GET_CURRENT_OR_RETURN();
    current->core->retro_set_input_state(info->cb);
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
    GET_CURRENT_OR_RETURN(false);

    struct retro_callbacks *cbs = (struct retro_callbacks*)data;
#ifdef HAVE_NETPLAY
    global_t            *global = global_get_ptr();
#endif
    
    if (!cbs)
        return false;
    
    current->core->retro_set_video_refresh(video_driver_frame);
    //   core->retro_set_audio_sample(audio_driver_sample);
    //   core->retro_set_audio_sample_batch(audio_driver_sample_batch);
    current->core->retro_set_input_state(core_input_state_poll);
    current->core->retro_set_input_poll(core_input_state_poll_maybe);
    
    core_set_default_callbacks(cbs);
    
#ifdef HAVE_NETPLAY
    if (!netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_DATA_INITED, NULL))
        return true;
    
    /* Force normal poll type for netplay. */
    core_poll_type = POLL_TYPE_NORMAL;
    
    if (global->netplay.is_spectate)
    {
        core->retro_set_input_state(
                                   (global->netplay.is_client ?
                                    input_state_spectate_client : input_state_spectate)
                                   );
    }
    else
    {
        core->retro_set_video_refresh(video_frame_net);
        core->retro_set_audio_sample(audio_sample_net);
        core->retro_set_audio_sample_batch(audio_sample_batch_net);
        core->retro_set_input_state(input_state_net);
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
    //	  core->retro_set_audio_sample(audio_driver_sample_rewind);
    //	  core->retro_set_audio_sample_batch(audio_driver_sample_batch_rewind);
    //   }
    //   else
    //   {
    //	  core->retro_set_audio_sample(audio_driver_sample);
    //	  core->retro_set_audio_sample_batch(audio_driver_sample_batch);
    //   }
    return true;
}

bool core_set_cheat(retro_ctx_cheat_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_cheat_set(info->index, info->enabled, info->code);
    return true;
}

bool core_reset_cheat(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_cheat_reset();
    return true;
}

bool core_api_version(retro_ctx_api_info_t *api)
{
    GET_CURRENT_OR_RETURN(false);
    if (!api)
        return false;
    api->version = current->core->retro_api_version();
    return true;
}

bool core_set_poll_type(unsigned *type)
{
    GET_CURRENT_OR_RETURN(false);
    current->core_poll_type = *type;
    return true;
}

void core_uninit_symbols(void)
{
    GET_CURRENT_OR_RETURN();
    uninit_libretro_sym(current->core);
}

bool core_init_symbols(enum rarch_core_type *type)
{
    GET_CURRENT_OR_RETURN(false);
    if (!type)
        return false;
    init_libretro_sym(*type, current->core);
    return true;
}

bool core_set_controller_port_device(retro_ctx_controller_info_t *pad) {
    GET_CURRENT_OR_RETURN(false);
    if (!pad)
        return false;
    current->core->retro_set_controller_port_device(pad->port, pad->device);
    return true;
}

bool core_get_memory(retro_ctx_memory_info_t *info) {
    GET_CURRENT_OR_RETURN(false);

    if (!info)
        return false;
    info->size  = current->core->retro_get_memory_size(info->id);
    info->data  = current->core->retro_get_memory_data(info->id);
    return true;
}



//static void video_configure(const struct retro_game_geometry * geom) {
//    __strong PVLibRetroCore *strongCurrent = _current;
//
//    strongCurrent->_videoWidth  = geom->max_width;
//    strongCurrent->_videoHeight = geom->max_height;
//}


bool core_load_game(retro_ctx_load_content_info_t *load_info)
{
    GET_CURRENT_OR_RETURN(false);

    if (!load_info)
        return false;
    
    BOOL loaded = false;
    if (load_info->special != nil) {
        loaded = current->core->retro_load_game_special(load_info->special->id, load_info->info, load_info->content->size);
    } else {
//        if(load_info->content != nil && load_info->content->elems != nil) {
//            core->retro_load_game(*load_info->content->elems[0].data);
//        } else {
        loaded = current->core->retro_load_game(load_info->info);
//        }
    }
    
    if (!loaded) {
        ELOG(@"Core failed to load game.");
        return false;
    }
    
    struct retro_system_timing timing = {
        60.0f, 10000.0f
    };
    struct retro_game_geometry geom = {
        100, 100, 100, 100, 1.0f
    };
    struct retro_system_av_info av = {
        geom, timing
    };
    //    struct retro_system_info system = {
    //      0, 0, 0, false, false
    //    };
    //
    //    struct retro_game_info info = {
    //      filename,
    //      0,
    //      0,
    //      NULL
    //    };
    
    
    current->core->retro_get_system_av_info(&av);
    ILOG(@"Video: %ix%i\n", av.geometry.base_width, av.geometry.base_height);
    current->av_info = av;
//    video_configure(&av.geometry);
    return true;
    //    audio_init(av.timing.sample_rate);
}

bool core_get_system_info(struct retro_system_info *system) {
    GET_CURRENT_OR_RETURN(false);
    if (!system)
        return false;
    current->core->retro_get_system_info(system);
    return true;
}

bool core_unserialize(retro_ctx_serialize_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    if (!current->core->retro_unserialize(info->data_const, info->size))
        return false;
    return true;
}

bool core_serialize(retro_ctx_serialize_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    if (!current->core->retro_serialize(info->data, info->size))
        return false;
    return true;
}

bool core_serialize_size(retro_ctx_size_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    info->size = current->core->retro_serialize_size();
    return true;
}

bool core_frame(retro_ctx_frame_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info || !retro_ctx.frame_cb)
        return false;
    
    retro_ctx.frame_cb(
                       info->data, info->width, info->height, info->pitch);
    return true;
}

bool core_poll(void) {
    GET_CURRENT_OR_RETURN(false);
    if (!retro_ctx.poll_cb)
        return false;
    retro_ctx.poll_cb();
    return true;
}

bool core_set_environment(retro_ctx_environ_info_t *info) {
    GET_CURRENT_OR_RETURN(false);
    if (!info)
        return false;
    current->core->retro_set_environment(info->env);
    return true;
}

bool core_get_system_av_info(struct retro_system_av_info *av_info) {
    GET_CURRENT_OR_RETURN(false);
    if (!av_info)
        return false;
    current->core->retro_get_system_av_info(av_info);
    return true;
}

bool core_reset(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_reset();
    return true;
}

bool core_init(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_init();
    return true;
}

bool core_unload(void) {
    GET_CURRENT_OR_RETURN(false);
    current->core->retro_deinit();
    return true;
}

bool core_has_set_input_descriptor(void) {
    GET_CURRENT_OR_RETURN(false);
    return current->core_has_set_input_descriptors;
}

void core_set_input_descriptors(void) {
    GET_CURRENT_OR_RETURN();
    current->core_has_set_input_descriptors = true;
}

void core_unset_input_descriptors(void) {
    GET_CURRENT_OR_RETURN();
    current->core_has_set_input_descriptors = false;
}

static settings_t *configuration_settings = NULL;

settings_t *config_get_ptr(void) {
    return configuration_settings;
}

bool core_load(void) {
    GET_CURRENT_OR_RETURN(false);

    settings_t *settings = config_get_ptr();
    current->core_poll_type = settings->input.poll_type_behavior;
    
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


bool core_verify_api_version(void) {
    GET_CURRENT_OR_RETURN(false);

    //   unsigned api_version = core->retro_api_version();
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
 * Frees libretro core->
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
    VLOG(@"runloop_ctl : %i", state);
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

extern video_pixel_scaler_t *video_driver_scaler_ptr;
extern bool video_pixel_frame_scale(const void *data,
      unsigned width, unsigned height,
                                    size_t pitch);
//extern video_driver_state_t video_driver_state;
void video_driver_frame(const void *data, unsigned width,
                        unsigned height, size_t pitch)
{
    NAssert(@"Shouldn't be here, or need to implement");
//       static char video_driver_msg[256];
//       unsigned output_width  = 0;
//       unsigned output_height = 0;
//       unsigned  output_pitch = 0;
//       const char *msg        = NULL;
//       settings_t *settings   = config_get_ptr();
//
//       runloop_ctl(RUNLOOP_CTL_MSG_QUEUE_PULL,   &msg);
//
//       if (!video_driver_is_active())
//          return;
//
//       if (video_driver_scaler_ptr &&
//             video_pixel_frame_scale(data, width, height, pitch))
//       {
//          data                = video_driver_scaler_ptr->scaler_out;
//          pitch               = video_driver_scaler_ptr->scaler->out_stride;
//       }
//
//       video_driver_cached_frame_set(data, width, height, pitch);
//
//       /* Slightly messy code,
//        * but we really need to do processing before blocking on VSync
//        * for best possible scheduling.
//        */
//       if (
//             (
//                 !video_driver_state.filter.filter
//              || !settings->video.post_filter_record
//              || !data
//              || video_driver_has_gpu_record()
//             )
//          )
//          recording_dump_frame(data, width, height, pitch);
//
//       if (video_driver_frame_filter(data, width, height, pitch,
//                &output_width, &output_height, &output_pitch))
//       {
//          data   = video_driver_state.filter.buffer;
//          width  = output_width;
//          height = output_height;
//          pitch  = output_pitch;
//       }
//
//       video_driver_msg[0] = '\0';
//       if (msg)
//          strlcpy(video_driver_msg, msg, sizeof(video_driver_msg));
//
//       if (!current_video || !current_video->frame(
//                video_driver_data, data, width, height,
//                video_driver_frame_count,
//                pitch, video_driver_msg))
//       {
//          video_driver_unset_active();
//       }
//
//       video_driver_frame_count++;
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
    GET_CURRENT_OR_RETURN();
    environ_cb = cb;
    current->core->retro_set_environment(cb);
}

static void core_log(enum retro_log_level level, const char * fmt, ...) {
    char buffer[4096] = {0};
    static const char * levelstr[] = {
        "dbg",
        "inf",
        "wrn",
        "err"
    };
    va_list va;
    
    va_start(va, fmt);
    vsnprintf(buffer, sizeof(buffer), fmt, va);
    va_end(va);
    
    if (level == 0)
        return;
    
    switch (level) {
        case 0:
            DLOG(@"%s", buffer);
            break;
        case 1:
            ILOG(@"%s", buffer);
            break;
        case 2:
            WLOG(@"%s", buffer);
            break;
        case 3:
            ELOG(@"%s", buffer);
            break;
        default:
            break;
    }
    
    fprintf(stderr, "[%s] %s", levelstr[level], buffer);
    fflush(stderr);
    
    if (level == RETRO_LOG_ERROR) {
        exit(EXIT_FAILURE);
    }
}
/*
 TODO:
 make an obj-c version this calls
 and make sure to call the subclass and super(this) classses
 custom core configs are set with keys, search `desmume_advanced_timing`, `desmume_internal_resolution` for example.
 will need to make a list for each core and type those into core options
 */
static bool environment_callback(unsigned cmd, void *data) {
    __strong PVLibRetroCore *strongCurrent = _current;

    switch(cmd) {
        case RETRO_ENVIRONMENT_SET_ROTATION:
                                                        /* const unsigned * --
                                                        * Sets screen rotation of graphics.
                                                        * Valid values are 0, 1, 2, 3, which rotates screen by 0, 90, 180,
                                                        * 270 degrees counter-clockwise respectively.
                                                        */
            ILOG(@"%i", *(const unsigned*)data);
            return false;
        case RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE:
                                                      /* const struct retro_disk_control_callback * --
                                                       * Sets an interface which frontend can use to eject and insert
                                                       * disk images.
                                                       * This is used for games which consist of multiple images and
                                                       * must be manually swapped out by the user (e.g. PSX).
                                                       */
//            const struct retro_disk_control_callback* cb = (const struct retro_disk_control_callback*)data
//            ILOG(@"%i", cb->data);
            return false;
        case RETRO_ENVIRONMENT_SET_HW_RENDER:
                                                      /* struct retro_hw_render_callback * --
                                                       * Sets an interface to let a libretro core render with
                                                       * hardware acceleration.
                                                       * Should be called in retro_load_game().
                                                       * If successful, libretro cores will be able to render to a
                                                       * frontend-provided framebuffer.
                                                       * The size of this framebuffer will be at least as large as
                                                       * max_width/max_height provided in get_av_info().
                                                       * If HW rendering is used, pass only RETRO_HW_FRAME_BUFFER_VALID or
                                                       * NULL to retro_video_refresh_t.
                                                       */
//            struct retro_hw_render_callback* cb = (const struct retro_hw_render_callback*)data;
//            ILOG(@"%i", cb);
            return true;
        case RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE: {
                                           /* struct retro_rumble_interface * --
                                            * Gets an interface which is used by a libretro core to set
                                            * state of rumble motors in controllers.
                                            * A strong and weak motor is supported, and they can be
                                            * controlled indepedently.
                                            * Should be called from either retro_init() or retro_load_game().
                                            * Should not be called from retro_set_environment().
                                            * Returns false if rumble functionality is unavailable.
                                            */
            // TODO: Rumble
            return false;
        }
        case RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES: {
                                           /* uint64_t * --
                                            * Gets a bitmask telling which device type are expected to be
                                            * handled properly in a call to retro_input_state_t.
                                            * Devices which are not handled or recognized always return
                                            * 0 in retro_input_state_t.
                                            * Example bitmask: caps = (1 << RETRO_DEVICE_JOYPAD) | (1 << RETRO_DEVICE_ANALOG).
                                            * Should only be called in retro_run().
                                            */
            // RETRO_DEVICE_MOUSE RETRO_DEVICE_LIGHTGUN RETRO_DEVICE_POINTER RETRO_DEVICE_KEYBOARD
            uint64_t features = (1 << RETRO_DEVICE_JOYPAD) | (1 << RETRO_DEVICE_ANALOG);
            if ([strongCurrent conformsToProtocol:@protocol(KeyboardResponder)]) {
                features  |= 1 << RETRO_DEVICE_KEYBOARD;
            }
            if ([strongCurrent conformsToProtocol:@protocol(MouseResponder)]) {
                features  |= 1 << RETRO_DEVICE_MOUSE;
            }
            if ([strongCurrent conformsToProtocol:@protocol(TouchPadResponder)]) {
                features  |= 1 << RETRO_DEVICE_POINTER;
            }
            
            *(uint64_t *)data = features;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SENSOR_INTERFACE:
            return false;
                                           /* struct retro_sensor_interface * --
                                            * Gets access to the sensor interface.
                                            * The purpose of this interface is to allow
                                            * setting state related to sensors such as polling rate,
                                            * enabling/disable it entirely, etc.
                                            * Reading sensor state is done via the normal
                                            * input_state_callback API.
                                            */
        case RETRO_ENVIRONMENT_GET_CAMERA_INTERFACE:
            return false;
                                           /* struct retro_camera_callback * --
                                            * Gets an interface to a video camera driver.
                                            * A libretro core can use this interface to get access to a
                                            * video camera.
                                            * New video frames are delivered in a callback in same
                                            * thread as retro_run().
                                            *
                                            * GET_CAMERA_INTERFACE should be called in retro_load_game().
                                            *
                                            * Depending on the camera implementation used, camera frames
                                            * will be delivered as a raw framebuffer,
                                            * or as an OpenGL texture directly.
                                            *
                                            * The core has to tell the frontend here which types of
                                            * buffers can be handled properly.
                                            * An OpenGL texture can only be handled when using a
                                            * libretro GL core (SET_HW_RENDER).
                                            * It is recommended to use a libretro GL core when
                                            * using camera interface.
                                            *
                                            * The camera is not started automatically. The retrieved start/stop
                                            * functions must be used to explicitly
                                            * start and stop the camera driver.
                                            */
        case RETRO_ENVIRONMENT_GET_LOCATION_INTERFACE :
                                           /* struct retro_location_callback * --
                                            * Gets access to the location interface.
                                            * The purpose of this interface is to be able to retrieve
                                            * location-based information from the host device,
                                            * such as current latitude / longitude.
                                            */
            return false;
        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            *(bool *)data = true;
            return true;
        case RETRO_ENVIRONMENT_GET_LOG_INTERFACE: {
            struct retro_log_callback* cb = (struct retro_log_callback*)data;
            cb->log = core_log;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY : {
            NSString *BIOSPath = [strongCurrent BIOSPath];
            CFStringRef cfString = (CFStringRef)CFBridgingRetain(BIOSPath);

            *(const char **)data = CFStringGetCStringPtr(cfString, kCFStringEncodingUTF8); //[BIOSPath UTF8String];
            
            DLOG(@"Environ SYSTEM_DIRECTORY: \"%@\".\n", BIOSPath);
            return true;
        }
//        case RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER : {
//            const struct retro_framebuffer *fb =
//                    (const struct retro_framebuffer *)data;
//            fb->data = (void *)[strongCurrent videoBuffer];
//            return true;
//        }
//            // TODO: When/if vulkan support add this
////        case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE : {
////            struct retro_hw_render_interface* rend = (struct retro_hw_render_interface*)data;
////
////            return true;
////        }
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY : {
            NSString *appSupportPath = [strongCurrent saveStatesPath];
            
            *(const char **)data = [appSupportPath UTF8String];
            DLOG(@"Environ SAVE_DIRECTORY: \"%@\".\n", appSupportPath);
            return true;
        }
        case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY : {
            NSString *batterySavesPath = [strongCurrent batterySavesPath];
            
            *(const char **)data = [batterySavesPath UTF8String];
            DLOG(@"Environ CONTENT_DIRECTORY: \"%@\".\n", batterySavesPath);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            enum retro_pixel_format pix_fmt =
               *(const enum retro_pixel_format*)data;

            switch (pix_fmt)
            {
               case RETRO_PIXEL_FORMAT_0RGB1555:
                    DLOG(@"Environ SET_PIXEL_FORMAT: 0RGB1555.\n");
                  break;

               case RETRO_PIXEL_FORMAT_RGB565:
                    DLOG(@"Environ SET_PIXEL_FORMAT: RGB565.\n");
                  break;
               case RETRO_PIXEL_FORMAT_XRGB8888:
                    DLOG(@"Environ SET_PIXEL_FORMAT: XRGB8888.\n");
                  break;
               default:
                    ELOG(@"Environ SET_PIXEL_FORMAT: UNKNOWN.\n");
                  return false;
            }

            strongCurrent->pix_fmt = pix_fmt;
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
                ILOG(@"Environ SET_VARIABLES: {\"%s\",\"%s\"}.\n", currentEnv->key, currentEnv->value);
                i++;
            } while(currentEnv->key != NULL && currentEnv->value != NULL);

            break;

        }
        case RETRO_ENVIRONMENT_GET_GAME_INFO_EXT:
        {
            const struct retro_game_info_ext **game_info_ext =
                    (const struct retro_game_info_ext **)data;
            
            if (!game_info_ext) {
                ELOG(@"`game_info_ext` is nil.")
                return false;
            }
            
            ////            struct retro_game_info_ext *game_info = (struct retro_game_info_ext*)data;
            //            // TODO: Is there a way to pass `retro_game_info_ext` before callbacks?
            struct retro_game_info_ext *game_info = malloc(sizeof(struct retro_game_info_ext));
            game_info->persistent_data = true;
            
            //            void *buffer = malloc(romData.length);
            //            [romData getBytes:buffer length:romData.length];
            //
            //            game_info->data = buffer;
            NSData *romData = [NSData dataWithContentsOfFile:strongCurrent.romPath];
            CFDataRef cfData = (CFDataRef)CFBridgingRetain(romData);
            game_info->data = CFDataGetBytePtr(cfData);
            game_info->size = romData.length;
            
            const char *c_full_path = [strongCurrent.romPath cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->full_path = c_full_path;
            
            const char *c_dir = [[strongCurrent.romPath stringByDeletingLastPathComponent] cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->dir = c_dir;
            
            const char *c_rom_name = [[strongCurrent.romPath.lastPathComponent stringByDeletingPathExtension] cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->name = c_rom_name;
            
            const char *c_extension = [[strongCurrent.romPath.lastPathComponent pathExtension] cStringUsingEncoding:NSUTF8StringEncoding];
            game_info->ext = c_extension;

            *game_info_ext = game_info;
//            *game_info_ext = &game_info;
            return true;
            break;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE:
        {
            struct retro_variable *var = (struct retro_variable*)data;

           void *value = [strongCurrent getVariable:var->key];
            if(value) {
                var->value = value;
                return true;
            } else {
                return false;
            }
            break;
        }
        case RETRO_ENVIRONMENT_SET_MINIMUM_AUDIO_LATENCY:
            return true;
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            return false;
        case RETRO_ENVIRONMENT_GET_MESSAGE_INTERFACE_VERSION:
        {
            *((unsigned*)data) = 1;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_MESSAGE:
        case RETRO_ENVIRONMENT_SET_MESSAGE_EXT:
        {
            const char* msg = ((struct retro_message*)data)->msg;
            ILOG(@"%s", msg);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
        {
                                                       /* const struct retro_system_av_info * --
                                                        * Sets a new av_info structure. This can only be called from
                                                        * within retro_run().
                                                        * This should *only* be used if the core is completely altering the
                                                        * internal resolutions, aspect ratios, timings, sampling rate, etc.
                                                        * Calling this can require a full reinitialization of video/audio
                                                        * drivers in the frontend,
                                                        *
                                                        * so it is important to call it very sparingly, and usually only with
                                                        * the users explicit consent.
                                                        * An eventual driver reinitialize will happen so that video and
                                                        * audio callbacks
                                                        * happening after this call within the same retro_run() call will
                                                        * target the newly initialized driver.
                                                        *
                                                        * This callback makes it possible to support configurable resolutions
                                                        * in games, which can be useful to
                                                        * avoid setting the "worst case" in max_width/max_height.
                                                        *
                                                        * ***HIGHLY RECOMMENDED*** Do not call this callback every time
                                                        * resolution changes in an emulator core if it's
                                                        * expected to be a temporary change, for the reasons of possible
                                                        * driver reinitialization.
                                                        * This call is not a free pass for not trying to provide
                                                        * correct values in retro_get_system_av_info(). If you need to change
                                                        * things like aspect ratio or nominal width/height,
                                                        * use RETRO_ENVIRONMENT_SET_GEOMETRY, which is a softer variant
                                                        * of SET_SYSTEM_AV_INFO.
                                                        *
                                                        * If this returns false, the frontend does not acknowledge a
                                                        * changed av_info struct.
                                                        */
            struct retro_system_av_info info = *(const struct retro_system_av_info*)data;
            strongCurrent->av_info = info;
            ILOG(@"%s", info.geometry.max_width, info.geometry.max_height, info.geometry.base_width, info.geometry.base_height, info.geometry.aspect_ratio, info.timing.sample_rate, info.timing.fps);
            return true;
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
    const char* corepath = config_get_active_core_path();

    ILOG(@"Loading dynamic libretro core from: \"%s\"\n",
         corepath);
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
#define PITCH_SHIFT 2

@implementation PVLibRetroCore
static void RETRO_CALLCONV audio_callback(int16_t left, int16_t right)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    [[strongCurrent ringBufferAtIndex:0] write:&left maxLength:2];
    [[strongCurrent ringBufferAtIndex:0] write:&right maxLength:2];
    
    strongCurrent = nil;
}

static size_t RETRO_CALLCONV audio_batch_callback(const int16_t *data, size_t frames)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    
    [[strongCurrent ringBufferAtIndex:0] write:data maxLength:frames << 2];
    
    strongCurrent = nil;
    
    return frames;
}

static void RETRO_CALLCONV video_callback(const void *data, unsigned width, unsigned height, size_t pitch)
{
//    if (!video_driver_is_active())
//       return;
    
    __strong PVLibRetroCore *strongCurrent = _current;
    
    static dispatch_queue_t serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0);
        serialQueue = dispatch_queue_create("com.provenance.video", queueAttributes);
        
        DLOG(@"vid: width: %i height: %i, pitch: %zu. _videoWidth: %f, _videoHeight: %f\n", width, height, pitch, strongCurrent.videoWidth, strongCurrent.videoHeight);
    });
    // 512
    uint16_t pitch_shift = strongCurrent->pitch_shift; //PITCH_SHIFT; //pitch % 256; // PITCH_SHIFT
    dispatch_apply(height, serialQueue, ^(size_t y){
        size_t shifted_pitch = pitch >> pitch_shift;              //pitch is in bytes not pixels
        size_t offset = y * shifted_pitch;
        const uint32_t *src = (uint16_t*)data + offset;
        uint32_t *dst = strongCurrent->videoBuffer + y * width;
        
        memcpy(dst, src, sizeof(uint32_t)*width);
    });
    
    strongCurrent = nil;
}

static void RETRO_CALLCONV input_poll_callback(void)
{
    __strong PVLibRetroCore *strongCurrent = _current;
    [strongCurrent pollControllers];
    //DLOG(@"poll callback");
}

static int16_t RETRO_CALLCONV input_state_callback(unsigned port, unsigned device, unsigned index, unsigned _id)
{
    //DLOG(@"polled input: port: %d device: %d id: %d", port, device, id);
    
    __strong PVLibRetroCore *strongCurrent = _current;
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

- (instancetype)init {
    if((self = [super init])) {
        pitch_shift = PITCH_SHIFT;
        _current = self;
        const char* path = [[NSBundle bundleForClass:[self class]].bundlePath fileSystemRepresentation];
        config_set_active_core_path(path);
        //        load_dynamic_core();
        core = malloc(sizeof(retro_core_t));
        init_libretro_sym(CORE_TYPE_PLAIN, core);
        retro_set_environment(environment_callback);
        
        memset(_pad, 0, sizeof(int16_t) * 24);

//        struct retro_system_info info;
//        core_get_info(&info);
//        std::cout << "Loaded core " << info.library_name << " version " << info.library_version << std::endl;
//        std::cout << "Core needs fullpath " << info.need_fullpath << std::endl;
//        std::cout << "Running for " << maxframes << " frames with frame timeout of ";
//        std::cout << frametimeout << " seconds" << std::endl;
        
        //        libretro_get_system_info(path,
        //        libretro_get_system_info_lib
        
        videoBufferA = (uint32_t *)malloc(2560 * 2560 * sizeof(uint32_t));
        videoBufferB = (uint32_t *)malloc(2560 * 2560 * sizeof(uint32_t));
        videoBuffer = videoBufferA;
    }
    
    return self;
}

- (void)dealloc {
    core_unload();
}

-(void)coreInit {
    GET_CURRENT_OR_RETURN();

    current->core->retro_init();

    current->core->retro_set_audio_sample(audio_callback);
    current->core->retro_set_audio_sample_batch(audio_batch_callback);
    current->core->retro_set_video_refresh(video_callback);
    current->core->retro_set_input_poll(input_poll_callback);
    current->core->retro_set_input_state(input_state_callback);
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    self.romPath = path;
    NSURL *batterySavesDirectory = [NSURL fileURLWithPath:[self batterySavesPath]];
    NSError *localError;
    BOOL status = [[NSFileManager defaultManager] createDirectoryAtURL:batterySavesDirectory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:&localError];
    if(!status) {
        *error = localError;
        return NO;
    }

    [self coreInit];
    
    struct retro_game_info info;
    info.data = [NSData dataWithContentsOfFile:path].bytes;
    info.path = [path fileSystemRepresentation];
    // TODO:: retro_load_game
//    BOOL loaded = core->retro_load_game(&info); // retro_load_game(&info);
    
    struct retro_ctx_load_content_info info2;
    info2.info = &info;
    info2.content = nil;
    info2.special = nil;

    BOOL loaded = core_load_game(&info2);
   
    if(loaded) {
        core->retro_reset();
    }
    
    self->loaded = loaded;

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
    if (core->retro_run)
        core->retro_run();
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
    core->retro_reset();
}

- (void)stopEmulation {
    [super stopEmulation];

    core->retro_unload_game();
    
//    if (self->loaded) {
//        core->retro_reset();
//    }
//    core->retro_deinit();
}

- (NSTimeInterval)frameInterval {
    NSTimeInterval fps = av_info.timing.fps ?: 60;
    VLOG(@"%f", fps);
    return fps;
}

# pragma mark - Video
- (void)swapBuffers {
    if (videoBuffer == videoBufferA) {
        videoBuffer = videoBufferB;
    } else {
        videoBuffer = videoBufferA;
    }
}

-(BOOL)isDoubleBuffered {
    return YES;
}

- (CGFloat)videoWidth {
    return av_info.geometry.base_width;
}

- (CGFloat)videoHeight {
    return av_info.geometry.base_height;
}

- (const void *)videoBuffer {
    return videoBuffer;
}

- (CGRect)screenRect {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.base_height;
    unsigned width = av_info.geometry.base_width;

//    unsigned height = _videoHeight;
//    unsigned width = _videoWidth;
    
    return CGRectMake(0, 0, width, height);
}

- (CGSize)aspectSize {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
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
    core->retro_get_system_av_info(&av_info);
    unsigned height = av_info.geometry.max_height;
    unsigned width = av_info.geometry.max_width;
    
    return CGSizeMake(width, height);
}

- (GLenum)pixelFormat {
    switch (pix_fmt)
    {
       case RETRO_PIXEL_FORMAT_0RGB1555:
            return GL_RGB5_A1; // GL_UNSIGNED_SHORT_1_5_5_5_REV_EXT
#if !TARGET_OS_MAC
       case RETRO_PIXEL_FORMAT_RGB565:
            return GL_RGB565;
#else
        case RETRO_PIXEL_FORMAT_RGB565:
             return GL_UNSIGNED_SHORT_5_6_5;
#endif
       case RETRO_PIXEL_FORMAT_XRGB8888:
            return GL_RGBA8; // GL_RGBA8
       default:
            return GL_RGBA;
    }
}

- (GLenum)internalPixelFormat {
    switch (pix_fmt)
    {
       case RETRO_PIXEL_FORMAT_0RGB1555:
            return GL_RGB5_A1;
#if !TARGET_OS_MAC
       case RETRO_PIXEL_FORMAT_RGB565:
            return GL_RGB565;
#else
        case RETRO_PIXEL_FORMAT_RGB565:
             return GL_UNSIGNED_SHORT_5_6_5;
#endif
       case RETRO_PIXEL_FORMAT_XRGB8888:
            return GL_RGBA8;
       default:
            return GL_RGBA;
    }

    return GL_RGBA;
}

- (GLenum)pixelType {
    // GL_UNSIGNED_SHORT_5_6_5
    // GL_UNSIGNED_BYTE
    return GL_UNSIGNED_SHORT;
}

# pragma mark - Audio

- (double)audioSampleRate {
    static struct retro_system_av_info av_info;
    core->retro_get_system_av_info(&av_info);
    double sample_rate = av_info.timing.sample_rate;
    return sample_rate ?: 44100;
}

- (NSUInteger)channelCount {
    return 2;
}

@end

# pragma mark - Options
@implementation PVLibRetroCore (Options)
- (void *)getVariable:(const char *)variable {
    WLOG(@"This should be done in sub class: %s", variable);
    return NULL;
}
@end

# pragma mark - Controls
@implementation PVLibRetroCore (Controls)
- (void)pollControllers {
    // TODO: This should warn or something if not in subclass
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

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player
{
    // TODO: This should warn or something if not in subclass

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

@end

# pragma mark - Save States
@implementation PVLibRetroCore (Saves)

#pragma mark Properties
-(BOOL)supportsSaveStates {
    return core->retro_get_memory_size(0) != 0 && core->retro_get_memory_data(0) != NULL;
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
    core->retro_cheat_set(index, enabled, cCode);
    // void retro_cheat_reset(void) { }
    //    void retro_cheat_set(unsigned index, bool enabled, const char *code) { (void)index; (void)enabled; (void)code; }
}

@end

unsigned retro_api_version(void)
{
    return RETRO_API_VERSION;
}

#pragma clang diagnostic pop
