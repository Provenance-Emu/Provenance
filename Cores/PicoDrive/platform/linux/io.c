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

#include "../libpicofe/menu.h"
#include "../libpicofe/input.h"
#include "../common/emu.h"
#include "../common/input_pico.h"
#include "version.h"

#include "log_io.h"

int current_keys;

#ifdef FBDEV

#include "fbdev.h"

#else

#include <pthread.h>
#include <semaphore.h>

static int current_bpp = 16;
static int current_pal[256];
static const char *verstring = "PicoDrive " VERSION;
static int scr_changed = 0, scr_w = 320, scr_h = 240;

/* faking GP2X pad */
enum  { GP2X_UP=0x1,       GP2X_LEFT=0x4,       GP2X_DOWN=0x10,  GP2X_RIGHT=0x40,
        GP2X_START=1<<8,   GP2X_SELECT=1<<9,    GP2X_L=1<<10,    GP2X_R=1<<11,
        GP2X_A=1<<12,      GP2X_B=1<<13,        GP2X_X=1<<14,    GP2X_Y=1<<15,
        GP2X_VOL_UP=1<<23, GP2X_VOL_DOWN=1<<22, GP2X_PUSH=1<<27 };

static void key_press_event(int keycode)
{
	switch (keycode)
	{
		case 111:
		case 0x62: current_keys |= GP2X_UP;    break;
		case 116:
		case 0x68: current_keys |= GP2X_DOWN;  break;
		case 113:
		case 0x64: current_keys |= GP2X_LEFT;  break;
		case 114:
		case 0x66: current_keys |= GP2X_RIGHT; break;
		case 0x24: current_keys |= GP2X_START; break; // enter
		case 0x23: current_keys |= GP2X_SELECT;break; // ]
		case 0x34: current_keys |= GP2X_A;     break; // z
		case 0x35: current_keys |= GP2X_X;     break; // x
		case 0x36: current_keys |= GP2X_B;     break; // c
		case 0x37: current_keys |= GP2X_Y;     break; // v
		case 0x27: current_keys |= GP2X_L;     break; // s
		case 0x28: current_keys |= GP2X_R;     break; // d
		case 0x29: current_keys |= GP2X_PUSH;  break; // f
		case 0x18: current_keys |= GP2X_VOL_DOWN;break; // q
		case 0x19: current_keys |= GP2X_VOL_UP;break; // w
		case 0x2d: log_io_clear(); break; // k
		case 0x2e: log_io_dump();  break; // l
		case 0x17: { // tab
			extern int PicoReset(void);
			PicoReset();
			break;
		}
	}
}

static void key_release_event(int keycode)
{
	switch (keycode)
	{
		case 111:
		case 0x62: current_keys &= ~GP2X_UP;    break;
		case 116:
		case 0x68: current_keys &= ~GP2X_DOWN;  break;
		case 113:
		case 0x64: current_keys &= ~GP2X_LEFT;  break;
		case 114:
		case 0x66: current_keys &= ~GP2X_RIGHT; break;
		case 0x24: current_keys &= ~GP2X_START; break; // enter
		case 0x23: current_keys &= ~GP2X_SELECT;break; // ]
		case 0x34: current_keys &= ~GP2X_A;     break; // z
		case 0x35: current_keys &= ~GP2X_X;     break; // x
		case 0x36: current_keys &= ~GP2X_B;     break; // c
		case 0x37: current_keys &= ~GP2X_Y;     break; // v
		case 0x27: current_keys &= ~GP2X_L;     break; // s
		case 0x28: current_keys &= ~GP2X_R;     break; // d
		case 0x29: current_keys &= ~GP2X_PUSH;  break; // f
		case 0x18: current_keys &= ~GP2X_VOL_DOWN;break; // q
		case 0x19: current_keys &= ~GP2X_VOL_UP;break; // w
	}
}

/* --- */

#include <X11/Xlib.h>
#include <X11/Xutil.h>

static Display *xlib_display;
static Window xlib_window;
static XImage *ximage;

static void ximage_realloc(Display *display, Visual *visual)
{
	void *xlib_screen;

	XLockDisplay(xlib_display);

	if (ximage != NULL)
		XDestroyImage(ximage);
	ximage = NULL;

	xlib_screen = calloc(scr_w * scr_h, 4);
	if (xlib_screen != NULL)
		ximage = XCreateImage(display, visual, 24, ZPixmap, 0,
				xlib_screen, scr_w, scr_h, 32, 0);
	if (ximage == NULL)
		fprintf(stderr, "failed to alloc ximage\n");

	XUnlockDisplay(xlib_display);
}

static void xlib_update(void)
{
	Status xstatus;

	XLockDisplay(xlib_display);

	xstatus = XPutImage(xlib_display, xlib_window, DefaultGC(xlib_display, 0), ximage,
		0, 0, 0, 0, g_screen_width, g_screen_height);
	if (xstatus != 0)
		fprintf(stderr, "XPutImage %d\n", xstatus);

	XUnlockDisplay(xlib_display);
}

static void *xlib_threadf(void *targ)
{
	unsigned int width, height, display_width, display_height;
	sem_t *sem = targ;
	XTextProperty windowName;
	Window win;
	XEvent report;
	Display *display;
	Visual *visual;
	int screen;

	XInitThreads();

	xlib_display = display = XOpenDisplay(NULL);
	if (display == NULL)
	{
		fprintf(stderr, "cannot connect to X server %s\n",
				XDisplayName(NULL));
		sem_post(sem);
		return NULL;
	}

	visual = DefaultVisual(display, 0);
	if (visual->class != TrueColor)
	{
		fprintf(stderr, "cannot handle non true color visual\n");
		XCloseDisplay(display);
		sem_post(sem);
		return NULL;
	}

	printf("X vendor: %s, rel: %d, display: %s, protocol ver: %d.%d\n", ServerVendor(display),
		VendorRelease(display), DisplayString(display), ProtocolVersion(display),
		ProtocolRevision(display));

	screen = DefaultScreen(display);

	ximage_realloc(display, visual);
	sem_post(sem);

	display_width = DisplayWidth(display, screen);
	display_height = DisplayHeight(display, screen);

	xlib_window = win = XCreateSimpleWindow(display,
			RootWindow(display, screen),
			display_width / 2 - scr_w / 2,
			display_height / 2 - scr_h / 2,
			scr_w + 2, scr_h + 2, 1,
			BlackPixel(display, screen),
			BlackPixel(display, screen));

	XStringListToTextProperty((char **)&verstring, 1, &windowName);
	XSetWMName(display, win, &windowName);

	XSelectInput(display, win, ExposureMask |
			KeyPressMask | KeyReleaseMask |
			StructureNotifyMask);

	XMapWindow(display, win);

	while (1)
	{
		XNextEvent(display, &report);
		switch (report.type)
		{
			case Expose:
				while (XCheckTypedEvent(display, Expose, &report))
					;
				xlib_update();
				break;

			case ConfigureNotify:
				width = report.xconfigure.width;
				height = report.xconfigure.height;
				if (scr_w != width - 2 || scr_h != height - 2) {
					scr_w = width - 2;
					scr_h = height - 2;
					scr_changed = 1;
				}
				break;

			case ButtonPress:
				break;

			case KeyPress:
				key_press_event(report.xkey.keycode);
				break;

			case KeyRelease:
				key_release_event(report.xkey.keycode);
				break;

			default:
				break;
		}
	}
}

static void xlib_init(void)
{
	pthread_t x_thread;
	sem_t xlib_sem;

	sem_init(&xlib_sem, 0, 0);

	pthread_create(&x_thread, NULL, xlib_threadf, &xlib_sem);
	pthread_detach(x_thread);

	sem_wait(&xlib_sem);
	sem_destroy(&xlib_sem);
}

/* --- */

static void realloc_screen(void)
{
	int size = scr_w * scr_h * 2;
	g_screen_width = g_menuscreen_w = scr_w;
	g_screen_height = g_menuscreen_h = scr_h;
	g_screen_ptr = realloc(g_screen_ptr, size);
	g_menubg_ptr = realloc(g_menubg_ptr, size);
	memset(g_screen_ptr, 0, size);
	memset(g_menubg_ptr, 0, size);
	scr_changed = 0;
}

void plat_video_flip(void)
{
	unsigned int *image;
	int pixel_count, i;

	if (ximage == NULL)
		return;

	pixel_count = g_screen_width * g_screen_height;
	image = (void *)ximage->data;

	if (current_bpp == 8)
	{
		unsigned char *pixels = g_screen_ptr;
		int pix;

		for (i = 0; i < pixel_count; i++)
		{
			pix = current_pal[pixels[i]];
			image[i] = pix;
		}
	}
	else
	{
		unsigned short *pixels = g_screen_ptr;

		for (i = 0; i < pixel_count; i++)
		{
			/*  in:           rrrr rggg gggb bbbb */
			/* out: rrrr r000 gggg gg00 bbbb b000 */
			image[i]  = (pixels[i] << 8) & 0xf80000;
			image[i] |= (pixels[i] << 5) & 0x00fc00;
			image[i] |= (pixels[i] << 3) & 0x0000f8;
		}
	}
	xlib_update();

	if (scr_changed) {
		realloc_screen();
		ximage_realloc(xlib_display, DefaultVisual(xlib_display, 0));

		// propagate new ponters to renderers
		plat_video_toggle_renderer(0, 0);
	}
}

void plat_video_wait_vsync(void)
{
}

#endif // !FBDEV

void plat_early_init(void)
{
}

void plat_init(void)
{
#ifdef FBDEV
	int ret, w, h;
	ret = vout_fbdev_init(&w, &h);
	if (ret != 0)
		exit(1);
	g_screen_width = g_menuscreen_w = w;
	g_screen_height = g_menuscreen_h = h;
	g_menubg_ptr = realloc(g_menubg_ptr, w * g_screen_height * 2);
#else
	realloc_screen();
	memset(g_screen_ptr, 0, g_screen_width * g_screen_height * 2);
	xlib_init();
#endif
}

void plat_finish(void)
{
#ifdef FBDEV
	vout_fbdev_finish();
#else
	free(g_screen_ptr);
#endif
}

/* misc */
int mp3_get_bitrate(void *f, int size)
{
	return 128;
}

void mp3_start_play(void *f, int pos)
{
}

void mp3_update(int *buffer, int length, int stereo)
{
}

#include <linux/input.h>

struct in_default_bind in_evdev_defbinds[] =
{
	/* MXYZ SACB RLDU */
	{ KEY_UP,	IN_BINDTYPE_PLAYER12, 0 },
	{ KEY_DOWN,	IN_BINDTYPE_PLAYER12, 1 },
	{ KEY_LEFT,	IN_BINDTYPE_PLAYER12, 2 },
	{ KEY_RIGHT,	IN_BINDTYPE_PLAYER12, 3 },
	{ KEY_S,	IN_BINDTYPE_PLAYER12, 4 },	/* B */
	{ KEY_D,	IN_BINDTYPE_PLAYER12, 5 },	/* C */
	{ KEY_A,	IN_BINDTYPE_PLAYER12, 6 },	/* A */
	{ KEY_ENTER,	IN_BINDTYPE_PLAYER12, 7 },
	{ KEY_BACKSLASH, IN_BINDTYPE_EMU, PEVB_MENU },
	{ 0, 0, 0 }
};

