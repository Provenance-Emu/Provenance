/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus - eventloop.c                                             *
 *   Mupen64Plus homepage: https://mupen64plus.org/                        *
 *   Copyright (C) 2008-2009 Richard Goedeken                              *
 *   Copyright (C) 2008 Ebenblues Nmn Okaygo Tillin9                       *
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

#include <SDL.h>
#include <SDL_syswm.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if ! SDL_VERSION_ATLEAST(1,3,0)

#define SDL_SCANCODE_ESCAPE SDLK_ESCAPE
#define SDL_NUM_SCANCODES SDLK_LAST
#define SDL_SCANCODE_F5 SDLK_F5
#define SDL_SCANCODE_F7 SDLK_F7
#define SDL_SCANCODE_F9 SDLK_F9
#define SDL_SCANCODE_F10 SDLK_F10
#define SDL_SCANCODE_F11 SDLK_F11
#define SDL_SCANCODE_F12 SDLK_F12
#define SDL_SCANCODE_P SDLK_p
#define SDL_SCANCODE_M SDLK_m
#define SDL_SCANCODE_RIGHTBRACKET SDLK_RIGHTBRACKET
#define SDL_SCANCODE_LEFTBRACKET SDLK_LEFTBRACKET
#define SDL_SCANCODE_F SDLK_f
#define SDL_SCANCODE_SLASH SDLK_SLASH
#define SDL_SCANCODE_G SDLK_g
#define SDL_SCANCODE_RETURN SDLK_RETURN
#define SDL_SCANCODE_0 SDLK_0
#define SDL_SCANCODE_1 SDLK_1
#define SDL_SCANCODE_2 SDLK_2
#define SDL_SCANCODE_3 SDLK_3
#define SDL_SCANCODE_4 SDLK_4
#define SDL_SCANCODE_5 SDLK_5
#define SDL_SCANCODE_6 SDLK_6
#define SDL_SCANCODE_7 SDLK_7
#define SDL_SCANCODE_8 SDLK_8
#define SDL_SCANCODE_9 SDLK_9
#define SDL_SCANCODE_UNKNOWN SDLK_UNKNOWN

#define SDL_SetEventFilter(func, data) SDL_SetEventFilter(func)
#define event_sdl_filter(userdata, event) event_sdl_filter(const event)

#else
	 SDL_JoystickID l_iJoyInstanceID[10];
#endif

#define M64P_CORE_PROTOTYPES 1
#include "api/callbacks.h"
#include "api/config.h"
#include "api/m64p_config.h"
#include "api/m64p_types.h"
#include "eventloop.h"
#include "main.h"
#include "plugin/plugin.h"
#include "sdl_key_converter.h"
#include "util.h"

/* version number for CoreEvents config section */
#define CONFIG_PARAM_VERSION 1.00

static m64p_handle l_CoreEventsConfig = NULL;

/*********************************************************************************************************
* static variables and definitions for eventloop.c
*/

#define kbdFullscreen "Kbd Mapping Fullscreen"
#define kbdStop "Kbd Mapping Stop"
#define kbdPause "Kbd Mapping Pause"
#define kbdSave "Kbd Mapping Save State"
#define kbdLoad "Kbd Mapping Load State"
#define kbdIncrement "Kbd Mapping Increment Slot"
#define kbdReset "Kbd Mapping Reset"
#define kbdSpeeddown "Kbd Mapping Speed Down"
#define kbdSpeedup "Kbd Mapping Speed Up"
#define kbdScreenshot "Kbd Mapping Screenshot"
#define kbdMute "Kbd Mapping Mute"
#define kbdIncrease "Kbd Mapping Increase Volume"
#define kbdDecrease "Kbd Mapping Decrease Volume"
#define kbdForward "Kbd Mapping Fast Forward"
#define kbdAdvance "Kbd Mapping Frame Advance"
#define kbdGameshark "Kbd Mapping Gameshark"

typedef enum {joyFullscreen,
              joyStop,
              joyPause,
              joySave,
              joyLoad,
              joyIncrement,
              joyReset,
              joySpeedDown,
              joySpeedUp,
              joyScreenshot,
              joyMute,
              joyIncrease,
              joyDecrease,
              joyForward,
              joyAdvance,
              joyGameshark
} eJoyCommand;

static const char *JoyCmdName[] = { "Joy Mapping Fullscreen",
                                    "Joy Mapping Stop",
                                    "Joy Mapping Pause",
                                    "Joy Mapping Save State",
                                    "Joy Mapping Load State",
                                    "Joy Mapping Increment Slot",
                                    "Joy Mapping Reset",
                                    "Joy Mapping Speed Down",
                                    "Joy Mapping Speed Up",
                                    "Joy Mapping Screenshot",
                                    "Joy Mapping Mute",
                                    "Joy Mapping Increase Volume",
                                    "Joy Mapping Decrease Volume",
                                    "Joy Mapping Fast Forward",
                                    "Joy Mapping Frame Advance",
                                    "Joy Mapping Gameshark"};

static const int NumJoyCommands = sizeof(JoyCmdName) / sizeof(const char *);

static int JoyCmdActive[16][2];  /* if extra joystick commands are added above, make sure there is enough room in this array */
                                 /* [i][0] is Command Active, [i][1] is Hotkey Active */

static int GamesharkActive = 0;

/*********************************************************************************************************
* static functions for eventloop.c
*/

/** MatchJoyCommand
 *    This function processes an SDL event and updates the JoyCmdActive array if the
 *    event matches with the given command.
 *
 *    If the event activates a joystick command which was not previously active, then
 *    a 1 is returned.  If the event de-activates an command, a -1 is returned.  Otherwise
 *    (if the event does not match the command or active status didn't change), a 0 is returned.
 */
static int MatchJoyCommand(const SDL_Event *event, eJoyCommand cmd)
{
    const char *multi_event_str = ConfigGetParamString(l_CoreEventsConfig, JoyCmdName[cmd]);
    const int orig_cmd_value = (JoyCmdActive[cmd][1] << 1) | JoyCmdActive[cmd][0];
    int dev_number, input_number, input_value;
    char axis_direction;

    /* Empty string or non-joystick command */
    if (multi_event_str == NULL || strlen(multi_event_str) < 4 || multi_event_str[0] != 'J')
        return 0;

    /* Make copy of the event config string that we can hack it up with strtok */
    char tokenized_event_str[128];
    strncpy(tokenized_event_str, multi_event_str, 127);
    tokenized_event_str[127] = '\0';
    
    /* Iterate over comma-separated config phrases */
    char *phrase_str = strtok(tokenized_event_str, ",");
    while (phrase_str != NULL)
    {
        int iHotkey, has_hotkey = 0;
        
        /* Check for invalid phrase */
        if (strlen(phrase_str) < 4 || phrase_str[0] != 'J')
        {
            phrase_str = strtok(NULL, ",");
            continue;
        }
        
        /* Get device (joystick) number */
        if (phrase_str[1] == '*')
        {
            dev_number = -1;
        }
        else if (phrase_str[1] >= '0' && phrase_str[1] <= '9')
        {
            dev_number = phrase_str[1] - '0';
#if SDL_VERSION_ATLEAST(2,0,0)
            dev_number = l_iJoyInstanceID[dev_number];
#endif
        }
        else
        {
            phrase_str = strtok(NULL, ",");
            continue;
        }

        /* Iterate over JoyAction/JoyHotkey action fields */
        for (iHotkey = 0; iHotkey < 2; iHotkey++)
        {
            const char *action_str = NULL;
            if (iHotkey == 0)
            {
                action_str = phrase_str + 2;
            }
            else
            {
                char *hotkey_str = strchr(phrase_str, '/');
                if (hotkey_str == NULL || strlen(hotkey_str) < 3)
                {
                    break;
                }
                action_str = hotkey_str+1;
                has_hotkey = 1;
            }

            /* Evaluate action based on type of joystick input expected */
            switch (action_str[0])
            {
                /* Axis */
                case 'A':
                    if (event->type != SDL_JOYAXISMOTION)
                        break;
                    if (sscanf(action_str, "A%d%c", &input_number, &axis_direction) != 2)
                        break;
                    if ((dev_number != 1 && dev_number != event->jaxis.which) || input_number != event->jaxis.axis)
                        break;
                    if (axis_direction == '+')
                    {
                        if (event->jaxis.value >= 15000)
                            JoyCmdActive[cmd][iHotkey] = 1;
                        else if (event->jaxis.value <= 8000)
                            JoyCmdActive[cmd][iHotkey] = 0;
                        break;
                    }
                    else if (axis_direction == '-')
                    {
                        if (event->jaxis.value <= -15000)
                            JoyCmdActive[cmd][iHotkey] = 1;
                        else if (event->jaxis.value >= -8000)
                            JoyCmdActive[cmd][iHotkey] = 0;
                        break;
                    }
                    break;
                /* Hat */
                case 'H':
                    if (event->type != SDL_JOYHATMOTION)
                        break;
                    if (sscanf(action_str, "H%dV%d", &input_number, &input_value) != 2)
                        break;
                    if ((dev_number != -1 && dev_number != event->jhat.which) || input_number != event->jhat.hat)
                        break;
                    if ((event->jhat.value & input_value) == input_value)
                        JoyCmdActive[cmd][iHotkey] = 1;
                    else if ((event->jhat.value & input_value) != input_value)
                        JoyCmdActive[cmd][iHotkey] = 0;
                    break;
                /* Button. */
                case 'B':
                    if (event->type != SDL_JOYBUTTONDOWN && event->type != SDL_JOYBUTTONUP)
                        break;
                    if (sscanf(action_str, "B%d", &input_number) != 1)
                        break;
                    if ((dev_number != -1 && dev_number != event->jbutton.which) || input_number != event->jbutton.button)
                        break;
                    if (event->type == SDL_JOYBUTTONDOWN)
                        JoyCmdActive[cmd][iHotkey] = 1;
                    else if (event->type == SDL_JOYBUTTONUP)
                        JoyCmdActive[cmd][iHotkey] = 0;
                    break;
                default:
                    /* bad configuration parameter */
                    break;
            }
        } /* Iterate over JoyAction/JoyHotkey action fields */
        
        /* Detect changes in command activation status */
        const int new_cmd_value = (JoyCmdActive[cmd][1] << 1) | JoyCmdActive[cmd][0];
        const int active_mask = has_hotkey ? 3 : 1;
        if ((orig_cmd_value & active_mask) != active_mask && (new_cmd_value & active_mask) == active_mask)
            return 1;
        if ((orig_cmd_value & active_mask) == active_mask && (new_cmd_value & active_mask) != active_mask)
            return -1;

        /* get next comma-separated command phrase from event string */
        phrase_str = strtok(NULL, ",");
    } /* Iterate over comma-separated config phrases */

    /* nothing found */
    return 0;
}

/*********************************************************************************************************
* sdl event filter
*/
static int SDLCALL event_sdl_filter(void *userdata, SDL_Event *event)
{
    int cmd, action;

    switch(event->type)
    {
        // user clicked on window close button
        case SDL_QUIT:
            main_stop();
            break;

        case SDL_KEYDOWN:
#if SDL_VERSION_ATLEAST(1,3,0)
            if (event->key.repeat)
                return 0;

            event_sdl_keydown(event->key.keysym.scancode, event->key.keysym.mod);
#else
            event_sdl_keydown(event->key.keysym.sym, event->key.keysym.mod);
#endif
            return 0;
        case SDL_KEYUP:
#if SDL_VERSION_ATLEAST(1,3,0)
            event_sdl_keyup(event->key.keysym.scancode, event->key.keysym.mod);
#else
            event_sdl_keyup(event->key.keysym.sym, event->key.keysym.mod);
#endif
            return 0;

#if SDL_VERSION_ATLEAST(1,3,0)
        case SDL_WINDOWEVENT:
            switch (event->window.event) {
                case SDL_WINDOWEVENT_RESIZED:
                    // call the video plugin.  if the video plugin supports resizing, it will resize its viewport and call
                    // VidExt_ResizeWindow to update the window manager handling our opengl output window
                    gfx.resizeVideoOutput(event->window.data1, event->window.data2);
                    return 0;  // consumed the event
                    break;

                case SDL_WINDOWEVENT_MOVED:
                    gfx.moveScreen(event->window.data1, event->window.data2);
                    return 0;  // consumed the event
                    break;
            }
            break;
#else
        case SDL_VIDEORESIZE:
            // call the video plugin.  if the video plugin supports resizing, it will resize its viewport and call
            // VidExt_ResizeWindow to update the window manager handling our opengl output window
            gfx.resizeVideoOutput(event->resize.w, event->resize.h);
            return 0;  // consumed the event
            break;

#ifdef WIN32
        case SDL_SYSWMEVENT:
            if(event->syswm.msg->msg == WM_MOVE)
                gfx.moveScreen(0,0); // The video plugin is responsible for getting the new window position
            return 0;  // consumed the event
            break;
#endif
#endif

        // if joystick action is detected, check if it's mapped to a special function
        case SDL_JOYAXISMOTION:
        case SDL_JOYBUTTONDOWN:
        case SDL_JOYBUTTONUP:
        case SDL_JOYHATMOTION:
            for (cmd = 0; cmd < NumJoyCommands; cmd++)
            {
                action = MatchJoyCommand(event, (eJoyCommand) cmd);
                if (action == 1) /* command was just activated (button down, etc) */
                {
                    if (cmd == joyFullscreen)
                        gfx.changeWindow();
                    else if (cmd == joyStop)
                        main_stop();
                    else if (cmd == joyPause)
                        main_toggle_pause();
                    else if (cmd == joySave)
                        main_state_save(1, NULL); /* save in mupen64plus format using current slot */
                    else if (cmd == joyLoad)
                        main_state_load(NULL); /* load using current slot */
                    else if (cmd == joyIncrement)
                        main_state_inc_slot();
                    else if (cmd == joyReset)
                        main_reset(0);
                    else if (cmd == joySpeedDown)
                        main_speeddown(5);
                    else if (cmd == joySpeedUp)
                        main_speedup(5);
                    else if (cmd == joyScreenshot)
                        main_take_next_screenshot();
                    else if (cmd == joyMute)
                        main_volume_mute();
                    else if (cmd == joyDecrease)
                        main_volume_down();
                    else if (cmd == joyIncrease)
                        main_volume_up();
                    else if (cmd == joyForward)
                        main_set_fastforward(1);
                    else if (cmd == joyAdvance)
                        main_advance_one();
                    else if (cmd == joyGameshark)
                        event_set_gameshark(1);
                }
                else if (action == -1) /* command was just de-activated (button up, etc) */
                {
                    if (cmd == joyForward)
                        main_set_fastforward(0);
                    else if (cmd == joyGameshark)
                        event_set_gameshark(0);
                }
            }

            return 0;
            break;
    }

    return 1;  // add this event to SDL queue
}

/*********************************************************************************************************
* global functions
*/

void event_initialize(void)
{
    int i, j;

    /* set initial state of all joystick commands to 'off' */
    for (i = 0; i < NumJoyCommands; i++)
        for (j = 0; j < 2; j++)
            JoyCmdActive[i][j] = 0;

    /* activate any joysticks which are referenced in the joystick event command strings */
    const int NumJoysticks = SDL_NumJoysticks();
    if (NumJoysticks > 0)
    {
        for (i = 0; i < NumJoyCommands; i++)
        {
            const char *multi_event_str = ConfigGetParamString(l_CoreEventsConfig, JoyCmdName[i]);
            /* Empty string or invalid command */
            if (multi_event_str == NULL || strlen(multi_event_str) < 4 || multi_event_str[0] != 'J')
                continue;
            /* Make copy of the event config string that we can hack it up with strtok */
            char tokenized_event_str[128];
            strncpy(tokenized_event_str, multi_event_str, 127);
            tokenized_event_str[127] = '\0';
            /* Iterate over comma-separated config phrases */
            char *phrase_str = strtok(tokenized_event_str, ",");
            while (phrase_str != NULL)
            {
                /* Check for invalid phrase */
                if (strlen(phrase_str) < 4 || phrase_str[0] != 'J')
                {
                    phrase_str = strtok(NULL, ",");
                    continue;
                }
                /* Get device (joystick) number(s) to initialize */
                int joy_min, joy_max;
                if (phrase_str[1] == '*')
                {
                    joy_min = 0;
                    joy_max = NumJoysticks;
                }
                else if (phrase_str[1] >= '0' && phrase_str[1] <= '9')
                {
                    joy_min = joy_max = phrase_str[1] - '0';
                }
                else
                {
                    phrase_str = strtok(NULL, ",");
                    continue;
                }
                /* initialize them */
                int device;
                for (device = joy_min; device <= joy_max; device++)
                {
                    if (!SDL_WasInit(SDL_INIT_JOYSTICK))
                        SDL_InitSubSystem(SDL_INIT_JOYSTICK);
#if SDL_VERSION_ATLEAST(2,0,0)
                    SDL_Joystick *thisJoy = SDL_JoystickOpen(device);
			        l_iJoyInstanceID[device] = SDL_JoystickInstanceID(thisJoy);
#else
                    if (!SDL_JoystickOpened(device))
                        SDL_JoystickOpen(device);
#endif
                }
                
                phrase_str = strtok(NULL, ",");
            } /* Iterate over comma-separated config phrases */
        }
    }

    /* set up SDL event filter and disable key repeat */
#if !SDL_VERSION_ATLEAST(2,0,0)
    SDL_EnableKeyRepeat(0, 0);
#endif
    SDL_SetEventFilter(event_sdl_filter, NULL);
    
#if defined(WIN32) && !SDL_VERSION_ATLEAST(1,3,0)
    SDL_EventState(SDL_SYSWMEVENT, SDL_ENABLE);

    if (SDL_EventState(SDL_SYSWMEVENT, SDL_QUERY) != SDL_ENABLE)
        DebugMessage(M64MSG_WARNING, "Failed to change event state: %s", SDL_GetError());
#endif
}

int event_set_core_defaults(void)
{
    float fConfigParamsVersion;
    int bSaveConfig = 0;

    if (ConfigOpenSection("CoreEvents", &l_CoreEventsConfig) != M64ERR_SUCCESS || l_CoreEventsConfig == NULL)
    {
        DebugMessage(M64MSG_ERROR, "Failed to open CoreEvents config section.");
        return 0; /* fail */
    }

    if (ConfigGetParameter(l_CoreEventsConfig, "Version", M64TYPE_FLOAT, &fConfigParamsVersion, sizeof(float)) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_WARNING, "No version number in 'CoreEvents' config section. Setting defaults.");
        ConfigDeleteSection("CoreEvents");
        ConfigOpenSection("CoreEvents", &l_CoreEventsConfig);
        bSaveConfig = 1;
    }
    else if (((int) fConfigParamsVersion) != ((int) CONFIG_PARAM_VERSION))
    {
        DebugMessage(M64MSG_WARNING, "Incompatible version %.2f in 'CoreEvents' config section: current is %.2f. Setting defaults.", fConfigParamsVersion, (float) CONFIG_PARAM_VERSION);
        ConfigDeleteSection("CoreEvents");
        ConfigOpenSection("CoreEvents", &l_CoreEventsConfig);
        bSaveConfig = 1;
    }
    else if ((CONFIG_PARAM_VERSION - fConfigParamsVersion) >= 0.0001f)
    {
        /* handle upgrades */
        float fVersion = CONFIG_PARAM_VERSION;
        ConfigSetParameter(l_CoreEventsConfig, "Version", M64TYPE_FLOAT, &fVersion);
        DebugMessage(M64MSG_INFO, "Updating parameter set version in 'CoreEvents' config section to %.2f", fVersion);
        bSaveConfig = 1;
    }

    ConfigSetDefaultFloat(l_CoreEventsConfig, "Version", CONFIG_PARAM_VERSION,  "Mupen64Plus CoreEvents config parameter set version number.  Please don't change this version number.");
    /* Keyboard presses mapped to core functions */
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdStop, sdl_native2keysym(SDL_SCANCODE_ESCAPE),          "SDL keysym for stopping the emulator");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdFullscreen, sdl_native2keysym(SDL_NUM_SCANCODES),      "SDL keysym for switching between fullscreen/windowed modes");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdSave, sdl_native2keysym(SDL_SCANCODE_F5),              "SDL keysym for saving the emulator state");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdLoad, sdl_native2keysym(SDL_SCANCODE_F7),              "SDL keysym for loading the emulator state");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdIncrement, sdl_native2keysym(SDL_SCANCODE_UNKNOWN),    "SDL keysym for advancing the save state slot");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdReset, sdl_native2keysym(SDL_SCANCODE_F9),             "SDL keysym for resetting the emulator");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdSpeeddown, sdl_native2keysym(SDL_SCANCODE_F10),        "SDL keysym for slowing down the emulator");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdSpeedup, sdl_native2keysym(SDL_SCANCODE_F11),          "SDL keysym for speeding up the emulator");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdScreenshot, sdl_native2keysym(SDL_SCANCODE_F12),       "SDL keysym for taking a screenshot");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdPause, sdl_native2keysym(SDL_SCANCODE_P),              "SDL keysym for pausing the emulator");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdMute, sdl_native2keysym(SDL_SCANCODE_M),               "SDL keysym for muting/unmuting the sound");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdIncrease, sdl_native2keysym(SDL_SCANCODE_RIGHTBRACKET),"SDL keysym for increasing the volume");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdDecrease, sdl_native2keysym(SDL_SCANCODE_LEFTBRACKET), "SDL keysym for decreasing the volume");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdForward, sdl_native2keysym(SDL_SCANCODE_F),            "SDL keysym for temporarily going really fast");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdAdvance, sdl_native2keysym(SDL_SCANCODE_SLASH),        "SDL keysym for advancing by one frame when paused");
    ConfigSetDefaultInt(l_CoreEventsConfig, kbdGameshark, sdl_native2keysym(SDL_SCANCODE_G),          "SDL keysym for pressing the game shark button");
    /* Joystick events mapped to core functions */
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyStop], "",       "Joystick event string for stopping the emulator");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyFullscreen], "", "Joystick event string for switching between fullscreen/windowed modes");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joySave], "",       "Joystick event string for saving the emulator state");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyLoad], "",       "Joystick event string for loading the emulator state");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyIncrement], "",  "Joystick event string for advancing the save state slot");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyReset], "",      "Joystick event string for resetting the emulator");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joySpeedDown], "",  "Joystick event string for slowing down the emulator");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joySpeedUp], "",    "Joystick event string for speeding up the emulator");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyScreenshot], "", "Joystick event string for taking a screenshot");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyPause], "",      "Joystick event string for pausing the emulator");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyMute], "",       "Joystick event string for muting/unmuting the sound");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyIncrease], "",   "Joystick event string for increasing the volume");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyDecrease], "",   "Joystick event string for decreasing the volume");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyForward], "",    "Joystick event string for fast-forward");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyAdvance], "",    "Joystick event string for advancing by one frame when paused");
    ConfigSetDefaultString(l_CoreEventsConfig, JoyCmdName[joyGameshark], "",  "Joystick event string for pressing the game shark button");

    if (bSaveConfig)
        ConfigSaveSection("CoreEvents");

    return 1;
}

static int get_saveslot_from_keysym(int keysym)
{
    switch (keysym) {
    case SDL_SCANCODE_0:
        return 0;
    case SDL_SCANCODE_1:
        return 1;
    case SDL_SCANCODE_2:
        return 2;
    case SDL_SCANCODE_3:
        return 3;
    case SDL_SCANCODE_4:
        return 4;
    case SDL_SCANCODE_5:
        return 5;
    case SDL_SCANCODE_6:
        return 6;
    case SDL_SCANCODE_7:
        return 7;
    case SDL_SCANCODE_8:
        return 8;
    case SDL_SCANCODE_9:
        return 9;
    default:
        return -1;
    }
}

/*********************************************************************************************************
* sdl keyup/keydown handlers
*/

void event_sdl_keydown(int keysym, int keymod)
{
    int slot;

    /* check for the only 2 hard-coded key commands: Alt-enter for fullscreen and 0-9 for save state slot */
    if (keysym == SDL_SCANCODE_RETURN && keymod & (KMOD_LALT | KMOD_RALT))
        gfx.changeWindow();
    else if ((slot = get_saveslot_from_keysym(keysym)) >= 0)
        main_state_set_slot(slot);
    /* check all of the configurable commands */
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdStop)))
        main_stop();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdFullscreen)))
        gfx.changeWindow();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdSave)))
        main_state_save(0, NULL); /* save in mupen64plus format using current slot */
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdLoad)))
        main_state_load(NULL); /* load using current slot */
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdIncrement)))
        main_state_inc_slot();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdReset)))
        main_reset(0);
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdSpeeddown)))
        main_speeddown(5);
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdSpeedup)))
        main_speedup(5);
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdScreenshot)))
        main_take_next_screenshot();    /* screenshot will be taken at the end of frame rendering */
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdPause)))
        main_toggle_pause();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdMute)))
        main_volume_mute();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdIncrease)))
        main_volume_up();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdDecrease)))
        main_volume_down();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdForward)))
        main_set_fastforward(1);
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdAdvance)))
        main_advance_one();
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdGameshark))) {
        event_set_gameshark(1);
    }
    else
    {
        /* pass all other keypresses to the input plugin */
        input.keyDown(keymod, keysym);
    }

}

void event_sdl_keyup(int keysym, int keymod)
{
    if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdStop)))
    {
        return;
    }
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdForward)))
    {
        main_set_fastforward(0);
    }
    else if (keysym == sdl_keysym2native(ConfigGetParamInt(l_CoreEventsConfig, kbdGameshark)))
    {
        event_set_gameshark(0);
    }
    else input.keyUp(keymod, keysym);

}

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

