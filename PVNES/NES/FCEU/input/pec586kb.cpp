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
static uint8 kspos, kstrobe;
static uint8 ksindex;

//TODO: check all keys, some of the are wrong

static uint16 matrix[13][8] =
{
	{ AK(ESCAPE),AK(SPACE),AK(LMENU),AK(LCONTROL),AK(LSHIFT),AK(GRAVE),AK(TAB),AK(CAPITAL) },
	{ AK(F6),AK(F7),AK(F5),AK(F4),AK(F8),AK(F2),AK(F1),AK(F3) },
	{ AK(EQUALS), AK(NUMPAD0),AK(PERIOD),AK(A),AK(RETURN),AK(1),AK(Q),AK(Z) },
	{ 0, AK(NUMPAD3),AK(NUMPAD6),AK(S),AK(NUMPAD9),AK(2),AK(W),AK(X) },
	{ AK(SLASH), AK(NUMPAD2),AK(NUMPAD5),AK(D),AK(NUMPAD8),AK(3),AK(E),AK(C) },
	{ AK(BREAK), AK(NUMPAD1),AK(NUMPAD4),AK(F),AK(NUMPAD7),AK(4),AK(R),AK(V) },
	{ AK(BACK),AK(BACKSLASH),AK(GRETURN),AK(G),AK(RBRACKET),AK(5),AK(T),AK(B) },
	{ AK(9),AK(PERIOD),AK(L),AK(K),AK(O),AK(8),AK(I),AK(COMMA) },
	{ AK(0),AK(SLASH),AK(SEMICOLON),AK(J),AK(P),AK(7),AK(U),AK(M) },
	{ AK(MINUS),AK(MINUS),AK(APOSTROPHE),AK(H),AK(LBRACKET),AK(6),AK(Y),AK(N) },
	{ AK(F11),AK(F12),AK(F10),0,AK(MINUS),AK(F9),0,0 },
	{ AK(UP),AK(RIGHT),AK(DOWN),AK(DIVIDE),AK(LEFT),AK(MULTIPLY),AK(SUBTRACT),AK(ADD) },
	{ AK(INSERT),AK(NUMPAD1),AK(HOME),AK(PRIOR),AK(DELETE),AK(END),AK(NEXT),AK(NUMLOCK) },
};

static void PEC586KB_Write(uint8 v) {
	if (!(kstrobe & 2) && (v & 2)) {
		kspos = 0;
	}
	if ((kstrobe & 1) && !(v & 1)) {
		ksindex = 0;
	}
	if ((kstrobe & 4) && !(v & 4)) {
		kspos++;
		kspos %= 13;
	}
	kstrobe = v;
}

static uint8 PEC586KB_Read(int w, uint8 ret) {
#ifdef FCEUDEF_DEBUGGER
	if (!fceuindbg) {
#endif
	if (w) {
		ret &= ~2;
		if(bufit[matrix[kspos][7-ksindex]])
			ret |= 2;
		ksindex++;
		ksindex&=7;
	}
#ifdef FCEUDEF_DEBUGGER
	}
#endif
	return(ret);
}

static void PEC586KB_Strobe(void) {
//	kstrobe = 0;
//	ksindex = 0;
}

static void PEC586KB_Update(void *data, int arg) {
	memcpy(bufit + 1, data, sizeof(bufit) - 1);
}

static INPUTCFC PEC586KB = { PEC586KB_Read, PEC586KB_Write, PEC586KB_Strobe, PEC586KB_Update, 0, 0 };

INPUTCFC *FCEU_InitPEC586KB(void) {
	memset(bufit, 0, sizeof(bufit));
	kspos = ksindex = kstrobe = 0;
	return(&PEC586KB);
}
