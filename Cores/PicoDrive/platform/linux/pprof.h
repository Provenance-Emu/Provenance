#ifndef __PPROF_H__
#define __PPROF_H__

enum pprof_points {
  pp_main,
  pp_frame,
  pp_draw,
  pp_sound,
  pp_m68k,
  pp_z80,
  pp_msh2,
  pp_ssh2,
  pp_dummy,
  pp_total_points
};

struct pp_counters
{
	unsigned long long counter[pp_total_points];
};

extern struct pp_counters *pp_counters;

#ifdef __i386__
static __attribute__((always_inline)) inline unsigned int pprof_get_one(void)
{
  unsigned long long ret;
  __asm__ __volatile__ ("rdtsc" : "=A" (ret));
  return (unsigned int)ret;
}
#define unglitch_timer(x)

#elif defined(__GP2X__)
// XXX: MMSP2 only, timer sometimes seems to return lower vals?
extern volatile unsigned long *gp2x_memregl;
#define pprof_get_one() (unsigned int)gp2x_memregl[0x0a00 >> 2]
#define unglitch_timer(di) \
  if ((signed int)(di) < 0) di = 0

#else
#error no timer
#endif

#define pprof_start(point) { \
    unsigned int pp_start_##point = pprof_get_one()

#define pprof_end(point) \
    { \
      unsigned int di = pprof_get_one() - pp_start_##point; \
      unglitch_timer(di); \
      pp_counters->counter[pp_##point] += di; \
    } \
  }

// subtract for recursive stuff
#define pprof_end_sub(point) \
    { \
      unsigned int di = pprof_get_one() - pp_start_##point; \
      unglitch_timer(di); \
      pp_counters->counter[pp_##point] -= di; \
    } \
  }

extern void pprof_init(void);
extern void pprof_finish(void);

#endif // __PPROF_H__
