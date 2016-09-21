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

#include <string.h>
#include <stdlib.h>
#include "share.h"

typedef struct {
	bool strobe;
	uint32 latch; // latched data (read when strobe goes high to low)
	uint32 sensitivity; // reading while strobe is high cycles sensitivity 0,1,2
	int32 mx, my; // current screen location
	int32 lmx, lmy; // last latched location
	uint32 mb; // current buttons
} SNES_MOUSE;

static SNES_MOUSE SNESMouse;

static uint8 ReadSNESMouse(int w)
{
	if (SNESMouse.strobe)
	{
		SNESMouse.sensitivity += 1;
		if (SNESMouse.sensitivity > 2) SNESMouse.sensitivity = 0;
	}

	uint8 result = (SNESMouse.latch & 0x80000000) >> 31;
	SNESMouse.latch = (SNESMouse.latch << 1);

	return result;
}

static void WriteSNESMouse(uint8 v)
{
	bool strobing = v & 1;

	if (SNESMouse.strobe && !strobing)
	{
		int dx = SNESMouse.mx - SNESMouse.lmx;
		int dy = SNESMouse.my - SNESMouse.lmy;

		SNESMouse.lmx = SNESMouse.mx;
		SNESMouse.lmy = SNESMouse.my;

		// convert to sign and magnitude
		bool sx = (dx < 0);
		bool sy = (dy < 0);
		if (dx < 0) dx = -dx;
		if (dy < 0) dy = -dy;

		// apply sensitivity
		dx += dx >> (2 - SNESMouse.sensitivity);
		dx += dx >> (2 - SNESMouse.sensitivity);

		// clamp
		if (dx > 127) dx = 127;
		if (dy > 127) dy = 127;

		//FCEU_printf("SNES Mouse: %1d %3d, %1d %3d %1d x%1d\n",sx,dx,sy,dy,SNESMouse.mb,SNESMouse.sensitivity);

		uint8 byte0 = 0x00;
		uint8 byte1 =
			0x1 | // signature
			((SNESMouse.sensitivity & 3) << 4) | // sensitivity
			((SNESMouse.mb & 3) << 6); // buttons
		uint8 byte2 = uint8(dy) | (sy ? 0x80 : 0x00);
		uint8 byte3 = uint8(dx) | (sx ? 0x80 : 0x00);

		SNESMouse.latch = (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | (byte3 << 0);
	}

	SNESMouse.strobe = strobing;
}

static void UpdateSNESMouse(int w, void *data, int arg)
{
	uint32 *ptr=(uint32*)data;
	SNESMouse.mx = ptr[0]; // screen position
	SNESMouse.my = ptr[1];
	SNESMouse.mb = ptr[2] & 3; // bit 0 = left button, bit 1 = right button
}

static INPUTC SNES_MOUSEC =
{
	ReadSNESMouse, // Read
	WriteSNESMouse, // Write
	0, // Strobe (handled by Write)
	UpdateSNESMouse, // Update
	0, // SLHook
	0, // Draw
	0, // Log
	0, // Load
};

INPUTC *FCEU_InitSNESMouse(int w)
{
	memset(&SNESMouse,0,sizeof(SNESMouse));
	return(&SNES_MOUSEC);
}
