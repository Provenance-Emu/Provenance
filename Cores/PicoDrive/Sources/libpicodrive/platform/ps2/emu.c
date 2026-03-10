/*
 * PicoDrive PS2 frontend
 *
 * (C) fjtrujy,irixxxx, 2024
 */

#include <stddef.h>
#include <malloc.h>

#include <kernel.h>
#include <ps2_joystick_driver.h>
#include <ps2_audio_driver.h>
#include <libpad.h>
#include <gsKit.h>
#include <dmaKit.h>
#include <gsToolkit.h>
#include <gsInline.h>
#include <audsrv.h>

#include "in_ps2.h"
#include "../libpicofe/input.h"
#include "../libpicofe/plat.h"
#include "../libpicofe/menu.h"
#include "../common/input_pico.h"
#include "../common/emu.h"
#include "../common/keyboard.h"

#include <pico/pico_int.h>

#define OSD_FPS_X (gsGlobal->Width - 80)

/* turn black GS Screen */
#define GS_BLACK GS_SETREG_RGBA(0x00, 0x00, 0x00, 0x80)
/* Generic tint color */
#define GS_TEXT GS_SETREG_RGBA(0x80, 0x80, 0x80, 0x80)

static int osd_buf_cnt, osd_cdleds;

static int out_x, out_y;
static int out_w, out_h;
static float hscale, vscale;

static struct in_default_bind in_ps2_defbinds[] =
{
	{ PAD_UP,          IN_BINDTYPE_PLAYER12, GBTN_UP },
	{ PAD_DOWN,        IN_BINDTYPE_PLAYER12, GBTN_DOWN },
	{ PAD_LEFT,        IN_BINDTYPE_PLAYER12, GBTN_LEFT },
	{ PAD_RIGHT,       IN_BINDTYPE_PLAYER12, GBTN_RIGHT },
	{ PAD_SQUARE,      IN_BINDTYPE_PLAYER12, GBTN_A },
	{ PAD_CROSS,       IN_BINDTYPE_PLAYER12, GBTN_B },
	{ PAD_CIRCLE,      IN_BINDTYPE_PLAYER12, GBTN_C },
	{ PAD_START,       IN_BINDTYPE_PLAYER12, GBTN_START },
	{ PAD_TRIANGLE,    IN_BINDTYPE_EMU, PEVB_SWITCH_RND },
	{ PAD_L1,          IN_BINDTYPE_EMU, PEVB_STATE_SAVE },
	{ PAD_R1,          IN_BINDTYPE_EMU, PEVB_STATE_LOAD },
	{ PAD_SELECT,      IN_BINDTYPE_EMU, PEVB_MENU },
	{ 0, 0, 0 }
};

const char *renderer_names[] = { "16bit accurate", " 8bit accurate", " 8bit fast", NULL };
const char *renderer_names32x[] = { "accurate", "faster", "fastest", NULL };
enum renderer_types { RT_16BIT, RT_8BIT_ACC, RT_8BIT_FAST, RT_COUNT };
static int is_bg_frame;

static GSGLOBAL *gsGlobal;

static GSTEXTURE *g_menuscreen;
static GSPRIMUVPOINT *g_menuscreen_vertices;

static GSTEXTURE *g_screens[2];
static int g_screen_index;
static GSTEXTURE *g_screen;
static GSPRIMUVPOINT *g_screen_vertices;
static void *g_screen_palette;

static GSTEXTURE *osd;
static uint32_t osd_vertices_count;
static GSPRIMUVPOINT *osd_vertices;

static GSTEXTURE *cdleds;
static GSPRIMUVPOINT *cdleds_vertices;

static int vsync_sema_id;
static int32_t vsync_callback_id;
static uint8_t vsync; /* 0 (Disabled), 1 (Enabled), 2 (Dynamic) */

/* sound stuff */
#define SOUND_BLOCK_COUNT    7
#define SOUND_BUFFER_CHUNK   (2*54000/50) // max.rate/min.frames in stereo

static short sndBuffer_emu[SOUND_BUFFER_CHUNK+4]; // 4 for sample rounding overhang
static short __attribute__((aligned(4))) sndBuffer[SOUND_BUFFER_CHUNK*SOUND_BLOCK_COUNT];
static short __attribute__((aligned(4))) nulBuffer[SOUND_BUFFER_CHUNK];
static short *snd_playptr, *sndBuffer_ptr, *sndBuffer_endptr;
static int samples_made, samples_done, samples_block;

static int sound_thread_exit = 0, sound_stopped = 1;
static int32_t sound_sem = -1, sound_mutex = -1;
static uint8_t stack[0x4000] __attribute__((aligned(16)));
extern void *_gp;

static int mp3_init(void) { return 0; }

/* audsrv in ps2sdk has shortcomings:
 * - it has a bug which prevents it from discerning "ringbuffer empty" from
 *   "ringbuffer full", which leads to audio not stopped if all queued samples
 *   have been played. Hence, it repeats the complete ringbuffer over and again.
 * - on audsrv_set_format the ringbuffer is preset to be about 40% filled,
 *   regardless of the data in the buffer at that moment. Old data is played out
 *   if audio play is started.
 * - stopping audio play is keeping any remaining samples in the buffer, which
 *   are played first after the next audio play. There's no method to clear the
 *   ringbuffer.
 *
 * To cope with this, audio samples are always pushed to audsrv to prevent the
 * ringbuffer from emptying, even in the menu. This also avoids stopping audio.
 * Since silence is played in the menu, the behaviour of set_format when leaving
 * the menu is covered since the buffer is filled with silence at that time.
 */

static void writeSound(int len)
{
	int l;

	if (samples_made - samples_done < samples_block * (SOUND_BLOCK_COUNT-2) - 8) {
		samples_made += len / 2;
		sndBuffer_ptr += len / 2;
		l = sndBuffer_ptr - sndBuffer;

		if (sndBuffer_ptr > sndBuffer_endptr)
			sndBuffer_endptr = sndBuffer_ptr;
		if (l > sizeof(sndBuffer)/2)
			lprintf("snd ovrn %d %d\n", len, sndBuffer_ptr - sndBuffer);
		// leave space for block with 1 overhanging sample @11025Hz
		if (l >= samples_block * (SOUND_BLOCK_COUNT-1) - 8) {
			sndBuffer_endptr = sndBuffer_ptr;
			sndBuffer_ptr = sndBuffer;
		}
	} else
		lprintf("ovfl %d\n", samples_made - samples_done);

	// signal the snd thread
	SignalSema(sound_sem);
}

static void writeSound_44100(int len)
{
	writeSound(len);
	PicoIn.sndOut = sndBuffer_ptr;
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

	for (i = 0; i < len / 2; i++, p+=2) {
		p[0] = p[1] = PicoIn.sndOut[i];
	}
	writeSound(2*len);
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

	for (i = 0; i < len / 2; i++, p+=4) {
		p[0] = p[1] = p[2] = p[3] = PicoIn.sndOut[i];
	}
	writeSound(4*len);
}

#define PS2_RATE 44100 // PicoIn.sndRate

static void resetSound()
{
	struct audsrv_fmt_t format;
	int stereo = (PicoIn.opt&8)>>3;
	int ret;

	format.bits = 16;
	format.freq = PS2_RATE;
	format.channels = stereo ? 2 : 1;
	ret = audsrv_set_format(&format);
	if (ret < 0) {
		lprintf("audsrv_set_format() failed: %i\n", ret);
		emu_status_msg("sound init failed (%i), snd disabled", ret);
		currentConfig.EmuOpt &= ~EOPT_EN_SOUND;
	}
}

static int sound_thread(void *argp)
{
	lprintf("sthr: start\n");

	while (!sound_thread_exit)
	{
		int ret = WaitSema(sound_mutex);
		if (ret < 0) lprintf("sthr: WaitSema mutex failed (%d)\n", ret);

		// queue samples to audsrv, minimum 2 frames
		// if there aren't enough samples, queue silence
		int queued = audsrv_queued()/2;
		while (queued < 2*samples_block) {
			// compute sample chunk size
			int buflen = samples_made - samples_done;
			if (snd_playptr >= sndBuffer_endptr)
				snd_playptr -= sndBuffer_endptr - sndBuffer;
			if (buflen > sndBuffer_endptr - snd_playptr)
				buflen = sndBuffer_endptr - snd_playptr;
			if (buflen > 3*samples_block - queued)
				buflen = 3*samples_block - queued;

			// play audio
			if (buflen > 0) {
				ret = audsrv_play_audio((char *)snd_playptr, buflen*2);

				samples_done += buflen;
				snd_playptr  += buflen;
			} else {
				buflen = (3*samples_block - queued) & ~1;
				while (buflen > sizeof(nulBuffer)/2) {
					audsrv_play_audio((char *)nulBuffer, sizeof(nulBuffer));
					buflen -= sizeof(nulBuffer)/2;
				}
				ret = audsrv_play_audio((char *)nulBuffer, buflen*2);
			}
			if (ret != buflen*2 && ret > 0) lprintf("sthr: play ret: %i, buflen: %i\n", ret, buflen*2);
			if (ret < 0) lprintf("sthr: play: ret %08x; pos %i/%i\n", ret, samples_done, samples_made);
			if (ret == 0) resetSound();

			queued = audsrv_queued()/2;
		}

		SignalSema(sound_mutex);
		ret = WaitSema(sound_sem);
		if (ret < 0) lprintf("sthr: WaitSema sound failed (%d)\n", ret);
	}

	lprintf("sthr: exit\n");
	ExitDeleteThread();
	return 0;
}

static void sound_init(void)
{
	int thid;
	int ret;
	ee_sema_t sema;
	ee_thread_t thread;

	sema.max_count  = 1;
	sema.init_count = 0;
	sema.option     = (u32) "sndsem";
	if ((sound_sem = CreateSema(&sema)) < 0)
		return;
	sema.max_count  = 1;
	sema.init_count = 1;
	sema.option     = (u32) "sndmutex";
	if ((sound_mutex = CreateSema(&sema)) < 0)
		return;
	audsrv_init();

	thread.func             = &sound_thread;
	thread.stack            = stack;
	thread.stack_size       = sizeof(stack);
	thread.gp_reg           = &_gp;
	thread.option           = (u32) "sndthread";
	thread.initial_priority = 40;
	thid = CreateThread(&thread);

	samples_block = PS2_RATE/60; // needs to be initialized before thread start
	if (thid >= 0) {
		ret = StartThread(thid, NULL);
		if (ret < 0) lprintf("sound_init: StartThread returned %08x\n", ret);
		ChangeThreadPriority(0, 64);
	} else {
		DeleteSema(sound_sem);
		lprintf("CreateThread failed: %i\n", thid);
	}
}

void pemu_sound_start(void) {
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

	ret = WaitSema(sound_mutex);
	if (ret < 0) lprintf("WaitSema mutex failed (%d)\n", ret);

	ret = POPT_EN_FM|POPT_EN_PSG|POPT_EN_STEREO;
	if (PicoIn.sndRate != PsndRate_old || (PicoIn.opt&ret) != (PicoOpt_old&ret) || Pico.m.pal != pal_old) {
		PsndRerate(Pico.m.frame_count ? 1 : 0);
	}
	stereo = (PicoIn.opt&8)>>3;

	factor = PS2_RATE / PicoIn.sndRate;
	samples_block = (PS2_RATE / (Pico.m.pal ? 50 : 60)) * (stereo ? 2 : 1);

	lprintf("starting audio: %i, len: %i, stereo: %i, pal: %i, block samples: %i\n",
			PicoIn.sndRate, Pico.snd.len, stereo, Pico.m.pal, samples_block);

	resetSound();
	switch (factor) {
	case 1: PicoIn.writeSound = stereo ? writeSound_44100       :writeSound_44100     ; break;
	case 2: PicoIn.writeSound = stereo ? writeSound_22050_stereo:writeSound_22050_mono; break;
	case 4: PicoIn.writeSound = stereo ? writeSound_11025_stereo:writeSound_11025_mono; break;
	}
	sndBuffer_endptr = sndBuffer;
	snd_playptr = sndBuffer_ptr = sndBuffer;
	PicoIn.sndOut = (factor == 1 ? sndBuffer_ptr : sndBuffer_emu);

	PsndRate_old = PicoIn.sndRate;
	PicoOpt_old  = PicoIn.opt;
	pal_old = Pico.m.pal;

	sound_stopped = 0;
	audsrv_play_audio((char *)snd_playptr, 2*2);
	SignalSema(sound_mutex);
}

void pemu_sound_stop(void)
{
	sound_stopped = 1;
	samples_made = samples_done = 0;
}

static void sound_deinit(void)
{
	sound_thread_exit = 1;
	SignalSema(sound_sem);
	DeleteSema(sound_sem);
	sound_sem = -1;
}

#define is_16bit_mode() \
	(currentConfig.renderer == RT_16BIT || (PicoIn.AHW & PAHW_32X) || is_bg_frame)

static int vsync_handler(void)
{
	iSignalSema(vsync_sema_id);
	if (sound_stopped)
		iSignalSema(sound_sem);

	ExitHandler();
	return 0;
}

/* Copy of gsKit_sync_flip, but without the 'sync' */
static void gsKit_flip(GSGLOBAL *gsGlobal)
{
	if (!gsGlobal->FirstFrame)
	{
		if (gsGlobal->DoubleBuffering == GS_SETTING_ON)
		{
			GS_SET_DISPFB2(gsGlobal->ScreenBuffer[gsGlobal->ActiveBuffer & 1] / 8192,
					gsGlobal->Width / 64, gsGlobal->PSM, 0, 0);

			gsGlobal->ActiveBuffer ^= 1;
		}
	}

	gsKit_setactive(gsGlobal);
}

static void flipScreen()
{
	gsKit_flip(gsGlobal);

	gsKit_TexManager_nextFrame(gsGlobal);
}


static void set_g_menuscreen_values(void)
{
	size_t g_menuscreenSize = gsKit_texture_size_ee(gsGlobal->Width, gsGlobal->Height, GS_PSM_CT16);

	g_menuscreen = (GSTEXTURE *)calloc(1, sizeof(GSTEXTURE));
	g_menuscreen->Mem = malloc(g_menuscreenSize);
	g_menuscreen_vertices = (GSPRIMUVPOINT *)calloc(2, sizeof(GSPRIMUVPOINT));

	g_menuscreen->Width = gsGlobal->Width;
	g_menuscreen->Height = gsGlobal->Height;
	g_menuscreen->PSM = GS_PSM_CT16;

	g_menuscreen_w = g_menuscreen->Width;
	g_menuscreen_h  = g_menuscreen->Height;
	g_menuscreen_pp = g_menuscreen->Width;
	g_menuscreen_ptr = g_menuscreen->Mem;

	g_menuscreen_vertices[0].xyz2 = vertex_to_XYZ2(gsGlobal, 0, 0, 2);
	g_menuscreen_vertices[0].uv = vertex_to_UV(g_menuscreen, 0, 0);
	g_menuscreen_vertices[0].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);

	g_menuscreen_vertices[1].xyz2 = vertex_to_XYZ2(gsGlobal, g_menuscreen->Width, g_menuscreen->Height, 2);
	g_menuscreen_vertices[1].uv = vertex_to_UV(g_menuscreen, g_menuscreen->Width, g_menuscreen->Height);
	g_menuscreen_vertices[1].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);
}

void set_g_screen_values() {
	size_t g_screenSize = gsKit_texture_size_ee(328, 256, GS_PSM_CT16);
	int i;

	g_screen_palette = malloc(gsKit_texture_size_ee(16, 16, GS_PSM_CT16));
	g_screen_vertices = (GSPRIMUVPOINT *)calloc(2, sizeof(GSPRIMUVPOINT));
	for (i = 0; i < 2; i++) {
		g_screens[i] = (GSTEXTURE *)calloc(1, sizeof(GSTEXTURE));
		g_screens[i]->Mem = malloc(g_screenSize);

		g_screens[i]->Width = 328;
		g_screens[i]->Height = 256;

		g_screens[i]->Clut = g_screen_palette;
		g_screens[i]->ClutPSM = GS_PSM_CT16;
	}
	g_screen = g_screens[g_screen_index];
	g_screen_ptr = g_screen->Mem;

	g_screen_width = 328;
	g_screen_height = 256;
	g_screen_ppitch = 328;

	g_screen_vertices[0].xyz2 = vertex_to_XYZ2(gsGlobal, 0, 0, 0);
	g_screen_vertices[0].uv = vertex_to_UV(g_screen, 0, 0);
	g_screen_vertices[0].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);

	g_screen_vertices[1].xyz2 = vertex_to_XYZ2(gsGlobal, gsGlobal->Width, gsGlobal->Height, 0);
	g_screen_vertices[1].uv = vertex_to_UV(g_screen, g_screen->Width, g_screen->Height);
	g_screen_vertices[1].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);
}

void set_cdleds_values() {
	size_t cdledsSize = gsKit_texture_size_ee(14, 5, GS_PSM_CT16);

	cdleds = (GSTEXTURE *)calloc(1, sizeof(GSTEXTURE));
	cdleds->Mem = malloc(cdledsSize);
	cdleds_vertices = (GSPRIMUVPOINT *)calloc(2, sizeof(GSPRIMUVPOINT));

	cdleds->Width = 14;
	cdleds->Height = 5;
	cdleds->PSM = GS_PSM_CT16;

	cdleds_vertices[0].xyz2 = vertex_to_XYZ2(gsGlobal, 4, 1, 1);
	cdleds_vertices[0].uv = vertex_to_UV(cdleds, 0, 0);
	cdleds_vertices[0].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);

	cdleds_vertices[1].xyz2 = vertex_to_XYZ2(gsGlobal, cdleds->Width, cdleds->Height, 1);
	cdleds_vertices[1].uv = vertex_to_UV(cdleds, cdleds->Width, cdleds->Height);
	cdleds_vertices[1].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);
}

void set_osd_values() {
	size_t osdSize = gsKit_texture_size_ee(gsGlobal->Width, 8, GS_PSM_CT16);
	int num_osds = 4, i;

	osd = (GSTEXTURE *)calloc(1, sizeof(GSTEXTURE));
	osd->Mem = malloc(osdSize);

	osd_vertices_count = 2*num_osds;
	osd_vertices = (GSPRIMUVPOINT *)calloc(osd_vertices_count, sizeof(GSPRIMUVPOINT));

	osd->Width = gsGlobal->Width;
	osd->Height = 8;
	osd->PSM = GS_PSM_CT16;

	for (i = 0; i < 2*num_osds; i++)
		osd_vertices[i].rgbaq = color_to_RGBAQ(0x80, 0x80, 0x80, 0x80, 0);
}

static void video_init(void)
{
	ee_sema_t sema;

	sema.init_count = 0;
	sema.max_count  = 1;
	sema.option     = 0;

	vsync_sema_id   = CreateSema(&sema);

	gsGlobal = gsKit_init_global();
//	gsGlobal->Mode = GS_MODE_NTSC;
//	gsGlobal->Height = 448;

	gsGlobal->PSM  = GS_PSM_CT16;
	gsGlobal->PSMZ = GS_PSMZ_16S;
	gsGlobal->ZBuffering = GS_SETTING_OFF;
	gsGlobal->DoubleBuffering = GS_SETTING_ON;
	gsGlobal->PrimAlphaEnable = GS_SETTING_OFF;
	gsGlobal->Dithering = GS_SETTING_OFF;


	dmaKit_init(D_CTRL_RELE_OFF, D_CTRL_MFD_OFF, D_CTRL_STS_UNSPEC, D_CTRL_STD_OFF, D_CTRL_RCYC_8, 1 << DMA_CHANNEL_GIF);
	dmaKit_chan_init(DMA_CHANNEL_GIF);

	gsKit_set_clamp(gsGlobal, GS_CMODE_REPEAT);

	gsKit_vram_clear(gsGlobal);
	gsKit_init_screen(gsGlobal);
	gsKit_TexManager_init(gsGlobal);
	gsKit_mode_switch(gsGlobal, GS_ONESHOT);
	gsKit_clear(gsGlobal, GS_BLACK);
	vsync = 0;
	vsync_callback_id = gsKit_add_vsync_handler(vsync_handler);

	set_g_screen_values();
	set_g_menuscreen_values();
	set_osd_values();
	set_cdleds_values();

	g_menubg_ptr = malloc(2 * g_menuscreen_pp * g_menuscreen_h);
	g_menubg_src_w = g_screen->Width;
	g_menubg_src_h = g_screen->Height;
	g_menubg_src_pp = g_screen->Width;
}

static void video_deinit(void)
{
	free(g_screens[0]->Mem);
	free(g_screens[0]);
	free(g_screens[1]->Mem);
	free(g_screens[1]);
	free(g_screen_vertices);
	free(g_screen_palette);

	free(g_menuscreen->Mem);
	free(g_menuscreen);
	free(g_menuscreen_vertices);
	free(g_menubg_ptr);

	free(osd->Mem);
	free(osd);
	free(osd_vertices);

	free(cdleds->Mem);
	free(cdleds);
	free(cdleds_vertices);

	gsKit_clear(gsGlobal, GS_BLACK);
	gsKit_vram_clear(gsGlobal);
	gsKit_deinit_global(gsGlobal);
	gsKit_remove_vsync_handler(vsync_callback_id);

	if (vsync_sema_id >= 0)
		DeleteSema(vsync_sema_id);
}

static void set_scaling_params(void)
{
	int width, height, xoffs, yoffs;
	int u[2], v[2];

	height = (int)(out_h * vscale + 0.5);
	width  = (int)(out_w * hscale + 0.5);

	if (width  & 1) width++;  // make even
	if (height & 1) height++;

	if (width >= gsGlobal->Width) {
		u[0] = out_x + (width-gsGlobal->Width)/2;
		u[1] = out_x + out_w - (width-gsGlobal->Width)/2 - 1;
		width = gsGlobal->Width;
		xoffs = 0;
	} else {
		u[0] = out_x;
		u[1] = out_x + out_w;
		xoffs = gsGlobal->Width/2 - width/2;
	}

	if (height >= gsGlobal->Height) {
		v[0] = out_y + (height-gsGlobal->Height)/2;
		v[1] = out_y + out_h - (height-gsGlobal->Height)/2;
		height = gsGlobal->Height;
		yoffs = 0;
	} else {
		v[0] = out_y;
		v[1] = out_y + out_h;
		yoffs = gsGlobal->Height/2 - height/2;
	}

	if (xoffs < 0) xoffs = 0;
	if (yoffs < 0) yoffs = 0;
	g_screen_vertices[0].xyz2 = vertex_to_XYZ2(gsGlobal, xoffs, yoffs, 0);
	g_screen_vertices[1].xyz2 = vertex_to_XYZ2(gsGlobal, xoffs + width, yoffs + height, 0);

	if (!is_16bit_mode()) {
		// 8-bit modes have an 8 px overlap area on the left
		u[0] += 8; u[1] += 8;
	}
	g_screen_vertices[0].uv = vertex_to_UV(g_screen, u[0], v[0]);
	g_screen_vertices[1].uv = vertex_to_UV(g_screen, u[1], v[1]);

//	lprintf("set_scaling_params: wxh = %ix%i\n",gsGlobal->Width,gsGlobal->Height);
//	lprintf("offs: %i, %i  wh: %i, %i\n", xoffs, yoffs, width, height);
//	lprintf("uv0, uv1: %i, %i; %i, %i\n", u[0], v[0], u[1], v[1]);
}

static void make_ps2_palette(void)
{
	PicoDrawUpdateHighPal();

	// Rotate CLUT. PS2 is special since entries in CLUT are not in sequence.
	unsigned short int *pal=(void *)g_screen_palette;
	int i;

	for (i = 0; i < 256; i+=8) {
		if ((i&0x18) == 0x08)
			memcpy(pal+i,Pico.est.HighPal+i+8,16);
		else if ((i&0x18) == 0x10)
			memcpy(pal+i,Pico.est.HighPal+i-8,16);
		else
			memcpy(pal+i,Pico.est.HighPal+i,16);
	}
}

static int get_renderer(void)
{
	if (is_bg_frame)
		return RT_16BIT;
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

static void blit_screen(void)
{
	if (!is_16bit_mode() && Pico.m.dirtyPal)
		make_ps2_palette();

	g_screen->PSM = is_16bit_mode() ? GS_PSM_CT16 : GS_PSM_T8;
	g_screen->Filter = (currentConfig.filter ? GS_FILTER_LINEAR : GS_FILTER_NEAREST);

	gsKit_TexManager_bind(gsGlobal, g_screen);
	gskit_prim_list_sprite_texture_uv_3d(gsGlobal, g_screen, 2, g_screen_vertices);
}

static void osd_text(int x, const char *text)
{
	void *old_ptr = g_screen_ptr;
	int old_pitch = g_screen_ppitch;

	int len = strlen(text) * 8;
	u16 *osd_buf = (u16 *)osd->Mem;
	int *p, h;

	g_screen_ptr = osd_buf;
	g_screen_ppitch = gsGlobal->Width;
	for (h = 0; h < 8; h++) {
		p = (int *) (osd_buf + x + gsGlobal->Width*h);
		p = (int *) ((int)p & ~3); // align
		memset32_uncached(p, 0, len/2);
	}
	emu_text_out16(x, 0, text);
	g_screen_ptr = old_ptr;
	g_screen_ppitch = old_pitch;

	osd_vertices[osd_buf_cnt].xyz2 = vertex_to_XYZ2(gsGlobal, x, gsGlobal->Height-8, 1);
	osd_vertices[osd_buf_cnt].uv = vertex_to_UV(osd, x, 0);
	osd_vertices[osd_buf_cnt+1].xyz2 = vertex_to_XYZ2(gsGlobal, x+len, gsGlobal->Height, 1);
	osd_vertices[osd_buf_cnt+1].uv = vertex_to_UV(osd, x+len, 8);
	osd_buf_cnt += 2;
}

static void blit_osd(void)
{
	gsKit_TexManager_bind(gsGlobal, osd);
	while (osd_buf_cnt > 0) {
		osd_buf_cnt -= 2;
		gskit_prim_list_sprite_texture_uv_3d(gsGlobal, osd, 2, osd_vertices+osd_buf_cnt);
	}
}

static void cd_leds(void)
{
	unsigned int reg, col_g, col_r, *p;

	reg = Pico_mcd->s68k_regs[0];

	p = (unsigned int *)cdleds->Mem;
	col_g = (reg & 2) ? 0x06000600 : 0;
	col_r = (reg & 1) ? 0x00180018 : 0;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += gsGlobal->Width/2 - 12/2;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r; p += gsGlobal->Width/2 - 12/2;
	*p++ = col_g; *p++ = col_g; p+=2; *p++ = col_r; *p++ = col_r;

	osd_cdleds = 1;
}

static void blit_cdleds(void)
{
	if (!osd_cdleds) return;

	gsKit_TexManager_bind(gsGlobal, cdleds);
	gskit_prim_list_sprite_texture_uv_3d(gsGlobal, cdleds, 2, cdleds_vertices);
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
		int o = (up ? 0x0000 : 0x7fff), _ = (up ? 0x7fff : 0x0000);

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
	set_scaling_params();

	Pico.m.dirtyPal = 1;
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
	if (notice)      osd_text(4, notice);
	if (emu_opt & 2) osd_text(OSD_FPS_X, fps);

	osd_cdleds = 0;
	if ((emu_opt & 0x400) && (PicoIn.AHW & PAHW_MCD))
		cd_leds();

	FlushCache(WRITEBACK_DCACHE);
}

/* clear all video buffers to remove remnants in borders */
void plat_video_clear_buffers(void)
{
	// not needed since output buffer is cleared in flip anyway
}

/* display a completed frame buffer and prepare a new render buffer */
void plat_video_flip(void)
{
	gsKit_TexManager_invalidate(gsGlobal, osd);
	gsKit_TexManager_invalidate(gsGlobal, cdleds);
	gsKit_TexManager_invalidate(gsGlobal, g_screen);

	gsKit_finish();
	flipScreen();

	gsKit_clear(gsGlobal, GS_BLACK);
	blit_screen();
	blit_osd();
	blit_cdleds();
	gsKit_queue_exec(gsGlobal);

	g_screen_index ^= 1;
	g_screen = g_screens[g_screen_index];
	g_screen_ptr = g_screen->Mem;

	plat_video_set_buffer(g_screen_ptr);
}

/* wait for start of vertical blanking */
void plat_video_wait_vsync(void)
{
	while (PollSema(vsync_sema_id) >= 0);

	if (!gsGlobal->FirstFrame)
		WaitSema(vsync_sema_id);
	
}

/* update surface data */
void plat_video_menu_update(void)
{
	// surface is always the screen
}

/* switch from emulation display to menu display */
void plat_video_menu_enter(int is_rom_loaded)
{
}

/* start rendering a menu screen */
void plat_video_menu_begin(void)
{
}

/* display a completed menu screen */
void plat_video_menu_end(void)
{
	gsKit_TexManager_bind(gsGlobal, g_menuscreen);
	gskit_prim_list_sprite_texture_uv_3d( gsGlobal, g_menuscreen, 2, g_menuscreen_vertices);
	gsKit_queue_exec(gsGlobal);
	gsKit_finish();
	gsKit_TexManager_invalidate(gsGlobal, g_menuscreen);

	flipScreen();
}

/* terminate menu display */
void plat_video_menu_leave(void)
{
	g_screen_ptr = g_screen->Mem;
	plat_video_set_buffer(g_screen_ptr);
}

/* set default configuration values */
void pemu_prep_defconfig(void)
{
	defaultConfig.s_PsndRate = 22050;
	defaultConfig.s_PicoCDBuffers = 64;
	defaultConfig.filter = EOPT_FILTER_BILINEAR; // bilinear filtering
	defaultConfig.scaling = EOPT_SCALE_43;
	defaultConfig.vscaling = EOPT_VSCALE_FULL;
	defaultConfig.renderer = RT_8BIT_ACC;
	defaultConfig.renderer32x = RT_8BIT_ACC;
	defaultConfig.EmuOpt |= EOPT_SHOW_RTC;
}

/* check configuration for inconsistencies */
void pemu_validate_config(void)
{
}

void plat_init(void)
{
	video_init();
	init_joystick_driver(false);

	flip_after_sync = 1;
	in_ps2_init(in_ps2_defbinds);
	in_probe();
	init_audio_driver();
	sound_init();
	plat_get_data_dir(rom_fname_loaded, sizeof(rom_fname_loaded));
}

void plat_finish(void) {
	sound_deinit();
	deinit_audio_driver();
	deinit_joystick_driver(false);
	video_deinit();
}

/* display emulator status messages while holding emulation */
void plat_status_msg_busy_first(const char *msg)
{
	// stop sound to make sure silence is played
	pemu_sound_stop();
	plat_status_msg_busy_next(msg);
}

void plat_status_msg_busy_next(const char *msg)
{
	pemu_finalize_frame("", msg);
	// flip twice since our gskit pipeline has one frame delay
	plat_video_flip();
	plat_video_flip();
	emu_status_msg("");
	reset_timing = 1;
}

void plat_status_msg_busy_done(void)
{
	pemu_sound_start();
}

/* clear status message area */
void plat_status_msg_clear(void)
{
	// not needed since the screen buf is cleared through the gskit_clear
}

/* change the audio volume setting */
void plat_update_volume(int has_changed, int is_up) {}

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
		vscale = (float)gsGlobal->Height/line_count;
		break;
	case EOPT_VSCALE_NOBORDER:
		vscale = (float)gsGlobal->Height/line_count;
		break;
	default:
		vscale = 1;
		break;
	}

	hscale = vscale * (gsGlobal->Aspect == GS_ASPECT_16_9 ? (4./3)/(16./9) : 1);
	switch (currentConfig.scaling) {
	case EOPT_SCALE_43:
		hscale = (hscale*h43)/col_count;
		break;
	case EOPT_SCALE_STRETCH:
		hscale = (hscale*h43/2 + gsGlobal->Width/2)/col_count;
		break;
	case EOPT_SCALE_WIDE:
		hscale = (float)gsGlobal->Width/col_count;
		break;
	default:
		// hscale = vscale, computed before switch
		break;
	}

	vidResetMode();
}

/* render one frame in RGB */
void pemu_forced_frame(int no_scale, int do_emu)
{
	is_bg_frame = 1;
	Pico.m.dirtyPal = 1;

	if (!no_scale)
		no_scale = currentConfig.scaling == EOPT_SCALE_NONE;
	emu_cmn_forced_frame(no_scale, do_emu, g_screen_ptr);

	g_menubg_src_ptr = g_screen_ptr;
	is_bg_frame = 0;
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
	pemu_forced_frame(0, 1);
}
