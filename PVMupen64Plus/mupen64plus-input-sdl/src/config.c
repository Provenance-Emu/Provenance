/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *   Mupen64plus-input-sdl - config.c                                      *
 *   Mupen64Plus homepage: http://code.google.com/p/mupen64plus/           *
 *   Copyright (C) 2009-2013 Richard Goedeken                              *
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

#define M64P_PLUGIN_PROTOTYPES 1
#include "m64p_types.h"
#include "m64p_plugin.h"
#include "m64p_config.h"

#include "osal_preproc.h"
#include "autoconfig.h"
#include "plugin.h"

#include "config.h"

#define HAT_POS_NAME( hat )         \
       ((hat == SDL_HAT_UP) ? "Up" :        \
       ((hat == SDL_HAT_DOWN) ? "Down" :    \
       ((hat == SDL_HAT_LEFT) ? "Left" :    \
       ((hat == SDL_HAT_RIGHT) ? "Right" :  \
         "None"))))

typedef enum {
    E_MODE_MANUAL = 0,
    E_MODE_NAMED_AUTO,
    E_MODE_FULL_AUTO
 } eModeType;

static const char *button_names[] = {
    "DPad R",       // R_DPAD
    "DPad L",       // L_DPAD
    "DPad D",       // D_DPAD
    "DPad U",       // U_DPAD
    "Start",        // START_BUTTON
    "Z Trig",       // Z_TRIG
    "B Button",     // B_BUTTON
    "A Button",     // A_BUTTON
    "C Button R",   // R_CBUTTON
    "C Button L",   // L_CBUTTON
    "C Button D",   // D_CBUTTON
    "C Button U",   // U_CBUTTON
    "R Trig",       // R_TRIG
    "L Trig",       // L_TRIG
    "Mempak switch",
    "Rumblepak switch",
    "X Axis",       // X_AXIS
    "Y Axis"        // Y_AXIS
};

/* static functions */
static int get_hat_pos_by_name( const char *name )
{
    if( !strcasecmp( name, "up" ) )
        return SDL_HAT_UP;
    if( !strcasecmp( name, "down" ) )
        return SDL_HAT_DOWN;
    if( !strcasecmp( name, "left" ) )
        return SDL_HAT_LEFT;
    if( !strcasecmp( name, "right" ) )
        return SDL_HAT_RIGHT;
    DebugMessage(M64MSG_WARNING, "get_hat_pos_by_name(): direction '%s' unknown", name);
    return -1;
}

static void clear_controller(int iCtrlIdx)
{
    int b;

    controller[iCtrlIdx].device = DEVICE_NO_JOYSTICK;
    controller[iCtrlIdx].control->Present = 0;
    controller[iCtrlIdx].control->RawData = 0;
    controller[iCtrlIdx].control->Plugin = PLUGIN_NONE;
    for( b = 0; b < 16; b++ )
    {
        controller[iCtrlIdx].button[b].button = -1;
        controller[iCtrlIdx].button[b].key = SDL_SCANCODE_UNKNOWN;
        controller[iCtrlIdx].button[b].axis = -1;
        controller[iCtrlIdx].button[b].axis_deadzone = -1;
        controller[iCtrlIdx].button[b].hat = -1;
        controller[iCtrlIdx].button[b].hat_pos = -1;
        controller[iCtrlIdx].button[b].mouse = -1;
    }
    for( b = 0; b < 2; b++ )
    {
        controller[iCtrlIdx].mouse_sens[b] = 2.0;
        controller[iCtrlIdx].axis_deadzone[b] = 4096;
        controller[iCtrlIdx].axis_peak[b] = 32768;
        controller[iCtrlIdx].axis[b].button_a = controller[iCtrlIdx].axis[b].button_b = -1;
        controller[iCtrlIdx].axis[b].key_a = controller[iCtrlIdx].axis[b].key_b = SDL_SCANCODE_UNKNOWN;
        controller[iCtrlIdx].axis[b].axis_a = -1;
        controller[iCtrlIdx].axis[b].axis_dir_a = 1;
        controller[iCtrlIdx].axis[b].axis_b = -1;
        controller[iCtrlIdx].axis[b].axis_dir_b = 1;
        controller[iCtrlIdx].axis[b].hat = -1;
        controller[iCtrlIdx].axis[b].hat_pos_a = -1;
        controller[iCtrlIdx].axis[b].hat_pos_b = -1;
    }
}

static const char * get_sdl_joystick_name(int iCtrlIdx)
{
    static char JoyName[256];
    const char *joySDLName;
    int joyWasInit = SDL_WasInit(SDL_INIT_JOYSTICK);
    
    /* initialize the joystick subsystem if necessary */
    if (!joyWasInit)
        if (SDL_InitSubSystem(SDL_INIT_JOYSTICK) == -1)
        {
            DebugMessage(M64MSG_ERROR, "Couldn't init SDL joystick subsystem: %s", SDL_GetError() );
            return NULL;
        }

    /* get the name of the corresponding joystick */
    joySDLName = SDL_JoystickName(iCtrlIdx);

    /* copy the name to our local string */
    if (joySDLName != NULL)
    {
        strncpy(JoyName, joySDLName, 255);
        JoyName[255] = 0;
    }

    /* quit the joystick subsystem if necessary */
    if (!joyWasInit)
        SDL_QuitSubSystem(SDL_INIT_JOYSTICK);

    /* if the SDL function had an error, then return NULL, otherwise return local copy of joystick name */
    if (joySDLName == NULL)
        return NULL;
    else
        return JoyName;
}

static int get_sdl_num_joysticks(void)
{
    int numJoysticks = 0;
    int joyWasInit = SDL_WasInit(SDL_INIT_JOYSTICK);
    
    /* initialize the joystick subsystem if necessary */
    if (!joyWasInit)
        if (SDL_InitSubSystem(SDL_INIT_JOYSTICK) == -1)
        {
            DebugMessage(M64MSG_ERROR, "Couldn't init SDL joystick subsystem: %s", SDL_GetError() );
            return 0;
        }

    /* get thenumber of joysticks */
    numJoysticks = SDL_NumJoysticks();

    /* quit the joystick subsystem if necessary */
    if (!joyWasInit)
        SDL_QuitSubSystem(SDL_INIT_JOYSTICK);

    return numJoysticks;
}

/////////////////////////////////////
// load_controller_config()
// return value: 1 = OK
//               0 = fail: couldn't open config section

static int load_controller_config(const char *SectionName, int i, int sdlDeviceIdx)
{
    m64p_handle pConfig;
    char input_str[256], value1_str[16], value2_str[16];
    const char *config_ptr;
    int j;

    /* Open the configuration section for this controller */
    if (ConfigOpenSection(SectionName, &pConfig) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_ERROR, "Couldn't open config section '%s'", SectionName);
        return 0;
    }

    /* set SDL device number */
    controller[i].device = sdlDeviceIdx;

    /* throw warnings if 'plugged' or 'plugin' are missing */
    if (ConfigGetParameter(pConfig, "plugged", M64TYPE_BOOL, &controller[i].control->Present, sizeof(int)) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_WARNING, "missing 'plugged' parameter from config section %s. Setting to 1 (true).", SectionName);
        controller[i].control->Present = 1;
    }
    if (ConfigGetParameter(pConfig, "plugin", M64TYPE_INT, &controller[i].control->Plugin, sizeof(int)) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_WARNING, "missing 'plugin' parameter from config section %s. Setting to 1 (none).", SectionName);
        controller[i].control->Plugin = PLUGIN_NONE;
    }
    /* load optional parameters */
    ConfigGetParameter(pConfig, "mouse", M64TYPE_BOOL, &controller[i].mouse, sizeof(int));
    if (ConfigGetParameter(pConfig, "MouseSensitivity", M64TYPE_STRING, input_str, 256) == M64ERR_SUCCESS)
    {
        if (sscanf(input_str, "%f,%f", &controller[i].mouse_sens[0], &controller[i].mouse_sens[1]) != 2)
            DebugMessage(M64MSG_WARNING, "parsing error in MouseSensitivity parameter for controller %i", i + 1);
    }
    if (ConfigGetParameter(pConfig, "AnalogDeadzone", M64TYPE_STRING, input_str, 256) == M64ERR_SUCCESS)
    {
        if (sscanf(input_str, "%i,%i", &controller[i].axis_deadzone[0], &controller[i].axis_deadzone[1]) != 2)
            DebugMessage(M64MSG_WARNING, "parsing error in AnalogDeadzone parameter for controller %i", i + 1);
    }
    if (ConfigGetParameter(pConfig, "AnalogPeak", M64TYPE_STRING, input_str, 256) == M64ERR_SUCCESS)
    {
        if (sscanf(input_str, "%i,%i", &controller[i].axis_peak[0], &controller[i].axis_peak[1]) != 2)
            DebugMessage(M64MSG_WARNING, "parsing error in AnalogPeak parameter for controller %i", i + 1);
    }
    /* load configuration for all the digital buttons */
    for (j = 0; j < X_AXIS; j++)
    {
        if (ConfigGetParameter(pConfig, button_names[j], M64TYPE_STRING, input_str, 256) != M64ERR_SUCCESS)
        {
            DebugMessage(M64MSG_WARNING, "missing config key '%s' for controller %i button %i", button_names[j], i+1, j);
            continue;
        }
        if ((config_ptr = strstr(input_str, "key")) != NULL)
            if (sscanf(config_ptr, "key(%i)", (int *) &controller[i].button[j].key) != 1)
                DebugMessage(M64MSG_WARNING, "parsing error in key() parameter of button '%s' for controller %i", button_names[j], i + 1);
        if ((config_ptr = strstr(input_str, "button")) != NULL)
            if (sscanf(config_ptr, "button(%i)", &controller[i].button[j].button) != 1)
                DebugMessage(M64MSG_WARNING, "parsing error in button() parameter of button '%s' for controller %i", button_names[j], i + 1);
        if ((config_ptr = strstr(input_str, "axis")) != NULL)
        {
            char chAxisDir;
            if (sscanf(config_ptr, "axis(%d%c,%d", &controller[i].button[j].axis, &chAxisDir, &controller[i].button[j].axis_deadzone) != 3 &&
                sscanf(config_ptr, "axis(%i%c", &controller[i].button[j].axis, &chAxisDir) != 2)
                DebugMessage(M64MSG_WARNING, "parsing error in axis() parameter of button '%s' for controller %i", button_names[j], i + 1);
            controller[i].button[j].axis_dir = (chAxisDir == '+' ? 1 : (chAxisDir == '-' ? -1 : 0));
        }
        if ((config_ptr = strstr(input_str, "hat")) != NULL)
        {
            char *lastchar = NULL;
            if (sscanf(config_ptr, "hat(%i %15s", &controller[i].button[j].hat, value1_str) != 2)
                DebugMessage(M64MSG_WARNING, "parsing error in hat() parameter of button '%s' for controller %i", button_names[j], i + 1);
            value1_str[15] = 0;
            /* chop off the last character of value1_str if it is the closing parenthesis */
            lastchar = &value1_str[strlen(value1_str) - 1];
            if (lastchar > value1_str && *lastchar == ')') *lastchar = 0;
            controller[i].button[j].hat_pos = get_hat_pos_by_name(value1_str);
        }
        if ((config_ptr = strstr(input_str, "mouse")) != NULL)
            if (sscanf(config_ptr, "mouse(%i)", &controller[i].button[j].mouse) != 1)
                DebugMessage(M64MSG_WARNING, "parsing error in mouse() parameter of button '%s' for controller %i", button_names[j], i + 1);
    }
    /* load configuration for the 2 analog joystick axes */
    for (j = X_AXIS; j <= Y_AXIS; j++)
    {
        int axis_idx = j - X_AXIS;
        if (ConfigGetParameter(pConfig, button_names[j], M64TYPE_STRING, input_str, 256) != M64ERR_SUCCESS)
        {
            DebugMessage(M64MSG_WARNING, "missing config key '%s' for controller %i axis %i", button_names[j], i+1, axis_idx);
            continue;
        }
        if ((config_ptr = strstr(input_str, "key")) != NULL)
            if (sscanf(config_ptr, "key(%i,%i)", (int *) &controller[i].axis[axis_idx].key_a, (int *) &controller[i].axis[axis_idx].key_b) != 2)
                DebugMessage(M64MSG_WARNING, "parsing error in key() parameter of axis '%s' for controller %i", button_names[j], i + 1);
        if ((config_ptr = strstr(input_str, "button")) != NULL)
            if (sscanf(config_ptr, "button(%i,%i)", &controller[i].axis[axis_idx].button_a, &controller[i].axis[axis_idx].button_b) != 2)
                DebugMessage(M64MSG_WARNING, "parsing error in button() parameter of axis '%s' for controller %i", button_names[j], i + 1);
        if ((config_ptr = strstr(input_str, "axis")) != NULL)
        {
            char chAxisDir1, chAxisDir2;
            if (sscanf(config_ptr, "axis(%i%c,%i%c)", &controller[i].axis[axis_idx].axis_a, &chAxisDir1,
                                                      &controller[i].axis[axis_idx].axis_b, &chAxisDir2) != 4)
                DebugMessage(M64MSG_WARNING, "parsing error in axis() parameter of axis '%s' for controller %i", button_names[j], i + 1);
            controller[i].axis[axis_idx].axis_dir_a = (chAxisDir1 == '+' ? 1 : (chAxisDir1 == '-' ? -1 : 0));
            controller[i].axis[axis_idx].axis_dir_b = (chAxisDir2 == '+' ? 1 : (chAxisDir2 == '-' ? -1 : 0));
        }
        if ((config_ptr = strstr(input_str, "hat")) != NULL)
        {
            char *lastchar = NULL;
            if (sscanf(config_ptr, "hat(%i %15s %15s", &controller[i].axis[axis_idx].hat, value1_str, value2_str) != 3)
                DebugMessage(M64MSG_WARNING, "parsing error in hat() parameter of axis '%s' for controller %i", button_names[j], i + 1);
            value1_str[15] = value2_str[15] = 0;
            /* chop off the last character of value2_str if it is the closing parenthesis */
            lastchar = &value2_str[strlen(value2_str) - 1];
            if (lastchar > value2_str && *lastchar == ')') *lastchar = 0;
            controller[i].axis[axis_idx].hat_pos_a = get_hat_pos_by_name(value1_str);
            controller[i].axis[axis_idx].hat_pos_b = get_hat_pos_by_name(value2_str);
        }
    }

    return 1;
}

static void init_controller_config(int iCtrlIdx, const char *pccDeviceName, eModeType mode)
{
    m64p_handle pConfig;
    char SectionName[32], Param[32], ParamString[128];
    int j;

    /* Delete the configuration section for this controller, so we can use SetDefaults and save the help comments also */
    sprintf(SectionName, "Input-SDL-Control%i", iCtrlIdx + 1);
    ConfigDeleteSection(SectionName);
    /* Open the configuration section for this controller (create a new one) */
    if (ConfigOpenSection(SectionName, &pConfig) != M64ERR_SUCCESS)
    {
        DebugMessage(M64MSG_ERROR, "Couldn't open config section '%s'", SectionName);
        return;
    }

    /* save the general controller parameters */
    ConfigSetDefaultFloat(pConfig, "version", CONFIG_VERSION, "Mupen64Plus SDL Input Plugin config parameter version number.  Please don't change this version number.");
    ConfigSetDefaultInt(pConfig, "mode", (int) mode, "Controller configuration mode: 0=Fully Manual, 1=Auto with named SDL Device, 2=Fully automatic");
    ConfigSetDefaultInt(pConfig, "device", controller[iCtrlIdx].device, "Specifies which joystick is bound to this controller: -1=No joystick, 0 or more= SDL Joystick number");
    ConfigSetDefaultString(pConfig, "name", pccDeviceName, "SDL joystick name (or Keyboard)");
    ConfigSetDefaultBool(pConfig, "plugged", controller[iCtrlIdx].control->Present, "Specifies whether this controller is 'plugged in' to the simulated N64");
    ConfigSetDefaultInt(pConfig, "plugin", controller[iCtrlIdx].control->Plugin, "Specifies which type of expansion pak is in the controller: 1=None, 2=Mem pak, 5=Rumble pak");
    ConfigSetDefaultBool(pConfig, "mouse", controller[iCtrlIdx].mouse, "If True, then mouse buttons may be used with this controller");

    sprintf(Param, "%.2f,%.2f", controller[iCtrlIdx].mouse_sens[0], controller[iCtrlIdx].mouse_sens[1]);
    ConfigSetDefaultString(pConfig, "MouseSensitivity", Param, "Scaling factor for mouse movements.  For X, Y axes.");
    sprintf(Param, "%i,%i", controller[iCtrlIdx].axis_deadzone[0], controller[iCtrlIdx].axis_deadzone[1]);
    ConfigSetDefaultString(pConfig, "AnalogDeadzone", Param, "The minimum absolute value of the SDL analog joystick axis to move the N64 controller axis value from 0.  For X, Y axes.");
    sprintf(Param, "%i,%i", controller[iCtrlIdx].axis_peak[0], controller[iCtrlIdx].axis_peak[1]);
    ConfigSetDefaultString(pConfig, "AnalogPeak", Param, "An absolute value of the SDL joystick axis >= AnalogPeak will saturate the N64 controller axis value (at 80).  For X, Y axes. For each axis, this must be greater than the corresponding AnalogDeadzone value");

    /* save configuration for all the digital buttons */
    for (j = 0; j < X_AXIS; j++ )
    {
        const char *Help;
        int len = 0;
        ParamString[0] = 0;
        if (controller[iCtrlIdx].button[j].key > 0)
        {
            sprintf(Param, "key(%i) ", controller[iCtrlIdx].button[j].key);
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].button[j].button >= 0)
        {
            sprintf(Param, "button(%i) ", controller[iCtrlIdx].button[j].button);
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].button[j].axis >= 0)
        {
            if (controller[iCtrlIdx].button[j].axis_deadzone >= 0)
                sprintf(Param, "axis(%i%c,%i) ", controller[iCtrlIdx].button[j].axis, (controller[iCtrlIdx].button[j].axis_dir == -1) ? '-' : '+',
                        controller[iCtrlIdx].button[j].axis_deadzone);
            else
                sprintf(Param, "axis(%i%c) ", controller[iCtrlIdx].button[j].axis, (controller[iCtrlIdx].button[j].axis_dir == -1) ? '-' : '+');
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].button[j].hat >= 0)
        {
            sprintf(Param, "hat(%i %s) ", controller[iCtrlIdx].button[j].hat, HAT_POS_NAME(controller[iCtrlIdx].button[j].hat_pos));
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].button[j].mouse >= 0)
        {
            sprintf(Param, "mouse(%i) ", controller[iCtrlIdx].button[j].mouse);
            strcat(ParamString, Param);
        }
        if (j == 0)
            Help = "Digital button configuration mappings";
        else
            Help = NULL;
        /* if last character is a space, chop it off */
        len = strlen(ParamString);
        if (len > 0 && ParamString[len-1] == ' ')
            ParamString[len-1] = 0;
        ConfigSetDefaultString(pConfig, button_names[j], ParamString, Help);
    }

    /* save configuration for the 2 analog axes */
    for (j = 0; j < 2; j++ )
    {
        const char *Help;
        int len = 0;
        ParamString[0] = 0;
        if (controller[iCtrlIdx].axis[j].key_a > 0 && controller[iCtrlIdx].axis[j].key_b > 0)
        {
            sprintf(Param, "key(%i,%i) ", controller[iCtrlIdx].axis[j].key_a, controller[iCtrlIdx].axis[j].key_b);
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].axis[j].button_a >= 0 && controller[iCtrlIdx].axis[j].button_b >= 0)
        {
            sprintf(Param, "button(%i,%i) ", controller[iCtrlIdx].axis[j].button_a, controller[iCtrlIdx].axis[j].button_b);
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].axis[j].axis_a >= 0 && controller[iCtrlIdx].axis[j].axis_b >= 0)
        {
            sprintf(Param, "axis(%i%c,%i%c) ", controller[iCtrlIdx].axis[j].axis_a, (controller[iCtrlIdx].axis[j].axis_dir_a <= 0) ? '-' : '+',
                                               controller[iCtrlIdx].axis[j].axis_b, (controller[iCtrlIdx].axis[j].axis_dir_b <= 0) ? '-' : '+' );
            strcat(ParamString, Param);
        }
        if (controller[iCtrlIdx].axis[j].hat >= 0)
        {
            sprintf(Param, "hat(%i %s %s) ", controller[iCtrlIdx].axis[j].hat,
                                             HAT_POS_NAME(controller[iCtrlIdx].axis[j].hat_pos_a),
                                             HAT_POS_NAME(controller[iCtrlIdx].axis[j].hat_pos_b));
            strcat(ParamString, Param);
        }
        if (j == 0)
            Help = "Analog axis configuration mappings";
        else
            Help = NULL;
        /* if last character is a space, chop it off */
        len = strlen(ParamString);
        if (len > 0 && ParamString[len-1] == ' ')
            ParamString[len-1] = 0;
        ConfigSetDefaultString(pConfig, button_names[X_AXIS + j], ParamString, Help);
    }

}

static int setup_auto_controllers(int bPreConfig, int n64CtrlStart, int sdlCtrlIdx, const char *sdlJoyName, eModeType ControlMode[], eModeType OrigControlMode[], char DeviceName[][256])
{
    char SectionName[32];
    int ActiveControllers = 0;
    int j;

    /* create auto-config section(s) for this joystick (if this joystick is in the InputAutoConfig.ini) */
    int ControllersFound = auto_set_defaults(sdlCtrlIdx, sdlJoyName);
    if (ControllersFound == 0)
        return 0;

    /* copy the auto-config settings to the controller config section, and load our plugin joystick config from this */
    sprintf(SectionName, "Input-SDL-Control%i", n64CtrlStart + 1);
    if (OrigControlMode[n64CtrlStart] == E_MODE_FULL_AUTO)
        auto_copy_inputconfig("AutoConfig0", SectionName, sdlJoyName);
    else
        auto_copy_inputconfig("AutoConfig0", SectionName, NULL);  // don't overwrite 'name' parameter if original mode was "named auto"
    if (load_controller_config("AutoConfig0", n64CtrlStart, sdlCtrlIdx) > 0)
    {
        if (!bPreConfig)
            DebugMessage(M64MSG_INFO, "N64 Controller #%i: Using auto-config with SDL joystick %i ('%s')", n64CtrlStart+1, sdlCtrlIdx, sdlJoyName);
        ActiveControllers++;
        ConfigSaveSection(SectionName);
    }
    else
    {
        if (!bPreConfig)
            DebugMessage(M64MSG_ERROR, "Autoconfig data invalid for SDL joystick '%s'", sdlJoyName);
    }
    ConfigDeleteSection("AutoConfig0");

    /* we have to handle the unfortunate case of a USB device mapping more than > 1 controller */
    if (ControllersFound > 1)
    {
        for (j = 1; j < ControllersFound; j++)
        {
            char AutoSectionName[32];
            sprintf(AutoSectionName, "AutoConfig%i", j);
            /* if this would be > 4th controller, then just delete the auto-config */
            if (n64CtrlStart + j >= 4)
            {
                ConfigDeleteSection(AutoSectionName);
                continue;
            }
            /* look for another N64 controller that is in AUTO mode */
            if (ControlMode[n64CtrlStart+j] == E_MODE_FULL_AUTO ||
                (ControlMode[n64CtrlStart+j] == E_MODE_NAMED_AUTO && strncmp(DeviceName[n64CtrlStart+j], sdlJoyName, 255) == 0))
            {
                sprintf(SectionName, "Input-SDL-Control%i", n64CtrlStart + j + 1);
                /* load our plugin joystick settings from the autoconfig */
                if (load_controller_config(AutoSectionName, n64CtrlStart+j, sdlCtrlIdx) > 0)
                {
                    /* copy the auto-config settings to the controller config section */
                    if (OrigControlMode[n64CtrlStart+j] == E_MODE_FULL_AUTO)
                        auto_copy_inputconfig(AutoSectionName, SectionName, sdlJoyName);
                    else
                        auto_copy_inputconfig(AutoSectionName, SectionName, NULL);  // don't overwrite 'name' parameter if original mode was "named auto"
                    if (!bPreConfig)
                        DebugMessage(M64MSG_INFO, "N64 Controller #%i: Using auto-config with SDL joystick %i ('%s')", n64CtrlStart+j+1, sdlCtrlIdx, sdlJoyName);
                    ActiveControllers++;
                    ConfigSaveSection(SectionName);
                    /* set the local controller mode to Manual so that we won't re-configure this controller in the next loop */
                    ControlMode[n64CtrlStart+j] = E_MODE_MANUAL;
                }
                else
                {
                    if (!bPreConfig)
                        DebugMessage(M64MSG_ERROR, "Autoconfig data invalid for SDL device '%s'", sdlJoyName);
                }
                /* delete the autoconfig section */
                ConfigDeleteSection(AutoSectionName);
            }
        }
    }

    return ActiveControllers;
}

/* global functions */

/* There are 4 special section parameters: version, mode, device, and name.  There are also 24 regular
 * parameters: plugged, plugin, mouse, MouseSensitivity, DPad R/L/D/U, Start, Z/L/R Trigger, A/B button,
 * C Button R/L/D/U, Mempak/Rumblepak switch, X/Y Axis, AnalogDeadzone, AnalogPeak.
 *
 * The N64 controller configuration behavior is regulated by the 'mode' parameter.  If this parameter is
 * 0 (Fully Manual), then all configuration data is loaded and parsed without changes or autoconfig from
 * the configuration section.  Any errors or warnings are printed.  If the mode parameter is 1 (Auto with
 * named SDL Device), then the code below searches through the available SDL joysticks for one which
 * matches with the 'name' parameter in the config section.  If a match is found, then the corresponding
 * autoconfig is loaded and the regular parameters from the config section are updated with the
 * autoconfig'ed settings.  If the mode parameter is 2 (Fully Auto), then the code below searches through
 * all available detected SDL joysticks to try and find an autoconfig for each.  If an autoconfig match is
 * found, then it is loaded and all config parameters (including device, name, and the regular parameters)
 * are updated.
 *
 * This function is called with bPreConfig=true from the PluginStartup() function.  The purpose of this
 * call is to load the 4 configuration sections with autoconfig data if necessary for a GUI front-end.
 * When we are called with bPreConfig=true, we should only print warning/error messages and not info/status.
 * This function is also called right before running the ROM game from InitiateControllers() with
 * bPreConfig=false.  We should only print informational messages here, because we do not want to duplicate
 * console output with the console-ui front-end (since the PluginStart() and InitiateControllers()
 * functions are called in quick sequence from the console-ui).
 */
  
void load_configuration(int bPreConfig)
{
    char SectionName[32];
    int joy_plugged = 0;
    int n64CtrlIdx, sdlCtrlIdx, j;
    int sdlNumDevUsed = 0;
    int sdlDevicesUsed[4];
    eModeType OrigControlMode[4], ControlMode[4];
    int ControlDevice[4];
    char DeviceName[4][256];
    int ActiveControllers = 0;
    int sdlNumJoysticks = get_sdl_num_joysticks();
    float fVersion = 0.0f;
    const char *sdl_name;
    int ControllersFound = 0;

    /* tell user how many SDL joysticks are available */
    if (!bPreConfig)
        DebugMessage(M64MSG_INFO, "%i SDL joysticks were found.", sdlNumJoysticks);

    /* loop through 4 N64 controllers, initializing and validating special section parameters */
    for (n64CtrlIdx=0; n64CtrlIdx < 4; n64CtrlIdx++)
    {
        m64p_handle pConfig;
        /* reset the controller configuration */
        clear_controller(n64CtrlIdx);

        /* Open the configuration section for this controller */
        sprintf(SectionName, "Input-SDL-Control%i", n64CtrlIdx + 1);
        if (ConfigOpenSection(SectionName, &pConfig) != M64ERR_SUCCESS)
        {
            // this should never happen
            DebugMessage(M64MSG_ERROR, "Couldn't open config section '%s'.  Aborting...", SectionName);
            return;
        }
        /* Check version number, and if it doesn't match: delete the config section */
        fVersion = 0.0f;
        if (ConfigGetParameter(pConfig, "version", M64TYPE_FLOAT, &fVersion, sizeof(float)) != M64ERR_SUCCESS || ((int) fVersion) != ((int) CONFIG_VERSION))
        {
            DebugMessage(M64MSG_WARNING, "Missing or incompatible config section '%s'. Clearing.", SectionName);
            ConfigDeleteSection(SectionName);
            // set local controller default parameters
            OrigControlMode[n64CtrlIdx] = ControlMode[n64CtrlIdx] = E_MODE_FULL_AUTO;
            ControlDevice[n64CtrlIdx] = DEVICE_NO_JOYSTICK;
            DeviceName[n64CtrlIdx][0] = 0;
            // write blank config for GUI front-ends
            init_controller_config(n64CtrlIdx, "", E_MODE_FULL_AUTO);
            // save it to the file too
            ConfigSaveSection(SectionName);
        }
        else
        {
            if (ConfigGetParameter(pConfig, "mode", M64TYPE_INT, &OrigControlMode[n64CtrlIdx], sizeof(int)) != M64ERR_SUCCESS ||
                (int) OrigControlMode[n64CtrlIdx] < 0 || (int) OrigControlMode[n64CtrlIdx] > 2)
            {
                if (!bPreConfig)
                    DebugMessage(M64MSG_WARNING, "Missing or invalid 'mode' parameter in config section '%s'.  Setting to 2 (Fully Auto)", SectionName);
                OrigControlMode[n64CtrlIdx] = E_MODE_FULL_AUTO;
            }
            ControlMode[n64CtrlIdx] = OrigControlMode[n64CtrlIdx];
            if (ConfigGetParameter(pConfig, "device", M64TYPE_INT, &ControlDevice[n64CtrlIdx], sizeof(int)) != M64ERR_SUCCESS)
            {
                if (!bPreConfig)
                    DebugMessage(M64MSG_WARNING, "Missing 'device' parameter in config section '%s'.  Setting to -1 (No joystick)", SectionName);
                ControlDevice[n64CtrlIdx] = DEVICE_NO_JOYSTICK;
            }
            if (ConfigGetParameter(pConfig, "name", M64TYPE_STRING, DeviceName[n64CtrlIdx], 256) != M64ERR_SUCCESS)
            {
                DeviceName[n64CtrlIdx][0] = 0;
            }
        }
    }

    /* loop through 4 N64 controllers and set up those in Fully Manual mode */
    for (n64CtrlIdx=0; n64CtrlIdx < 4; n64CtrlIdx++)
    {
        if (ControlMode[n64CtrlIdx] != E_MODE_MANUAL)
            continue;
        /* load the stored configuration (disregard any errors) */
        sprintf(SectionName, "Input-SDL-Control%i", n64CtrlIdx + 1);
        load_controller_config(SectionName, n64CtrlIdx, ControlDevice[n64CtrlIdx]);
        /* if this config uses an SDL joystick, mark it as used */
        if (ControlDevice[n64CtrlIdx] == DEVICE_NO_JOYSTICK)
        {
            if (!bPreConfig)
                DebugMessage(M64MSG_INFO, "N64 Controller #%i: Using manual config with no SDL joystick (keyboard/mouse only)", n64CtrlIdx+1);
        }
        else
        {
            sdlDevicesUsed[sdlNumDevUsed++] = ControlDevice[n64CtrlIdx];
            if (!bPreConfig)
                DebugMessage(M64MSG_INFO, "N64 Controller #%i: Using manual config for SDL joystick %i", n64CtrlIdx+1, ControlDevice[n64CtrlIdx]);
        }
        ActiveControllers++;
    }

    /* now loop through again, setting up those in Named Auto mode */
    for (n64CtrlIdx=0; n64CtrlIdx < 4; n64CtrlIdx++)
    {
        if (ControlMode[n64CtrlIdx] != E_MODE_NAMED_AUTO)
            continue;
        /* if name is empty, then use full auto mode instead */
        if (DeviceName[n64CtrlIdx][0] == 0)
        {
            ControlMode[n64CtrlIdx] = E_MODE_FULL_AUTO;
            continue;
        }
        sprintf(SectionName, "Input-SDL-Control%i", n64CtrlIdx + 1);
        /* if user is looking for a keyboard, set that up */
        if (strcasecmp(DeviceName[n64CtrlIdx], "Keyboard") == 0)
        {
            auto_set_defaults(DEVICE_NO_JOYSTICK, "Keyboard");
            if (load_controller_config("AutoConfig0", n64CtrlIdx, DEVICE_NO_JOYSTICK) > 0)
            {
                if (!bPreConfig)
                    DebugMessage(M64MSG_INFO, "N64 Controller #%i: Using auto-config for keyboard", n64CtrlIdx+1);
                /* copy the auto-config settings to the controller config section */
                auto_copy_inputconfig("AutoConfig0", SectionName, "Keyboard");
                ActiveControllers++;
                ConfigSaveSection(SectionName);
            }
            else
            {
                DebugMessage(M64MSG_ERROR, "Autoconfig keyboard setup invalid");
            }
            ConfigDeleteSection("AutoConfig0");
            continue;
        }
        /* search for an unused SDL device with the matching name */
        for (sdlCtrlIdx=0; sdlCtrlIdx < sdlNumJoysticks; sdlCtrlIdx++)
        {
            /* check if this one is in use */
            int deviceAlreadyUsed = 0;
            for (j = 0; j < sdlNumDevUsed; j++)
            {
                if (sdlDevicesUsed[j] == sdlCtrlIdx)
                    deviceAlreadyUsed = 1;
            }
            if (deviceAlreadyUsed)
                continue;
            /* check if the name matches */
            sdl_name = get_sdl_joystick_name(sdlCtrlIdx);
            if (sdl_name != NULL && strncmp(DeviceName[n64CtrlIdx], sdl_name, 255) == 0)
            {
                /* set up one or more controllers for this SDL device, if present in InputAutoConfig.ini */
                int ControllersFound = setup_auto_controllers(bPreConfig, n64CtrlIdx, sdlCtrlIdx, sdl_name, ControlMode, OrigControlMode, DeviceName);
                if (ControllersFound == 0)
                {
                    // error: no auto-config found for this SDL device
                    DebugMessage(M64MSG_ERROR, "No auto-config found for joystick named '%s' in InputAutoConfig.ini", sdl_name);
                    // mark this device as being used just so we don't complain about it again
                    sdlDevicesUsed[sdlNumDevUsed++] = sdlCtrlIdx;
                    // quit looking for SDL joysticks which match the name, because there's no valid autoconfig for that name.
                    // this controller will be unused; skip to the next one
                    break;
                }
                /* mark this sdl device as used */
                sdlDevicesUsed[sdlNumDevUsed++] = sdlCtrlIdx;
                ActiveControllers += ControllersFound;
                break;
            }
        }
        /* if we didn't find a match for this joystick name, then set the controller to fully auto */
        if (sdlCtrlIdx == sdlNumJoysticks)
        {
            if (!bPreConfig)
                DebugMessage(M64MSG_WARNING, "N64 Controller #%i: No SDL joystick found matching name '%s'.  Using full auto mode.", n64CtrlIdx+1, DeviceName[n64CtrlIdx]);
            ControlMode[n64CtrlIdx] = E_MODE_FULL_AUTO;
        }
    }

    /* Final loop through N64 controllers, setting up those in Full Auto mode */
    for (n64CtrlIdx=0; n64CtrlIdx < 4; n64CtrlIdx++)
    {
        if (ControlMode[n64CtrlIdx] != E_MODE_FULL_AUTO)
            continue;
        sprintf(SectionName, "Input-SDL-Control%i", n64CtrlIdx + 1);
        /* search for an unused SDL device */
        for (sdlCtrlIdx=0; sdlCtrlIdx < sdlNumJoysticks; sdlCtrlIdx++)
        {
            /* check if this one is in use */
            int deviceAlreadyUsed = 0;
            for (j = 0; j < sdlNumDevUsed; j++)
            {
                if (sdlDevicesUsed[j] == sdlCtrlIdx)
                    deviceAlreadyUsed = 1;
            }
            if (deviceAlreadyUsed)
                continue;
            /* set up one or more controllers for this SDL device, if present in InputAutoConfig.ini */
            sdl_name = get_sdl_joystick_name(sdlCtrlIdx);
            ControllersFound = setup_auto_controllers(bPreConfig, n64CtrlIdx, sdlCtrlIdx, sdl_name, ControlMode, OrigControlMode, DeviceName);
            if (!bPreConfig && ControllersFound == 0)
            {
                // error: no auto-config found for this SDL device
                DebugMessage(M64MSG_ERROR, "No auto-config found for joystick named '%s' in InputAutoConfig.ini", sdl_name);
                // mark this device as being used just so we don't complain about it again
                sdlDevicesUsed[sdlNumDevUsed++] = sdlCtrlIdx;
                // keep trying more SDL devices to see if we can auto-config one for this N64 controller
                continue;
            }
            /* mark this sdl device as used */
            sdlDevicesUsed[sdlNumDevUsed++] = sdlCtrlIdx;
            ActiveControllers += ControllersFound;
            break;
        }
        /* if this N64 controller was not activated, set device to -1 */
        if (sdlCtrlIdx == sdlNumJoysticks)
        {
            m64p_handle section;
            if (ConfigOpenSection(SectionName, &section) == M64ERR_SUCCESS)
            {
                const int iNoDevice = -1;
                ConfigSetParameter(section, "device", M64TYPE_INT, &iNoDevice);
                if (OrigControlMode[n64CtrlIdx] == E_MODE_FULL_AUTO)
                    ConfigSetParameter(section, "name", M64TYPE_STRING, "");
                ConfigSaveSection(SectionName);
            }
        }
    }

    /* fallback to keyboard if no controllers were configured */
    if (ActiveControllers == 0)
    {
        if (!bPreConfig)
            DebugMessage(M64MSG_INFO, "N64 Controller #1: Forcing default keyboard configuration");
        auto_set_defaults(DEVICE_NO_JOYSTICK, "Keyboard");
        if (load_controller_config("AutoConfig0", 0, DEVICE_NO_JOYSTICK) > 0)
        {
            /* copy the auto-config settings to the controller config section */
            if (OrigControlMode[0] == E_MODE_FULL_AUTO)
                auto_copy_inputconfig("AutoConfig0", "Input-SDL-Control1", "Keyboard");
            else
                auto_copy_inputconfig("AutoConfig0", "Input-SDL-Control1", NULL);  // don't overwrite 'name' parameter
            ActiveControllers++;
            ConfigSaveSection("Input-SDL-Control1");
        }
        else
        {
            DebugMessage(M64MSG_ERROR, "Autoconfig keyboard setup invalid");
        }
        ConfigDeleteSection("AutoConfig0");
    }

    /* see how many joysticks are plugged in */
    joy_plugged = 0;
    for (j = 0; j < 4; j++)
    {
        if (controller[j].control->Present)
            joy_plugged++;
    }

    /* print out summary info message */
    if (!bPreConfig)
    {
        if (joy_plugged > 0)
        {
            DebugMessage(M64MSG_INFO, "%i controller(s) found, %i plugged in and usable in the emulator", ActiveControllers, joy_plugged);
        }
        else
        {
            if (ActiveControllers == 0)
                DebugMessage(M64MSG_WARNING, "No joysticks/controllers found");
            else
                DebugMessage(M64MSG_WARNING, "%i controllers found, but none were 'plugged in'", ActiveControllers);
        }
    }

}


