
extern int engineStateSuspend;

void emu_HandleResume(void);

void emu_msg_cb(const char *msg);

// actually comes from Pico/Misc_amips.s
void memset32_uncached(int *dest, int c, int count);

