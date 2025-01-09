#ifndef LIBPICOFE_SNDOUT_H
#define LIBPICOFE_SNDOUT_H

struct sndout_driver {
	const char *name;
	int  (*init)(void);
	void (*exit)(void);
	int  (*start)(int rate, int stereo);
	void (*stop)(void);
	void (*wait)(void);
	int  (*write_nb)(const void *data, int bytes);
};

extern struct sndout_driver sndout_current;

void sndout_init(void);

static inline void sndout_exit(void)
{
	sndout_current.exit();
}

static inline int sndout_start(int rate, int stereo)
{
	return sndout_current.start(rate, stereo);
}

static inline void sndout_stop(void)
{
	sndout_current.stop();
}

static inline void sndout_wait(void)
{
	sndout_current.wait();
}

static inline int sndout_write_nb(const void *data, int bytes)
{
	return sndout_current.write_nb(data, bytes);
}

#endif // LIBPICOFE_SNDOUT_H
