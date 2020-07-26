/*
 * The SVP chip emulator
 *
 * Copyright (c) Gražvydas "notaz" Ignotas, 2008
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the organization nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <pico/pico_int.h>
#include <cpu/drc/cmn.h>
#include "compiler.h"

svp_t *svp = NULL;
int PicoSVPCycles = 850; // cycles/line, just a guess
static int svp_dyn_ready = 0;

/* save state stuff */
typedef enum {
	CHUNK_IRAM = CHUNK_CARTHW,
	CHUNK_DRAM,
	CHUNK_SSP
} chunk_name_e;

static carthw_state_chunk svp_states[] =
{
	{ CHUNK_IRAM, 0x800,                 NULL },
	{ CHUNK_DRAM, sizeof(svp->dram),     NULL },
	{ CHUNK_SSP,  sizeof(svp->ssp1601) - sizeof(svp->ssp1601.drc),  NULL },
	{ 0,          0,                     NULL }
};


static void PicoSVPReset(void)
{
	elprintf(EL_SVP, "SVP reset");

	memcpy(svp->iram_rom + 0x800, Pico.rom + 0x800, 0x20000 - 0x800);
	ssp1601_reset(&svp->ssp1601);
#ifdef _SVP_DRC
	if ((PicoOpt & POPT_EN_DRC) && svp_dyn_ready)
		ssp1601_dyn_reset(&svp->ssp1601);
#endif
}


static void PicoSVPLine(void)
{
	int count = 1;
#if defined(__arm__) || defined(PSP)
	// performance hack
	static int delay_lines = 0;
	delay_lines++;
	if ((Pico.m.scanline&0xf) != 0xf && Pico.m.scanline != 261 && Pico.m.scanline != 311)
		return;
	count = delay_lines;
	delay_lines = 0;
#endif

#ifdef _SVP_DRC
	if ((PicoOpt & POPT_EN_DRC) && svp_dyn_ready)
		ssp1601_dyn_run(PicoSVPCycles * count);
	else
#endif
	{
		ssp1601_run(PicoSVPCycles * count);
		svp_dyn_ready = 0; // just in case
	}

	// test mode
	//if (Pico.m.frame_count == 13) PicoPad[0] |= 0xff;
}


static int PicoSVPDma(unsigned int source, int len, unsigned short **srcp, unsigned short **limitp)
{
	if (source < Pico.romsize) // Rom
	{
		source -= 2;
		*srcp = (unsigned short *)(Pico.rom + (source&~1));
		*limitp = (unsigned short *)(Pico.rom + Pico.romsize);
		return 1;
	}
	else if ((source & 0xfe0000) == 0x300000)
	{
		elprintf(EL_VDPDMA|EL_SVP, "SVP DmaSlow from %06x, len=%i", source, len);
		source &= 0x1fffe;
		source -= 2;
		*srcp = (unsigned short *)(svp->dram + source);
		*limitp = (unsigned short *)(svp->dram + sizeof(svp->dram));
		return 1;
	}
	else
		elprintf(EL_VDPDMA|EL_SVP|EL_ANOMALY, "SVP FIXME unhandled DmaSlow from %06x, len=%i", source, len);

	return 0;
}


void PicoSVPInit(void)
{
#ifdef _SVP_DRC
	// this is to unmap tcache and make
	// mem available for large ROMs, MCD, etc.
	drc_cmn_cleanup();
#endif
}

static void PicoSVPExit(void)
{
#ifdef _SVP_DRC
	ssp1601_dyn_exit();
#endif
}


void PicoSVPStartup(void)
{
	int ret;

	elprintf(EL_STATUS, "SVP startup");

	ret = PicoCartResize(Pico.romsize + sizeof(*svp));
	if (ret != 0) {
		elprintf(EL_STATUS|EL_SVP, "OOM for SVP data");
		return;
	}

	svp = (void *) ((char *)Pico.rom + Pico.romsize);
	memset(svp, 0, sizeof(*svp));

	// init SVP compiler
	svp_dyn_ready = 0;
#ifdef _SVP_DRC
	if (PicoOpt & POPT_EN_DRC) {
		if (ssp1601_dyn_startup())
			return;
		svp_dyn_ready = 1;
	}
#endif

	// init ok, setup hooks..
	PicoCartMemSetup = PicoSVPMemSetup;
	PicoDmaHook = PicoSVPDma;
	PicoResetHook = PicoSVPReset;
	PicoLineHook = PicoSVPLine;
	PicoCartUnloadHook = PicoSVPExit;

	// save state stuff
	svp_states[0].ptr = svp->iram_rom;
	svp_states[1].ptr = svp->dram;
	svp_states[2].ptr = &svp->ssp1601;
	carthw_chunks = svp_states;
	PicoAHW |= PAHW_SVP;
}

