/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2015 CaH4e3, ClusteR
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
 * CoolBoy 400-in-1 FK23C-mimic mapper 16Mb/32Mb PROM + 128K/256K CHR RAM, optional SRAM, optional NTRAM
 * only MMC3 mode
 *
 * 6000 (xx76x210) | 0xC0
 * 6001 (xxx354x)
 * 6002 = 0
 * 6003 = 0
 *
 * hardware tested logic, don't try to understand lol
 */

#include "mapinc.h"
#include "mmc3.h"

static void COOLBOYCW(uint32 A, uint8 V) {
	uint32 mask = 0xFF ^ (EXPREGS[0] & 0x80);
	if (EXPREGS[3] & 0x10) {
		if (EXPREGS[3] & 0x40) { // Weird mode
			int cbase = (MMC3_cmd & 0x80) << 5;
			switch (cbase ^ A) { // Don't even try do understand
			case 0x0400:
			case 0x0C00: V &= 0x7F; break;
			}
		}
		// Highest bit goes from MMC3 registers when EXPREGS[3]&0x80==0 or from EXPREGS[0]&0x08 otherwise
		setchr1(A,
			(V & 0x80 & mask) | ((((EXPREGS[0] & 0x08) << 4) & ~mask)) // 7th bit
			| ((EXPREGS[2] & 0x0F) << 3) // 6-3 bits
			| ((A >> 10) & 7) // 2-0 bits
		);
	} else {
		if (EXPREGS[3] & 0x40) { // Weird mode, again
			int cbase = (MMC3_cmd & 0x80) << 5;
			switch (cbase ^ A) { // Don't even try do understand
			case 0x0000: V = DRegBuf[0]; break;
			case 0x0800: V = DRegBuf[1]; break;
			case 0x0400:
			case 0x0C00: V = 0; break;
			}
		}
		// Simple MMC3 mode
		// Highest bit goes from MMC3 registers when EXPREGS[3]&0x80==0 or from EXPREGS[0]&0x08 otherwise
		setchr1(A, (V & mask) | (((EXPREGS[0] & 0x08) << 4) & ~mask));
	}
}

static void COOLBOYPW(uint32 A, uint8 V) {
	uint32 mask = ((0x3F | (EXPREGS[1] & 0x40) | ((EXPREGS[1] & 0x20) << 2)) ^ ((EXPREGS[0] & 0x40) >> 2)) ^ ((EXPREGS[1] & 0x80) >> 2);
	uint32 base = ((EXPREGS[0] & 0x07) >> 0) | ((EXPREGS[1] & 0x10) >> 1) | ((EXPREGS[1] & 0x0C) << 2) | ((EXPREGS[0] & 0x30) << 2);

	// Very weird mode
	// Last banks are first in this mode, ignored when MMC3_cmd&0x40
	if ((EXPREGS[3] & 0x40) && (V >= 0xFE) && !((MMC3_cmd & 0x40) != 0)) {
		switch (A & 0xE000) {
		case 0xA000:
			if ((MMC3_cmd & 0x40)) V = 0;
			break;
		case 0xC000:
			if (!(MMC3_cmd & 0x40)) V = 0;
			break;
		case 0xE000:
			V = 0;
			break;
		}
	}

	// Regular MMC3 mode, internal ROM size can be up to 2048kb!
	if (!(EXPREGS[3] & 0x10))
		setprg8(A, (((base << 4) & ~mask)) | (V & mask));
	else { // NROM mode
		mask &= 0xF0;
		uint8 emask;
		if ((((EXPREGS[1] & 2) != 0))) // 32kb mode
			emask = (EXPREGS[3] & 0x0C) | ((A & 0x4000) >> 13);
		else // 16kb mode
			emask = EXPREGS[3] & 0x0E;
		setprg8(A, ((base << 4) & ~mask) // 7-4 bits are from base (see below)
			| (V & mask)                   // ... or from MM3 internal regs, depends on mask
			| emask                        // 3-1 (or 3-2 when (EXPREGS[3]&0x0C is set) from EXPREGS[3]
			| ((A & 0x2000) >> 13));       // 0th just as is
	}
}

static DECLFW(COOLBOYWrite) {
	if(A001B & 0x80)
		CartBW(A,V);

	// Deny any further writes when 7th bit is 1 AND 4th is 0
	if ((EXPREGS[3] & 0x90) != 0x80) {
		EXPREGS[A & 3] = V;
		FixMMC3PRG(MMC3_cmd);
		FixMMC3CHR(MMC3_cmd);
	}
}

static void COOLBOYReset(void) {
	MMC3RegReset();
	EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = EXPREGS[3] = 0;
//	EXPREGS[0] = 0;
//	EXPREGS[1] = 0x60;
//	EXPREGS[2] = 0;
//	EXPREGS[3] = 0;
	FixMMC3PRG(MMC3_cmd);
	FixMMC3CHR(MMC3_cmd);
}

static void COOLBOYPower(void) {
	GenMMC3Power();
	EXPREGS[0] = EXPREGS[1] = EXPREGS[2] = EXPREGS[3] = 0;
//	EXPREGS[0] = 0;
//	EXPREGS[1] = 0x60;
//	EXPREGS[2] = 0;
//	EXPREGS[3] = 0;
	FixMMC3PRG(MMC3_cmd);
	FixMMC3CHR(MMC3_cmd);
	SetWriteHandler(0x5000, 0x5fff, CartBW);            // some games access random unmapped areas and crashes because of KT-008 PCB hack in MMC3 source lol
	SetWriteHandler(0x6000, 0x7fff, COOLBOYWrite);
}

void COOLBOY_Init(CartInfo *info) {
	GenMMC3_Init(info, 512, 256, 8, 0);
	pwrap = COOLBOYPW;
	cwrap = COOLBOYCW;
	info->Power = COOLBOYPower;
	info->Reset = COOLBOYReset;
	AddExState(EXPREGS, 4, 0, "EXPR");
}