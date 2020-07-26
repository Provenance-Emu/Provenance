/*
 * PicoDrive
 * Copyright (C) 2009,2010 notaz
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <stdio.h>

#include <pico/pico_int.h>
#include "cmn.h"

u8 __attribute__((aligned(4096))) tcache[DRC_TCACHE_SIZE];


void drc_cmn_init(void)
{
  int ret = plat_mem_set_exec(tcache, sizeof(tcache));
  elprintf(EL_STATUS, "drc_cmn_init: %p, %zd bytes: %d",
    tcache, sizeof(tcache), ret);

#ifdef __arm__
  if (PicoOpt & POPT_EN_DRC)
  {
    static int test_done;
    if (!test_done)
    {
      int *test_out = (void *)tcache;
      int (*testfunc)(void) = (void *)tcache;

      elprintf(EL_STATUS, "testing if we can run recompiled code..");
      *test_out++ = 0xe3a000dd; // mov r0, 0xdd
      *test_out++ = 0xe12fff1e; // bx lr
      cache_flush_d_inval_i(tcache, test_out);

      // we'll usually crash on broken platforms or bad ports,
      // but do a value check too just in case
      ret = testfunc();
      elprintf(EL_STATUS, "test %s.", ret == 0xdd ? "passed" : "failed");
      test_done = 1;
    }
  }
#endif
}

void drc_cmn_cleanup(void)
{
}

// vim:shiftwidth=2:expandtab
