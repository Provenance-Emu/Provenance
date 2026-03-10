/*
 * PicoDrive
 * (c) Copyright Dave, 2004
 * (C) notaz, 2006-2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#ifndef PICO_H
#define PICO_H

#include <stdint.h> // [u]int<n>_t
#include <stdlib.h> // size_t

#ifdef __cplusplus
extern "C" {
#endif

// message log
extern void lprintf(const char *fmt, ...);

// external funcs for Sega/Mega CD
extern int  mp3_get_bitrate(void *f, int size);
extern void mp3_start_play(void *f, int pos);
extern void mp3_update(s32 *buffer, int length, int stereo);

// this function should write-back d-cache and invalidate i-cache
// on a mem region [start_addr, end_addr)
// used by dynarecs
extern void cache_flush_d_inval_i(void *start_addr, void *end_addr);

// attempt to alloc mem at specified address.
// alloc anywhere else if that fails (callers should handle that)
extern void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed);
extern void *plat_mremap(void *ptr, size_t oldsize, size_t newsize);
extern void  plat_munmap(void *ptr, size_t size);

// memory for the dynarec; plat_mem_get_for_drc() can just return NULL
extern void *plat_mem_get_for_drc(size_t size);
extern int   plat_mem_set_exec(void *ptr, size_t size);

// this one should handle display mode changes
extern void emu_video_mode_change(int start_line, int line_count, int start_col, int col_count);

// this must switch to 16bpp mode
extern void emu_32x_startup(void);

// optional 32X BIOS, should be left NULL if not used
// must be 256, 2048, 1024 bytes
extern void *p32x_bios_g, *p32x_bios_m, *p32x_bios_s;

// Pico.c
#define POPT_EN_FM          (1<< 0) // 00 000x
#define POPT_EN_PSG         (1<< 1)
#define POPT_EN_Z80         (1<< 2)
#define POPT_EN_STEREO      (1<< 3)
#define POPT_ALT_RENDERER   (1<< 4) // 00 00x0
#define POPT_EN_YM2413      (1<< 5)
#define POPT_EN_SNDFILTER   (1<< 6)
#define POPT_ACC_SPRITES    (1<< 7)
#define POPT_DIS_32C_BORDER (1<< 8) // 00 0x00
#define POPT_EXT_FM         (1<< 9)
#define POPT_EN_MCD_PCM     (1<<10)
#define POPT_EN_MCD_CDDA    (1<<11)
#define POPT_EN_MCD_GFX     (1<<12) // 00 x000
#define POPT_EN_GG_LCD      (1<<13)
#define POPT_EN_SOFTSCALE   (1<<14)
#define POPT_EN_MCD_RAMCART (1<<15)
#define POPT_DIS_VDP_FIFO   (1<<16) // 0x 0000
#define POPT_EN_DRC         (1<<17)
#define POPT_DIS_SPRITE_LIM (1<<18)
#define POPT_DIS_IDLE_DET   (1<<19)
#define POPT_EN_32X         (1<<20) // x0 0000
#define POPT_EN_PWM         (1<<21)
#define POPT_PWM_IRQ_OPT    (1<<22)
#define POPT_DIS_FM_SSGEG   (1<<23)
#define POPT_EN_FM_DAC      (1<<24) //x00 0000
#define POPT_EN_FM_FILTER   (1<<25)
#define POPT_EN_KBD         (1<<26)

#define PAHW_MCD    (1<<0)
#define PAHW_32X    (1<<1)
#define PAHW_SVP    (1<<2)
#define PAHW_PICO   (1<<3)

#define PAHW_SMS    (1<<4)
#define PAHW_GG     (1<<5)
#define PAHW_SG     (1<<6)
#define PAHW_SC     (1<<7)
#define PAHW_8BIT   (PAHW_SMS|PAHW_GG|PAHW_SG|PAHW_SC)

#define PHWS_AUTO   0
#define PHWS_GG     1
#define PHWS_SMS    2
#define PHWS_SG     3
#define PHWS_SC     4

#define PQUIRK_FORCE_6BTN       (1<<0)
#define PQUIRK_BLACKTHORNE_HACK (1<<1)
#define PQUIRK_WWFRAW_HACK      (1<<2)
#define PQUIRK_MARSCHECK_HACK   (1<<3)
#define PQUIRK_NO_Z80_BUS_LOCK  (1<<4)

// the emulator is configured and some status is reported
// through this global state (not saved in savestates)
typedef struct PicoInterface
{
	unsigned int opt; // POPT_* bitfield

	unsigned short pad[4];     // Joypads, format is MXYZ SACB RLDU
	unsigned short padInt[4];  // internal copy
	unsigned short AHW;        // active addon hardware: PAHW_* bitfield

	unsigned short skipFrame;      // skip rendering frame, but still do sound (if enabled) and emulation stuff
	unsigned short regionOverride; // override the region detection 0: auto, 1: Japan NTSC, 2: Japan PAL, 4: US, 8: Europe
	unsigned short autoRgnOrder;   // packed priority list of regions, for example 0x148 means this detection order: EUR, USA, JAP
	unsigned int hwSelect;         // hardware preselected via option menu
	unsigned int mapper;           // mapper selection for SMS, 0 = auto
	unsigned int tmsPalette;       // palette used by SMS in TMS graphic modes

	unsigned short quirks;         // game-specific quirks: PQUIRK_*
	unsigned short overclockM68k;  // overclock the emulated 68k, in %

	unsigned short filter;         // softscale filter type

	int sndRate;                   // rate in Hz
	int sndFilterAlpha;            // Low pass sound filter alpha (Q16)
	short *sndOut;                 // PCM output buffer
	void (*writeSound)(int len);   // write .sndOut callback, called once per frame

	void (*osdMessage)(const char *msg); // output OSD message from emu, optional

	void (*mcdTrayOpen)(void);
	void (*mcdTrayClose)(void);

	unsigned int kbd;   // PS/2 peripherals, e.g. Pico Keyboard
} PicoInterface;

extern PicoInterface PicoIn;

void PicoInit(void);
void PicoExit(void);
void PicoPower(void);
int  PicoReset(void);
void PicoLoopPrepare(void);
void PicoFrame(void);
void PicoFrameDrawOnly(void);
typedef enum { PI_ROM, PI_ISPAL, PI_IS40_CELL, PI_IS240_LINES } pint_t;
typedef union { int vint; void *vptr; } pint_ret_t;
void PicoGetInternal(pint_t which, pint_ret_t *ret);

struct PicoEState;

// pico.c
#define XPCM_BUFFER_SIZE 64
enum {
  PKEY_RELEASED = 0,
  PKEY_DOWN,
  PKEY_UP,
};
enum {
  PSHIFT_RELEASED = 0,
  PSHIFT_DOWN,
  PSHIFT_UP_HELD_DOWN,
  PSHIFT_RELEASED_HELD_DOWN,
  PSHIFT_UP
};
typedef struct
{
    uint8_t i;
    uint8_t mode;
    uint8_t neg;
    uint8_t has_read;
    uint8_t caps_lock;
    uint8_t has_caps_lock;
    uint32_t mem;
    uint64_t start_time_keydown;
    uint64_t time_keydown;
    uint8_t key_state;
    uint8_t shift_state;
    uint8_t active;
} picohw_kb;
typedef struct
{
	int pen_pos[2];
	int page;
	int fifo_bytes;      // bytes in FIFO
	unsigned short r1, r12;
	unsigned int reserved[3];
	unsigned char xpcm_buffer[XPCM_BUFFER_SIZE+4];
	unsigned char *xpcm_ptr;
	picohw_kb kb;
} picohw_state;
extern picohw_state PicoPicohw;

// area.c
int PicoState(const char *fname, int is_save);
int PicoStateLoadGfx(const char *fname);
void *PicoTmpStateSave(void);
void  PicoTmpStateRestore(void *data);
extern void (*PicoStateProgressCB)(const char *str);

// cd/cdd.c
int cdd_load(const char *filename, int type);
int cdd_unload(void);

// Cart.c
typedef enum
{
	PMT_UNCOMPRESSED = 0,
	PMT_ZIP,
	PMT_CSO,
	PMT_CHD
} pm_type;
typedef struct
{
	void *file;		/* file handle */
	void *param;		/* additional file related field */
	unsigned int size;	/* size */
	pm_type type;
	char ext[4];
} pm_file;
pm_file *pm_open(const char *path);
void     pm_sectorsize(int length, pm_file *stream);
size_t   pm_read(void *ptr, size_t bytes, pm_file *stream);
size_t   pm_read_audio(void *ptr, size_t bytes, pm_file *stream);
int      pm_seek(pm_file *stream, long offset, int whence);
int      pm_close(pm_file *fp);
int PicoCartLoad(pm_file *f, const unsigned char *rom, unsigned int romsize,
  unsigned char **prom, unsigned int *psize, int is_sms);
int PicoCartInsert(unsigned char *rom, unsigned int romsize, const char *carthw_cfg);
void PicoCartUnload(void);
extern void (*PicoCartLoadProgressCB)(int percent);
extern void (*PicoCDLoadProgressCB)(const char *fname, int percent);
extern int PicoGameLoaded;

// Draw.c
// for line-based renderer, set conversion
// from internal 8 bit representation in 'HighCol' to:
typedef enum
{
	PDF_NONE = 0,    // no conversion
	PDF_RGB555,      // RGB/BGR output, depends on compile options
	PDF_8BIT,        // 8-bit out (handles shadow/hilight mode, sonic water)
} pdso_t;
void PicoDrawSetOutFormat(pdso_t which, int use_32x_line_mode);
void PicoDrawSetOutBuf(void *dest, int increment);
void PicoDrawSetCallbacks(int (*begin)(unsigned int num), int (*end)(unsigned int num));
// utility
#ifdef _ASM_DRAW_C
void vidConvCpyRGB565(void *to, void *from, int pixels);
#endif
void PicoDoHighPal555(int sh, int line, struct PicoEState *est);
// internals, NB must keep in sync with ASM draw functions
#define PDRAW_WND_DIFF_PRIO (1<<1) // not all window tiles use same priority
#define PDRAW_PARSE_SPRITES (1<<2) // SAT needs parsing
#define PDRAW_INTERLACE     (1<<3)
#define PDRAW_DIRTY_SPRITES (1<<4) // SAT modified
#define PDRAW_SONIC_MODE    (1<<5) // mid-frame palette changes for 8bit renderer
#define PDRAW_PLANE_HI_PRIO (1<<6) // have layer with all hi prio tiles (mk3)
#define PDRAW_SHHI_DONE     (1<<7) // layer sh/hi already processed
#define PDRAW_32_COLS       (1<<8) // 32 columns mode
#define PDRAW_BORDER_32     (1<<9) // center H32 in buffer (32 px border)
#define PDRAW_SKIP_FRAME   (1<<10) // frame is skipped
#define PDRAW_30_ROWS      (1<<11) // 30 rows mode (240 lines)
#define PDRAW_32X_SCALE    (1<<12) // scale CLUT layer for 32X
#define PDRAW_SMS_BLANK_1  (1<<13) // 1st column blanked
#define PDRAW_BGC_DMA      (1<<14) // in background color DMA
#define PDRAW_SOFTSCALE    (1<<15) // H32 upscaling
#define PDRAW_SYNC_NEEDED  (1<<16) // redraw needed
#define PDRAW_SYNC_NEXT    (1<<17) // redraw next frame
extern int rendstatus_old;
extern int rendlines;

// draw.c
void PicoDrawUpdateHighPal(void);
void PicoDrawSetInternalBuf(void *dest, int line_increment);

// draw2.c
// stuff below is optional
extern unsigned short *PicoCramHigh; // pointer to CRAM buff (0x40 shorts), converted to native device color (works only with 16bit for now)
extern void (*PicoPrepareCram)(void);// prepares PicoCramHigh for renderer to use

// pico.c (32x)
#ifndef NO_32X

void Pico32xSetClocks(int msh2_hz, int ssh2_hz);

#else

#define Pico32xSetClocks(msh2_khz, ssh2_khz)

#endif

// normally 68k clock (7670442) * 3, in reality but much lower
// because of high memory latencies
#define PICO_MSH2_HZ ((int)(7670442.0 * 2.4))
#define PICO_SSH2_HZ ((int)(7670442.0 * 2.4))

// sound.c
extern void (*PsndMix_32_to_16)(s16 *dest, s32 *src, int count);
void PsndRerate(int preserve_state);

// media.c
enum media_type_e {
  PM_BAD_DETECT = -1,
  PM_ERROR = -2,
  PM_BAD_CD = -3,
  PM_BAD_CD_NO_BIOS = -4,
  PM_MD_CART = 1,	/* also 32x */
  PM_MARK3,
  PM_PICO,
  PM_CD,
};

enum cd_track_type
{
  CT_UNKNOWN = 0,
  // data tracks
  CT_ISO = 1,	/* 2048 B/sector */
  CT_BIN = 2,	/* 2352 B/sector */
  // audio tracks
  CT_AUDIO = 8,
  CT_RAW = CT_AUDIO | 1,
  CT_CHD = CT_AUDIO | 2,
  CT_MP3 = CT_AUDIO | 3,
  CT_WAV = CT_AUDIO | 4,
};

typedef struct
{
	char *fname;
	int pregap;		/* pregap for current track */
	int sector_offset;	/* in current file */
	int sector_xlength;
	int loop, loop_lba;	/* MEGASD extensions */
	enum cd_track_type type;
} cd_track_t;

typedef struct
{
	int track_count;
	cd_track_t tracks[0];
} cd_data_t;


enum media_type_e PicoLoadMedia(const char *filename,
  const unsigned char *rom, unsigned int romsize,
  const char *carthw_cfg_fname,
  const char *(*get_bios_filename)(int *region, const char *cd_fname),
  const char *(*get_msu_filename)(const char *cd_fname),
  void (*do_region_override)(const char *media_filename));
int PicoCdCheck(const char *fname_in, int *pregion);

extern unsigned char media_id_header[0x100];

// memory.c
enum input_device {
  PICO_INPUT_NOTHING,
  PICO_INPUT_PAD_3BTN,
  PICO_INPUT_PAD_6BTN,
  PICO_INPUT_PAD_TEAM,
  PICO_INPUT_PAD_4WAY,
};
void PicoSetInputDevice(int port, enum input_device device);

#ifdef __cplusplus
} // End of extern "C"
#endif

#endif // PICO_H
