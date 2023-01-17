/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-Next - libretro.c                                         *
 *   Copyright (C) 2020 M4xw <m4x@m4xw.net>                                *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <compat/strl.h>

#include "libretro.h"
#include "libretro_private.h"
#include "libretro_core_options.h"

#include "GLideN64_libretro.h"
#include "mupen64plus-next_common.h"

#include <libco.h>

#ifdef HAVE_LIBNX
#include <switch.h>
#endif
#include <pthread.h>
#include <glsm/glsmsym.h>

#include "api/m64p_frontend.h"
#include "api/m64p_types.h"
#include "device/r4300/r4300_core.h"
#include "device/memory/memory.h"
#include "main/main.h"
#include "api/callbacks.h"
#include "main/cheat.h"
#include "main/version.h"
#include "main/util.h"
#include "main/savestates.h"
#include "main/mupen64plus.ini.h"
#include "api/m64p_config.h"
#include "osal_files.h"
#include "main/rom.h"
#include "plugin/plugin.h"
#include "device/rcp/pi/pi_controller.h"
#include "device/pif/pif.h"
#include "libretro_memory.h"

#include "audio_plugin.h"

#ifndef PRESCALE_WIDTH
#define PRESCALE_WIDTH  640
#endif

#ifndef PRESCALE_HEIGHT
#define PRESCALE_HEIGHT 625
#endif

#define PATH_SIZE 2048

#define ISHEXDEC ((codeLine[cursor]>='0') && (codeLine[cursor]<='9')) || ((codeLine[cursor]>='a') && (codeLine[cursor]<='f')) || ((codeLine[cursor]>='A') && (codeLine[cursor]<='F'))

/* Forward declarations */
#ifdef HAVE_THR_AL
void angrylion_set_filtering(unsigned filter_type);
void angrylion_set_vi_blur(unsigned value);
void angrylion_set_threads(unsigned value);
void angrylion_set_overscan(unsigned value);
void angrylion_set_synclevel(unsigned value);
void angrylion_set_vi_dedither(unsigned value);
void angrylion_set_vi(unsigned value);

struct rgba
{
    uint8_t b;
    uint8_t g;
    uint8_t r;
    uint8_t a;
};
extern struct rgba prescale[PRESCALE_WIDTH * PRESCALE_HEIGHT];
#endif // HAVE_THR_AL

#if defined(HAVE_PARALLEL_RDP)
#include "../mupen64plus-video-paraLLEl/parallel.h"

static struct retro_hw_render_callback hw_render;
static struct retro_hw_render_context_negotiation_interface_vulkan hw_context_negotiation;
#endif

struct retro_perf_callback perf_cb;
retro_get_cpu_features_t perf_get_cpu_features_cb = NULL;

retro_log_printf_t log_cb = NULL;
retro_video_refresh_t video_cb = NULL;
retro_input_poll_t poll_cb = NULL;
retro_input_state_t input_cb = NULL;
retro_audio_sample_batch_t audio_batch_cb = NULL;
retro_environment_t environ_cb = NULL;
retro_environment_t environ_clear_thread_waits_cb = NULL;

struct retro_rumble_interface rumble;

save_memory_data saved_memory;

static cothread_t game_thread;
cothread_t retro_thread;

int astick_deadzone;
int astick_sensitivity;
int r_cbutton;
int l_cbutton;
int d_cbutton;
int u_cbutton;
bool alternate_mapping;

static uint8_t* game_data = NULL;
static uint32_t game_size = 0;

static bool     emu_initialized     = false;
static unsigned audio_buffer_size   = 2048;

static unsigned retro_filtering      = 0;
static bool     first_context_reset  = false;
static bool     initializing         = true;
static bool     load_game_successful = false;

bool libretro_swap_buffer;

uint32_t *blitter_buf = NULL;
uint32_t *blitter_buf_lock = NULL;
uint32_t retro_screen_width = 640;
uint32_t retro_screen_height = 480;
uint32_t screen_pitch = 0;

float retro_screen_aspect = 4.0 / 3.0;

static char rdp_plugin_last[32] = {0};

// Savestate globals
bool retro_savestate_complete = false;
int  retro_savestate_result = 0;

// 64DD globals
char* retro_dd_path_img = NULL;
char* retro_dd_path_rom = NULL;

// Other Subsystems
char* retro_transferpak_rom_path = NULL;
char* retro_transferpak_ram_path = NULL;

uint32_t CoreOptionCategoriesSupported = 0;
uint32_t CoreOptionUpdateDisplayCbSupported = 0;
uint32_t bilinearMode = 0;
uint32_t EnableHybridFilter = 0;
uint32_t EnableDitheringPattern = 0;
uint32_t RDRAMImageDitheringMode = 0;
uint32_t EnableDitheringQuantization = 0;
uint32_t EnableHWLighting = 0;
uint32_t CorrectTexrectCoords = 0;
uint32_t EnableTexCoordBounds = 0;
uint32_t EnableInaccurateTextureCoordinates = 0;
uint32_t enableNativeResTexrects = 0;
uint32_t enableLegacyBlending = 0;
uint32_t EnableCopyColorToRDRAM = 0;
uint32_t EnableCopyDepthToRDRAM = 0;
uint32_t AspectRatio = 0;
uint32_t MaxTxCacheSize = 0;
uint32_t MaxHiResTxVramLimit = 0;
uint32_t txFilterMode = 0;
uint32_t txEnhancementMode = 0;
uint32_t txHiresEnable = 0;
uint32_t txHiresFullAlphaChannel = 0;
uint32_t txFilterIgnoreBG = 0;
uint32_t EnableFXAA = 0;
uint32_t MultiSampling = 0;
uint32_t EnableFragmentDepthWrite = 0;
uint32_t EnableShadersStorage = 0;
uint32_t EnableTextureCache = 0;
uint32_t EnableFBEmulation = 0;
uint32_t EnableFrameDuping = 0;
uint32_t EnableLODEmulation = 0;
uint32_t BackgroundMode = 0; // 0 is bgOnePiece
uint32_t EnableEnhancedTextureStorage = 0;
uint32_t EnableHiResAltCRC = 0;
uint32_t EnableEnhancedHighResStorage = 0;
uint32_t EnableTxCacheCompression = 0;
uint32_t EnableNativeResFactor = 0;
uint32_t EnableN64DepthCompare = 0;
uint32_t EnableThreadedRenderer = 0;
uint32_t EnableCopyAuxToRDRAM = 0;
uint32_t GLideN64IniBehaviour = 0;

// Overscan options
#define GLN64_OVERSCAN_SCALING "0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37|38|39|40|41|42|43|44|45|46|47|48|49|50"
uint32_t EnableOverscan = 0;
uint32_t OverscanTop = 0;
uint32_t OverscanLeft = 0;
uint32_t OverscanRight = 0;
uint32_t OverscanBottom = 0;

uint32_t EnableFullspeed = 0;
uint32_t CountPerOp = 0;
uint32_t CountPerOpDenomPot = 0;
uint32_t CountPerScanlineOverride = 0;
uint32_t ForceDisableExtraMem = 0;
uint32_t IgnoreTLBExceptions = 0;

extern struct device g_dev;
extern unsigned int r4300_emumode;
extern struct cheat_ctx g_cheat_ctx;

static bool emuThreadRunning = false;
static pthread_t emuThread;

// after the controller's CONTROL* member has been assigned we can update
// them straight from here...
extern struct
{
    CONTROL *control;
    BUTTONS buttons;
} controller[4];
// ...but it won't be at least the first time we're called, in that case set
// these instead for input_plugin to read.
int pad_pak_types[4];
int pad_present[4] = {1, 1, 1, 1};

static void n64DebugCallback(void* aContext, int aLevel, const char* aMessage)
{
    char buffer[1024];
    snprintf(buffer, 1024, CORE_NAME ": %s\n", aMessage);
    if (log_cb)
        log_cb(RETRO_LOG_INFO, buffer);
}

extern m64p_rom_header ROM_HEADER;

static bool set_variable_visibility(void)
{
    // For simplicity we create a prepared var per plugin, maybe create a macro for this?
    struct retro_core_option_display option_display_gliden64;
    struct retro_core_option_display option_display_angrylion;
    struct retro_core_option_display option_display_parallel_rdp;

    size_t i;
    size_t num_options = 0;
    char **values_buf = NULL;
    struct retro_variable var;
    const char *rdp_plugin_current = "__NULL__";
    bool rdp_plugin_found = false;

    // If option categories are supported but
    // the option update display callback is not,
    // then all options should be shown,
    // i.e. do nothing
    if (CoreOptionCategoriesSupported && !CoreOptionUpdateDisplayCbSupported)
        return false;

    // Get current plugin
    var.key = CORE_NAME "-rdp-plugin";
    var.value = NULL;
    if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
    {
        rdp_plugin_current = var.value;
        rdp_plugin_found = true;
    }

    // Check if plugin has changed since last
    // call of this function
    if (!strcmp(rdp_plugin_last, rdp_plugin_current))
        return false;

    strlcpy(rdp_plugin_last, rdp_plugin_current, sizeof(rdp_plugin_last));

    // Show/hide options depending on Plugins (Active isn't relevant!)
    if (rdp_plugin_found)
    {
        option_display_gliden64.visible = !strcmp(rdp_plugin_current, "gliden64");
        option_display_angrylion.visible = !strcmp(rdp_plugin_current, "angrylion");
        option_display_parallel_rdp.visible = !strcmp(rdp_plugin_current, "parallel");
    } else {
        option_display_gliden64.visible = option_display_angrylion.visible = option_display_parallel_rdp.visible = true;
    }

    // Determine number of options
    for (;;)
    {
        if (!option_defs_us[num_options].key)
            break;
        num_options++;
    }

    // Copy parameters from option_defs_us array
    for (i = 0; i < num_options; i++)
    {
        const char *key  = option_defs_us[i].key;
        const char *hint = option_defs_us[i].info;
        if (hint)
        {
            // Quick and dirty, its the only consistent naming
            // Otherwise GlideN64 Setting keys will need to be broken again..
            if (!!strstr(hint, "(GLN64)"))
            {
                option_display_gliden64.key = key;
                environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display_gliden64);
            } else if (!!strstr(hint, "(AL)"))
            {
                option_display_angrylion.key = key;
                environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display_angrylion);
            } else if (!!strstr(key, "parallel-rdp")) // Maybe unify it later?
            {
                option_display_parallel_rdp.key = key;
                environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display_parallel_rdp);
            }
        }
    }

    return true;
}

static void setup_variables(void)
{
    bool categoriesSupported = false;
    bool updateDisplayCbSupported = false;
    struct retro_core_options_update_display_callback updateDisplayCb;

    static const struct retro_controller_description port[] = {
        { "Controller", RETRO_DEVICE_JOYPAD },
        { "RetroPad", RETRO_DEVICE_JOYPAD },
    };

    static const struct retro_controller_info ports[] = {
        { port, 2 },
        { port, 2 },
        { port, 2 },
        { port, 2 },
        { 0, 0 }
    };

    libretro_set_core_options(environ_cb, &categoriesSupported);
    if (categoriesSupported)
        CoreOptionCategoriesSupported = 1;

    updateDisplayCb.callback = set_variable_visibility;
    updateDisplayCbSupported = environ_cb(
            RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK,
            &updateDisplayCb);
    if (updateDisplayCbSupported)
        CoreOptionUpdateDisplayCbSupported = 1;

    environ_cb(RETRO_ENVIRONMENT_SET_CONTROLLER_INFO, (void*)ports);
}

static void cleanup_global_paths()
{
    // Ensure potential leftovers are cleaned up
    if(retro_dd_path_img)
    {
        free(retro_dd_path_img);
        retro_dd_path_img = NULL;
    }

    if(retro_dd_path_rom)
    {
        free(retro_dd_path_rom);
        retro_dd_path_rom = NULL;
    }

    if(retro_transferpak_rom_path)
    {
        free(retro_transferpak_rom_path);
        retro_transferpak_rom_path = NULL;
    }

    if(retro_transferpak_ram_path)
    {
        free(retro_transferpak_ram_path);
        retro_transferpak_ram_path = NULL;
    }
}

static void n64StateCallback(void *Context, m64p_core_param param_type, int new_value)
{
    if(param_type == M64CORE_STATE_LOADCOMPLETE || param_type == M64CORE_STATE_SAVECOMPLETE)
    {
        retro_savestate_complete = true;
        retro_savestate_result = new_value;
    }
}

static bool emu_step_load_data()
{
    g_EmulatorRunning=false;    
    m64p_error ret = CoreStartup(FRONTEND_API_VERSION, ".", ".", NULL, n64DebugCallback, 0, n64StateCallback);
    if(ret && log_cb)
        log_cb(RETRO_LOG_ERROR, CORE_NAME ": failed to initialize core (err=%i)\n", ret);

    log_cb(RETRO_LOG_DEBUG, CORE_NAME ": [EmuThread] M64CMD_ROM_OPEN\n");

    CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL);
    if(CoreDoCommand(M64CMD_ROM_OPEN, game_size, (void*)game_data))
    {
        if (log_cb)
            log_cb(RETRO_LOG_ERROR, CORE_NAME ": failed to load ROM\n");
        goto load_fail;
    }

    free(game_data);
    game_data = NULL;

    log_cb(RETRO_LOG_DEBUG, CORE_NAME ": [EmuThread] M64CMD_ROM_GET_HEADER\n");

    if(CoreDoCommand(M64CMD_ROM_GET_HEADER, sizeof(ROM_HEADER), &ROM_HEADER))
    {
        if (log_cb)
            log_cb(RETRO_LOG_ERROR, CORE_NAME ": failed to query ROM header information\n");
        goto load_fail;
    }

    return true;

load_fail:
    free(game_data);
    game_data = NULL;
    //stop = 1;

    return false;
}

static void emu_step_initialize(void)
{
    if (emu_initialized)
        return;

    emu_initialized = true;

    plugin_connect_all();
}

static void* EmuThreadFunction(void* param)
{
    uint32_t netplay_port = 0;
    uint16_t netplay_player = 1;

    initializing = false;

    if (netplay_port)
    {
        uint32_t version;
        if (CoreDoCommand(M64CMD_NETPLAY_GET_VERSION, 0x010000, &version) == M64ERR_SUCCESS)
        {
            log_cb(RETRO_LOG_INFO, "Netplay: using core version %u\n", version);

            if (CoreDoCommand(M64CMD_NETPLAY_INIT, netplay_port, "") == M64ERR_SUCCESS)
                log_cb(RETRO_LOG_INFO, "Netplay: init success\n");

            uint32_t reg_id = 0;
            while (reg_id == 0)
            {
#ifdef __MINGW32__
                rand_s(&reg_id);
#else
                reg_id = rand();
#endif
            }
            reg_id += netplay_player;

            if (CoreDoCommand(M64CMD_NETPLAY_CONTROL_PLAYER, netplay_player, &reg_id) == M64ERR_SUCCESS)
                log_cb(RETRO_LOG_INFO, "Netplay: registered for player %d\n", netplay_player);
        }
    }

    log_cb(RETRO_LOG_DEBUG, CORE_NAME ": [EmuThread] M64CMD_EXECUTE\n");

    // Runs until CMD_STOP
    CoreDoCommand(M64CMD_EXECUTE, 0, NULL);

    if(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer)
    {
        // Unset
        emuThreadRunning = false;
    }

    return NULL;
}

static void reinit_gfx_plugin(void)
{
#ifdef HAVE_PARALLEL_RDP
    if (current_rdp_type == RDP_PLUGIN_PARALLEL)
    {
        const struct retro_hw_render_interface_vulkan *vulkan;
        if (!environ_cb(RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE, &vulkan) || !vulkan)
        {
            if (log_cb)
                log_cb(RETRO_LOG_ERROR, "Failed to obtain Vulkan interface.\n");
            vulkan = NULL;
        }
        parallel_set_vulkan_interface(vulkan);

        // On first context init, the ROM is not loaded yet, so defer initialization of the plugin.
        // On context destroy/resets however, just initialize right away.
        if (!first_context_reset)
            parallel_init();
    }
#endif

    if(first_context_reset)
    {
        first_context_reset = false;
        emu_step_initialize();
    }
}

const char* retro_get_system_directory(void)
{
    const char* dir;
    environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &dir);

    return dir ? dir : ".";
}


void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb)   { }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { poll_cb = cb; }
void retro_set_input_state(retro_input_state_t cb) { input_cb = cb; }

bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info)
{
    size_t outSize = 0;
    bool result = false;
    void* gameBuffer = NULL;

    cleanup_global_paths();

    switch(game_type)
    {
        case RETRO_GAME_TYPE_DD:
            if(num_info == 1)
            {
                retro_dd_path_img = strdup(info[0].path);
            }
            else if(num_info == 2)
            {
                retro_dd_path_img = strdup(info[0].path);
                retro_dd_path_rom = strdup(info[1].path);
            } else {
                return false;
            }
            
            log_cb(RETRO_LOG_INFO, "Loading %s...\n", info[0].path);
            
            result = load_file(info[1].path, &gameBuffer, &outSize) == file_ok;
            if(result)
            {
               memcpy(&info[1].data, &gameBuffer, sizeof(void*));
               memcpy(&info[1].size, &outSize, sizeof(size_t));
               result = result && retro_load_game(&info[1]);
               
               if(gameBuffer)
               {
                  free(gameBuffer);
                  gameBuffer = NULL;
                  // To prevent potential double free // TODO: revisit later
                  memcpy(&info[1].data, &gameBuffer, sizeof(void*));
               }
            }
            break;
        case RETRO_GAME_TYPE_TRANSFERPAK:
            if(num_info == 3)
            {
                retro_transferpak_ram_path = strdup(info[0].path);
                retro_transferpak_rom_path = strdup(info[1].path);
            } else {
                return false;
            }
            
            log_cb(RETRO_LOG_INFO, "Loading %s...\n", info[0].path);
            log_cb(RETRO_LOG_INFO, "Loading %s...\n", info[1].path);
            log_cb(RETRO_LOG_INFO, "Loading %s...\n", info[2].path);
            result = load_file(info[2].path, &gameBuffer, &outSize) == file_ok;
            if(result)
            {
               memcpy(&info[2].data, &gameBuffer, sizeof(void*));
               memcpy(&info[2].size, &outSize, sizeof(size_t));
               result = result && retro_load_game(&info[2]);
               if(gameBuffer)
               {
                  free(gameBuffer);
                  gameBuffer = NULL;
                  // To prevent potential double free // TODO: revisit later
                  memcpy(&info[2].data, &gameBuffer, sizeof(void*));
               }
            }
            break;
        default:
            return false;
    }

	 return result;
}

void retro_set_environment(retro_environment_t cb)
{
    environ_cb = cb;

    static const struct retro_subsystem_memory_info memory_info_dd[] = {
        { "srm", RETRO_MEMORY_DD },
        {}
    };

    static const struct retro_subsystem_memory_info memory_info_transferpak[] = {
        { "srm", RETRO_MEMORY_TRANSFERPAK },
        {}
    };

    static const struct retro_subsystem_rom_info dd_roms[] = {
        { "Disk", "ndd", true, false, true, memory_info_dd, 1 },
        { "Cartridge", "n64|v64|z64|bin|u1", true, false, true, NULL, 0 },
        {}
    };

    static const struct retro_subsystem_rom_info transferpak_roms[] = {
        { "Gameboy RAM", "ram|sav", true, false, true, NULL, 0 },
        { "Gameboy ROM", "rom|gb|gbc", true, false, true, NULL, 0 },
        { "Cartridge", "n64|v64|z64|bin|u1", true, false, true, memory_info_transferpak, 1 },
        {}
    };

    static const struct retro_subsystem_info subsystems[] = {
        { "N64 Disk Drive", "ndd", dd_roms, 2, RETRO_GAME_TYPE_DD },
        { "N64 Transferpak", "gb", transferpak_roms, 3, RETRO_GAME_TYPE_TRANSFERPAK },
        {}
    };

    environ_cb(RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO, (void*)subsystems);
    environ_cb(RETRO_ENVIRONMENT_GET_CLEAR_ALL_THREAD_WAITS_CB, &environ_clear_thread_waits_cb);
    
    setup_variables();
}

void retro_get_system_info(struct retro_system_info *info)
{
    info->library_name = "Mupen64Plus-Next";
    info->library_version = "2.4" FLAVOUR_VERSION GIT_VERSION;
    info->valid_extensions = "n64|v64|z64|bin|u1";
    info->need_fullpath = false;
    info->block_extract = false;
}

void retro_get_system_av_info(struct retro_system_av_info *info)
{
    info->geometry.base_width   = retro_screen_width;
    info->geometry.base_height  = retro_screen_height;
    info->geometry.max_width    = retro_screen_width;
    info->geometry.max_height   = retro_screen_height;
    info->geometry.aspect_ratio = retro_screen_aspect;
#ifdef HAVE_PARALLEL_RDP
    if (current_rdp_type == RDP_PLUGIN_PARALLEL)
        parallel_get_geometry(&info->geometry);
#endif
    info->timing.fps = vi_expected_refresh_rate_from_tv_standard(ROM_PARAMS.systemtype);
    info->timing.sample_rate = 44100.0;
}

unsigned retro_get_region (void)
{
    return ((ROM_PARAMS.systemtype == SYSTEM_PAL) ? RETRO_REGION_PAL : RETRO_REGION_NTSC);
}

void copy_file(char * ininame, char * fileName)
{
    const char* filename = ConfigGetSharedDataFilepath(fileName);
    FILE *fp = fopen(filename, "w");
    if (fp != NULL)    {
        fputs(ininame, fp);
        fclose(fp);
    }
}

void retro_init(void)
{
    char* sys_pathname;
    wchar_t w_pathname[PATH_SIZE];
    environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &sys_pathname);
    char pathname[PATH_SIZE];
    strncpy(pathname, sys_pathname, PATH_SIZE);
    if (pathname[(strlen(pathname)-1)] != '/' && pathname[(strlen(pathname)-1)] != '\\')
        strcat(pathname, "/");
    strcat(pathname, "Mupen64plus/");
    mbstowcs(w_pathname, pathname, PATH_SIZE);
    if (!osal_path_existsW(w_pathname) || !osal_is_directory(w_pathname))
        osal_mkdirp(w_pathname);
    copy_file(inifile, "mupen64plus.ini");

    struct retro_log_callback log;
    unsigned colorMode = RETRO_PIXEL_FORMAT_XRGB8888;

    if (environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
        log_cb = log.log;
    else
        log_cb = NULL;

    if (environ_cb(RETRO_ENVIRONMENT_GET_PERF_INTERFACE, &perf_cb))
        perf_get_cpu_features_cb = perf_cb.get_cpu_features;
    else
        perf_get_cpu_features_cb = NULL;

    environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &colorMode);
    environ_cb(RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE, &rumble);
    if(!(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer))
    {
        initializing = true;

        retro_thread = co_active();
        game_thread = co_create(65536 * sizeof(void*) * 16, EmuThreadFunction);
    }
}

void retro_deinit(void)
{
    // Prevent yield to game_thread on unsuccessful context request
    CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL);
    CoreShutdown();
    g_EmulatorRunning=false;    
    /*if(load_game_successful)
    {
       if(!(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer))
       {
           CoreDoCommand(M64CMD_STOP, 0, NULL);
           co_switch(game_thread); 
       }
    }
    */
    deinit_audio_libretro();

    if (perf_cb.perf_log)
        perf_cb.perf_log();

    rdp_plugin_last[0] = '\0';
    CoreOptionCategoriesSupported = 0;
    CoreOptionUpdateDisplayCbSupported = 0;
}

void update_controllers()
{
    struct retro_variable pk1var = { CORE_NAME "-pak1" };
    if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &pk1var) && pk1var.value)
    {
        int p1_pak = PLUGIN_NONE;
        if (!strcmp(pk1var.value, "rumble"))
            p1_pak = PLUGIN_RAW;
        else if (!strcmp(pk1var.value, "memory"))
            p1_pak = PLUGIN_MEMPAK;
        else if (!strcmp(pk1var.value, "transfer"))
            p1_pak = PLUGIN_TRANSFER_PAK;

        // If controller struct is not initialised yet, set pad_pak_types instead
        // which will be looked at when initialising the controllers.
        if (controller[0].control)
            controller[0].control->Plugin = p1_pak;
        else
            pad_pak_types[0] = p1_pak;
    }

    struct retro_variable pk2var = { CORE_NAME "-pak2" };
    if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &pk2var) && pk2var.value)
    {
        int p2_pak = PLUGIN_NONE;
        if (!strcmp(pk2var.value, "rumble"))
            p2_pak = PLUGIN_RAW;
        else if (!strcmp(pk2var.value, "memory"))
            p2_pak = PLUGIN_MEMPAK;
        else if (!strcmp(pk2var.value, "transfer"))
            p2_pak = PLUGIN_TRANSFER_PAK;

        if (controller[1].control)
            controller[1].control->Plugin = p2_pak;
        else
            pad_pak_types[1] = p2_pak;
    }

    struct retro_variable pk3var = { CORE_NAME "-pak3" };
    if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &pk3var) && pk3var.value)
    {
        int p3_pak = PLUGIN_NONE;
        if (!strcmp(pk3var.value, "rumble"))
            p3_pak = PLUGIN_RAW;
        else if (!strcmp(pk3var.value, "memory"))
            p3_pak = PLUGIN_MEMPAK;
        else if (!strcmp(pk3var.value, "transfer"))
            p3_pak = PLUGIN_TRANSFER_PAK;

        if (controller[2].control)
            controller[2].control->Plugin = p3_pak;
        else
            pad_pak_types[2] = p3_pak;
    }

    struct retro_variable pk4var = { CORE_NAME "-pak4" };
    if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &pk4var) && pk4var.value)
    {
        int p4_pak = PLUGIN_NONE;
        if (!strcmp(pk4var.value, "rumble"))
            p4_pak = PLUGIN_RAW;
        else if (!strcmp(pk4var.value, "memory"))
            p4_pak = PLUGIN_MEMPAK;
        else if (!strcmp(pk4var.value, "transfer"))
            p4_pak = PLUGIN_TRANSFER_PAK;

        if (controller[3].control)
            controller[3].control->Plugin = p4_pak;
        else
            pad_pak_types[3] = p4_pak;
    }
}

static void update_variables(bool startup)
{
    struct retro_variable var;
    static const char *screen_size_key = CORE_NAME "-43screensize";

    if (startup)
    {
       bool save_state_in_background = true;
       //environ_cb(RETRO_ENVIRONMENT_SET_SAVE_STATE_IN_BACKGROUND, &save_state_in_background);

       var.key = CORE_NAME "-rdp-plugin";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "gliden64"))
          {
            plugin_connect_rdp_api(RDP_PLUGIN_GLIDEN64);
          }
          else if (!strcmp(var.value, "angrylion"))
          {
             plugin_connect_rdp_api(RDP_PLUGIN_ANGRYLION);
          }
          else if (!strcmp(var.value, "parallel"))
          {
             plugin_connect_rdp_api(RDP_PLUGIN_PARALLEL);
          }
       }
       else
       {
          plugin_connect_rdp_api(RDP_PLUGIN_GLIDEN64);
       }

       var.key = CORE_NAME "-rsp-plugin";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "hle"))
          {
             // If we use angrylion with hle, we will force parallel if available!
             if(current_rdp_type != RDP_PLUGIN_ANGRYLION && current_rdp_type != RDP_PLUGIN_PARALLEL)
             {
                plugin_connect_rsp_api(RSP_PLUGIN_HLE);
             }
             else
             {
#if defined(HAVE_PARALLEL_RSP)
                plugin_connect_rsp_api(RSP_PLUGIN_PARALLEL);
                log_cb(RETRO_LOG_INFO, "Selected HLE RSP with Angrylion, falling back to Parallel RSP!\n");
#elif defined(HAVE_LLE)
                plugin_connect_rsp_api(RSP_PLUGIN_CXD4);
                log_cb(RETRO_LOG_INFO, "Selected HLE RSP with Angrylion, falling back to CXD4!\n");
#else
                log_cb(RETRO_LOG_INFO, "Requested Angrylion but no LLE RSP available, falling back to GLideN64!\n");
                plugin_connect_rsp_api(RSP_PLUGIN_HLE);
                plugin_connect_rdp_api(RDP_PLUGIN_GLIDEN64);
#endif 
             }
          }
          else if (!strcmp(var.value, "cxd4"))
          {
             plugin_connect_rsp_api(RSP_PLUGIN_CXD4);
          }
          else if (!strcmp(var.value, "parallel"))
          {
             plugin_connect_rsp_api(RSP_PLUGIN_PARALLEL);
          }
       }
       else
       {
          if(current_rdp_type != RDP_PLUGIN_ANGRYLION && current_rdp_type != RDP_PLUGIN_PARALLEL)
          {
                plugin_connect_rsp_api(RSP_PLUGIN_HLE);
          }
          else
          {
#if defined(HAVE_PARALLEL_RSP)
             plugin_connect_rsp_api(RSP_PLUGIN_PARALLEL);
#elif defined(HAVE_LLE)
             plugin_connect_rsp_api(RSP_PLUGIN_CXD4);
#else
             log_cb(RETRO_LOG_INFO, "Requested Angrylion but no LLE RSP available, falling back to GLideN64!\n");
             plugin_connect_rdp_api(RDP_PLUGIN_GLIDEN64);
             plugin_connect_rsp_api(RSP_PLUGIN_HLE);
#endif 
          }
       }

       if(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer)
       {
          unsigned poll_type_early      = 1; /* POLL_TYPE_EARLY */
          environ_cb(RETRO_ENVIRONMENT_POLL_TYPE_OVERRIDE, &poll_type_early);
       }
       
       var.key = CORE_NAME "-ThreadedRenderer";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableThreadedRenderer = !strcmp(var.value, "True") ? 1 : 0;
       }

       var.key = CORE_NAME "-BilinearMode";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          bilinearMode = !strcmp(var.value, "3point") ? 0 : 1;
       }

       var.key = CORE_NAME "-HybridFilter";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableHybridFilter = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-DitheringPattern";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableDitheringPattern = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-DitheringQuantization";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableDitheringQuantization = !strcmp(var.value, "False") ? 0 : 1;
       }
       
       var.key = CORE_NAME "-RDRAMImageDitheringMode";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "BlueNoise"))
             RDRAMImageDitheringMode = 2; // bdmBlueNoise
          else if (!strcmp(var.value, "MagicSquare"))
             RDRAMImageDitheringMode = 1; // bdmMagicSquare
          else if (!strcmp(var.value, "Bayer"))
             RDRAMImageDitheringMode = 1; // bdmBayer
          else
             RDRAMImageDitheringMode = 0; // bdmDisable
       }
       
       var.key = CORE_NAME "-FXAA";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableFXAA = atoi(var.value);
       }

       var.key = CORE_NAME "-MultiSampling";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          MultiSampling = atoi(var.value);
       }

       var.key = CORE_NAME "-FrameDuping";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableFrameDuping = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-Framerate";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableFullspeed = !strcmp(var.value, "Original") ? 0 : 1;
       }

       var.key = CORE_NAME "-virefresh";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          CountPerScanlineOverride = !strcmp(var.value, "Auto") ? 0 : atoi(var.value);
       }

       var.key = CORE_NAME "-EnableLODEmulation";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableLODEmulation = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableFBEmulation";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableFBEmulation = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableN64DepthCompare";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "Compatible"))
             EnableN64DepthCompare = 2; // dcCompatible
          else if (!strcmp(var.value, "True"))
             EnableN64DepthCompare = 1; // dcFast
          else
             EnableN64DepthCompare = 0; // dcDisable
       }

       var.key = CORE_NAME "-EnableCopyColorToRDRAM";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "TripleBuffer"))
             EnableCopyColorToRDRAM = 3;
          else if (!strcmp(var.value, "Async"))
             EnableCopyColorToRDRAM = 2;
          else if (!strcmp(var.value, "Sync"))
             EnableCopyColorToRDRAM = 1;
          else
             EnableCopyColorToRDRAM = 0;
       }

       var.key = CORE_NAME "-EnableCopyDepthToRDRAM";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "Software"))
             EnableCopyDepthToRDRAM = 2;
          else if (!strcmp(var.value, "FromMem"))
             EnableCopyDepthToRDRAM = 1;
          else
             EnableCopyDepthToRDRAM = 0;
       }

       var.key = CORE_NAME "-EnableHWLighting";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableHWLighting = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-CorrectTexrectCoords";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "Force"))
             CorrectTexrectCoords = 2;
          else if (!strcmp(var.value, "Auto"))
             CorrectTexrectCoords = 1;
          else
             CorrectTexrectCoords = 0;
       }

       var.key = CORE_NAME "-EnableTexCoordBounds";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableTexCoordBounds = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableInaccurateTextureCoordinates";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableInaccurateTextureCoordinates = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-BackgroundMode";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          BackgroundMode = !strcmp(var.value, "OnePiece") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableNativeResTexrects";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if(!strcmp(var.value, "False") || !strcmp(var.value, "Disabled"))
          {
             enableNativeResTexrects = 0; // NativeResTexrectsMode::ntDisable
          }
          else if(!strcmp(var.value, "Optimized"))
          {
             enableNativeResTexrects = 1; // NativeResTexrectsMode::ntOptimized
          }
          else if(!strcmp(var.value, "Unoptimized"))
          {
             enableNativeResTexrects = 2; // NativeResTexrectsMode::ntUnptimized (Note: upstream typo)
          }
       }

       var.key = CORE_NAME "-txFilterMode";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "Smooth filtering 1"))
             txFilterMode = 1;
          else if (!strcmp(var.value, "Smooth filtering 2"))
             txFilterMode = 2;
          else if (!strcmp(var.value, "Smooth filtering 3"))
             txFilterMode = 3;
          else if (!strcmp(var.value, "Smooth filtering 4"))
             txFilterMode = 4;
          else if (!strcmp(var.value, "Sharp filtering 1"))
             txFilterMode = 5;
          else if (!strcmp(var.value, "Sharp filtering 2"))
             txFilterMode = 6;
          else
             txFilterMode = 0;
       }

       var.key = CORE_NAME "-txEnhancementMode";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "As Is"))
             txEnhancementMode = 1;
          else if (!strcmp(var.value, "X2"))
             txEnhancementMode = 2;
          else if (!strcmp(var.value, "X2SAI"))
             txEnhancementMode = 3;
          else if (!strcmp(var.value, "HQ2X"))
             txEnhancementMode = 4;
          else if (!strcmp(var.value, "HQ2XS"))
             txEnhancementMode = 5;
          else if (!strcmp(var.value, "LQ2X"))
             txEnhancementMode = 6;
          else if (!strcmp(var.value, "LQ2XS"))
             txEnhancementMode = 7;
          else if (!strcmp(var.value, "HQ4X"))
             txEnhancementMode = 8;
          else if (!strcmp(var.value, "2xBRZ"))
             txEnhancementMode = 9;
          else if (!strcmp(var.value, "3xBRZ"))
             txEnhancementMode = 10;
          else if (!strcmp(var.value, "4xBRZ"))
             txEnhancementMode = 11;
          else if (!strcmp(var.value, "5xBRZ"))
             txEnhancementMode = 12;
          else if (!strcmp(var.value, "6xBRZ"))
             txEnhancementMode = 13;
          else
             txEnhancementMode = 0;
       }

       var.key = CORE_NAME "-txFilterIgnoreBG";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          // "Filter background textures; True|False" (true=filter, false=ignore)
          txFilterIgnoreBG = !strcmp(var.value, "False") ? 1 : 0;
       }

       var.key = CORE_NAME "-txHiresEnable";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          txHiresEnable = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-txCacheCompression";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableTxCacheCompression = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-txHiresFullAlphaChannel";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          txHiresFullAlphaChannel = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-MaxHiResTxVramLimit";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          MaxHiResTxVramLimit = atoi(var.value);
       }

       var.key = CORE_NAME "-MaxTxCacheSize";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          MaxTxCacheSize = atoi(var.value);
       }

       var.key = CORE_NAME "-EnableLegacyBlending";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          enableLegacyBlending = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableFragmentDepthWrite";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableFragmentDepthWrite = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableShadersStorage";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableShadersStorage = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableTextureCache";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableTextureCache = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableEnhancedTextureStorage";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableEnhancedTextureStorage = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableEnhancedHighResStorage";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableEnhancedHighResStorage = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableHiResAltCRC";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableHiResAltCRC = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-EnableCopyAuxToRDRAM";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableCopyAuxToRDRAM = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-GLideN64IniBehaviour";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "late"))
             GLideN64IniBehaviour = 0;
          else if (!strcmp(var.value, "early"))
             GLideN64IniBehaviour = 1;
          else if (!strcmp(var.value, "disabled"))
             GLideN64IniBehaviour = -1;
       }

       var.key = CORE_NAME "-cpucore";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "pure_interpreter"))
             r4300_emumode = EMUMODE_PURE_INTERPRETER;
          else if (!strcmp(var.value, "cached_interpreter"))
             r4300_emumode = EMUMODE_INTERPRETER;
          else if (!strcmp(var.value, "dynamic_recompiler"))
             r4300_emumode = EMUMODE_DYNAREC;
       }

       var.key = CORE_NAME "-aspect";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "16:9 adjusted")) {
             AspectRatio = 3; // Aspect::aAdjust
             // `retro_screen_aspect` is calculated on the fly when retrieving the `-169screensize` setting.
             screen_size_key = CORE_NAME "-169screensize";
          } else if (!strcmp(var.value, "16:9")) {
             AspectRatio = 0; // Aspect::aStretch
             screen_size_key = CORE_NAME "-169screensize";
          } else {
             AspectRatio = 1; // Aspect::a43
             retro_screen_aspect = 4.0 / 3.0;
             screen_size_key = CORE_NAME "-43screensize";
          }
       }

       var.key = CORE_NAME "-EnableNativeResFactor";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
         EnableNativeResFactor = atoi(var.value);
       }

       var.key = screen_size_key;
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          sscanf(var.value, "%dx%d", &retro_screen_width, &retro_screen_height);
          if (AspectRatio != 1) // Calculate the correct aspect ratio when using a ratio different than 4:3.
          {
             retro_screen_aspect = (float)retro_screen_width / (float)retro_screen_height;
          }

          // Sanity check... not optimal since we will render at a higher res, but otherwise
          // GLideN64 might blit a bigger image onto a smaller framebuffer
          // This is a recent regression.
          if((retro_screen_width == 320 && retro_screen_height == 240) ||
             (retro_screen_width == 640 && retro_screen_height == 360))
          {
             // Force factor to 1 for low resolutions, unless set manually
             EnableNativeResFactor = !EnableNativeResFactor ? 1 : EnableNativeResFactor;
          }
       }

       // If we use Angrylion, we force 640x480
       // TODO: ?
#ifdef HAVE_THR_AL
       if(current_rdp_type == RDP_PLUGIN_ANGRYLION)
       {
          retro_screen_width = 640;
          retro_screen_height = 480;
          retro_screen_aspect = 4.0 / 3.0;
          AspectRatio = 1; // Aspect::a43
       }
#endif // HAVE_THR_AL

       var.key = CORE_NAME "-astick-deadzone";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
          astick_deadzone = (int)(atoi(var.value) * 0.01f * 0x8000);

       var.key = CORE_NAME "-astick-sensitivity";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
          astick_sensitivity = atoi(var.value);

       var.key = CORE_NAME "-CountPerOp";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          CountPerOp = atoi(var.value);
       }
       
       var.key = CORE_NAME "-CountPerOpDenomPot";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          CountPerOpDenomPot = atoi(var.value);
       }

       if(EnableFullspeed)
       {
          CountPerOp = 1; // Force CountPerOp == 1
          if(current_rdp_type == RDP_PLUGIN_GLIDEN64 && !EnableFBEmulation)
             EnableFrameDuping = 1;
       }

#ifdef HAVE_THR_AL
       if(current_rdp_type == RDP_PLUGIN_ANGRYLION)
       {
           // We always want frame duping here, the result will be different from GLideN64
           // This is always prefered here!
           EnableFrameDuping = 1;
       }
#endif // HAVE_THR_AL

       var.key = CORE_NAME "-r-cbutton";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "C1"))
             r_cbutton = RETRO_DEVICE_ID_JOYPAD_A;
          else if (!strcmp(var.value, "C2"))
             r_cbutton = RETRO_DEVICE_ID_JOYPAD_Y;
          else if (!strcmp(var.value, "C3"))
             r_cbutton = RETRO_DEVICE_ID_JOYPAD_B;
          else if (!strcmp(var.value, "C4"))
             r_cbutton = RETRO_DEVICE_ID_JOYPAD_X;
       }

       var.key = CORE_NAME "-l-cbutton";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "C1"))
             l_cbutton = RETRO_DEVICE_ID_JOYPAD_A;
          else if (!strcmp(var.value, "C2"))
             l_cbutton = RETRO_DEVICE_ID_JOYPAD_Y;
          else if (!strcmp(var.value, "C3"))
             l_cbutton = RETRO_DEVICE_ID_JOYPAD_B;
          else if (!strcmp(var.value, "C4"))
             l_cbutton = RETRO_DEVICE_ID_JOYPAD_X;
       }

       var.key = CORE_NAME "-d-cbutton";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "C1"))
             d_cbutton = RETRO_DEVICE_ID_JOYPAD_A;
          else if (!strcmp(var.value, "C2"))
             d_cbutton = RETRO_DEVICE_ID_JOYPAD_Y;
          else if (!strcmp(var.value, "C3"))
             d_cbutton = RETRO_DEVICE_ID_JOYPAD_B;
          else if (!strcmp(var.value, "C4"))
             d_cbutton = RETRO_DEVICE_ID_JOYPAD_X;
       }

       var.key = CORE_NAME "-u-cbutton";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "C1"))
             u_cbutton = RETRO_DEVICE_ID_JOYPAD_A;
          else if (!strcmp(var.value, "C2"))
             u_cbutton = RETRO_DEVICE_ID_JOYPAD_Y;
          else if (!strcmp(var.value, "C3"))
             u_cbutton = RETRO_DEVICE_ID_JOYPAD_B;
          else if (!strcmp(var.value, "C4"))
             u_cbutton = RETRO_DEVICE_ID_JOYPAD_X;
       }

       var.key = CORE_NAME "-EnableOverscan";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          EnableOverscan = !strcmp(var.value, "Enabled") ? 1 : 0;
       }

       var.key = CORE_NAME "-OverscanTop";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          OverscanTop = atoi(var.value);
       }

       var.key = CORE_NAME "-OverscanLeft";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          OverscanLeft = atoi(var.value);
       }

       var.key = CORE_NAME "-OverscanRight";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          OverscanRight = atoi(var.value);
       }

       var.key = CORE_NAME "-OverscanBottom";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          OverscanBottom = atoi(var.value);
       }

       var.key = CORE_NAME "-alt-map";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          alternate_mapping = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-ForceDisableExtraMem";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          ForceDisableExtraMem = !strcmp(var.value, "False") ? 0 : 1;
       }

       var.key = CORE_NAME "-IgnoreTLBExceptions";
       var.value = NULL;
       if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
       {
          if (!strcmp(var.value, "False"))
             IgnoreTLBExceptions = 0;
          else if (!strcmp(var.value, "OnlyNotEnabled"))
             IgnoreTLBExceptions = 1;
          else if (!strcmp(var.value, "AlwaysIgnoreTLB"))
             IgnoreTLBExceptions = 2;
       }
    }

#ifdef HAVE_PARALLEL_RDP
    if (current_rdp_type == RDP_PLUGIN_PARALLEL)
    {
        var.key = CORE_NAME "-parallel-rdp-synchronous";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_synchronous_rdp(!strcmp(var.value, "True"));
        else
            parallel_set_synchronous_rdp(true);

        var.key = CORE_NAME "-parallel-rdp-overscan";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_overscan_crop(strtol(var.value, NULL, 0));
        else
            parallel_set_overscan_crop(0);

        var.key = CORE_NAME "-parallel-rdp-divot-filter";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_divot_filter(!strcmp(var.value, "True"));
        else
            parallel_set_divot_filter(true);

        var.key = CORE_NAME "-parallel-rdp-gamma-dither";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_gamma_dither(!strcmp(var.value, "True"));
        else
            parallel_set_gamma_dither(true);

        var.key = CORE_NAME "-parallel-rdp-vi-aa";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_vi_aa(!strcmp(var.value, "True"));
        else
            parallel_set_vi_aa(true);

        var.key = CORE_NAME "-parallel-rdp-vi-bilinear";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_vi_scale(!strcmp(var.value, "True"));
        else
            parallel_set_vi_scale(true);

        var.key = CORE_NAME "-parallel-rdp-dither-filter";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_dither_filter(!strcmp(var.value, "True"));
        else
            parallel_set_dither_filter(true);

        {
            unsigned upscaling;
            bool super_sampled;
            var.key = CORE_NAME "-parallel-rdp-upscaling";
            var.value = NULL;
            if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
                upscaling = strtol(var.value, NULL, 0);
            else
                upscaling = 1;

            var.key = CORE_NAME "-parallel-rdp-super-sampled-read-back";
            var.value = NULL;
            if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
                super_sampled = !strcmp(var.value, "True");
            else
                super_sampled = false;

            parallel_set_upscaling(upscaling, super_sampled);
        }

        var.key = CORE_NAME "-parallel-rdp-super-sampled-read-back-dither";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_super_sampled_read_back_dither(!strcmp(var.value, "True"));
        else
            parallel_set_super_sampled_read_back_dither(true);

        var.key = CORE_NAME "-parallel-rdp-downscaling";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
        {
            if (!strcmp(var.value, "disable"))
                parallel_set_downscaling_steps(0);
            else if (!strcmp(var.value, "1/2"))
                parallel_set_downscaling_steps(1);
            else if (!strcmp(var.value, "1/4"))
                parallel_set_downscaling_steps(2);
            else if (!strcmp(var.value, "1/8"))
                parallel_set_downscaling_steps(3);
        }
        else
            parallel_set_downscaling_steps(0);

        var.key = CORE_NAME "-parallel-rdp-native-texture-lod";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_native_texture_lod(!strcmp(var.value, "True"));
        else
            parallel_set_native_texture_lod(false);

        var.key = CORE_NAME "-parallel-rdp-native-tex-rect";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_native_tex_rect(!strcmp(var.value, "True"));
        else
            parallel_set_native_tex_rect(true);

        var.key = CORE_NAME "-parallel-rdp-deinterlace-method";
        var.value = NULL;
        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
            parallel_set_interlacing(!strcmp(var.value, "Weave"));
        else
            parallel_set_interlacing(false);
    }
#endif

#ifdef HAVE_THR_AL
    if (current_rdp_type == RDP_PLUGIN_ANGRYLION)
    {
        var.key = CORE_NAME "-angrylion-vioverlay";
        var.value = NULL;

        environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

        if (var.value)
        {
           if (!strcmp(var.value, "Filtered"))
           {
              angrylion_set_vi(0);
              angrylion_set_vi_dedither(1);
              angrylion_set_vi_blur(1);
           }
           else if (!strcmp(var.value, "AA+Blur"))
           {
              angrylion_set_vi(0);
              angrylion_set_vi_dedither(0);
              angrylion_set_vi_blur(1);
           }
           else if (!strcmp(var.value, "AA+Dedither"))
           {
              angrylion_set_vi(0);
              angrylion_set_vi_dedither(1);
              angrylion_set_vi_blur(0);
           }
           else if (!strcmp(var.value, "AA only"))
           {
              angrylion_set_vi(0);
              angrylion_set_vi_dedither(0);
              angrylion_set_vi_blur(0);
           }
           else if (!strcmp(var.value, "Unfiltered"))
           {
              angrylion_set_vi(1);
              angrylion_set_vi_dedither(1);
              angrylion_set_vi_blur(1);
           }
           else if (!strcmp(var.value, "Depth"))
           {
              angrylion_set_vi(2);
              angrylion_set_vi_dedither(1);
              angrylion_set_vi_blur(1);
           }
           else if (!strcmp(var.value, "Coverage"))
           {
              angrylion_set_vi(3);
              angrylion_set_vi_dedither(1);
              angrylion_set_vi_blur(1);
           }
        }
        else
        {
           angrylion_set_vi(0);
           angrylion_set_vi_dedither(1);
           angrylion_set_vi_blur(1);
        }

        var.key = CORE_NAME "-angrylion-sync";
        var.value = NULL;

        environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

        if (var.value)
        {
           if (!strcmp(var.value, "High"))
              angrylion_set_synclevel(2);
           else if (!strcmp(var.value, "Medium"))
              angrylion_set_synclevel(1);
           else if (!strcmp(var.value, "Low"))
              angrylion_set_synclevel(0);
        }
        else
           angrylion_set_synclevel(0);

        var.key = CORE_NAME "-angrylion-multithread";
        var.value = NULL;

        if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
        {
           if (!strcmp(var.value, "all threads"))
              angrylion_set_threads(0);
           else
              angrylion_set_threads(atoi(var.value));
        }
        else
           angrylion_set_threads(0);

        var.key = CORE_NAME "-angrylion-overscan";
        var.value = NULL;

        environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);

        if (var.value)
        {
           if (!strcmp(var.value, "enabled"))
              angrylion_set_overscan(1);
           else if (!strcmp(var.value, "disabled"))
              angrylion_set_overscan(0);
        }
        else
        {
           angrylion_set_overscan(0);
        }
    }
#endif // HAVE_THR_AL

    update_controllers();

    // Hide irrelevant options
    set_variable_visibility();
}

static void format_saved_memory(void)
{
    format_sram(saved_memory.sram);
    format_eeprom(saved_memory.eeprom, EEPROM_MAX_SIZE);
    format_flashram(saved_memory.flashram);
    format_mempak(saved_memory.mempack + 0 * MEMPAK_SIZE);
    format_mempak(saved_memory.mempack + 1 * MEMPAK_SIZE);
    format_mempak(saved_memory.mempack + 2 * MEMPAK_SIZE);
    format_mempak(saved_memory.mempack + 3 * MEMPAK_SIZE);
}

void context_reset(void)
{
    static bool first_init = true;

    if(current_rdp_type == RDP_PLUGIN_GLIDEN64)
    {
       log_cb(RETRO_LOG_DEBUG, CORE_NAME ": context_reset()\n");
       glsm_ctl(GLSM_CTL_STATE_CONTEXT_RESET, NULL);
       if (first_init)
       {
          glsm_ctl(GLSM_CTL_STATE_SETUP, NULL);
          first_init = false;
       }
    }

    reinit_gfx_plugin();
}

static void context_destroy(void)
{
    if(current_rdp_type == RDP_PLUGIN_GLIDEN64)
    {
       glsm_ctl(GLSM_CTL_STATE_CONTEXT_DESTROY, NULL);
    }
#ifdef HAVE_PARALLEL_RDP
    if (current_rdp_type == RDP_PLUGIN_PARALLEL)
        parallel_deinit();
#endif
}

static bool context_framebuffer_lock(void *data)
{
    //if (!stop)
     //   return false;
    return true;
}

static bool retro_init_vulkan(void)
{
#if defined(HAVE_PARALLEL_RDP)
   hw_render.context_type    = RETRO_HW_CONTEXT_VULKAN;
   hw_render.version_major   = VK_MAKE_VERSION(1, 1, 0);
   hw_render.context_reset   = context_reset;
   hw_render.context_destroy = context_destroy;

   if (!environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render))
   {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "mupen64plus: libretro frontend doesn't have Vulkan support.\n");
      return false;
   }

   hw_context_negotiation.interface_type = RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN;
   hw_context_negotiation.interface_version = RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN_VERSION;
   hw_context_negotiation.get_application_info = parallel_get_application_info;
   hw_context_negotiation.create_device = parallel_create_device;
   hw_context_negotiation.destroy_device = NULL;
   if (!environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE, &hw_context_negotiation))
   {
      if (log_cb)
         log_cb(RETRO_LOG_ERROR, "mupen64plus: libretro frontend doesn't have context negotiation support.\n");
   }

   return true;
#else
   return false;
#endif
}

bool retro_load_game(const struct retro_game_info *game)
{
    char* gamePath;
    char* newPath;

    // Workaround for broken subsystem on static platforms
    // Note: game->path can be NULL if loading from a archive
    // Current impl. uses mupen internals so that wouldn't work either way for dd/tpak
    // So we just sanity check
    if(!retro_dd_path_img && game->path)
    {
        gamePath = (char*)game->path;
        newPath = (char*)calloc(1, strlen(gamePath)+5);
        strcpy(newPath, gamePath);
        strcat(newPath, ".ndd");
        FILE* fileTest = fopen(newPath, "r");
        if(!fileTest)
        {
            free(newPath);
        } else {
            fclose(fileTest);
            // Free'd later in Mupen Core
            retro_dd_path_img = newPath;
        }
    }
    
    if (!retro_transferpak_rom_path && game->path)
    {
       gamePath = (char *)game->path;
       newPath = (char *)calloc(1, strlen(gamePath) + 4);
       strcpy(newPath, gamePath);
       strcat(newPath, ".gb");
       FILE *fileTest = fopen(newPath, "r");
       if (!fileTest)
       {
          free(newPath);
       }
       else
       {
          fclose(fileTest);
          // Free'd later in Mupen Core
          retro_transferpak_rom_path = newPath;
 
          // We have a gb rom!
          if (!retro_transferpak_ram_path)
          {
             gamePath = (char *)game->path;
             newPath = (char *)calloc(1, strlen(gamePath) + 5);
             strcpy(newPath, gamePath);
             strcat(newPath, ".sav");
             FILE *fileTest = fopen(newPath, "r");
             if (!fileTest)
             {
                free(newPath);
             }
             else
             {
                fclose(fileTest);
                // Free'd later in Mupen Core
                retro_transferpak_ram_path = newPath;
             }
          }
       }
    }
 
    // Init default vals
    retro_savestate_complete = true;
    load_game_successful = false;

    glsm_ctx_params_t params = {0};
    format_saved_memory();

    update_variables(true);

    if(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer)
    {
       initializing = true;
       retro_thread = co_active();
       game_thread = co_create(65536 * sizeof(void*) * 16, gln64_thr_gl_invoke_command_loop);
    }

    init_audio_libretro(audio_buffer_size);

    params.context_reset         = context_reset;
    params.context_destroy       = context_destroy;
    params.environ_cb            = environ_cb;
    params.stencil               = false;

    params.framebuffer_lock      = context_framebuffer_lock;
    if (current_rdp_type == RDP_PLUGIN_GLIDEN64 && !glsm_ctl(GLSM_CTL_STATE_CONTEXT_INIT, &params))
    {
        if (log_cb)
            log_cb(RETRO_LOG_ERROR, CORE_NAME ": libretro frontend doesn't have OpenGL support\n");
        return false;
    }

#ifdef HAVE_PARALLEL_RDP
    if (current_rdp_type == RDP_PLUGIN_PARALLEL)
    {
        if (!retro_init_vulkan())
            return false;
    }
#endif

    game_data = malloc(game->size);
    memcpy(game_data, game->data, game->size);
    game_size = game->size;

    emu_step_load_data();

    if(current_rdp_type == RDP_PLUGIN_GLIDEN64 || current_rdp_type == RDP_PLUGIN_PARALLEL)
    {
       first_context_reset = true;
    }
    else
    {
       // Prevents later emu_step_initialize call
       first_context_reset = false;
       emu_step_initialize();
       /* Additional check for vioverlay not set at start */
       update_variables(false);
    }
    
    load_game_successful = true;

    return true;
}

void retro_unload_game(void)
{
    if(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer)
    {
       environ_clear_thread_waits_cb(1, NULL);
    }

    CoreDoCommand(M64CMD_ROM_CLOSE, 0, NULL);
    if(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer)
    {
       CoreDoCommand(M64CMD_STOP, 0, NULL);

       // Run one more frame to unlock it
       glsm_ctl(GLSM_CTL_STATE_BIND, NULL);
       while(!threaded_gl_safe_shutdown)
       {
          co_switch(game_thread);
       }
       glsm_ctl(GLSM_CTL_STATE_UNBIND, NULL);
    
       pthread_join(emuThread, NULL);

       environ_clear_thread_waits_cb(0, NULL);
    }
    cleanup_global_paths();
    
    emu_initialized = false;

    // Reset savestate job var
    retro_savestate_complete = false;
}

void retro_run (void)
{
    libretro_swap_buffer = false;
    static bool updated = false;

    if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated) {
       update_variables(false);
       update_controllers();
    }

    if(current_rdp_type == RDP_PLUGIN_GLIDEN64)
    {
       if(EnableThreadedRenderer)
       {
          if(!emuThreadRunning)
          {
             pthread_create(&emuThread, NULL, &EmuThreadFunction, NULL);
             emuThreadRunning = true;
          }
       }
       
       glsm_ctl(GLSM_CTL_STATE_BIND, NULL);
    }

    co_switch(game_thread);

    if(current_rdp_type == RDP_PLUGIN_GLIDEN64)
    {
       glsm_ctl(GLSM_CTL_STATE_UNBIND, NULL);
    }
    
    if (libretro_swap_buffer)
    {
       if(current_rdp_type == RDP_PLUGIN_GLIDEN64)
       {
          video_cb(RETRO_HW_FRAME_BUFFER_VALID, retro_screen_width, retro_screen_height, 0);
       }
#ifdef HAVE_THR_AL
       else if(current_rdp_type == RDP_PLUGIN_ANGRYLION)
       {
          video_cb(prescale, retro_screen_width, retro_screen_height, screen_pitch);
       }
#endif // HAVE_THR_AL
#ifdef HAVE_PARALLEL_RDP
       else if (current_rdp_type == RDP_PLUGIN_PARALLEL)
       {
           parallel_profile_video_refresh_begin();
           video_cb(parallel_frame_is_valid() ? RETRO_HW_FRAME_BUFFER_VALID : NULL,
                   parallel_frame_width(), parallel_frame_height(), 0);
           parallel_profile_video_refresh_end();
       }
#endif
    }
    else if(EnableFrameDuping)
    {
        // screen_pitch will be 0 for GLN
        video_cb(NULL, retro_screen_width, retro_screen_height, screen_pitch);
    }
}

void retro_reset (void)
{
    CoreDoCommand(M64CMD_RESET, 0, (void*)0);
}

void *retro_get_memory_data(unsigned type)
{
    switch (type)
    {
        case RETRO_MEMORY_SYSTEM_RAM: return g_dev.rdram.dram;
        case RETRO_MEMORY_TRANSFERPAK:
        case RETRO_MEMORY_DD:
        case RETRO_MEMORY_SAVE_RAM:   return &saved_memory;
    }
    return NULL;
}

size_t retro_get_memory_size(unsigned type)
{
    switch (type)
    {
        case RETRO_MEMORY_SYSTEM_RAM:  return RDRAM_MAX_SIZE;
        case RETRO_MEMORY_TRANSFERPAK:
        case RETRO_MEMORY_DD:
        case RETRO_MEMORY_SAVE_RAM:    return sizeof(saved_memory);
    }

    return 0;
}

size_t retro_serialize_size (void)
{
    return 16788288 + 1024 + 4 + 4096;
}

bool retro_serialize(void *data, size_t size)
{
   if (initializing)
      return false;

   retro_savestate_complete = false;
   retro_savestate_result = 0;

   savestates_set_job(savestates_job_save, savestates_type_m64p, data);

   if (current_rdp_type == RDP_PLUGIN_GLIDEN64)
   {
      if(EnableThreadedRenderer)
      {
         // Ensure the Audio driver is on (f.e. menu sounds off)
         environ_clear_thread_waits_cb(1, NULL);
      }
      glsm_ctl(GLSM_CTL_STATE_BIND, NULL);
   }

   while (!retro_savestate_complete)
   {
      co_switch(game_thread);
   }

   if (current_rdp_type == RDP_PLUGIN_GLIDEN64)
   {
      glsm_ctl(GLSM_CTL_STATE_UNBIND, NULL);
   }

   return !!retro_savestate_result;
}

bool retro_unserialize(const void *data, size_t size)
{
   if (initializing)
      return false;

   retro_savestate_complete = false;
   retro_savestate_result = 0;

   savestates_set_job(savestates_job_load, savestates_type_m64p, data);

   if (current_rdp_type == RDP_PLUGIN_GLIDEN64)
   {
      if(EnableThreadedRenderer)
      {
         // Ensure the Audio driver is on (f.e. menu sounds off)
         environ_clear_thread_waits_cb(1, NULL);
      }
      glsm_ctl(GLSM_CTL_STATE_BIND, NULL);
   }

   while (!retro_savestate_complete)
   {
      co_switch(game_thread);
   }

   if (current_rdp_type == RDP_PLUGIN_GLIDEN64)
   {
      glsm_ctl(GLSM_CTL_STATE_UNBIND, NULL);
   }

   return true;
}

//Needed to be able to detach controllers for Lylat Wars multiplayer
//Only sets if controller struct is initialised as addon paks do.
void retro_set_controller_port_device(unsigned in_port, unsigned device) {
    if (in_port < 4){
        switch(device)
        {
            case RETRO_DEVICE_NONE:
               if (controller[in_port].control){
                   controller[in_port].control->Present = 0;
                   break;
               } else {
                   pad_present[in_port] = 0;
                   break;
               }

            case RETRO_DEVICE_JOYPAD:
            default:
               if (controller[in_port].control){
                   controller[in_port].control->Present = 1;
                   break;
               } else {
                   pad_present[in_port] = 1;
                   break;
               }
        }
    }
}

unsigned retro_api_version(void) { return RETRO_API_VERSION; }

void retro_cheat_reset(void)
{
    cheat_delete_all(&g_cheat_ctx);
}

void retro_cheat_set(unsigned index, bool enabled, const char* codeLine)
{
    char name[256];
    m64p_cheat_code mupenCode[256];
    int matchLength=0,partCount=0;
    uint32_t codeParts[256];
    int cursor;

    //Generate a name
    sprintf(name, "cheat_%u",index);

    //Break the code into Parts
    for (cursor=0;;cursor++)
    {
        if (ISHEXDEC){
            matchLength++;
        } else {
            if (matchLength){
               char codePartS[matchLength];
               strncpy(codePartS,codeLine+cursor-matchLength,matchLength);
               codePartS[matchLength]=0;
               codeParts[partCount++]=strtoul(codePartS,NULL,16);
               matchLength=0;
            }
        }
        if (!codeLine[cursor]){
            break;
        }
    }

    //Assign the parts to mupenCode
    for (cursor=0;2*cursor+1<partCount;cursor++){
        mupenCode[cursor].address=codeParts[2*cursor];
        mupenCode[cursor].value=codeParts[2*cursor+1];
    }

    //Assign to mupenCode
    cheat_add_new(&g_cheat_ctx, name, mupenCode, partCount / 2);
    cheat_set_enabled(&g_cheat_ctx, name, enabled);
}

void retro_return(void)
{
    if(!(current_rdp_type == RDP_PLUGIN_GLIDEN64 && EnableThreadedRenderer))
    {
       co_switch(retro_thread);
    }
}

uint32_t get_retro_screen_width()
{
    return retro_screen_width;
}

uint32_t get_retro_screen_height()
{
    return retro_screen_height;
}

static int GamesharkActive = 0;

int event_gameshark_active(void)
{
    return GamesharkActive;
}

void event_set_gameshark(int active)
{
    // if boolean value doesn't change then just return
    if (!active == !GamesharkActive)
        return;

    // set the button state
    GamesharkActive = (active ? 1 : 0);

    // notify front-end application that gameshark button state has changed
    StateChanged(M64CORE_INPUT_GAMESHARK, GamesharkActive);
}
