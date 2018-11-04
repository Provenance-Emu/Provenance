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

#ifndef PM_MUSIC_H
#define PM_MUSIC_H

#include <stdint.h>

enum {
	PMMUSTMR_DIV_OFF = 0,
	PMMUSTMR_DIV_2 = 8,
	PMMUSTMR_DIV_8 = 9,
	PMMUSTMR_DIV_32 = 10,
	PMMUSTMR_DIV_64 = 11,
	PMMUSTMR_DIV_128 = 12,
	PMMUSTMR_DIV_256 = 13,
	PMMUSTMR_DIV_1024 = 14,
	PMMUSTMR_DIV_4096 = 15
};

enum {
	PMMUSIC_FLAG_VOL = 1,
	PMMUSIC_FLAG_WRITERAM = 2,
	PMMUSIC_FLAG_PRESET = 4,
	PMMUSIC_FLAG_PIVOT = 8,
	PMMUSIC_FLAG_END = 16,
	PMMUSIC_FLAG_PATTERN = 32,
	PMMUSIC_FLAG_MARK = 64,
	PMMUSIC_FLAG_LOOP = 128,
};

typedef struct {
	int flags;		// Flags
	int wait;		// Wait (0 = immediate)
	uint8_t volume;		// Volume (0 to 3)
	uint8_t ram_addr;	// RAM address (0 to 255)
	uint8_t ram_data;	// RAM data (0 to 255)
	uint16_t preset;	// Preset
	uint16_t pivot;		// Pivot
	int pattern;		// Pattern offset
	uint8_t loop_id;	// Loop ID (0 to 3)
	uint8_t loop_num;	// Number of loops (0 to 255)
} pmmusic_cmd;

typedef struct {
	void *metadata;		// Meta data
	char varname[256];	// Variable name
	int param;		// Parameter

	// Commands list
	int alloccmd;		// Num. allocated commands
	int numcmd;		// Number of commands
	pmmusic_cmd *cmd;	// Commands structures

	// Assembled commands list
	int allocraw;		// Num. allocated RAW commands
	int numraw;		// Number of RAW commands
	uint16_t *raw;		// RAW commands structures
} pmmusic_pattern, pmmusic_sfx;

typedef struct {
	void *metadata;		// Meta data
	char varname[256];	// Variable name
	int param;		// Parameter

	// Patterns list
	int allocpattern;	// Num. allocated patterns
	int numpattern;		// Number of patterns
	pmmusic_pattern **pattern;	// Patterns pointers
} pmmusic_bgm;

typedef struct {
	// Hardware
	int err;
	uint16_t mtime;
	uint16_t hwpreset;
	uint16_t hwpivot;
	uint8_t hwvol;

	// Main Data
	uint8_t aud_ena;
	uint8_t *ram_ptr;
	pmmusic_bgm *bgm_ptb;
	int bgm_ptb_offset;

	// BGM Data
	uint8_t bgm_wait;
	uint8_t bgm_mvol;
	uint8_t bgm_pvol;
	pmmusic_pattern *bgm_ppr;
	int bgm_ppr_offset;
	uint16_t bgm_frq;
	uint16_t bgm_pvt;
	uint8_t bgm_tvol[4];
	struct {
		int ptb_offset;
		int ppr_offset;
		uint8_t loop_num;
	} bgm_loop[4];

	// SFX Data
	uint8_t sfx_wait;
	uint8_t sfx_mvol;
	uint8_t sfx_pvol;
	pmmusic_sfx *sfx_ppr;
	int sfx_ppr_offset;
	uint16_t sfx_frq;
	uint16_t sfx_pvt;
	uint8_t sfx_tvol[4];
	struct {
		int ppr_offset;
		uint8_t loop_num;
	} sfx_loop[4];
} pmmusram;

typedef struct {
	void *metadata;		// Meta data

	// Patterns list
	int allocpattern;	// Num. allocated BGM Patterns
	int numpattern;		// Number of BGM Patterns
	pmmusic_pattern **pattern;	// BGM Patterns pointers
	void *metadata_pattern;	// Meta data (Patterns)

	// BGM list
	int allocbgm;		// Num. allocated SFXs
	int numbgm;		// Number of BGMs
	pmmusic_bgm **bgm;	// BGMs pointers
	void *metadata_bgm;	// Meta data (BGM)

	// SFX list
	int allocsfx;		// Num. allocated SFXs
	int numsfx;		// Number of SFXs
	pmmusic_sfx **sfx;	// SFXs pointers
	void *metadata_sfx;	// Meta data (SFX)
} pmmusic_list;

extern pmmusram pmmusic;

// Initialize / Terminate
int pmmusic_initialize(int soundfifo, int sndengine, int sndfilter);
void pmmusic_terminate(void);

// Playback
void pmmusic_init(uint16_t mastertempo, uint8_t *ramptr);
uint8_t pmmusic_getvolbgm(void);
void pmmusic_setvolbgm(uint8_t volume);
uint8_t pmmusic_getvolsfx(void);
void pmmusic_setvolsfx(uint8_t volume);
void pmmusic_playbgm(pmmusic_bgm *bgm);
void pmmusic_stopbgm(void);
void pmmusic_playsfx(pmmusic_sfx *sfx);
void pmmusic_stopsfx(void);
void pmmusic_emulate(int lcylc);

// Command
int pmmusic_cmd2raw(pmmusic_cmd *cmd, uint16_t *data);

// Pattern
pmmusic_pattern *pmmusic_newpattern(const char *varname, int param);
void pmmusic_deletepattern(pmmusic_pattern *pattern);
void pmmusic_expandpattern(pmmusic_pattern *pattern);

// BGM
pmmusic_bgm *pmmusic_newbgm(const char *varname, int param);
void pmmusic_deletebgm(pmmusic_bgm *bgm);
void pmmusic_expandbgm(pmmusic_bgm *bgm);

// List
pmmusic_list *pmmusic_newlist();
void pmmusic_deletelist(pmmusic_list *list);

pmmusic_pattern *pmmusic_newPAT(pmmusic_list *list, const char *varname, int param);
pmmusic_bgm *pmmusic_newBGM(pmmusic_list *list, const char *varname, int param);
pmmusic_sfx *pmmusic_newSFX(pmmusic_list *list, const char *varname, int param);

int pmmusic_delPAT(pmmusic_list *list, pmmusic_pattern *pattern);
int pmmusic_delBGM(pmmusic_list *list, pmmusic_bgm *bgm);
int pmmusic_delSFX(pmmusic_list *list, pmmusic_sfx *sfx);

int pmmusic_existVAR(pmmusic_list *list, const char *varname, int *type, int *index);

pmmusic_pattern *pmmusic_getPAT(pmmusic_list *list, const char *varname, int *index);
pmmusic_bgm *pmmusic_getBGM(pmmusic_list *list, const char *varname, int *index);
pmmusic_sfx *pmmusic_getSFX(pmmusic_list *list, const char *varname, int *index);

int pmmusic_addSEQ(pmmusic_bgm *bgm, pmmusic_pattern *pattern, int index);
int pmmusic_delSEQ(pmmusic_bgm *bgm, int index);

int pmmusic_addCMD(pmmusic_pattern *pattern, pmmusic_cmd *cmd, int index);
int pmmusic_delCMD(pmmusic_pattern *pattern, int index);

int pmmusic_asmPAT(pmmusic_pattern *pattern);

#endif
