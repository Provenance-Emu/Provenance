#ifndef __GP2X_H__
#define __GP2X_H__

extern int default_cpu_clock;

/* misc */
enum {
	GP2X_DEV_GP2X = 1,
	GP2X_DEV_WIZ,
	GP2X_DEV_CAANOO,
};
extern int gp2x_dev_id;

unsigned int plat_get_ticks_ms_good(void);
unsigned int plat_get_ticks_us_good(void);

#endif
