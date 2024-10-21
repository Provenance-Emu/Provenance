/******************************************************************************/
/* Mednafen NEC PC-FX Emulation Module                                        */
/******************************************************************************/
/* king-bgfast-blit.inc:
**  Copyright (C) 2006-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

  switch(bgmode & 0x7)
  {
   case 0x01: // 4 color, 1/4 byte per pixel :b
        sexy_y_pos >>= 3;
        for(int x = 0; x < 256 + 8; x+= 8)
        {
	 DRAWBG8x1_LPRE();
         const uint16 *cgptr;
	 uint32 pbn = 0;

	 if(BGFAST_BATMODE)
	 {
          uint16 bat = king_bat_base[(bat_offset + (bat_x + bat_y)) & 0x1FFFF];
          pbn = (bat >> 12) << 2;
          bat &= 0x0FFF;
          cgptr = &king_cg_base[(cg_offset + (bat * 8) + ysmall) & 0x1FFFF];
	 }
	 else
  	  cgptr = &king_cg_base[(cg_offset + (bat_x * 1) + sexy_y_pos) & 0x1FFFF];

         DRAWBG8x1_4(target + x, cgptr, palette_ptr + pbn, layer_or);
         DRAWBG8x1_LPOST();
        }
	break;
   case 0x02: // 16 color, 1/2 byte per pixel
	sexy_y_pos >>= 2;
        for(int x = 0; x < 256 + 8; x+= 8)
        {
	 DRAWBG8x1_LPRE();
	 const uint16 *cgptr;
	 uint32 pbn = 0;

	 if(BGFAST_BATMODE)
	 {
          uint16 bat = king_bat_base[(bat_offset + (bat_x + bat_y)) & 0x1FFFF];
          pbn = ((bat >> 12) << 4);
          bat &= 0x0FFF;
          cgptr = &king_cg_base[(cg_offset + (bat * 16) + ysmall * 2) & 0x1FFFF];
	 }
	 else 
	  cgptr = &king_cg_base[(cg_offset + (bat_x * 2) + sexy_y_pos) & 0x1FFFF];

         DRAWBG8x1_16(target + x, cgptr, palette_ptr + pbn, layer_or);
         DRAWBG8x1_LPOST();
        }
        break;
   case 0x03: // 256 color, 1 byte per pixel palettized - OK
	 sexy_y_pos >>= 1;
         for(int x = 0; x < 256 + 8; x+= 8)
         {
	  DRAWBG8x1_LPRE();
	  const uint16 *cgptr;

	  if(BGFAST_BATMODE)
	  {
           uint16 bat = king_bat_base[(bat_offset + (bat_x + bat_y)) & 0x1FFFF];
           cgptr = &king_cg_base[(cg_offset + (bat * 32) + ysmall * 4) & 0x1FFFF];
	  }
	  else
           cgptr = &king_cg_base[(cg_offset + (bat_x * 4) + sexy_y_pos) & 0x1FFFF];

          DRAWBG8x1_256(target + x, cgptr, palette_ptr, layer_or);
          DRAWBG8x1_LPOST();
        }
	break;

   case 0x04: // 64K color, 2 bytes per pixel - OK
        for(int x = 0; x < 256 + 8; x+=8)
        {
	 DRAWBG8x1_LPRE();
	 const uint16 *cgptr;

	 if(BGFAST_BATMODE)
	 {
          uint16 bat = king_bat_base[(bat_offset + (bat_x + bat_y)) & 0x1FFFF];
          cgptr = &king_cg_base[(cg_offset + (bat * 64) + ysmall * 8) & 0x1FFFF];
	 }
	 else
          cgptr = &king_cg_base[(cg_offset + (bat_x * 8) + sexy_y_pos) & 0x1FFFF];

         DRAWBG8x1_64K(target + x, cgptr, palette_ptr, layer_or);
         DRAWBG8x1_LPOST();
        }
	break;

   case 0x05: // 16M color, 2 bytes per pixel - OK
        for(int x = 0; x < 256 + 8; x+=8)
        {
	 DRAWBG8x1_LPRE();
	 const uint16 *cgptr;
	 if(BGFAST_BATMODE)
	 {
          uint16 bat = king_bat_base[(bat_offset + (bat_x + bat_y)) & 0x1FFFF];
          cgptr = &king_cg_base[(cg_offset + (bat * 64) + ysmall * 8) & 0x1FFFF];
	 }
         else 
	  cgptr = &king_cg_base[(cg_offset + (bat_x * 8) + sexy_y_pos) & 0x1FFFF];

         DRAWBG8x1_16M(target + x, cgptr, palette_ptr, layer_or);
         DRAWBG8x1_LPOST();
        }
	break;
  }
