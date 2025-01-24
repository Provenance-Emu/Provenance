/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2010-2014 - Hans-Kristian Arntzen
 *  Copyright (C) 2011-2016 - Daniel De Matteis
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include <string.h>
#include <ctype.h>

#include <boolean.h>
#include <file/file_path.h>
#include <compat/strl.h>
#include <compat/posix_string.h>
#include <dynamic/dylib.h>
#include <string/stdstring.h>
#include <retro_assert.h>

#include <features/features_cpu.h>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "dynamic.h"
#include "command.h"

#include "audio/audio_driver.h"
#include "camera/camera_driver.h"
//#include "location/location_driver.h"
//#include "record/record_driver.h"
#include "core.h"
#include "performance_counters.h"
#include "system.h"
#include "gfx/video_context_driver.h"

#include "cores/internal_cores.h"
//#include "frontend/frontend_driver.h"
#include "content.h"
#ifdef HAVE_CHEEVOS
#include "cheevos.h"
#endif
#include "retroarch.h"
#include "configuration.h"
#include "general.h"
#include "msg_hash.h"
#include "verbosity.h"

#ifdef HAVE_DYNAMIC
#define SYMBOL(x) do { \
   function_t func = dylib_proc(lib_handle, #x); \
   memcpy(&current_core->x, &func, sizeof(func)); \
   if (current_core->x == NULL) { ELOG("Failed to load symbol: \"%s\"\n", #x); retroarch_fail(1, "init_libretro_sym()"); } \
} while (0)

static dylib_t lib_handle;
#else
#define SYMBOL(x) current_core->x = x
#endif

#define SYMBOL_DUMMY(x) current_core->x = libretro_dummy_##x

#ifdef HAVE_FFMPEG
#define SYMBOL_FFMPEG(x) current_core->x = libretro_ffmpeg_##x
#endif

#ifdef HAVE_IMAGEVIEWER
#define SYMBOL_IMAGEVIEWER(x) current_core->x = libretro_imageviewer_##x
#endif

#if defined(HAVE_NETWORKGAMEPAD) && defined(HAVE_NETPLAY)
#define SYMBOL_NETRETROPAD(x) current_core->x = libretro_netretropad_##x
#endif

#if defined(HAVE_VIDEO_PROCESSOR)
#define SYMBOL_VIDEOPROCESSOR(x) current_core->x = libretro_videoprocessor_##x
#endif

static bool ignore_environment_cb;

const struct retro_subsystem_info *libretro_find_subsystem_info(
      const struct retro_subsystem_info *info, unsigned num_info,
      const char *ident)
{
   unsigned i;
   for (i = 0; i < num_info; i++)
   {
      if (string_is_equal(info[i].ident, ident))
         return &info[i];
      else if (string_is_equal(info[i].desc, ident))
         return &info[i];
   }

   return NULL;
}

/**
 * libretro_find_controller_description:
 * @info                         : Pointer to controller info handle.
 * @id                           : Identifier of controller to search
 *                                 for.
 *
 * Search for a controller of type @id in @info.
 *
 * Returns: controller description of found controller on success,
 * otherwise NULL.
 **/
const struct retro_controller_description *
libretro_find_controller_description(
      const struct retro_controller_info *info, unsigned id)
{
   unsigned i;

   for (i = 0; i < info->num_types; i++)
   {
      if (info->types[i].id != id)
         continue;

      return &info->types[i];
   }

   return NULL;
}

/**
 * libretro_free_system_info:
 * @info                         : Pointer to system info information.
 *
 * Frees system information.
 **/
void libretro_free_system_info(struct retro_system_info *info)
{
   if (!info)
      return;

   free((void*)info->library_name);
   free((void*)info->library_version);
   free((void*)info->valid_extensions);
   memset(info, 0, sizeof(*info));
}

static bool *load_no_content_hook;

static bool environ_cb_get_system_info(unsigned cmd, void *data)
{
   switch (cmd)
   {
      case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
         *load_no_content_hook = *(const bool*)data;
         break;

      default:
         return false;
   }

   return true;
}

#ifndef HAVE_DYNAMIC
bool libretro_get_system_info_static(struct retro_system_info *info,
      bool *load_no_content)
{
   struct retro_system_info dummy_info = {0};

   if (load_no_content)
   {
      load_no_content_hook = load_no_content;

      /* load_no_content gets set in this callback. */
      retro_set_environment(environ_cb_get_system_info);

      /* It's possible that we just set get_system_info callback 
       * to the currently running core.
       *
       * Make sure we reset it to the actual environment callback.
       * Ignore any environment callbacks here in case we're running 
       * on the non-current core. */
      ignore_environment_cb = true;
      retro_set_environment(rarch_environment_cb);
      ignore_environment_cb = false;
   }

   retro_get_system_info(&dummy_info);
   memcpy(info, &dummy_info, sizeof(*info));

   info->library_name    = strdup(dummy_info.library_name);
   info->library_version = strdup(dummy_info.library_version);
   if (dummy_info.valid_extensions)
      info->valid_extensions = strdup(dummy_info.valid_extensions);
   return true;
}
#endif

#ifdef HAVE_DYNAMIC
/**
 * libretro_get_environment_info:
 * @func                         : Function pointer for get_environment_info.
 * @load_no_content              : If true, core should be able to auto-start
 *                                 without any content loaded.
 *
 * Sets environment callback in order to get statically known
 * information from it.
 *
 * Fetched via environment callbacks instead of
 * retro_get_system_info(), as this info is part of extensions.
 *
 * Should only be called once right after core load to
 * avoid overwriting the "real" environ callback.
 *
 * For statically linked cores, pass retro_set_environment as argument.
 */
void libretro_get_environment_info(void (*func)(retro_environment_t),
      bool *load_no_content)
{
   load_no_content_hook = load_no_content;

   /* load_no_content gets set in this callback. */
   func(environ_cb_get_system_info);

   /* It's possible that we just set get_system_info callback 
    * to the currently running core.
    *
    * Make sure we reset it to the actual environment callback.
    * Ignore any environment callbacks here in case we're running 
    * on the non-current core. */
   ignore_environment_cb = true;
   func(rarch_environment_cb);
   ignore_environment_cb = false;
}

static dylib_t libretro_get_system_info_lib(const char *path,
      struct retro_system_info *info, bool *load_no_content)
{
   dylib_t lib = dylib_load(path);
   void (*proc)(struct retro_system_info*);

   if (!lib)
   {
      ELOG("%s: \"%s\"\n",
            msg_hash_to_str(MSG_FAILED_TO_OPEN_LIBRETRO_CORE),
            path);
      ELOG("Error(s): %s\n", dylib_error());
      return NULL;
   }

   proc = (void (*)(struct retro_system_info*))
      dylib_proc(lib, "retro_get_system_info");

   if (!proc)
   {
      dylib_close(lib);
      return NULL;
   }

   proc(info);

   if (load_no_content)
   {
      void (*set_environ)(retro_environment_t);
      *load_no_content = false;
      set_environ = (void (*)(retro_environment_t))
         dylib_proc(lib, "retro_set_environment");

      if (!set_environ)
         return lib;

      libretro_get_environment_info(set_environ, load_no_content);
   }

   return lib;
}

/**
 * libretro_get_system_info:
 * @path                         : Path to libretro library.
 * @info                         : Pointer to system info information.
 * @load_no_content              : If true, core should be able to auto-start
 *                                 without any content loaded.
 *
 * Gets system info from an arbitrary lib.
 * The struct returned must be freed as strings are allocated dynamically.
 *
 * Returns: true (1) if successful, otherwise false (0).
 **/
bool libretro_get_system_info(const char *path,
      struct retro_system_info *info, bool *load_no_content)
{
   struct retro_system_info dummy_info = {0};
   dylib_t lib = libretro_get_system_info_lib(path,
         &dummy_info, load_no_content);
   if (!lib)
      return false;

   memcpy(info, &dummy_info, sizeof(*info));
   info->library_name    = strdup(dummy_info.library_name);
   info->library_version = strdup(dummy_info.library_version);
   if (dummy_info.valid_extensions)
      info->valid_extensions = strdup(dummy_info.valid_extensions);
   dylib_close(lib);
   return true;
}

static void load_dynamic_core(void)
{
   function_t sym       = dylib_proc(NULL, "retro_init");

   if (sym)
   {
      /* Try to verify that -lretro was not linked in from other modules
       * since loading it dynamically and with -l will fail hard. */
      ELOG("Serious problem. RetroArch wants to load libretro cores"
            "dyamically, but it is already linked.\n");
      ELOG("This could happen if other modules RetroArch depends on "
            "link against libretro directly.\n");
      ELOG("Proceeding could cause a crash. Aborting ...\n");
      retroarch_fail(1, "init_libretro_sym()");
   }

   if (string_is_empty(config_get_active_core_path()))
   {
      ELOG("RetroArch is built for dynamic libretro cores, but "
            "libretro_path is not set. Cannot continue.\n");
      retroarch_fail(1, "init_libretro_sym()");
   }

   /* Need to use absolute path for this setting. It can be
    * saved to content history, and a relative path would
    * break in that scenario. */
   path_resolve_realpath(
         config_get_active_core_path_ptr(),
         config_get_active_core_path_size(), true);

   VLOG("Loading dynamic libretro core from: \"%s\"\n",
         config_get_active_core_path());
   lib_handle = dylib_load(config_get_active_core_path());
   if (!lib_handle)
   {
      ELOG("Failed to open libretro core: \"%s\"\n",
            config_get_active_core_path());
      ELOG("Error(s): %s\n", dylib_error());
      retroarch_fail(1, "load_dynamic()");
   }
}
#endif

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

/**
 * libretro_get_current_core_pathname:
 * @name                         : Sanitized name of libretro core.
 * @size                         : Size of @name
 *
 * Transforms a library id to a name suitable as a pathname.
 **/
void libretro_get_current_core_pathname(char *name, size_t size)
{
   size_t i;
   struct retro_system_info info;
   const char                *id = msg_hash_to_str(MSG_UNKNOWN);

   if (size == 0)
      return;

   core_get_system_info(&info);

   if (info.library_name)
      id = info.library_name;

   if (!id || strlen(id) >= size)
   {
      name[0] = '\0';
      return;
   }

   name[strlen(id)] = '\0';

   for (i = 0; id[i] != '\0'; i++)
   {
      char c = id[i];

      if (isspace((int)c) || isblank((int)c))
         name[i] = '_';
      else
         name[i] = tolower((int)c);
   }
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
   camera_driver_ctl(RARCH_CAMERA_CTL_UNSET_ACTIVE, NULL);
//   location_driver_ctl(RARCH_LOCATION_CTL_UNSET_ACTIVE, NULL);

   /* Performance counters no longer valid. */
   performance_counters_clear();
}

static void rarch_log_libretro(enum retro_log_level level,
      const char *fmt, ...)
{
   va_list vp;
   settings_t *settings = config_get_ptr();

   if ((unsigned)level < settings->libretro_log_level)
      return;

   va_start(vp, fmt);

   switch (level)
   {
      case RETRO_LOG_DEBUG:
//         RARCH_LOG_V("[libretro DEBUG]", fmt, vp);
         break;

      case RETRO_LOG_INFO:
//         RARCH_LOG_OUTPUT_V("[libretro INFO]", fmt, vp);
         break;

      case RETRO_LOG_WARN:
//		   "[libretro WARN]"
		   printf(fmt, vp);
//         RARCH_WARN_V("[libretro WARN]", fmt, vp);
         break;

      case RETRO_LOG_ERROR:
		   printf(fmt, vp);
//         RARCH_ERR_V("[libretro ERROR]", fmt, vp);
         break;

      default:
         break;
   }

   va_end(vp);
}

static size_t mmap_add_bits_down(size_t n)
{
   n |= n >>  1;
   n |= n >>  2;
   n |= n >>  4;
   n |= n >>  8;
   n |= n >> 16;
   
   /* double shift to avoid warnings on 32bit (it's dead code, but compilers suck) */
   if (sizeof(size_t) > 4)
      n |= n >> 16 >> 16;
   
   return n;
}

static size_t mmap_inflate(size_t addr, size_t mask)
{
    while (mask)
   {
      size_t tmp = (mask - 1) & ~mask;
      /* to put in an 1 bit instead, OR in tmp+1 */
      addr = ((addr & ~tmp) << 1) | (addr & tmp);
      mask = mask & (mask - 1);
   }
   
   return addr;
}

static size_t mmap_reduce(size_t addr, size_t mask)
{
   while (mask)
   {
      size_t tmp = (mask - 1) & ~mask;
      addr = (addr & tmp) | ((addr >> 1) & ~tmp);
      mask = (mask & (mask - 1)) >> 1;
   }
   
   return addr;
}

static size_t mmap_highest_bit(size_t n)
{
   n = mmap_add_bits_down(n);
   return n ^ (n >> 1);
}

static bool mmap_preprocess_descriptors(struct retro_memory_descriptor *first, unsigned count)
{
   struct retro_memory_descriptor *desc;
   const struct retro_memory_descriptor *end;
   size_t top_addr, disconnect_mask;
   
   end = first + count;
   top_addr = 1;
   
   for (desc = first; desc < end; desc++)
   {
      if (desc->select != 0)
         top_addr |= desc->select;
      else
         top_addr |= desc->start + desc->len - 1;
   }
   
   top_addr = mmap_add_bits_down(top_addr);
   
   for (desc = first; desc < end; desc++)
   {
      if (desc->select == 0)
      {
         if (desc->len == 0)
            return false;
         
         if ((desc->len & (desc->len - 1)) != 0)
            return false;
         
         desc->select = top_addr & ~mmap_inflate(mmap_add_bits_down(desc->len - 1), desc->disconnect);
      }
      
      if (desc->len == 0)
         desc->len = mmap_add_bits_down(mmap_reduce(top_addr & ~desc->select, desc->disconnect)) + 1;
      
      if (desc->start & ~desc->select)
         return false;
       
      while (mmap_reduce(top_addr & ~desc->select, desc->disconnect) >> 1 > desc->len - 1)
         desc->disconnect |= mmap_highest_bit(top_addr & ~desc->select & ~desc->disconnect);
      
      disconnect_mask = mmap_add_bits_down(desc->len - 1);
      desc->disconnect &= disconnect_mask;
      
      while ((~disconnect_mask) >> 1 & desc->disconnect)
      {
         disconnect_mask >>= 1;
         desc->disconnect &= disconnect_mask;
      }
   }
   
   return true;
}

/**
 * rarch_environment_cb:
 * @cmd                          : Identifier of command.
 * @data                         : Pointer to data.
 *
 * Environment callback function implementation.
 *
 * Returns: true (1) if environment callback command could
 * be performed, otherwise false (0).
 **/
bool rarch_environment_cb(unsigned cmd, void *data)
{
   unsigned p;
   settings_t         *settings = config_get_ptr();
   global_t         *global     = global_get_ptr();
   rarch_system_info_t *system  = NULL;
   
   runloop_ctl(RUNLOOP_CTL_SYSTEM_INFO_GET, &system);

   if (ignore_environment_cb)
      return false;

   switch (cmd)
   {
      case RETRO_ENVIRONMENT_GET_OVERSCAN:
         *(bool*)data = !settings->video.crop_overscan;
         VLOG("Environ GET_OVERSCAN: %u\n",
               (unsigned)!settings->video.crop_overscan);
         break;

      case RETRO_ENVIRONMENT_GET_CAN_DUPE:
         *(bool*)data = true;
         VLOG("Environ GET_CAN_DUPE: true\n");
         break;

      case RETRO_ENVIRONMENT_GET_VARIABLE:
         if (!runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_GET, data))
         {
            struct retro_variable *var = (struct retro_variable*)data;

            if (var) {
               VLOG("Environ GET_VARIABLE %s: not implemented.\n", var->key);
               var->value = NULL;
            }
         }

         break;

      case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
         *(bool*)data = runloop_ctl(RUNLOOP_CTL_IS_CORE_OPTION_UPDATED, NULL);
         break;

      case RETRO_ENVIRONMENT_SET_VARIABLES:
         VLOG("Environ SET_VARIABLES.\n");

         runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_DEINIT, NULL);
         runloop_ctl(RUNLOOP_CTL_CORE_OPTIONS_INIT,   data);

         break;

      case RETRO_ENVIRONMENT_SET_MESSAGE:
      {
         const struct retro_message *msg = (const struct retro_message*)data;
         VLOG("Environ SET_MESSAGE: %s\n", msg->msg);
         runloop_msg_queue_push(msg->msg, 3, msg->frames, true);
         break;
      }

      case RETRO_ENVIRONMENT_SET_ROTATION:
      {
         unsigned rotation = *(const unsigned*)data;
         VLOG("Environ SET_ROTATION: %u\n", rotation);
         if (!settings->video.allow_rotate)
            break;

         if (system)
            system->rotation = rotation;

         if (!video_driver_set_rotation(rotation))
            return false;
         break;
      }

      case RETRO_ENVIRONMENT_SHUTDOWN:
         VLOG("Environ SHUTDOWN.\n");
         runloop_ctl(RUNLOOP_CTL_SET_SHUTDOWN,      NULL);
         runloop_ctl(RUNLOOP_CTL_SET_CORE_SHUTDOWN, NULL);
         break;

      case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
         if (system)
         {
            system->performance_level = *(const unsigned*)data;
            VLOG("Environ PERFORMANCE_LEVEL: %u.\n",
                  system->performance_level);
         }
         break;

      case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
         if (string_is_empty(settings->directory.system))
         {
            char *fullpath = NULL;
            if (runloop_ctl(RUNLOOP_CTL_GET_CONTENT_PATH, &fullpath) &&
                  fullpath)
            {
               WLOG("SYSTEM DIR is empty, assume CONTENT DIR %s\n",
                     fullpath);
               fill_pathname_basedir(global->dir.systemdir, fullpath,
                     sizeof(global->dir.systemdir));
            }

            *(const char**)data = global->dir.systemdir;
            VLOG("Environ SYSTEM_DIRECTORY: \"%s\".\n",
                  global->dir.systemdir);
         }
         else
         {
            *(const char**)data = settings->directory.system;
            VLOG("Environ SYSTEM_DIRECTORY: \"%s\".\n",
               settings->directory.system);
         }

         break;

      case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
         *(const char**)data = retroarch_get_current_savefile_dir();
         break;

      case RETRO_ENVIRONMENT_GET_USERNAME:
         *(const char**)data = *settings->username ?
            settings->username : NULL;
         VLOG("Environ GET_USERNAME: \"%s\".\n",
               settings->username);
         break;

      case RETRO_ENVIRONMENT_GET_LANGUAGE:
#ifdef HAVE_LANGEXTRA
         *(unsigned *)data = settings->user_language;
         VLOG("Environ GET_LANGUAGE: \"%u\".\n",
               settings->user_language);
#endif
         break;

      case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
      {
         enum retro_pixel_format pix_fmt =
            *(const enum retro_pixel_format*)data;

         switch (pix_fmt)
         {
            case RETRO_PIXEL_FORMAT_0RGB1555:
               VLOG("Environ SET_PIXEL_FORMAT: 0RGB1555.\n");
               break;

            case RETRO_PIXEL_FORMAT_RGB565:
               VLOG("Environ SET_PIXEL_FORMAT: RGB565.\n");
               break;
            case RETRO_PIXEL_FORMAT_XRGB8888:
               VLOG("Environ SET_PIXEL_FORMAT: XRGB8888.\n");
               break;
            default:
               return false;
         }

         video_driver_set_pixel_format(pix_fmt);
         break;
      }

      case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
      {
         static const char *libretro_btn_desc[]    = {
            "B (bottom)", "Y (left)", "Select", "Start",
            "D-Pad Up", "D-Pad Down", "D-Pad Left", "D-Pad Right",
            "A (right)", "X (up)",
            "L", "R", "L2", "R2", "L3", "R3",
         };

         if (system)
         {
            unsigned retro_id;
            const struct retro_input_descriptor *desc = NULL;
            memset(&system->input_desc_btn, 0,
                  sizeof(system->input_desc_btn));

            desc = (const struct retro_input_descriptor*)data;

            for (; desc->description; desc++)
            {
               unsigned retro_port = desc->port;

               retro_id            = desc->id;

               if (desc->port >= MAX_USERS)
                  continue;

               /* Ignore all others for now. */
               if (desc->device != RETRO_DEVICE_JOYPAD  &&
                     desc->device != RETRO_DEVICE_ANALOG)
                  continue;

               if (desc->id >= RARCH_FIRST_CUSTOM_BIND)
                  continue;

               if (desc->device == RETRO_DEVICE_ANALOG)
               {
                  switch (retro_id)
                  {
                     case RETRO_DEVICE_ID_ANALOG_X:
                        switch (desc->index)
                        {
                           case RETRO_DEVICE_INDEX_ANALOG_LEFT:
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_LEFT_X_PLUS]  = desc->description;
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_LEFT_X_MINUS] = desc->description;
                              break;
                           case RETRO_DEVICE_INDEX_ANALOG_RIGHT:
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_RIGHT_X_PLUS] = desc->description;
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_RIGHT_X_MINUS] = desc->description;
                              break;
                        }
                        break;
                     case RETRO_DEVICE_ID_ANALOG_Y:
                        switch (desc->index)
                        {
                           case RETRO_DEVICE_INDEX_ANALOG_LEFT:
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_LEFT_Y_PLUS] = desc->description;
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_LEFT_Y_MINUS] = desc->description;
                              break;
                           case RETRO_DEVICE_INDEX_ANALOG_RIGHT:
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_RIGHT_Y_PLUS] = desc->description;
                              system->input_desc_btn[retro_port]
                                 [RARCH_ANALOG_RIGHT_Y_MINUS] = desc->description;
                              break;
                        }
                        break;
                  }
               }
               else
                  system->input_desc_btn[retro_port]
                     [retro_id] = desc->description;
            }

            VLOG("Environ SET_INPUT_DESCRIPTORS:\n");
            for (p = 0; p < settings->input.max_users; p++)
            {
               for (retro_id = 0; retro_id < RARCH_FIRST_CUSTOM_BIND; retro_id++)
               {
                  const char *description = system->input_desc_btn[p][retro_id];

                  if (!description)
                     continue;

                  VLOG("\tRetroPad, User %u, Button \"%s\" => \"%s\"\n",
                        p + 1, libretro_btn_desc[retro_id], description);
               }
            }

            core_set_input_descriptors();
         }

         break;
      }

      case RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK:
      {
         retro_keyboard_event_t *frontend_key_event = NULL;
         retro_keyboard_event_t *key_event          = NULL;
         const struct retro_keyboard_callback *info =
            (const struct retro_keyboard_callback*)data;

         runloop_ctl(RUNLOOP_CTL_FRONTEND_KEY_EVENT_GET, &frontend_key_event);
         runloop_ctl(RUNLOOP_CTL_KEY_EVENT_GET, &key_event);

         VLOG("Environ SET_KEYBOARD_CALLBACK.\n");
         if (key_event)
            *key_event                  = info->callback;

         if (frontend_key_event && key_event)
            *frontend_key_event         = *key_event;
         break;
      }

      case RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE:
         VLOG("Environ SET_DISK_CONTROL_INTERFACE.\n");
         if (system)
            system->disk_control_cb =
               *(const struct retro_disk_control_callback*)data;
         break;

      case RETRO_ENVIRONMENT_SET_HW_RENDER:
      case RETRO_ENVIRONMENT_SET_HW_RENDER | RETRO_ENVIRONMENT_EXPERIMENTAL:
      {
         struct retro_hw_render_callback *hwr = NULL;
         struct retro_hw_render_callback *cb =
            (struct retro_hw_render_callback*)data;

         hwr = video_driver_get_hw_context();

         VLOG("Environ SET_HW_RENDER.\n");

         switch (cb->context_type)
         {
            case RETRO_HW_CONTEXT_NONE:
               VLOG("Requesting no HW context.\n");
               break;

            case RETRO_HW_CONTEXT_VULKAN:
#ifdef HAVE_VULKAN
               VLOG("Requesting Vulkan context.\n");
               break;
#else
               ELOG("Requesting Vulkan context, but RetroArch is not compiled against Vulkan. Cannot use HW context.\n");
               return false;
#endif

#if defined(HAVE_OPENGLES)

#if (defined(HAVE_OPENGLES2) || defined(HAVE_OPENGLES3))
            case RETRO_HW_CONTEXT_OPENGLES2:
#ifdef HAVE_OPENGLES3
            case RETRO_HW_CONTEXT_OPENGLES3:
#endif
               VLOG("Requesting OpenGLES%u context.\n",
                     cb->context_type == RETRO_HW_CONTEXT_OPENGLES2 ? 2 : 3);
               break;

#if defined(HAVE_OPENGLES3)
            case RETRO_HW_CONTEXT_OPENGLES_VERSION:
               VLOG("Requesting OpenGLES%u.%u context.\n",
                     cb->version_major, cb->version_minor);
               break;
#endif

#endif
            case RETRO_HW_CONTEXT_OPENGL:
            case RETRO_HW_CONTEXT_OPENGL_CORE:
               ELOG("Requesting OpenGL context, but RetroArch "
                     "is compiled against OpenGLES. Cannot use HW context.\n");
               return false;

#elif defined(HAVE_OPENGL)
            case RETRO_HW_CONTEXT_OPENGLES2:
            case RETRO_HW_CONTEXT_OPENGLES3:
               ELOG("Requesting OpenGLES%u context, but RetroArch "
                     "is compiled against OpenGL. Cannot use HW context.\n",
                     cb->context_type == RETRO_HW_CONTEXT_OPENGLES2 ? 2 : 3);
               return false;

            case RETRO_HW_CONTEXT_OPENGLES_VERSION:
               ELOG("Requesting OpenGLES%u.%u context, but RetroArch "
                     "is compiled against OpenGL. Cannot use HW context.\n",
                     cb->version_major, cb->version_minor);
               return false;

            case RETRO_HW_CONTEXT_OPENGL:
               VLOG("Requesting OpenGL context.\n");
               break;

            case RETRO_HW_CONTEXT_OPENGL_CORE:
               {
                  gfx_ctx_flags_t flags;
                  flags.flags = 0;
                  BIT32_SET(flags.flags, GFX_CTX_FLAGS_GL_CORE_CONTEXT);

                  video_context_driver_set_flags(&flags);

                  VLOG("Requesting core OpenGL context (%u.%u).\n",
                        cb->version_major, cb->version_minor);
               }
               break;
#endif

            default:
               VLOG("Requesting unknown context.\n");
               return false;
         }
         cb->get_current_framebuffer = video_driver_get_current_framebuffer;
         cb->get_proc_address        = video_driver_get_proc_address;

         /* Old ABI. Don't copy garbage. */
         if (cmd & RETRO_ENVIRONMENT_EXPERIMENTAL) 
            memcpy(hwr,
                  cb, offsetof(struct retro_hw_render_callback, stencil));
         else
            memcpy(hwr, cb, sizeof(*cb));
         break;
      }

      case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
      {
         bool state = *(const bool*)data;
         VLOG("Environ SET_SUPPORT_NO_GAME: %s.\n", state ? "yes" : "no");

         if (state)
            content_set_does_not_need_content();
         else
            content_unset_does_not_need_content();
         break;
      }

      case RETRO_ENVIRONMENT_GET_LIBRETRO_PATH:
      {
         const char **path = (const char**)data;
#ifdef HAVE_DYNAMIC
         *path = config_get_active_core_path();
#else
         *path = NULL;
#endif
         break;
      }

      case RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK:
#if defined(HAVE_THREADS) && !defined(__CELLOS_LV2__)
      {
         VLOG("Environ SET_AUDIO_CALLBACK.\n");
         audio_driver_set_callback(data);
      }
#endif
      break;

      case RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK:
      {
         VLOG("Environ SET_FRAME_TIME_CALLBACK.\n");
         runloop_ctl(RUNLOOP_CTL_SET_FRAME_TIME, data);
         break;
      }

      case RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE:
      {
         struct retro_rumble_interface *iface =
            (struct retro_rumble_interface*)data;

         VLOG("Environ GET_RUMBLE_INTERFACE.\n");
         iface->set_rumble_state = input_driver_set_rumble_state;
         break;
      }

      case RETRO_ENVIRONMENT_GET_INPUT_DEVICE_CAPABILITIES:
      {
         uint64_t *mask = (uint64_t*)data;

         VLOG("Environ GET_INPUT_DEVICE_CAPABILITIES.\n");
         if (input_driver_has_capabilities())
            *mask = input_driver_get_capabilities();
         else
            return false;
         break;
      }

      case RETRO_ENVIRONMENT_GET_SENSOR_INTERFACE:
      {
         struct retro_sensor_interface *iface =
            (struct retro_sensor_interface*)data;

         VLOG("Environ GET_SENSOR_INTERFACE.\n");
         iface->set_sensor_state = input_sensor_set_state;
         iface->get_sensor_input = input_sensor_get_input;
         break;
      }
      case RETRO_ENVIRONMENT_GET_CAMERA_INTERFACE:
      {
         struct retro_camera_callback *cb =
            (struct retro_camera_callback*)data;

         VLOG("Environ GET_CAMERA_INTERFACE.\n");
         cb->start                        = driver_camera_start;
         cb->stop                         = driver_camera_stop;

         camera_driver_ctl(RARCH_CAMERA_CTL_SET_CB, cb);

         if (cb->caps != 0)
            camera_driver_ctl(RARCH_CAMERA_CTL_SET_ACTIVE, NULL);
         else
            camera_driver_ctl(RARCH_CAMERA_CTL_UNSET_ACTIVE, NULL);
         break;
      }

      case RETRO_ENVIRONMENT_GET_LOCATION_INTERFACE:
      {
//         struct retro_location_callback *cb =
//            (struct retro_location_callback*)data;
//
//         VLOG("Environ GET_LOCATION_INTERFACE.\n");
//         cb->start                 = driver_location_start;
//         cb->stop                  = driver_location_stop;
//         cb->get_position          = driver_location_get_position;
//         cb->set_interval          = driver_location_set_interval;
//
//         if (system)
//            system->location_cb    = *cb;
//
//         location_driver_ctl(RARCH_LOCATION_CTL_UNSET_ACTIVE, NULL);
         break;
      }

      case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
      {
         struct retro_log_callback *cb = (struct retro_log_callback*)data;

         VLOG("Environ GET_LOG_INTERFACE.\n");
         cb->log = rarch_log_libretro;
         break;
      }

      case RETRO_ENVIRONMENT_GET_PERF_INTERFACE:
      {
         struct retro_perf_callback *cb = (struct retro_perf_callback*)data;

         VLOG("Environ GET_PERF_INTERFACE.\n");
         cb->get_time_usec    = cpu_features_get_time_usec;
         cb->get_cpu_features = cpu_features_get;
         cb->get_perf_counter = cpu_features_get_perf_counter;

         cb->perf_register    = performance_counter_register; 
         cb->perf_start       = performance_counter_start;
         cb->perf_stop        = performance_counter_stop;
         cb->perf_log         = retro_perf_log;
         break;
      }

      case RETRO_ENVIRONMENT_GET_CORE_ASSETS_DIRECTORY:
      {
         const char **dir = (const char**)data;

         *dir = *settings->directory.core_assets ?
            settings->directory.core_assets : NULL;
         VLOG("Environ CORE_ASSETS_DIRECTORY: \"%s\".\n",
               settings->directory.core_assets);
         break;
      }

      case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO:
      {
         VLOG("Environ SET_SYSTEM_AV_INFO.\n");
         return driver_ctl(RARCH_DRIVER_CTL_UPDATE_SYSTEM_AV_INFO,
               (void**)&data);
      }

      case RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO:
      {
         unsigned i, j;
         const struct retro_subsystem_info *info =
            (const struct retro_subsystem_info*)data;

         VLOG("Environ SET_SUBSYSTEM_INFO.\n");

         for (i = 0; info[i].ident; i++)
         {
            VLOG("Special game type: %s\n", info[i].desc);
            VLOG("  Ident: %s\n", info[i].ident);
            VLOG("  ID: %u\n", info[i].id);
            VLOG("  Content:\n");
            for (j = 0; j < info[i].num_roms; j++)
            {
               VLOG("    %s (%s)\n",
                     info[i].roms[j].desc, info[i].roms[j].required ?
                     "required" : "optional");
            }
         }

         if (system)
         {
            free(system->subsystem.data);
            system->subsystem.data = (struct retro_subsystem_info*)
               calloc(i, sizeof(*system->subsystem.data));

            if (!system->subsystem.data)
               return false;

            memcpy(system->subsystem.data, info,
                  i * sizeof(*system->subsystem.data));
            system->subsystem.size = i;
         }
         break;
      }

      case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
      {
         unsigned i, j;
         const struct retro_controller_info *info =
            (const struct retro_controller_info*)data;

         VLOG("Environ SET_CONTROLLER_INFO.\n");

         for (i = 0; info[i].types; i++)
         {
            VLOG("Controller port: %u\n", i + 1);
            for (j = 0; j < info[i].num_types; j++)
               VLOG("   %s (ID: %u)\n", info[i].types[j].desc,
                     info[i].types[j].id);
         }

         if (system)
         {
            free(system->ports.data);
            system->ports.data = (struct retro_controller_info*)
               calloc(i, sizeof(*system->ports.data));
            if (!system->ports.data)
               return false;

            memcpy(system->ports.data, info,
                  i * sizeof(*system->ports.data));
            system->ports.size = i;
         }
         break;
      }
      
      case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
      {
         if (system)
         {
            unsigned i;
            const struct retro_memory_map *mmaps        =
               (const struct retro_memory_map*)data;
            struct retro_memory_descriptor *descriptors = NULL;

            VLOG("Environ SET_MEMORY_MAPS.\n");
            free((void*)system->mmaps.descriptors);
            system->mmaps.num_descriptors = 0;
            descriptors = (struct retro_memory_descriptor*)
               calloc(mmaps->num_descriptors,
                     sizeof(*system->mmaps.descriptors));

            if (!descriptors)
               return false;

            system->mmaps.descriptors = descriptors;
            memcpy((void*)system->mmaps.descriptors, mmaps->descriptors,
                  mmaps->num_descriptors * sizeof(*system->mmaps.descriptors));
            system->mmaps.num_descriptors = mmaps->num_descriptors;
            mmap_preprocess_descriptors(descriptors, mmaps->num_descriptors);

            if (sizeof(void *) == 8)
               VLOG("   ndx flags  ptr              offset   start    select   disconn  len      addrspace\n");
            else
               VLOG("   ndx flags  ptr          offset   start    select   disconn  len      addrspace\n");

            for (i = 0; i < system->mmaps.num_descriptors; i++)
            {
               const struct retro_memory_descriptor *desc =
                  &system->mmaps.descriptors[i];
               char flags[7];

               flags[0] = 'M';
               if ((desc->flags & RETRO_MEMDESC_MINSIZE_8) == RETRO_MEMDESC_MINSIZE_8)
                  flags[1] = '8';
               else if ((desc->flags & RETRO_MEMDESC_MINSIZE_4) == RETRO_MEMDESC_MINSIZE_4)
                  flags[1] = '4';
               else if ((desc->flags & RETRO_MEMDESC_MINSIZE_2) == RETRO_MEMDESC_MINSIZE_2)
                  flags[1] = '2';
               else
                  flags[1] = '1';

               flags[2] = 'A';
               if ((desc->flags & RETRO_MEMDESC_ALIGN_8) == RETRO_MEMDESC_ALIGN_8)
                  flags[3] = '8';
               else if ((desc->flags & RETRO_MEMDESC_ALIGN_4) == RETRO_MEMDESC_ALIGN_4)
                  flags[3] = '4';
               else if ((desc->flags & RETRO_MEMDESC_ALIGN_2) == RETRO_MEMDESC_ALIGN_2)
                  flags[3] = '2';
               else
                  flags[3] = '1';

               flags[4] = (desc->flags & RETRO_MEMDESC_BIGENDIAN) ? 'B' : 'b';
               flags[5] = (desc->flags & RETRO_MEMDESC_CONST) ? 'C' : 'c';
               flags[6] = 0;

               VLOG("   %03u %s %p %08X %08X %08X %08X %08X %s\n",
                     i + 1, flags, desc->ptr, desc->offset, desc->start,
                     desc->select, desc->disconnect, desc->len,
                     desc->addrspace ? desc->addrspace : "");
            }
         }
         else
         {
            WLOG("Environ SET_MEMORY_MAPS, but system pointer not initialized..\n");
         }

         break;
      }

      case RETRO_ENVIRONMENT_SET_GEOMETRY:
      {
         const struct retro_game_geometry *in_geom = NULL;
         struct retro_game_geometry *geom = NULL;
         struct retro_system_av_info *av_info = 
            video_viewport_get_system_av_info();
         
         if (av_info)
            geom = (struct retro_game_geometry*)&av_info->geometry;

         if (!geom)
            return false;

         in_geom = (const struct retro_game_geometry*)data;

         VLOG("Environ SET_GEOMETRY.\n");

         /* Can potentially be called every frame,
          * don't do anything unless required. */
         if (geom->base_width != in_geom->base_width ||
               geom->base_height != in_geom->base_height ||
               geom->aspect_ratio != in_geom->aspect_ratio)
         {
            geom->base_width   = in_geom->base_width;
            geom->base_height  = in_geom->base_height;
            geom->aspect_ratio = in_geom->aspect_ratio;

            VLOG("SET_GEOMETRY: %ux%u, aspect: %.3f.\n",
                  geom->base_width, geom->base_height, geom->aspect_ratio);

            /* Forces recomputation of aspect ratios if
             * using core-dependent aspect ratios. */
            command_event(CMD_EVENT_VIDEO_SET_ASPECT_RATIO, NULL);

            /* TODO: Figure out what to do, if anything, with recording. */
         }
         break;
      }

      case RETRO_ENVIRONMENT_GET_CURRENT_SOFTWARE_FRAMEBUFFER:
         return video_driver_get_current_software_framebuffer(
               (struct retro_framebuffer*)data);

      case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE:
         return video_driver_get_hw_render_interface(
               (const struct retro_hw_render_interface**)data);
      
      case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
#ifdef HAVE_CHEEVOS
         {
            bool state = *(const bool*)data;
            VLOG("Environ SET_SUPPORT_ACHIEVEMENTS: %s.\n", state ? "yes" : "no");
            cheevos_set_support_cheevos(state);
         }
#endif
         break;

      case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE:
      {
         const struct retro_hw_render_context_negotiation_interface *iface =
            (const struct retro_hw_render_context_negotiation_interface*)data;
         VLOG("Environ SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE.\n");
         video_driver_set_context_negotiation_interface(iface);
         break;
      }

      /* Default */
      default:
         VLOG("Environ UNSUPPORTED (#%u).\n", cmd);
         return false;
   }

   return true;
}
