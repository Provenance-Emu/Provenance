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

#include <stdio.h>
#include <string.h>
#include "tests.h"
#include "smpc.h"

//////////////////////////////////////////////////////////////////////////////

void smpc_test()
{
   int choice;

   menu_item_struct smpc_menu[] = {
   { "SMPC commands" , &smpc_cmd_test, },
   { "SMPC command timing", &smpc_cmd_timing_test, },
//   { "Keyboard test" , &kbd_test, },
//   { "Mouse target test" , &mouse_test, },
//   { "Stunner target test" , &stunner_test, },
   { "Peripheral test" , &per_test, },
//   { "Misc" , &misc_smpc_test, },
   { "\0", NULL }
   };

   for (;;)
   {
      choice = gui_do_menu(smpc_menu, &test_disp_font, 0, 0, "SMPC Tests", MTYPE_CENTER, -1);
      if (choice == -1)
         break;
   }
}

//////////////////////////////////////////////////////////////////////////////

void disable_iapetus_handler()
{
   bios_change_scu_interrupt_mask(0xFFFFFFF, MASK_VBLANKOUT | MASK_SYSTEMMANAGER);
   bios_set_scu_interrupt(0x41, NULL);
   bios_set_scu_interrupt(0x47, NULL);
}

//////////////////////////////////////////////////////////////////////////////

volatile int hblank_timer = 0;
volatile int issue_intback = 0;

volatile int lines_since_vblank_out = 0;
volatile int lines_since_vblank_in = 0;

volatile int result_pos = 0;
volatile int system_manager_occured = 0;

volatile int frame_count = 0;
volatile int stored_timer = 0;

struct ResultType
{
   int type;
   int since_vblank_out;
   int since_vblank_in;
   int free_timer;
   int frame;
   int total_time;
};

volatile struct ResultType results[64] = { { 0 } };

char * result_types[] =
{
   "bad       ",
   "intb issue",
   "sys interu",
   "in no data",
   "data remai"
};

#define RESULT_START 1
#define RESULT_SYS_MAN 2
#define RESULT_NO_DATA 3
#define RESULT_DATA_REM 4

#define TEST_STATUS_ONLY 1
#define TEST_STATUS_PERIPHERAL 2
#define TEST_PERIPHERAL_ONLY 3

//////////////////////////////////////////////////////////////////////////////

void smpc_test_vblank_out_handler()
{
   lines_since_vblank_out = 0;
   frame_count++;
}

//////////////////////////////////////////////////////////////////////////////

void smpc_test_hblank_in_handler()
{
   hblank_timer++;
   lines_since_vblank_out++;
   lines_since_vblank_in++;
}

//////////////////////////////////////////////////////////////////////////////

void smpc_test_vblank_in_handler()
{
   lines_since_vblank_in = 0;
   issue_intback = 1;
}

//////////////////////////////////////////////////////////////////////////////

void reset_result(int pos)
{
   volatile struct ResultType * r = &results[pos];
   r->type = 0;
   r->since_vblank_out = 0;
   r->since_vblank_in = 0;
   r->free_timer = 0;
   r->frame = 0;
   r->total_time = 0;
}

//////////////////////////////////////////////////////////////////////////////

inline void set_result(int type)
{
   volatile struct ResultType * r = &results[result_pos];

   r->type = type;
   r->since_vblank_out = lines_since_vblank_out;
   r->since_vblank_in = lines_since_vblank_in;
   r->free_timer = hblank_timer;
   r->frame = frame_count;
   r->total_time = hblank_timer - stored_timer;
   result_pos++;
}

//////////////////////////////////////////////////////////////////////////////

void smpc_test_system_manager_handler()
{
   set_result(RESULT_SYS_MAN);

   system_manager_occured = 1;
}

//////////////////////////////////////////////////////////////////////////////

void intback_write_iregs(int status, int p2md, int p1md, int pen, int ope)
{
   SMPC_REG_IREG(0) = status;
   SMPC_REG_IREG(1) = (p2md << 6) | (p1md << 4) | (pen << 3) | (ope << 0);
   SMPC_REG_IREG(2) = 0xF0;
   SMPC_REG_IREG(6) = 0xFE;
}

//////////////////////////////////////////////////////////////////////////////

void smpc_intback_disable_interrupts()
{
   interrupt_set_level_mask(0xF);
   bios_change_scu_interrupt_mask(0xFFFFFFFF, MASK_VBLANKOUT | MASK_HBLANKIN | MASK_VBLANKIN | MASK_SYSTEMMANAGER);
}

//////////////////////////////////////////////////////////////////////////////

void smpc_intback_set_interrupts()
{
   bios_set_scu_interrupt(0x47, smpc_test_system_manager_handler);
   bios_set_scu_interrupt(0x40, smpc_test_vblank_in_handler);
   bios_set_scu_interrupt(0x41, smpc_test_vblank_out_handler);
   bios_set_scu_interrupt(0x42, smpc_test_hblank_in_handler);
   bios_change_scu_interrupt_mask(~(MASK_VBLANKOUT | MASK_HBLANKIN | MASK_VBLANKIN | MASK_SYSTEMMANAGER), 0);
   interrupt_set_level_mask(0x1);
}

//////////////////////////////////////////////////////////////////////////////

void reset_test_vars()
{
   int i;
   for (i = 0; i < 64; i++)
      reset_result(i);

   hblank_timer = 0;
   issue_intback = 0;

   lines_since_vblank_out = 0;
   lines_since_vblank_in = 0;

   result_pos = 0;
   system_manager_occured = 0;

   frame_count = 0;
   stored_timer = 0;
}

//////////////////////////////////////////////////////////////////////////////

void smpc_intback_issue_timing_test_main(int test_type, int vblank_line)
{
   smpc_intback_disable_interrupts();

   reset_test_vars();

   test_disp_font.transparent = 0;

   smpc_intback_set_interrupts();

   for (;;)
   {
      if (issue_intback && (lines_since_vblank_in == vblank_line))
      {
         issue_intback = 0;

         if (test_type == TEST_STATUS_PERIPHERAL)
            intback_write_iregs(1, 0, 0, 1, 0);
         else if (test_type == TEST_PERIPHERAL_ONLY)
            intback_write_iregs(0, 0, 0, 1, 0);
         else if (test_type == TEST_STATUS_ONLY)
            intback_write_iregs(1, 0, 0, 0, 0);

         stored_timer = hblank_timer;

         set_result(RESULT_START);

         smpc_issue_command(SMPC_CMD_INTBACK);
      }

      if (system_manager_occured)
      {
         system_manager_occured = 0;

         if (SMPC_REG_SR & (1 << 5))
         {
            set_result(RESULT_DATA_REM);
            SMPC_REG_IREG(0) = 0x80;

         }
         else
         {
            set_result(RESULT_NO_DATA);
         }
      }

      if (result_pos > 48)
         break;
   }

   // Re-enable Peripheral Handler
   per_init();

   int i;
   int j = 2;
   int previous_frame = -1;

   for (i = 0; i < 64; i++)
   {
      if (results[i].frame < 3)
         continue;

      if (results[i].frame != previous_frame)
         j++;

      previous_frame = results[i].frame;

      vdp_printf(&test_disp_font, 0, 8 * j, 15,
         "%s | %03d | %03d | %04d | %02d | %03d",
         result_types[results[i].type],
         results[i].since_vblank_out,
         results[i].since_vblank_in,
         results[i].free_timer,
         results[i].frame,
         results[i].total_time);

      j++;

      if (j > 27)
         break;
   }

   for (;;)
   {
      vdp_vsync();

      if (per[0].but_push_once & PAD_A)
      {
         break;
      }

      if (per[0].but_push_once & PAD_START)
      {
         reset_system();
      }
   }
}

//////////////////////////////////////////////////////////////////////////////

void smpc_intback_issue_timing_test()
{
   int line = 0;

   vdp_printf(&test_disp_font, 0, 2 * 8, 15, "           | vbo | vbi | hbla | fr | lin", line);

   int increment = 4;

   for (line = 0; line < 41; line += increment)
   {
      vdp_printf(&test_disp_font, 0, 0, 15,"peripheral only, %d lines from vblank in    ", line);
      smpc_intback_issue_timing_test_main(TEST_PERIPHERAL_ONLY, line);
   }

   for (line = 0; line < 41; line += increment)
   {
      vdp_printf(&test_disp_font, 0, 0, 15, "status before, %d lines from vblank in  ", line);
      smpc_intback_issue_timing_test_main(TEST_STATUS_PERIPHERAL, line);
   }

   for (line = 0; line < 41; line += increment)
   {
      vdp_printf(&test_disp_font, 0, 0, 15, "status only, %d lines from vblank in  ", line);
      smpc_intback_issue_timing_test_main(TEST_STATUS_ONLY, line);
   }

   test_disp_font.transparent = 1;
   gui_clear_scr(&test_disp_font);
}

//////////////////////////////////////////////////////////////////////////////

void smpc_cmd_test()
{
	// Intback IREG test
//   unregister_all_tests();
//   register_test(&SmpcSNDONTest, "SNDOFF");
//   register_test(&SmpcSNDOFFTest, "SNDON");
//   register_test(&SmpcCDOFFTest, "CDOFF");
//   register_test(&SmpcCDONTest, "CDON");
//   register_test(&SmpcNETLINKOFFTest, "NETLINKOFF");
//   register_test(&SmpcNETLINKONTest, "NETLINKON");
//   register_test(&SmpcINTBACKTest, "INTBACK");
//   register_test(&SmpcSETTIMETest, "SETTIME");
//   register_test(&SmpcSETSMEMTest, "SETSMEM");
//   register_test(&SmpcNMIREQTest, "NMIREQ");
//   register_test(&SmpcRESENABTest, "RESENAB");
//   register_test(&SmpcRESDISATest, "RESDISA");
//   DoTests("SMPC Command tests", 0, 0);

   int i, j, k;

   // Disable Peripheral handler
   disable_iapetus_handler();
   test_disp_font.transparent = 0;

   vdp_printf(&test_disp_font, 2 * 8, 2 * 16, 15, "Starting test in X second(s)");

   for (i = 5; i > 0; i--)
   {
      vdp_printf(&test_disp_font, 19 * 8, 2 * 16, 15, "%d", i);

      for (j = 0; j < 60; j++)
         vdp_vsync();
   }

//   SMPC_REG_IREG(0) = 0x40;
   SMPC_REG_IREG(0) = 0xFF;
   SMPC_REG_IREG(1) = 0x08;
   SMPC_REG_IREG(2) = 0xF0;

   smpc_issue_command(SMPC_CMD_INTBACK);
   smpc_wait_till_ready();

   // Display OREGs

   // Delay for a bit
   vdp_printf(&test_disp_font, 2 * 8, (6+17) * 8, 15, "Finishing up in X second(s)");

   for (i = 9; i > 0; i--)
   {
      for (j = 0; j < 16; j++)
         vdp_printf(&test_disp_font, 2 * 8, (6+j) * 8, 15, "OREG%d = %08X", j, SMPC_REG_OREG(j));
      for (j = 0; j < 16; j++)
         vdp_printf(&test_disp_font, 20 * 8, (6+j) * 8, 15, "OREG%d = %08X", 16+j, SMPC_REG_OREG(16+j));

   	vdp_printf(&test_disp_font, 18 * 8, (6+17) * 8, 15, "%d", i);

      for (k = 0; k < 60; k++)
         vdp_vsync();
   }

   // Re-enable Peripheral Handler
   per_init();

   test_disp_font.transparent = 1;
   gui_clear_scr(&test_disp_font);
}

//////////////////////////////////////////////////////////////////////////////

void smpc_cmd_timing_test()
{
}

//////////////////////////////////////////////////////////////////////////////

void pad_test()
{
}

//////////////////////////////////////////////////////////////////////////////

void kbd_test()
{
}

//////////////////////////////////////////////////////////////////////////////

void mouse_test()
{
}

//////////////////////////////////////////////////////////////////////////////

void analogtest()
{
}

//////////////////////////////////////////////////////////////////////////////

void stunner_test()
{
}

//////////////////////////////////////////////////////////////////////////////

char *pad_string[16] = {
"",
"",
"",
"L",
"Z",
"Y",
"X",
"R",
"B",
"C",
"A",
"START",
"UP",
"DOWN",
"LEFT",
"RIGHT"
};

//////////////////////////////////////////////////////////////////////////////

u8 per_fetch_continue()
{
   // Issue a continue
   SMPC_REG_IREG(0) = 0x80;

   // Wait till command is finished
   while(SMPC_REG_SF & 0x1) {}
   return 0;
}

//////////////////////////////////////////////////////////////////////////////

u8 get_oreg(u8 *oreg_counter)
{
   u8 ret;

   if (oreg_counter[0] >= 32)
      oreg_counter[0] = per_fetch_continue();

   ret = SMPC_REG_OREG(oreg_counter[0]);
   oreg_counter[0]++;
   return ret;
}

//////////////////////////////////////////////////////////////////////////////

int end_test;

u8 disp_pad_data(u8 oreg_counter, int x, int y, u8 id)
{
   int i;
   u16 data;

   data = get_oreg(&oreg_counter) << 8;
   data |= get_oreg(&oreg_counter);

   if (!(data & 0x0F00))
      end_test = 1;

   for (i = 0; i < 16; i++)
   {
      if (!(data & (1 << i)))
      {
         vdp_printf(&test_disp_font, x, y, 0xF, "%s ", pad_string[i]);
         x += (strlen(pad_string[i])+1) * 8;
      }
   }

   for (i = 0; i < ((352 - x) >> 3); i++)
      vdp_printf(&test_disp_font, x+(i << 3), y, 0xF, " ");

   return oreg_counter;
}

//////////////////////////////////////////////////////////////////////////////

u8 disp_nothing(u8 oreg_counter, int x, int y, u8 id)
{
   int i;
   for (i = 0; i < ((352 - x) >> 3); i++)
      vdp_printf(&test_disp_font, x+(i << 3), y, 0xF, " ");

   if (id == 0xFF)
      return oreg_counter;
   else
      return (oreg_counter+(id & 0xF));
}

//////////////////////////////////////////////////////////////////////////////

typedef struct
{
  u8 id;
  char *name;
  u8 (*disp_data)(u8 oreg_counter, int xoffset, int yoffset, u8 id);
} per_info_struct;

per_info_struct per_info[] =
{
   { 0x02, "Standard Pad", disp_pad_data },
   { 0x13, "Racing Wheel", disp_nothing },
   { 0x15, "Analog Pad", disp_nothing },
   { 0x23, "Saturn Mouse", disp_nothing },
   { 0x25, "Gun", disp_nothing },
   { 0x34, "Keyboard", disp_nothing },
   { 0xE1, "Megadrive 3 button", disp_nothing },
   { 0xE2, "Megadrive 6 button", disp_nothing },
   { 0xE3, "Shuttle Mouse", disp_nothing },
   { 0xFF, "Nothing", disp_nothing }
};

//////////////////////////////////////////////////////////////////////////////

u8 per_parse(char *port_name, int y_offset, u8 oreg_counter)
{
   int i;
   u8 perid = get_oreg(&oreg_counter);

   for (i = 0; i < (sizeof(per_info) / sizeof(per_info_struct)); i++)
   {
      if (perid == per_info[i].id)
      {
         char text[50];

         sprintf(text, "Port %s: %s", port_name, per_info[i].name);
         vdp_printf(&test_disp_font, 0 * 8, y_offset, 0xF, "%s ", text);

         // Display peripheral data
         oreg_counter = per_info[i].disp_data(oreg_counter, (strlen(text)+1) * 8, y_offset, perid);
         return oreg_counter;
      }
   }

   vdp_printf(&test_disp_font, 0 * 8, y_offset, 0xF, "Port %s: Unknown(%02X)", port_name, perid);
   return oreg_counter;
}

//////////////////////////////////////////////////////////////////////////////

void per_test()
{
   interrupt_set_level_mask(0xF);

   init_iapetus(RES_352x240);
   vdp_rbg0_init(&test_disp_settings);
   vdp_set_default_palette();

   // Display On
   vdp_disp_on();

   // Disable Lapetus's peripheral handler
   bios_change_scu_interrupt_mask(0xFFFFFFF, MASK_VBLANKOUT | MASK_SYSTEMMANAGER);

   test_disp_font.transparent = 0;

   vdp_printf(&test_disp_font, 0 * 8, 1 * 8, 0xF, "Peripheral test");
   vdp_printf(&test_disp_font, 0 * 8, 2 * 8, 0xF, "(to exit, press A+B+C+START on any pad)");

   end_test = 0;

   for (;;)
   {
      unsigned char oreg_counter=0;
      unsigned char portcon;
      int i, i2;

      vdp_vsync();

      // Issue intback command
      smpc_wait_till_ready();
      SMPC_REG_IREG(0) = 0x00; // no intback status
      SMPC_REG_IREG(1) = 0x0A; // 15-byte mode, peripheral data returned, time optimized
      SMPC_REG_IREG(2) = 0xF0; // ???
      smpc_issue_command(SMPC_CMD_INTBACK);

      // Wait till command is finished
      while(SMPC_REG_SF & 0x1) {}

#if 0
      for (i = 0; i < 16; i++)
        vdp_printf(&test_disp_font, 0 * 8, (4+i) * 8, 0xF, "OREG %02d: %02X", i, SMPC_REG_OREG(i));
      for (i = 0; i < 16; i++)
        vdp_printf(&test_disp_font, 16 * 8, (4+i) * 8, 0xF, "OREG %02d: %02X", i+16, SMPC_REG_OREG(i+16));
#endif

      // Grab oreg's
      for (i = 0; i < 2; i++)
      {
         portcon = get_oreg(&oreg_counter);

         if (portcon != 0x16)
         {
            if (portcon == 0xF1)
            {
               char text[3];
               sprintf(text, "%d", i+1);
               oreg_counter = per_parse(text, (4+(8*i)) * 8, oreg_counter);
            }
            else if (portcon == 0xF0)
               vdp_printf(&test_disp_font, 0 * 8, (4+(8*i)) * 8, 0xF, "Port %d: Nothing                   ", i+1);

            for (i2 = 0; i2 < 6; i2++)
               vdp_printf(&test_disp_font, 0 * 8, (4+(8*i)+1+i2) * 8, 0xF, "                           ");
         }
         else
         {
            vdp_printf(&test_disp_font, 0 * 8, (4+(8*i)) * 8, 0xF, "Port %d: Multi-tap                 ", i+1);

            for (i2 = 0; i2 < (portcon & 0x0F); i2++)
            {
               char text[3];
               sprintf(text, "%d%c", i+1, 'A' + (char)i2);
               oreg_counter = per_parse(text, (4+(8*i)+1+i2) * 8, oreg_counter);
            }
         }
      }

      if (end_test)
         break;
   }


   test_disp_font.transparent = 1;

   // Re-enable Lapetus's peripheral handler
   bios_change_scu_interrupt_mask(~(MASK_VBLANKOUT | MASK_SYSTEMMANAGER), 0);
}

//////////////////////////////////////////////////////////////////////////////

void misc_smpc_test()
{
}

//////////////////////////////////////////////////////////////////////////////