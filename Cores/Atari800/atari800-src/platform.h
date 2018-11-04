#ifndef PLATFORM_H_
#define PLATFORM_H_

#include "config.h"
#include <stdio.h>
#include "atari.h"
#if SUPPORTS_CHANGE_VIDEOMODE
#include "videomode.h"
#endif
#if defined(SOUND) && defined(SOUND_THIN_API)
#include "sound.h"
#endif /* defined(SOUND) && defined(SOUND_THIN_API) */

/* This include file defines prototypes for platform-specific functions. */

int PLATFORM_Initialise(int *argc, char *argv[]);
int PLATFORM_Exit(int run_monitor);
int PLATFORM_Keyboard(void);
void PLATFORM_DisplayScreen(void);

int PLATFORM_PORT(int num);
int PLATFORM_TRIG(int num);

#ifdef SUPPORTS_PLATFORM_CONFIGINIT
/* This function sets the configuration parameters to default values */
void PLATFORM_ConfigInit(void);
#endif

#ifdef SUPPORTS_PLATFORM_CONFIGURE
/* This procedure processes lines not recognized by RtConfigLoad. */
int PLATFORM_Configure(char *option, char *parameters);
#endif

#ifdef SUPPORTS_PLATFORM_CONFIGSAVE
/* This function saves additional config lines */
void PLATFORM_ConfigSave(FILE *fp);
#endif

#ifdef SUPPORTS_PLATFORM_PALETTEUPDATE
/* This function updates the palette */
/* If the platform does a conversion of colortable when it initialises
 * and the user changes colortable (such as changing from PAL to NTSC)
 * then this function should update the platform palette */
void PLATFORM_PaletteUpdate(void);
#endif

#ifdef SUPPORTS_PLATFORM_SLEEP
/* This function is for those ports that need their own version of sleep */
void PLATFORM_Sleep(double s);
#endif

#ifdef SUPPORTS_PLATFORM_TIME
/* This function is for those ports that need their own version of sleep */
double PLATFORM_Time(void);
#endif

#ifdef USE_CURSES
void curses_clear_screen(void);

void curses_clear_rectangle(int x1, int y1, int x2, int y2);

void curses_putch(int x, int y, int ascii, UBYTE fg, UBYTE bg);

void curses_display_line(int anticmode, const UBYTE *screendata);
#endif

#ifdef GUI_SDL
/* used in UI to show how the keyboard joystick is mapped */
extern int PLATFORM_kbd_joy_0_enabled;
extern int PLATFORM_kbd_joy_1_enabled;
int PLATFORM_GetRawKey(void);
#endif /* GUI_SDL */

#ifdef DIRECTX
int PLATFORM_GetKeyName(void);
#endif

#if SUPPORTS_CHANGE_VIDEOMODE
/* Returns whether the platform-specific code support the given display mode, MODE,
   with/without stretching and with/without rotation. */
int PLATFORM_SupportsVideomode(VIDEOMODE_MODE_t mode, int stretch, int rotate90);
/* Sets the screen (or window, if WINDOWED is TRUE) to resolution RES and
   selects the display mode, MODE. If ROTATE90 is TRUE, then the display area
   is rotated 90 degrees counter-clockwise. */
void PLATFORM_SetVideoMode(VIDEOMODE_resolution_t const *res, int windowed, VIDEOMODE_MODE_t mode, int rotate90);
/* Returns list of all available resolutions. The result points to a newly
   allocated memory. If no resolutions are found, the result is NULL and no
   memory is allocated. Entries on the list may repeat.*/
VIDEOMODE_resolution_t *PLATFORM_AvailableResolutions(unsigned int *size);
/* Returns the current desktop resolution. Used to compute pixel aspect ratio in windowed modes. */
VIDEOMODE_resolution_t *PLATFORM_DesktopResolution(void);
/* When in windowed mode, returns whether the application window is maximised. */
int PLATFORM_WindowMaximised(void);

#endif /* SUPPORTS_CHANGE_VIDEOMODE */

#ifdef PLATFORM_MAP_PALETTE
typedef struct PLATFORM_pixel_format_t {
	int bpp; /* Current bits per pixel */
	ULONG rmask;
	ULONG gmask;
	ULONG bmask;
} PLATFORM_pixel_format_t;
/* Returns parameters of the current display pixel format. Used when computing
   lookup tables used for blitting the Atari screen to display surface. */
void PLATFORM_GetPixelFormat(PLATFORM_pixel_format_t *format);/* Can be 8, 16, 32 */

/* Convert a table of RGB values, PALETTE, of size SIZE, to a display's native
   format and store it in the lookup table DEST. */
void PLATFORM_MapRGB(void *dest, int const *palette, int size);
#endif /* PLATFORM_MAP_PALETTE */

#if defined(SOUND) && defined(SOUND_THIN_API)
/* PLATFORM_SoundSetup opens the hardware sound output with parameters
   set beforehand in Sound_out. The implementation If the code decides so,
   the actual setup with which audio output is opened may differ from the
   provided ones. In such case Sound_out will be modified accordingly.
   The function returns TRUE if it successfully opened the sound output - in such
   case the caller should set Sound_enabled to TRUE. Sound output is initially
   paused - caller should call PLATFORM_SoundContinue to start sound output.
   When opening failed, the function returns FALSE - in this case the caller
   should set Sound_enabled to FALSE and not attempt to generate any sound.
   Calling PLATFORM_SoundSetup again with Sound_out unmodified since the
   previous call to the function, is guaranteed to not change them further -
   after all, they had been determined to be OK (or modified to be OK) at the
   previous call.
   PLATFORM_SoundSetup may be called multiple times without calling
   PLATFORM_SoundExit inbetween. */
int PLATFORM_SoundSetup(Sound_setup_t *setup);

/* PLATFORM_SoundExit is the reverse of PLATFORM_SoundSetup. It closes the
   sound output completely.
   The function will be called only if the last call to PLATFORM_SoundSetup
   returned TRUE (ie. iff Sound_enabled == TRUE). */
void PLATFORM_SoundExit(void);

/* PLATFORM_SoundPause pauses the sound output.
   The function will be called only if the last call to PLATFORM_SoundSetup
   returned TRUE (ie. iff Sound_enabled == TRUE) and only when sound is
   unpaused (ie. after PLATFORM_SoundContinue). */
void PLATFORM_SoundPause(void);

/* PLATFORM_SoundContinue unpauses the sound output.
   The function will be called only if the last call to PLATFORM_SoundSetup
   returned TRUE (ie. iff Sound_enabled == TRUE) and only when sound is paused
   (ie. straight after PLATFORM_SoundSetup or after PLATFORM_SoundPause). */
void PLATFORM_SoundContinue(void);

#ifdef SOUND_CALLBACK
/* Data from sound buffer is sent to output device by calling Sound_Callback
   in a separate thread. These two functions must be used in the main thread to
   synchronise access to variables accessed by Sound_Callback. */
void PLATFORM_SoundLock(void);
void PLATFORM_SoundUnlock(void);
#else /* !SOUND_CALLBACK */

/* Return number of bytes that can be written to the output device without
   blocking. If it is equal or larger than
   Sound_out.frag_frames*channels*sample_size, it probably means that sound
   underflow has occurred. */
unsigned int PLATFORM_SoundAvailable(void);

/* Write contents of *BUFFER to audio output device. SIZE is the size of BUFFER.
   SIZE must not be greater than
   Sound_out.frag_frames*Sound_out.channels*Sound_out.sample_size. */
void PLATFORM_SoundWrite(UBYTE const *buffer, unsigned int size);

/* Dummy functions, not needed with no SOUND_CALLBACK. */
#define PLATFORM_SoundLock() {}
#define PLATFORM_SoundUnlock() {}

#endif /* !SOUND_CALLBACK */
#endif /* defined(SOUND) && defined(SOUND_THIN_API) */

#endif /* PLATFORM_H_ */
