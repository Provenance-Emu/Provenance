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
    along with YabauseUT; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef TESTSH
#define TESTSH

#include <iapetus.h>

#define AUTO_TEST_SELECT_ADDRESS 0x7F000
#define AUTO_TEST_STATUS_ADDRESS 0x7F004
#define AUTO_TEST_MESSAGE_ADDRESS 0x7F008
#define AUTO_TEST_MESSAGE_SENT 1
#define AUTO_TEST_MESSAGE_RECEIVED 2

enum STAGESTAT
{
   STAGESTAT_USERCUSTOM=-8,
   STAGESTAT_NOTEST=-7,
   STAGESTAT_BADSIZE=-6,
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

extern volatile int stage_status;
extern u32 errordata;

void init_test(void);
void tests_wait_press();
void do_tests(const char *testname, int x, int y);
void register_test(void (*func)(void), const char *name);
void unregister_all_tests();
void tests_disp_iapetus_error(enum IAPETUS_ERR err, char *file, int line);

void auto_test_all_finished();
void auto_test_take_screenshot();
void auto_test_section_start(char* test_section_name);
void auto_test_sub_test_start(char* sub_test_name);
void auto_test_section_end();
void auto_test_get_framebuffer();

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
