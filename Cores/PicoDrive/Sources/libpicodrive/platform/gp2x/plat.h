extern void *gp2x_screens[4];
extern int gp2x_current_bpp;

/* SoC specific functions */
extern void (*gp2x_video_flip)(void);
extern void (*gp2x_video_flip2)(void);
/* negative bpp means rotated mode (for Wiz) */
extern void (*gp2x_video_changemode_ll)(int bpp, int is_pal);
extern void (*gp2x_video_setpalette)(int *pal, int len);
extern void (*gp2x_video_RGB_setscaling)(int ln_offs, int W, int H);
extern void (*gp2x_video_wait_vsync)(void);

/* ??? */
void gp2x_video_changemode(int bpp, int is_pal);
void gp2x_memcpy_all_buffers(void *data, int offset, int len);
void gp2x_memset_all_buffers(int offset, int byte, int len);

/* vid_*.c */
void vid_mmsp2_init(void);
void vid_mmsp2_finish(void);

void vid_pollux_init();
void vid_pollux_finish();

void gp2x_menu_init(void);
