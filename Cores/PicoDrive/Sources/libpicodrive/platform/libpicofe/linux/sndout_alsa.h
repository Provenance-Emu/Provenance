
int  sndout_alsa_init(void);
int  sndout_alsa_start(int rate, int stereo);
void sndout_alsa_stop(void);
void sndout_alsa_wait(void);
int  sndout_alsa_write_nb(const void *samples, int len);
void sndout_alsa_exit(void);
