extern void *giz_screen;

void giz_init();
void giz_deinit(void);
void lprintf(const char *fmt, ...);

void *directfb_lock(int unused);
void  directfb_unlock(void);
void  directfb_flip(void);

#if 1
#define fb_lock   Framework2D_LockBuffer
#define fb_unlock Framework2D_UnlockBuffer
#define fb_flip   Framework2D_Flip
#else
#define fb_lock   directfb_lock
#define fb_unlock directfb_unlock
#define fb_flip   directfb_flip
#endif

#ifndef _FRAMEWORK_H
// bah, some copy-pasta
enum FRAMEWORK_BUTTONTYPES
{
	FRAMEWORK_BUTTON_DPAD_LEFT = 0,
	FRAMEWORK_BUTTON_DPAD_RIGHT,
	FRAMEWORK_BUTTON_DPAD_UP,
	FRAMEWORK_BUTTON_DPAD_DOWN,
	FRAMEWORK_BUTTON_STOP,
	FRAMEWORK_BUTTON_PLAY,
	FRAMEWORK_BUTTON_FORWARD,
	FRAMEWORK_BUTTON_REWIND,
	FRAMEWORK_BUTTON_LEFT_SHOULDER,
	FRAMEWORK_BUTTON_RIGHT_SHOULDER,
	FRAMEWORK_BUTTON_HOME,
	FRAMEWORK_BUTTON_VOLUME,
	FRAMEWORK_BUTTON_BRIGHTNESS,
	FRAMEWORK_BUTTON_ALARM,
	FRAMEWORK_BUTTON_POWER,

	FRAMEWORK_BUTTON_COUNT

};
#endif

#define PBTN_LEFT  (1 << FRAMEWORK_BUTTON_DPAD_LEFT)
#define PBTN_RIGHT (1 << FRAMEWORK_BUTTON_DPAD_RIGHT)
#define PBTN_UP    (1 << FRAMEWORK_BUTTON_DPAD_UP)
#define PBTN_DOWN  (1 << FRAMEWORK_BUTTON_DPAD_DOWN)
#define PBTN_STOP  (1 << FRAMEWORK_BUTTON_STOP)
#define PBTN_PLAY  (1 << FRAMEWORK_BUTTON_PLAY)
#define PBTN_FWD   (1 << FRAMEWORK_BUTTON_FORWARD)
#define PBTN_REW   (1 << FRAMEWORK_BUTTON_REWIND)
#define PBTN_L     (1 << FRAMEWORK_BUTTON_LEFT_SHOULDER)
#define PBTN_R     (1 << FRAMEWORK_BUTTON_RIGHT_SHOULDER)

#define PBTN_HOME       (1 << FRAMEWORK_BUTTON_HOME)
#define PBTN_VOLUME     (1 << FRAMEWORK_BUTTON_VOLUME)
#define PBTN_BRIGHTNESS (1 << FRAMEWORK_BUTTON_BRIGHTNESS)
#define PBTN_ALARM      (1 << FRAMEWORK_BUTTON_ALARM)
#define PBTN_POWER      (1 << FRAMEWORK_BUTTON_POWER)

