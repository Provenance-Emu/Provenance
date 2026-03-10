/*
 * PicoDrive
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#ifdef __cplusplus
extern "C" {
#endif

#define array_size(x) (sizeof(x) / sizeof(x[0]))

extern void *g_screen_ptr;

extern int g_screen_width;
extern int g_screen_height;
extern int g_screen_ppitch; // pitch in pixels

#define EOPT_EN_SRAM      (1<<0)
#define EOPT_SHOW_FPS     (1<<1)
#define EOPT_EN_SOUND     (1<<2)
#define EOPT_GZIP_SAVES   (1<<3)
#define EOPT_NO_AUTOSVCFG (1<<5)
#define EOPT_16BPP        (1<<7)  // depreceted for .renderer
#define EOPT_EN_CD_LEDS   (1<<10)
#define EOPT_A_SN_GAMMA   (1<<12)
#define EOPT_VSYNC        (1<<13)
#define EOPT_GIZ_SCANLN   (1<<14)
#define EOPT_GIZ_DBLBUF   (1<<15)
#define EOPT_VSYNC_MODE   (1<<16)
#define EOPT_SHOW_RTC     (1<<17)
#define EOPT_NO_FRMLIMIT  (1<<18)
#define EOPT_WIZ_TEAR_FIX (1<<19)
#define EOPT_EXT_FRMLIMIT (1<<20) // no internal frame limiter (limited by snd, etc)
#define EOPT_PICO_PEN     (1<<21)

enum {
	EOPT_SCALE_NONE = 0,
	// linux, GP2X:
	EOPT_SCALE_SW = 1,
	EOPT_SCALE_HW,
	// PSP horiz:
	EOPT_SCALE_43 = 1,	// 4:3 screen
	EOPT_SCALE_STRETCH,	// stretched to between _43 and _WIDE
	EOPT_SCALE_WIDE,	// stretched to match display width
	// PSP vert:
	EOPT_VSCALE_FULL = 1,	// TV height scaled to screen height
	EOPT_VSCALE_NOBORDER,	// VDP area scaled to screen height
};

enum {
	EOPT_FILTER_NONE = 0,
	// PSP texture filtering
	EOPT_FILTER_BILINEAR = 1,
	// software scalers
	EOPT_FILTER_SMOOTHER = 1,
	EOPT_FILTER_BILINEAR1,
	EOPT_FILTER_BILINEAR2,
};

enum {
	EOPT_CONFIRM_NONE = 0,
	EOPT_CONFIRM_SAVE = 1,
	EOPT_CONFIRM_LOAD = 2,
	EOPT_CONFIRM_BOTH = 3,
};

typedef struct _currentConfig_t {
	int EmuOpt;
	int s_PicoOpt;
	int s_PsndRate;
	int s_PicoRegion;
	int s_PicoAutoRgnOrder;
	int s_hwSelect;
	int s_PicoCDBuffers;
	int s_PicoSndFilterAlpha;
	int Frameskip;
	int input_dev0;
	int input_dev1;
	int confirm_save;
	int CPUclock;
	int volume;
	int gamma;
	int scaling;  // EOPT_SCALE_*
	int vscaling;
	int rotation; // for UIQ
	int gamma2;  // psp: black level
	int turbo_rate;
	int renderer;
	int renderer32x;
	int filter;  // EOPT_FILTER_* video filter
	int ghosting;
	int analog_deadzone;
	int keyboard;
	int msh2_khz;
	int ssh2_khz;
	int overclock_68k;
	int max_skip;
} currentConfig_t;

extern currentConfig_t currentConfig, defaultConfig;
extern const char *PicoConfigFile;
extern int state_slot;
extern int config_slot, config_slot_current;
extern unsigned char *movie_data;
extern int reset_timing;
extern int flip_after_sync;
extern int kbd_mode;
extern struct vkbd *vkbd;

#define PICO_PEN_ADJUST_X 1
#define PICO_PEN_ADJUST_Y 1
extern int pico_pen_x, pico_pen_y;
extern int pico_inp_mode;

extern const char *rom_fname_reload;		// ROM to try loading on next PGS_ReloadRom
extern char rom_fname_loaded[512];		// currently loaded ROM filename

// engine states
extern int engineState;
enum TPicoGameState {
	PGS_Paused = 1,
	PGS_Running,
	PGS_Quit,
	PGS_KeyConfig,
	PGS_ReloadRom,
	PGS_Menu,
	PGS_TrayMenu,
	PGS_RestartRun,
	PGS_Suspending,		/* PSP */
	PGS_SuspendWake,	/* PSP */
};

void  emu_init(void);
void  emu_finish(void);
void  emu_loop(void);

int   emu_reload_rom(const char *rom_fname_in);
int   emu_swap_cd(const char *fname);
int   emu_play_tape(const char *fname);
int   emu_record_tape(const char *ext);
int   emu_save_load_game(int load, int sram);
void  emu_reset_game(void);

void  emu_prep_defconfig(void);
void  emu_set_defconfig(void);
int   emu_read_config(const char *rom_fname, int no_defaults);
int   emu_write_config(int game);

char *emu_get_save_fname(int load, int is_sram, int slot, int *time);
int   emu_check_save_file(int slot, int *time);

void  emu_text_out8 (int x, int y, const char *text);
void  emu_text_out16(int x, int y, const char *text);
void  emu_text_out8_rot (int x, int y, const char *text);
void  emu_text_out16_rot(int x, int y, const char *text);

void  emu_osd_text16(int x, int y, const char *text);

void  emu_make_path(char *buff, const char *end, int size);
void  emu_update_input(void);
void  emu_get_game_name(char *str150);
void  emu_set_fastforward(int set_on);
void  emu_status_msg(const char *format, ...);

void  emu_pico_overlay(unsigned short *pd, int w, int h, int pitch);

/* default sound code */
void  emu_sound_start(void);
void  emu_sound_stop(void);
void  emu_sound_wait(void);

/* used by some (but not all) platforms */
void  emu_cmn_forced_frame(int no_scale, int do_emu, void *buf);

/* stuff to be implemented by platform code */
extern const char *renderer_names[];
extern const char *renderer_names32x[];

void pemu_prep_defconfig(void);
void pemu_validate_config(void);
void pemu_loop_prep(void);
void pemu_loop_end(void);
void pemu_forced_frame(int no_scale, int do_emu); // ..to g_menubg_src_ptr
void pemu_finalize_frame(const char *fps, const char *notice_msg);

void pemu_sound_start(void);

int plat_parse_arg(int argc, char *argv[], int *x);
void plat_early_init(void);
void plat_init(void);
void plat_finish(void);

/* used before things blocking for a while (these funcs redraw on return) */
void plat_status_msg_busy_first(const char *msg);
void plat_status_msg_busy_next(const char *msg);
void plat_status_msg_busy_done(void);
void plat_status_msg_clear(void);

void plat_video_toggle_renderer(int change, int menu_call);
void plat_video_loop_prepare(void);
void plat_video_set_buffer(void *);

void plat_update_volume(int has_changed, int is_up);

/* should be in libpicofe/plat.h */
void plat_video_clear_status(void);
void plat_video_clear_buffers(void);
void plat_video_set_size(int w, int h);
void plat_video_set_shadow(int w, int h);

#ifdef __cplusplus
} // extern "C"
#endif

