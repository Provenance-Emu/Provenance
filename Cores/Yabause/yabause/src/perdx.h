/*  Copyright 2006 Theo Berkau

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

#ifndef PERDX_H
#define PERDX_H

#define DIRECTINPUT_VERSION 0x0800
#include <dinput.h>
#include "dx.h"
#include "peripheral.h"

#define PERCORE_DIRECTX 2

extern PerInterface_struct PERDIRECTX;

typedef struct
{
   LPDIRECTINPUTDEVICE8 lpDIDevice;
   int type;
   int emulatetype;
#ifdef HAVE_XINPUT
	int is_xinput_device;
	int xinput_num;
#endif
} padconf_struct;

enum XIAXIS
{
	XI_THUMBL=1,
	XI_THUMBLX=1,
	XI_THUMBLY=5,
	XI_THUMBR=9,
	XI_THUMBRX=9,
	XI_THUMBRY=13,
	XI_TRIGGERL=17,
	XI_TRIGGERR=19
};

int PERDXInit(void);
void PERDXDeInit(void);
int PERDXHandleEvents(void);
void PERDXPerSetButtonMapping(void);
u32 PERDXScan(u32 flags) ;
void PERDXFlush(void);
#endif
