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
#include <stdarg.h>
#include <ctype.h>
#include <signal.h>

#include "saudio_al.h"
#include "raw_input.h"

#include "PMCommon.h"
#include "PokeMini.h"
#include "ExportCode.h"
#include "ExportWAV.h"
#include "pokemini_musicconv.h"
#include "pm_music.h"

#define VERSION_STR	"v1.4"
#define EXPORT_STR	"Music exported with PokeMini Music Converter " VERSION_STR

#define STR_MTIME	"%s_mastertime"
#define STR_TITLE	"%s_title"
#define STR_COMPOSER	"%s_composer"
#define STR_PROGRAMMER	"%s_programmer"
#define STR_DESCRIPTION	"%s_description"
#define STR_NUMPAT	"%s_numpat"
#define STR_NUMBGM	"%s_numbgm"
#define STR_NUMSFX	"%s_numsfx"

#define STR_APPEND_SFX	"_sfxlist"
#define STR_APPEND_BGM	"_bgmlist"

// Sound buffer size
#define SOUNDBUFFER	2048
#define PMSNDBUFFER	(SOUNDBUFFER*4)
FILE *sdump = NULL;

// ---------- Header ----------

char p_file[128];
int p_line;
int p_recursive = 0;
int p_comment = 0;
int p_brace = 0;
int p_dloop = 0;
int p_bpat = 0, p_bpatloop = -1;
int notbreak = 1;

pmmusic_list *musiclist;
pmmusic_pattern *macro_pat[26] = {NULL};

struct {
	int quiet;		// Quiet
	int verbose;		// Verbose
	int sndengine;		// Sound engine
	int sndfilter;		// Piezo filter
	char mus_f[128];	// Music file
	char mus_v[128];	// Music variable name
	int format;		// 1 = Asm, 2 = C
	char out_f[128];	// Output file
	char outh_f[128];	// Output header file
	char outl_f[128];	// Output sound list file
	char sfx_v[128];	// SFX variable name
	char bgm_v[128];	// BGM variable name
	char rec_f[128];	// Record music file
	char play_v[128];	// Playback variable name
} confs;

struct {
	char title[256];	// Title
	char composer[256];	// Composer name
	char programmer[256];	// Programmer name
	char description[256];	// Description
	uint8_t ram[256];	// RAM content for modules
	int vollevel;		// Volume level: 0 = MML (0 to 15), 1 = System (0 to 3)
	int octrev;		// Reverse octave characters?
	int shortq;		// Shorter quantize range?
	int mastertime_set;	// Master time has been set?
	int mastertime_val;	// Master time value
	struct {
		int wait;	// Wait
		int note;	// Note
		int note2;	// Note 2 for effects
		int note3;	// Note 3 for effects
		int ramaddr;	// RAM address
		int ramdata;	// RAM data
		int length;	// Length
		int octave;	// Octave
		int volume;	// Volume
		int pulse;	// Pulse-width
		int quantize;	// Quantize
		int arpptr;	// Arpeggio pointer
		int efftype;	// Effect type
		int efftick;	// Effect ticks
		int sustain;	// Sustain
	} cur;
	struct {
		int wait;	// Wait
		int note;	// Note
		int note2;	// Note 2 for effects
		int note3;	// Note 3 for effects
		int ramaddr;	// RAM address
		int ramdata;	// RAM data
		int length;	// Length
		int octave;	// Octave
		int volume;	// Volume
		int pulse;	// Pulse-width
		int quantize;	// Quantize
		int arpptr;	// Arpeggio pointer
		int efftype;	// Effect type
		int efftick;	// Effect ticks
		int sustain;	// Sustain
	} def;
} musicsh;

enum {
	EFFECT_DISABLED,
	EFFECT_ARPEGGIO,
	EFFECT_PORTAMENTO,
	EFFECT_RANDOM
} EffectsTypes;

// ---------- Conf ----------

// Initialize confs
void init_confs()
{
	memset((void *)&confs, 0, sizeof(confs));
	confs.format = FILE_ECODE_ASM;
	confs.sndengine = MINX_AUDIO_DIRECT;
	confs.sndfilter = 1;
}

// Load confs from arguments
int load_confs_args(int argc, char **argv)
{
	argv++;
	while (*argv) {
		if (*argv[0] == '-') {
			if (!strcasecmp(*argv, "-asmf")) confs.format = FILE_ECODE_ASM;
			else if (!strcasecmp(*argv, "-cf")) confs.format = FILE_ECODE_C;
			else if (!strcasecmp(*argv, "-i")) { if (*++argv) strncpy(confs.mus_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-in")) { if (*++argv) strncpy(confs.mus_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-input")) { if (*++argv) strncpy(confs.mus_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-o")) { if (*++argv) strncpy(confs.out_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-out")) { if (*++argv) strncpy(confs.out_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-output")) { if (*++argv) strncpy(confs.out_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-oh")) { if (*++argv) strncpy(confs.outh_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outheader")) { if (*++argv) strncpy(confs.outh_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outputheader")) { if (*++argv) strncpy(confs.outh_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-ol")) { if (*++argv) strncpy(confs.outl_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outlist")) { if (*++argv) strncpy(confs.outl_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-outputlist")) { if (*++argv) strncpy(confs.outl_f, *argv, 127); }
			else if (!strcasecmp(*argv, "-vh")) { if (*++argv) strncpy(confs.mus_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-varheader")) { if (*++argv) strncpy(confs.mus_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vsfx")) { if (*++argv) strncpy(confs.sfx_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-varsfx")) { if (*++argv) strncpy(confs.sfx_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-vbgm")) { if (*++argv) strncpy(confs.bgm_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-varbgm")) { if (*++argv) strncpy(confs.bgm_v, *argv, 127); }
			else if (!strcasecmp(*argv, "-snddirect")) confs.sndengine = MINX_AUDIO_DIRECT;
			else if (!strcasecmp(*argv, "-sndemulated")) confs.sndengine = MINX_AUDIO_EMULATED;
			else if (!strcasecmp(*argv, "-piezo")) confs.sndfilter = 1;
			else if (!strcasecmp(*argv, "-nopiezo")) confs.sndfilter = 0;
			else if (!strcasecmp(*argv, "-q")) confs.quiet = 1;
			else if (!strcasecmp(*argv, "-v")) confs.verbose = 1;
			else if (!strcasecmp(*argv, "-sv")) confs.verbose = 2;
			else if (!strcasecmp(*argv, "-play")) {
				if (*++argv) strncpy(confs.play_v, *argv, 127);
			}
			else if (!strcasecmp(*argv, "-towav")) {
				if (*++argv) strncpy(confs.rec_f, *argv, 127);
			}
			else return 0;
		} else return 0;
		if (*argv) argv++;
	}

	// Music filename cannot be empty
	if (!strlen(confs.mus_f)) return 0;

	return 1;
}

// ---------- Converter ----------

// Notes table (Octave 1 to 7)
int N_Note[7*12] = {
	0xEEE3, 0xE17A, 0xD4D2, 0xC8E0, 0xBD9A, 0xB2F6, 0xA8EA, 0x9F6F, 0x967C, 0x8E0A, 0x8611, 0x7E8B,
	0x7771, 0x70BC, 0x6A68, 0x646F, 0x5ECC, 0x597A, 0x5474, 0x4FB7, 0x4B3D, 0x4704, 0x4308, 0x3F45,
	0x3BB8, 0x385D, 0x3533, 0x3237, 0x2F65, 0x2CBC, 0x2A39, 0x27DB, 0x259E, 0x2381, 0x2183, 0x1FA2,
	0x1DDB, 0x1C2E, 0x1A99, 0x191B, 0x17B2, 0x165D, 0x151C, 0x13ED, 0x12CE, 0x11C0, 0x10C1, 0x0FD0,
	0x0EED, 0x0E16, 0x0D4C, 0x0C8D, 0x0BD8, 0x0B2E, 0x0A8D, 0x09F6, 0x0966, 0x08DF, 0x0860, 0x07E7,
	0x0776, 0x070A, 0x06A5, 0x0646, 0x05EB, 0x0596, 0x0546, 0x04FA, 0x04B2, 0x046F, 0x042F, 0x03F3,
	0x03BA, 0x0384, 0x0352, 0x0322, 0x02F5, 0x02CA, 0x02A2, 0x027C, 0x0258, 0x0237, 0x0217, 0x01F9
};

// Get note frequency from offsets
uint16_t getnotefreq(int noteoff, int octoff)
{
	octoff--;
	int num = (octoff * 12) + (noteoff - 12);
	if ((num < 0) || (num >= (7*12))) return 0xFFFF;
	if (num < 0) num = 0;
	if (num >= (7*12)) num = 7*12-1;
	return N_Note[num];
}

// Level: -1 = Error, 0 = Warning, 1 = Default, 2 = Verbose, 3 = Super-verbose
void Pprintf(int level, const char *fmt, ...)
{
	va_list args;

	// Permission
	if (level > 0) {
		if (confs.quiet) return;
		if ((level == 2) && (confs.verbose < 1)) return;
		if ((level == 3) && (confs.verbose < 2)) return;
	}

	// Output
	va_start(args, fmt);
	if (level >= 0) printf("%s[%i] ", p_file, p_line);
	else fprintf(stderr, "%s[%i] ", p_file, p_line);
	vprintf(fmt, args);
	va_end(args);
}

// Remove comments (C style)
void RemoveCommentsC(char *so)
{
	char *s = so;
	while (*s) {
		if ((s[0] == '/') && (s[1] == '*')) {
			p_comment = 1;
			strcpy(s, s+2);
		} else if ((s[0] == '*') && (s[1] == '/')) {
			p_comment = 0;
			strcpy(s, s+2);
		}
		if (p_comment) {
			strcpy(s, s+1);
		} else {
			if ((s[0] == '/') && (s[1] == '/')) {
				if (!p_comment) *s = 0;
				break;
			} else s++;
		}
	}
}

// Read number
const char *readmus_num(const char *s, int *nout, int maxhdigits)
{
	int hexmode = 0, digits = 0, num = 0, negsign = 0;
	do { s++; } while ((*s == ' ') || (*s == '\t')); // Skipping 1 is intentional
	if ((s[0] == '0') && (tolower(s[1]) == 'x')) { hexmode = 1; s += 2; }
	else if (s[0] == '$') { hexmode = 1; s++; }
	if (s[0] == '-') { negsign = 1; s++; }
	while (*s != 0) {
		if (hexmode) {
			if (digits == maxhdigits) break;
			if ((*s >= '0') && (*s <= '9')) num = (num * 16) + (*s - '0');
			else if ((*s >= 'A') && (*s <= 'F')) num = (num * 16) + (*s - 'A');
			else if ((*s >= 'a') && (*s <= 'f')) num = (num * 16) + (*s - 'a');
			else break;
			digits++;
		} else {
			if ((*s >= '0') && (*s <= '9')) num = (num * 10) + (*s - '0');
			else break;
			digits++;
		}
		s++;
	}
	if (nout && digits) *nout = negsign ? -num : num;
	return s-1;
}

// Read line
char *readmus_line(FILE *fi, char *s, int len)
{
	if (!fgets(s, len, fi)) return 0;
	p_line++;
	RemoveCommentsC(s);
	return TrimStr(s);
}

// Add note from specs
void pattern_addnote(pmmusic_pattern *pattern, int wait, int portoff, int porttot, int preset, int preset2, int preset3, int volume)
{
	pmmusic_cmd cmd;
	int posfx;
	if (wait <= 0) wait = 1;
	do {
		// Wait
		cmd.wait = (wait > 255) ? 255 : wait;
		if (volume && musicsh.cur.efftype) cmd.wait = musicsh.cur.efftick;
		// Flags
		cmd.flags = PMMUSIC_FLAG_VOL;
		if (preset >= 0) cmd.flags |= PMMUSIC_FLAG_PRESET | PMMUSIC_FLAG_PIVOT;
		if (musicsh.cur.ramaddr >= 0) cmd.flags |= PMMUSIC_FLAG_WRITERAM;
		// Effects
		if (musicsh.cur.efftype == EFFECT_ARPEGGIO) {
			if (musicsh.def.arpptr == 0) cmd.preset = preset;
			else if (musicsh.def.arpptr == 1) cmd.preset = preset2;
			else if (musicsh.def.arpptr == 2) cmd.preset = preset3;
		} else if (musicsh.cur.efftype == EFFECT_PORTAMENTO) {
			posfx = portoff * 32768 / porttot;
			cmd.preset = ((32768-posfx) * preset + posfx * preset2) >> 15;
		} else if (musicsh.cur.efftype == EFFECT_RANDOM) {
			posfx = rand() & 32767;
			cmd.preset = ((32768-posfx) * preset + posfx * preset2) >> 15;
		} else cmd.preset = preset;
		// Setup and send command
		cmd.pivot = cmd.preset * musicsh.cur.pulse / 256;
		cmd.volume = volume;
		cmd.ram_addr = musicsh.cur.ramaddr;
		cmd.ram_data = musicsh.cur.ramdata;
		if (cmd.volume < 0) cmd.volume = 0;
		if (cmd.volume > 3) cmd.volume = 3;
		pmmusic_addCMD(pattern, &cmd, -1);
		wait -= cmd.wait;
		portoff += cmd.wait;
		musicsh.cur.ramaddr = -1;
		musicsh.cur.ramdata = -1;
		musicsh.def.arpptr = (musicsh.def.arpptr + 1) % 3;
	} while (wait > 0);
}

// Parse note by applying effects
void parse_pattern_note(pmmusic_pattern *pattern, int noteid, double len, int mode)
{
	int wait, waiton, waitoff, waitsus, waitrel;
	int note, note2, note3;
	pmmusic_cmd cmd;
	memset((void *)&cmd, 0, sizeof(pmmusic_cmd));

	if (len <= 0.0) return;
	if (mode == 1) {
		Pprintf(3, "Info: Note %i (len=%.2f)\n", noteid, len);
		wait = (int)((double)musicsh.cur.wait / len);
		note = getnotefreq(noteid, musicsh.cur.octave);
		note2 = getnotefreq(noteid + musicsh.cur.note2, musicsh.cur.octave);
		note3 = getnotefreq(noteid + musicsh.cur.note3, musicsh.cur.octave);
	} else if (mode == 0) {
		Pprintf(3, "Info: Note %i (wait=%i)\n", noteid, (int)len);
		wait = (int)len;
		note = getnotefreq(noteid, musicsh.cur.octave);
		note2 = getnotefreq(noteid + musicsh.cur.note2, musicsh.cur.octave);
		note3 = getnotefreq(noteid + musicsh.cur.note3, musicsh.cur.octave);
	} else {
		Pprintf(3, "Info: Wait (wait=%i)\n", (int)len);
		wait = (int)len;
		note = -1;
		note2 = -1;
		note3 = -1;
	}
	if (wait <= 0) wait = 1;
	waiton = (wait * musicsh.cur.quantize) / 64;
	waitoff = wait - waiton;
	if (waiton) {
		waitsus = (waiton * musicsh.cur.sustain) / 64;
		waitrel = waiton - waitsus;
		if (waitsus) pattern_addnote(pattern, waitsus, 0,       waiton, note, note2, note3, musicsh.cur.volume);
		if (waitrel) pattern_addnote(pattern, waitrel, waitsus, waiton, note, note2, note3, musicsh.cur.volume-1);
	}
	if (waitoff) pattern_addnote(pattern, waitoff, 0, waitoff, note, note2, note3, 0);
}

// Parse pattern (MML)
int parse_pattern(const char *s, int sfx, pmmusic_pattern *pattern)
{
	pmmusic_cmd cmd, *cmdptr;
	int num, num2, noteid;
	double dnum;

	memset((void *)&cmd, 0, sizeof(pmmusic_cmd));
	while (*s != 0) {
		switch (*s) {
			case ' ': case '\t': case '\n': // Ignore
				break;
			case '{': if (p_brace) {
					Pprintf(-1, "Error: Open brace already declared\n");
					exit(1);
				}
				p_brace++;
				break;
			case '}': if (!p_brace) {
					Pprintf(-1, "Error: Closing brace without open\n");
					exit(1);
				}
				p_brace--;
				if (!p_brace) return 0;
				break;
			case '[': // Loop start
				Pprintf(3, "Info: Starting loop %i\n", p_dloop);
				cmd.wait = 0;
				cmd.flags = PMMUSIC_FLAG_MARK;
				cmd.loop_id = p_dloop;
				pmmusic_addCMD(pattern, &cmd, -1);
				p_dloop++;
				if (p_dloop == 3) {
					Pprintf(-1, "Error: Number of loops exceeded\n");
					exit(1);
				}
				break;
			case ']': // Loop end
				if (sfx) {
					Pprintf(-1, "Error: Looping isn't supported in SFX\n");
					exit(1);
				}
				if (p_dloop) {
					p_dloop--;
					num = 2;
					s = readmus_num(s, &num, 2);
					if (num <= 0) {
						Pprintf(-1, "Error: Number of loops need to be >= 1\n");
						exit(1);
					}
					Pprintf(3, "Info: Ending loop %i (num=%i)\n", p_dloop, num);
					cmd.wait = 0;
					cmd.flags = PMMUSIC_FLAG_LOOP;
					cmd.loop_id = p_dloop;
					cmd.loop_num = num - 1;
					pmmusic_addCMD(pattern, &cmd, -1);
				} else {
					Pprintf(-1, "Error: Closing loop without open\n");
					exit(1);
				}
				break;
			case 'c': // C note
				noteid = 0;
				if (s[1] == '-') { noteid = -1; s++; }
				else if (s[1] == '+') { noteid = 1; s++; }
				else if (s[1] == '#') { noteid = 1; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'd': // D note
				noteid = 2;
				if (s[1] == '-') { noteid = 1; s++; }
				else if (s[1] == '+') { noteid = 3; s++; }
				else if (s[1] == '#') { noteid = 3; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'e': // E note
				noteid = 4;
				if (s[1] == '-') { noteid = 3; s++; }
				else if (s[1] == '+') { noteid = 5; s++; }
				else if (s[1] == '#') { noteid = 5; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'f': // F note
				noteid = 5;
				if (s[1] == '-') { noteid = 4; s++; }
				else if (s[1] == '+') { noteid = 6; s++; }
				else if (s[1] == '#') { noteid = 6; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'g': // G note
				noteid = 7;
				if (s[1] == '-') { noteid = 6; s++; }
				else if (s[1] == '+') { noteid = 8; s++; }
				else if (s[1] == '#') { noteid = 8; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'a': // A note
				noteid = 9;
				if (s[1] == '-') { noteid = 8; s++; }
				else if (s[1] == '+') { noteid = 10; s++; }
				else if (s[1] == '#') { noteid = 10; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'b': // B note
				noteid = 11;
				if (s[1] == '-') { noteid = 10; s++; }
				else if (s[1] == '+') { noteid = 12; s++; }
				else if (s[1] == '#') { noteid = 12; s++; }
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				parse_pattern_note(pattern, noteid, dnum, 1);
				break;
			case 'r': // Rest
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.') && (s[4] == '.')) { dnum = (double)num / 1.9375; s += 4; }
				if ((s[1] == '.') && (s[2] == '.') && (s[3] == '.')) { dnum = (double)num / 1.875; s += 3; }
				if ((s[1] == '.') && (s[2] == '.')) { dnum = (double)num / 1.75; s += 2; }
				if (s[1] == '.') { dnum = (double)num / 1.5; s++; }
				else dnum = (double)num;
				if (dnum <= 0.0) break;
				Pprintf(3, "Info: Rest (len=%.2f)\n", dnum);
				cmd.wait = (int)((double)musicsh.cur.wait / dnum);
				if (cmd.wait == 0) cmd.wait = 1;
				cmd.flags = PMMUSIC_FLAG_VOL;
				cmd.volume = 0;
				pmmusic_addCMD(pattern, &cmd, -1);
				break;
			case '%': // Pulse-width
				num = musicsh.cur.pulse;
				s = readmus_num(s, &num, 2);
				if (num < 0) num = 0;
				if (num > 255) num = 255;
				Pprintf(3, "Info: Pulse-width %i (%i%%)\n", num, num * 100 / 255);
				musicsh.cur.pulse = num;
				break;
			case '\\': // Pulse-width in percentage
			case '/':
				num = musicsh.cur.pulse;
				s = readmus_num(s, &num, 2);
				num = num * 255 / 100;
				if (num < 0) num = 0;
				if (num > 255) num = 255;
				Pprintf(3, "Info: Pulse-width %i (%i%%)\n", num, num * 100 / 255);
				musicsh.cur.pulse = num;
				break;
			case 'v': // Volume
				num = musicsh.cur.volume;
				if (musicsh.vollevel) {
					if (musicsh.cur.volume == 1) num = 4;
					else if (musicsh.cur.volume == 2) num = 8;
					else if (musicsh.cur.volume == 3) num = 15;
				}
				s = readmus_num(s, &num, 1);
				if (num < 0) num = 0;
				if (musicsh.vollevel) {
					if (num > 15) num = 15;
					if (num > 8) num2 = 3;
					else if (num > 4) num2 = 2;
					else if (num > 2) num2 = 1;
					else num2 = 0;
					Pprintf(3, "Info: Volume %i (%i)\n", num, num2);
					musicsh.cur.volume = num2;
				} else {
					if (num > 3) num = 3;
					Pprintf(3, "Info: Volume %i\n", num);
					musicsh.cur.volume = num;
				}
				break;
			case 'w': // Wait
				num = musicsh.cur.wait;
				s = readmus_num(s, &num, 2);
				if (num < 0) num = 0;
				if (num > 255) num = 255;
				Pprintf(3, "Info: Wait %i\n", num);
				musicsh.cur.wait = num;
				break;
			case '!': // Write to RAM
				num = 0;
				s = readmus_num(s, &num, 2);
				if (s[1] != ':') {
					Pprintf(-1, "Error: Missing ':' in write to RAM\n");
					exit(1);
				}
				s++;
				num2 = 0;
				s = readmus_num(s, &num2, 2);
				if ((num < 0) || (num > 255)) {
					Pprintf(-1, "Error: Write to RAM address out of range\n");
					exit(1);
				}
				if ((num2 < 0) || (num2 > 255)) {
					Pprintf(-1, "Error: Write to RAM address out of range\n");
					exit(1);
				}
				Pprintf(3, "Info: Write RAM[$%02X]=$%02X\n", num & 255, num2 & 255);
				cmd.wait = 0;
				cmd.flags = PMMUSIC_FLAG_WRITERAM;
				cmd.ram_addr = num;
				cmd.ram_data = num2;
				pmmusic_addCMD(pattern, &cmd, -1);
				break;
			case 'l': // Length
				num = musicsh.cur.length;
				s = readmus_num(s, &num, 2);
				if (num < 1) num = 1;
				if (num > 64) num = 64;
				Pprintf(3, "Info: Length %i\n", num);
				musicsh.cur.length = num;
				break;
			case '>': // Increase octave
				if (!musicsh.octrev) {
					musicsh.cur.octave++;
					if (musicsh.cur.octave > 9) musicsh.cur.octave = 9;
				} else {
					musicsh.cur.octave--;
					if (musicsh.cur.octave < 1) musicsh.cur.octave = 1;
				}
				break;
			case '<': // Decrease octave
				if (!musicsh.octrev) {
					musicsh.cur.octave--;
					if (musicsh.cur.octave < 1) musicsh.cur.octave = 1;
				} else {
					musicsh.cur.octave++;
					if (musicsh.cur.octave > 9) musicsh.cur.octave = 9;
				}
				break;
			case 'o': // Octave
				num = musicsh.cur.octave;
				s = readmus_num(s, &num, 1);
				if (num < 1) num = 1;
				if (num > 9) num = 9;
				Pprintf(3, "Info: Octave %i\n", num);
				musicsh.cur.octave = num;
				break;
			case 'q': // Quantize
				if (!musicsh.shortq) {
					num = musicsh.cur.quantize;
					s = readmus_num(s, &num, 2);
					if (num < 0) num = 0;
					if (num > 64) num = 64;
					Pprintf(3, "Info: Quantize %i (%i%%)\n", num, num * 100 / 64);
					musicsh.cur.quantize = num;
				} else {
					num = (musicsh.cur.quantize / 7) - 1;
					s = readmus_num(s, &num, 2);
					if (num < 0) num = 0;
					if (num > 8) num = 8;
					musicsh.cur.quantize = (num + 1) * 7;
					Pprintf(3, "Info: Quantize %i (%i%%)\n", num, musicsh.cur.quantize * 100 / 64);
				}
				break;
			case 's': // Sustain
				num = musicsh.cur.sustain;
				s = readmus_num(s, &num, 2);
				if (num < 0) num = 0;
				if (num > 64) num = 64;
				Pprintf(3, "Info: Sustain %i (%i%%)\n", num, num * 100 / 64);
				musicsh.cur.sustain = num;
				break;
			case 'x': // Effect
				s++;
				switch (*s) {
					case 't': // Ticks
						num = 1;
						s = readmus_num(s, &num, 2);
						if (num < 1) num = 1;
						if (num > 128) num = 128;
						Pprintf(3, "Info: Effect ticks = %i\n", musicsh.cur.efftick);
						musicsh.cur.efftick = num;
						break;
					case 'd': // Disable
						Pprintf(3, "Info: Effect type = Disabled\n");
						musicsh.cur.efftype = EFFECT_DISABLED;
						break;
					case 'a': // Arpeggio
						num = 0;
						s = readmus_num(s, &num, 2);
						musicsh.cur.note2 = num;
						if (s[1] != ':') {
							Pprintf(-1, "Error: Missing ':' in write to RAM\n");
							exit(1);
						}
						s++;
						num2 = 0;
						s = readmus_num(s, &num2, 2);
						musicsh.cur.note3 = num2;
						musicsh.cur.efftype = EFFECT_ARPEGGIO;
						Pprintf(3, "Info: Effect type = Arpeggio (Notes=%i,%i)\n", musicsh.cur.note2, musicsh.cur.note3);
						break;
					case 'p': // Portamento
						num = 0;
						s = readmus_num(s, &num, 2);
						musicsh.cur.note2 = num;
						musicsh.cur.efftype = EFFECT_PORTAMENTO;
						Pprintf(3, "Info: Effect type = Portamento (Note=%i)\n", musicsh.cur.note2);
						break;
					case 'r': // Random between
						num = 0;
						s = readmus_num(s, &num, 2);
						musicsh.cur.note2 = num;
						musicsh.cur.efftype = EFFECT_RANDOM;
						Pprintf(3, "Info: Effect type = Random Between (Note=%i)\n", musicsh.cur.note2);
						break;
					case 's': // Random seed
						num = 1;
						s = readmus_num(s, &num, 8);
						srand (num);
						Pprintf(3, "Info: Effect type = Random Seed (Seed=%i)\n", musicsh.cur.note2);
						break;
					default: // Invalid
						Pprintf(0, "Warning: Unknown character '%c' in effect\n", *s);
						break;
				}
				break;
			case ';': // End music
				Pprintf(3, "Info: End music\n", num & 255, num2 & 255);
				cmd.wait = 0;
				cmd.flags = PMMUSIC_FLAG_VOL | PMMUSIC_FLAG_END;
				cmd.volume = 0;
				pmmusic_addCMD(pattern, &cmd, -1);
				break;
			case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
			case 'G': case 'H': case 'I': case 'J': case 'K': case 'L':
			case 'M': case 'N': case 'O': case 'P': case 'Q': case 'R':
			case 'S': case 'T': case 'U': case 'V': case 'W': case 'X':
			case 'Y': case 'Z': // Macro
				num = *s - 'A';
				if (!macro_pat[num]) {
					Pprintf(-1, "Error: Macro %c not defined\n", *s);
					exit(1);
				}
				for (num2=0; num2<macro_pat[num]->numcmd; num2++) {
					cmdptr = &macro_pat[num]->cmd[num2];
					pmmusic_addCMD(pattern, cmdptr, -1);
				}
				break;
			default:
				Pprintf(0, "Warning: Unknown character '%c'\n", *s);
				break;
		}
		s++;
	}
	return p_brace;
}



// Parse pattern (Track sub-command)
int parse_pattern_trksub(const char *s, pmmusic_pattern *pattern)
{
	pmmusic_cmd cmd;
	int num, num2, noteid;

	if (!strlen(s)) return 0;
	memset((void *)&cmd, 0, sizeof(pmmusic_cmd));

	switch (tolower(*s)) {
		case ' ': case '\t': case '\n': // Ignore
			break;
		case '-': case '_': // No note
			musicsh.cur.note = -1;
			break;
		case 'c': // C note
			noteid = 0;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 1; s++; }
			else if (s[1] == '#') { noteid = 1; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case 'd': // D note
			noteid = 2;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 3; s++; }
			else if (s[1] == '#') { noteid = 3; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case 'e': // E note
			noteid = 4;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 5; s++; }
			else if (s[1] == '#') { noteid = 5; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case 'f': // F note
			noteid = 5;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 6; s++; }
			else if (s[1] == '#') { noteid = 6; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case 'g': // G note
			noteid = 7;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 8; s++; }
			else if (s[1] == '#') { noteid = 8; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case 'a': // A note
			noteid = 9;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 10; s++; }
			else if (s[1] == '#') { noteid = 10; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case 'b': // B note
			noteid = 11;
			if (s[1] == ' ') s++;
			else if (s[1] == '_') s++;
			else if (s[1] == '-') s++;
			else if (s[1] == '+') { noteid = 12; s++; }
			else if (s[1] == '#') { noteid = 12; s++; }
			num = musicsh.cur.octave;
			s = readmus_num(s, &num, 2);
			musicsh.cur.octave = num;
			musicsh.cur.note = noteid;
			break;
		case '%': // Pulse-width
			num = musicsh.cur.pulse;
			s = readmus_num(s, &num, 2);
			if (num < 0) num = 0;
			if (num > 255) num = 255;
			Pprintf(3, "Info: Pulse-width %i (%i%%)\n", num, num * 100 / 255);
			musicsh.cur.pulse = num;
			break;
		case '\\': // Pulse-width in percentage
			num = musicsh.cur.pulse;
			s = readmus_num(s, &num, 2);
			num = num * 255 / 100;
			if (num < 0) num = 0;
			if (num > 255) num = 255;
			Pprintf(3, "Info: Pulse-width %i (%i%%)\n", num, num * 100 / 255);
			musicsh.cur.pulse = num;
			break;
		case 'v': // Volume
			num = musicsh.cur.volume;
			if (musicsh.vollevel) {
				if (musicsh.cur.volume == 1) num = 4;
				else if (musicsh.cur.volume == 2) num = 8;
				else if (musicsh.cur.volume == 3) num = 15;
			}
			s = readmus_num(s, &num, 1);
			if (num < 0) num = 0;
			if (musicsh.vollevel) {
				if (num > 15) num = 15;
				if (num > 8) num2 = 3;
				else if (num > 4) num2 = 2;
				else if (num > 2) num2 = 1;
				else num2 = 0;
				Pprintf(3, "Info: Volume %i (%i)\n", num, num2);
				musicsh.cur.volume = num2;
			} else {
				if (num > 3) num = 3;
				Pprintf(3, "Info: Volume %i\n", num);
				musicsh.cur.volume = num;
			}
			break;
		case 'w': // Wait
			num = musicsh.cur.wait;
			s = readmus_num(s, &num, 2);
			if (num < 0) num = 0;
			if (num > 255) num = 255;
			Pprintf(3, "Info: Wait %i\n", num);
			musicsh.cur.wait = num;
			break;
		case '!': // Write to RAM
			num = 0;
			s = readmus_num(s, &num, 2);
			if (s[1] != ':') {
				Pprintf(-1, "Error: Missing ':' in write to RAM\n");
				exit(1);
			}
			s++;
			num2 = 0;
			s = readmus_num(s, &num2, 2);
			if ((num < 0) || (num > 255)) {
				Pprintf(-1, "Error: Write to RAM address out of range\n");
				exit(1);
			}
			if ((num2 < 0) || (num2 > 255)) {
				Pprintf(-1, "Error: Write to RAM address out of range\n");
				exit(1);
			}
			if (musicsh.cur.ramaddr != -1) {
				Pprintf(-1, "Error: Can only define one RAM write per row\n");
				exit(1);
			}
			Pprintf(3, "Info: Write RAM[$%02X]=$%02X\n", num & 255, num2 & 255);
			musicsh.cur.ramaddr = num;
			musicsh.cur.ramdata = num2;
			break;
		case 'q': // Quantize
			if (!musicsh.shortq) {
				num = musicsh.cur.quantize;
				s = readmus_num(s, &num, 2);
				if (num < 0) num = 0;
				if (num > 64) num = 64;
				Pprintf(3, "Info: Quantize %i (%i%%)\n", num, num * 100 / 64);
				musicsh.cur.quantize = num;
			} else {
				num = (musicsh.cur.quantize / 7) - 1;
				s = readmus_num(s, &num, 2);
				if (num < 0) num = 0;
				if (num > 8) num = 8;
				musicsh.cur.quantize = (num + 1) * 7;
				Pprintf(3, "Info: Quantize %i (%i%%)\n", num, musicsh.cur.quantize * 100 / 64);
			}
			break;
		case 's': // Sustain
			num = musicsh.cur.sustain;
			s = readmus_num(s, &num, 2);
			if (num < 0) num = 0;
			if (num > 64) num = 64;
			Pprintf(3, "Info: Sustain %i (%i%%)\n", num, num * 100 / 64);
			musicsh.cur.sustain = num;
			break;
		case 'x': // Effect
			s++;
			switch (*s) {
				case 't': // Ticks
					num = 1;
					s = readmus_num(s, &num, 2);
					if (num < 1) num = 1;
					if (num > 128) num = 128;
					Pprintf(3, "Info: Effect ticks = %i\n", musicsh.cur.efftick);
					musicsh.cur.efftick = num;
					break;
				case 'd': // Disable
					Pprintf(3, "Info: Effect type = Disabled\n");
					musicsh.cur.efftype = EFFECT_DISABLED;
					break;
				case 'a': // Arpeggio
					num = 0;
					s = readmus_num(s, &num, 2);
					musicsh.cur.note2 = num;
					if (s[1] != ':') {
						Pprintf(-1, "Error: Missing ':' in write to RAM\n");
						exit(1);
					}
					s++;
					num2 = 0;
					s = readmus_num(s, &num2, 2);
					musicsh.cur.note3 = num2;
					musicsh.cur.efftype = EFFECT_ARPEGGIO;
					Pprintf(3, "Info: Effect type = Arpeggio (Notes=%i,%i)\n", musicsh.cur.note2, musicsh.cur.note3);
					break;
				case 'p': // Portamento
					num = 0;
					s = readmus_num(s, &num, 2);
					musicsh.cur.note2 = num;
					musicsh.cur.efftype = EFFECT_PORTAMENTO;
					Pprintf(3, "Info: Effect type = Portamento (Note=%i)\n", musicsh.cur.note2);
					break;
				case 'r': // Random between
					num = 0;
					s = readmus_num(s, &num, 2);
					musicsh.cur.note2 = num;
					musicsh.cur.efftype = EFFECT_RANDOM;
					Pprintf(3, "Info: Effect type = Random Between (Note=%i)\n", musicsh.cur.note2);
					break;
				case 's': // Random seed
					num = 1;
					s = readmus_num(s, &num, 8);
					srand (num);
					Pprintf(3, "Info: Effect type = Random Seed (Seed=%i)\n", musicsh.cur.note2);
					break;
				default: // Invalid
					Pprintf(0, "Warning: Unknown character '%c' in effect\n", *s);
					break;
			}
			break;
		case ';': // End music
			Pprintf(3, "Info: End music\n", num & 255, num2 & 255);
			cmd.wait = 0;
			cmd.flags = PMMUSIC_FLAG_VOL | PMMUSIC_FLAG_END;
			cmd.volume = 0;
			pmmusic_addCMD(pattern, &cmd, -1);
			break;
		default:
			Pprintf(0, "Warning: Unknown command '%s'\n", s);
			break;
	}
	return p_brace;
}

// Parse pattern (Track)
int parse_pattern_trk(const char *s, int sfx, pmmusic_pattern *pattern)
{
	char tmp[1024], *txt, *stxt;
	char *directive, *parameter;
	int directivenum, parnum, num, num2;
	pmmusic_cmd cmd, *cmdptr;

	strcpy(tmp, s);
	memset((void *)&cmd, 0, sizeof(pmmusic_cmd));

	// Handle braces
	txt = tmp;
	while (*txt != 0) {
		if (*txt == '{') {
			if (p_brace) {
				Pprintf(-1, "Error: Open brace already declared\n");
				exit(1);
			}
			p_brace++;
			*txt = ' ';
		} else if (*txt == '}') {
			if (!p_brace) {
				Pprintf(-1, "Error: Closing brace without open\n");
				exit(1);
			}
			p_brace--;
			*txt = ' ';
			break;
		}
		txt++;
	}
	*txt++ = ';'; *txt = 0;

	txt = TrimStr(tmp);
	if ((txt[0] == 0) || (txt[0] == ';')) return p_brace;
	if (!SeparateAtChars(txt, " \t", &directive, &parameter)) {
		Pprintf(-1, "Error: Malformed track directive\n");
		exit(1);
	}
	if (!strcasecmp(directive, "ROW")) {
		directivenum = 0;
	} else if (!strcasecmp(directive, "LOOP") || !strcasecmp(directive, "MARK") || !strcasecmp(directive, "DO")) {
		Pprintf(3, "Info: Starting loop %i\n", p_dloop);
		cmd.wait = 0;
		cmd.flags = PMMUSIC_FLAG_MARK;
		cmd.loop_id = p_dloop;
		pmmusic_addCMD(pattern, &cmd, -1);
		p_dloop++;
		if (p_dloop == 3) {
			Pprintf(-1, "Error: Number of loops exceeded\n");
			exit(1);
		}
		return p_brace;
	} else if (!strcasecmp(directive, "ENDL") || !strcasecmp(directive, "ENDLOOP") || !strcasecmp(directive, "REPEAT")) {
		directivenum = 1;
	} else if (!strcasecmp(directive, "MACRO")) {
		directivenum = 2;
	} else {
		Pprintf(-1, "Error: Invalid track directive '%s'\n", directive);
		exit(1);
	}

	// Set no note
	musicsh.cur.note = -1;
	musicsh.cur.ramaddr = -1;
	musicsh.cur.ramdata = -1;

	// Row directive
	parnum = 0;
	stxt = txt = TrimStr(parameter);
	while (*txt != 0) {
		if ((*txt == ',') || (*txt == ';')) {
			*txt = 0;
			if (strlen(stxt)) {
				if (directivenum == 0) {
					// ROW
					parse_pattern_trksub(TrimStr(stxt), pattern);
				} else if (directivenum == 1) {
					// ENDL
					if (parnum == 0) {
						num = atoi_Ex(stxt, 2);
						if (p_dloop) {
							p_dloop--;
							if (num <= 0) {
								Pprintf(-1, "Error: Number of loops need to be >= 1\n");
								exit(1);
							}
							Pprintf(3, "Info: Ending loop %i (num=%i)\n", p_dloop, num);
							cmd.wait = 0;
							cmd.flags = PMMUSIC_FLAG_LOOP;
							cmd.loop_id = p_dloop;
							cmd.loop_num = num - 1;
							pmmusic_addCMD(pattern, &cmd, -1);
						} else {
							Pprintf(-1, "Error: Closing bracket without open\n");
							exit(1);
						}
					}
				} else if (directivenum == 2) {
					// MACRO
					if (parnum == 0) {
						stxt = TrimStr(stxt);
						num = *stxt - 'A';
						if ((num < 0) || (num > 25)) break;
						if (!macro_pat[num]) {
							Pprintf(-1, "Error: Macro %c not defined\n", *stxt);
							exit(1);
						}
						for (num2=0; num2<macro_pat[num]->numcmd; num2++) {
							cmdptr = &macro_pat[num]->cmd[num2];
							pmmusic_addCMD(pattern, cmdptr, -1);
						}
					}
				}
				parnum++;
			}
			stxt = txt = TrimStr(&txt[1]);
			continue;
		}
		txt++;
	}

	// Apply ROW
	if (directivenum == 0) {
		if (musicsh.cur.note == -1) {
			parse_pattern_note(pattern, -1, (double)musicsh.cur.wait, -1);
		} else {
			parse_pattern_note(pattern, musicsh.cur.note, (double)musicsh.cur.wait, 0);
		}
	}

	return p_brace;
}

// Parse BGM
int parse_bgm(const char *cmd, pmmusic_bgm *bgm)
{
	char tmp[1024], *txt, *stxt;
	pmmusic_pattern *pat;
	strcpy(tmp, cmd);

	// Handle braces
	txt = tmp;
	while (*txt != 0) {
		if (*txt == '{') {
			if (p_brace) {
				Pprintf(-1, "Error: Open brace already declared\n");
				exit(1);
			}
			p_brace++;
			*txt = ' ';
		} else if (*txt == '}') {
			if (!p_brace) {
				Pprintf(-1, "Error: Closing brace without open\n");
				exit(1);
			}
			p_brace--;
			*txt = ' ';
			break;
		}
		txt++;
	}
	*txt++ = ';'; *txt = 0;

	// if bgm is NULL then we are at 1st pass
	if (!bgm) return p_brace;

	stxt = txt = TrimStr(tmp);
	while (*txt != 0) {
		if ((*txt == ' ') || (*txt == '\t') || (*txt == ';')) {
			*txt = 0;
			if (strlen(stxt)) {
				if (!strcmp(stxt, "|")) {
					if (p_bpatloop != -1) {
						Pprintf(-1, "Error: Loop mark already defined\n");
						exit(1);
					}
					p_bpatloop = p_bpat;
					Pprintf(3, "Loop mark\n", txt);
				} else {
					Pprintf(3, "Pattern %s\n", stxt);
					pat = pmmusic_getPAT(musiclist, stxt, NULL);
					if (!pat) {
						Pprintf(-1, "Error: Pattern '%s' doesn't exist\n", stxt);
						exit(1);
					}
					pmmusic_addSEQ(bgm, pat, -1);
				}
				p_bpat++;
			}
			stxt = txt = TrimStr(&txt[1]);
			continue;
		}
		txt++;
	}
	return p_brace;
}

// Convert music file
int convertmus_file(const char *musfile)
{
	char tmp[1024], *txt;
	char *directive, *parameter, *varname;
	int i, value;
	double fvalue;
	FILE *fi;
	char tp_file[128];
	pmmusic_pattern *pat;
	pmmusic_bgm *bgm;
	pmmusic_cmd endcmd, nextpatcmd;

	// End command
	endcmd.wait = 1;
	endcmd.flags = PMMUSIC_FLAG_VOL | PMMUSIC_FLAG_END;
	endcmd.volume = 0;

	// Next pattern command
	nextpatcmd.wait = 0;
	nextpatcmd.flags = PMMUSIC_FLAG_PATTERN;
	nextpatcmd.pattern = 1;

	if (p_recursive++ >= 2) {
		Pprintf(-1, "Error: Recursive include overflow\n");
		exit(1);
	}

	fi = fopen(musfile, "r");
	if (!fi) {
		Pprintf(-1, "Error: Couldn't open file\n");
		exit(1);
	}
	strcpy(p_file, musfile);

	// 1st Pass
	p_line = 0;
	p_comment = 0;
	fseek(fi, 0, SEEK_SET);
	while ((txt = readmus_line(fi, tmp, 1024)) != NULL) {
		// Separate directive from parameter
		RemoveComments(txt);
		if (!SeparateAtChars(txt, " \t", &directive, &parameter)) continue;
		directive = TrimStr(directive);
		parameter = TrimStr(parameter);

		// Process directive
		if (!strcasecmp(directive, "TITLE")) {
			strncpy(musicsh.title, parameter, 255);
		} else if (!strcasecmp(directive, "COMPOSER")) {
			strncpy(musicsh.composer, parameter, 255);
		} else if (!strcasecmp(directive, "PROGRAMMER")) {
			strncpy(musicsh.programmer, parameter, 255);
		} else if (!strcasecmp(directive, "DESCRIPTION")) {
			strncpy(musicsh.description, parameter, 255);
		} else if (!strcasecmp(directive, "OUTFORMAT")) {
			if (!strcasecmp(parameter, "ASM")) confs.format = FILE_ECODE_ASM;
			else if (!strcasecmp(parameter, "C")) confs.format = FILE_ECODE_C;
			else {
				Pprintf(-1, "Error: Invalid output format '%s'\n", parameter);
				exit(1);
			}
		} else if (!strcasecmp(directive, "OUTFILE")) {
			parameter = TrimStr(parameter);
			strcpy(confs.out_f, parameter);
		} else if (!strcasecmp(directive, "VARHEADER")) {
			parameter = TrimStr(parameter);
			strcpy(confs.mus_v, parameter);
		} else if (!strcasecmp(directive, "OUTHEADER")) {
			parameter = TrimStr(parameter);
			strcpy(confs.outh_f, parameter);
		} else if (!strcasecmp(directive, "OUTLIST")) {
			parameter = TrimStr(parameter);
			strcpy(confs.outl_f, parameter);
		} else if (!strcasecmp(directive, "VARSFX")) {
			parameter = TrimStr(parameter);
			strcpy(confs.sfx_v, parameter);
		} else if (!strcasecmp(directive, "VARBGM")) {
			parameter = TrimStr(parameter);
			strcpy(confs.bgm_v, parameter);
		} else if (!strcasecmp(directive, "INCLUDE")) {
			// Include file
			strcpy(tp_file, p_file);
			if (!convertmus_file(parameter)) {
				Pprintf(-1, "Error: Invalid file '%s'\n", parameter);
				exit(1);
			}
		} else if (!strcasecmp(directive, "MTIME") || !strcasecmp(directive, "MASTERTIME")) {
			// Change master time
			value = atoi_Ex(parameter, -1);
			if ((value <= 0) || (value > 65535)) {
				Pprintf(-1, "Error: Invalid master time value\n", parameter);
				exit(1);
			}
			if (musicsh.mastertime_set && (value != musicsh.mastertime_val)) {
				Pprintf(0, "Warning: Master time has been set with different value\n");
			}
			musicsh.mastertime_val = value;
			musicsh.mastertime_set = 1;
			Pprintf(2, "Info: Master time set to $%04X (%i)\n", value, value);
		} else if (!strcasecmp(directive, "MBPM") || !strcasecmp(directive, "MASTERBPM")) {
			// Change master time based of BPM
			fvalue = atof_Ex(parameter, -1.0f);
			if (fvalue <= 0.0f) {
				Pprintf(-1, "Error: Invalid BPM value\n");
				exit(1);
			}
			if (!SeparateAtChars(parameter, ",", NULL, &parameter)) {
				Pprintf(-1, "Error: Missing wait value\n", parameter);
				exit(1);
			}
			value = atoi_Ex(parameter, -1);
			if ((value < 0) || (value > 255)) {
				Pprintf(-1, "Error: Invalid wait value\n");
				exit(1);
			}
			value = (int)(3905.25f / (fvalue / 960.0f * (float)value)) - 1;
			if (value > 65535) {
				Pprintf(-1, "Error: Master time value too high\n");
				exit(1);
			}
			if (musicsh.mastertime_set && (value != musicsh.mastertime_val)) {
				Pprintf(0, "Warning: Master time has been set with different value\n");
			}
			musicsh.mastertime_val = value;
			musicsh.mastertime_set = 1;
			Pprintf(2, "Info: Master time set to $%04X (%i)\n", value, value);
		} else if (!strcasecmp(directive, "VOLLVL") || !strcasecmp(directive, "VOLLEVEL")) {
			// Setup volume level
			if (!strcasecmp(parameter, "system")) {
				musicsh.vollevel = 0;
			} else if (!strcasecmp(parameter, "4")) {
				musicsh.vollevel = 0;
			} else if (!strcasecmp(parameter, "mml")) {
				musicsh.vollevel = 1;
			} else if (!strcasecmp(parameter, "16")) {
				musicsh.vollevel = 1;
			} else {
				Pprintf(-1, "Error: Invalid VOLLVL value\n");
				exit(1);
			}
		} else if (!strcasecmp(directive, "OCTREV") || !strcasecmp(directive, "OCTAVEREV")) {
			// Setup octave reverse
			if (!strcasecmp(parameter, "no")) {
				musicsh.octrev = 0;
			} else if (!strcasecmp(parameter, "yes")) {
				musicsh.octrev = 1;
			} else if (!strcasecmp(parameter, "false")) {
				musicsh.octrev = 0;
			} else if (!strcasecmp(parameter, "true")) {
				musicsh.octrev = 1;
			} else if (!strcasecmp(parameter, "0")) {
				musicsh.octrev = 0;
			} else if (!strcasecmp(parameter, "1")) {
				musicsh.octrev = 1;
			} else {
				Pprintf(-1, "Error: Invalid OCTREV value\n");
				exit(1);
			}
		} else if (!strcasecmp(directive, "SHORTQ") || !strcasecmp(directive, "SHORTQUANTIZE")) {
			// Setup octave reverse
			if (!strcasecmp(parameter, "no")) {
				musicsh.shortq = 0;
			} else if (!strcasecmp(parameter, "yes")) {
				musicsh.shortq = 1;
			} else if (!strcasecmp(parameter, "false")) {
				musicsh.shortq = 0;
			} else if (!strcasecmp(parameter, "true")) {
				musicsh.shortq = 1;
			} else if (!strcasecmp(parameter, "0")) {
				musicsh.shortq = 0;
			} else if (!strcasecmp(parameter, "1")) {
				musicsh.shortq = 1;
			} else {
				Pprintf(-1, "Error: Invalid SHORTQ value\n");
				exit(1);
			}
		} else if (!strcasecmp(directive, "MACRO")) {
			// Add or change macro
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (strlen(varname) != 1) {
				Pprintf(-1, "Error: Macro must be 1 character\n");
				exit(1);
			}
			if ((varname[0] < 'A') && (varname[0] > 'Z')) {
				Pprintf(-1, "Error: Macro must be a uppercase character\n");
				exit(1);
			}
			pat = pmmusic_newpattern(varname, 1);
			Pprintf(2, "Info: Macro '%s' defined/changed\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_pattern(txt, 0, pat)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			value = pat->varname[0] - 'A';
			if (!macro_pat[value]) macro_pat[value] = pmmusic_newpattern("Macro", 1);
			macro_pat[value]->numcmd = 0;
			for (i=0; i<pat->numcmd; i++) pmmusic_addCMD(macro_pat[value], &pat->cmd[i], -1);
			pmmusic_deletepattern(pat);
			Pprintf(3, "Info: Macro '%s' end\n", pat->varname);
		} else if (!strcasecmp(directive, "MACRO_T") || !strcasecmp(directive, "MACRO_TRACK")) {
			// Add or change macro
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (strlen(varname) != 1) {
				Pprintf(-1, "Error: Macro must be 1 character\n");
				exit(1);
			}
			if ((varname[0] < 'A') && (varname[0] > 'Z')) {
				Pprintf(-1, "Error: Macro must be a uppercase character\n");
				exit(1);
			}
			pat = pmmusic_newpattern(varname, 1);
			Pprintf(2, "Info: Macro '%s' defined/changed\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_pattern_trk(txt, 0, pat)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			value = pat->varname[0] - 'A';
			if (!macro_pat[value]) macro_pat[value] = pmmusic_newpattern("Macro", 1);
			macro_pat[value]->numcmd = 0;
			for (i=0; i<pat->numcmd; i++) pmmusic_addCMD(macro_pat[value], &pat->cmd[i], -1);
			pmmusic_deletepattern(pat);
			Pprintf(3, "Info: Macro '%s' end\n", pat->varname);
		} else if (!strcasecmp(directive, "PAT") || !strcasecmp(directive, "PATTERN")) {
			// Define pattern
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (!strlen(varname)) {
				Pprintf(-1, "Error: Pattern varname cannot be empty\n");
				exit(1);
			}
			if (pmmusic_existVAR(musiclist, varname, NULL, NULL)) {
				Pprintf(-1, "Error: Variable '%s' already defined\n", varname);
				exit(1);
			}
			pat = pmmusic_newPAT(musiclist, varname, 1);
			Pprintf(2, "Info: Pattern '%s' defined\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_pattern(txt, 0, pat)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			pmmusic_addCMD(pat, &nextpatcmd, -1);
			Pprintf(3, "Info: Pattern '%s' end\n", pat->varname);
		} else if (!strcasecmp(directive, "PAT_T") || !strcasecmp(directive, "PATTERN_T") ||
			   !strcasecmp(directive, "PAT_TRACK") || !strcasecmp(directive, "PATTERN_TRACK")) {
			// Define pattern
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (!strlen(varname)) {
				Pprintf(-1, "Error: Pattern varname cannot be empty\n");
				exit(1);
			}
			if (pmmusic_existVAR(musiclist, varname, NULL, NULL)) {
				Pprintf(-1, "Error: Variable '%s' already defined\n", varname);
				exit(1);
			}
			pat = pmmusic_newPAT(musiclist, varname, 1);
			Pprintf(2, "Info: Pattern '%s' defined\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_pattern_trk(txt, 0, pat)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			pmmusic_addCMD(pat, &nextpatcmd, -1);
			Pprintf(3, "Info: Pattern '%s' end\n", pat->varname);
		} else if (!strcasecmp(directive, "SFX")) {
			// Define SFX
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (!strlen(varname)) {
				Pprintf(-1, "Error: SFX varname cannot be empty\n");
				exit(1);
			}
			if (pmmusic_existVAR(musiclist, varname, NULL, NULL)) {
				Pprintf(-1, "Error: Variable '%s' already defined\n", varname);
				exit(1);
			}
			pat = pmmusic_newSFX(musiclist, varname, 1);
			Pprintf(2, "Info: SFX '%s' defined\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_pattern(txt, 1, pat)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			pmmusic_addCMD(pat, &endcmd, -1);
			Pprintf(3, "Info: SFX '%s' end\n", pat->varname);
		} else if (!strcasecmp(directive, "SFX_T") || !strcasecmp(directive, "SFX_TRACK")) {
			// Define SFX
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (!strlen(varname)) {
				Pprintf(-1, "Error: SFX varname cannot be empty\n");
				exit(1);
			}
			if (pmmusic_existVAR(musiclist, varname, NULL, NULL)) {
				Pprintf(-1, "Error: Variable '%s' already defined\n", varname);
				exit(1);
			}
			pat = pmmusic_newSFX(musiclist, varname, 1);
			Pprintf(2, "Info: SFX '%s' defined\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_pattern_trk(txt, 1, pat)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			pmmusic_addCMD(pat, &endcmd, -1);
			Pprintf(3, "Info: SFX '%s' end\n", pat->varname);
		} else if (!strcasecmp(directive, "BGM")) {
			// Define BGM
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (!strlen(varname)) {
				Pprintf(-1, "Error: BGM varname cannot be empty\n");
				exit(1);
			}
			if (pmmusic_existVAR(musiclist, varname, NULL, NULL)) {
				Pprintf(-1, "Error: Variable '%s' already defined\n", varname);
				exit(1);
			}
			txt = parameter;
			do {
				if (!parse_bgm(txt, NULL)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
		} else {
			// Empty of unknown directive
			if (strlen(directive)) {
				Pprintf(-1, "Error: Unknown directive '%s'\n", directive);
				exit(1);
			}
		}

		// Cannot have open brace
		if (p_brace) {
			Pprintf(-1, "Error: Opening brace without close\n");
			exit(1);
		}
	}

	// 2nd Pass
	p_line = 0;
	p_comment = 0;
	fseek(fi, 0, SEEK_SET);
	while ((txt = readmus_line(fi, tmp, 1024)) != NULL) {
		// Separate directive from parameter
		if (!SeparateAtChars(txt, " \t", &directive, &parameter)) continue;

		// Process directive
		if (!strcasecmp(directive, "BGM")) {
			// Define BGM
			p_bpat = 0;
			p_bpatloop = -1;
			if (!SeparateAtChars(parameter, " \t", &varname, &parameter)) {
				Pprintf(-1, "Error: Malformed directive\n");
				exit(1);
			}
			if (pmmusic_existVAR(musiclist, varname, NULL, NULL)) {
				Pprintf(-1, "Error: Variable '%s' already defined\n", varname);
				exit(1);
			}
			bgm = pmmusic_newBGM(musiclist, varname, 1);
			Pprintf(2, "Info: BGM '%s' defined\n", varname);
			txt = parameter;
			memcpy(&musicsh.cur, &musicsh.def, sizeof(musicsh.def));
			do {
				if (!parse_bgm(txt, bgm)) break;
			} while ((txt = readmus_line(fi, tmp, 1024)) != NULL);
			Pprintf(3, "Info: BGM '%s' end\n", bgm->varname);
			// Create loop / end pattern
			sprintf(txt, "%s_ENDBGM", bgm->varname);
			pat = pmmusic_newPAT(musiclist, txt, 0);
			if (p_bpatloop == -1) {
				// End pattern
				pmmusic_addCMD(pat, &endcmd, -1);
			} else {
				// Loop pattern
				nextpatcmd.pattern = -(p_bpat - p_bpatloop - 1);
				pmmusic_addCMD(pat, &nextpatcmd, -1);
				nextpatcmd.pattern = 1;
			}
			pmmusic_addSEQ(bgm, pat, -1);
		}

		// Cannot have open brace
		if (p_brace) {
			Pprintf(-1, "Error: Opening brace without close\n");
			exit(1);
		}
	}
	fclose(fi);

	p_recursive--;

	return 1;
}

// ---------- Main ----------

void audio_fill(int16_t *stream, int len)
{
	MinxAudio_GetSamplesS16(stream, len>>1);
	if (sdump) WriteS16A_ExportWAV(sdump, (int16_t *)stream, len>>1);
}

void sdump_close(void)
{
	if (sdump) Close_ExportWAV(sdump);
	sdump = NULL;
}

int main(int argc, char **argv)
{
	pmmusic_bgm *tbgm;
	pmmusic_sfx *tsfx;
	int i, j, playdec, totalsiz;
	char tmp[256];
	FILE_ECODE *foptr;
	FILE *fo;

	// Read from command line
	init_confs();
	if (!load_confs_args(argc, argv)) {
		printf("PokeMini Music Converter " VERSION_STR "\n\n");
		printf("Usage: pokemini_musicconv [options]\n\n");
		printf("  -asmf               Output in asm format (def)\n");
		printf("  -cf                 Output in C format\n");
		printf("  -i music.txt        Music input (required)\n");
		printf("  -o music.asm        Output file\n");
		printf("  -oh music.inc       Output file (header)\n");
		printf("  -ol music_list.asm  Output file (sound list)\n");
		printf("  -q                  Quiet\n");
		printf("  -v                  Verbose\n");
		printf("  -sv                 Super-verbose\n");
		printf("  -play varname       Play specific BGM/SFX\n");
		printf("\nPlay flags:\n");
		printf("  -snddirect          Sound Engine: Direct (def)\n");
		printf("  -sndemulated        Sound Engine: Emulated\n");
		printf("  -piezo              Use piezo filtering (def)\n");
		printf("  -nopiezo            Don't use piezo filtering\n");
		printf("  -towav music.wav    Save to WAV while playing\n");
		return 1;
	}
	if (!confs.quiet) printf("PokeMini Music Converter " VERSION_STR "\n\n");

	// Initialize
	musiclist = pmmusic_newlist();
	if (!musiclist) {
		printf("Error: Not enough memory!\n");
		return 1;
	}
	musicsh.mastertime_val = 260;	// Default master time, aprox 60fps
	musicsh.vollevel = 1;		// Volume level of MML
	musicsh.def.wait = 24;		// Wait
	musicsh.def.note = -1;		// Note
	musicsh.def.note2 = -1;		// Note 2 for effects
	musicsh.def.note3 = -1;		// Note 3 for effects
	musicsh.def.ramaddr = -1;	// RAM address
	musicsh.def.ramdata = -1;	// RAM data
	musicsh.def.length = 4;		// Length
	musicsh.def.octave = 4;		// Octave
	musicsh.def.volume = 3;		// Volume
	musicsh.def.pulse = 128;	// Pulse-Width
	musicsh.def.quantize = 64;	// Quantize
	musicsh.def.sustain = 64;	// Sustain
	musicsh.def.arpptr = 0;		// Arpeggio pointer
	musicsh.def.efftype = 0;	// Effect type
	musicsh.def.efftick = 1;	// Effect tick

	// Convert file
	strcpy(p_file, "");
	p_line = 1;
	convertmus_file(confs.mus_f);

	// Generate var name out of source filename
	if (!strlen(confs.mus_v)) {
		strcpy(confs.mus_v, GetFilename(confs.mus_f));
		RemoveExtension(confs.mus_v);
		FixSymbolID(confs.mus_v);
	}
	if (!strlen(confs.sfx_v)) {
		strcpy(confs.sfx_v, GetFilename(confs.mus_f));
		RemoveExtension(confs.sfx_v);
		strcat(confs.sfx_v, STR_APPEND_SFX);
		FixSymbolID(confs.sfx_v);
	}
	if (!strlen(confs.bgm_v)) {
		strcpy(confs.bgm_v, GetFilename(confs.mus_f));
		RemoveExtension(confs.bgm_v);
		strcat(confs.bgm_v, STR_APPEND_BGM);
		FixSymbolID(confs.bgm_v);
	}

	// Assemble raw commands
	totalsiz = 0;
	for (i=0; i<musiclist->numpattern; i++) {
		pmmusic_asmPAT(musiclist->pattern[i]);
		totalsiz += musiclist->pattern[i]->numraw * 2;
	}
	for (i=0; i<musiclist->numsfx; i++) {
		pmmusic_asmPAT(musiclist->sfx[i]);
		totalsiz += musiclist->sfx[i]->numraw * 2;
	}

	// Display resources
	if (!confs.quiet) {
		printf("Mastertime: $%04X, (%i)\n", musicsh.mastertime_val, musicsh.mastertime_val);
		printf("Resources, %i Bytes:\n", totalsiz);
		printf("%3i Pattern(s)\n", musiclist->numpattern);
		if (confs.verbose) {
			for (i=0; i<musiclist->numpattern; i++) {
				printf("\t'%s' - %i Bytes\n", musiclist->pattern[i]->varname, musiclist->pattern[i]->numraw * 2);
			}
		}
		printf("%3i SFX\n", musiclist->numsfx);
		if (confs.verbose) {
			for (i=0; i<musiclist->numsfx; i++) {
				printf("\t'%s' - %i Bytes\n", musiclist->sfx[i]->varname, musiclist->sfx[i]->numraw * 2);
			}
		}
		printf("%3i BGM\n", musiclist->numbgm);
		if (confs.verbose) {
			for (i=0; i<musiclist->numbgm; i++) {
				printf("\t'%s' - %i Bytes\n", musiclist->bgm[i]->varname, musiclist->bgm[i]->numpattern * 4);
			}
		}
	}

	// Output file
	if (strlen(confs.out_f)) {
		foptr = Open_ExportCode(confs.format, confs.out_f);
		if (foptr) {
			Comment_ExportCode(foptr, "%s", EXPORT_STR);
			Comment_ExportCode(foptr, "Data file");
			Comment_ExportCode(foptr, "");
			if (strlen(musicsh.title)) Comment_ExportCode(foptr, "Title: %s", musicsh.title);
			if (strlen(musicsh.composer)) Comment_ExportCode(foptr, "Composer: %s", musicsh.composer);
			if (strlen(musicsh.programmer)) Comment_ExportCode(foptr, "Programmer: %s", musicsh.programmer);
			if (strlen(musicsh.description)) Comment_ExportCode(foptr, "Description: %s", musicsh.description);
			Comment_ExportCode(foptr, "Mastertime: $%04X, (%i)", musicsh.mastertime_val, musicsh.mastertime_val);
			PrintASM_ExportCode(foptr, "\n\t.align 2\n");
			// Export patterns
			Comment_ExportCode(foptr, "");
			Comment_ExportCode(foptr, "%3i Pattern(s)", musiclist->numpattern);
			Comment_ExportCode(foptr, "");
			for (i=0; i<musiclist->numpattern; i++) {
				WriteArray_ExportCode(foptr, FILE_ECODE_16BITS, musiclist->pattern[i]->varname, (void *)musiclist->pattern[i]->raw, musiclist->pattern[i]->numraw * 2);
			}
			// Export SFXs
			Comment_ExportCode(foptr, "");
			Comment_ExportCode(foptr, "%3i SFX", musiclist->numsfx);
			Comment_ExportCode(foptr, "");
			for (i=0; i<musiclist->numsfx; i++) {
				WriteArray_ExportCode(foptr, FILE_ECODE_16BITS, musiclist->sfx[i]->varname, (void *)musiclist->sfx[i]->raw, musiclist->sfx[i]->numraw * 2);
			}
			// Export BGMs
			Comment_ExportCode(foptr, "");
			Comment_ExportCode(foptr, "%3i BGM", musiclist->numbgm);
			Comment_ExportCode(foptr, "");
			for (i=0; i<musiclist->numbgm; i++) {
				BlockOpen_ExportCode(foptr, FILE_ECODE_32BITS, musiclist->bgm[i]->varname);
				for (j=0; j<musiclist->bgm[i]->numpattern; j++) BlockVarWrite_ExportCode(foptr, musiclist->bgm[i]->pattern[j]->varname);
				BlockClose_ExportCode(foptr);
			}

			if (!confs.quiet) printf("Exported data '%s'\n", confs.out_f);
		} else printf("Error: Couldn't write output to '%s'\n", confs.out_f);
		Close_ExportCode(foptr);
	}

	// Output header file
	if (strlen(confs.outh_f)) {
		fo = fopen(confs.outh_f, "w");
		if (fo) {
			if (confs.format == FILE_ECODE_ASM) {
				fprintf(fo, "; %s\n; Header file\n\n", EXPORT_STR);
				if (strlen(musicsh.title)) fprintf(fo, "; Title: %s\n", musicsh.title);
				if (strlen(musicsh.composer)) fprintf(fo, "; Composer: %s\n", musicsh.composer);
				if (strlen(musicsh.programmer)) fprintf(fo, "; Programmer: %s\n", musicsh.programmer);
				if (strlen(musicsh.description)) fprintf(fo, "; Description: %s\n", musicsh.description);
				if (strlen(musicsh.title)) fprintf(fo, ".set " STR_TITLE " \"%s\"\n", confs.mus_v, musicsh.title);
				if (strlen(musicsh.composer)) fprintf(fo, ".set " STR_COMPOSER " \"%s\"\n", confs.mus_v, musicsh.composer);
				if (strlen(musicsh.programmer)) fprintf(fo, ".set " STR_PROGRAMMER " \"%s\"\n", confs.mus_v, musicsh.programmer);
				if (strlen(musicsh.description)) fprintf(fo, ".set " STR_DESCRIPTION " \"%s\"\n", confs.mus_v, musicsh.description);
				fprintf(fo, "\n; Mastertime: $%04X, (%i)\n", musicsh.mastertime_val, musicsh.mastertime_val);
				fprintf(fo, ".set " STR_MTIME " %i\n", confs.mus_v, musicsh.mastertime_val);
				fprintf(fo, "\n; %3i Pattern(s)\n", musiclist->numpattern);
				fprintf(fo, ".set " STR_NUMPAT " %i\n", confs.mus_v, musiclist->numpattern);
				for (i=0; i<musiclist->numpattern; i++) {
					fprintf(fo, "; '%s'\n", musiclist->pattern[i]->varname);
				}
				fprintf(fo, "\n; %3i SFX\n", musiclist->numsfx);
				fprintf(fo, ".set " STR_NUMSFX " %i\n", confs.mus_v, musiclist->numsfx);
				for (i=0; i<musiclist->numsfx; i++) {
					fprintf(fo, "; '%s'\n", musiclist->sfx[i]->varname);
					for (j=strlen(musiclist->sfx[i]->varname); j>=0; j--) tmp[j] = toupper(musiclist->sfx[i]->varname[j]);
					fprintf(fo, "\t.set %s %i\n", tmp, i);
				}
				fprintf(fo, "\n; %3i BGM\n", musiclist->numbgm);
				fprintf(fo, ".set " STR_NUMBGM " %i\n", confs.mus_v, musiclist->numbgm);
				for (i=0; i<musiclist->numbgm; i++) {
					fprintf(fo, "; '%s'\n", musiclist->bgm[i]->varname);
					for (j=strlen(musiclist->bgm[i]->varname); j>=0; j--) tmp[j] = toupper(musiclist->bgm[i]->varname[j]);
					fprintf(fo, "\t.set %s %i\n", tmp, i);
				}
				fprintf(fo, "\n");
			} else if (confs.format == FILE_ECODE_C) {
				fprintf(fo, "// %s\n// Header file\n\n", EXPORT_STR);
				if (strlen(musicsh.title)) fprintf(fo, "// Title: %s\n", musicsh.title);
				if (strlen(musicsh.composer)) fprintf(fo, "// Composer: %s\n", musicsh.composer);
				if (strlen(musicsh.programmer)) fprintf(fo, "// Programmer: %s\n", musicsh.programmer);
				if (strlen(musicsh.description)) fprintf(fo, "// Description: %s\n", musicsh.description);
				if (strlen(musicsh.title)) fprintf(fo, "#define " STR_TITLE " \"%s\"\n", confs.mus_v, musicsh.title);
				if (strlen(musicsh.composer)) fprintf(fo, "#define " STR_COMPOSER " \"%s\"\n", confs.mus_v, musicsh.composer);
				if (strlen(musicsh.programmer)) fprintf(fo, "#define " STR_PROGRAMMER " \"%s\"\n", confs.mus_v, musicsh.programmer);
				if (strlen(musicsh.description)) fprintf(fo, "#define " STR_DESCRIPTION " \"%s\"\n", confs.mus_v, musicsh.description);
				fprintf(fo, "\n// Mastertime: $%04X, (%i)\n", musicsh.mastertime_val, musicsh.mastertime_val);
				fprintf(fo, "#define " STR_MTIME " (%i)\n", confs.mus_v, musicsh.mastertime_val);
				fprintf(fo, "\n// %3i Pattern(s)\n", musiclist->numpattern);
				fprintf(fo, "#define " STR_NUMPAT " %i\n", confs.mus_v, musiclist->numpattern);
				for (i=0; i<musiclist->numpattern; i++) {
					fprintf(fo, "extern unsigned short %s[];\n", musiclist->pattern[i]->varname);
				}
				fprintf(fo, "\n// %3i SFX\n", musiclist->numsfx);
				fprintf(fo, "#define " STR_NUMSFX " %i\n", confs.mus_v, musiclist->numsfx);
				for (i=0; i<musiclist->numsfx; i++) {
					for (j=strlen(musiclist->sfx[i]->varname); j>=0; j--) tmp[j] = toupper(musiclist->sfx[i]->varname[j]);
					fprintf(fo, "#define %s %i\n", tmp, i);
					fprintf(fo, "extern unsigned short %s[];\n", musiclist->sfx[i]->varname);
				}
				fprintf(fo, "\n// %3i BGM\n", musiclist->numbgm);
				fprintf(fo, "#define " STR_NUMBGM " %i\n", confs.mus_v, musiclist->numbgm);
				for (i=0; i<musiclist->numbgm; i++) {
					for (j=strlen(musiclist->bgm[i]->varname); j>=0; j--) tmp[j] = toupper(musiclist->bgm[i]->varname[j]);
					fprintf(fo, "#define %s %i\n", tmp, i);
					fprintf(fo, "extern unsigned long %s[];\n", musiclist->bgm[i]->varname);
				}
				fprintf(fo, "\n");
			}
			if (!confs.quiet) printf("Exported header '%s'\n", confs.outh_f);
		} else printf("Error: Couldn't write output to '%s'\n", confs.outh_f);
		fclose(fo);
	}

	// Output sound list
	if (strlen(confs.outl_f)) {
		fo = fopen(confs.outl_f, "w");
		if (fo) {
			if (confs.format == FILE_ECODE_ASM) {
				fprintf(fo, "; %s\n; Sound list file\n\n", EXPORT_STR);
				if (strlen(musicsh.title)) fprintf(fo, "; Title: %s\n", musicsh.title);
				if (strlen(musicsh.composer)) fprintf(fo, "; Composer: %s\n", musicsh.composer);
				if (strlen(musicsh.programmer)) fprintf(fo, "; Programmer: %s\n", musicsh.programmer);
				if (strlen(musicsh.description)) fprintf(fo, "; Description: %s\n", musicsh.description);
				fprintf(fo, "\n; Mastertime: $%04X, (%i)\n", musicsh.mastertime_val, musicsh.mastertime_val);
				fprintf(fo, "\n; %3i Pattern(s)\n", musiclist->numpattern);
				// Export SFXs
				fprintf(fo, "\n; %3i SFX\n", musiclist->numsfx);
				fprintf(fo, "%s:\n", confs.sfx_v);
				for (i=0; i<musiclist->numsfx; i++) {
					fprintf(fo, "\t.dd %s\n", musiclist->sfx[i]->varname);
				}
				// Export BGMs
				fprintf(fo, "\n; %3i BGM\n", musiclist->numbgm);
				fprintf(fo, "%s:\n", confs.bgm_v);
				for (i=0; i<musiclist->numbgm; i++) {
					fprintf(fo, "\t.dd %s\n", musiclist->bgm[i]->varname);
				}
				fprintf(fo, "\n");
			} else if (confs.format == FILE_ECODE_C) {
				fprintf(fo, "// %s\n// Sound list file\n\n", EXPORT_STR);
				if (strlen(musicsh.title)) fprintf(fo, "// Title: %s\n", musicsh.title);
				if (strlen(musicsh.composer)) fprintf(fo, "// Composer: %s\n", musicsh.composer);
				if (strlen(musicsh.programmer)) fprintf(fo, "// Programmer: %s\n", musicsh.programmer);
				if (strlen(musicsh.description)) fprintf(fo, "// Description: %s\n", musicsh.description);
				fprintf(fo, "\n// Mastertime: $%04X, (%i)\n", musicsh.mastertime_val, musicsh.mastertime_val);
				fprintf(fo, "\n// %3i Pattern(s)\n", musiclist->numpattern);
				// Export SFXs
				fprintf(fo, "\n// %3i SFX\n", musiclist->numsfx);
				fprintf(fo, "unsigned long %s[] = {\n", confs.sfx_v);
				for (i=0; i<musiclist->numsfx; i++) {
					fprintf(fo, "\t%s,\n", musiclist->sfx[i]->varname);
				}
				fprintf(fo, "};\n");
				// Export BGMs
				fprintf(fo, "\n// %3i BGM\n", musiclist->numbgm);
				fprintf(fo, "unsigned long %s[] = {\n", confs.bgm_v);
				for (i=0; i<musiclist->numbgm; i++) {
					fprintf(fo, "\t%s,\n", musiclist->bgm[i]->varname);
				}
				fprintf(fo, "};\n");
				fprintf(fo, "\n");
			}
			if (!confs.quiet) printf("Exported sound list '%s'\n", confs.outl_f);
		} else printf("Error: Couldn't write output to '%s'\n", confs.outl_f);
		fclose(fo);
	}

	// Playback converted music
	if (confs.play_v[0]) {

		// Initialize PMMusic engine
		if (!pmmusic_initialize(PMSNDBUFFER, confs.sndengine, confs.sndfilter)) {
			printf("Error: Couldn't initialize pmmusic engine\n");
			return 1;	
		}
		pmmusic_init(musicsh.mastertime_val, musicsh.ram);

		// Check if varname exist
		tbgm = pmmusic_getBGM(musiclist, confs.play_v, NULL);
		if (!tbgm) {
			tsfx = pmmusic_getSFX(musiclist, confs.play_v, NULL);
			if (!tsfx) {
				tsfx = pmmusic_getPAT(musiclist, confs.play_v, NULL);
				if (!tsfx) {
					printf("Error: Couldn't find '%s' to play\n", confs.play_v);
					return 1;
				} else {
					pmmusic_playsfx(tsfx);
					if (!confs.quiet) printf("Playing Pattern '%s'\n", confs.play_v);
				}
			} else {
				pmmusic_playsfx(tsfx);
				if (!confs.quiet) printf("Playing SFX '%s'\n", confs.play_v);
			}
		} else {
			pmmusic_playbgm(tbgm);
			if (!confs.quiet) printf("Playing BGM '%s'\nPress any key to stop...\n", confs.play_v);
		}

		// Open WAV capture if was requested
		if (confs.rec_f[0]) {
			sdump = Open_ExportWAV(confs.rec_f, EXPORTWAV_44KHZ | EXPORTWAV_MONO | EXPORTWAV_16BITS);
			if (!sdump) {
				printf("Error: Opening sound export file\n");
				return 1;
			}
			raw_handle_ctrlc(sdump_close);
		}

		// Initialize audio & play
		init_saudio(audio_fill, SOUNDBUFFER);
		play_saudio();

		// Play 
		playdec = 36;
		while ((!raw_input_check()) && playdec && notbreak) {
			if (pmmusic.aud_ena) playdec = 36;
			else playdec--;

			pmmusic_emulate(4000000/72);
			if (pmmusic.err) {
				if (pmmusic.err == 1) {
					printf("Player error: BGM out of range\n");
				} else if (pmmusic.err == 2) {
					printf("Player error: BGM invalid pattern\n");
				} else if (pmmusic.err == 3) {
					printf("Player error: SFX out of range\n");
				} else if (pmmusic.err == 4) {
					printf("Player error: Recursive overflow\n");
				} else {
					printf("Player error: Unknown\n");
				}
				break;
			}

			while (MinxAudio_SyncWithAudio()) {
				sync_saudio();
				sleep_saudio(1);
			}
		}

		// Terminate audio
		term_saudio();

		// Close WAV capture if there's one
		if (sdump) Close_ExportWAV(sdump);

		pmmusic_terminate();
	}

	// Destroy
	pmmusic_deletelist(musiclist);

	return 0;
}
