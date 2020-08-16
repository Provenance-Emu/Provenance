/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

// implementation of Subor Mouse
// used in Educational Computer 2000

#include <string.h>
#include <stdlib.h>
#include "share.h"

typedef struct {
	uint8 latch;
	int32 mx,my;
	int32 lmx,lmy;
	uint32 mb;
} MOUSE;

static MOUSE Mouse;

static void StrobeMOUSE(int w)
{
	Mouse.latch = Mouse.mb & 0x03;

	int32 dx = Mouse.mx - Mouse.lmx;
	int32 dy = Mouse.my - Mouse.lmy;

	Mouse.lmx = Mouse.mx;
	Mouse.lmy = Mouse.my;

	if      (dx > 0) Mouse.latch |= (0x2 << 2);
	else if (dx < 0) Mouse.latch |= (0x3 << 2);
	if      (dy > 0) Mouse.latch |= (0x2 << 4);
	else if (dy < 0) Mouse.latch |= (0x3 << 4);

	//FCEU_printf("Subor Mouse: %02X\n",Mouse.latch);
}

static uint8 ReadMOUSE(int w)
{
	uint8 result = Mouse.latch & 0x01;
	Mouse.latch = (Mouse.latch >> 1) | 0x80;
	return result;
}

static void UpdateMOUSE(int w, void *data, int arg)
{
	uint32 *ptr=(uint32*)data;
	Mouse.mx = ptr[0];
	Mouse.my = ptr[1];
	Mouse.mb = ptr[2];
}

static INPUTC MOUSEC={ReadMOUSE,0,StrobeMOUSE,UpdateMOUSE,0,0};

INPUTC *FCEU_InitMouse(int w)
{
	memset(&Mouse,0,sizeof(Mouse));
	return(&MOUSEC);
}
