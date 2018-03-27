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

#include <iapetus.h>
#include "tests.h"
#include "m68k.h"

//////////////////////////////////////////////////////////////////////////////

void m68k_test()
{
   int choice;

   menu_item_struct m68k_menu[] = {
   { "68k instructions", &m68k_inst_test, },
   { "Misc" , &misc_m68k_test, },
   { "\0", NULL }
   };

   for (;;)
   {
      choice = gui_do_menu(m68k_menu, &test_disp_font, 0, 0, "68k Tests", MTYPE_CENTER, -1);
      if (choice == -1)
         break;
   }   
}

//////////////////////////////////////////////////////////////////////////////

void m68k_inst_test()
{
}

//////////////////////////////////////////////////////////////////////////////

void misc_m68k_test()
{
}

//////////////////////////////////////////////////////////////////////////////
