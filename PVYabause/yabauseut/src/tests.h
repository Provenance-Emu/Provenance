/*  Copyright 2013 Theo Berkau

    This file is part of YabauseUT

    YabauseUT is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    YabauseUT is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Lapetus; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef TESTSH
#define TESTSH

#include <iapetus.h>

enum STAGESTAT
{
   STAGESTAT_USERCUSTOM=-6,
   STAGESTAT_BADGRAPHICS=-5,
   STAGESTAT_BADMIRROR=-4,
   STAGESTAT_BADINTERRUPT=-3,
   STAGESTAT_BADDATA=-2,
   STAGESTAT_BADTIMING=-1,
   STAGESTAT_WAITINGFORINT=0,
   STAGESTAT_BUSY=1,
   STAGESTAT_START=2,
   STAGESTAT_DONE=3
};

extern int stage_status;
extern u32 errordata;

void init_test(void);
void do_tests(const char *testname, int x, int y);
void register_test(void (*func)(void), const char *name);
void unregister_all_tests();

extern screen_settings_struct test_disp_settings;
extern font_struct test_disp_font;

#define wait_test(testarg, maxtime, failstatus) \
   { \
      int time; \
      \
      for (time = 0; time < (maxtime); time++) \
      { \
         if (testarg) \
         { \
            stage_status = STAGESTAT_DONE; \
            break; \
         } \
         if (time == ((maxtime) - 1)) \
            stage_status = (failstatus); \
      } \
   } 


#endif
