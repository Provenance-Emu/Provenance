/*
 * PicoDrive
 * (C) notaz, 2007-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#ifdef __GP2X__
#include <unistd.h>
#endif

#include "../libpicofe/posix.h"
#include "../libpicofe/input.h"
#include "../libpicofe/fonts.h"
#include "../libpicofe/sndout.h"
#include "../libpicofe/lprintf.h"
#include "../libpicofe/plat.h"
#include "emu.h"
#include "input_pico.h"
#include "menu_pico.h"
#include "config_file.h"

#include <pico/pico_int.h>
#include <pico/patch.h>

#ifndef _WIN32
#define PATH_SEP      "/"
#define PATH_SEP_C    '/'
#else
#define PATH_SEP      "\\"
#define PATH_SEP_C    '\\'
#endif

#define STATUS_MSG_TIMEOUT 2000

void *g_screen_ptr;

int g_screen_width  = 320;
int g_screen_height = 240;

const char *PicoConfigFile = "config2.cfg";
currentConfig_t currentConfig, defaultConfig;
int state_slot = 0;
int config_slot = 0, config_slot_current = 0;
int pico_pen_x = 320/2, pico_pen_y = 240/2;
int pico_inp_mode;
int flip_after_sync;
int engineState = PGS_Menu;

static short __attribute__((aligned(4))) sndBuffer[2*44100/50];

/* tmp buff to reduce stack usage for plats with small stack */
static char static_buff[512];
const char *rom_fname_reload;
char rom_fname_loaded[512];
int reset_timing = 0;
static unsigned int notice_msg_time;	/* when started showing */
static char noticeMsg[40];

unsigned char *movie_data = NULL;
static int movie_size = 0;


/* don't use tolower() for easy old glibc binary compatibility */
static void strlwr_(char *string)
{
	char *p;
	for (p = string; *p; p++)
		if ('A' <= *p && *p <= 'Z')
			*p += 'a' - 'A';
}

static int try_rfn_cut(char *fname)
{
	FILE *tmp;
	char *p;

	p = fname + strlen(fname) - 1;
	for (; p > fname; p--)
		if (*p == '.') break;
	*p = 0;

	if((tmp = fopen(fname, "rb"))) {
		fclose(tmp);
		return 1;
	}
	return 0;
}

static void get_ext(const char *file, char *ext)
{
	const char *p;

	p = file + strlen(file) - 4;
	if (p < file) p = file;
	strncpy(ext, p, 4);
	ext[4] = 0;
	strlwr_(ext);
}

static void fname_ext(char *dst, int dstlen, const char *prefix, const char *ext, const char *fname)
{
	int prefix_len = 0;
	const char *p;

	*dst = 0;
	if (prefix) {
		int len = plat_get_root_dir(dst, dstlen);
		strcpy(dst + len, prefix);
		prefix_len = len + strlen(prefix);
	}

	p = fname + strlen(fname) - 1;
	for (; p >= fname && *p != PATH_SEP_C; p--)
		;
	p++;
	strncpy(dst + prefix_len, p, dstlen - prefix_len - 1);

	dst[dstlen - 8] = 0;
	if (dst[strlen(dst) - 4] == '.')
		dst[strlen(dst) - 4] = 0;
	if (ext)
		strcat(dst, ext);
}

static void romfname_ext(char *dst, int dstlen, const char *prefix, const char *ext)
{
	fname_ext(dst, dstlen, prefix, ext, rom_fname_loaded);
}

void emu_status_msg(const char *format, ...)
{
	va_list vl;
	int ret;

	va_start(vl, format);
	ret = vsnprintf(noticeMsg, sizeof(noticeMsg), format, vl);
	va_end(vl);

	/* be sure old text gets overwritten */
	for (; ret < 28; ret++)
		noticeMsg[ret] = ' ';
	noticeMsg[ret] = 0;

	notice_msg_time = plat_get_ticks_ms();
}

static const char * const biosfiles_us[] = {
	"us_scd2_9306", "SegaCDBIOS9303", "us_scd1_9210", "bios_CD_U"
};
static const char * const biosfiles_eu[] = {
	"eu_mcd2_9306", "eu_mcd2_9303", "eu_mcd1_9210", "bios_CD_E"
};
static const char * const biosfiles_jp[] = {
	"jp_mcd2_921222", "jp_mcd1_9112", "jp_mcd1_9111", "bios_CD_J"
};

static const char *find_bios(int *region, const char *cd_fname)
{
	int i, count;
	const char * const *files;
	FILE *f = NULL;
	int ret;

	// we need to have config loaded at this point
	ret = emu_read_config(cd_fname, 0);
	if (!ret) emu_read_config(NULL, 0);

	if (PicoRegionOverride) {
		*region = PicoRegionOverride;
		lprintf("override region to %s\n", *region != 4 ?
			(*region == 8 ? "EU" : "JAP") : "USA");
	}

	if (*region == 4) { // US
		files = biosfiles_us;
		count = sizeof(biosfiles_us) / sizeof(char *);
	} else if (*region == 8) { // EU
		files = biosfiles_eu;
		count = sizeof(biosfiles_eu) / sizeof(char *);
	} else if (*region == 1 || *region == 2) {
		files = biosfiles_jp;
		count = sizeof(biosfiles_jp) / sizeof(char *);
	} else {
		return 0;
	}

	for (i = 0; i < count; i++)
	{
		emu_make_path(static_buff, files[i], sizeof(static_buff) - 4);
		strcat(static_buff, ".bin");
		f = fopen(static_buff, "rb");
		if (f) break;

		static_buff[strlen(static_buff) - 4] = 0;
		strcat(static_buff, ".zip");
		f = fopen(static_buff, "rb");
		if (f) break;
	}

	if (f) {
		lprintf("using bios: %s\n", static_buff);
		fclose(f);
		return static_buff;
	} else {
		sprintf(static_buff, "no %s BIOS files found, read docs",
			*region != 4 ? (*region == 8 ? "EU" : "JAP") : "USA");
		menu_update_msg(static_buff);
		return NULL;
	}
}

/* check if the name begins with BIOS name */
/*
static int emu_isBios(const char *name)
{
	int i;
	for (i = 0; i < sizeof(biosfiles_us)/sizeof(biosfiles_us[0]); i++)
		if (strstr(name, biosfiles_us[i]) != NULL) return 1;
	for (i = 0; i < sizeof(biosfiles_eu)/sizeof(biosfiles_eu[0]); i++)
		if (strstr(name, biosfiles_eu[i]) != NULL) return 1;
	for (i = 0; i < sizeof(biosfiles_jp)/sizeof(biosfiles_jp[0]); i++)
		if (strstr(name, biosfiles_jp[i]) != NULL) return 1;
	return 0;
}
*/

static int extract_text(char *dest, const unsigned char *src, int len, int swab)
{
	char *p = dest;
	int i;

	if (swab) swab = 1;

	for (i = len - 1; i >= 0; i--)
	{
		if (src[i^swab] != ' ') break;
	}
	len = i + 1;

	for (i = 0; i < len; i++)
	{
		unsigned char s = src[i^swab];
		if (s >= 0x20 && s < 0x7f && s != '#' && s != '|' &&
			s != '[' && s != ']' && s != '\\')
		{
			*p++ = s;
		}
		else
		{
			sprintf(p, "\\%02x", s);
			p += 3;
		}
	}

	return p - dest;
}

static char *emu_make_rom_id(const char *fname)
{
	static char id_string[3+0xe*3+0x3*3+0x30*3+3];
	int pos, swab = 1;

	if (PicoAHW & PAHW_MCD) {
		strcpy(id_string, "CD|");
		swab = 0;
	}
	else if (PicoAHW & PAHW_SMS)
		strcpy(id_string, "MS|");
	else	strcpy(id_string, "MD|");
	pos = 3;

	if (!(PicoAHW & PAHW_SMS)) {
		pos += extract_text(id_string + pos, media_id_header + 0x80, 0x0e, swab); // serial
		id_string[pos] = '|'; pos++;
		pos += extract_text(id_string + pos, media_id_header + 0xf0, 0x03, swab); // region
		id_string[pos] = '|'; pos++;
		pos += extract_text(id_string + pos, media_id_header + 0x50, 0x30, swab); // overseas name
		id_string[pos] = 0;
		if (pos > 5)
			return id_string;
		pos = 3;
	}

	// can't find name in ROM, use filename
	fname_ext(id_string + 3, sizeof(id_string) - 3, NULL, NULL, fname);

	return id_string;
}

// buffer must be at least 150 byte long
void emu_get_game_name(char *str150)
{
	int ret, swab = (PicoAHW & PAHW_MCD) ? 0 : 1;
	char *s, *d;

	ret = extract_text(str150, media_id_header + 0x50, 0x30, swab); // overseas name

	for (s = d = str150 + 1; s < str150+ret; s++)
	{
		if (*s == 0) break;
		if (*s != ' ' || d[-1] != ' ')
			*d++ = *s;
	}
	*d = 0;
}

static void system_announce(void)
{
	const char *sys_name, *tv_standard, *extra = "";
	int fps;

	if (PicoAHW & PAHW_SMS) {
		sys_name = "Master System";
#ifdef NO_SMS
		extra = " [no support]";
#endif
	} else if (PicoAHW & PAHW_PICO) {
		sys_name = "Pico";
	} else if ((PicoAHW & (PAHW_32X|PAHW_MCD)) == (PAHW_32X|PAHW_MCD)) {
		sys_name = "32X + Mega CD";
		if ((Pico.m.hardware & 0xc0) == 0x80)
			sys_name = "32X + Sega CD";
	} else if (PicoAHW & PAHW_MCD) {
		sys_name = "Mega CD";
		if ((Pico.m.hardware & 0xc0) == 0x80)
			sys_name = "Sega CD";
	} else if (PicoAHW & PAHW_32X) {
		sys_name = "32X";
	} else {
		sys_name = "MegaDrive";
		if ((Pico.m.hardware & 0xc0) == 0x80)
			sys_name = "Genesis";
	}
	tv_standard = Pico.m.pal ? "PAL" : "NTSC";
	fps = Pico.m.pal ? 50 : 60;

	emu_status_msg("%s %s / %dFPS%s", tv_standard, sys_name, fps, extra);
}

static void do_region_override(const char *media_fname)
{
	// we only need to override region if config tells us so
	int ret = emu_read_config(media_fname, 0);
	if (!ret) emu_read_config(NULL, 0);
}

int emu_reload_rom(const char *rom_fname_in)
{
	// use setting before rom config is loaded
	int autoload = g_autostateld_opt;
	char *rom_fname = NULL;
	char ext[5];
	enum media_type_e media_type;
	int menu_romload_started = 0;
	char carthw_path[512];
	int retval = 0;

	lprintf("emu_ReloadRom(%s)\n", rom_fname_in);

	rom_fname = strdup(rom_fname_in);
	if (rom_fname == NULL)
		return 0;

	get_ext(rom_fname, ext);

	// early cleanup
	PicoPatchUnload();
	if (movie_data) {
		free(movie_data);
		movie_data = 0;
	}

	if (!strcmp(ext, ".gmv"))
	{
		// check for both gmv and rom
		int dummy;
		FILE *movie_file = fopen(rom_fname, "rb");
		if (!movie_file) {
			menu_update_msg("Failed to open movie.");
			goto out;
		}
		fseek(movie_file, 0, SEEK_END);
		movie_size = ftell(movie_file);
		fseek(movie_file, 0, SEEK_SET);
		if (movie_size < 64+3) {
			menu_update_msg("Invalid GMV file.");
			fclose(movie_file);
			goto out;
		}
		movie_data = malloc(movie_size);
		if (movie_data == NULL) {
			menu_update_msg("low memory.");
			fclose(movie_file);
			goto out;
		}
		dummy = fread(movie_data, 1, movie_size, movie_file);
		fclose(movie_file);
		if (strncmp((char *)movie_data, "Gens Movie TEST", 15) != 0) {
			menu_update_msg("Invalid GMV file.");
			goto out;
		}
		dummy = try_rfn_cut(rom_fname) || try_rfn_cut(rom_fname);
		if (!dummy) {
			menu_update_msg("Could't find a ROM for movie.");
			goto out;
		}
		get_ext(rom_fname, ext);
		lprintf("gmv loaded for %s\n", rom_fname);
	}
	else if (!strcmp(ext, ".pat"))
	{
		int dummy;
		PicoPatchLoad(rom_fname);
		dummy = try_rfn_cut(rom_fname) || try_rfn_cut(rom_fname);
		if (!dummy) {
			menu_update_msg("Could't find a ROM to patch.");
			goto out;
		}
		get_ext(rom_fname, ext);
	}

	menu_romload_prepare(rom_fname); // also CD load
	menu_romload_started = 1;

	emu_make_path(carthw_path, "carthw.cfg", sizeof(carthw_path));

	media_type = PicoLoadMedia(rom_fname, carthw_path,
			find_bios, do_region_override);

	switch (media_type) {
	case PM_BAD_DETECT:
		menu_update_msg("Not a ROM/CD img selected.");
		goto out;
	case PM_BAD_CD:
		menu_update_msg("Invalid CD image");
		goto out;
	case PM_BAD_CD_NO_BIOS:
		// find_bios() prints a message
		goto out;
	case PM_ERROR:
		menu_update_msg("Load error");
		goto out;
	default:
		break;
	}

	// make quirks visible in UI
	if (PicoQuirks & PQUIRK_FORCE_6BTN)
		currentConfig.input_dev0 = PICO_INPUT_PAD_6BTN;

	menu_romload_end();
	menu_romload_started = 0;

	if (PicoPatches) {
		PicoPatchPrepare();
		PicoPatchApply();
	}

	// additional movie stuff
	if (movie_data)
	{
		enum input_device indev = (movie_data[0x14] == '6') ?
			PICO_INPUT_PAD_6BTN : PICO_INPUT_PAD_3BTN;
		PicoSetInputDevice(0, indev);
		PicoSetInputDevice(1, indev);

		PicoOpt |= POPT_DIS_VDP_FIFO; // no VDP fifo timing
		if (movie_data[0xF] >= 'A') {
			if (movie_data[0x16] & 0x80) {
				PicoRegionOverride = 8;
			} else {
				PicoRegionOverride = 4;
			}
			PicoReset();
			// TODO: bits 6 & 5
		}
		movie_data[0x18+30] = 0;
		emu_status_msg("MOVIE: %s", (char *) &movie_data[0x18]);
	}
	else
	{
		system_announce();
		PicoOpt &= ~POPT_DIS_VDP_FIFO;
	}

	strncpy(rom_fname_loaded, rom_fname, sizeof(rom_fname_loaded)-1);
	rom_fname_loaded[sizeof(rom_fname_loaded)-1] = 0;

	// load SRAM for this ROM
	if (currentConfig.EmuOpt & EOPT_EN_SRAM)
		emu_save_load_game(1, 1);

	// state autoload?
	if (autoload) {
		int time, newest = 0, newest_slot = -1;
		int slot;

		for (slot = 0; slot < 10; slot++) {
			if (emu_check_save_file(slot, &time)) {
				if (time > newest) {
					newest = time;
					newest_slot = slot;
				}
			}
		}

		if (newest_slot >= 0) {
			lprintf("autoload slot %d\n", newest_slot);
			state_slot = newest_slot;
			emu_save_load_game(1, 0);
		}
		else {
			lprintf("no save to autoload.\n");
		}
	}

	retval = 1;
out:
	if (menu_romload_started)
		menu_romload_end();
	free(rom_fname);
	return retval;
}

int emu_swap_cd(const char *fname)
{
	enum cd_img_type cd_type;
	int ret = -1;

	cd_type = PicoCdCheck(fname, NULL);
	if (cd_type != CIT_NOT_CD)
		ret = cdd_load(fname, cd_type);
	if (ret != 0) {
		menu_update_msg("Load failed, invalid CD image?");
		return 0;
	}

	strncpy(rom_fname_loaded, fname, sizeof(rom_fname_loaded)-1);
	rom_fname_loaded[sizeof(rom_fname_loaded) - 1] = 0;

	return 1;
}

// <base dir><end>
void emu_make_path(char *buff, const char *end, int size)
{
	int pos, end_len;

	end_len = strlen(end);
	pos = plat_get_root_dir(buff, size);
	strncpy(buff + pos, end, size - pos);
	buff[size - 1] = 0;
	if (pos + end_len > size - 1)
		lprintf("Warning: path truncated: %s\n", buff);
}

static void make_config_cfg(char *cfg_buff_512)
{
	emu_make_path(cfg_buff_512, PicoConfigFile, 512-6);
	if (config_slot != 0)
	{
		char *p = strrchr(cfg_buff_512, '.');
		if (p == NULL)
			p = cfg_buff_512 + strlen(cfg_buff_512);
		sprintf(p, ".%i.cfg", config_slot);
	}
	cfg_buff_512[511] = 0;
}

void emu_prep_defconfig(void)
{
	memset(&defaultConfig, 0, sizeof(defaultConfig));
	defaultConfig.EmuOpt    = 0x9d | EOPT_EN_CD_LEDS;
	defaultConfig.s_PicoOpt = POPT_EN_STEREO|POPT_EN_FM|POPT_EN_PSG|POPT_EN_Z80 |
				  POPT_EN_MCD_PCM|POPT_EN_MCD_CDDA|POPT_EN_MCD_GFX |
				  POPT_EN_DRC|POPT_ACC_SPRITES |
				  POPT_EN_32X|POPT_EN_PWM;
	defaultConfig.s_PsndRate = 44100;
	defaultConfig.s_PicoRegion = 0; // auto
	defaultConfig.s_PicoAutoRgnOrder = 0x184; // US, EU, JP
	defaultConfig.s_PicoCDBuffers = 0;
	defaultConfig.confirm_save = EOPT_CONFIRM_SAVE;
	defaultConfig.Frameskip = -1; // auto
	defaultConfig.input_dev0 = PICO_INPUT_PAD_3BTN;
	defaultConfig.input_dev1 = PICO_INPUT_PAD_3BTN;
	defaultConfig.volume = 50;
	defaultConfig.gamma = 100;
	defaultConfig.scaling = 0;
	defaultConfig.turbo_rate = 15;
	defaultConfig.msh2_khz = PICO_MSH2_HZ / 1000;
	defaultConfig.ssh2_khz = PICO_SSH2_HZ / 1000;

	// platform specific overrides
	pemu_prep_defconfig();
}

void emu_set_defconfig(void)
{
	memcpy(&currentConfig, &defaultConfig, sizeof(currentConfig));
	PicoOpt = currentConfig.s_PicoOpt;
	PsndRate = currentConfig.s_PsndRate;
	PicoRegionOverride = currentConfig.s_PicoRegion;
	PicoAutoRgnOrder = currentConfig.s_PicoAutoRgnOrder;
}

int emu_read_config(const char *rom_fname, int no_defaults)
{
	char cfg[512];
	int ret;

	if (!no_defaults)
		emu_set_defconfig();

	if (rom_fname == NULL)
	{
		// global config
		make_config_cfg(cfg);
		ret = config_readsect(cfg, NULL);
	}
	else
	{
		char ext[16];
		int vol;

		if (config_slot != 0)
			snprintf(ext, sizeof(ext), ".%i.cfg", config_slot);
		else
			strcpy(ext, ".cfg");

		fname_ext(cfg, sizeof(cfg), "cfg"PATH_SEP, ext, rom_fname);

		// read user's config
		vol = currentConfig.volume;
		ret = config_readsect(cfg, NULL);
		currentConfig.volume = vol; // make vol global (bah)

		if (ret != 0)
		{
			// read global config, and apply game_def.cfg on top
			make_config_cfg(cfg);
			config_readsect(cfg, NULL);

			emu_make_path(cfg, "game_def.cfg", sizeof(cfg));
			ret = config_readsect(cfg, emu_make_rom_id(rom_fname));
		}
	}

	pemu_validate_config();

	// some sanity checks
#ifdef PSP
	/* TODO: mv to plat_validate_config() */
	if (currentConfig.CPUclock < 10 || currentConfig.CPUclock > 4096) currentConfig.CPUclock = 200;
	if (currentConfig.gamma < -4 || currentConfig.gamma >  16) currentConfig.gamma = 0;
	if (currentConfig.gamma2 < 0 || currentConfig.gamma2 > 2)  currentConfig.gamma2 = 0;
#endif
	if (currentConfig.volume < 0 || currentConfig.volume > 99)
		currentConfig.volume = 50;

	if (ret == 0)
		config_slot_current = config_slot;

	return (ret == 0);
}


int emu_write_config(int is_game)
{
	char cfg[512];
	int ret, write_lrom = 0;

	if (!is_game)
	{
		make_config_cfg(cfg);
		write_lrom = 1;
	} else {
		char ext[16];

		if (config_slot != 0)
			snprintf(ext, sizeof(ext), ".%i.cfg", config_slot);
		else
			strcpy(ext, ".cfg");

		romfname_ext(cfg, sizeof(cfg), "cfg"PATH_SEP, ext);
	}

	lprintf("emu_write_config: %s ", cfg);
	ret = config_write(cfg);
	if (write_lrom) config_writelrom(cfg);
#ifdef __GP2X__
	sync();
#endif
	lprintf((ret == 0) ? "(ok)\n" : "(failed)\n");

	if (ret == 0) config_slot_current = config_slot;
	return ret == 0;
}


/* always using built-in font */

#define mk_text_out(name, type, val, topleft, step_x, step_y) \
void name(int x, int y, const char *text)				\
{									\
	int i, l, len = strlen(text);					\
	type *screen = (type *)(topleft) + x * step_x + y * step_y;	\
									\
	for (i = 0; i < len; i++, screen += 8 * step_x)			\
	{								\
		for (l = 0; l < 8; l++)					\
		{							\
			unsigned char fd = fontdata8x8[text[i] * 8 + l];\
			type *s = screen + l * step_y;			\
			if (fd&0x80) s[step_x * 0] = val;		\
			if (fd&0x40) s[step_x * 1] = val;		\
			if (fd&0x20) s[step_x * 2] = val;		\
			if (fd&0x10) s[step_x * 3] = val;		\
			if (fd&0x08) s[step_x * 4] = val;		\
			if (fd&0x04) s[step_x * 5] = val;		\
			if (fd&0x02) s[step_x * 6] = val;		\
			if (fd&0x01) s[step_x * 7] = val;		\
		}							\
	}								\
}

mk_text_out(emu_text_out8,      unsigned char,    0xf0, g_screen_ptr, 1, g_screen_width)
mk_text_out(emu_text_out16,     unsigned short, 0xffff, g_screen_ptr, 1, g_screen_width)
mk_text_out(emu_text_out8_rot,  unsigned char,    0xf0,
	(char *)g_screen_ptr  + (g_screen_width - 1) * g_screen_height, -g_screen_height, 1)
mk_text_out(emu_text_out16_rot, unsigned short, 0xffff,
	(short *)g_screen_ptr + (g_screen_width - 1) * g_screen_height, -g_screen_height, 1)

#undef mk_text_out

void emu_osd_text16(int x, int y, const char *text)
{
	int len = strlen(text) * 8;
	int i, h;

	len++;
	if (x + len > g_screen_width)
		len = g_screen_width - x;

	for (h = 0; h < 8; h++) {
		unsigned short *p;
		p = (unsigned short *)g_screen_ptr
			+ x + g_screen_width * (y + h);
		for (i = len; i > 0; i--, p++)
			*p = (*p >> 2) & 0x39e7;
	}
	emu_text_out16(x, y, text);
}

static void update_movie(void)
{
	int offs = Pico.m.frame_count*3 + 0x40;
	if (offs+3 > movie_size) {
		free(movie_data);
		movie_data = 0;
		emu_status_msg("END OF MOVIE.");
		lprintf("END OF MOVIE.\n");
	} else {
		// MXYZ SACB RLDU
		PicoPad[0] = ~movie_data[offs]   & 0x8f; // ! SCBA RLDU
		if(!(movie_data[offs]   & 0x10)) PicoPad[0] |= 0x40; // C
		if(!(movie_data[offs]   & 0x20)) PicoPad[0] |= 0x10; // A
		if(!(movie_data[offs]   & 0x40)) PicoPad[0] |= 0x20; // B
		PicoPad[1] = ~movie_data[offs+1] & 0x8f; // ! SCBA RLDU
		if(!(movie_data[offs+1] & 0x10)) PicoPad[1] |= 0x40; // C
		if(!(movie_data[offs+1] & 0x20)) PicoPad[1] |= 0x10; // A
		if(!(movie_data[offs+1] & 0x40)) PicoPad[1] |= 0x20; // B
		PicoPad[0] |= (~movie_data[offs+2] & 0x0A) << 8; // ! MZYX
		if(!(movie_data[offs+2] & 0x01)) PicoPad[0] |= 0x0400; // X
		if(!(movie_data[offs+2] & 0x04)) PicoPad[0] |= 0x0100; // Z
		PicoPad[1] |= (~movie_data[offs+2] & 0xA0) << 4; // ! MZYX
		if(!(movie_data[offs+2] & 0x10)) PicoPad[1] |= 0x0400; // X
		if(!(movie_data[offs+2] & 0x40)) PicoPad[1] |= 0x0100; // Z
	}
}

static int try_ropen_file(const char *fname, int *time)
{
	struct stat st;
	FILE *f;

	f = fopen(fname, "rb");
	if (f) {
		if (time != NULL) {
			*time = 0;
			if (fstat(fileno(f), &st) == 0)
				*time = (int)st.st_mtime;
		}
		fclose(f);
		return 1;
	}
	return 0;
}

char *emu_get_save_fname(int load, int is_sram, int slot, int *time)
{
	char *saveFname = static_buff;
	char ext[16];

	if (is_sram)
	{
		strcpy(ext, (PicoAHW & PAHW_MCD) ? ".brm" : ".srm");
		romfname_ext(saveFname, sizeof(static_buff),
			(PicoAHW & PAHW_MCD) ? "brm"PATH_SEP : "srm"PATH_SEP, ext);
		if (!load)
			return saveFname;

		if (try_ropen_file(saveFname, time))
			return saveFname;

		romfname_ext(saveFname, sizeof(static_buff), NULL, ext);
		if (try_ropen_file(saveFname, time))
			return saveFname;
	}
	else
	{
		const char *ext_main = (currentConfig.EmuOpt & EOPT_GZIP_SAVES) ? ".mds.gz" : ".mds";
		const char *ext_othr = (currentConfig.EmuOpt & EOPT_GZIP_SAVES) ? ".mds" : ".mds.gz";
		ext[0] = 0;
		if (slot > 0 && slot < 10)
			sprintf(ext, ".%i", slot);
		strcat(ext, ext_main);

		if (!load) {
			romfname_ext(saveFname, sizeof(static_buff), "mds" PATH_SEP, ext);
			return saveFname;
		}
		else {
			romfname_ext(saveFname, sizeof(static_buff), "mds" PATH_SEP, ext);
			if (try_ropen_file(saveFname, time))
				return saveFname;

			romfname_ext(saveFname, sizeof(static_buff), NULL, ext);
			if (try_ropen_file(saveFname, time))
				return saveFname;

			// try the other ext
			ext[0] = 0;
			if (slot > 0 && slot < 10)
				sprintf(ext, ".%i", slot);
			strcat(ext, ext_othr);

			romfname_ext(saveFname, sizeof(static_buff), "mds"PATH_SEP, ext);
			if (try_ropen_file(saveFname, time))
				return saveFname;
		}
	}

	return NULL;
}

int emu_check_save_file(int slot, int *time)
{
	return emu_get_save_fname(1, 0, slot, time) ? 1 : 0;
}

int emu_save_load_game(int load, int sram)
{
	int ret = 0;
	char *saveFname;

	// make save filename
	saveFname = emu_get_save_fname(load, sram, state_slot, NULL);
	if (saveFname == NULL) {
		if (!sram)
			emu_status_msg(load ? "LOAD FAILED (missing file)" : "SAVE FAILED");
		return -1;
	}

	lprintf("saveLoad (%i, %i): %s\n", load, sram, saveFname);

	if (sram)
	{
		FILE *sramFile;
		int sram_size;
		unsigned char *sram_data;
		int truncate = 1;
		if (PicoAHW & PAHW_MCD)
		{
			if (PicoOpt & POPT_EN_MCD_RAMCART) {
				sram_size = 0x12000;
				sram_data = SRam.data;
				if (sram_data)
					memcpy32((int *)sram_data, (int *)Pico_mcd->bram, 0x2000/4);
			} else {
				sram_size = 0x2000;
				sram_data = Pico_mcd->bram;
				truncate  = 0; // the .brm may contain RAM cart data after normal brm
			}
		} else {
			sram_size = SRam.size;
			sram_data = SRam.data;
		}
		if (sram_data == NULL)
			return 0; // SRam forcefully disabled for this game

		if (load)
		{
			sramFile = fopen(saveFname, "rb");
			if (!sramFile)
				return -1;
			ret = fread(sram_data, 1, sram_size, sramFile);
			ret = ret > 0 ? 0 : -1;
			fclose(sramFile);
			if ((PicoAHW & PAHW_MCD) && (PicoOpt&POPT_EN_MCD_RAMCART))
				memcpy32((int *)Pico_mcd->bram, (int *)sram_data, 0x2000/4);
		} else {
			// sram save needs some special processing
			// see if we have anything to save
			for (; sram_size > 0; sram_size--)
				if (sram_data[sram_size-1]) break;

			if (sram_size) {
				sramFile = fopen(saveFname, truncate ? "wb" : "r+b");
				if (!sramFile) sramFile = fopen(saveFname, "wb"); // retry
				if (!sramFile) return -1;
				ret = fwrite(sram_data, 1, sram_size, sramFile);
				ret = (ret != sram_size) ? -1 : 0;
				fclose(sramFile);
#ifdef __GP2X__
				sync();
#endif
			}
		}
		return ret;
	}
	else
	{
		ret = PicoState(saveFname, !load);
		if (!ret) {
#ifdef __GP2X__
			if (!load) sync();
#endif
			emu_status_msg(load ? "STATE LOADED" : "STATE SAVED");
		} else {
			emu_status_msg(load ? "LOAD FAILED" : "SAVE FAILED");
			ret = -1;
		}

		return ret;
	}
}

void emu_set_fastforward(int set_on)
{
	static void *set_PsndOut = NULL;
	static int set_Frameskip, set_EmuOpt, is_on = 0;

	if (set_on && !is_on) {
		set_PsndOut = PsndOut;
		set_Frameskip = currentConfig.Frameskip;
		set_EmuOpt = currentConfig.EmuOpt;
		PsndOut = NULL;
		currentConfig.Frameskip = 8;
		currentConfig.EmuOpt &= ~4;
		currentConfig.EmuOpt |= 0x40000;
		is_on = 1;
		emu_status_msg("FAST FORWARD");
	}
	else if (!set_on && is_on) {
		PsndOut = set_PsndOut;
		currentConfig.Frameskip = set_Frameskip;
		currentConfig.EmuOpt = set_EmuOpt;
		PsndRerate(1);
		is_on = 0;
	}
}

static void emu_tray_open(void)
{
	engineState = PGS_TrayMenu;
}

static void emu_tray_close(void)
{
	emu_status_msg("CD tray closed.");
}

void emu_32x_startup(void)
{
	plat_video_toggle_renderer(0, 0); // HACK
	system_announce();
}

void emu_reset_game(void)
{
	PicoReset();
	reset_timing = 1;
}

void run_events_pico(unsigned int events)
{
	int lim_x;

	if (events & PEV_PICO_SWINP) {
		pico_inp_mode++;
		if (pico_inp_mode > 2)
			pico_inp_mode = 0;
		switch (pico_inp_mode) {
			case 2: emu_status_msg("Input: Pen on Pad"); break;
			case 1: emu_status_msg("Input: Pen on Storyware"); break;
			case 0: emu_status_msg("Input: Joystick");
				PicoPicohw.pen_pos[0] = PicoPicohw.pen_pos[1] = 0x8000;
				break;
		}
	}
	if (events & PEV_PICO_PPREV) {
		PicoPicohw.page--;
		if (PicoPicohw.page < 0)
			PicoPicohw.page = 0;
		emu_status_msg("Page %i", PicoPicohw.page);
	}
	if (events & PEV_PICO_PNEXT) {
		PicoPicohw.page++;
		if (PicoPicohw.page > 6)
			PicoPicohw.page = 6;
		emu_status_msg("Page %i", PicoPicohw.page);
	}

	if (pico_inp_mode == 0)
		return;

	/* handle other input modes */
	if (PicoPad[0] & 1) pico_pen_y--;
	if (PicoPad[0] & 2) pico_pen_y++;
	if (PicoPad[0] & 4) pico_pen_x--;
	if (PicoPad[0] & 8) pico_pen_x++;
	PicoPad[0] &= ~0x0f; // release UDLR

	lim_x = (Pico.video.reg[12]&1) ? 319 : 255;
	if (pico_pen_y < 8)
		pico_pen_y = 8;
	if (pico_pen_y > 224 - PICO_PEN_ADJUST_Y)
		pico_pen_y = 224 - PICO_PEN_ADJUST_Y;
	if (pico_pen_x < 0)
		pico_pen_x = 0;
	if (pico_pen_x > lim_x - PICO_PEN_ADJUST_X)
		pico_pen_x = lim_x - PICO_PEN_ADJUST_X;

	PicoPicohw.pen_pos[0] = pico_pen_x;
	if (!(Pico.video.reg[12] & 1))
		PicoPicohw.pen_pos[0] += pico_pen_x / 4;
	PicoPicohw.pen_pos[0] += 0x3c;
	PicoPicohw.pen_pos[1] = pico_inp_mode == 1 ? (0x2f8 + pico_pen_y) : (0x1fc + pico_pen_y);
}

static void do_turbo(int *pad, int acts)
{
	static int turbo_pad = 0;
	static unsigned char turbo_cnt[3] = { 0, 0, 0 };
	int inc = currentConfig.turbo_rate * 2;

	if (acts & 0x1000) {
		turbo_cnt[0] += inc;
		if (turbo_cnt[0] >= 60)
			turbo_pad ^= 0x10, turbo_cnt[0] = 0;
	}
	if (acts & 0x2000) {
		turbo_cnt[1] += inc;
		if (turbo_cnt[1] >= 60)
			turbo_pad ^= 0x20, turbo_cnt[1] = 0;
	}
	if (acts & 0x4000) {
		turbo_cnt[2] += inc;
		if (turbo_cnt[2] >= 60)
			turbo_pad ^= 0x40, turbo_cnt[2] = 0;
	}
	*pad |= turbo_pad & (acts >> 8);
}

static void run_events_ui(unsigned int which)
{
	if (which & (PEV_STATE_LOAD|PEV_STATE_SAVE))
	{
		int do_it = 1;
		if ( emu_check_save_file(state_slot, NULL) &&
			(((which & PEV_STATE_LOAD) && (currentConfig.confirm_save & EOPT_CONFIRM_LOAD)) ||
			 ((which & PEV_STATE_SAVE) && (currentConfig.confirm_save & EOPT_CONFIRM_SAVE))) )
		{
			const char *nm;
			char tmp[64];
			int keys, len;

			strcpy(tmp, (which & PEV_STATE_LOAD) ? "LOAD STATE? " : "OVERWRITE SAVE? ");
			len = strlen(tmp);
			nm = in_get_key_name(-1, -PBTN_MOK);
			snprintf(tmp + len, sizeof(tmp) - len, "(%s=yes, ", nm);
			len = strlen(tmp);
			nm = in_get_key_name(-1, -PBTN_MBACK);
			snprintf(tmp + len, sizeof(tmp) - len, "%s=no)", nm);

			plat_status_msg_busy_first(tmp);

			in_set_config_int(0, IN_CFG_BLOCKING, 1);
			while (in_menu_wait_any(NULL, 50) & (PBTN_MOK | PBTN_MBACK))
				;
			while ( !((keys = in_menu_wait_any(NULL, 50)) & (PBTN_MOK | PBTN_MBACK)))
				;
			if (keys & PBTN_MBACK)
				do_it = 0;
			while (in_menu_wait_any(NULL, 50) & (PBTN_MOK | PBTN_MBACK))
				;
			in_set_config_int(0, IN_CFG_BLOCKING, 0);
		}
		if (do_it) {
			plat_status_msg_busy_first((which & PEV_STATE_LOAD) ? "LOADING STATE" : "SAVING STATE");
			PicoStateProgressCB = plat_status_msg_busy_next;
			emu_save_load_game((which & PEV_STATE_LOAD) ? 1 : 0, 0);
			PicoStateProgressCB = NULL;
		}
	}
	if (which & PEV_SWITCH_RND)
	{
		plat_video_toggle_renderer(1, 0);
	}
	if (which & (PEV_SSLOT_PREV|PEV_SSLOT_NEXT))
	{
		if (which & PEV_SSLOT_PREV) {
			state_slot -= 1;
			if (state_slot < 0)
				state_slot = 9;
		} else {
			state_slot += 1;
			if (state_slot > 9)
				state_slot = 0;
		}

		emu_status_msg("SAVE SLOT %i [%s]", state_slot,
			emu_check_save_file(state_slot, NULL) ? "USED" : "FREE");
	}
	if (which & PEV_MENU)
		engineState = PGS_Menu;
}

void emu_update_input(void)
{
	static int prev_events = 0;
	int actions[IN_BINDTYPE_COUNT] = { 0, };
	int pl_actions[2];
	int events;

	in_update(actions);

	pl_actions[0] = actions[IN_BINDTYPE_PLAYER12];
	pl_actions[1] = actions[IN_BINDTYPE_PLAYER12] >> 16;

	PicoPad[0] = pl_actions[0] & 0xfff;
	PicoPad[1] = pl_actions[1] & 0xfff;

	if (pl_actions[0] & 0x7000)
		do_turbo(&PicoPad[0], pl_actions[0]);
	if (pl_actions[1] & 0x7000)
		do_turbo(&PicoPad[1], pl_actions[1]);

	events = actions[IN_BINDTYPE_EMU] & PEV_MASK;

	// volume is treated in special way and triggered every frame
	if (events & (PEV_VOL_DOWN|PEV_VOL_UP))
		plat_update_volume(1, events & PEV_VOL_UP);

	if ((events ^ prev_events) & PEV_FF) {
		emu_set_fastforward(events & PEV_FF);
		plat_update_volume(0, 0);
		reset_timing = 1;
	}

	events &= ~prev_events;

	if (PicoAHW == PAHW_PICO)
		run_events_pico(events);
	if (events)
		run_events_ui(events);
	if (movie_data)
		update_movie();

	prev_events = actions[IN_BINDTYPE_EMU] & PEV_MASK;
}

static void mkdir_path(char *path_with_reserve, int pos, const char *name)
{
	strcpy(path_with_reserve + pos, name);
	if (plat_is_dir(path_with_reserve))
		return;
	if (mkdir(path_with_reserve, 0777) < 0)
		lprintf("failed to create: %s\n", path_with_reserve);
}

void emu_cmn_forced_frame(int no_scale, int do_emu)
{
	int po_old = PicoOpt;

	memset32(g_screen_ptr, 0, g_screen_width * g_screen_height * 2 / 4);

	PicoOpt &= ~POPT_ALT_RENDERER;
	PicoOpt |= POPT_ACC_SPRITES;
	if (!no_scale)
		PicoOpt |= POPT_EN_SOFTSCALE;

	PicoDrawSetOutFormat(PDF_RGB555, 1);
	Pico.m.dirtyPal = 1;
	if (do_emu)
		PicoFrame();
	else
		PicoFrameDrawOnly();

	PicoOpt = po_old;
}

void emu_init(void)
{
	char path[512];
	int pos;

#if 0
	// FIXME: handle through menu, etc
	FILE *f;
	f = fopen("32X_M_BIOS.BIN", "rb");
	p32x_bios_m = malloc(2048);
	fread(p32x_bios_m, 1, 2048, f);
	fclose(f);
	f = fopen("32X_S_BIOS.BIN", "rb");
	p32x_bios_s = malloc(1024);
	fread(p32x_bios_s, 1, 1024, f);
	fclose(f);
#endif

	/* make dirs for saves */
	pos = plat_get_root_dir(path, sizeof(path) - 4);
	mkdir_path(path, pos, "mds");
	mkdir_path(path, pos, "srm");
	mkdir_path(path, pos, "brm");
	mkdir_path(path, pos, "cfg");

	pprof_init();

	make_config_cfg(path);
	config_readlrom(path);

	PicoInit();
	PicoMessage = plat_status_msg_busy_next;
	PicoMCDopenTray = emu_tray_open;
	PicoMCDcloseTray = emu_tray_close;

	sndout_init();
}

void emu_finish(void)
{
	// save SRAM
	if ((currentConfig.EmuOpt & EOPT_EN_SRAM) && SRam.changed) {
		emu_save_load_game(0, 1);
		SRam.changed = 0;
	}

	if (!(currentConfig.EmuOpt & EOPT_NO_AUTOSVCFG)) {
		char cfg[512];
		make_config_cfg(cfg);
		config_writelrom(cfg);
#ifdef __GP2X__
		sync();
#endif
	}

	pprof_finish();

	PicoExit();
	sndout_exit();
}

static void snd_write_nonblocking(int len)
{
	sndout_write_nb(PsndOut, len);
}

void emu_sound_start(void)
{
	PsndOut = NULL;

	if (currentConfig.EmuOpt & EOPT_EN_SOUND)
	{
		int is_stereo = (PicoOpt & POPT_EN_STEREO) ? 1 : 0;

		PsndRerate(Pico.m.frame_count ? 1 : 0);

		printf("starting audio: %i len: %i stereo: %i, pal: %i\n",
			PsndRate, PsndLen, is_stereo, Pico.m.pal);
		sndout_start(PsndRate, is_stereo);
		PicoWriteSound = snd_write_nonblocking;
		plat_update_volume(0, 0);
		memset(sndBuffer, 0, sizeof(sndBuffer));
		PsndOut = sndBuffer;
	}
}

void emu_sound_stop(void)
{
	sndout_stop();
}

void emu_sound_wait(void)
{
	sndout_wait();
}

static void emu_loop_prep(void)
{
	static int pal_old = -1;
	static int filter_old = -1;

	if (currentConfig.CPUclock != plat_target_cpu_clock_get())
		plat_target_cpu_clock_set(currentConfig.CPUclock);

	if (Pico.m.pal != pal_old) {
		plat_target_lcdrate_set(Pico.m.pal);
		pal_old = Pico.m.pal;
	}

	if (currentConfig.filter != filter_old) {
		plat_target_hwfilter_set(currentConfig.filter);
		filter_old = currentConfig.filter;
	}

	plat_target_gamma_set(currentConfig.gamma, 0);

	pemu_loop_prep();
}

/* our tick here is 1 us right now */
#define ms_to_ticks(x) (unsigned int)(x * 1000)
#define get_ticks() plat_get_ticks_us()

void emu_loop(void)
{
	int frames_done, frames_shown;	/* actual frames for fps counter */
	int target_frametime_x3;
	unsigned int timestamp_x3 = 0;
	unsigned int timestamp_aim_x3 = 0;
	unsigned int timestamp_fps_x3 = 0;
	char *notice_msg = NULL;
	char fpsbuff[24];
	int fskip_cnt = 0;

	fpsbuff[0] = 0;

	PicoLoopPrepare();

	plat_video_loop_prepare();
	emu_loop_prep();
	pemu_sound_start();

	/* number of ticks per frame */
	if (Pico.m.pal)
		target_frametime_x3 = 3 * ms_to_ticks(1000) / 50;
	else
		target_frametime_x3 = 3 * ms_to_ticks(1000) / 60;

	reset_timing = 1;
	frames_done = frames_shown = 0;

	/* loop with resync every 1 sec. */
	while (engineState == PGS_Running)
	{
		int skip = 0;
		int diff;

		pprof_start(main);

		if (reset_timing) {
			reset_timing = 0;
			plat_video_wait_vsync();
			timestamp_aim_x3 = get_ticks() * 3;
			timestamp_fps_x3 = timestamp_aim_x3;
			fskip_cnt = 0;
		}
		else if (currentConfig.EmuOpt & EOPT_NO_FRMLIMIT) {
			timestamp_aim_x3 = get_ticks() * 3;
		}

		timestamp_x3 = get_ticks() * 3;

		// show notice_msg message?
		if (notice_msg_time != 0)
		{
			static int noticeMsgSum;
			if (timestamp_x3 - ms_to_ticks(notice_msg_time) * 3
			     > ms_to_ticks(STATUS_MSG_TIMEOUT) * 3)
			{
				notice_msg_time = 0;
				plat_status_msg_clear();
				plat_video_flip();
				plat_status_msg_clear(); /* Do it again in case of double buffering */
				notice_msg = NULL;
			}
			else {
				int sum = noticeMsg[0] + noticeMsg[1] + noticeMsg[2];
				if (sum != noticeMsgSum) {
					plat_status_msg_clear();
					noticeMsgSum = sum;
				}
				notice_msg = noticeMsg;
			}
		}

		// second changed?
		if (timestamp_x3 - timestamp_fps_x3 >= ms_to_ticks(1000) * 3)
		{
#ifdef BENCHMARK
			static int bench = 0, bench_fps = 0, bench_fps_s = 0, bfp = 0, bf[4];
			if (++bench == 10) {
				bench = 0;
				bench_fps_s = bench_fps;
				bf[bfp++ & 3] = bench_fps;
				bench_fps = 0;
			}
			bench_fps += frames_shown;
			sprintf(fpsbuff, "%02i/%02i/%02i", frames_shown, bench_fps_s, (bf[0]+bf[1]+bf[2]+bf[3])>>2);
			printf("%s\n", fpsbuff);
#else
			if (currentConfig.EmuOpt & EOPT_SHOW_FPS)
				sprintf(fpsbuff, "%02i/%02i  ", frames_shown, frames_done);
#endif
			frames_shown = frames_done = 0;
			timestamp_fps_x3 += ms_to_ticks(1000) * 3;
		}
#ifdef PFRAMES
		sprintf(fpsbuff, "%i", Pico.m.frame_count);
#endif

		diff = timestamp_aim_x3 - timestamp_x3;

		if (currentConfig.Frameskip >= 0) // frameskip enabled (or 0)
		{
			if (fskip_cnt < currentConfig.Frameskip) {
				fskip_cnt++;
				skip = 1;
			}
			else {
				fskip_cnt = 0;
			}
		}
		else if (diff < -target_frametime_x3)
		{
			/* no time left for this frame - skip */
			/* limit auto frameskip to 8 */
			if (frames_done / 8 <= frames_shown)
				skip = 1;
		}

		// don't go in debt too much
		while (diff < -target_frametime_x3 * 3) {
			timestamp_aim_x3 += target_frametime_x3;
			diff = timestamp_aim_x3 - timestamp_x3;
		}

		emu_update_input();
		if (skip) {
			int do_audio = diff > -target_frametime_x3 * 2;
			PicoSkipFrame = do_audio ? 1 : 2;
			PicoFrame();
			PicoSkipFrame = 0;
		}
		else {
			PicoFrame();
			pemu_finalize_frame(fpsbuff, notice_msg);
			frames_shown++;
		}
		frames_done++;
		timestamp_aim_x3 += target_frametime_x3;

		if (!skip && !flip_after_sync)
			plat_video_flip();

		/* frame limiter */
		if (!skip && !reset_timing
		    && !(currentConfig.EmuOpt & (EOPT_NO_FRMLIMIT|EOPT_EXT_FRMLIMIT)))
		{
			unsigned int timestamp = get_ticks();
			diff = timestamp_aim_x3 - timestamp * 3;

			// sleep or vsync if we are still too fast
			if (diff > target_frametime_x3 && (currentConfig.EmuOpt & EOPT_VSYNC)) {
				// we are too fast
				plat_video_wait_vsync();
				timestamp = get_ticks();
				diff = timestamp * 3 - timestamp_aim_x3;
			}
			if (diff > target_frametime_x3) {
				// still too fast
				plat_wait_till_us(timestamp + (diff - target_frametime_x3) / 3);
			}
		}

		if (!skip && flip_after_sync)
			plat_video_flip();

		pprof_end(main);
	}

	emu_set_fastforward(0);

	// save SRAM
	if ((currentConfig.EmuOpt & EOPT_EN_SRAM) && SRam.changed) {
		plat_status_msg_busy_first("Writing SRAM/BRAM...");
		emu_save_load_game(0, 1);
		SRam.changed = 0;
	}

	pemu_loop_end();
	emu_sound_stop();
}
