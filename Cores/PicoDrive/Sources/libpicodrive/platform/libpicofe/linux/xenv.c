/*
 * (C) Gražvydas "notaz" Ignotas, 2009-2012
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#include <stdio.h>
#include <string.h>
#include <pthread.h>

#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/XKBlib.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <linux/kd.h>

#include "xenv.h"

#define PFX "xenv: "

#define FPTR(f) typeof(f) * p##f
#define FPTR_LINK(xf, dl, f) { \
	xf.p##f = dlsym(dl, #f); \
	if (xf.p##f == NULL) { \
		fprintf(stderr, "missing symbol: %s\n", #f); \
		goto fail; \
	} \
}

struct xstuff {
	Display *display;
	Window window;
	FPTR(XCreateBitmapFromData);
	FPTR(XCreatePixmapCursor);
	FPTR(XFreePixmap);
	FPTR(XOpenDisplay);
	FPTR(XDisplayName);
	FPTR(XCloseDisplay);
	FPTR(XCreateSimpleWindow);
	FPTR(XChangeWindowAttributes);
	FPTR(XSelectInput);
	FPTR(XMapWindow);
	FPTR(XNextEvent);
	FPTR(XCheckTypedEvent);
	FPTR(XWithdrawWindow);
	FPTR(XGrabKeyboard);
	FPTR(XPending);
	FPTR(XLookupKeysym);
	FPTR(XkbSetDetectableAutoRepeat);
	FPTR(XStoreName);
	FPTR(XIconifyWindow);
	FPTR(XMoveResizeWindow);
	FPTR(XInternAtom);
	FPTR(XSetWMHints);
	FPTR(XSync);
};

static struct xstuff g_xstuff;

static Cursor transparent_cursor(struct xstuff *xf, Display *display, Window win)
{
	Cursor cursor;
	Pixmap pix;
	XColor dummy;
	char d = 0;

	memset(&dummy, 0, sizeof(dummy));
	pix = xf->pXCreateBitmapFromData(display, win, &d, 1, 1);
	cursor = xf->pXCreatePixmapCursor(display, pix, pix,
			&dummy, &dummy, 0, 0);
	xf->pXFreePixmap(display, pix);
	return cursor;
}

static int x11h_init(int *xenv_flags, const char *window_title)
{
	unsigned int display_width, display_height;
	Display *display;
	XSetWindowAttributes attributes;
	Window win;
	Visual *visual;
	long evt_mask;
	void *x11lib;
	int screen;

	memset(&g_xstuff, 0, sizeof(g_xstuff));
	x11lib = dlopen("libX11.so.6", RTLD_LAZY);
	if (x11lib == NULL) {
		fprintf(stderr, "libX11.so load failed:\n%s\n", dlerror());
		goto fail;
	}
	FPTR_LINK(g_xstuff, x11lib, XCreateBitmapFromData);
	FPTR_LINK(g_xstuff, x11lib, XCreatePixmapCursor);
	FPTR_LINK(g_xstuff, x11lib, XFreePixmap);
	FPTR_LINK(g_xstuff, x11lib, XOpenDisplay);
	FPTR_LINK(g_xstuff, x11lib, XDisplayName);
	FPTR_LINK(g_xstuff, x11lib, XCloseDisplay);
	FPTR_LINK(g_xstuff, x11lib, XCreateSimpleWindow);
	FPTR_LINK(g_xstuff, x11lib, XChangeWindowAttributes);
	FPTR_LINK(g_xstuff, x11lib, XSelectInput);
	FPTR_LINK(g_xstuff, x11lib, XMapWindow);
	FPTR_LINK(g_xstuff, x11lib, XNextEvent);
	FPTR_LINK(g_xstuff, x11lib, XCheckTypedEvent);
	FPTR_LINK(g_xstuff, x11lib, XWithdrawWindow);
	FPTR_LINK(g_xstuff, x11lib, XGrabKeyboard);
	FPTR_LINK(g_xstuff, x11lib, XPending);
	FPTR_LINK(g_xstuff, x11lib, XLookupKeysym);
	FPTR_LINK(g_xstuff, x11lib, XkbSetDetectableAutoRepeat);
	FPTR_LINK(g_xstuff, x11lib, XStoreName);
	FPTR_LINK(g_xstuff, x11lib, XIconifyWindow);
	FPTR_LINK(g_xstuff, x11lib, XMoveResizeWindow);
	FPTR_LINK(g_xstuff, x11lib, XInternAtom);
	FPTR_LINK(g_xstuff, x11lib, XSetWMHints);
	FPTR_LINK(g_xstuff, x11lib, XSync);

	//XInitThreads();

	g_xstuff.display = display = g_xstuff.pXOpenDisplay(NULL);
	if (display == NULL)
	{
		fprintf(stderr, "cannot connect to X server %s, X handling disabled.\n",
				g_xstuff.pXDisplayName(NULL));
		goto fail2;
	}

	visual = DefaultVisual(display, 0);
	if (visual->class != TrueColor)
		fprintf(stderr, PFX "warning: non true color visual\n");

	printf(PFX "X vendor: %s, rel: %d, display: %s, protocol ver: %d.%d\n", ServerVendor(display),
		VendorRelease(display), DisplayString(display), ProtocolVersion(display),
		ProtocolRevision(display));

	screen = DefaultScreen(display);

	display_width = DisplayWidth(display, screen);
	display_height = DisplayHeight(display, screen);
	printf(PFX "display is %dx%d\n", display_width, display_height);

	g_xstuff.window = win = g_xstuff.pXCreateSimpleWindow(display,
		RootWindow(display, screen), 0, 0, display_width, display_height,
		0, BlackPixel(display, screen), BlackPixel(display, screen));

	attributes.override_redirect = True;
	attributes.cursor = transparent_cursor(&g_xstuff, display, win);
	g_xstuff.pXChangeWindowAttributes(display, win, CWOverrideRedirect | CWCursor, &attributes);

	if (window_title != NULL)
		g_xstuff.pXStoreName(display, win, window_title);
	evt_mask = ExposureMask | FocusChangeMask | PropertyChangeMask;
	if (xenv_flags && (*xenv_flags & XENV_CAP_KEYS))
		evt_mask |= KeyPressMask | KeyReleaseMask;
	if (xenv_flags && (*xenv_flags & XENV_CAP_MOUSE))
		evt_mask |= ButtonPressMask | ButtonReleaseMask | PointerMotionMask;
	g_xstuff.pXSelectInput(display, win, evt_mask);
	g_xstuff.pXMapWindow(display, win);
	g_xstuff.pXGrabKeyboard(display, win, False, GrabModeAsync, GrabModeAsync, CurrentTime);
	g_xstuff.pXkbSetDetectableAutoRepeat(display, 1, NULL);
	// XSetIOErrorHandler

	// we don't know when event dispatch will be called, so sync now
	g_xstuff.pXSync(display, False);

	return 0;
fail2:
	dlclose(x11lib);
fail:
	g_xstuff.display = NULL;
	fprintf(stderr, "x11 handling disabled.\n");
	return -1;
}

static void x11h_update(int (*key_cb)(void *cb_arg, int kc, int is_pressed),
			int (*mouseb_cb)(void *cb_arg, int x, int y, int button, int is_pressed),
			int (*mousem_cb)(void *cb_arg, int x, int y),
			void *cb_arg)
{
	XEvent evt;
	int keysym;

	while (g_xstuff.pXPending(g_xstuff.display))
	{
		g_xstuff.pXNextEvent(g_xstuff.display, &evt);
		switch (evt.type)
		{
		case Expose:
			while (g_xstuff.pXCheckTypedEvent(g_xstuff.display, Expose, &evt))
				;
			break;

		case KeyPress:
			keysym = g_xstuff.pXLookupKeysym(&evt.xkey, 0);
			if (key_cb != NULL)
				key_cb(cb_arg, keysym, 1);
			break;

		case KeyRelease:
			keysym = g_xstuff.pXLookupKeysym(&evt.xkey, 0);
			if (key_cb != NULL)
				key_cb(cb_arg, keysym, 0);
			break;

		case ButtonPress:
			if (mouseb_cb != NULL)
				mouseb_cb(cb_arg, evt.xbutton.x, evt.xbutton.y,
					  evt.xbutton.button, 1);
			break;

		case ButtonRelease:
			if (mouseb_cb != NULL)
				mouseb_cb(cb_arg, evt.xbutton.x, evt.xbutton.y,
					  evt.xbutton.button, 0);
			break;

		case MotionNotify:
			if (mousem_cb != NULL)
				mousem_cb(cb_arg, evt.xmotion.x, evt.xmotion.y);
			break;
		}
	}
}

static void x11h_wait_vmstate(void)
{
	Atom wm_state = g_xstuff.pXInternAtom(g_xstuff.display, "WM_STATE", False);
	XEvent evt;
	int i;

	usleep(20000);

	for (i = 0; i < 20; i++) {
		while (g_xstuff.pXPending(g_xstuff.display)) {
			g_xstuff.pXNextEvent(g_xstuff.display, &evt);
			// printf("w event %d\n", evt.type);
			if (evt.type == PropertyNotify && evt.xproperty.atom == wm_state)
				return;
		}
		usleep(200000);
	}

	fprintf(stderr, PFX "timeout waiting for wm_state change\n");
}

static int x11h_minimize(void)
{
	XSetWindowAttributes attributes;
	Display *display = g_xstuff.display;
	Window window = g_xstuff.window;
	int screen = DefaultScreen(g_xstuff.display);
	int display_width, display_height;
	XWMHints wm_hints;
	XEvent evt;

	g_xstuff.pXWithdrawWindow(display, window, screen);

	attributes.override_redirect = False;
	g_xstuff.pXChangeWindowAttributes(display, window,
		CWOverrideRedirect, &attributes);

	wm_hints.flags = StateHint;
	wm_hints.initial_state = IconicState;
	g_xstuff.pXSetWMHints(display, window, &wm_hints);

	g_xstuff.pXMapWindow(display, window);

	while (g_xstuff.pXNextEvent(display, &evt) == 0)
	{
		// printf("m event %d\n", evt.type);
		switch (evt.type)
		{
			case FocusIn:
				goto out;
			default:
				break;
		}
	}

out:
	g_xstuff.pXWithdrawWindow(display, window, screen);

	// must wait for some magic vmstate property change before setting override_redirect
	x11h_wait_vmstate();

	attributes.override_redirect = True;
	g_xstuff.pXChangeWindowAttributes(display, window,
		CWOverrideRedirect, &attributes);

	// fixup window after resize on override_redirect loss
	display_width = DisplayWidth(display, screen);
	display_height = DisplayHeight(display, screen);
	g_xstuff.pXMoveResizeWindow(display, window, 0, 0, display_width, display_height);

	g_xstuff.pXMapWindow(display, window);
	g_xstuff.pXGrabKeyboard(display, window, False, GrabModeAsync, GrabModeAsync, CurrentTime);
	g_xstuff.pXkbSetDetectableAutoRepeat(display, 1, NULL);

	// we don't know when event dispatch will be called, so sync now
	g_xstuff.pXSync(display, False);

	return 0;
}

static struct termios g_kbd_termios_saved;
static int g_kbdfd = -1;

static int tty_init(void)
{
	struct termios kbd_termios;
	int mode;

	g_kbdfd = open("/dev/tty", O_RDWR);
	if (g_kbdfd == -1) {
		perror(PFX "open /dev/tty");
		return -1;
	}

	if (ioctl(g_kbdfd, KDGETMODE, &mode) == -1) {
		perror(PFX "(not hiding FB): KDGETMODE");
		goto fail;
	}

	if (tcgetattr(g_kbdfd, &kbd_termios) == -1) {
		perror(PFX "tcgetattr");
		goto fail;
	}

	g_kbd_termios_saved = kbd_termios;
	kbd_termios.c_lflag &= ~(ICANON | ECHO); // | ISIG);
	kbd_termios.c_iflag &= ~(ISTRIP | IGNCR | ICRNL | INLCR | IXOFF | IXON);
	kbd_termios.c_cc[VMIN] = 0;
	kbd_termios.c_cc[VTIME] = 0;

	if (tcsetattr(g_kbdfd, TCSAFLUSH, &kbd_termios) == -1) {
		perror(PFX "tcsetattr");
		goto fail;
	}

	if (ioctl(g_kbdfd, KDSETMODE, KD_GRAPHICS) == -1) {
		perror(PFX "KDSETMODE KD_GRAPHICS");
		tcsetattr(g_kbdfd, TCSAFLUSH, &g_kbd_termios_saved);
		goto fail;
	}

	return 0;

fail:
	close(g_kbdfd);
	g_kbdfd = -1;
	return -1;
}

static void tty_end(void)
{
	if (g_kbdfd < 0)
		return;

	if (ioctl(g_kbdfd, KDSETMODE, KD_TEXT) == -1)
		perror(PFX "KDSETMODE KD_TEXT");

	if (tcsetattr(g_kbdfd, TCSAFLUSH, &g_kbd_termios_saved) == -1)
		perror(PFX "tcsetattr");

	close(g_kbdfd);
	g_kbdfd = -1;
}

int xenv_init(int *xenv_flags, const char *window_title)
{
	int ret;

	ret = x11h_init(xenv_flags, window_title);
	if (ret == 0)
		goto out;

	if (xenv_flags != NULL)
		*xenv_flags &= ~(XENV_CAP_KEYS | XENV_CAP_MOUSE); /* TODO? */
	ret = tty_init();
	if (ret == 0)
		goto out;

	fprintf(stderr, PFX "error: both x11h_init and tty_init failed\n");
	ret = -1;
out:
	return ret;
}

int xenv_update(int (*key_cb)(void *cb_arg, int kc, int is_pressed),
		int (*mouseb_cb)(void *cb_arg, int x, int y, int button, int is_pressed),
		int (*mousem_cb)(void *cb_arg, int x, int y),
		void *cb_arg)
{
	if (g_xstuff.display) {
		x11h_update(key_cb, mouseb_cb, mousem_cb, cb_arg);
		return 0;
	}

	// TODO: read tty?
	return -1;
}

/* blocking minimize until user maximizes again */
int xenv_minimize(void)
{
	int ret;

	if (g_xstuff.display) {
		xenv_update(NULL, NULL, NULL, NULL);
		ret = x11h_minimize();
		xenv_update(NULL, NULL, NULL, NULL);
		return ret;
	}

	return -1;
}

void xenv_finish(void)
{
	// TODO: cleanup X?
	tty_end();
}

#if 0
int main()
{
	int i, r, d;

	xenv_init("just a test");

	for (i = 0; i < 5; i++) {
		while ((r = xenv_update(&d)) > 0)
			printf("%d %x %d\n", d, r, r);
		sleep(1);

		if (i == 1)
			xenv_minimize();
		printf("ll %d\n", i);
	}

	printf("xenv_finish..\n");
	xenv_finish();

	return 0;
}
#endif
