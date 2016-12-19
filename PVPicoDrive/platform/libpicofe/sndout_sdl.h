int  sndout_sdl_init(void);
int  sndout_sdl_start(int rate, int stereo);
void sndout_sdl_stop(void);
void sndout_sdl_wait(void);
int  sndout_sdl_write_nb(const void *buff, int len);
void sndout_sdl_exit(void);

