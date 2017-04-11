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

#include <iapetus.h>
#include "tests.h"

int stage_status=STAGESTAT_START;
int waitcounter;
u32 errordata=0;

typedef struct
{
   void (*testfunc)(void);
   const char *name;
} tests_struct;

tests_struct tests[0x100];

u8 numtests=0;

//////////////////////////////////////////////////////////////////////////////

void init_test(void)
{
   // Put saturn in a minimalized state
   int i;

   interrupt_set_level_mask(0xF);

   for (i = 0; i < 0x80; i++)
      bios_set_sh2_interrupt(i, 0);

   for (i = 0x40; i < 0x60; i++)
      bios_set_scu_interrupt(i, 0);

   // Make sure all interrupts have been called
   bios_change_scu_interrupt_mask(0, 0);
   bios_change_scu_interrupt_mask(0xFFFFFFFF, 0xFFFFFFFF);

   vdp_init(RES_320x224);
//   per_init();

   commlink_stop_service();

//   if (InterruptGetLevelMask() > 0x7)
//      interrupt_set_level_mask(0x7);

   vdp_rbg0_init(&test_disp_settings);
}

//////////////////////////////////////////////////////////////////////////////

void do_tests(const char *testname, int x, int y)
{
   int i;
   u8 stage=0;

   // Print messages and cursor
   vdp_printf(&test_disp_font, x * 8, y * 8, 0xF, (char *)testname);

   for(;;)
   {
      vdp_vsync();

      if (stage_status != STAGESTAT_BUSY && stage_status != STAGESTAT_WAITINGFORINT)
      {
         if (stage_status == STAGESTAT_DONE)
            vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xA, "OK");

         else if (stage_status < 0)
         {
            // Handle error
            switch (stage_status)
            {
               case STAGESTAT_BADTIMING:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xE, "BT");
                  break;
               case STAGESTAT_BADDATA:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "BD");
                  break;
               case STAGESTAT_BADINTERRUPT:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "BI");
                  break;
               default:
                  vdp_printf(&test_disp_font, (x+38) * 8, (y + stage + 2) * 8, 0xC, "failed");
                  break;
            }
         }

         if (stage >= numtests)
         {
            vdp_printf(&test_disp_font, x * 8, (y + stage + 3) * 8, 0xF, "All tests done.");
            break;
         }

         stage_status = STAGESTAT_BUSY;

         if (tests[stage].name)
            vdp_printf(&test_disp_font, x * 8, (y + stage + 3) * 8, 0xF, (char *)tests[stage].name);

         if (tests[stage].testfunc)
            tests[stage].testfunc();

         waitcounter = 60 * 5;

         stage++;
      }
      else
      {
         if (stage_status == STAGESTAT_WAITINGFORINT)
         {
            // decrement waitcounter
            waitcounter--;
            if (waitcounter <= 0)
               stage_status = STAGESTAT_BADINTERRUPT;
#ifdef DEBUG
            vdp_printf(&test_disp_font, 0 * 8, 23 * 8, 0xF, "%08X", waitcounter);
#endif
         }
      }
   }

   // Reset all interrupts
   for (i = 0; i < 0x80; i++)
      bios_set_sh2_interrupt(i, 0);

   for (i = 0x40; i < 0x60; i++)
      bios_set_scu_interrupt(i, 0);

   per_init();
   interrupt_set_level_mask(0x6);

   vdp_vsync();

   // Wait until no buttons are pressed
   while (per[0].but_push_once || per[0].but_push)
   {
      vdp_vsync();
   }

   for (;;)
   {
      vdp_vsync(); 

      // return whenever a button pressed
      if (per[0].but_push_once & PAD_A ||
          per[0].but_push_once & PAD_B ||
          per[0].but_push_once & PAD_C ||
          per[0].but_push_once & PAD_X ||
          per[0].but_push_once & PAD_Y ||
          per[0].but_push_once & PAD_Z ||
          per[0].but_push_once & PAD_L ||
          per[0].but_push_once & PAD_R ||
          per[0].but_push_once & PAD_START)
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void register_test(void (*func)(void), const char *name)
{
   tests[numtests].testfunc = func;
   tests[numtests].name = name;
   numtests++;
}

//////////////////////////////////////////////////////////////////////////////

void unregister_all_tests()
{
   int i;

   for (i = 0; i < 0x100; i++)
   {
      tests[i].testfunc = 0;
      tests[i].name = 0;
   }

   numtests=0;
   stage_status=STAGESTAT_START;
}

//////////////////////////////////////////////////////////////////////////////

