
extern int engineStateSuspend;

void emu_handle_resume(void);

void blitscreen_clut(void);

// actually comes from Pico/Misc_amips.s
void memset32_uncached(int *dest, int c, int count);

