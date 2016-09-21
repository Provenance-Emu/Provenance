/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2015 CaH4e3
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
 *
 * "Dragon Fighter" protected MMC3 based custom mapper board
 * mostly hacky implementation, I can't verify if this mapper can read a RAM of the
 * console or watches the bus writes somehow.
 *
 */

#include "mapinc.h"
#include "mmc3.h"

static void UNLBMW8544PW(uint32 A, uint8 V) {
	if(A == 0x8000)
		setprg8(A,EXPREGS[0] & 0x1F);	// the real hardware has this bank overrided with it's own register,
	else								// but MMC3 prg swap still works and you can actually change bank C000 at the same time if use 0x46 cmd
		setprg8(A,V);
}

static void UNLBMW8544CW(uint32 A, uint8 V) {
	if(A == 0x0000)
		setchr2(0x0000,(V >> 1) ^ EXPREGS[1]);
	else if (A == 0x0800)
		setchr2(0x0800,(V >> 1) | ((EXPREGS[2] & 0x40) << 1));
	else if (A == 0x1000)
		setchr4(0x1000, EXPREGS[2] & 0x3F);

}

static DECLFW(UNLBMW8544ProtWrite) {
	if(!(A & 1)) {
		EXPREGS[0] = V;
		FixMMC3PRG(MMC3_cmd);
	}
}

static DECLFR(UNLBMW8544ProtRead) {
	if(!fceuindbg) {
		if(!(A & 1)) {
			if((EXPREGS[0] & 0xE0) == 0xC0) {
				EXPREGS[1] = ARead[0x6a](0x6a);	// program can latch some data from the BUS, but I can't say how exactly,
			} else {							// without more euipment and skills ;) probably here we can try to get any write
				EXPREGS[2] = ARead[0xff](0xff);	// before the read operation
			}
			FixMMC3CHR(MMC3_cmd & 0x7F);		// there are more different behaviour of the board isn't used by game itself, so unimplemented here and
		}										// actually will break the current logic ;)
	}
	return 0;
}

static void UNLBMW8544Power(void) {
	GenMMC3Power();
	SetWriteHandler(0x6000, 0x6FFF, UNLBMW8544ProtWrite);
	SetReadHandler(0x6000, 0x6FFF, UNLBMW8544ProtRead);
}

void UNLBMW8544_Init(CartInfo *info) {
	GenMMC3_Init(info, 128, 256, 0, 0);
	pwrap = UNLBMW8544PW;
	cwrap = UNLBMW8544CW;
	info->Power = UNLBMW8544Power;
	AddExState(EXPREGS, 3, 0, "EXPR");
}
