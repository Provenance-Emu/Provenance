/*  Copyright 2009 Lawrence Sebald

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include <stdio.h>

#include "macjoy.h"
#include "permacjoy.h"
#include "debug.h"

int PERMacJoyInit(void);
void PERMacJoyDeInit(void);
int PERMacJoyHandleEvents(void);

u32 PERMacJoyScan(u32 flags);
void PERMacJoyFlush(void);
void PERMacJoyKeyName(u32 key, char *name, int size);

PerInterface_struct PERMacJoy = {
    PERCORE_MACJOY,
    "Mac OS X (IOKit) Joystick Interface",
    PERMacJoyInit,
    PERMacJoyDeInit,
    PERMacJoyHandleEvents,
    PERMacJoyScan,
    1,
    PERMacJoyFlush,
    PERMacJoyKeyName
};

static int initted = 0;
static int joycount = 0;
static joydata_t **joys = NULL;

#define AXIS_POSITIVE_VALUE 0x800000
#define AXIS_NEGATIVE_VALUE 0xC00000
#define HAT_VALUE           0xA00000

#define MIDDLE(x, y) (((x) + (y)) / 2)

int PERMacJoyInit(void) {
    int i;

    /* Don't bother trying to init the thing again. */
    if(initted)
        return 0;

    /* Grab the number of joysticks connected to the system. */
    joycount = joy_scan_joysticks();
    if(joycount == -1)  {
        joycount = 0;
        return -1;
    }

    joys = (joydata_t **)malloc(sizeof(joydata_t *) * joycount);
    if(!joys)   {
        joycount = 0;
        return -1;
    }

    /* Grab each joystick and open it. */
    for(i = 0; i < joycount; ++i)   {
        joys[i] = joy_get_joystick(i);

        if(joys[i] == NULL)
            continue;

        if(!joy_open_joystick(joys[i])) {
            joys[i] = NULL;
            continue;
        }
    }

    initted = 1;

    return 0;
}

void PERMacJoyDeInit(void)  {
    int i;

    if(!initted)
        return;

    /* Close each joystick. */
    for(i = 0; i < joycount; ++i)   {
        joy_close_joystick(joys[i]);
    }

    free(joys);
    joys = NULL;
    joycount = 0;
    initted = 0;
}

int PERMacJoyHandleEvents(void) {
    int i, j, k, data;
    joydata_t *joy;

    /* Check each joystick. */
    for(i = 0; i < joycount; ++i)   {
        joy = joys[i];

        if(!joy)    {
            continue;
        }

        /* Handle each axis. */
        for(j = 0; j < joy->axes_count; ++j)    {
            int midpoint = MIDDLE(joy->axes[j].min, joy->axes[j].max);

            data = joy_read_axis(joy, j);

            if(joy->axes[j].max > 0 &&
               data > MIDDLE(midpoint, joy->axes[j].max))   {
                PerKeyDown((i << 24) | AXIS_POSITIVE_VALUE | j);
                PerKeyUp((i << 24) | AXIS_NEGATIVE_VALUE | j);
            }
            else if(joy->axes[j].min < 0 &&
                    data < MIDDLE(midpoint, joy->axes[j].min))  {
                PerKeyUp((i << 24) | AXIS_POSITIVE_VALUE | j);
                PerKeyDown((i << 24) | AXIS_NEGATIVE_VALUE | j);
            }
            else    {
                PerKeyUp((i << 24) | AXIS_POSITIVE_VALUE | j);
                PerKeyUp((i << 24) | AXIS_NEGATIVE_VALUE | j);
            }
        }

        /* Handle each button. */
        for(j = 1; j <= joy->buttons_count; ++j)    {
            data = joy_read_button(joy, j);

            if(data > joy->buttons[j].min)  {
                PerKeyDown((i << 24) | j);
            }
            else    {
                PerKeyUp((i << 24) | j);
            }
        }

        /* Handle any hats. */
        for(j = 0; j < joy->hats_count; ++j)    {
            data = joy_read_element(joy, joy->hats + j);

            for(k = joy->hats[j].min; k < joy->hats[j].max; ++k)    {
                if(data == k)   {
                    PerKeyDown((i << 24) | HAT_VALUE | (k << 8) | j);
                }
                else    {
                    PerKeyUp((i << 24) | HAT_VALUE | (k << 8) | j);
                }
            }
        }
    }

    if(YabauseExec() != 0)  {
        return -1;
    }

    return 0;
}

u32 PERMacJoyScan(u32 flags) {
    int i, j, k, data;
    joydata_t *joy;

    /* Check each joystick. */
    for(i = 0; i < joycount; ++i)   {
        joy = joys[i];

        if(!joy)    {
            continue;
        }

        /* Handle each axis. */
        for(j = 0; j < joy->axes_count; ++j)    {
            int midpoint = MIDDLE(joy->axes[j].min, joy->axes[j].max);

            data = joy_read_axis(joy, j);

            if(joy->axes[j].max > 0 &&
               data > MIDDLE(midpoint, joy->axes[j].max))   {
                return ((i << 24) | AXIS_POSITIVE_VALUE | j);
            }
            else if(joy->axes[j].min < 0 && 
                    data < MIDDLE(midpoint, joy->axes[j].min))  {
                return ((i << 24) | AXIS_NEGATIVE_VALUE | j);
            }
        }

        /* Handle each button. */
        for(j = 1; j <= joy->buttons_count; ++j)    {
            data = joy_read_button(joy, j);

            if(data > joy->buttons[j].min)  {
                return ((i << 24) | j);
            }
        }

        /* Handle any hats. */
        for(j = 0; j < joy->hats_count; ++j)    {
            data = joy_read_element(joy, joy->hats + j);

            for(k = joy->hats[j].min; k < joy->hats[j].max; ++k)    {
                if(data == k)   {
                    return ((i << 24) | HAT_VALUE | (k << 8) | j);
                }
            }
        }
    }

    return 0;
}

void PERMacJoyFlush(void)   {
    /* Nothing. */
}

void PERMacJoyKeyName(u32 key, char *name, int size)    {
    snprintf(name, size, "%x", (unsigned int)key);
}
