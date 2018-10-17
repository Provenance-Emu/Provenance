/*  Copyright 2005-2008 Lawrence Sebald

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

#include "perdc.h"
#include "../yabause.h"
#include "../yui.h"
#include "../vdp2.h"

#include <dc/maple.h>
#include <dc/maple/controller.h>

int PERDCInit(void);
void PERDCDeInit(void);
int PERDCHandleEvents(void);
void PERDCNothing(void);
u32 PERDCScan(u32 flags);
void PERDCKeyName(u32 key, char *name, int size);

static PerPad_struct *pad1;

PerInterface_struct PERDC = {
    PERCORE_DC,
    "Dreamcast Input Interface",
    PERDCInit,
    PERDCDeInit,
    PERDCHandleEvents,
    PERDCScan,
    0,
    PERDCNothing,
    PERDCKeyName
};

int PERDCInit(void)	{
    PerPortReset();
    pad1 = PerPadAdd(&PORTDATA1);
	return 0;
}

void PERDCDeInit(void)	{
}

int PERDCHandleEvents(void)	{
    maple_device_t *dev;

    dev = maple_enum_type(0, MAPLE_FUNC_CONTROLLER);
    if(dev != NULL) {
        cont_state_t *state = (cont_state_t *) maple_dev_status(dev);

        if(state != NULL)   {
            if(state->buttons & CONT_DPAD_UP)
                *pad1->padbits &= 0xEF;
            else
                *pad1->padbits |= 0x10;

            if(state->buttons & CONT_DPAD_DOWN)
                *pad1->padbits &= 0xDF;
            else
                *pad1->padbits |= 0x20;

            if(state->buttons & CONT_DPAD_RIGHT)
                *pad1->padbits &= 0x7F;
            else
                *pad1->padbits |= 0x80;

            if(state->buttons & CONT_DPAD_LEFT)
                *pad1->padbits &= 0xBF;
            else
                *pad1->padbits |= 0x40;

            if(state->buttons & CONT_START)
                *pad1->padbits &= 0xF7;
            else
                *pad1->padbits |= 0x08;

            if(state->buttons & CONT_A)
                *pad1->padbits &= 0xFB;
            else
                *pad1->padbits |= 0x04;

            if(state->buttons & CONT_B)
                *pad1->padbits &= 0xFE;
            else
                *pad1->padbits |= 0x01;

            if(state->buttons & CONT_X)
                *(pad1->padbits + 1) &= 0xBF;
            else
                *(pad1->padbits + 1) |= 0x40;

            if(state->buttons & CONT_Y)
                *(pad1->padbits + 1) &= 0xDF;
            else
                *(pad1->padbits + 1) |= 0x20;

            if(state->rtrig > 20)
                *(pad1->padbits + 1) &= 0x7F;
            else
                *(pad1->padbits + 1) |= 0x80;

            if(state->ltrig > 20)
                *(pad1->padbits + 1) &= 0xF7;
            else
                *(pad1->padbits + 1) |= 0x08;

            if(state->joyx > 20)
                *pad1->padbits &= 0xFD;
            else
                *pad1->padbits |= 0x02;

            if(state->joyy > 20)
                *(pad1->padbits + 1) &= 0xEF;
            else
                *(pad1->padbits + 1) |= 0x10;

        }
    }

    YabauseExec();

	return 0;
}

void PERDCNothing(void) {
    /* Nothing */
}

u32 PERDCScan(u32 flags) {
    /* Nothing */
    return 0;
}

void PERDCKeyName(u32 key, char *name, int size) {
    snprintf(name, size, "%x", (unsigned int)key);
}
