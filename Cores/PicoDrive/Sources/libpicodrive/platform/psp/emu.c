/*
 * PicoDrive PSP frontend
 *
 * (C) notaz, 2007,2008
 * (C) irixxxx, 2022-2024
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
#include <pspsysmem.h>

#include "psp.h"
#include "emu.h"
#include "mp3.h"
#include "in_psp.h"
#include "asm_utils.h"
#include "../common/emu.h"
#include "../common/input_pico.h"
#include "../common/keyboard.h"
#include "platform/libpicofe/input.h"
#include "platform/libpicofe/menu.h"
#include "platform/libpicofe/plat.h"

#include <pico/pico_int.h>
#include <pico/cd/genplus_macros.h>
#include <pico/cd/cdd.h>

#define OSD_FPS_X 432

int engineStateSuspend;

struct Vertex
{
	short u,v;
	short x,y,z;
};

static struct Vertex __attribute__((aligned(4))) g_vertices[2];
static u16 __attribute__((aligned(16))) localPal[0x100];
static int need_pal_upload = 0;

u16 __attribute__((aligned(16))) osd_buf[512*8]; // buffer for osd text
int osd_buf_x[4], osd_buf_l[4]; // store for x and length for blitting
int osd_buf_cnt, osd_cdleds;

static int out_x, out_y;
static int out_w, out_h;
static float hscale, vscale;

static struct in_default_bind in_psp_defbinds[] =
{
	{ PSP_CTRL_UP,          IN_BINDTYPE_PLAYER12, GBTN_UP },
	{ PSP_CTRL_DOWN,        IN_BINDTYPE_PLAYER12, GBTN_DOWN },
	{ PSP_CTRL_LEFT,        IN_BINDTYPE_PLAYER12, GBTN_LEFT },
	{ PSP_CTRL_RIGHT,       IN_BINDTYPE_PLAYER12, GBTN_RIGHT },
	{ PSP_CTRL_SQUARE,      IN_BINDTYPE_PLAYER12, GBTN_A },
	{ PSP_CTRL_CROSS,       IN_BINDTYPE_PLAYER12, GBTN_B },
	{ PSP_CTRL_CIRCLE,      IN_BINDTYPE_PLAYER12, GBTN_C },
	{ PSP_CTRL_START,       IN_BINDTYPE_PLAYER12, GBTN_START },
	{ PSP_CTRL_TRIANGLE,    IN_BINDTYPE_EMU, PEVB_SWITCH_RND },
	{ PSP_CTRL_LTRIGGER,    IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ PSP_CTRL_RTRIGGER,    IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ PSP_CTRL_SELECT,      IN_BINDTYPE_EMU, PEVB_MENU },
	{ 0, 0, 0 }
};


const char *renderer_names[] = { "16bit accurate", " 8bit accurate", " 8bit fast", NULL };
const char *renderer_names32x[] = { "accurate", "faster", "fastest", NULL };
enum renderer_types { RT_16BIT, RT_8BIT_ACC, RT_8BIT_FAST, RT_COUNT };

#define is_16bit_mode() \
	(currentConfig.renderer == RT_16BIT || (PicoIn.AHW & PAHW_32X))

static int get_renderer(void)
{
	if (PicoIn.AHW & PAHW_32X)
		return currentConfig.renderer32x;
	else
		return currentConfig.renderer;
}

static void change_renderer(int diff)
{
	int *r;
	if (PicoIn.AHW & PAHW_32X)
		r = &currentConfig.renderer32x;
	else
		r = &currentConfig.renderer;
	*r += diff;

	if      (*r >= RT_COUNT)
		*r = 0;
	else if (*r < 0)
		*r = RT_COUNT - 1;
}

static void apply_renderer(void)
{
	PicoIn.opt &= ~(POPT_ALT_RENDERER|POPT_EN_SOFTSCALE);
	PicoIn.opt |= POPT_DIS_32C_BORDER;

	switch (get_renderer()) {
	case RT_16BIT:
		PicoDrawSetOutFormat(PDF_RGB555, 0);
		break;
	case RT_8BIT_ACC:
		PicoDrawSetOutFormat(PDF_8BIT, 0);
		break;
	case RT_8BIT_FAST:
		PicoIn.opt |=  POPT_ALT_RENDERER;
		PicoDrawSetOutFormat(PDF_NONE, 0);
		break;
	}
}


static void set_scaling_params(void)
{
	int fbimg_width, fbimg_height, fbimg_xoffs, fbimg_yoffs, border_hack = 0;
	g_vertices[0].z = g_vertices[1].z = 0;

	fbimg_height = (int)(out_h * vscale + 0.5);
	fbimg_width  = (int)(out_w * hscale + 0.5);

	if (fbimg_width  & 1) fbimg_width++;  // make even
	if (fbimg_height & 1) fbimg_height++;

	if (fbimg_width >= 480) {
		g_vertices[0].u = out_x + (fbimg_width-480)/2;
		g_vertices[1].u = out_x + out_w - (fbimg_width-480)/2 - 1;
		fbimg_width = 480;
		fbimg_xoffs = 0;
	} else {
		g_vertices[0].u = out_x;
		g_vertices[1].u = out_x + out_w;
		fbimg_xoffs = 240 - fbimg_width/2;
	}
	if (fbimg_width > 320 && fbimg_width <= 480) border_hack = 1;

	if (fbimg_height >= 272) {
		g_vertices[0].v = out_y + (fbimg_height-272)/2;
		g_vertices[1].v = out_y + out_h - (fbimg_height-272)/2;
		fbimg_height = 272;
		fbimg_yoffs = 0;
	} else {
		g_vertices[0].v = out_y;
		g_vertices[1].v = out_y + out_h;
		fbimg_yoffs = 136 - fbimg_height/2;
	}

	if (fbimg_xoffs < 0) fbimg_xoffs = 0;
	if (fbimg_yoffs < 0) fbimg_yoffs = 0;
	g_vertices[0].x = fbimg_xoffs;
	g_vertices[0].y = fbimg_yoffs;
	g_vertices[1].x = fbimg_xoffs + fbimg_width;
	g_vertices[1].y = fbimg_yoffs + fbimg_height;
	if (!is_16bit_mode()) {
		// 8-bit modes have an 8 px overlap area on the left
		g_vertices[0].u += 8; g_vertices[1].u += 8;
	}
	if (border_hack) {
		g_vertices[0].u++;    g_vertices[1].u--;
		g_vertices[0].x++;    g_vertices[1].x--;
	}

	/*
	lprintf("set_scaling_params:\n");
	lprintf("offs: %i, %i\n", fbimg_xoffs, fbimg_yoffs);
	lprintf("xy0, xy1: %i, %i; %i, %i\n", g_vertices[0].x, g_vertices[0].y, g_vertices[1].x, g_vertices[1].y);
	lprintf("uv0, uv1: %i, %i; %i, %i\n", g_vertices[0].u, g_vertices[0].v, g_vertices[1].u, g_vertices[1].v);
	*/
}

static void do_pal_update_sms(void)
{
	static u16 tmspal[32] = {
		// SMS palette
		0x0000, 0x0000, 0x00a0, 0x00f0, 0x0500, 0x0f00, 0x0005, 0x0ff0,
		0x000a, 0x000f, 0x0055, 0x00ff, 0x0050, 0x0f0f, 0x0555, 0x0fff,
		// TMS palette
		0x0000, 0x0000, 0x04c2, 0x07d6, 0x0e55, 0x0f77, 0x055c, 0x0ee4,
		0x055f, 0x077f, 0x05bc, 0x08ce, 0x03a2, 0x0b5c, 0x0ccc, 0x0fff,
	};
	int i;
	
	if (!(Pico.video.reg[0] & 0x4)) {
		int sg = !!(PicoIn.AHW & (PAHW_SG|PAHW_SC));
		for (i = Pico.est.SonicPalCount; i >= 0; i--)
			do_pal_convert(localPal+i*0x40, tmspal+sg*0x10, currentConfig.gamma, currentConfig.gamma2);
	} else {
		for (i = Pico.est.SonicPalCount; i >= 0; i--)
			do_pal_convert(localPal+i*0x40, Pico.est.SonicPal+i*0x40, currentConfig.gamma, currentConfig.gamma2);
	}
	if (Pico.m.dirtyPal == 2)
		Pico.m.dirtyPal = 0;
	need_pal_upload = 1;
}

static void do_pal_update(void)
{
	u32 *dpal=(void *)localPal;
	int i;

	if (PicoIn.opt & POPT_ALT_RENDERER) {
		do_pal_convert(localPal, PicoMem.cram, currentConfig.gamma, currentConfig.gamma2);
		Pico.m.dirtyPal = 0;
	}
	else if (Pico.est.rendstatus & PDRAW_SONIC_MODE)
	{
		switch (Pico.est.SonicPalCount) {
		case 3: do_pal_convert(localPal+0xc0, Pico.est.SonicPal+0xc0, currentConfig.gamma, currentConfig.gamma2);
		case 2: do_pal_convert(localPal+0x80, Pico.est.SonicPal+0x80, currentConfig.gamma, currentConfig.gamma2);
		case 1:	do_pal_convert(localPal+0x40, Pico.est.SonicPal+0x40, currentConfig.gamma, currentConfig.gamma2);
		default:do_pal_convert(localPal, Pico.est.SonicPal, currentConfig.gamma, currentConfig.gamma2);
		}
	}
	else if (Pico.video.reg[0xC]&8) // shadow/hilight?
	{
		do_pal_convert(localPal, Pico.est.SonicPal, currentConfig.gamma, currentConfig.gamma2);
		// shadowed pixels
		for (i = 0; i < 0x40 / 2; i++) {
			dpal[0xc0/2 + i] = dpal[i];
			dpal[0x80/2 + i] = (dpal[i] >> 1) & 0x738e738e;
		}
		// hilighted pixels
		for (i = 0; i < 0x40 / 2; i++) {
			u32 t = ((dpal[i] >> 1) & 0x738e738e) + 0x738e738e;
			t |= (t >> 4) & 0x08610861;
			dpal[0x40/2 + i] = t;
		}
	}
 	else
 	{
		do_pal_convert(localPal, Pico.est.SonicPal, currentConfig.gamma, currentConfig.gamma2);
		memcpy((int *)dpal+0x40/2, (void *)localPal, 0x40*2);
		memcpy((int *)dpal+0x80/2, (void *)localPal, 0x80*2);
	}
	localPal[0xe0] = 0;
	localPal[0xf0] = 0x001f;

	if (Pico.m.dirtyPal == 2)
		Pico.m.dirtyPal = 0;
	need_pal_upload = 1;
}

static void osd_text(int x, const char *text)
{
	int len = strlen(text) * 8;
	int *p, h;
	void *tmp = g_screen_ptr;

	g_screen_ptr = osd_buf;
	for (h = 0; h < 8; h++) {
		p = (int *) (osd_buf+x+512*h);
		p = (int *) ((int)p & ~3); // align
		memset32_uncached(p, 0, len/2);
	}
	emu_text_out16(x, 0, text);
	g_screen_ptr = tmp;

	osd_buf_x[osd_buf_cnt] = x;
	osd_buf_l[osd_buf_cnt] = len;
	osd_buf_cnt ++;
}

static void blit_osd(void)
{
	struct Vertex* vx;
	int x, len;

	while (osd_buf_cnt > 0) {
		osd_buf_cnt --;
		x = osd_buf_x[osd_buf_cnt];
		len = osd_buf_l[osd_buf_cnt];
		vx = (struct Vertex*)sceGuGetMemory(2 * sizeof(struct Vertex));
		vx[0].u = x,       vx[0].v = 0;
		vx[1].u = x + len, vx[1].v = 8;
		vx[0].x = x,       vx[0].y = 264;
		vx[1].x = x + len, vx[1].y = 272;
		sceGuTexMode(GU_PSM_5650,0,0,0);
		sceGuTexImage(0,512,8,512,osd_buf);
		sceGuDrawArray(GU_SPRITES,GU_TEXTURE_16BIT|GU_VERTEX_16BIT|GU_TRANSFORM_2D,2,0,vx);
	}
}

static void cd_leds(void)
{
	unsigned int reg, col_g, col_r, *p;

	reg = Pico_mcd->s68k_regs[0];

	p = (unsigned int *)((short *)osd_buf + 512*2+498);
	col_g = (reg & 2) ? 0x06000600 : 0;
	col_r = (reg & 1) ? 0x00180018 : 0;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += 512/2 - 12/2;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += 512/2 - 12/2;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r;

	osd_cdleds = 1;
}

static void blit_cdleds(void)
{
	struct Vertex* vx;

	if (!osd_cdleds) return;

	vx = (struct Vertex*)sceGuGetMemory(2 * sizeof(struct Vertex));
	vx[0].u = 497,          vx[0].v = 1;
	vx[1].u = 497+14,       vx[1].v = 6;
	vx[0].x = 4,            vx[0].y = 1;
	vx[1].x = 4+14,         vx[1].y = 6;
	sceGuTexMode(GU_PSM_5650,0,0,0);
	sceGuTexImage(0,512,8,512,osd_buf);
	sceGuDrawArray(GU_SPRITES,GU_TEXTURE_16BIT|GU_VERTEX_16BIT|GU_TRANSFORM_2D,2,0,vx);
}

void blitscreen_clut(void)
{
	sceGuTexMode(is_16bit_mode() ? GU_PSM_5650:GU_PSM_T8,0,0,0);
	sceGuTexImage(0,512,512,512,g_screen_ptr);

	if (!is_16bit_mode() && Pico.m.dirtyPal) {
		if (PicoIn.AHW & PAHW_SMS)
			do_pal_update_sms();
		else
			do_pal_update();
	}

	if (need_pal_upload) {
		need_pal_upload = 0;
		sceGuClutLoad((256/8), localPal); // upload 32*8 entries (256)
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

	blit_osd();
	blit_cdleds();
}


static void draw_pico_ptr(void)
{
	int up = (PicoPicohw.pen_pos[0]|PicoPicohw.pen_pos[1]) & 0x8000;
	int x = pico_pen_x, y = pico_pen_y, offs;
	int pitch = g_screen_ppitch;
	// storyware pages are actually squished, 2:1
	int h = (pico_inp_mode == 1 ? 160 : out_h);
	if (h < 224) y++;

	x = (x * out_w * ((1ULL<<32) / 320 + 1)) >> 32;
	y = (y *     h * ((1ULL<<32) / 224 + 1)) >> 32;

	offs = pitch * (out_y+y) + (out_x+x);

	if (is_16bit_mode()) {
		unsigned short *p = (unsigned short *)g_screen_ptr + offs;
		int o = (up ? 0x0000 : 0xffff), _ = (up ? 0xffff : 0x0000);

		p[-pitch-1] ^= o; p[-pitch] ^= _; p[-pitch+1] ^= _; p[-pitch+2] ^= o;
		p[-1]       ^= _; p[0]      ^= o; p[1]        ^= o; p[2]        ^= _;
		p[pitch-1]  ^= _; p[pitch]  ^= o; p[pitch+1]  ^= o; p[pitch+2]  ^= _;
		p[2*pitch-1]^= o; p[2*pitch]^= _; p[2*pitch+1]^= _; p[2*pitch+2]^= o;
	} else {
		unsigned char *p = (unsigned char *)g_screen_ptr + offs + 8;
		int o = (up ? 0xe0 : 0xf0), _ = (up ? 0xf0 : 0xe0);

		p[-pitch-1] = o; p[-pitch] = _; p[-pitch+1] = _; p[-pitch+2] = o;
		p[-1]       = _; p[0]      = o; p[1]        = o; p[2]        = _;
		p[pitch-1]  = _; p[pitch]  = o; p[pitch+1]  = o; p[pitch+2]  = _;
		p[2*pitch-1]= o; p[2*pitch]= _; p[2*pitch+1]= _; p[2*pitch+2]= o;
	}
}


static void vidResetMode(void)
{
	// setup GU
	sceGuSync(0,0); // sync with prev
	sceGuStart(GU_DIRECT, guCmdList);

	sceGuClutMode(GU_PSM_5650,0,0xff,0);
	sceGuTexFunc(GU_TFX_REPLACE,GU_TCC_RGB);
	if (currentConfig.filter)
	     sceGuTexFilter(GU_LINEAR, GU_LINEAR);
	else sceGuTexFilter(GU_NEAREST, GU_NEAREST);
	sceGuTexScale(1.0f,1.0f);
	sceGuTexOffset(0.0f,0.0f);

	Pico.m.dirtyPal = 1;

	sceGuFinish();
	set_scaling_params();
	sceGuSync(0,0);
}

/* sound stuff */
#define SOUND_BLOCK_COUNT    7
#define SOUND_BUFFER_CHUNK   (2*44100/50) // max.rate/min.frames in stereo

static short sndBuffer_emu[SOUND_BUFFER_CHUNK+4]; // 4 for sample rounding overhang
static short __attribute__((aligned(4))) sndBuffer[SOUND_BUFFER_CHUNK*SOUND_BLOCK_COUNT];
static short *sndBuffer_endptr;
static int samples_block;

static short *snd_playptr, *sndBuffer_ptr;
static int samples_made, samples_done;

static int sound_thread_exit = 0;
static SceUID sound_sem = -1;

// There are problems if the sample rate used with the PSP isn't 44100 Hz stereo.
// Hence, use only 11025,22050,44100 here and handle duplication and upsampling.
// Upsample by nearest neighbour, which is the fastest but may create artifacts.

static void writeSound(int len)
{
	// make sure there is enough free space in the buffer after
	// this frame, else the next frame may overwrite old stored samples.
	if (samples_made - samples_done < samples_block * (SOUND_BLOCK_COUNT-2) - 8) {
		sndBuffer_ptr += len / 2;
		if (sndBuffer_ptr - sndBuffer > sizeof(sndBuffer)/2)
			lprintf("snd ovrn %d %d\n", len, sndBuffer_ptr - sndBuffer);
		if (sndBuffer_ptr >= sndBuffer_endptr) {
			int wrap = sndBuffer_ptr - sndBuffer_endptr;
			if (wrap > 0)
				memcpy(sndBuffer, sndBuffer_endptr, 2*wrap);
			sndBuffer_ptr -= sndBuffer_endptr - sndBuffer;
		}

		samples_made += len / 2;
	} else
		lprintf("snd oflow %i!\n", samples_made - samples_done);

	// signal the snd thread
	sceKernelSignalSema(sound_sem, 1);
}

static void writeSound_44100_stereo(int len)
{
	writeSound(len);
	PicoIn.sndOut = sndBuffer_ptr;
}

static void writeSound_44100_mono(int len)
{
	short *p = sndBuffer_ptr;
	int i;

	for (i = 0; i < len / 2; i++, p+=2)
		p[0] = p[1] = PicoIn.sndOut[i];
	writeSound(2*len);
}

static void writeSound_22050_stereo(int len)
{
	short *p = sndBuffer_ptr;
	int i;

	for (i = 0; i < len / 2; i+=2, p+=4) {
		p[0] = p[2] = PicoIn.sndOut[i];
		p[1] = p[3] = PicoIn.sndOut[i+1];
	}
	writeSound(2*len);
}

static void writeSound_22050_mono(int len)
{
	short *p = sndBuffer_ptr;
	int i;

	for (i = 0; i < len / 2; i++, p+=4) {
		p[0] = p[2] = PicoIn.sndOut[i];
		p[1] = p[3] = PicoIn.sndOut[i];
	}
	writeSound(4*len);
}

static void writeSound_11025_stereo(int len)
{
	short *p = sndBuffer_ptr;
	int i;

	for (i = 0; i < len / 2; i+=2, p+=8) {
		p[0] = p[2] = p[4] = p[6] = PicoIn.sndOut[i];
		p[1] = p[3] = p[5] = p[7] = PicoIn.sndOut[i+1];
	}
	writeSound(4*len);
}

static void writeSound_11025_mono(int len)
{
	short *p = sndBuffer_ptr;
	int i;

	for (i = 0; i < len / 2; i++, p+=8) {
		p[0] = p[2] = p[4] = p[6] = PicoIn.sndOut[i];
		p[1] = p[3] = p[5] = p[7] = PicoIn.sndOut[i];
	}
	writeSound(8*len);
}

static int sound_thread(SceSize args, void *argp)
{
	lprintf("sthr: started, priority %i\n", sceKernelGetThreadCurrentPriority());

	while (!sound_thread_exit)
	{
		int ret;

		if (samples_made - samples_done < samples_block) {
			// wait for data (use at least 2 blocks)
			//lprintf("sthr: wait... (%i)\n", samples_made - samples_done);
			while (samples_made - samples_done < samples_block*2 && !sound_thread_exit) {
				ret = sceKernelWaitSema(sound_sem, 1, 0);
				if (ret < 0) lprintf("sthr: sceKernelWaitSema: %i\n", ret);
			}
		}

		// if the sample buffer runs low, push some extra
		if (sceAudioOutput2GetRestSample()*2 < samples_block/4)
			ret = sceAudioSRCOutputBlocking(PSP_AUDIO_VOLUME_MAX, snd_playptr);
		ret = sceAudioSRCOutputBlocking(PSP_AUDIO_VOLUME_MAX, snd_playptr);
		// 1.5 kernel returns 0, newer ones return # of samples queued
		if (ret < 0) lprintf("sthr: play: ret %08x; pos %i/%i\n", ret, samples_done, samples_made);

		samples_done += samples_block;
		snd_playptr  += samples_block;
		if (snd_playptr >= sndBuffer_endptr)
			snd_playptr -= sndBuffer_endptr - sndBuffer;
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
	samples_block = 2*22050/60; // make sure it goes to sema
	sound_thread_exit = 0;
	thid = sceKernelCreateThread("sndthread", sound_thread, 0x12, 0x1000, 0, NULL);
	if (thid >= 0)
	{
		ret = sceKernelStartThread(thid, 0, 0);
		if (ret < 0) lprintf("sound_init: sceKernelStartThread returned %08x\n", ret);
	}
	else
		lprintf("sceKernelCreateThread failed: %i\n", thid);
}

#define PSP_RATE 44100 // PicoIn.sndRate

void pemu_sound_start(void)
{
	static int PsndRate_old = 0, PicoOpt_old = 0, pal_old = 0;
	static int mp3_init_done;
	int ret, stereo, factor;

	samples_made = samples_done = 0;

	if (!(currentConfig.EmuOpt & EOPT_EN_SOUND))
		return;

	if (PicoIn.AHW & PAHW_MCD) {
		// mp3...
		if (!mp3_init_done) {
			ret = mp3_init();
			mp3_init_done = 1;
			if (ret) emu_status_msg("mp3 init failed (%i)", ret);
		}
	}

	ret = POPT_EN_FM|POPT_EN_PSG|POPT_EN_STEREO;
	if (PicoIn.sndRate != PsndRate_old || (PicoIn.opt&ret) != (PicoOpt_old&ret) || Pico.m.pal != pal_old) {
		PsndRerate(Pico.m.frame_count ? 1 : 0);
	}
	stereo = (PicoIn.opt&8)>>3;

	// PSP doesn't support mono in SRC, always use stereo and convert
	factor = PSP_RATE / PicoIn.sndRate;
	samples_block = (PSP_RATE / (Pico.m.pal ? 50 : 60)) * 2;

	lprintf("starting audio: %i, len: %i, stereo: %i, pal: %i, block samples: %i\n",
			PicoIn.sndRate, Pico.snd.len, stereo, Pico.m.pal, samples_block);

	ret = sceAudioSRCChReserve(samples_block/2, PSP_RATE, 2); // seems to not need that stupid 64byte alignment
	if (ret < 0) {
		lprintf("sceAudioSRCChReserve() failed: %i\n", ret);
		emu_status_msg("sound init failed (%i), snd disabled", ret);
		currentConfig.EmuOpt &= ~EOPT_EN_SOUND;
	} else {
		switch (factor) {
		case 1: PicoIn.writeSound = stereo ? writeSound_44100_stereo:writeSound_44100_mono; break;
		case 2: PicoIn.writeSound = stereo ? writeSound_22050_stereo:writeSound_22050_mono; break;
		case 4: PicoIn.writeSound = stereo ? writeSound_11025_stereo:writeSound_11025_mono; break;
		}
		sndBuffer_endptr = sndBuffer + (SOUND_BLOCK_COUNT-1)*samples_block;
		snd_playptr = sndBuffer_ptr = sndBuffer;
		PicoIn.sndOut = (factor == 1 && stereo ? sndBuffer_ptr : sndBuffer_emu);

		// push one audio block to cover time to first frame audio
//		memset32(PicoIn.sndOut, 0, samples_block/2);
//		writeSound(samples_block*2);

		PsndRate_old = PicoIn.sndRate;
		PicoOpt_old  = PicoIn.opt;
		pal_old = Pico.m.pal;
	}
}

void pemu_sound_stop(void)
{
	int i;
	if (samples_done == 0)
	{
		// if no data is written between sceAudioSRCChReserve and sceAudioSRCChRelease calls,
		// we get a deadlock on next sceAudioSRCChReserve call
		// so this is yet another workaround:
		memset32((int *)(void *)sndBuffer, 0, samples_block*4/4);
		samples_made = samples_block * 3;
		sceKernelSignalSema(sound_sem, 1);
	}
	sceKernelDelayThread(100*1000);
	samples_made = samples_done = 0;
	for (i = 0; sceAudioOutput2GetRestSample() > 0 && i < 16; i++)
		psp_msleep(100);
	sceAudioSRCChRelease();
}

static void sound_deinit(void)
{
	sound_thread_exit = 1;
	sceKernelSignalSema(sound_sem, 1);
	sceKernelDeleteSema(sound_sem);
	sound_sem = -1;
}

/* set default configuration values */
void pemu_prep_defconfig(void)
{
	defaultConfig.s_PsndRate = 22050;
	defaultConfig.s_PicoCDBuffers = 64;
	defaultConfig.CPUclock = 333;
	defaultConfig.filter = EOPT_FILTER_BILINEAR; // bilinear filtering
	defaultConfig.scaling = EOPT_SCALE_43;
	defaultConfig.vscaling = EOPT_VSCALE_FULL;
	defaultConfig.renderer = RT_8BIT_ACC;
	defaultConfig.renderer32x = RT_8BIT_FAST;
	defaultConfig.EmuOpt |= EOPT_SHOW_RTC;
}

/* check configuration for inconsistencies */
void pemu_validate_config(void)
{
	if (currentConfig.CPUclock < 33 || currentConfig.CPUclock > 333)
		currentConfig.CPUclock = 333;
	if (currentConfig.gamma < -4 || currentConfig.gamma >  16)
		currentConfig.gamma = 0;
	if (currentConfig.gamma2 < 0 || currentConfig.gamma2 > 2)
		currentConfig.gamma2 = 0;
}

/* finalize rendering a frame */
void pemu_finalize_frame(const char *fps, const char *notice)
{
	int emu_opt = currentConfig.EmuOpt;

	if (PicoIn.AHW & PAHW_PICO) {
		int h = out_h, w = out_w;
		u16 *pd = g_screen_ptr + out_y*g_screen_ppitch + out_x;

		if (pico_inp_mode && is_16bit_mode())
			emu_pico_overlay(pd, w, h, g_screen_ppitch);
		if (pico_inp_mode /*== 2 || overlay*/)
			draw_pico_ptr();
	}

	// draw virtual keyboard on display
	if (kbd_mode && currentConfig.keyboard == 2 && vkbd)
		vkbd_draw(vkbd);

	osd_buf_cnt = 0;
	if (notice)
		osd_text(4, notice);
	if (emu_opt & EOPT_SHOW_FPS)
		osd_text(OSD_FPS_X, fps);

	osd_cdleds = 0;
	if ((emu_opt & EOPT_EN_CD_LEDS) && (PicoIn.AHW & PAHW_MCD))
		cd_leds();

	sceKernelDcacheWritebackAll();
}

/* FIXME: move plat_* to plat? */

void plat_debug_cat(char *str)
{
}

/* platform dependend emulator initialization */
void plat_init(void)
{
	flip_after_sync = 1;
	psp_menu_init();
	in_psp_init(in_psp_defbinds);
	in_probe();
	sound_init();
	plat_get_data_dir(rom_fname_loaded, sizeof(rom_fname_loaded));
}

/* platform dependend emulator deinitialization */
void plat_finish(void)
{
	sound_deinit();
}

/* display emulator status messages before holding emulation */
void plat_status_msg_busy_first(const char *msg)
{
	plat_status_msg_busy_next(msg);
}

void plat_status_msg_busy_next(const char *msg)
{
	plat_status_msg_clear();
	pemu_finalize_frame("", msg);
	// flip twice since our GU pipeline has one frame delay
	plat_video_flip();
	plat_video_flip();
	emu_status_msg("");
	reset_timing = 1;
}

void plat_status_msg_busy_done(void)
{
}

/* clear status message area */
void plat_status_msg_clear(void)
{
	// not needed since the screen buf is cleared through the GU
}

/* change the audio volume setting */
void plat_update_volume(int has_changed, int is_up)
{
}

/* prepare for MD screen mode change */
void emu_video_mode_change(int start_line, int line_count, int start_col, int col_count)
{
	int h43 = (col_count  >= 192 ? 320 : col_count); // ugh, mind GG...
	int v43 = (line_count >= 192 ? Pico.m.pal ? 240 : 224 : line_count);

	out_y = start_line; out_x = start_col;
	out_h = line_count; out_w = col_count;

	if (col_count == 248) // mind aspect ratio when blanking 1st column
		col_count = 256;

	switch (currentConfig.vscaling) {
	case EOPT_VSCALE_FULL:
		line_count = v43;
		vscale = (float)270/line_count;
		break;
	case EOPT_VSCALE_NOBORDER:
		vscale = (float)270/line_count;
		break;
	default:
		vscale = 1;
		break;
	}

	switch (currentConfig.scaling) {
	case EOPT_SCALE_43:
		hscale = (vscale*h43)/col_count;
		break;
	case EOPT_SCALE_STRETCH:
		hscale = (vscale*h43/2 + 480/2)/col_count;
		break;
	case EOPT_SCALE_WIDE:
		hscale = (float)480/col_count;
		break;
	default:
		hscale = vscale;
		break;
	}

	vidResetMode();
}

/* render one frame in RGB */
void pemu_forced_frame(int no_scale, int do_emu)
{
	Pico.m.dirtyPal = 1;

	if (!no_scale)
		no_scale = currentConfig.scaling == EOPT_SCALE_NONE;
	emu_cmn_forced_frame(no_scale, do_emu, g_screen_ptr);
}

/* clear all video buffers to remove remnants in borders */
void plat_video_clear_buffers(void)
{
	// not needed since output buffer is cleared in flip anyway
}

/* change the platform output rendering */
void plat_video_toggle_renderer(int change, int is_menu_call)
{
	change_renderer(change);

	if (is_menu_call)
		return;

	apply_renderer();
	vidResetMode();
	rendstatus_old = -1;

	if (PicoIn.AHW & PAHW_32X)
		emu_status_msg(renderer_names32x[get_renderer()]);
	else
		emu_status_msg(renderer_names[get_renderer()]);
}

/* set the buffer for emulator output rendering */
void plat_video_set_buffer(void *buf)
{
	if (is_16bit_mode())
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_ppitch * 2);
	else
		PicoDrawSetOutBuf(g_screen_ptr, g_screen_ppitch);
}

/* prepare for emulator output rendering */
void plat_video_loop_prepare(void) 
{
	apply_renderer();
	vidResetMode();
}

/* prepare for entering the emulator loop */
void pemu_loop_prep(void)
{
}

/* terminate the emulator loop */
void pemu_loop_end(void)
{
	pemu_sound_stop();
}

/* resume from suspend: change to main menu if emu was running */
void emu_handle_resume(void)
{
	if (engineState == PGS_Running)
		engineState = PGS_Menu;
}

