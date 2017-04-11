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

//#include <lapetus.h>
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
   bios_change_scu_interrupt_mask(0xFFFFFFF, MASK_VBLANKOUT | MASK_SYSTEMMANAGER);
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
   bios_change_scu_interrupt_mask(~(MASK_VBLANKOUT | MASK_SYSTEMMANAGER), 0);
   test_disp_font.transparent = 1;
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
