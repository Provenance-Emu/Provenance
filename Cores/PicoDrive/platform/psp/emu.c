/*
 * PicoDrive
 * (C) notaz, 2007,2008
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/syslimits.h> // PATH_MAX

#include <pspthreadman.h>
#include <pspdisplay.h>
#include <psputils.h>
#include <pspgu.h>
#include <pspaudio.h>

#include "psp.h"
#include "menu.h"
#include "emu.h"
#include "mp3.h"
#include "asm_utils.h"
#include "../common/emu.h"
#include "../common/config.h"
#include "../common/lprintf.h"
#include <pico/pico_int.h>
#include <pico/cd/cue.h>

#define OSD_FPS_X 432

// additional pspaudio imports, credits to crazyc
int sceAudio_38553111(unsigned short samples, unsigned short freq, char unknown);  // play with conversion?
int sceAudio_5C37C0AE(void);				// end play?
int sceAudio_E0727056(int volume, void *buffer);	// blocking output
int sceAudioOutput2GetRestSample();


//unsigned char *PicoDraw2FB = (unsigned char *)VRAM_CACHED_STUFF + 8; // +8 to be able to skip border with 1 quadword..
int engineStateSuspend;

#define PICO_PEN_ADJUST_X 4
#define PICO_PEN_ADJUST_Y 2
static int pico_pen_x = 320/2, pico_pen_y = 240/2;

static void sound_init(void);
static void sound_deinit(void);
static void blit2(const char *fps, const char *notice, int lagging_behind);
static void clearArea(int full);

int plat_get_root_dir(char *dst, int len)
{
	if (len > 0) *dst = 0;
	return 0;
}

static void osd_text(int x, const char *text, int is_active, int clear_all)
{
	unsigned short *screen = is_active ? psp_video_get_active_fb() : psp_screen;
	int len = clear_all ? (480 / 2) : (strlen(text) * 8 / 2);
	int *p, h;
	void *tmp;
	for (h = 0; h < 8; h++) {
		p = (int *) (screen+x+512*(264+h));
		p = (int *) ((int)p & ~3); // align
		memset32_uncached(p, 0, len);
	}
	if (is_active) { tmp = psp_screen; psp_screen = screen; } // nasty pointer tricks
	emu_text_out16(x, 264, text);
	if (is_active) psp_screen = tmp;
}

void emu_msg_cb(const char *msg)
{
	osd_text(4, msg, 1, 1);
	noticeMsgTime = sceKernelGetSystemTimeLow() - 2000000;

	/* assumption: emu_msg_cb gets called only when something slow is about to happen */
	reset_timing = 1;
}

/* FIXME: move to plat */
void emu_Init(void)
{
	sound_init();
}

void emu_Deinit(void)
{
	sound_deinit();
}

void pemu_prep_defconfig(void)
{
	defaultConfig.s_PsndRate = 22050;
	defaultConfig.s_PicoCDBuffers = 64;
	defaultConfig.CPUclock = 333;
	defaultConfig.KeyBinds[ 4] = 1<<0; // SACB RLDU
	defaultConfig.KeyBinds[ 6] = 1<<1;
	defaultConfig.KeyBinds[ 7] = 1<<2;
	defaultConfig.KeyBinds[ 5] = 1<<3;
	defaultConfig.KeyBinds[14] = 1<<4;
	defaultConfig.KeyBinds[13] = 1<<5;
	defaultConfig.KeyBinds[15] = 1<<6;
	defaultConfig.KeyBinds[ 3] = 1<<7;
	defaultConfig.KeyBinds[12] = 1<<26; // switch rnd
	defaultConfig.KeyBinds[ 8] = 1<<27; // save state
	defaultConfig.KeyBinds[ 9] = 1<<28; // load state
	defaultConfig.KeyBinds[28] = 1<<0; // num "buttons"
	defaultConfig.KeyBinds[30] = 1<<1;
	defaultConfig.KeyBinds[31] = 1<<2;
	defaultConfig.KeyBinds[29] = 1<<3;
	defaultConfig.scaling = 1;     // bilinear filtering for psp
	defaultConfig.scale = 1.20;    // fullscreen
	defaultConfig.hscale40 = 1.25;
	defaultConfig.hscale32 = 1.56;
}


extern void amips_clut(unsigned short *dst, unsigned char *src, unsigned short *pal, int count);
extern void amips_clut_6bit(unsigned short *dst, unsigned char *src, unsigned short *pal, int count);

static void (*amips_clut_f)(unsigned short *dst, unsigned char *src, unsigned short *pal, int count) = NULL;

struct Vertex
{
	short u,v;
	short x,y,z;
};

static struct Vertex __attribute__((aligned(4))) g_vertices[2];
static unsigned short __attribute__((aligned(16))) localPal[0x100];
static int dynamic_palette = 0, need_pal_upload = 0, blit_16bit_mode = 0;
static int fbimg_offs = 0;

static void set_scaling_params(void)
{
	int src_width, fbimg_width, fbimg_height, fbimg_xoffs, fbimg_yoffs, border_hack = 0;
	g_vertices[0].x = g_vertices[0].y =
	g_vertices[0].z = g_vertices[1].z = 0;

	fbimg_height = (int)(240.0 * currentConfig.scale + 0.5);
	if (Pico.video.reg[12] & 1) {
		fbimg_width = (int)(320.0 * currentConfig.scale * currentConfig.hscale40 + 0.5);
		src_width = 320;
	} else {
		fbimg_width = (int)(256.0 * currentConfig.scale * currentConfig.hscale32 + 0.5);
		src_width = 256;
	}

	if (fbimg_width  & 1) fbimg_width++;  // make even
	if (fbimg_height & 1) fbimg_height++;

	if (fbimg_width >= 480) {
		g_vertices[0].u = (fbimg_width-480)/2;
		g_vertices[1].u = src_width - (fbimg_width-480)/2 - 1;
		fbimg_width = 480;
		fbimg_xoffs = 0;
	} else {
		g_vertices[0].u = 0;
		g_vertices[1].u = src_width;
		fbimg_xoffs = 240 - fbimg_width/2;
	}
	if (fbimg_width > 320 && fbimg_width <= 480) border_hack = 1;

	if (fbimg_height >= 272) {
		g_vertices[0].v = (fbimg_height-272)/2;
		g_vertices[1].v = 240 - (fbimg_height-272)/2;
		fbimg_height = 272;
		fbimg_yoffs = 0;
	} else {
		g_vertices[0].v = 0;
		g_vertices[1].v = 240;
		fbimg_yoffs = 136 - fbimg_height/2;
	}

	g_vertices[1].x = fbimg_width;
	g_vertices[1].y = fbimg_height;
	if (fbimg_xoffs < 0) fbimg_xoffs = 0;
	if (fbimg_yoffs < 0) fbimg_yoffs = 0;
	if (border_hack) {
		g_vertices[0].u++;
		g_vertices[0].x++;
		g_vertices[1].u--;
		g_vertices[1].x--;
	}
	fbimg_offs = (fbimg_yoffs*512 + fbimg_xoffs) * 2; // dst is always 16bit

	/*
	lprintf("set_scaling_params:\n");
	lprintf("offs: %i, %i\n", fbimg_xoffs, fbimg_yoffs);
	lprintf("xy0, xy1: %i, %i; %i, %i\n", g_vertices[0].x, g_vertices[0].y, g_vertices[1].x, g_vertices[1].y);
	lprintf("uv0, uv1: %i, %i; %i, %i\n", g_vertices[0].u, g_vertices[0].v, g_vertices[1].u, g_vertices[1].v);
	*/
}

static void do_pal_update(int allow_sh, int allow_as)
{
	unsigned int *dpal=(void *)localPal;
	int i;

	//for (i = 0x3f/2; i >= 0; i--)
	//	dpal[i] = ((spal[i]&0x000f000f)<< 1)|((spal[i]&0x00f000f0)<<3)|((spal[i]&0x0f000f00)<<4);
	do_pal_convert(localPal, Pico.cram, currentConfig.gamma, currentConfig.gamma2);

	Pico.m.dirtyPal = 0;
	need_pal_upload = 1;

	if (allow_sh && (Pico.video.reg[0xC]&8)) // shadow/hilight?
	{
		// shadowed pixels
		for (i = 0x3f/2; i >= 0; i--)
			dpal[0x20|i] = dpal[0x60|i] = (dpal[i]>>1)&0x7bcf7bcf;
		// hilighted pixels
		for (i = 0x3f; i >= 0; i--) {
			int t=localPal[i]&0xf79e;t+=0x4208;
			if (t&0x20) t|=0x1e;
			if (t&0x800) t|=0x780;
			if (t&0x10000) t|=0xf000;
			t&=0xf79e;
			localPal[0x80|i]=(unsigned short)t;
		}
		localPal[0xe0] = 0;
		localPal[0xf0] = 0x001f;
	}
	else if (allow_as && (rendstatus & PDRAW_SPR_LO_ON_HI))
	{
		memcpy32((int *)dpal+0x80/2, (void *)localPal, 0x40*2/4);
	}
}

static void do_slowmode_lines(int line_to)
{
	int line = 0, line_len = (Pico.video.reg[12]&1) ? 320 : 256;
	unsigned short *dst = (unsigned short *)VRAM_STUFF + 512*240/2;
	unsigned char  *src = (unsigned char  *)VRAM_CACHED_STUFF + 16;
	if (!(Pico.video.reg[1]&8)) { line = 8; dst += 512*8; src += 512*8; }

	for (; line < line_to; line++, dst+=512, src+=512)
		amips_clut_f(dst, src, localPal, line_len);
}

static void EmuScanPrepare(void)
{
	HighCol = (unsigned char *)VRAM_CACHED_STUFF + 8;
	if (!(Pico.video.reg[1]&8)) HighCol += 8*512;

	if (dynamic_palette > 0)
		dynamic_palette--;

	if (Pico.m.dirtyPal)
		do_pal_update(1, 1);
	if ((rendstatus & PDRAW_SPR_LO_ON_HI) && !(Pico.video.reg[0xC]&8))
	     amips_clut_f = amips_clut_6bit;
	else amips_clut_f = amips_clut;
}

static int EmuScanSlowBegin(unsigned int num)
{
	if (!dynamic_palette)
		HighCol = (unsigned char *)VRAM_CACHED_STUFF + num * 512 + 8;

	return 0;
}

static int EmuScanSlowEnd(unsigned int num)
{
	if (Pico.m.dirtyPal) {
		if (!dynamic_palette) {
			do_slowmode_lines(num);
			dynamic_palette = 3; // last for 2 more frames
		}
		do_pal_update(1, 1);
	}

	if (dynamic_palette) {
		int line_len = (Pico.video.reg[12]&1) ? 320 : 256;
		void *dst = (char *)VRAM_STUFF + 512*240 + 512*2*num;
		amips_clut_f(dst, HighCol + 8, localPal, line_len);
	}

	return 0;
}

static void blitscreen_clut(void)
{
	int offs = fbimg_offs;
	offs += (psp_screen == VRAM_FB0) ? VRAMOFFS_FB0 : VRAMOFFS_FB1;

	sceGuSync(0,0); // sync with prev
	sceGuStart(GU_DIRECT, guCmdList);
	sceGuDrawBuffer(GU_PSM_5650, (void *)offs, 512); // point to back buffer

	if (dynamic_palette)
	{
		if (!blit_16bit_mode) { // the current mode is not 16bit
			sceGuTexMode(GU_PSM_5650, 0, 0, 0);
			sceGuTexImage(0,512,512,512,(char *)VRAM_STUFF + 512*240);

			blit_16bit_mode = 1;
		}
	}
	else
	{
		if (blit_16bit_mode) {
			sceGuClutMode(GU_PSM_5650,0,0xff,0);
			sceGuTexMode(GU_PSM_T8,0,0,0); // 8-bit image
			sceGuTexImage(0,512,512,512,(char *)VRAM_STUFF + 16);
			blit_16bit_mode = 0;
		}

		if ((PicoOpt&0x10) && Pico.m.dirtyPal)
			do_pal_update(0, 0);

		sceKernelDcacheWritebackAll();

		if (need_pal_upload) {
			need_pal_upload = 0;
			sceGuClutLoad((256/8), localPal); // upload 32*8 entries (256)
		}
	}

#if 1
	if (g_vertices[0].u == 0 && g_vertices[1].u == g_vertices[1].x)
	{
		struct Vertex* vertices;
		int x;

		#define SLICE_WIDTH 32
		for (x = 0; x < g_vertices[1].x; x += SLICE_WIDTH)
		{
			// render sprite
			vertices = (struct Vertex*)sceGuGetMemory(2 * sizeof(struct Vertex));
			memcpy(vertices, g_vertices, 2 * sizeof(struct Vertex));
			vertices[0].u = vertices[0].x = x;
			vertices[1].u = vertices[1].x = x + SLICE_WIDTH;
			sceGuDrawArray(GU_SPRITES,GU_TEXTURE_16BIT|GU_VERTEX_16BIT|GU_TRANSFORM_2D,2,0,vertices);
		}
		// lprintf("listlen: %iB\n", sceGuCheckList()); // ~480 only
	}
	else
#endif
		sceGuDrawArray(GU_SPRITES,GU_TEXTURE_16BIT|GU_VERTEX_16BIT|GU_TRANSFORM_2D,2,0,g_vertices);

	sceGuFinish();
}


static void cd_leds(void)
{
	unsigned int reg, col_g, col_r, *p;

	reg = Pico_mcd->s68k_regs[0];

	p = (unsigned int *)((short *)psp_screen + 512*2+4+2);
	col_g = (reg & 2) ? 0x06000600 : 0;
	col_r = (reg & 1) ? 0x00180018 : 0;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += 512/2 - 12/2;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += 512/2 - 12/2;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r;
}

static void draw_pico_ptr(void)
{
	unsigned char *p = (unsigned char *)VRAM_STUFF + 16;

	// only if pen enabled and for 8bit mode
	if (pico_inp_mode == 0 || blit_16bit_mode) return;

	p += 512 * (pico_pen_y + PICO_PEN_ADJUST_Y);
	p += pico_pen_x + PICO_PEN_ADJUST_X;
	p[  -1] = 0xe0; p[   0] = 0xf0; p[   1] = 0xe0;
	p[ 511] = 0xf0; p[ 512] = 0xf0; p[ 513] = 0xf0;
	p[1023] = 0xe0; p[1024] = 0xf0; p[1025] = 0xe0;
}


#if 0
static void dbg_text(void)
{
	int *p, h, len;
	char text[128];

	sprintf(text, "sl: %i, 16b: %i", g_vertices[0].u == 0 && g_vertices[1].u == g_vertices[1].x, blit_16bit_mode);
	len = strlen(text) * 8 / 2;
	for (h = 0; h < 8; h++) {
		p = (int *) ((unsigned short *) psp_screen+2+512*(256+h));
		p = (int *) ((int)p & ~3); // align
		memset32_uncached(p, 0, len);
	}
	emu_text_out16(2, 256, text);
}
#endif

/* called after rendering is done, but frame emulation is not finished */
void blit1(void)
{
	if (PicoOpt&0x10)
	{
		int i;
		unsigned char *pd;
		// clear top and bottom trash
		for (pd = PicoDraw2FB+8, i = 8; i > 0; i--, pd += 512)
			memset32((int *)pd, 0xe0e0e0e0, 320/4);
		for (pd = PicoDraw2FB+512*232+8, i = 8; i > 0; i--, pd += 512)
			memset32((int *)pd, 0xe0e0e0e0, 320/4);
	}

	if (PicoAHW & PAHW_PICO)
		draw_pico_ptr();

	blitscreen_clut();
}


static void blit2(const char *fps, const char *notice, int lagging_behind)
{
	int vsync = 0, emu_opt = currentConfig.EmuOpt;

	if (notice || (emu_opt & 2)) {
		if (notice)      osd_text(4, notice, 0, 0);
		if (emu_opt & 2) osd_text(OSD_FPS_X, fps, 0, 0);
	}

	//dbg_text();

	if ((emu_opt & 0x400) && (PicoAHW & PAHW_MCD))
		cd_leds();

	if (currentConfig.EmuOpt & 0x2000) { // want vsync
		if (!(currentConfig.EmuOpt & 0x10000) || !lagging_behind) vsync = 1;
	}

	psp_video_flip(vsync);
}

// clears whole screen or just the notice area (in all buffers)
static void clearArea(int full)
{
	if (full) {
		memset32_uncached(psp_screen, 0, 512*272*2/4);
		psp_video_flip(0);
		memset32_uncached(psp_screen, 0, 512*272*2/4);
		memset32(VRAM_CACHED_STUFF, 0xe0e0e0e0, 512*240/4);
		memset32((int *)VRAM_CACHED_STUFF+512*240/4, 0, 512*240*2/4);
	} else {
		void *fb = psp_video_get_active_fb();
		memset32_uncached((int *)((char *)psp_screen + 512*264*2), 0, 512*8*2/4);
		memset32_uncached((int *)((char *)fb         + 512*264*2), 0, 512*8*2/4);
	}
}

static void vidResetMode(void)
{
	// setup GU
	sceGuSync(0,0); // sync with prev
	sceGuStart(GU_DIRECT, guCmdList);

	sceGuClutMode(GU_PSM_5650,0,0xff,0);
	sceGuTexMode(GU_PSM_T8,0,0,0); // 8-bit image
	sceGuTexFunc(GU_TFX_REPLACE,GU_TCC_RGB);
	if (currentConfig.scaling)
	     sceGuTexFilter(GU_LINEAR, GU_LINEAR);
	else sceGuTexFilter(GU_NEAREST, GU_NEAREST);
	sceGuTexScale(1.0f,1.0f);
	sceGuTexOffset(0.0f,0.0f);

	sceGuTexImage(0,512,512,512,(char *)VRAM_STUFF + 16);

	// slow rend.
	PicoDrawSetOutFormat(PDF_NONE, 0);
	PicoDrawSetCallbacks(EmuScanSlowBegin, EmuScanSlowEnd);

	localPal[0xe0] = 0;
	localPal[0xf0] = 0x001f;
	Pico.m.dirtyPal = 1;
	blit_16bit_mode = dynamic_palette = 0;

	sceGuFinish();
	set_scaling_params();
	sceGuSync(0,0);
}

void plat_debug_cat(char *str)
{
	strcat(str, blit_16bit_mode ? "soft clut\n" : "hard clut\n");
}


/* sound stuff */
#define SOUND_BLOCK_SIZE_NTSC (1470*2) // 1024 // 1152
#define SOUND_BLOCK_SIZE_PAL  (1764*2)
#define SOUND_BLOCK_COUNT    8

static short __attribute__((aligned(4))) sndBuffer[SOUND_BLOCK_SIZE_PAL*SOUND_BLOCK_COUNT + 44100/50*2];
static short *snd_playptr = NULL, *sndBuffer_endptr = NULL;
static int samples_made = 0, samples_done = 0, samples_block = 0;
static int sound_thread_exit = 0;
static SceUID sound_sem = -1;

static void writeSound(int len);

static int sound_thread(SceSize args, void *argp)
{
	int ret = 0;

	lprintf("sthr: started, priority %i\n", sceKernelGetThreadCurrentPriority());

	while (!sound_thread_exit)
	{
		if (samples_made - samples_done < samples_block) {
			// wait for data (use at least 2 blocks)
			//lprintf("sthr: wait... (%i)\n", samples_made - samples_done);
			while (samples_made - samples_done <= samples_block*2 && !sound_thread_exit)
				ret = sceKernelWaitSema(sound_sem, 1, 0);
			if (ret < 0) lprintf("sthr: sceKernelWaitSema: %i\n", ret);
			continue;
		}

		// lprintf("sthr: got data: %i\n", samples_made - samples_done);

		ret = sceAudio_E0727056(PSP_AUDIO_VOLUME_MAX, snd_playptr);

		samples_done += samples_block;
		snd_playptr  += samples_block;
		if (snd_playptr >= sndBuffer_endptr)
			snd_playptr = sndBuffer;
		// 1.5 kernel returns 0, newer ones return # of samples queued
		if (ret < 0)
			lprintf("sthr: sceAudio_E0727056: %08x; pos %i/%i\n", ret, samples_done, samples_made);

		// shouln't happen, but just in case
		if (samples_made - samples_done >= samples_block*3) {
			//lprintf("sthr: block skip (%i)\n", samples_made - samples_done);
			samples_done += samples_block; // skip
			snd_playptr  += samples_block;
		}

	}

	lprintf("sthr: exit\n");
	sceKernelExitDeleteThread(0);
	return 0;
}

static void sound_init(void)
{
	SceUID thid;
	int ret;

	sound_sem = sceKernelCreateSema("sndsem", 0, 0, 1, NULL);
	if (sound_sem < 0) lprintf("sceKernelCreateSema() failed: %i\n", sound_sem);

	samples_made = samples_done = 0;
	samples_block = SOUND_BLOCK_SIZE_NTSC; // make sure it goes to sema
	sound_thread_exit = 0;
	thid = sceKernelCreateThread("sndthread", sound_thread, 0x12, 0x10000, 0, NULL);
	if (thid >= 0)
	{
		ret = sceKernelStartThread(thid, 0, 0);
		if (ret < 0) lprintf("sound_init: sceKernelStartThread returned %08x\n", ret);
	}
	else
		lprintf("sceKernelCreateThread failed: %i\n", thid);
}

void pemu_sound_start(void)
{
	static int PsndRate_old = 0, PicoOpt_old = 0, pal_old = 0;
	int ret, stereo;

	samples_made = samples_done = 0;

	if (PsndRate != PsndRate_old || (PicoOpt&0x0b) != (PicoOpt_old&0x0b) || Pico.m.pal != pal_old) {
		PsndRerate(Pico.m.frame_count ? 1 : 0);
	}
	stereo=(PicoOpt&8)>>3;

	samples_block = Pico.m.pal ? SOUND_BLOCK_SIZE_PAL : SOUND_BLOCK_SIZE_NTSC;
	if (PsndRate <= 22050) samples_block /= 2;
	sndBuffer_endptr = &sndBuffer[samples_block*SOUND_BLOCK_COUNT];

	lprintf("starting audio: %i, len: %i, stereo: %i, pal: %i, block samples: %i\n",
			PsndRate, PsndLen, stereo, Pico.m.pal, samples_block);

	// while (sceAudioOutput2GetRestSample() > 0) psp_msleep(100);
	// sceAudio_5C37C0AE();
	ret = sceAudio_38553111(samples_block/2, PsndRate, 2); // seems to not need that stupid 64byte alignment
	if (ret < 0) {
		lprintf("sceAudio_38553111() failed: %i\n", ret);
		emu_status_msg("sound init failed (%i), snd disabled", ret);
		currentConfig.EmuOpt &= ~EOPT_EN_SOUND;
	} else {
		PicoWriteSound = writeSound;
		memset32((int *)(void *)sndBuffer, 0, sizeof(sndBuffer)/4);
		snd_playptr = sndBuffer_endptr - samples_block;
		samples_made = samples_block; // send 1 empty block first..
		PsndOut = sndBuffer;
		PsndRate_old = PsndRate;
		PicoOpt_old  = PicoOpt;
		pal_old = Pico.m.pal;
	}
}

void pemu_sound_stop(void)
{
	int i;
	if (samples_done == 0)
	{
		// if no data is written between sceAudio_38553111 and sceAudio_5C37C0AE calls,
		// we get a deadlock on next sceAudio_38553111 call
		// so this is yet another workaround:
		memset32((int *)(void *)sndBuffer, 0, samples_block*4/4);
		samples_made = samples_block * 3;
		sceKernelSignalSema(sound_sem, 1);
	}
	sceKernelDelayThread(100*1000);
	samples_made = samples_done = 0;
	for (i = 0; sceAudioOutput2GetRestSample() > 0 && i < 16; i++)
		psp_msleep(100);
	sceAudio_5C37C0AE();
}

/* wait until we can write more sound */
void pemu_sound_wait(void)
{
	// TODO: test this
	while (!sound_thread_exit && samples_made - samples_done > samples_block * 4)
		psp_msleep(10);
}

static void sound_deinit(void)
{
	sound_thread_exit = 1;
	sceKernelSignalSema(sound_sem, 1);
	sceKernelDeleteSema(sound_sem);
	sound_sem = -1;
}

static void writeSound(int len)
{
	int ret;

	PsndOut += len / 2;
	/*if (PsndOut > sndBuffer_endptr) {
		memcpy32((int *)(void *)sndBuffer, (int *)endptr, (PsndOut - endptr + 1) / 2);
		PsndOut = &sndBuffer[PsndOut - endptr];
		lprintf("mov\n");
	}
	else*/
	if (PsndOut > sndBuffer_endptr) lprintf("snd oflow %i!\n", PsndOut - sndBuffer_endptr);
	if (PsndOut >= sndBuffer_endptr)
		PsndOut = sndBuffer;

	// signal the snd thread
	samples_made += len / 2;
	if (samples_made - samples_done > samples_block*2) {
		// lprintf("signal, %i/%i\n", samples_done, samples_made);
		ret = sceKernelSignalSema(sound_sem, 1);
		//if (ret < 0) lprintf("snd signal ret %08x\n", ret);
	}
}


static void SkipFrame(void)
{
	PicoSkipFrame=1;
	PicoFrame();
	PicoSkipFrame=0;
}

void pemu_forced_frame(int no_scale, int do_emu)
{
	int po_old = PicoOpt;
	int eo_old = currentConfig.EmuOpt;

	PicoOpt &= ~POPT_ALT_RENDERER;
	PicoOpt |= POPT_ACC_SPRITES;
	if (!no_scale)
		PicoOpt |= POPT_EN_SOFTSCALE;
	currentConfig.EmuOpt |= 0x80;

	vidResetMode();
	memset32(VRAM_CACHED_STUFF, 0xe0e0e0e0, 512*8/4); // borders
	memset32((int *)VRAM_CACHED_STUFF + 512*232/4, 0xe0e0e0e0, 512*8/4);
	memset32_uncached((int *)psp_screen + 512*264*2/4, 0, 512*8*2/4);

	PicoDrawSetOutFormat(PDF_NONE, 0);
	PicoDrawSetCallbacks(EmuScanSlowBegin, EmuScanSlowEnd);
	EmuScanPrepare();
	PicoFrameDrawOnly();
	blit1();
	sceGuSync(0,0);

	PicoOpt = po_old;
	currentConfig.EmuOpt = eo_old;
}


static void RunEventsPico(unsigned int events, unsigned int keys)
{
	emu_RunEventsPico(events);

	if (pico_inp_mode != 0)
	{
		PicoPad[0] &= ~0x0f; // release UDLR
		if (keys & PBTN_UP)   { pico_pen_y--; if (pico_pen_y < 8) pico_pen_y = 8; }
		if (keys & PBTN_DOWN) { pico_pen_y++; if (pico_pen_y > 224-PICO_PEN_ADJUST_Y) pico_pen_y = 224-PICO_PEN_ADJUST_Y; }
		if (keys & PBTN_LEFT) { pico_pen_x--; if (pico_pen_x < 0) pico_pen_x = 0; }
		if (keys & PBTN_RIGHT) {
			int lim = (Pico.video.reg[12]&1) ? 319 : 255;
			pico_pen_x++;
			if (pico_pen_x > lim-PICO_PEN_ADJUST_X)
				pico_pen_x = lim-PICO_PEN_ADJUST_X;
		}
		PicoPicohw.pen_pos[0] = pico_pen_x;
		if (!(Pico.video.reg[12]&1)) PicoPicohw.pen_pos[0] += pico_pen_x/4;
		PicoPicohw.pen_pos[0] += 0x3c;
		PicoPicohw.pen_pos[1] = pico_inp_mode == 1 ? (0x2f8 + pico_pen_y) : (0x1fc + pico_pen_y);
	}
}

static void RunEvents(unsigned int which)
{
	if (which & 0x1800) // save or load (but not both)
	{
		int do_it = 1;

		if ( emu_check_save_file(state_slot) &&
				(( (which & 0x1000) && (currentConfig.EmuOpt & 0x800)) || // load
				 (!(which & 0x1000) && (currentConfig.EmuOpt & 0x200))) ) // save
		{
			int keys;
			sceGuSync(0,0);
			blit2("", (which & 0x1000) ? "LOAD STATE? (X=yes, O=no)" : "OVERWRITE SAVE? (X=yes, O=no)", 0);
			while( !((keys = psp_pad_read(1)) & (PBTN_X|PBTN_CIRCLE)) )
				psp_msleep(50);
			if (keys & PBTN_CIRCLE) do_it = 0;
			while(  ((keys = psp_pad_read(1)) & (PBTN_X|PBTN_CIRCLE)) ) // wait for release
				psp_msleep(50);
			clearArea(0);
		}

		if (do_it)
		{
			osd_text(4, (which & 0x1000) ? "LOADING GAME" : "SAVING GAME", 1, 0);
			PicoStateProgressCB = emu_msg_cb;
			emu_save_load_game((which & 0x1000) >> 12, 0);
			PicoStateProgressCB = NULL;
			psp_msleep(0);
		}

		reset_timing = 1;
	}
	if (which & 0x0400) // switch renderer
	{
		if (PicoOpt&0x10) { PicoOpt&=~0x10; currentConfig.EmuOpt |=  0x80; }
		else              { PicoOpt|= 0x10; currentConfig.EmuOpt &= ~0x80; }

		vidResetMode();

		if (PicoOpt & POPT_ALT_RENDERER)
			emu_status_msg("fast renderer");
		else if (currentConfig.EmuOpt&0x80)
			emu_status_msg("accurate renderer");
	}
	if (which & 0x0300)
	{
		if(which&0x0200) {
			state_slot -= 1;
			if(state_slot < 0) state_slot = 9;
		} else {
			state_slot += 1;
			if(state_slot > 9) state_slot = 0;
		}
		emu_status_msg("SAVE SLOT %i [%s]", state_slot,
			emu_check_save_file(state_slot) ? "USED" : "FREE");
	}
}

static void updateKeys(void)
{
	unsigned int keys, allActions[2] = { 0, 0 }, events;
	static unsigned int prevEvents = 0;
	int i;

	/* FIXME: port to input fw, merge with emu.c:emu_update_input() */
	keys = psp_pad_read(0);
	if (keys & PSP_CTRL_HOME)
		sceDisplayWaitVblankStart();

	if (keys & PBTN_SELECT)
		engineState = PGS_Menu;

	keys &= CONFIGURABLE_KEYS;

	PicoPad[0] = allActions[0] & 0xfff;
	PicoPad[1] = allActions[1] & 0xfff;

	if (allActions[0] & 0x7000) emu_DoTurbo(&PicoPad[0], allActions[0]);
	if (allActions[1] & 0x7000) emu_DoTurbo(&PicoPad[1], allActions[1]);

	events = (allActions[0] | allActions[1]) >> 16;

	if ((events ^ prevEvents) & 0x40) {
		emu_set_fastforward(events & 0x40);
		reset_timing = 1;
	}

	events &= ~prevEvents;

	if (PicoAHW == PAHW_PICO)
		RunEventsPico(events, keys);
	if (events) RunEvents(events);
	if (movie_data) emu_updateMovie();

	prevEvents = (allActions[0] | allActions[1]) >> 16;
}


static void simpleWait(unsigned int until)
{
	unsigned int tval;
	int diff;

	tval = sceKernelGetSystemTimeLow();
	diff = (int)until - (int)tval;
	if (diff >= 512 && diff < 100*1024)
		sceKernelDelayThread(diff);
}

void pemu_loop(void)
{
	static int mp3_init_done = 0;
	char fpsbuff[24]; // fps count c string
	unsigned int tval, tval_thissec = 0; // timing
	int target_fps, target_frametime, lim_time, tval_diff, i, oldmodes = 0;
	int pframes_done, pframes_shown; // "period" frames, used for sync
	int  frames_done,  frames_shown, tval_fpsc = 0; // actual frames
	char *notice = NULL;

	lprintf("entered emu_Loop()\n");

	fpsbuff[0] = 0;

	if (currentConfig.CPUclock != psp_get_cpu_clock()) {
		lprintf("setting cpu clock to %iMHz... ", currentConfig.CPUclock);
		i = psp_set_cpu_clock(currentConfig.CPUclock);
		lprintf(i ? "failed\n" : "done\n");
		currentConfig.CPUclock = psp_get_cpu_clock();
	}

	// make sure we are in correct mode
	vidResetMode();
	clearArea(1);
	Pico.m.dirtyPal = 1;
	oldmodes = ((Pico.video.reg[12]&1)<<2) ^ 0xc;

	// pal/ntsc might have changed, reset related stuff
	target_fps = Pico.m.pal ? 50 : 60;
	target_frametime = Pico.m.pal ? (1000000<<8)/50 : (1000000<<8)/60+1;
	reset_timing = 1;

	if (PicoAHW & PAHW_MCD) {
		// prepare CD buffer
		PicoCDBufferInit();
		// mp3...
		if (!mp3_init_done) {
			i = mp3_init();
			mp3_init_done = 1;
			if (i) { engineState = PGS_Menu; return; }
		}
	}

	// prepare sound stuff
	PsndOut = NULL;
	if (currentConfig.EmuOpt & EOPT_EN_SOUND)
	{
		pemu_sound_start();
	}

	sceDisplayWaitVblankStart();
	pframes_shown = pframes_done =
	 frames_shown =  frames_done = 0;

	tval_fpsc = sceKernelGetSystemTimeLow();

	// loop?
	while (engineState == PGS_Running)
	{
		int modes;

		tval = sceKernelGetSystemTimeLow();
		if (reset_timing || tval < tval_fpsc) {
			//stdbg("timing reset");
			reset_timing = 0;
			tval_thissec = tval;
			pframes_shown = pframes_done = 0;
		}

		// show notice message?
		if (noticeMsgTime) {
			static int noticeMsgSum;
			if (tval - noticeMsgTime > 2000000) { // > 2.0 sec
				noticeMsgTime = 0;
				clearArea(0);
				notice = 0;
			} else {
				int sum = noticeMsg[0]+noticeMsg[1]+noticeMsg[2];
				if (sum != noticeMsgSum) { clearArea(0); noticeMsgSum = sum; }
				notice = noticeMsg;
			}
		}

		// check for mode changes
		modes = ((Pico.video.reg[12]&1)<<2)|(Pico.video.reg[1]&8);
		if (modes != oldmodes) {
			oldmodes = modes;
			clearArea(1);
			set_scaling_params();
		}

		// second passed?
		if (tval - tval_fpsc >= 1000000)
		{
			if (currentConfig.EmuOpt & 2)
				sprintf(fpsbuff, "%02i/%02i  ", frames_shown, frames_done);
			frames_done = frames_shown = 0;
			tval_fpsc += 1000000;
		}

		if (tval - tval_thissec >= 1000000)
		{
			// missing 1 frame?
			if (currentConfig.Frameskip < 0 && pframes_done < target_fps) {
				SkipFrame(); pframes_done++; frames_done++;
			}

			tval_thissec += 1000000;

			if (currentConfig.Frameskip < 0) {
				pframes_done  -= target_fps; if (pframes_done  < 0) pframes_done  = 0;
				pframes_shown -= target_fps; if (pframes_shown < 0) pframes_shown = 0;
				if (pframes_shown > pframes_done) pframes_shown = pframes_done;
			} else {
				pframes_done = pframes_shown = 0;
			}
		}
#ifdef PFRAMES
		sprintf(fpsbuff, "%i", Pico.m.frame_count);
#endif

		lim_time = (pframes_done+1) * target_frametime;
		if (currentConfig.Frameskip >= 0) // frameskip enabled
		{
			for (i = 0; i < currentConfig.Frameskip; i++) {
				updateKeys();
				SkipFrame(); pframes_done++; frames_done++;
				if (!(currentConfig.EmuOpt&0x40000)) { // do framelimitting if needed
					int tval_diff;
					tval = sceKernelGetSystemTimeLow();
					tval_diff = (int)(tval - tval_thissec) << 8;
					if (tval_diff < lim_time) // we are too fast
						simpleWait(tval + ((lim_time - tval_diff)>>8));
				}
				lim_time += target_frametime;
			}
		}
		else // auto frameskip
		{
			int tval_diff;
			tval = sceKernelGetSystemTimeLow();
			tval_diff = (int)(tval - tval_thissec) << 8;
			if (tval_diff > lim_time && (pframes_done/16 < pframes_shown))
			{
				// no time left for this frame - skip
				if (tval_diff - lim_time >= (300000<<8)) {
					reset_timing = 1;
					continue;
				}
				updateKeys();
				SkipFrame(); pframes_done++; frames_done++;
				continue;
			}
		}

		updateKeys();

		if (!(PicoOpt&0x10))
			EmuScanPrepare();

		PicoFrame();

		sceGuSync(0,0);

		// check time
		tval = sceKernelGetSystemTimeLow();
		tval_diff = (int)(tval - tval_thissec) << 8;

		blit2(fpsbuff, notice, tval_diff > lim_time);

		if (currentConfig.Frameskip < 0 && tval_diff - lim_time >= (300000<<8)) { // slowdown detection
			reset_timing = 1;
		}
		else if (!(currentConfig.EmuOpt&0x40000) || currentConfig.Frameskip < 0)
		{
			// sleep if we are still too fast
			if (tval_diff < lim_time)
			{
				// we are too fast
				simpleWait(tval + ((lim_time - tval_diff) >> 8));
			}
		}

		pframes_done++; pframes_shown++;
		 frames_done++;  frames_shown++;
	}


	emu_set_fastforward(0);

	if (PicoAHW & PAHW_MCD) PicoCDBufferFree();

	if (PsndOut != NULL) {
		pemu_sound_stop();
		PsndOut = NULL;
	}

	// save SRAM
	if ((currentConfig.EmuOpt & 1) && SRam.changed) {
		emu_msg_cb("Writing SRAM/BRAM..");
		emu_save_load_game(0, 1);
		SRam.changed = 0;
	}

	// clear fps counters and stuff
	memset32_uncached((int *)psp_video_get_active_fb() + 512*264*2/4, 0, 512*8*2/4);
}

void emu_HandleResume(void)
{
	if (!(PicoAHW & PAHW_MCD)) return;

	// reopen first CD track
	if (Pico_mcd->TOC.Tracks[0].F != NULL)
	{
		char *fname = rom_fname_reload;
		int len = strlen(rom_fname_reload);
		cue_data_t *cue_data = NULL;

		if (len > 4 && strcasecmp(fname + len - 4,  ".cue") == 0)
		{
			cue_data = cue_parse(rom_fname_reload);
			if (cue_data != NULL)
				fname = cue_data->tracks[1].fname;
		}

		lprintf("emu_HandleResume: reopen %s\n", fname);
		pm_close(Pico_mcd->TOC.Tracks[0].F);
		Pico_mcd->TOC.Tracks[0].F = pm_open(fname);
		lprintf("reopen %s\n", Pico_mcd->TOC.Tracks[0].F != NULL ? "ok" : "failed");

		if (cue_data != NULL) cue_destroy(cue_data);
	}

	mp3_reopen_file();

	if (!(Pico_mcd->s68k_regs[0x36] & 1) && (Pico_mcd->scd.Status_CDC & 1))
		cdda_start_play();
}

