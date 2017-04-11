/*  Copyright 2007 Guillaume Duhamel

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

/*! \file m68kc68k.c
    \brief C68K 68000 interface.
*/

#include "m68kc68k.h"
#include "c68k/c68k.h"
#include "memory.h"
#include "yabause.h"

/**
 * PROFILE_68K: Perform simple profiling of the 68000 emulation, reporting
 * the average time per 68000 clock cycle.  (Realtime execution would be
 * around 88.5 nsec/cycle.)
 */
// #define PROFILE_68K


static u8 *SoundDummy=NULL;

static int M68KC68KInit(void) {
	int i;

	// Setup a 64k buffer filled with invalid 68k instructions to serve
	// as a default map
	if ((SoundDummy = T2MemoryInit(0x10000)) != NULL)
		memset(SoundDummy, 0xFF, 0x10000);

	C68k_Init(&C68K, NULL); // not sure if I need the int callback or not

	for (i = 0x10; i < 0x100; i++)
		M68K->SetFetch(i << 16, (i << 16) + 0xFFFF, (pointer)SoundDummy);

	return 0;
}

static void M68KC68KDeInit(void) {
	if (SoundDummy)
		T2MemoryDeInit(SoundDummy);
	SoundDummy = NULL;
}

static void M68KC68KReset(void) {
	C68k_Reset(&C68K);
}

static s32 FASTCALL M68KC68KExec(s32 cycle) {
#ifdef PROFILE_68K
    static u32 tot_cycles = 0, tot_usec = 0, tot_ticks = 0, last_report = 0;
    u32 start, end;
    start = (u32) YabauseGetTicks();
    int retval = C68k_Exec(&C68K, cycle);
    end = (u32) YabauseGetTicks();
    tot_cycles += cycle;
    tot_ticks += end - start;
    if (tot_cycles/1000000 > last_report) {
        tot_usec += (u64)tot_ticks * 1000000 / yabsys.tickfreq;
        tot_ticks = 0;
        fprintf(stderr, "%ld cycles in %.3f sec = %.3f nsec/cycle\n",
                (long)tot_cycles, (double)tot_usec/1000000,
                ((double)tot_usec / (double)tot_cycles) * 1000);
        last_report = tot_cycles/1000000;
    }
    return retval;
#else
	return C68k_Exec(&C68K, cycle);
#endif
}

static void M68KC68KSync(void) {
}

static u32 M68KC68KGetDReg(u32 num) {
	return C68k_Get_DReg(&C68K, num);
}

static u32 M68KC68KGetAReg(u32 num) {
	return C68k_Get_AReg(&C68K, num);
}

static u32 M68KC68KGetPC(void) {
	return C68k_Get_PC(&C68K);
}

static u32 M68KC68KGetSR(void) {
	return C68k_Get_SR(&C68K);
}

static u32 M68KC68KGetUSP(void) {
	return C68k_Get_USP(&C68K);
}

static u32 M68KC68KGetMSP(void) {
	return C68k_Get_MSP(&C68K);
}

static void M68KC68KSetDReg(u32 num, u32 val) {
	C68k_Set_DReg(&C68K, num, val);
}

static void M68KC68KSetAReg(u32 num, u32 val) {
	C68k_Set_AReg(&C68K, num, val);
}

static void M68KC68KSetPC(u32 val) {
	C68k_Set_PC(&C68K, val);
}

static void M68KC68KSetSR(u32 val) {
	C68k_Set_SR(&C68K, val);
}

static void M68KC68KSetUSP(u32 val) {
	C68k_Set_USP(&C68K, val);
}

static void M68KC68KSetMSP(u32 val) {
	C68k_Set_MSP(&C68K, val);
}

static void M68KC68KSetFetch(u32 low_adr, u32 high_adr, pointer fetch_adr) {
	C68k_Set_Fetch(&C68K, low_adr, high_adr, fetch_adr);
}

static void FASTCALL M68KC68KSetIRQ(s32 level) {
	C68k_Set_IRQ(&C68K, level);
}

static void FASTCALL M68KC68KWriteNotify(u32 address, u32 size) {
	/* nothing to do */
}

static void M68KC68KSetReadB(M68K_READ *Func) {
	C68k_Set_ReadB(&C68K, Func);
}

static void M68KC68KSetReadW(M68K_READ *Func) {
	C68k_Set_ReadW(&C68K, Func);
}

static void M68KC68KSetWriteB(M68K_WRITE *Func) {
	C68k_Set_WriteB(&C68K, Func);
}

static void M68KC68KSetWriteW(M68K_WRITE *Func) {
	C68k_Set_WriteW(&C68K, Func);
}

M68K_struct M68KC68K = {
	1,
	"C68k Interface",
	M68KC68KInit,
	M68KC68KDeInit,
	M68KC68KReset,
	M68KC68KExec,
	M68KC68KSync,
	M68KC68KGetDReg,
	M68KC68KGetAReg,
	M68KC68KGetPC,
	M68KC68KGetSR,
	M68KC68KGetUSP,
	M68KC68KGetMSP,
	M68KC68KSetDReg,
	M68KC68KSetAReg,
	M68KC68KSetPC,
	M68KC68KSetSR,
	M68KC68KSetUSP,
	M68KC68KSetMSP,
	M68KC68KSetFetch,
	M68KC68KSetIRQ,
	M68KC68KWriteNotify,
	M68KC68KSetReadB,
	M68KC68KSetReadW,
	M68KC68KSetWriteB,
	M68KC68KSetWriteW
};
