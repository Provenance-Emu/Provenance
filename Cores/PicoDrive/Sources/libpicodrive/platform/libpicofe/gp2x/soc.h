
extern volatile unsigned short *memregs;
extern volatile unsigned int   *memregl;
extern int memdev;

typedef enum {
	SOCID_MMSP2 = 1,
	SOCID_POLLUX,
} gp2x_soc_t;

gp2x_soc_t soc_detect(void);

void mmsp2_init(void);
void mmsp2_finish(void);

void pollux_init(void);
void pollux_finish(void);

/* gettimeofday is not suitable for Wiz, at least fw 1.1 or lower */
extern unsigned int (*gp2x_get_ticks_ms)(void);
extern unsigned int (*gp2x_get_ticks_us)(void);
