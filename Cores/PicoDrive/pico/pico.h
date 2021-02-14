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

#include <stdlib.h> // size_t

#ifdef __cplusplus
extern "C" {
#endif

// message log
extern void lprintf(const char *fmt, ...);

// external funcs for Sega/Mega CD
extern int  mp3_get_bitrate(void *f, int size);
extern void mp3_start_play(void *f, int pos);
extern void mp3_update(int *buffer, int length, int stereo);

// this function should write-back d-cache and invalidate i-cache
// on a mem region [start_addr, end_addr)
// used by dynarecs
extern void cache_flush_d_inval_i(void *start_addr, void *end_addr);

// attempt to alloc mem at specified address.
// alloc anywhere else if that fails (callers should handle that)
extern void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed);
extern void *plat_mremap(void *ptr, size_t oldsize, size_t newsize);
extern void  plat_munmap(void *ptr, size_t size);
extern int   plat_mem_set_exec(void *ptr, size_t size);

// this one should handle display mode changes
extern void emu_video_mode_change(int start_line, int line_count, int is_32cols);

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
// unused                   (1<< 5)
// unused                   (1<< 6)
#define POPT_ACC_SPRITES    (1<< 7)
#define POPT_DIS_32C_BORDER (1<< 8) // 00 0x00
#define POPT_EXT_FM         (1<< 9)
#define POPT_EN_MCD_PCM     (1<<10)
#define POPT_EN_MCD_CDDA    (1<<11)
#define POPT_EN_MCD_GFX     (1<<12) // 00 x000
// unused                   (1<<13)
#define POPT_EN_SOFTSCALE   (1<<14)
#define POPT_EN_MCD_RAMCART (1<<15)
#define POPT_DIS_VDP_FIFO   (1<<16) // 0x 0000
#define POPT_EN_DRC         (1<<17)
#define POPT_DIS_SPRITE_LIM (1<<18)
#define POPT_DIS_IDLE_DET   (1<<19)
#define POPT_EN_32X         (1<<20)
#define POPT_EN_PWM         (1<<21)
extern int PicoOpt; // bitfield

#define PAHW_MCD  (1<<0)
#define PAHW_32X  (1<<1)
#define PAHW_SVP  (1<<2)
#define PAHW_PICO (1<<3)
#define PAHW_SMS  (1<<4)
extern int PicoAHW;            // Pico active hw

#define PQUIRK_FORCE_6BTN   (1<<0)
extern int PicoQuirks;

extern int PicoSkipFrame;      // skip rendering frame, but still do sound (if enabled) and emulation stuff
extern int PicoRegionOverride; // override the region detection 0: auto, 1: Japan NTSC, 2: Japan PAL, 4: US, 8: Europe
extern int PicoAutoRgnOrder;   // packed priority list of regions, for example 0x148 means this detection order: EUR, USA, JAP
extern int PicoSVPCycles;
void PicoInit(void);
void PicoExit(void);
void PicoPower(void);
int  PicoReset(void);
void PicoLoopPrepare(void);
void PicoFrame(void);
void PicoFrameDrawOnly(void);
extern int PicoPad[2]; // Joypads, format is MXYZ SACB RLDU
extern void (*PicoWriteSound)(int bytes); // called once per frame at the best time to send sound buffer (PsndOut) to hardware
extern void (*PicoMessage)(const char *msg); // callback to output text message from emu
typedef enum { PI_ROM, PI_ISPAL, PI_IS40_CELL, PI_IS240_LINES } pint_t;
typedef union { int vint; void *vptr; } pint_ret_t;
void PicoGetInternal(pint_t which, pint_ret_t *ret);

// cd/mcd.c
extern void (*PicoMCDopenTray)(void);
extern void (*PicoMCDcloseTray)(void);

// pico.c
#define XPCM_BUFFER_SIZE (320+160)
typedef struct
{
	int pen_pos[2];
	int page;
	// internal
	int fifo_bytes;      // bytes in FIFO
	int fifo_bytes_prev;
	int fifo_line_bytes; // float part, << 16
	int line_counter;
	unsigned short r1, r12;
	unsigned char xpcm_buffer[XPCM_BUFFER_SIZE+4];
	unsigned char *xpcm_ptr;
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
	PMT_CSO
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
size_t   pm_read(void *ptr, size_t bytes, pm_file *stream);
int      pm_seek(pm_file *stream, long offset, int whence);
int      pm_close(pm_file *fp);
int PicoCartLoad(pm_file *f,unsigned char **prom,unsigned int *psize,int is_sms);
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
extern void *DrawLineDest;
extern unsigned char *HighCol;
// utility
#ifdef _ASM_DRAW_C
void vidConvCpyRGB565(void *to, void *from, int pixels);
#endif
void PicoDoHighPal555(int sh);
extern int PicoDrawMask;
#define PDRAW_LAYERB_ON      (1<<2)
#define PDRAW_LAYERA_ON      (1<<3)
#define PDRAW_SPRITES_LOW_ON (1<<4)
#define PDRAW_SPRITES_HI_ON  (1<<7)
#define PDRAW_32X_ON         (1<<8)
// internals
#define PDRAW_SPRITES_MOVED (1<<0) // (asm)
#define PDRAW_WND_DIFF_PRIO (1<<1) // not all window tiles use same priority
#define PDRAW_SPR_LO_ON_HI  (1<<2) // seen sprites without layer pri bit ontop spr. with that bit
#define PDRAW_INTERLACE     (1<<3)
#define PDRAW_DIRTY_SPRITES (1<<4) // (asm)
#define PDRAW_SONIC_MODE    (1<<5) // mid-frame palette changes for 8bit renderer
#define PDRAW_PLANE_HI_PRIO (1<<6) // have layer with all hi prio tiles (mk3)
#define PDRAW_SHHI_DONE     (1<<7) // layer sh/hi already processed
#define PDRAW_32_COLS       (1<<8) // 32 column mode
extern int rendstatus, rendstatus_old;
extern int rendlines;
extern unsigned short HighPal[0x100];

// draw.c
void PicoDrawUpdateHighPal(void);
void PicoDrawSetInternalBuf(void *dest, int line_increment);

// draw2.c
// stuff below is optional
extern unsigned char  *PicoDraw2FB;  // buffer for fast renderer in format (8+320)x(8+224+8) (eights for borders)
extern unsigned short *PicoCramHigh; // pointer to CRAM buff (0x40 shorts), converted to native device color (works only with 16bit for now)
extern void (*PicoPrepareCram)();    // prepares PicoCramHigh for renderer to use

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
extern int PsndRate,PsndLen;
extern short *PsndOut;
extern void (*PsndMix_32_to_16l)(short *dest, int *src, int count);
void PsndRerate(int preserve_state);

// media.c
enum media_type_e {
  PM_BAD_DETECT = -1,
  PM_ERROR = -2,
  PM_BAD_CD = -3,
  PM_BAD_CD_NO_BIOS = -4,
  PM_MD_CART = 1,	/* also 32x */
  PM_MARK3,
  PM_CD,
};

enum cd_img_type
{
  CIT_NOT_CD = 0,
  CIT_ISO,
  CIT_BIN,
  CIT_CUE
};

enum media_type_e PicoLoadMedia(const char *filename,
  const char *carthw_cfg_fname,
  const char *(*get_bios_filename)(int *region, const char *cd_fname),
  void (*do_region_override)(const char *media_filename));
int PicoCdCheck(const char *fname_in, int *pregion);

extern unsigned char media_id_header[0x100];

// memory.c
enum input_device {
  PICO_INPUT_NOTHING,
  PICO_INPUT_PAD_3BTN,
  PICO_INPUT_PAD_6BTN,
};
void PicoSetInputDevice(int port, enum input_device device);

#ifdef __cplusplus
} // End of extern "C"
#endif

#endif // PICO_H
