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
 * BMC F-15 PCB (256+266 MMC3 based, with 16/32Kb banking discrete logic)
 * 150-in-1 Unchaied Melody FIGHT version with system test (START+SELECT)
 *
 * CHR - MMC3 stock regs
 * PRG - MMC3 regs disabled, area 6000-7FFF used instead
 *		 011xxxxxxxxxxxxx addr mask,
 *       ----APPp reg bits mask
 *       A - higher 128K PRG bank select/32K bank mode override
 *       PP - bank number in 32K mode
 *       PPp - bank number in 16K mode
 * initial state of extra regs is undefined, A001 enables/disables the 6000 area
 */

#include "mapinc.h"
#include "mmc3.h"

static void BMCF15PW(uint32 A, uint8 V) {
	uint32 bank = EXPREGS[0] & 0xF;
	uint32 mode = (EXPREGS[0] & 8) >> 3;
	uint32 mask = ~(mode);
	setprg16(0x8000, (bank & mask));
	setprg16(0xC000, (bank & mask) | mode);
}

static DECLFW(BMCF15Write) {
	if (A001B & 0x80) {
		EXPREGS[0] = V & 0xF;
		FixMMC3PRG(MMC3_cmd);
	}
}

static void BMCF15Power(void) {
	GenMMC3Power();
	SetWriteHandler(0x6000, 0x7FFF, BMCF15Write);
	SetWriteHandler(0x6000, 0x7FFF, BMCF15Write);
}

void BMCF15_Init(CartInfo *info) {
	GenMMC3_Init(info, 256, 256, 0, 0);
	pwrap = BMCF15PW;
	info->Power = BMCF15Power;
	AddExState(EXPREGS, 1, 0, "EXPR");
}
