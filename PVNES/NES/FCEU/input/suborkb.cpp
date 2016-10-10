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
#include "share.h"
#include "suborkb.h"
#define AK(x)	FKB_ ## x

static uint8 bufit[0x66];
static uint8 ksmode;
static uint8 ksindex;

static uint16 matrix[13][2][4] =
{
	{ { AK(4), AK(G), AK(F), AK(C) }, { AK(F2), AK(E), AK(5), AK(V) } },
	{ { AK(2), AK(D), AK(S), AK(END) }, { AK(F1), AK(W), AK(3), AK(X) } },
	{ { AK(INSERT), AK(BACK), AK(NEXT), AK(RIGHT) }, { AK(F8), AK(PRIOR), AK(DELETE), AK(HOME) } },
	{ { AK(9), AK(I), AK(L), AK(COMMA) }, { AK(F5), AK(O), AK(0), AK(PERIOD) } },
	{ { AK(RBRACKET), AK(RETURN), AK(UP), AK(LEFT) }, { AK(F7), AK(LBRACKET), AK(BACKSLASH), AK(DOWN) } },
	{ { AK(Q), AK(CAPITAL), AK(Z), AK(TAB) }, { AK(ESCAPE), AK(A), AK(1), AK(LCONTROL) } },
	{ { AK(7), AK(Y), AK(K), AK(M) }, { AK(F4), AK(U), AK(8), AK(J) } },
	{ { AK(MINUS), AK(SEMICOLON), AK(APOSTROPHE), AK(SLASH) }, { AK(F6), AK(P), AK(EQUALS), AK(LSHIFT) } },
	{ { AK(T), AK(H), AK(N), AK(SPACE) }, { AK(F3), AK(R), AK(6), AK(B) } },
	{ { AK(NUMPAD6), AK(GRETURN), AK(NUMPAD4), AK(NUMPAD8) }, { AK(NUMPAD2), 0, 0, 0 } },   // baibaidino actually uses diferent layot
	{ { AK(LMENU), AK(NUMPAD4), AK(NUMPAD7), AK(F11) }, { AK(F12), AK(NUMPAD1), AK(NUMPAD2), AK(NUMPAD8) } },
	{ { AK(SUBTRACT), AK(ADD), AK(MULTIPLY), AK(NUMPAD9) }, { AK(F10), AK(NUMPAD5), AK(DIVIDE), AK(NUMLOCK) } },
	{ { AK(GRAVE), AK(NUMPAD6), AK(PAUSE), AK(SPACE) },	 { AK(F9), AK(NUMPAD3), AK(DECIMAL), AK(NUMPAD0) } },
};

static void SuborKB_Write(uint8 v) {
	v >>= 1;
	if (v & 2) {
		if ((ksmode & 1) && !(v & 1))
			ksindex = (ksindex + 1) % 13;
	}
	ksmode = v;
}

static uint8 SuborKB_Read(int w, uint8 ret) {
	if (w) {
		int x;

		ret &= ~0x1E;
		for (x = 0; x < 4; x++)
			if (bufit[matrix[ksindex][ksmode & 1][x]])
				ret |= 1 << (x + 1);
		ret ^= 0x1E;
	}
	return(ret);
}

static void SuborKB_Strobe(void) {
	ksmode = 0;
	ksindex = 0;
}

static void SuborKB_Update(void *data, int arg) {
	memcpy(bufit + 1, data, sizeof(bufit) - 1);
}

static INPUTCFC SuborKB = { SuborKB_Read, SuborKB_Write, SuborKB_Strobe, SuborKB_Update, 0, 0 };

INPUTCFC *FCEU_InitSuborKB(void) {
	memset(bufit, 0, sizeof(bufit));
	ksmode = ksindex = 0;
	return(&SuborKB);
}
