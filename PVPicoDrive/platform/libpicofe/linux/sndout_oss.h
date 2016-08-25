int  sndout_oss_init(void);
int  sndout_oss_start(int rate, int stereo);
void sndout_oss_stop(void);
int  sndout_oss_write(const void *buff, int len);
int  sndout_oss_write_nb(const void *buff, int len);
int  sndout_oss_can_write(int bytes);
void sndout_oss_wait(void);
void sndout_oss_setvol(int l, int r);
void sndout_oss_exit(void);

/* make oss fragment size to fit this much video frames */
extern int sndout_oss_frag_frames;
extern int sndout_oss_can_restart;
