/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - main.c                                                  *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2012 CasualJames                                        *
 *   Copyright (C) 2008-2009 Richard Goedeken                              *
 *   Copyright (C) 2008 Ebenblues Nmn Okaygo Tillin9                       *
 *   Copyright (C) 2002 Hacktarux                                          *
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

/* This is MUPEN64's main entry point. It contains code that is common
 * to both the gui and non-gui versions of mupen64. See
 * gui subdirectories for the gui-specific code.
 * if you want to implement an interface, you should look here
 */

#include <SDL.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define M64P_CORE_PROTOTYPES 1
#include "ai/ai_controller.h"
#include "api/callbacks.h"
#include "api/config.h"
#include "api/debugger.h"
#include "api/m64p_config.h"
#include "api/m64p_types.h"
#include "api/m64p_vidext.h"
#include "api/vidext.h"
#include "cheat.h"
#include "eep_file.h"
#include "eventloop.h"
#include "fla_file.h"
#include "main.h"
#include "memory/memory.h"
#include "mpk_file.h"
#include "osal/files.h"
#include "osal/preproc.h"
#include "osd/osd.h"
#include "osd/screenshot.h"
#include "pi/pi_controller.h"
#include "plugin/emulate_game_controller_via_input_plugin.h"
#include "plugin/emulate_speaker_via_audio_plugin.h"
#include "plugin/get_time_using_C_localtime.h"
#include "plugin/plugin.h"
#include "plugin/rumble_via_input_plugin.h"
#include "profile.h"
#include "r4300/r4300.h"
#include "r4300/r4300_core.h"
#include "r4300/reset.h"
#include "rdp/rdp_core.h"
#include "ri/ri_controller.h"
#include "rom.h"
#include "rsp/rsp_core.h"
#include "savestates.h"
#include "si/si_controller.h"
#include "sra_file.h"
#include "util.h"
#include "vi/vi_controller.h"

#ifdef DBG
#include "debugger/dbg_debugger.h"
#include "debugger/dbg_types.h"
#endif

#ifdef WITH_LIRC
#include "lirc.h"
#endif //WITH_LIRC

/* version number for Core config section */
#define CONFIG_PARAM_VERSION 1.01

/** globals **/
m64p_handle g_CoreConfig = NULL;

m64p_frame_callback g_FrameCallback = NULL;

int         g_MemHasBeenBSwapped = 0;   // store byte-swapped flag so we don't swap twice when re-playing game
int         g_EmulatorRunning = 0;      // need separate boolean to tell if emulator is running, since --nogui doesn't use a thread

ALIGN(16, uint32_t g_rdram[RDRAM_MAX_SIZE/4]);
struct ai_controller g_ai;
struct pi_controller g_pi;
struct ri_controller g_ri;
struct si_controller g_si;
struct vi_controller g_vi;
struct r4300_core g_r4300;
struct rdp_core g_dp;
struct rsp_core g_sp;

int g_delay_si = 0;

int g_gs_vi_counter = 0;

/** static (local) variables **/
static int   l_CurrentFrame = 0;         // frame counter
static int   l_TakeScreenshot = 0;       // Tell OSD Rendering callback to take a screenshot just before drawing the OSD
static int   l_SpeedFactor = 100;        // percentage of nominal game speed at which emulator is running
static int   l_FrameAdvance = 0;         // variable to check if we pause on next frame
static int   l_MainSpeedLimit = 1;       // insert delay during vi_interrupt to keep speed at real-time

static osd_message_t *l_msgVol = NULL;
static osd_message_t *l_msgFF = NULL;
static osd_message_t *l_msgPause = NULL;

/*********************************************************************************************************
* static functions
*/

static const char *get_savepathdefault(const char *configpath)
{
    static char path[1024];

    if (!configpath || (strlen(configpath) == 0)) {
        snprintf(path, 1024, "%ssave%c", ConfigGetUserDataPath(), OSAL_DIR_SEPARATORS[0]);
        path[1023] = 0;
    } else {
        snprintf(path, 1024, "%s%c", configpath, OSAL_DIR_SEPARATORS[0]);
        path[1023] = 0;
    }

    /* create directory if it doesn't exist */
    osal_mkdirp(path, 0700);

    return path;
}

static char *get_mempaks_path(void)
{
    return formatstr("%s%s.mpk", get_savesrampath(), ROM_SETTINGS.goodname);
}

static char *get_eeprom_path(void)
{
    return formatstr("%s%s.eep", get_savesrampath(), ROM_SETTINGS.goodname);
}

static char *get_sram_path(void)
{
    return formatstr("%s%s.sra", get_savesrampath(), ROM_SETTINGS.goodname);
}

static char *get_flashram_path(void)
{
    return formatstr("%s%s.fla", get_savesrampath(), ROM_SETTINGS.goodname);
}


/*********************************************************************************************************
* helper functions
*/


const char *get_savestatepath(void)
{
    /* try to get the SaveStatePath string variable in the Core configuration section */
    return get_savepathdefault(ConfigGetParamString(g_CoreConfig, "SaveStatePath"));
}

const char *get_savesrampath(void)
{
    /* try to get the SaveSRAMPath string variable in the Core configuration section */
    return get_savepathdefault(ConfigGetParamString(g_CoreConfig, "SaveSRAMPath"));
}

void main_message(m64p_msg_level level, unsigned int corner, const char *format, ...)
{
    va_list ap;
    char buffer[2049];
    va_start(ap, format);
    vsnprintf(buffer, 2047, format, ap);
    buffer[2048]='\0';
    va_end(ap);

    /* send message to on-screen-display if enabled */
    if (ConfigGetParamBool(g_CoreConfig, "OnScreenDisplay"))
        osd_new_message((enum osd_corner) corner, "%s", buffer);
    /* send message to front-end */
    DebugMessage(level, "%s", buffer);
}

void main_check_inputs(void)
{
#ifdef WITH_LIRC
    lircCheckInput();
#endif
    SDL_PumpEvents();
}

/*********************************************************************************************************
* global functions, for adjusting the core emulator behavior
*/

int main_set_core_defaults(void)
{
    float fConfigParamsVersion;
    int bSaveConfig = 0, bUpgrade = 0;

    if (ConfigGetParameter(g_CoreConfig, "Version", M64TYPE_FLOAT, &fConfigParamsVersion, sizeof(float)) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_WARNING, "No version number in 'Core' config section. Setting defaults.");
        ConfigDeleteSection("Core");
        ConfigOpenSection("Core", &g_CoreConfig);
        bSaveConfig = 1;
    }
    else if (((int) fConfigParamsVersion) != ((int) CONFIG_PARAM_VERSION))
    {
        DebugMessage(M64MSG_WARNING, "Incompatible version %.2f in 'Core' config section: current is %.2f. Setting defaults.", fConfigParamsVersion, (float) CONFIG_PARAM_VERSION);
        ConfigDeleteSection("Core");
        ConfigOpenSection("Core", &g_CoreConfig);
        bSaveConfig = 1;
    }
    else if ((CONFIG_PARAM_VERSION - fConfigParamsVersion) >= 0.0001f)
    {
        float fVersion = (float) CONFIG_PARAM_VERSION;
        ConfigSetParameter(g_CoreConfig, "Version", M64TYPE_FLOAT, &fVersion);
        DebugMessage(M64MSG_INFO, "Updating parameter set version in 'Core' config section to %.2f", fVersion);
        bUpgrade = 1;
        bSaveConfig = 1;
    }

    /* parameters controlling the operation of the core */
    ConfigSetDefaultFloat(g_CoreConfig, "Version", (float) CONFIG_PARAM_VERSION,  "Mupen64Plus Core config parameter set version number.  Please don't change this version number.");
    ConfigSetDefaultBool(g_CoreConfig, "OnScreenDisplay", 1, "Draw on-screen display if True, otherwise don't draw OSD");
#if defined(DYNAREC)
    ConfigSetDefaultInt(g_CoreConfig, "R4300Emulator", 2, "Use Pure Interpreter if 0, Cached Interpreter if 1, or Dynamic Recompiler if 2 or more");
#else
    ConfigSetDefaultInt(g_CoreConfig, "R4300Emulator", 1, "Use Pure Interpreter if 0, Cached Interpreter if 1, or Dynamic Recompiler if 2 or more");
#endif
    ConfigSetDefaultBool(g_CoreConfig, "NoCompiledJump", 0, "Disable compiled jump commands in dynamic recompiler (should be set to False) ");
    ConfigSetDefaultBool(g_CoreConfig, "DisableExtraMem", 0, "Disable 4MB expansion RAM pack. May be necessary for some games");
    ConfigSetDefaultBool(g_CoreConfig, "AutoStateSlotIncrement", 0, "Increment the save state slot after each save operation");
    ConfigSetDefaultBool(g_CoreConfig, "EnableDebugger", 0, "Activate the R4300 debugger when ROM execution begins, if core was built with Debugger support");
    ConfigSetDefaultInt(g_CoreConfig, "CurrentStateSlot", 0, "Save state slot (0-9) to use when saving/loading the emulator state");
    ConfigSetDefaultString(g_CoreConfig, "ScreenshotPath", "", "Path to directory where screenshots are saved. If this is blank, the default value of ${UserConfigPath}/screenshot will be used");
    ConfigSetDefaultString(g_CoreConfig, "SaveStatePath", "", "Path to directory where emulator save states (snapshots) are saved. If this is blank, the default value of ${UserConfigPath}/save will be used");
    ConfigSetDefaultString(g_CoreConfig, "SaveSRAMPath", "", "Path to directory where SRAM/EEPROM data (in-game saves) are stored. If this is blank, the default value of ${UserConfigPath}/save will be used");
    ConfigSetDefaultString(g_CoreConfig, "SharedDataPath", "", "Path to a directory to search when looking for shared data files");
    ConfigSetDefaultBool(g_CoreConfig, "DelaySI", 1, "Delay interrupt after DMA SI read/write");
    ConfigSetDefaultInt(g_CoreConfig, "CountPerOp", 0, "Force number of cycles per emulated instruction");

    /* handle upgrades */
    if (bUpgrade)
    {
        if (fConfigParamsVersion < 1.01f)
        {  // added separate SaveSRAMPath parameter in v1.01
            const char *pccSaveStatePath = ConfigGetParamString(g_CoreConfig, "SaveStatePath");
            if (pccSaveStatePath != NULL)
                ConfigSetParameter(g_CoreConfig, "SaveSRAMPath", M64TYPE_STRING, pccSaveStatePath);
        }
    }

    if (bSaveConfig)
        ConfigSaveSection("Core");

    /* set config parameters for keyboard and joystick commands */
    return event_set_core_defaults();
}

void main_speeddown(int percent)
{
    if (l_SpeedFactor - percent > 10)  /* 10% minimum speed */
    {
        l_SpeedFactor -= percent;
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "%s %d%%", "Playback speed:", l_SpeedFactor);
        audio.setSpeedFactor(l_SpeedFactor);
        StateChanged(M64CORE_SPEED_FACTOR, l_SpeedFactor);
    }
}

void main_speedup(int percent)
{
    if (l_SpeedFactor + percent < 300) /* 300% maximum speed */
    {
        l_SpeedFactor += percent;
        main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "%s %d%%", "Playback speed:", l_SpeedFactor);
        audio.setSpeedFactor(l_SpeedFactor);
        StateChanged(M64CORE_SPEED_FACTOR, l_SpeedFactor);
    }
}

static void main_speedset(int percent)
{
    if (percent < 1 || percent > 1000)
    {
        DebugMessage(M64MSG_WARNING, "Invalid speed setting %i percent", percent);
        return;
    }
    // disable fast-forward if it's enabled
    main_set_fastforward(0);
    // set speed
    l_SpeedFactor = percent;
    main_message(M64MSG_STATUS, OSD_BOTTOM_LEFT, "%s %d%%", "Playback speed:", l_SpeedFactor);
    audio.setSpeedFactor(l_SpeedFactor);
    StateChanged(M64CORE_SPEED_FACTOR, l_SpeedFactor);
}

void main_set_fastforward(int enable)
{
    static int ff_state = 0;
    static int SavedSpeedFactor = 100;

    if (enable && !ff_state)
    {
        ff_state = 1; /* activate fast-forward */
        SavedSpeedFactor = l_SpeedFactor;
        l_SpeedFactor = 250;
        audio.setSpeedFactor(l_SpeedFactor);
        StateChanged(M64CORE_SPEED_FACTOR, l_SpeedFactor);
        // set fast-forward indicator
        l_msgFF = osd_new_message(OSD_TOP_RIGHT, "Fast Forward");
        osd_message_set_static(l_msgFF);
        osd_message_set_user_managed(l_msgFF);
    }
    else if (!enable && ff_state)
    {
        ff_state = 0; /* de-activate fast-forward */
        l_SpeedFactor = SavedSpeedFactor;
        audio.setSpeedFactor(l_SpeedFactor);
        StateChanged(M64CORE_SPEED_FACTOR, l_SpeedFactor);
        // remove message
        osd_delete_message(l_msgFF);
        l_msgFF = NULL;
    }

}

static void main_set_speedlimiter(int enable)
{
    l_MainSpeedLimit = enable ? 1 : 0;
}

static int main_is_paused(void)
{
    return (g_EmulatorRunning && rompause);
}

void main_toggle_pause(void)
{
    if (!g_EmulatorRunning)
        return;

    if (rompause)
    {
        DebugMessage(M64MSG_STATUS, "Emulation continued.");
        if(l_msgPause)
        {
            osd_delete_message(l_msgPause);
            l_msgPause = NULL;
        }
        StateChanged(M64CORE_EMU_STATE, M64EMU_RUNNING);
    }
    else
    {
        if(l_msgPause)
            osd_delete_message(l_msgPause);

        DebugMessage(M64MSG_STATUS, "Emulation paused.");
        l_msgPause = osd_new_message(OSD_MIDDLE_CENTER, "Paused");
        osd_message_set_static(l_msgPause);
        osd_message_set_user_managed(l_msgPause);
        StateChanged(M64CORE_EMU_STATE, M64EMU_PAUSED);
    }

    rompause = !rompause;
    l_FrameAdvance = 0;
}

void main_advance_one(void)
{
    l_FrameAdvance = 1;
    rompause = 0;
    StateChanged(M64CORE_EMU_STATE, M64EMU_RUNNING);
}

static void main_draw_volume_osd(void)
{
    char msgString[64];
    const char *volString;

    // this calls into the audio plugin
    volString = audio.volumeGetString();
    if (volString == NULL)
    {
        strcpy(msgString, "Volume Not Supported.");
    }
    else
    {
        sprintf(msgString, "%s: %s", "Volume", volString);
    }

    // create a new message or update an existing one
    if (l_msgVol != NULL)
        osd_update_message(l_msgVol, "%s", msgString);
    else {
        l_msgVol = osd_new_message(OSD_MIDDLE_CENTER, "%s", msgString);
        osd_message_set_user_managed(l_msgVol);
    }
}

/* this function could be called as a result of a keypress, joystick/button movement,
   LIRC command, or 'testshots' command-line option timer */
void main_take_next_screenshot(void)
{
    l_TakeScreenshot = l_CurrentFrame + 1;
}

void main_state_set_slot(int slot)
{
    if (slot < 0 || slot > 9)
    {
        DebugMessage(M64MSG_WARNING, "Invalid savestate slot '%i' in main_state_set_slot().  Using 0", slot);
        slot = 0;
    }

    savestates_select_slot(slot);
    StateChanged(M64CORE_SAVESTATE_SLOT, slot);
}

void main_state_inc_slot(void)
{
    savestates_inc_slot();
}

void main_state_load(const char *filename)
{
    rumblepak_rumble(&g_si.pif.controllers[0].rumblepak, RUMBLE_STOP);
    rumblepak_rumble(&g_si.pif.controllers[1].rumblepak, RUMBLE_STOP);
    rumblepak_rumble(&g_si.pif.controllers[2].rumblepak, RUMBLE_STOP);
    rumblepak_rumble(&g_si.pif.controllers[3].rumblepak, RUMBLE_STOP);

    if (filename == NULL) // Save to slot
        savestates_set_job(savestates_job_load, savestates_type_m64p, NULL);
    else
        savestates_set_job(savestates_job_load, savestates_type_unknown, filename);
}

void main_state_save(int format, const char *filename)
{
    if (filename == NULL) // Save to slot
        savestates_set_job(savestates_job_save, savestates_type_m64p, NULL);
    else // Save to file
        savestates_set_job(savestates_job_save, (savestates_type)format, filename);
}

m64p_error main_core_state_query(m64p_core_param param, int *rval)
{
    switch (param)
    {
        case M64CORE_EMU_STATE:
            if (!g_EmulatorRunning)
                *rval = M64EMU_STOPPED;
            else if (rompause)
                *rval = M64EMU_PAUSED;
            else
                *rval = M64EMU_RUNNING;
            break;
        case M64CORE_VIDEO_MODE:
            if (!VidExt_VideoRunning())
                *rval = M64VIDEO_NONE;
            else if (VidExt_InFullscreenMode())
                *rval = M64VIDEO_FULLSCREEN;
            else
                *rval = M64VIDEO_WINDOWED;
            break;
        case M64CORE_SAVESTATE_SLOT:
            *rval = savestates_get_slot();
            break;
        case M64CORE_SPEED_FACTOR:
            *rval = l_SpeedFactor;
            break;
        case M64CORE_SPEED_LIMITER:
            *rval = l_MainSpeedLimit;
            break;
        case M64CORE_VIDEO_SIZE:
        {
            int width, height;
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            main_get_screen_size(&width, &height);
            *rval = (width << 16) + height;
            break;
        }
        case M64CORE_AUDIO_VOLUME:
        {
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;    
            return main_volume_get_level(rval);
        }
        case M64CORE_AUDIO_MUTE:
            *rval = main_volume_get_muted();
            break;
        case M64CORE_INPUT_GAMESHARK:
            *rval = event_gameshark_active();
            break;
        // these are only used for callbacks; they cannot be queried or set
        case M64CORE_STATE_LOADCOMPLETE:
        case M64CORE_STATE_SAVECOMPLETE:
            return M64ERR_INPUT_INVALID;
        default:
            return M64ERR_INPUT_INVALID;
    }

    return M64ERR_SUCCESS;
}

m64p_error main_core_state_set(m64p_core_param param, int val)
{
    switch (param)
    {
        case M64CORE_EMU_STATE:
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            if (val == M64EMU_STOPPED)
            {        
                /* this stop function is asynchronous.  The emulator may not terminate until later */
                main_stop();
                return M64ERR_SUCCESS;
            }
            else if (val == M64EMU_RUNNING)
            {
                if (main_is_paused())
                    main_toggle_pause();
                return M64ERR_SUCCESS;
            }
            else if (val == M64EMU_PAUSED)
            {    
                if (!main_is_paused())
                    main_toggle_pause();
                return M64ERR_SUCCESS;
            }
            return M64ERR_INPUT_INVALID;
        case M64CORE_VIDEO_MODE:
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            if (val == M64VIDEO_WINDOWED)
            {
                if (VidExt_InFullscreenMode())
                    gfx.changeWindow();
                return M64ERR_SUCCESS;
            }
            else if (val == M64VIDEO_FULLSCREEN)
            {
                if (!VidExt_InFullscreenMode())
                    gfx.changeWindow();
                return M64ERR_SUCCESS;
            }
            return M64ERR_INPUT_INVALID;
        case M64CORE_SAVESTATE_SLOT:
            if (val < 0 || val > 9)
                return M64ERR_INPUT_INVALID;
            savestates_select_slot(val);
            return M64ERR_SUCCESS;
        case M64CORE_SPEED_FACTOR:
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            main_speedset(val);
            return M64ERR_SUCCESS;
        case M64CORE_SPEED_LIMITER:
            main_set_speedlimiter(val);
            return M64ERR_SUCCESS;
        case M64CORE_VIDEO_SIZE:
        {
            // the front-end app is telling us that the user has resized the video output frame, and so
            // we should try to update the video plugin accordingly.  First, check state
            int width, height;
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            width = (val >> 16) & 0xffff;
            height = val & 0xffff;
            // then call the video plugin.  if the video plugin supports resizing, it will resize its viewport and call
            // VidExt_ResizeWindow to update the window manager handling our opengl output window
            gfx.resizeVideoOutput(width, height);
            return M64ERR_SUCCESS;
        }
        case M64CORE_AUDIO_VOLUME:
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            if (val < 0 || val > 100)
                return M64ERR_INPUT_INVALID;
            return main_volume_set_level(val);
        case M64CORE_AUDIO_MUTE:
            if ((main_volume_get_muted() && !val) || (!main_volume_get_muted() && val))
                return main_volume_mute();
            return M64ERR_SUCCESS;
        case M64CORE_INPUT_GAMESHARK:
            if (!g_EmulatorRunning)
                return M64ERR_INVALID_STATE;
            event_set_gameshark(val);
            return M64ERR_SUCCESS;
        // these are only used for callbacks; they cannot be queried or set
        case M64CORE_STATE_LOADCOMPLETE:
        case M64CORE_STATE_SAVECOMPLETE:
            return M64ERR_INPUT_INVALID;
        default:
            return M64ERR_INPUT_INVALID;
    }
}

m64p_error main_get_screen_size(int *width, int *height)
{
    gfx.readScreen(NULL, width, height, 0);
    return M64ERR_SUCCESS;
}

m64p_error main_read_screen(void *pixels, int bFront)
{
    int width_trash, height_trash;
    gfx.readScreen(pixels, &width_trash, &height_trash, bFront);
    return M64ERR_SUCCESS;
}

m64p_error main_volume_up(void)
{
    int level = 0;
    audio.volumeUp();
    main_draw_volume_osd();
    main_volume_get_level(&level);
    StateChanged(M64CORE_AUDIO_VOLUME, level);
    return M64ERR_SUCCESS;
}

m64p_error main_volume_down(void)
{
    int level = 0;
    audio.volumeDown();
    main_draw_volume_osd();
    main_volume_get_level(&level);
    StateChanged(M64CORE_AUDIO_VOLUME, level);
    return M64ERR_SUCCESS;
}

m64p_error main_volume_get_level(int *level)
{
    *level = audio.volumeGetLevel();
    return M64ERR_SUCCESS;
}

m64p_error main_volume_set_level(int level)
{
    audio.volumeSetLevel(level);
    main_draw_volume_osd();
    level = audio.volumeGetLevel();
    StateChanged(M64CORE_AUDIO_VOLUME, level);
    return M64ERR_SUCCESS;
}

m64p_error main_volume_mute(void)
{
    audio.volumeMute();
    main_draw_volume_osd();
    StateChanged(M64CORE_AUDIO_MUTE, main_volume_get_muted());
    return M64ERR_SUCCESS;
}

int main_volume_get_muted(void)
{
    return (audio.volumeGetLevel() == 0);
}

m64p_error main_reset(int do_hard_reset)
{
    if (do_hard_reset)
        reset_hard_job |= 1;
    else
        reset_soft();
    return M64ERR_SUCCESS;
}

/*********************************************************************************************************
* global functions, callbacks from the r4300 core or from other plugins
*/

static void video_plugin_render_callback(int bScreenRedrawn)
{
    int bOSD = ConfigGetParamBool(g_CoreConfig, "OnScreenDisplay");

    // if the flag is set to take a screenshot, then grab it now
    if (l_TakeScreenshot != 0)
    {
        // if the OSD is enabled, and the screen has not been recently redrawn, then we cannot take a screenshot now because
        // it contains the OSD text.  Wait until the next redraw
        if (!bOSD || bScreenRedrawn)
        {
            TakeScreenshot(l_TakeScreenshot - 1);  // current frame number +1 is in l_TakeScreenshot
            l_TakeScreenshot = 0; // reset flag
        }
    }

    // if the OSD is enabled, then draw it now
    if (bOSD)
    {
        osd_render();
    }

    // if the input plugin specified a render callback, call it now
    if(input.renderCallback)
    {
        input.renderCallback();
    }
}

void new_frame(void)
{
    if (g_FrameCallback != NULL)
        (*g_FrameCallback)(l_CurrentFrame);

    /* advance the current frame */
    l_CurrentFrame++;

    if (l_FrameAdvance) {
        rompause = 1;
        l_FrameAdvance = 0;
        StateChanged(M64CORE_EMU_STATE, M64EMU_PAUSED);
    }
}

static void apply_speed_limiter(void)
{
    unsigned int CurrentFPSTime;
    static unsigned int LastFPSTime = 0;
    static int VITotalDelta;
    static int VIDeltas[64];
    static unsigned int VIDeltasIndex;

    double VILimitMilliseconds = 1000.0 / ROM_PARAMS.vilimit;
    double AdjustedLimit = VILimitMilliseconds * 100.0 / l_SpeedFactor;  // adjust for selected emulator speed
    int ThisFrameDelta, IntegratedDelta, TimeToWait;

    timed_section_start(TIMED_SECTION_IDLE);

#ifdef DBG
    if(g_DebuggerActive) DebuggerCallback(DEBUG_UI_VI, 0);
#endif

    // if this is the first frame, initialize our data structures
    if(LastFPSTime == 0)
    {
        LastFPSTime = SDL_GetTicks();
        VITotalDelta = 0;
        memset(VIDeltas, 0, sizeof(VIDeltas));
        VIDeltasIndex = 0;
        return;
    }

    // calculate # of milliseconds that have passed since the last video interrupt
    CurrentFPSTime = SDL_GetTicks();
    ThisFrameDelta = CurrentFPSTime - LastFPSTime - (int) AdjustedLimit;

    // are we too fast?
    if (ThisFrameDelta < 0)
    {
        // calculate the total time error over the last 64 frames
        IntegratedDelta = VITotalDelta  + ThisFrameDelta;
        // if we are still too fast, and then speed limiter is on, then we should wait
        if (IntegratedDelta < 0 && l_MainSpeedLimit)
        {
            TimeToWait = (IntegratedDelta > ThisFrameDelta) ? -IntegratedDelta : -ThisFrameDelta;
            DebugMessage(M64MSG_VERBOSE, "    apply_speed_limiter(): Waiting %ims", TimeToWait);
            SDL_Delay(TimeToWait);
            // recalculate # of milliseconds that have passed since the last video interrupt,
            // taking into account the time we just waited
            CurrentFPSTime = SDL_GetTicks();
            ThisFrameDelta = CurrentFPSTime - LastFPSTime - (int) AdjustedLimit;
        }
    }

    // update our data structures
    LastFPSTime = CurrentFPSTime ;
    VITotalDelta += ThisFrameDelta - VIDeltas[VIDeltasIndex];
    VIDeltas[VIDeltasIndex] = ThisFrameDelta;
    VIDeltasIndex = (VIDeltasIndex + 1) & 63;

    timed_section_end(TIMED_SECTION_IDLE);
}

/* TODO: make a GameShark module and move that there */
static void gs_apply_cheats(void)
{
    if(g_gs_vi_counter < 60)
    {
        if (g_gs_vi_counter == 0)
            cheat_apply_cheats(ENTRY_BOOT);
        g_gs_vi_counter++;
    }
    else
    {
        cheat_apply_cheats(ENTRY_VI);
    }
}

static void pause_loop(void)
{
    if(rompause)
    {
        osd_render();  // draw Paused message in case gfx.updateScreen didn't do it
        VidExt_GL_SwapBuffers();
        while(rompause)
        {
            SDL_Delay(10);
            main_check_inputs();
        }
    }
}
#ifndef IN_OPENEMU
/* called on vertical interrupt.
 * Allow the core to perform various things */
void new_vi(void)
{
    gs_apply_cheats();

    main_check_inputs();

    timed_sections_refresh();

    pause_loop();

    apply_speed_limiter();
}
#endif
static void connect_all(
        struct r4300_core* r4300,
        struct rdp_core* dp,
        struct rsp_core* sp,
        struct ai_controller* ai,
        struct pi_controller* pi,
        struct ri_controller* ri,
        struct si_controller* si,
        struct vi_controller* vi,
        uint32_t* dram,
        size_t dram_size,
        uint8_t* rom,
        size_t rom_size)
{
    connect_rdp(dp, r4300, sp, ri);
    connect_rsp(sp, r4300, dp, ri);
    connect_ai(ai, r4300, ri, vi);
    connect_pi(pi, r4300, ri, rom, rom_size);
    connect_ri(ri, dram, dram_size);
    connect_si(si, r4300, ri);
    connect_vi(vi, r4300);
}

/*********************************************************************************************************
* emulation thread - runs the core
*/
m64p_error main_run(void)
{
    size_t i;
    unsigned int disable_extra_mem;
    struct eep_file eep;
    struct fla_file fla;
    struct mpk_file mpk;
    struct sra_file sra;
    static int channels[] = { 0, 1, 2, 3 };

    /* take the r4300 emulator mode from the config file at this point and cache it in a global variable */
    r4300emu = ConfigGetParamInt(g_CoreConfig, "R4300Emulator");

    /* set some other core parameters based on the config file values */
    savestates_set_autoinc_slot(ConfigGetParamBool(g_CoreConfig, "AutoStateSlotIncrement"));
    savestates_select_slot(ConfigGetParamInt(g_CoreConfig, "CurrentStateSlot"));
    no_compiled_jump = ConfigGetParamBool(g_CoreConfig, "NoCompiledJump");
    g_delay_si = ConfigGetParamBool(g_CoreConfig, "DelaySI");
    disable_extra_mem = ConfigGetParamInt(g_CoreConfig, "DisableExtraMem");
    count_per_op = ConfigGetParamInt(g_CoreConfig, "CountPerOp");
    if (count_per_op <= 0)
        count_per_op = ROM_PARAMS.countperop;
    cheat_add_hacks();

    /* do byte-swapping if it's not been done yet */
    if (g_MemHasBeenBSwapped == 0)
    {
        swap_buffer(g_rom, 4, g_rom_size/4);
        g_MemHasBeenBSwapped = 1;
    }

    connect_all(&g_r4300, &g_dp, &g_sp,
                &g_ai, &g_pi, &g_ri, &g_si, &g_vi,
                g_rdram, (disable_extra_mem == 0) ? 0x800000 : 0x400000,
                g_rom, g_rom_size);

    init_memory();

    // Attach rom to plugins
    if (!gfx.romOpen())
    {
        return M64ERR_PLUGIN_FAIL;
    }
    if (!audio.romOpen())
    {
        gfx.romClosed(); return M64ERR_PLUGIN_FAIL;
    }
    if (!input.romOpen())
    {
        audio.romClosed(); gfx.romClosed(); return M64ERR_PLUGIN_FAIL;
    }

    /* set up the SDL key repeat and event filter to catch keyboard/joystick commands for the core */
    event_initialize();

    /* initialize the on-screen display */
    if (ConfigGetParamBool(g_CoreConfig, "OnScreenDisplay"))
    {
        // init on-screen display
        int width = 640, height = 480;
        gfx.readScreen(NULL, &width, &height, 0); // read screen to get width and height
        osd_init(width, height);
    }

    // setup rendering callback from video plugin to the core, for screenshots and On-Screen-Display
    gfx.setRenderingCallback(video_plugin_render_callback);

    /* connect external audio sink to AI component */
    g_ai.user_data = &g_ai;
    g_ai.set_audio_format = set_audio_format_via_audio_plugin;
    g_ai.push_audio_samples = push_audio_samples_via_audio_plugin;

    /* connect external time source to AF_RTC component */
    g_si.pif.af_rtc.user_data = NULL;
    g_si.pif.af_rtc.get_time = get_time_using_C_localtime;

    /* connect external game controllers */
    for(i = 0; i < GAME_CONTROLLERS_COUNT; ++i)
    {
        g_si.pif.controllers[i].user_data = &channels[i];
        g_si.pif.controllers[i].is_connected = egcvip_is_connected;
        g_si.pif.controllers[i].get_input = egcvip_get_input;
    }

    /* connect external rumblepaks */
    for(i = 0; i < GAME_CONTROLLERS_COUNT; ++i)
    {
        g_si.pif.controllers[i].rumblepak.user_data = &channels[i];
        g_si.pif.controllers[i].rumblepak.rumble = rvip_rumble;
    }

    /* open mpk file (if any) and connect it to mempaks */
    open_mpk_file(&mpk, get_mempaks_path());
    for(i = 0; i < GAME_CONTROLLERS_COUNT; ++i)
    {
        g_si.pif.controllers[i].mempak.user_data = &mpk;
        g_si.pif.controllers[i].mempak.save = save_mpk_file;
        g_si.pif.controllers[i].mempak.data = mpk_file_ptr(&mpk, i);
    }

    /* open eep file (if any) and connect it to eeprom */
    open_eep_file(&eep, get_eeprom_path());
    g_si.pif.eeprom.user_data = &eep;
    g_si.pif.eeprom.save = save_eep_file;
    g_si.pif.eeprom.data = eep_file_ptr(&eep);
    if (ROM_SETTINGS.savetype != EEPROM_16KB)
    {
        /* 4kbits EEPROM */
        g_si.pif.eeprom.size = 0x200;
        g_si.pif.eeprom.id = 0x8000;
    }
    else
    {
        /* 16kbits EEPROM */
        g_si.pif.eeprom.size = 0x800;
        g_si.pif.eeprom.id = 0xc000;
    }

    /* open fla file (if any) and connect it to flashram */
    open_fla_file(&fla, get_flashram_path());
    g_pi.flashram.user_data = &fla;
    g_pi.flashram.save = save_fla_file;
    g_pi.flashram.data = fla_file_ptr(&fla);

    /* open sra file (if any) and connect it to SRAM */
    open_sra_file(&sra, get_sram_path());
    g_pi.sram.user_data = &sra;
    g_pi.sram.save = save_sra_file;
    g_pi.sram.data = sra_file_ptr(&sra);

#ifdef WITH_LIRC
    lircStart();
#endif // WITH_LIRC

#ifdef DBG
    if (ConfigGetParamBool(g_CoreConfig, "EnableDebugger"))
        init_debugger();
#endif

    /* Startup message on the OSD */
    osd_new_message(OSD_MIDDLE_CENTER, "Mupen64Plus Started...");

    g_EmulatorRunning = 1;
    StateChanged(M64CORE_EMU_STATE, M64EMU_RUNNING);

    /* call r4300 CPU core and run the game */
    r4300_reset_hard();
    r4300_reset_soft();
    r4300_execute();

    /* now begin to shut down */
#ifdef WITH_LIRC
    lircStop();
#endif // WITH_LIRC

#ifdef DBG
    if (g_DebuggerActive)
        destroy_debugger();
#endif

    close_sra_file(&sra);
    close_fla_file(&fla);
    close_eep_file(&eep);
    close_mpk_file(&mpk);

    if (ConfigGetParamBool(g_CoreConfig, "OnScreenDisplay"))
    {
        osd_exit();
    }

    rsp.romClosed();
    input.romClosed();
    audio.romClosed();
    gfx.romClosed();

    // clean up
    g_EmulatorRunning = 0;
    StateChanged(M64CORE_EMU_STATE, M64EMU_STOPPED);

    return M64ERR_SUCCESS;
}

void main_stop(void)
{
    /* note: this operation is asynchronous.  It may be called from a thread other than the
       main emulator thread, and may return before the emulator is completely stopped */
    if (!g_EmulatorRunning)
        return;

    DebugMessage(M64MSG_STATUS, "Stopping emulation.");
    if(l_msgPause)
    {
        osd_delete_message(l_msgPause);
        l_msgPause = NULL;
    }
    if(l_msgFF)
    {
        osd_delete_message(l_msgFF);
        l_msgFF = NULL;
    }
    if(l_msgVol)
    {
        osd_delete_message(l_msgVol);
        l_msgVol = NULL;
    }
    if (rompause)
    {
        rompause = 0;
        StateChanged(M64CORE_EMU_STATE, M64EMU_RUNNING);
    }
    stop = 1;
#ifdef DBG
    if(g_DebuggerActive)
    {
        debugger_step();
    }
#endif        
}
