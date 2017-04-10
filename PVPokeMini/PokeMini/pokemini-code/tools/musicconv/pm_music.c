/*
  PokeMini Music Converter
  Copyright (C) 2011-2015  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pm_music.h"

#include "PokeMini.h"

int PokeMini_Flags = 0;
uint8_t PM_RAM[8192];
pmmusram pmmusic;

const uint8_t pmmusic_voltable[] = {
	0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x06, 0x06,
	0x00, 0x06, 0x06, 0x07,
	0x00, 0x06, 0x02, 0x02,
	0x00, 0x06, 0x02, 0x03
};

static void WriteReg(uint8_t reg, uint8_t data)
{
	if ((reg & 0x70) == 0x70) MinxAudio_WriteReg(reg, data);
	else MinxTimers_WriteReg(reg, data);
}

int pmmusic_initialize(int soundfifo, int sndengine, int sndfilter)
{
	int i;
	for (i=0; i<8192; i++) PM_RAM[i] = 0x00;
	if (!MinxTimers_Create()) return 0;
	if (!MinxAudio_Create(soundfifo, soundfifo)) return 0;
	MinxAudio_ChangeEngine(sndengine);
	MinxAudio_ChangeFilter(sndfilter);
	return 1;
}

void pmmusic_terminate(void)
{
	MinxTimers_Destroy();
	MinxAudio_Destroy();
}

void pmmusic_init(uint16_t mastertime, uint8_t *ramptr)
{
	// Set master time
	pmmusic.err = 0;
	pmmusic.mtime = mastertime;
	WriteReg(0x3A, mastertime);	// Tmr2 Preset
	WriteReg(0x3B, mastertime >> 8);

	// Set RAM pointer
	pmmusic.ram_ptr = ramptr;

	// Registers to zero
	pmmusic.aud_ena = 0;
	pmmusic.bgm_frq = 0;
	pmmusic.bgm_pvt = 0;
	pmmusic.sfx_frq = 0;
	pmmusic.sfx_pvt = 0;
	pmmusic.hwvol = 0;
	WriteReg(0x71, 0);		// Audio Volume
	WriteReg(0x38, 0);		// Tmr2 Ctrl
	WriteReg(0x39, 0);
	pmmusic.hwpreset = 0;
	WriteReg(0x4A, 0);		// Tmr3 Preset
	WriteReg(0x4B, 0);
	pmmusic.hwpivot = 0;
	WriteReg(0x4C, 0);		// Tmr3 Pivot
	WriteReg(0x4D, 0);
	WriteReg(0x1B, 0);		// Tmr2 Osc
	WriteReg(0x1D, 0);		// Tmr3 Osc
	WriteReg(0x1A, PMMUSTMR_DIV_256);	// Tmr2 Scale
	WriteReg(0x1C, PMMUSTMR_DIV_2);	// Tmr3 Scale

	// Registers to non-zero
	pmmusic_setvolbgm(4);
	pmmusic_setvolsfx(4);
	WriteReg(0x48, 0x86);		// Tmr3 Ctrl
	WriteReg(0x49, 0);
	WriteReg(0x19, 0x20);		// Tmr1 Osc + Enable
}

void pmmusic_setvolbgm(uint8_t volume)
{
	int i;
	if (volume < 5) {
		pmmusic.bgm_mvol = volume;
		for (i=0; i<4; i++) pmmusic.bgm_tvol[i] = pmmusic_voltable[volume * 4 + i];
	}
}

uint8_t pmmusic_getvolbgm(void)
{
	return pmmusic.bgm_mvol;
}

void pmmusic_setvolsfx(uint8_t volume)
{
	int i;
	if (volume < 5) {
		pmmusic.sfx_mvol = volume;
		for (i=0; i<4; i++) pmmusic.sfx_tvol[i] = pmmusic_voltable[volume * 4 + i];
	}
}

uint8_t pmmusic_getvolsfx(void)
{
	return pmmusic.sfx_mvol;
}

void pmtracker_setmastertime(uint16_t mtime)
{
	pmmusic.mtime = mtime;
	WriteReg(0x3A, mtime);	// Tmr2 Preset
	WriteReg(0x3B, mtime >> 8);
}

uint16_t pmtracker_getmastertime(void)
{
	return pmmusic.mtime;
}

void pmmusic_playbgm(pmmusic_bgm *bgm)
{
	if (bgm->numpattern <= 0) return;
	pmmusic.aud_ena &= 0x02;
	pmmusic.bgm_ptb = bgm;
	pmmusic.bgm_ptb_offset = 0;
	pmmusic.bgm_ppr = bgm->pattern[0];
	pmmusic.bgm_ppr_offset = 0;
	pmmusic.aud_ena |= 0x01;
	pmmusic.bgm_wait = 1;
	if (!(pmmusic.aud_ena & 2)) {
		WriteReg(0x38, 0x86);		// Tmr2 Ctrl
		WriteReg(0x39, 0);
		pmmusic.hwpreset = 0;
		WriteReg(0x4A, 0);		// Tmr3 Preset
		WriteReg(0x4B, 0);
		WriteReg(0x48, 0x86);		// Tmr3 Ctrl
	}
}

void pmmusic_stopbgm(void)
{
	pmmusic.aud_ena &= 0x02;
	if (pmmusic.aud_ena == 0) {
		WriteReg(0x38, 0);
		WriteReg(0x48, 0);
	}
}

void pmmusic_playsfx(pmmusic_sfx *sfx)
{
	pmmusic.aud_ena &= 0x01;
	pmmusic.sfx_ppr = sfx;
	pmmusic.sfx_ppr_offset = 0;
	pmmusic.aud_ena |= 0x02;
	pmmusic.sfx_wait = 1;
	WriteReg(0x38, 0x86);		// Tmr2 Ctrl
	WriteReg(0x39, 0);
	pmmusic.hwpreset = 0;
	WriteReg(0x4A, 0);		// Tmr3 Preset
	WriteReg(0x4B, 0);
	WriteReg(0x48, 0x86);		// Tmr3 Ctrl
}

void pmmusic_stopsfx(void)
{
	pmmusic.aud_ena &= 0x01;
	if (pmmusic.aud_ena == 0) {
		WriteReg(0x38, 0);
		WriteReg(0x48, 0);
	}
}

void pmmusic_irq(void)
{
	pmmusic_cmd *cmd;
	int recursivelimit = 65536;
	uint16_t val16;

	// Process BGM
	if (pmmusic.aud_ena & 0x01) {
		// Decrease BGM wait
		if (pmmusic.bgm_wait) pmmusic.bgm_wait--;
		if (!pmmusic.bgm_wait) while (recursivelimit >= 0) {
			recursivelimit--;

			// Read data from BGM pointer
			cmd = &pmmusic.bgm_ppr->cmd[pmmusic.bgm_ppr_offset];
			// Set wait and volume
			pmmusic.bgm_wait = cmd->wait;
			if (cmd->flags & PMMUSIC_FLAG_VOL) {
				pmmusic.bgm_pvol = pmmusic.bgm_tvol[cmd->volume & 3];
			}
			// Increment BGM pointer to next command
			pmmusic.bgm_ppr_offset++;
			if (pmmusic.bgm_ppr_offset > pmmusic.bgm_ppr->numcmd) {
				pmmusic.aud_ena = 0;
				pmmusic.err = 1;
				return;
			}
			// Write RAM
			if (cmd->flags & PMMUSIC_FLAG_WRITERAM) {
				if (pmmusic.ram_ptr) pmmusic.ram_ptr[cmd->ram_addr] = cmd->ram_data;
			}
			// Set Frequency
			if (cmd->flags & PMMUSIC_FLAG_PRESET) {
				pmmusic.bgm_frq = cmd->preset;
			}
			// Set Frequency
			if (cmd->flags & PMMUSIC_FLAG_PIVOT) {
				pmmusic.bgm_pvt = cmd->pivot;
			}
			// Jump pattern / End Sound
			if (cmd->flags & PMMUSIC_FLAG_END) {
				pmmusic_stopbgm();
				return;
			} else if (cmd->flags & PMMUSIC_FLAG_PATTERN) {
				val16 = cmd->pattern;
				pmmusic.bgm_ptb_offset += (val16 >= 0x8000) ? (val16 - 65536) : val16;
				if ((pmmusic.bgm_ptb_offset < 0) || (pmmusic.bgm_ptb_offset >= pmmusic.bgm_ptb->numpattern)) {
					pmmusic.aud_ena = 0;
					pmmusic.err = 2;
					return;
				}
				pmmusic.bgm_ppr = pmmusic.bgm_ptb->pattern[pmmusic.bgm_ptb_offset];
				pmmusic.bgm_ppr_offset = 0;
			}
			// Loop
			if (cmd->flags & PMMUSIC_FLAG_MARK) {
				pmmusic.bgm_loop[cmd->loop_id & 3].ptb_offset = pmmusic.bgm_ptb_offset;
				pmmusic.bgm_loop[cmd->loop_id & 3].ppr_offset = pmmusic.bgm_ppr_offset;
				pmmusic.bgm_loop[cmd->loop_id & 3].loop_num = 0;
			} else if (cmd->flags & PMMUSIC_FLAG_LOOP) {
				if (pmmusic.bgm_loop[cmd->loop_id & 3].loop_num != cmd->loop_num) {
					pmmusic.bgm_loop[cmd->loop_id & 3].loop_num++;
					pmmusic.bgm_ptb_offset = pmmusic.bgm_loop[cmd->loop_id & 3].ptb_offset;
					pmmusic.bgm_ppr = pmmusic.bgm_ptb->pattern[pmmusic.bgm_ptb_offset];
					pmmusic.bgm_ppr_offset = pmmusic.bgm_loop[cmd->loop_id & 3].ppr_offset;
				}
			}
			// All done!
			if (!pmmusic.bgm_wait) continue;
			// Check SFX first as it have higher priority
			if (!pmmusic.sfx_mvol || !(pmmusic.aud_ena & 2)) {
				val16 = pmmusic.bgm_frq;
				WriteReg(0x4A, val16);	// Tmr3 Preset
				WriteReg(0x4B, val16 >> 8);
				val16 = pmmusic.bgm_pvt;
				if (pmmusic.bgm_pvol & 4) {
					val16 >>= 4;
				}
				WriteReg(0x4C, val16);	// Tmr3 Pivot
				WriteReg(0x4D, val16 >> 8);
				WriteReg(0x71, pmmusic.bgm_pvol & 3);	// Audio Volume
			}
			break;
		}
	}

	// Process SFX
	if (pmmusic.aud_ena & 0x02) {
		// Decrease SFX wait
		if (pmmusic.sfx_wait) pmmusic.sfx_wait--;
		if (!pmmusic.sfx_wait) while (recursivelimit >= 0) {
			recursivelimit--;

			// Read data from SFX pointer
			cmd = &pmmusic.sfx_ppr->cmd[pmmusic.sfx_ppr_offset];
			// Set wait and volume
			pmmusic.sfx_wait = cmd->wait;
			if (cmd->flags & PMMUSIC_FLAG_VOL) {
				pmmusic.sfx_pvol = pmmusic.sfx_tvol[cmd->volume & 3];
			}
			// Increment SFX pointer to next command
			pmmusic.sfx_ppr_offset++;
			if (pmmusic.sfx_ppr_offset > pmmusic.sfx_ppr->numcmd) {
				pmmusic.aud_ena = 0;
				pmmusic.err = 3;
				return;
			}
			// Write RAM
			if (cmd->flags & PMMUSIC_FLAG_WRITERAM) {
				if (pmmusic.ram_ptr) pmmusic.ram_ptr[cmd->ram_addr] = cmd->ram_data;
			}
			// Set Frequency
			if (cmd->flags & PMMUSIC_FLAG_PRESET) {
				pmmusic.sfx_frq = cmd->preset;
			}
			// Set Frequency
			if (cmd->flags & PMMUSIC_FLAG_PIVOT) {
				pmmusic.sfx_pvt = cmd->pivot;
			}
			// Jump pattern / End Sound
			if (cmd->flags & PMMUSIC_FLAG_END) {
				pmmusic_stopsfx();
				return;
			} else if (cmd->flags & PMMUSIC_FLAG_PATTERN) {
				pmmusic_stopsfx();
				return;
			}
			// Loop
			if (cmd->flags & PMMUSIC_FLAG_MARK) {
				pmmusic.sfx_loop[cmd->loop_id & 3].ppr_offset = pmmusic.sfx_ppr_offset;
				pmmusic.sfx_loop[cmd->loop_id & 3].loop_num = 0;
			} else if (cmd->flags & PMMUSIC_FLAG_LOOP) {
				if (pmmusic.sfx_loop[cmd->loop_id & 3].loop_num != cmd->loop_num) {
					pmmusic.sfx_loop[cmd->loop_id & 3].loop_num++;
					pmmusic.sfx_ppr_offset = pmmusic.sfx_loop[cmd->loop_id & 3].ppr_offset;
				}
			}
			// All done!
			if (!pmmusic.sfx_wait) continue;
			// Check SFX first as it have higher priority
			val16 = pmmusic.sfx_frq;
			WriteReg(0x4A, val16);	// Tmr3 Preset
			WriteReg(0x4B, val16 >> 8);
			val16 = pmmusic.sfx_pvt;
			if (pmmusic.sfx_pvol & 4) {
				val16 >>= 4;
			}
			WriteReg(0x4C, val16);	// Tmr3 Pivot
			WriteReg(0x4D, val16 >> 8);
			WriteReg(0x71, pmmusic.sfx_pvol & 3);	// Audio Volume
			break;
		}
	}

	if (recursivelimit <= 0) {
		pmmusic.aud_ena = 0;
		pmmusic.err = 4;
		return;
	}
}

void MinxCPU_OnIRQAct(uint8_t intr)
{
	if (intr == MINX_INTR_05) {
		pmmusic_irq();
	}
}

int PokeHWCycles = 0;
void pmmusic_emulate(int lcylc)
{
	PokeHWCycles = 16;
	if (RequireSoundSync) {
		while (lcylc > 0) {
			MinxTimers_Sync();
			MinxAudio_Sync();
			lcylc -= PokeHWCycles;
		}
	} else {
		while (lcylc > 0) {
			MinxTimers_Sync();
			lcylc -= PokeHWCycles;
		}
	}
}

// -------
// Command

int pmmusic_cmd2raw(pmmusic_cmd *cmd, uint16_t *data)
{
	int idx = 1;
	int flags;

	if (!cmd) return 0;
	flags = cmd->flags;

	data[0] = cmd->wait;
	if (flags & PMMUSIC_FLAG_VOL) {
		data[0] |= 0x0400 + ((cmd->volume & 3) << 8);
	} else {
		data[0] |= 0x0300;
	}
	if (flags & PMMUSIC_FLAG_WRITERAM) {
		data[0] |= 0x0800;
		data[idx++] = (cmd->ram_addr << 8) | cmd->ram_data;
	}
	if (flags & PMMUSIC_FLAG_PRESET) {
		data[0] |= 0x1000;
		data[idx++] = cmd->preset;
	}
	if (flags & PMMUSIC_FLAG_PIVOT) {
		data[0] |= 0x2000;
		data[idx++] = cmd->pivot;
	}
	if (flags & PMMUSIC_FLAG_END) {
		data[0] &= 0xFC00;
		data[0] |= 0x4401;
		data[idx++] = 0x0000;
	} else if (flags & PMMUSIC_FLAG_PATTERN) {
		data[0] |= 0x4000;
		data[idx++] = cmd->pattern * 4;
	}
	if (flags & PMMUSIC_FLAG_MARK) {
		data[0] |= 0x8000;
		data[idx++] = (cmd->loop_id << 10);
	} else if (flags & PMMUSIC_FLAG_LOOP) {
		if (cmd->loop_num) {
			data[0] |= 0x8000;
			data[idx++] = (cmd->loop_id << 10) | (cmd->loop_num & 255);
		}
	}
	return idx;
}

// -------
// Pattern

pmmusic_pattern *pmmusic_newpattern(const char *varname, int param)
{
	pmmusic_pattern *pattern;
	pattern = (pmmusic_pattern *)malloc(sizeof(pmmusic_pattern));
	if (!pattern) return NULL;
	memset(pattern->varname, 0, 256);
	strncpy(pattern->varname, varname, 255);
	pattern->param = param;
	pattern->alloccmd = 1;
	pattern->numcmd = 0;
	pattern->cmd = (pmmusic_cmd *)malloc(pattern->alloccmd * sizeof(pmmusic_cmd));
	if (!pattern->cmd) return NULL;
	pattern->allocraw = 1;
	pattern->numraw = 0;
	pattern->raw = (uint16_t *)malloc(pattern->allocraw * sizeof(uint16_t));
	if (!pattern->raw) return NULL;
	return pattern;
}

void pmmusic_deletepattern(pmmusic_pattern *pattern)
{
	if (pattern) {
		if (pattern->cmd) free((void *)pattern->cmd);
		if (pattern->raw) free((void *)pattern->raw);
		free((void *)pattern);
	}
}

void pmmusic_expandpattern(pmmusic_pattern *pattern)
{
	if (pattern->numcmd >= pattern->alloccmd) {
		pattern->alloccmd += pattern->alloccmd;
		pattern->cmd = (pmmusic_cmd *)realloc(pattern->cmd, pattern->alloccmd * sizeof(pmmusic_cmd));
	}
	if (pattern->numraw >= pattern->allocraw) {
		pattern->allocraw += pattern->allocraw;
		pattern->raw = (uint16_t *)realloc(pattern->raw, pattern->allocraw * sizeof(uint16_t));
	}
}

// ---
// BGM

pmmusic_bgm *pmmusic_newbgm(const char *varname, int param)
{
	pmmusic_bgm *bgm;
	bgm = (pmmusic_bgm *)malloc(sizeof(pmmusic_bgm));
	if (!bgm) return NULL;
	memset(bgm->varname, 0, 256);
	strncpy(bgm->varname, varname, 255);
	bgm->param = param;
	bgm->allocpattern = 1;
	bgm->numpattern = 0;
	bgm->pattern = (pmmusic_pattern **)malloc(bgm->allocpattern * sizeof(pmmusic_pattern *));
	if (!bgm->pattern) return NULL;
	return bgm;
}

void pmmusic_deletebgm(pmmusic_bgm *bgm)
{
	if (bgm) {
		if (bgm->pattern) free((void *)bgm->pattern);
		free((void *)bgm);
	}
}

void pmmusic_expandbgm(pmmusic_bgm *bgm)
{
	if (bgm->numpattern >= bgm->allocpattern) {
		bgm->allocpattern += bgm->allocpattern;
		bgm->pattern = (pmmusic_pattern **)realloc(bgm->pattern, bgm->allocpattern * sizeof(pmmusic_pattern *));
	}
}

// ----
// List

pmmusic_list *pmmusic_newlist(void)
{
	pmmusic_list *list;
	list = (pmmusic_list *)malloc(sizeof(pmmusic_list));
	if (!list) return NULL;
	list->pattern = NULL;
	list->bgm = NULL;
	list->sfx = NULL;

	list->allocpattern = 1;
	list->numpattern = 0;
	list->pattern = (pmmusic_pattern **)malloc(list->allocpattern * sizeof(pmmusic_pattern *));
	if (!list->pattern) {
		pmmusic_deletelist(list);
		return NULL;
	}

	list->allocbgm = 1;
	list->numbgm = 0;
	list->bgm = (pmmusic_bgm **)malloc(list->allocbgm * sizeof(pmmusic_bgm *));
	if (!list->bgm) {
		pmmusic_deletelist(list);
		return NULL;
	}

	list->allocsfx = 1;
	list->numsfx = 0;
	list->sfx = (pmmusic_sfx **)malloc(list->allocsfx * sizeof(pmmusic_sfx *));
	if (!list->sfx) {
		pmmusic_deletelist(list);
		return NULL;
	}
	return list;
}

void pmmusic_deletelist(pmmusic_list *list)
{
	int i;
	if (list) {
		if (list->pattern) {
			for (i=0; i<list->numpattern; i++) pmmusic_deletepattern(list->pattern[i]);
			free((void *)list->pattern);
		}
		if (list->bgm) {
			for (i=0; i<list->numbgm; i++) pmmusic_deletebgm(list->bgm[i]);
			free((void *)list->bgm);
		}
		if (list->sfx) {
			for (i=0; i<list->numsfx; i++) pmmusic_deletepattern(list->sfx[i]);
			free((void *)list->sfx);
		}
		free((void *)list);
	}
}

pmmusic_pattern *pmmusic_newPAT(pmmusic_list *list, const char *varname, int param)
{
	if (list->numpattern >= list->allocpattern) {
		list->allocpattern += list->allocpattern;
		list->pattern = (pmmusic_pattern **)realloc(list->pattern, list->allocpattern * sizeof(pmmusic_pattern *));
	}
	list->pattern[list->numpattern] = pmmusic_newpattern(varname, param);
	return list->pattern[list->numpattern++];
}

pmmusic_bgm *pmmusic_newBGM(pmmusic_list *list, const char *varname, int param)
{
	if (list->numbgm >= list->allocbgm) {
		list->allocbgm += list->allocbgm;
		list->bgm = (pmmusic_bgm **)realloc(list->bgm, list->allocbgm * sizeof(pmmusic_bgm *));
	}
	list->bgm[list->numbgm] = pmmusic_newbgm(varname, param);
	return list->bgm[list->numbgm++];
}

pmmusic_sfx *pmmusic_newSFX(pmmusic_list *list, const char *varname, int param)
{
	if (list->numsfx >= list->allocsfx) {
		list->allocsfx += list->allocsfx;
		list->sfx = (pmmusic_sfx **)realloc(list->sfx, list->allocsfx * sizeof(pmmusic_sfx *));
	}
	list->sfx[list->numsfx] = pmmusic_newpattern(varname, param);
	return list->sfx[list->numsfx++];
}

int pmmusic_delPAT(pmmusic_list *list, pmmusic_pattern *pattern)
{
	int i, j;
	for (i=0; i<list->numpattern; i++) {
		if (pattern == list->pattern[i]) {
			pmmusic_deletepattern(pattern);
			for (j=i; j<list->numpattern-1; j++) {
				list->pattern[j] = list->pattern[j+1];
			}
			list->numpattern--;
			return 1;
		}
	}
	return 0;
}

int pmmusic_delBGM(pmmusic_list *list, pmmusic_bgm *bgm)
{
	int i, j;
	for (i=0; i<list->numbgm; i++) {
		if (bgm == list->bgm[i]) {
			pmmusic_deletebgm(bgm);
			for (j=i; j<list->numbgm-1; j++) {
				list->bgm[j] = list->bgm[j+1];
			}
			list->numbgm--;
			return 1;
		}
	}
	return 0;
}

int pmmusic_delSFX(pmmusic_list *list, pmmusic_sfx *sfx)
{
	int i, j;
	for (i=0; i<list->numsfx; i++) {
		if (sfx == list->sfx[i]) {
			pmmusic_deletepattern(sfx);
			for (j=i; j<list->numsfx-1; j++) {
				list->sfx[j] = list->sfx[j+1];
			}
			list->numsfx--;
			return 1;
		}
	}
	return 0;
}

int pmmusic_existVAR(pmmusic_list *list, const char *varname, int *type, int *index)
{
	int i;
	for (i=0; i<list->numpattern; i++) {
		if (!strcasecmp(varname, list->pattern[i]->varname)) {
			if (type) *type = 0;
			if (index) *index = i;
			return 1;
		}
	}
	for (i=0; i<list->numbgm; i++) {
		if (!strcasecmp(varname, list->bgm[i]->varname)) {
			if (type) *type = 1;
			if (index) *index = i;
			return 1;
		}
	}
	for (i=0; i<list->numsfx; i++) {
		if (!strcasecmp(varname, list->sfx[i]->varname)) {
			if (type) *type = 2;
			if (index) *index = i;
			return 1;
		}
	}
	return 0;
}

pmmusic_pattern *pmmusic_getPAT(pmmusic_list *list, const char *varname, int *index)
{
	int i;
	for (i=0; i<list->numpattern; i++) {
		if (!strcasecmp(varname, list->pattern[i]->varname)) {
			if (index) *index = i;
			return list->pattern[i];
		}
	}
	return NULL;
}

pmmusic_bgm *pmmusic_getBGM(pmmusic_list *list, const char *varname, int *index)
{
	int i;
	for (i=0; i<list->numbgm; i++) {
		if (!strcasecmp(varname, list->bgm[i]->varname)) {
			if (index) *index = i;
			return list->bgm[i];
		}
	}
	return NULL;
}

pmmusic_pattern *pmmusic_getSFX(pmmusic_list *list, const char *varname, int *index)
{
	int i;
	for (i=0; i<list->numsfx; i++) {
		if (!strcasecmp(varname, list->sfx[i]->varname)) {
			if (index) *index = i;
			return list->sfx[i];
		}
	}
	return NULL;
}

int pmmusic_addSEQ(pmmusic_bgm *bgm, pmmusic_pattern *pattern, int index)
{
	int j;
	if ((index < -1) || (index > bgm->numpattern)) return 0;
	if (index == -1) index = bgm->numpattern;
	pmmusic_expandbgm(bgm);
	if (index != bgm->numpattern) {
		for (j=bgm->numpattern-1; j>=index; j++) {
			bgm->pattern[j+1] = bgm->pattern[j];
		}
	}
	bgm->pattern[index] = pattern;
	bgm->numpattern++;
	return 1;
}

int pmmusic_delSEQ(pmmusic_bgm *bgm, int index)
{
	int j;
	if ((index < 0) || (index >= bgm->numpattern)) return 0;
	for (j=index; j<bgm->numpattern-1; j++) {
		bgm->pattern[j] = bgm->pattern[j+1];
	}
	bgm->numpattern--;
	return 1;
}

int pmmusic_addCMD(pmmusic_pattern *pattern, pmmusic_cmd *cmd, int index)
{
	int j;
	if ((index < -1) || (index > pattern->numcmd)) return 0;
	if (index == -1) index = pattern->numcmd;
	pmmusic_expandpattern(pattern);
	if (index != pattern->numcmd) {
		for (j=pattern->numcmd-1; j>=index; j++) {
			memcpy(&pattern->cmd[j+1], &pattern->cmd[j], sizeof(pmmusic_cmd));
		}
	}
	memcpy(&pattern->cmd[index], cmd, sizeof(pmmusic_cmd));
	pattern->numcmd++;
	return 1;
}

int pmmusic_delCMD(pmmusic_pattern *pattern, int index)
{
	int j;
	if ((index < 0) || (index >= pattern->numcmd)) return 0;
	for (j=index; j<pattern->numcmd-1; j++) {
		memcpy(&pattern->cmd[j], &pattern->cmd[j+1], sizeof(pmmusic_cmd));
	}
	pattern->numcmd--;
	return 1;
}

int pmmusic_asmPAT(pmmusic_pattern *pattern)
{
	uint16_t data[8];
	int i, j, siz;
	pattern->numraw = 0;
	for (i=0; i<pattern->numcmd; i++) {
		siz = pmmusic_cmd2raw(&pattern->cmd[i], data);
		for (j=0; j<siz; j++) {
			pmmusic_expandpattern(pattern);
			pattern->raw[pattern->numraw++] = data[j];
		}
	}
	return 1;
}
